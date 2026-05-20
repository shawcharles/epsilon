using Statistics

function _normalize_panel_allocation_mode(mode, action::AbstractString)
    symbol = mode isa Symbol ? mode : Symbol(lowercase(String(mode)))
    symbol === :historical_shares ||
        throw(
        ArgumentError(
            "$action currently supports only `panel_allocation_mode = :historical_shares`; free channel-by-panel allocation is deferred until panel response-curve validity is explicitly modeled",
        ),
    )
    return symbol
end

function _reject_deferred_panel_optimization_kwargs(
        action::AbstractString;
        panel_bounds = nothing,
        panel_total_bounds = nothing,
        channel_panel_bounds = nothing,
    )
    isnothing(panel_bounds) ||
        throw(
        ArgumentError(
            "$action does not yet support `panel_bounds`; v1 panel optimization preserves historical within-channel panel shares",
        ),
    )
    isnothing(panel_total_bounds) ||
        throw(
        ArgumentError(
            "$action does not yet support `panel_total_bounds`; v1 panel optimization preserves historical within-channel panel shares",
        ),
    )
    isnothing(channel_panel_bounds) ||
        throw(
        ArgumentError(
            "$action does not yet support `channel_panel_bounds`; v1 panel optimization preserves historical within-channel panel shares",
        ),
    )
    return nothing
end

function _reject_time_series_panel_optimization_kwargs(
        action::AbstractString;
        panel_allocation_mode = :historical_shares,
        panel_bounds = nothing,
        panel_total_bounds = nothing,
        channel_panel_bounds = nothing,
    )
    _normalize_panel_allocation_mode(panel_allocation_mode, action)
    _reject_deferred_panel_optimization_kwargs(
        action;
        panel_bounds,
        panel_total_bounds,
        channel_panel_bounds,
    )
    return nothing
end

function _positive_observed_panel_spend(observed_spend::Real, channel::AbstractString, action::AbstractString)
    spend = Float64(observed_spend)
    spend > sqrt(eps(Float64)) ||
        throw(
        ArgumentError(
            "$action requires positive observed spend for panel channel `$channel` because historical-share optimization evaluates response curves with spend deltas",
        ),
    )
    return spend
end

function _panel_delta_grid_from_spend_grid(
        spend_grid::AbstractVector{<:Real},
        observed_spend::Real,
        channel::AbstractString,
        action::AbstractString,
    )
    spend = _positive_observed_panel_spend(observed_spend, channel, action)
    delta_grid = Float64.(spend_grid) ./ spend
    all(isfinite, delta_grid) ||
        throw(ArgumentError("$action requires finite panel delta-grid values for channel `$channel`"))
    return delta_grid
end

function _panel_summed_response_grid(curves::ResponseCurveResults, action::AbstractString)
    values = curves.values
    ndims(values) == 3 ||
        throw(ArgumentError("$action requires panel response curves with draw, panel, and grid axes"))
    npoints = size(values, 3)
    response_grid = Vector{Float64}(undef, npoints)
    for point in 1:npoints
        response_grid[point] = mean(sum(view(values, :, :, point); dims = 2))
    end
    return response_grid
end

function _panel_component_total_mean(values, indices::AbstractVector{<:Integer})
    isempty(indices) && return 0.0
    ndraws = size(values, 1)
    totals = Vector{Float64}(undef, ndraws)
    if ndims(values) == 4
        for draw in 1:ndraws
            totals[draw] = sum(view(values, draw, :, :, indices))
        end
    elseif ndims(values) == 3
        for draw in 1:ndraws
            totals[draw] = sum(view(values, draw, :, indices))
        end
    else
        throw(ArgumentError("panel optimization requires contribution values with time and panel axes"))
    end
    return Float64(mean(totals))
end

function _panel_baseline_and_fixed_response(
        results::InferenceResults,
        optimized_channels::AbstractVector{<:AbstractString},
    )
    contributions = contribution_results(results)
    optimized_media_names = Set("media:$(channel)" for channel in optimized_channels)
    baseline_indices = Int[]
    fixed_media_indices = Int[]

    for (index, kind) in enumerate(contributions.component_kinds)
        if kind == :media
            contributions.component_names[index] in optimized_media_names ||
                push!(fixed_media_indices, index)
        else
            push!(baseline_indices, index)
        end
    end

    values = contributions.values
    return (
        _panel_component_total_mean(values, baseline_indices),
        _panel_component_total_mean(values, fixed_media_indices),
    )
end

