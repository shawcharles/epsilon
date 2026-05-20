const _OPTIMIZATION_GRID_POINTS = 64

function _channel_total_spend(data::MMMData, channel_index::Integer)
    return sum(Float64.(view(data.channels, :, Int(channel_index))))
end

function _channel_total_spend(data::PanelMMMData, channel_index::Integer)
    return sum(Float64.(view(data.channels, :, Int(channel_index), :)))
end

function _finite_spend_value(value, action::AbstractString, description::AbstractString)
    finite_value = Float64(value)
    isfinite(finite_value) ||
        throw(ArgumentError("$action requires $description to be finite"))
    finite_value >= 0.0 ||
        throw(ArgumentError("$action requires $description to be nonnegative"))
    return finite_value
end

function _normalized_optimization_channels(
        spec::MMMModelSpec,
        channels,
        action::AbstractString,
    )
    if isnothing(channels)
        optimized_channels = copy(spec.channel_columns)
    else
        provided = [String(channel) for channel in channels]
        isempty(provided) &&
            throw(ArgumentError("$action requires at least one optimization channel"))
        length(unique(provided)) == length(provided) ||
            throw(ArgumentError("$action requires optimization channels without duplicates"))

        unknown = sort(setdiff(provided, spec.channel_columns))
        isempty(unknown) ||
            throw(
            ArgumentError(
                "$action requires optimization channels drawn from `InferenceResults.spec.channel_columns`; unknown channels: $(join(unknown, ", "))",
            ),
        )
        optimized_channels = [
            channel for channel in spec.channel_columns if channel in Set(provided)
        ]
    end

    fixed_channels = [
        channel for channel in spec.channel_columns if !(channel in Set(optimized_channels))
    ]
    return optimized_channels, fixed_channels
end

function _normalized_bound_record(value, action::AbstractString, label::AbstractString, channel::AbstractString)
    source = if value isa NamedTuple
        Dict(Symbol(key) => entry for (key, entry) in pairs(value))
    elseif value isa AbstractDict
        Dict(Symbol(String(key)) => entry for (key, entry) in pairs(value))
    else
        throw(
            ArgumentError(
                "$action requires `$label` bounds for channel `$channel` to be a named tuple or mapping with optional `lower` / `upper` keys",
            ),
        )
    end

    invalid = sort!(String.(setdiff(collect(keys(source)), [:lower, :upper])))
    isempty(invalid) ||
        throw(
        ArgumentError(
            "$action requires `$label` bounds for channel `$channel` to use only `lower` / `upper` keys",
        ),
    )

    lower = haskey(source, :lower) ? _finite_spend_value(
            source[:lower],
            action,
            "`$label.lower` for channel `$channel`",
        ) : nothing
    upper = haskey(source, :upper) ? _finite_spend_value(
            source[:upper],
            action,
            "`$label.upper` for channel `$channel`",
        ) : nothing
    (!isnothing(lower) && !isnothing(upper) && lower > upper) &&
        throw(
        ArgumentError(
            "$action requires `$label.lower <= $label.upper` for channel `$channel`",
        ),
    )
    return (lower = lower, upper = upper)
end

function _normalized_bound_mapping(
        mapping,
        action::AbstractString,
        label::AbstractString,
        optimized_channels::AbstractVector{<:AbstractString},
    )
    isnothing(mapping) && return Dict{String, NamedTuple{(:lower, :upper), Tuple{Union{Nothing, Float64}, Union{Nothing, Float64}}}}()
    mapping isa AbstractDict ||
        throw(
        ArgumentError(
            "$action requires `$label` to be a channel-keyed mapping or `nothing`",
        ),
    )

    optimized_set = Set(String.(optimized_channels))
    normalized = Dict{String, NamedTuple{(:lower, :upper), Tuple{Union{Nothing, Float64}, Union{Nothing, Float64}}}}()
    seen = Set{String}()

    for (raw_key, value) in pairs(mapping)
        channel = String(raw_key)
        channel in seen &&
            throw(
            ArgumentError(
                "$action requires `$label` to contain each optimized channel at most once; duplicate channel `$channel` encountered",
            ),
        )
        push!(seen, channel)
        channel in optimized_set ||
            throw(
            ArgumentError(
                "$action requires `$label` keys to be drawn from the optimized channel set; unexpected channel `$channel` encountered",
            ),
        )
        normalized[channel] = _normalized_bound_record(value, action, label, channel)
    end
    return normalized
end

