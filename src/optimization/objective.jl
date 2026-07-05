struct _MonotoneCubicInterpolation
    x::Vector{Float64}
    y::Vector{Float64}
    slopes::Vector{Float64}
end

function _monotone_cubic_interpolation(
        x::AbstractVector,
        y::AbstractVector,
        action::AbstractString,
    )
    x_values = _validated_spend_grid(x, action; require_multiple_points = true)
    y_values = Float64.(collect(y))
    length(x_values) == length(y_values) ||
        throw(ArgumentError("$action requires matching spend and response grid lengths"))
    all(isfinite, y_values) ||
        throw(ArgumentError("$action requires finite response-grid values"))
    all(diff(y_values) .>= -sqrt(eps(Float64))) ||
        throw(
        ArgumentError(
            "$action requires nondecreasing posterior-mean response across the spend grid",
        ),
    )

    deltas = diff(y_values) ./ diff(x_values)
    slopes = zeros(Float64, length(x_values))
    slopes[1] = deltas[1]
    slopes[end] = deltas[end]

    for index in 2:(length(x_values) - 1)
        if isapprox(deltas[index - 1], 0.0; atol = sqrt(eps(Float64))) ||
                isapprox(deltas[index], 0.0; atol = sqrt(eps(Float64))) ||
                signbit(deltas[index - 1]) != signbit(deltas[index])
            slopes[index] = 0.0
        else
            h_prev = x_values[index] - x_values[index - 1]
            h_next = x_values[index + 1] - x_values[index]
            w_prev = 2.0 * h_next + h_prev
            w_next = h_next + 2.0 * h_prev
            slopes[index] = (w_prev + w_next) / (
                (w_prev / deltas[index - 1]) + (w_next / deltas[index])
            )
        end
    end

    return _MonotoneCubicInterpolation(x_values, y_values, slopes)
end

function _find_bracketing_interval(x::AbstractVector{Float64}, point::Float64)
    point < x[1] - sqrt(eps(Float64)) &&
        throw(ArgumentError("evaluation point lies below the interpolation domain"))
    point > x[end] + sqrt(eps(Float64)) &&
        throw(ArgumentError("evaluation point lies above the interpolation domain"))

    point <= x[1] && return 1
    point >= x[end] && return length(x) - 1
    return searchsortedlast(x, point)
end

function _evaluate(interpolation::_MonotoneCubicInterpolation, point::Real)
    x = interpolation.x
    y = interpolation.y
    slopes = interpolation.slopes
    xq = Float64(point)
    interval = _find_bracketing_interval(x, xq)
    h = x[interval + 1] - x[interval]
    t = (xq - x[interval]) / h

    h00 = (2 * t^3) - (3 * t^2) + 1
    h10 = t^3 - (2 * t^2) + t
    h01 = (-2 * t^3) + (3 * t^2)
    h11 = t^3 - t^2

    return (h00 * y[interval]) +
        (h10 * h * slopes[interval]) +
        (h01 * y[interval + 1]) +
        (h11 * h * slopes[interval + 1])
end

function _evaluate_derivative(interpolation::_MonotoneCubicInterpolation, point::Real)
    x = interpolation.x
    y = interpolation.y
    slopes = interpolation.slopes
    xq = Float64(point)
    interval = _find_bracketing_interval(x, xq)
    h = x[interval + 1] - x[interval]
    t = (xq - x[interval]) / h

    dh00 = 6 * t^2 - 6 * t
    dh10 = 3 * t^2 - 4 * t + 1
    dh01 = -6 * t^2 + 6 * t
    dh11 = 3 * t^2 - 2 * t

    return (
        (dh00 * y[interval]) +
            (dh10 * h * slopes[interval]) +
            (dh01 * y[interval + 1]) +
            (dh11 * h * slopes[interval + 1])
    ) / h
end

function _evaluate_second_derivative(
        interpolation::_MonotoneCubicInterpolation,
        point::Real,
    )
    x = interpolation.x
    y = interpolation.y
    slopes = interpolation.slopes
    xq = Float64(point)
    interval = _find_bracketing_interval(x, xq)
    h = x[interval + 1] - x[interval]
    t = (xq - x[interval]) / h

    d2h00 = 12 * t - 6
    d2h10 = 6 * t - 4
    d2h01 = -12 * t + 6
    d2h11 = 6 * t - 2

    return (
        (d2h00 * y[interval]) +
            (d2h10 * h * slopes[interval]) +
            (d2h01 * y[interval + 1]) +
            (d2h11 * h * slopes[interval + 1])
    ) / (h^2)