function _build_panel_budget_optimization_problem(
        results::InferenceResults;
        total_budget,
        channels = nothing,
        budget_bounds = nothing,
        relative_bounds = nothing,
        objective = :total_response,
        grid = nothing,
        panel_allocation_mode = :historical_shares,
        panel_bounds = nothing,
        panel_total_bounds = nothing,
        channel_panel_bounds = nothing,
    )
    action = "optimize_budget"
    data = _require_postmodel_panel_results(results, action)
    _normalize_panel_allocation_mode(panel_allocation_mode, action)
    _reject_deferred_panel_optimization_kwargs(
        action;
        panel_bounds,
        panel_total_bounds,
        channel_panel_bounds,
    )
    objective_symbol = objective isa Symbol ? objective : Symbol(lowercase(String(objective)))
    objective_symbol === :total_response ||
        throw(
        ArgumentError(
            "$action currently supports only `objective = :total_response` in the bounded panel optimization surface",
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
        spend_grid = if isnothing(custom_grids)
            _default_spend_grid(
                constraint.observed_spend,
                audit.total_budget;
                effective_lower = constraint.effective_lower,
                effective_upper = constraint.effective_upper,
            )
        else
            _normalized_custom_grid(
                custom_grids[constraint.channel],
                constraint,
                audit.total_budget,
                action,
            )
        end
        delta_grid = _panel_delta_grid_from_spend_grid(
            spend_grid,
            constraint.observed_spend,
            constraint.channel,
            action,
        )
        curves = response_curve_results(
            results;
            channel = constraint.channel,
            delta_grid,
        )
        response_grid = _panel_summed_response_grid(curves, action)
        _ = _monotone_cubic_interpolation(spend_grid, response_grid, action)
        push!(
            channel_surfaces,
            BudgetChannelSurface(
                constraint.channel,
                constraint.observed_spend,
                spend_grid,
                response_grid,
                constraint.effective_lower,
                constraint.effective_upper,
            ),
        )
        push!(current_spend, constraint.observed_spend)
    end

    fixed_spend = Float64[
        _channel_total_spend(data, results.spec.channel_indices[channel]) for
            channel in audit.fixed_channels
    ]
    baseline_response, fixed_response = _panel_baseline_and_fixed_response(
        results,
        audit.optimized_channels,
    )
    current_response = baseline_response +
        fixed_response +
        sum(
        _evaluate_channel_surface_unbounded(surface, spend; action) for
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

function _channel_panel_spend_matrix(data::PanelMMMData, spec::MMMModelSpec)
    nchannels = length(spec.channel_columns)
    npanels = length(data.panel_names)
    matrix = zeros(Float64, nchannels, npanels)
    for (channel_index, channel) in enumerate(spec.channel_columns)
        data_index = spec.channel_indices[channel]
        for panel_index in 1:npanels
            matrix[channel_index, panel_index] = sum(
                Float64.(view(data.channels, :, data_index, panel_index)),
            )
        end
    end
    return matrix
end

function _historical_panel_shares(current_channel_panel_spend::AbstractMatrix{<:Real})
    shares = zeros(Float64, size(current_channel_panel_spend))
    for channel_index in axes(current_channel_panel_spend, 1)
        total = sum(view(current_channel_panel_spend, channel_index, :))
        if total > sqrt(eps(Float64))
            shares[channel_index, :] .= view(current_channel_panel_spend, channel_index, :) ./ total
        end
    end
    return shares
end

function _panel_channel_response_at_delta(
        results::InferenceResults,
        channel::AbstractString,
        delta::Real,
    )
    curves = response_curve_results(results; channel, delta_grid = [Float64(delta)])
    values = curves.values
    return Float64[mean(view(values, :, panel_index, 1)) for panel_index in axes(values, 2)]
end

function _panel_channel_response_matrix(
        results::InferenceResults,
        spend::AbstractDict{String, Float64},
    )
    data = _require_postmodel_panel_results(results, "optimize_budget")
    matrix = zeros(Float64, length(results.spec.channel_columns), length(data.panel_names))
    for (channel_index, channel) in enumerate(results.spec.channel_columns)
        observed = _channel_total_spend(data, results.spec.channel_indices[channel])
        delta = _positive_observed_panel_spend(observed, channel, "optimize_budget")
        matrix[channel_index, :] .= _panel_channel_response_at_delta(
            results,
            channel,
            spend[channel] / delta,
        )
    end
    return matrix
end

function _panel_budget_optimization_result(
        result::BudgetOptimizationResult,
        results::InferenceResults,
    )
    data = _require_postmodel_panel_results(results, "optimize_budget")
    current_channel_panel_spend = _channel_panel_spend_matrix(data, results.spec)
    shares = _historical_panel_shares(current_channel_panel_spend)
    optimized_channel_panel_spend = zeros(Float64, size(current_channel_panel_spend))
    for (channel_index, channel) in enumerate(results.spec.channel_columns)
        optimized_channel_panel_spend[channel_index, :] .=
            shares[channel_index, :] .* result.optimized_spend[channel]
    end
    channel_delta = Dict{String, Float64}()
    for channel in results.spec.channel_columns
        observed = result.current_spend[channel]
        channel_delta[channel] = result.optimized_spend[channel] /
            _positive_observed_panel_spend(observed, channel, "optimize_budget")
    end

    return PanelBudgetOptimizationResult(
        result.metadata,
        result.spec,
        result.coordinate_metadata,
        result.objective,
        result.optimized_channels,
        result.fixed_channels,
        result.current_spend,
        result.optimized_spend,
        result.current_response,
        result.optimized_response,
        result.current_default_efficiency,
        result.optimized_default_efficiency,
        result.solver_status,
        result.objective_value,
        result.convergence_metadata,
        result.constraint_audit,
        :historical_shares,
        copy(data.panel_names),
        copy(data.panel_coordinates),
        shares,
        current_channel_panel_spend,
        optimized_channel_panel_spend,
        _panel_channel_response_matrix(results, result.current_spend),
        _panel_channel_response_matrix(results, result.optimized_spend),
        channel_delta,
    )
end

function _optimize_panel_budget(
        results::InferenceResults;
        total_budget,
        channels = nothing,
        budget_bounds = nothing,
        relative_bounds = nothing,
        objective = :total_response,
        grid = nothing,
        panel_allocation_mode = :historical_shares,
        panel_bounds = nothing,
        panel_total_bounds = nothing,
        channel_panel_bounds = nothing,
    )
    problem = _build_panel_budget_optimization_problem(
        results;
        total_budget,
        channels,
        budget_bounds,
        relative_bounds,
        objective,
        grid,
        panel_allocation_mode,
        panel_bounds,
        panel_total_bounds,
        channel_panel_bounds,
    )
    result = _solve_budget_optimization_problem(problem)
    return _panel_budget_optimization_result(result, results)
end