function _normalized_relative_bound_mapping(
        mapping,
        action::AbstractString,
        optimized_channels::AbstractVector{<:AbstractString},
    )
    normalized = _normalized_bound_mapping(mapping, action, "relative_bounds", optimized_channels)
    for (channel, bounds) in pairs(normalized)
        lower = bounds.lower
        upper = bounds.upper
        (!isnothing(lower) && lower < 0.0) &&
            throw(
            ArgumentError(
                "$action requires `relative_bounds.lower` for channel `$channel` to be nonnegative",
            ),
        )
        (!isnothing(upper) && upper < 0.0) &&
            throw(
            ArgumentError(
                "$action requires `relative_bounds.upper` for channel `$channel` to be nonnegative",
            ),
        )
    end
    return normalized
end

function _effective_channel_constraint(
        channel::AbstractString,
        observed_spend::Real;
        absolute_bounds = nothing,
        relative_bounds = nothing,
    )
    absolute_lower = isnothing(absolute_bounds) ? nothing : absolute_bounds.lower
    absolute_upper = isnothing(absolute_bounds) ? nothing : absolute_bounds.upper
    relative_lower = isnothing(relative_bounds) || isnothing(relative_bounds.lower) ? nothing :
        Float64(relative_bounds.lower) * Float64(observed_spend)
    relative_upper = isnothing(relative_bounds) || isnothing(relative_bounds.upper) ? nothing :
        Float64(relative_bounds.upper) * Float64(observed_spend)

    lower_candidates = Float64[0.0]
    !isnothing(absolute_lower) && push!(lower_candidates, Float64(absolute_lower))
    !isnothing(relative_lower) && push!(lower_candidates, Float64(relative_lower))
    effective_lower = maximum(lower_candidates)

    upper_candidates = Float64[]
    !isnothing(absolute_upper) && push!(upper_candidates, Float64(absolute_upper))
    !isnothing(relative_upper) && push!(upper_candidates, Float64(relative_upper))
    effective_upper = isempty(upper_candidates) ? nothing : minimum(upper_candidates)

    (!isnothing(effective_upper) && effective_lower > effective_upper) &&
        throw(
        ArgumentError(
            "optimize_budget requires feasible bounds for channel `$channel`; effective lower bound exceeds effective upper bound",
        ),
    )

    return BudgetChannelConstraint(
        String(channel),
        Float64(observed_spend),
        isnothing(absolute_lower) ? nothing : Float64(absolute_lower),
        isnothing(absolute_upper) ? nothing : Float64(absolute_upper),
        isnothing(relative_bounds) ? nothing : relative_bounds.lower,
        isnothing(relative_bounds) ? nothing : relative_bounds.upper,
        effective_lower,
        effective_upper,
    )
end

function _normalized_constraint_audit(
        results::InferenceResults;
        total_budget,
        channels = nothing,
        budget_bounds = nothing,
        relative_bounds = nothing,
        action::AbstractString = "optimize_budget",
    )
    data = if results.spec.model_kind === :panel_mmm
        _require_postmodel_panel_results(results, action)
    else
        _require_postmodel_time_series_results(results, action)
    end
    total_budget_value = _finite_spend_value(total_budget, action, "`total_budget`")
    optimized_channels, fixed_channels = _normalized_optimization_channels(
        results.spec,
        channels,
        action,
    )

    absolute_mapping = _normalized_bound_mapping(
        budget_bounds,
        action,
        "budget_bounds",
        optimized_channels,
    )
    relative_mapping = _normalized_relative_bound_mapping(
        relative_bounds,
        action,
        optimized_channels,
    )

    channel_constraints = BudgetChannelConstraint[]
    for channel in optimized_channels
        channel_index = results.spec.channel_indices[channel]
        observed_spend = _channel_total_spend(data, channel_index)
        constraint = _effective_channel_constraint(
            channel,
            observed_spend;
            absolute_bounds = get(absolute_mapping, channel, nothing),
            relative_bounds = get(relative_mapping, channel, nothing),
        )
        push!(channel_constraints, constraint)
    end

    lower_sum = sum(constraint.effective_lower for constraint in channel_constraints)
    total_budget_value + sqrt(eps(Float64)) < lower_sum &&
        throw(
        ArgumentError(
            "$action requires a feasible `total_budget`; requested total budget is below the summed effective lower bounds",
        ),
    )

    finite_upper = [constraint.effective_upper for constraint in channel_constraints if !isnothing(constraint.effective_upper)]
    if length(finite_upper) == length(channel_constraints)
        upper_sum = sum(Float64(value) for value in finite_upper)
        total_budget_value - sqrt(eps(Float64)) > upper_sum &&
            throw(
            ArgumentError(
                "$action requires a feasible `total_budget`; requested total budget exceeds the summed effective upper bounds",
            ),
        )
    end

    return BudgetConstraintAudit(
        total_budget_value,
        optimized_channels,
        fixed_channels,
        channel_constraints,
    )
