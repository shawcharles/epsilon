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

function _component_total_draws(values, indices::AbstractVector{<:Integer})
    ndraws = size(values, 1)
    totals = zeros(Float64, ndraws)
    isempty(indices) && return totals
    if ndims(values) == 3
        for draw in 1:ndraws
            totals[draw] = sum(view(values, draw, :, indices))
        end
    elseif ndims(values) == 4
        for draw in 1:ndraws
            totals[draw] = sum(view(values, draw, :, :, indices))
        end
    else
        throw(ArgumentError("budget allocation evaluation requires contribution values with observation axes"))
    end
    return totals
end

function _baseline_response_draws(results::InferenceResults, action::AbstractString)
    contributions = contribution_results(results)
    baseline_indices = Int[
        index for (index, kind) in enumerate(contributions.component_kinds) if kind != :media
    ]
    return _component_total_draws(contributions.values, baseline_indices)
end

function _observed_allocation_mapping(results::InferenceResults, action::AbstractString)
    data = results.spec.model_kind === :panel_mmm ?
        _require_postmodel_panel_results(results, action) :
        _require_postmodel_time_series_results(results, action)
    mapping = Dict{String, Float64}()
    for channel in results.spec.channel_columns
        mapping[channel] = _channel_total_spend(data, results.spec.channel_indices[channel])
    end
    return mapping
end

function _normalized_full_allocation_mapping(
        spec::MMMModelSpec,
        allocation::AbstractDict,
        action::AbstractString,
    )
    normalized = Dict{String, Any}()
    seen = Set{String}()
    for (channel, value) in pairs(allocation)
        normalized_channel = String(channel)
        normalized_channel in seen &&
            throw(
            ArgumentError(
                "$action requires allocation mappings to contain each channel at most once; duplicate channel `$normalized_channel` encountered",
            ),
        )
        push!(seen, normalized_channel)
        normalized[normalized_channel] = value
    end
    supplied = collect(keys(normalized))
    unknown = sort(setdiff(supplied, spec.channel_columns))
    isempty(unknown) ||
        throw(
        ArgumentError(
            "$action requires allocation channels drawn from `InferenceResults.spec.channel_columns`; unknown channels: $(join(unknown, ", "))",
        ),
    )
    missing = sort(setdiff(spec.channel_columns, supplied))
    isempty(missing) ||
        throw(
        ArgumentError(
            "$action requires allocations for exactly the fitted channel set; missing channels: $(join(missing, ", "))",
        ),
    )
    return Dict{String, Float64}(
        channel => _finite_spend_value(
                normalized[channel],
                action,
                "allocation for channel `$channel`",
            ) for channel in spec.channel_columns
    )
end

function _allocation_total_budget(
        allocation::AbstractDict{String, Float64},
        total_budget,
        action::AbstractString,
    )
    observed_total = sum(values(allocation))
    budget = isnothing(total_budget) ? observed_total :
        _finite_spend_value(total_budget, action, "total_budget")
    budget > 0.0 ||
        throw(ArgumentError("$action requires total_budget to be positive"))
    observed_total ≈ budget ||
        throw(ArgumentError("$action requires allocation spend to equal the fixed total_budget"))
    return Float64(budget)
end

function _allocation_default_efficiency(
        spec::MMMModelSpec,
        total_response::Real,
        total_budget::Real,
    )
    if lowercase(spec.target_type) == "conversion"
        return _safe_metric_ratio(total_budget, total_response)
    end
    return _safe_metric_ratio(total_response, total_budget)
end

function _allocation_kind(kind::Symbol)
    kind in (:current, :manual, :optimized) ||
        throw(ArgumentError("evaluate_budget_allocation supports allocation_kind values :current, :manual, and :optimized"))
    return kind
end

function _response_curve_draws_at_allocation(
        results::InferenceResults,
        channel::AbstractString,
        spend::Real,
        action::AbstractString,
    )
    spend_value = _finite_spend_value(spend, action, "allocation for channel `$channel`")
    if results.spec.model_kind === :panel_mmm
        observed = _channel_total_spend(
            _require_postmodel_panel_results(results, action),
            results.spec.channel_indices[channel],
        )
        delta = spend_value / _positive_observed_panel_spend(observed, channel, action)
        curves = response_curve_results(results; channel, delta_grid = [delta])
        values = curves.values
        ndims(values) == 3 ||
            throw(ArgumentError("$action requires panel response-curve draws with draw, panel, and spend axes"))
        return Float64[sum(view(values, draw, :, 1)) for draw in axes(values, 1)]
    end

    curves = response_curve_results(results; channel, grid = [spend_value])
    values = curves.values
    ndims(values) == 2 ||
        throw(ArgumentError("$action requires time-series response-curve draws with draw and spend axes"))
    return Float64.(vec(values[:, 1]))
end

function _allocation_response_draws(
        results::InferenceResults,
        allocation::AbstractDict{String, Float64},
        action::AbstractString,
    )
    draws = _baseline_response_draws(results, action)
    for channel in results.spec.channel_columns
        draws .+= _response_curve_draws_at_allocation(
            results,
            channel,
            allocation[channel],
            action,
        )
    end
    return draws
end

function _evaluate_budget_allocation(
        results::InferenceResults,
        allocation::AbstractDict{String, Float64};
        allocation_kind::Symbol,
        total_budget,
        objective,
        action::AbstractString,
    )
    objective_symbol = objective isa Symbol ? objective : Symbol(lowercase(String(objective)))
    objective_symbol === :total_response ||
        throw(
        ArgumentError(
            "$action currently supports only `objective = :total_response`",
        ),
    )
    kind = _allocation_kind(allocation_kind)
    budget = _allocation_total_budget(allocation, total_budget, action)
    response_draws = _allocation_response_draws(results, allocation, action)
    expected_response = Float64(mean(response_draws))
    return BudgetAllocationEvaluationResult(
        results.metadata,
        results.spec,
        results.coordinate_metadata,
        objective_symbol,
        kind,
        copy(allocation),
        budget,
        response_draws,
        expected_response,
        _allocation_default_efficiency(results.spec, expected_response, budget),
    )