end

function _baseline_and_fixed_response(
        results::InferenceResults,
        optimized_channels::AbstractVector{<:AbstractString},
    )
    contributions = contribution_results(results)
    optimized_media_names = Set("media:$(channel)" for channel in optimized_channels)
    baseline_indices = Int[]
    fixed_media_indices = Int[]

    for (index, kind) in enumerate(contributions.component_kinds)
        if kind == :media
            contributions.component_names[index] in optimized_media_names || push!(
                fixed_media_indices,
                index,
            )
        else
            push!(baseline_indices, index)
        end
    end

    values = contributions.values
    baseline_response = isempty(baseline_indices) ? 0.0 :
        sum(mean(sum(values[:, :, baseline_indices]; dims = 2); dims = 1))
    fixed_response = isempty(fixed_media_indices) ? 0.0 :
        sum(mean(sum(values[:, :, fixed_media_indices]; dims = 2); dims = 1))
    return Float64(baseline_response), Float64(fixed_response)
end

function _surface_interpolation(surface::BudgetChannelSurface, action::AbstractString)
    return _monotone_cubic_interpolation(surface.spend_grid, surface.response_grid, action)
end

function _evaluate_channel_surface_unbounded(
        surface::BudgetChannelSurface,
        spend::Real;
        action::AbstractString = "optimize_budget",
    )
    spend_value = _finite_spend_value(spend, action, "channel spend")
    return _evaluate(_surface_interpolation(surface, action), spend_value)
end

function _evaluate_channel_surface(surface::BudgetChannelSurface, spend::Real; action::AbstractString = "optimize_budget")
    spend_value = _finite_spend_value(spend, action, "channel spend")
    spend_value + sqrt(eps(Float64)) >= surface.effective_lower ||
        throw(
        ArgumentError(
            "$action requires channel spend for `$(surface.channel)` to respect the effective lower bound",
        ),
    )
    (!isnothing(surface.effective_upper) && spend_value - sqrt(eps(Float64)) > surface.effective_upper) &&
        throw(
        ArgumentError(
            "$action requires channel spend for `$(surface.channel)` to respect the effective upper bound",
        ),
    )
    return _evaluate_channel_surface_unbounded(surface, spend_value; action = action)
end

function _evaluate_channel_surface_derivative(
        surface::BudgetChannelSurface,
        spend::Real;
        action::AbstractString = "optimize_budget",
    )
    _evaluate_channel_surface(surface, spend; action = action)
    return _evaluate_derivative(_surface_interpolation(surface, action), spend)
end

function _evaluate_channel_surface_second_derivative(
        surface::BudgetChannelSurface,
        spend::Real;
        action::AbstractString = "optimize_budget",
    )
    _evaluate_channel_surface(surface, spend; action = action)
    return _evaluate_second_derivative(_surface_interpolation(surface, action), spend)
end

function _allocation_vector(
        problem::BudgetOptimizationProblem,
        allocation;
        action::AbstractString = "optimize_budget",
    )
    values = if allocation isa AbstractDict
        normalized = Dict{String, Any}()
        seen = Set{String}()
        for (channel, value) in pairs(allocation)
            normalized_channel = String(channel)
            normalized_channel in seen &&
                throw(
                ArgumentError(
                    "$action requires spend allocations to contain each optimized channel at most once; duplicate channel `$normalized_channel` encountered",
                ),
            )
            push!(seen, normalized_channel)
            normalized[normalized_channel] = value
        end
        channels = collect(keys(normalized))
        length(channels) == length(problem.optimized_channels) ||
            throw(
            ArgumentError(
                "$action requires spend allocations for exactly the optimized channel set",
            ),
        )
        unknown = sort(setdiff(channels, problem.optimized_channels))
        isempty(unknown) ||
            throw(
            ArgumentError(
                "$action requires spend allocations for only the optimized channel set; unknown channels: $(join(unknown, ", "))",
            ),
        )
        [
            _finite_spend_value(
                    normalized[channel],
                    action,
                    "spend allocation for channel `$channel`",
                ) for channel in problem.optimized_channels
        ]
    else
        vector = Float64.(collect(allocation))
        length(vector) == length(problem.optimized_channels) ||
            throw(
            ArgumentError(
                "$action requires one spend allocation per optimized channel",
            ),
        )
        [
            _finite_spend_value(
                    value,
                    action,
                    "spend allocation entry",
                ) for value in vector
        ]
    end

    sum(values) ≈ problem.total_budget ||
        throw(
        ArgumentError(
            "$action requires spend allocations to satisfy the fixed total-budget equality",
        ),
    )
    return values