end

function _unique_sorted_floats(values::AbstractVector{<:Real})
    sorted_values = sort(Float64.(collect(values)))
    isempty(sorted_values) && return Float64[]

    unique_values = Float64[sorted_values[1]]
    tolerance = sqrt(eps(Float64))
    for value in sorted_values[2:end]
        isapprox(value, unique_values[end]; atol = tolerance, rtol = tolerance) || push!(
            unique_values,
            value,
        )
    end
    return unique_values
end

function _default_spend_grid(
        observed_spend::Real,
        total_budget::Real;
        effective_lower::Real,
        effective_upper = nothing,
    )
    domain_upper = isnothing(effective_upper) ?
        max(Float64(observed_spend), Float64(total_budget)) :
        max(Float64(observed_spend), Float64(total_budget), Float64(effective_upper))

    if isapprox(domain_upper, 0.0; atol = sqrt(eps(Float64)))
        return [0.0, 1.0]
    end

    base = collect(range(0.0, stop = domain_upper, length = _OPTIMIZATION_GRID_POINTS))
    extras = Float64[0.0, Float64(observed_spend), Float64(effective_lower), domain_upper]
    !isnothing(effective_upper) && push!(extras, Float64(effective_upper))
    grid = _unique_sorted_floats(vcat(base, extras))
    length(grid) >= 2 || push!(grid, domain_upper + 1.0)
    return grid
end

function _normalized_custom_grid(
        custom_grid,
        constraint::BudgetChannelConstraint,
        total_budget::Real,
        action::AbstractString,
    )
    spend_grid = _validated_spend_grid(custom_grid, action; require_multiple_points = true)
    domain_upper = isnothing(constraint.effective_upper) ?
        max(constraint.observed_spend, Float64(total_budget)) :
        Float64(constraint.effective_upper)
    spend_grid[1] <= constraint.effective_lower + sqrt(eps(Float64)) ||
        throw(
        ArgumentError(
            "$action requires custom spend grids to cover the effective lower bound for channel `$(constraint.channel)`",
        ),
    )
    spend_grid[end] + sqrt(eps(Float64)) >= domain_upper ||
        throw(
        ArgumentError(
            "$action requires custom spend grids to cover the full feasible spend domain for channel `$(constraint.channel)`",
        ),
    )
    spend_grid[1] <= constraint.observed_spend + sqrt(eps(Float64)) <= spend_grid[end] + sqrt(eps(Float64)) ||
        throw(
        ArgumentError(
            "$action requires custom spend grids to cover the observed spend point for channel `$(constraint.channel)`",
        ),
    )
    return spend_grid
end

function _normalized_grid_mapping(
        grid,
        audit::BudgetConstraintAudit,
        action::AbstractString,
    )
    isnothing(grid) && return nothing
    grid isa AbstractDict ||
        throw(
        ArgumentError(
            "$action requires `grid` to be a channel-keyed mapping or `nothing`",
        ),
    )

    optimized_set = Set(audit.optimized_channels)
    normalized = Dict{String, Vector{Float64}}()
    seen = Set{String}()
    for (raw_key, raw_value) in pairs(grid)
        channel = String(raw_key)
        channel in seen &&
            throw(
            ArgumentError(
                "$action requires `grid` to contain each optimized channel at most once; duplicate channel `$channel` encountered",
            ),
        )
        push!(seen, channel)
        channel in optimized_set ||
            throw(
            ArgumentError(
                "$action requires `grid` keys to be drawn from the optimized channel set; unexpected channel `$channel` encountered",
            ),
        )
        normalized[channel] = _validated_spend_grid(
            raw_value,
            action;
            require_multiple_points = true,
        )
    end

    missing_channels = [channel for channel in audit.optimized_channels if !haskey(normalized, channel)]
    isempty(missing_channels) ||
        throw(
        ArgumentError(
            "$action requires `grid` entries for every optimized channel; missing entries for $(join(missing_channels, ", "))",
        ),
    )
    return normalized
end