end

"""
    evaluate_budget_allocation(results, allocation=:current; total_budget=nothing, objective=:total_response, panel_allocation_mode=:historical_shares)
    evaluate_budget_allocation(results, result; allocation=:optimized, total_budget=nothing, objective=:total_response)

Evaluate one supplied channel allocation against posterior response draws.

`allocation` may be `:current`, a full channel-spend dictionary, or an existing
`BudgetOptimizationResult`/`PanelBudgetOptimizationResult`. Dictionary
allocations must provide exactly the fitted channel set, use nonnegative finite
spend in the fitted data's original units, and match `total_budget` when that
keyword is supplied. Result allocations are hard-checked against the supplied
`InferenceResults` metadata, model spec, and coordinate metadata.

This function does not solve an optimization problem, refit the model, or
simulate a future spend path. Panel evaluation is limited to historical-share
semantics.
"""
function evaluate_budget_allocation(
        results::InferenceResults,
        allocation = :current;
        total_budget = nothing,
        objective = :total_response,
        panel_allocation_mode = :historical_shares,
        panel_bounds = nothing,
        panel_total_bounds = nothing,
        channel_panel_bounds = nothing,
    )
    action = "evaluate_budget_allocation"
    if results.spec.model_kind === :panel_mmm
        _normalize_panel_allocation_mode(panel_allocation_mode, action)
        _reject_deferred_panel_optimization_kwargs(
            action;
            panel_bounds,
            panel_total_bounds,
            channel_panel_bounds,
        )
    else
        _reject_time_series_panel_optimization_kwargs(
            action;
            panel_allocation_mode,
            panel_bounds,
            panel_total_bounds,
            channel_panel_bounds,
        )
    end

    if allocation === :current
        current = _observed_allocation_mapping(results, action)
        return _evaluate_budget_allocation(
            results,
            current;
            allocation_kind = :current,
            total_budget,
            objective,
            action,
        )
    end
    allocation isa AbstractDict ||
        throw(ArgumentError("$action allocation must be `:current`, a full channel-spend dictionary, or a solved budget optimization result"))
    manual = _normalized_full_allocation_mapping(results.spec, allocation, action)
    return _evaluate_budget_allocation(
        results,
        manual;
        allocation_kind = :manual,
        total_budget,
        objective,
        action,
    )
end

function _validate_allocation_result_compatible(
        results::InferenceResults,
        result::Union{BudgetOptimizationResult, PanelBudgetOptimizationResult},
        action::AbstractString,
    )
    result.metadata == results.metadata ||
        throw(ArgumentError("$action requires optimization result metadata to match `results`"))
    result.spec == results.spec ||
        throw(ArgumentError("$action requires optimization result model spec to match `results`"))
    result.coordinate_metadata == results.coordinate_metadata ||
        throw(ArgumentError("$action requires optimization result coordinate metadata to match `results`"))
    return nothing
end

function evaluate_budget_allocation(
        results::InferenceResults,
        result::Union{BudgetOptimizationResult, PanelBudgetOptimizationResult};
        allocation = :optimized,
        total_budget = nothing,
        objective = result.objective,
        panel_allocation_mode = :historical_shares,
        panel_bounds = nothing,
        panel_total_bounds = nothing,
        channel_panel_bounds = nothing,
    )
    action = "evaluate_budget_allocation"
    _validate_allocation_result_compatible(results, result, action)
    if results.spec.model_kind === :panel_mmm
        result isa PanelBudgetOptimizationResult ||
            throw(ArgumentError("$action requires a panel optimization result for panel `InferenceResults`"))
        _normalize_panel_allocation_mode(panel_allocation_mode, action)
        _reject_deferred_panel_optimization_kwargs(
            action;
            panel_bounds,
            panel_total_bounds,
            channel_panel_bounds,
        )
    else
        result isa BudgetOptimizationResult ||
            throw(ArgumentError("$action requires a time-series optimization result for time-series `InferenceResults`"))
        _reject_time_series_panel_optimization_kwargs(
            action;
            panel_allocation_mode,
            panel_bounds,
            panel_total_bounds,
            channel_panel_bounds,
        )
    end
    kind = allocation isa Symbol ? allocation : Symbol(lowercase(String(allocation)))
    mapping = if kind === :current
        result.current_spend
    elseif kind === :optimized
        result.optimized_spend
    else
        throw(ArgumentError("$action result allocation must be `:current` or `:optimized`"))
    end
    normalized = _normalized_full_allocation_mapping(results.spec, mapping, action)
    budget = isnothing(total_budget) ? sum(values(normalized)) : total_budget
    return _evaluate_budget_allocation(
        results,
        normalized;
        allocation_kind = kind,
        total_budget = budget,
        objective,
        action,
    )
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

function _evaluate_channel_surface_derivative_unbounded(
        surface::BudgetChannelSurface,
        spend::Real;
        action::AbstractString = "optimize_budget",
    )
    spend_value = _finite_spend_value(spend, action, "channel spend")
    return _evaluate_derivative(_surface_interpolation(surface, action), spend_value)
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

Assemble the solver-agnostic bounded optimization problem from grouped
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
            "$action currently supports only `objective = :total_response` in the bounded optimization surface",
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

Evaluate the bounded total-response objective at one fixed-budget
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