end

"""
    _build_budget_optimization_problem(results; total_budget, channels=nothing, budget_bounds=nothing, relative_bounds=nothing, objective=:total_response, grid=nothing)

Assemble the solver-agnostic bounded Phase 8 optimization problem from grouped
`InferenceResults`.
"""
function _build_budget_optimization_problem(
        results::InferenceResults;
        total_budget,
        channels = nothing,
        budget_bounds = nothing,
        relative_bounds = nothing,
        objective = :total_response,
        grid = nothing,
    )
    action = "optimize_budget"
    _require_postmodel_time_series_results(results, action)
    objective_symbol = objective isa Symbol ? objective : Symbol(lowercase(String(objective)))
    objective_symbol === :total_response ||
        throw(
        ArgumentError(
            "$action currently supports only `objective = :total_response` in the bounded Phase 8 surface",
        ),
    )

    audit = _normalized_constraint_audit(
        results;
        total_budget,
        channels,
        budget_bounds,
        relative_bounds,
        action,
    )
    custom_grids = _normalized_grid_mapping(grid, audit, action)

    channel_surfaces = BudgetChannelSurface[]
    current_spend = Float64[]
    for constraint in audit.channel_constraints
        spend_grid = isnothing(custom_grids) ? nothing : custom_grids[constraint.channel]
        surface = if isnothing(spend_grid)
            total_budget_value = audit.total_budget
            default_grid = _default_spend_grid(
                constraint.observed_spend,
                total_budget_value;
                effective_lower = constraint.effective_lower,
                effective_upper = constraint.effective_upper,
            )
            curves = response_curve_results(results; channel = constraint.channel, grid = default_grid)
            response_grid = vec(mean(curves.values; dims = 1))
            _ = _monotone_cubic_interpolation(default_grid, response_grid, action)
            BudgetChannelSurface(
                constraint.channel,
                constraint.observed_spend,
                default_grid,
                response_grid,
                constraint.effective_lower,
                constraint.effective_upper,
            )
        else
            validated_grid = _normalized_custom_grid(
                spend_grid,
                constraint,
                audit.total_budget,
                action,
            )
            curves = response_curve_results(results; channel = constraint.channel, grid = validated_grid)
            response_grid = vec(mean(curves.values; dims = 1))
            _ = _monotone_cubic_interpolation(validated_grid, response_grid, action)
            BudgetChannelSurface(
                constraint.channel,
                constraint.observed_spend,
                validated_grid,
                response_grid,
                constraint.effective_lower,
                constraint.effective_upper,
            )
        end
        push!(channel_surfaces, surface)
        push!(current_spend, constraint.observed_spend)
    end

    fixed_spend = Float64[
        _channel_total_spend(
                results.observed_data,
                results.spec.channel_indices[channel],
            ) for channel in audit.fixed_channels
    ]
    baseline_response, fixed_response = _baseline_and_fixed_response(
        results,
        audit.optimized_channels,
    )
    current_response = baseline_response +
        fixed_response +
        sum(
        _evaluate_channel_surface_unbounded(surface, spend; action = action) for
            (surface, spend) in zip(channel_surfaces, current_spend)
    )

    return BudgetOptimizationProblem(
        results.metadata,
        results.spec,
        results.coordinate_metadata,
        objective_symbol,
        audit.total_budget,
        audit.optimized_channels,
        audit.fixed_channels,
        current_spend,
        fixed_spend,
        baseline_response,
        fixed_response,
        current_response,
        channel_surfaces,
        audit,
    )
end

"""
    _evaluate_budget_objective(problem, allocation)

Evaluate the bounded Phase 8 total-response objective at one fixed-budget
allocation over the optimized channel set.
"""
function _evaluate_budget_objective(
        problem::BudgetOptimizationProblem,
        allocation;
        action::AbstractString = "optimize_budget",
    )
    spend_allocation = _allocation_vector(problem, allocation; action)
    return problem.baseline_response +
        problem.fixed_response +
        sum(
        _evaluate_channel_surface(surface, spend; action) for
            (surface, spend) in zip(problem.channel_surfaces, spend_allocation)
    )
end

function _evaluate_budget_objective_gradient(
        problem::BudgetOptimizationProblem,
        allocation;
        action::AbstractString = "optimize_budget",
    )
    spend_allocation = _allocation_vector(problem, allocation; action)
    return [
        _evaluate_channel_surface_derivative(surface, spend; action) for
            (surface, spend) in zip(problem.channel_surfaces, spend_allocation)
    ]
end
