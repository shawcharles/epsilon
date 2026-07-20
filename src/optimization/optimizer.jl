using JuMP
import Ipopt

function _solver_status_symbol(status)
    normalized = replace(lowercase(string(status)), r"[^a-z0-9]+" => "_")
    return Symbol(strip(normalized, '_'))
end

function _register_channel_operator!(
        model::JuMP.Model,
        surface::BudgetChannelSurface,
        index::Integer,
    )
    operator_name = Symbol("budget_response_$(index)")
    interpolation = _surface_interpolation(surface, "optimize_budget")
    evaluate(x::Real) = Float64(_evaluate(interpolation, Float64(x)))
    gradient(x::Real) = Float64(_evaluate_derivative(interpolation, Float64(x)))
    hessian(x::Real) = Float64(_evaluate_second_derivative(interpolation, Float64(x)))
    return JuMP.add_nonlinear_operator(
        model,
        1,
        evaluate,
        gradient,
        hessian;
        name = operator_name,
    )
end

function _objective_expression(
        problem::BudgetOptimizationProblem,
        allocation::AbstractVector,
        operators::AbstractVector,
    )
    expression = problem.baseline_response + problem.fixed_response
    for index in eachindex(operators)
        expression += operators[index](allocation[index])
    end
    return expression
end

function _clamped_current_spend(constraint::BudgetChannelConstraint)
    current = max(constraint.observed_spend, constraint.effective_lower)
    return isnothing(constraint.effective_upper) ? current :
        min(current, Float64(constraint.effective_upper))
end

function _feasible_initial_allocation(problem::BudgetOptimizationProblem)
    constraints = problem.constraint_audit.channel_constraints
    allocation = Float64[constraint.effective_lower for constraint in constraints]
    remaining_budget = problem.total_budget - sum(allocation)
    tolerance = sqrt(eps(Float64))

    remaining_budget < -tolerance &&
        throw(ArgumentError("optimize_budget requires a feasible initial allocation"))

    clamped_current = [_clamped_current_spend(constraint) for constraint in constraints]
    for index in eachindex(allocation)
        remaining_budget <= tolerance && break
        increment = min(clamped_current[index] - allocation[index], remaining_budget)
        increment <= 0.0 && continue
        allocation[index] += increment
        remaining_budget -= increment
    end

    for index in eachindex(allocation)
        remaining_budget <= tolerance && break
        upper = constraints[index].effective_upper
        slack = isnothing(upper) ? remaining_budget : Float64(upper) - allocation[index]
        slack <= tolerance && continue
        increment = min(slack, remaining_budget)
        allocation[index] += increment
        remaining_budget -= increment
    end

    if !isempty(allocation) && !iszero(remaining_budget)
        for index in reverse(eachindex(allocation))
            lower = constraints[index].effective_lower
            upper = constraints[index].effective_upper
            candidate = allocation[index] + remaining_budget
            if candidate < lower || (!isnothing(upper) && candidate > Float64(upper))
                continue
            end
            allocation[index] = candidate
            remaining_budget = 0.0
            break
        end
    end
    abs(remaining_budget) <= tolerance ||
        throw(ArgumentError("optimize_budget requires a feasible initial allocation"))
    return allocation
end

function _build_optimizer_model(problem::BudgetOptimizationProblem)
    model = JuMP.Model(Ipopt.Optimizer)
    JuMP.set_silent(model)
    JuMP.set_attribute(model, "print_level", 0)

    nchannels = length(problem.channel_surfaces)
    allocation = JuMP.@variable(model, allocation[1:nchannels])
    for (index, constraint) in enumerate(problem.constraint_audit.channel_constraints)
        JuMP.set_lower_bound(allocation[index], constraint.effective_lower)
        if !isnothing(constraint.effective_upper)
            JuMP.set_upper_bound(allocation[index], Float64(constraint.effective_upper))
        end
    end

    initial_allocation = _feasible_initial_allocation(problem)
    for (index, value) in enumerate(initial_allocation)
        JuMP.set_start_value(allocation[index], value)
    end

    JuMP.@constraint(model, sum(allocation) == problem.total_budget)
    operators = [
        _register_channel_operator!(model, surface, index) for
            (index, surface) in enumerate(problem.channel_surfaces)
    ]
    objective = _objective_expression(problem, allocation, operators)
    JuMP.@objective(model, Max, objective)
    return model, allocation
end

function _spend_mapping(
        problem::BudgetOptimizationProblem,
        optimized_spend::AbstractVector,
    )
    optimized_lookup = Dict(
        channel => Float64(spend) for
            (channel, spend) in zip(problem.optimized_channels, optimized_spend)
    )
    fixed_lookup = Dict(
        channel => Float64(spend) for
            (channel, spend) in zip(problem.fixed_channels, problem.fixed_spend)
    )
    mapping = Dict{String, Float64}()
    for channel in problem.spec.channel_columns
        mapping[channel] = if haskey(optimized_lookup, channel)
            optimized_lookup[channel]
        else
            fixed_lookup[channel]
        end
    end
    return mapping
end

function _bound_projection_tolerance()
    return 1.0e-6
end

function _rebalance_projected_allocation!(
        projected::AbstractVector{Float64},
        constraints::AbstractVector{BudgetChannelConstraint},
        residual::Real,
        tolerance::Real,
    )
    remaining = Float64(residual)
    if remaining > tolerance
        for index in reverse(eachindex(projected))
            upper = constraints[index].effective_upper
            slack = isnothing(upper) ? remaining : Float64(upper) - projected[index]
            slack <= tolerance && continue
            increment = min(slack, remaining)
            projected[index] += increment
            remaining -= increment
            remaining <= tolerance && break
        end
    elseif remaining < -tolerance
        for index in reverse(eachindex(projected))
            slack = projected[index] - constraints[index].effective_lower
            slack <= tolerance && continue
            decrement = min(slack, -remaining)
            projected[index] -= decrement
            remaining += decrement
            remaining >= -tolerance && break
        end
    end
    return remaining
end

function _apply_exact_projection_residual!(
        projected::AbstractVector{Float64},
        constraints::AbstractVector{BudgetChannelConstraint},
        residual::Real,
        tolerance::Real,
    )
    remaining = Float64(residual)
    iszero(remaining) && return remaining

    for index in reverse(eachindex(projected))
        lower = constraints[index].effective_lower
        upper = constraints[index].effective_upper
        candidate = projected[index] + remaining
        if candidate < lower - tolerance
            continue
        end
        if !isnothing(upper) && candidate > Float64(upper) + tolerance
            continue
        end
        projected[index] = clamp(candidate, lower, something(upper, candidate))
        return 0.0
    end

    return remaining
end

function _project_to_constraint_bounds(
        allocation::AbstractVector{<:Real},
        constraints::AbstractVector{BudgetChannelConstraint},
        total_budget::Real,
    )
    # Projection is post-solve hygiene, not a second optimizer. The 1e-6
    # tolerance snaps near-bound solver drift and accepts only the final
    # leftover residual; any larger residual is rebalanced solely through valid
    # effective-bound slack or fails closed.
    projected = Float64.(collect(allocation))
    tolerance = _bound_projection_tolerance()

    for index in eachindex(projected)
        lower = constraints[index].effective_lower
        upper = constraints[index].effective_upper
        if abs(projected[index] - lower) <= tolerance
            projected[index] = lower
        end
        if !isnothing(upper) && abs(projected[index] - Float64(upper)) <= tolerance
            projected[index] = Float64(upper)
        end
    end

    residual = Float64(total_budget) - sum(projected)
    remaining = _rebalance_projected_allocation!(projected, constraints, residual, tolerance)
    if !iszero(remaining)
        remaining = _apply_exact_projection_residual!(
            projected,
            constraints,
            remaining,
            tolerance,
        )
    end
    abs(remaining) <= tolerance ||
        throw(
        ErrorException(
            "optimize_budget could not preserve the fixed total-budget equality after bound projection",
        ),
    )
    return projected
end

function _default_efficiency(
        problem::BudgetOptimizationProblem,
        total_response::Real,
        spend_mapping::AbstractDict{String, Float64},
    )
    total_spend = sum(values(spend_mapping))
    if lowercase(problem.spec.target_type) == "conversion"
        return _safe_metric_ratio(total_spend, total_response)
    end
    return _safe_metric_ratio(total_response, total_spend)
end

function _convergence_metadata(model::JuMP.Model)
    metadata = Dict{String, Any}()
    metadata["termination_status"] = string(JuMP.termination_status(model))
    metadata["primal_status"] = string(JuMP.primal_status(model))
    metadata["dual_status"] = string(JuMP.dual_status(model))
    metadata["raw_status"] = JuMP.raw_status(model)
    metadata["result_count"] = JuMP.result_count(model)
    metadata["solve_time_sec"] = JuMP.solve_time(model)
    return metadata
end

function _solve_budget_optimization_problem(problem::BudgetOptimizationProblem)
    model, allocation = _build_optimizer_model(problem)
    JuMP.optimize!(model)

    JuMP.is_solved_and_feasible(model; allow_local = true) ||
        throw(
        ErrorException(
            "optimize_budget failed to produce a feasible solution ($(JuMP.termination_status(model)))",
        ),
    )

    optimized_allocation = _project_to_constraint_bounds(
        JuMP.value.(allocation),
        problem.constraint_audit.channel_constraints,
        problem.total_budget,
    )
    current_spend = _spend_mapping(problem, problem.current_spend)
    optimized_spend = _spend_mapping(problem, optimized_allocation)
    optimized_response = _evaluate_budget_objective(problem, optimized_allocation)

    return BudgetOptimizationResult(
        problem.metadata,
        problem.spec,
        problem.coordinate_metadata,
        problem.objective,
        copy(problem.optimized_channels),
        copy(problem.fixed_channels),
        current_spend,
        optimized_spend,
        problem.current_response,
        optimized_response,
        _default_efficiency(problem, problem.current_response, current_spend),
        _default_efficiency(problem, optimized_response, optimized_spend),
        _solver_status_symbol(JuMP.termination_status(model)),
        optimized_response,
        _convergence_metadata(model),
        problem.constraint_audit,
    )
end

"""
    optimize_budget(results::InferenceResults; total_budget, channels=nothing, budget_bounds=nothing, relative_bounds=nothing, objective=:total_response, grid=nothing, panel_allocation_mode=:historical_shares)

Run the bounded fixed-budget optimizer on one supported grouped
`InferenceResults` artifact.

For time-series results, spend is allocated directly across channels. For panel
results, v1 optimization allocates channel totals and preserves historical
within-channel panel-cell spend shares (`panel_allocation_mode =
:historical_shares`). Free channel-by-panel allocation, panel-total bounds, and
channel-panel bounds are intentionally deferred because Stage 60 panel response
curves are defined by a shared historical spend delta within each channel.

Supported constraints are the fixed total-budget equality, optional per-channel
absolute bounds, optional observed-relative guardrails, and optional channel
subset selection with unselected channels held fixed at observed spend.

`total_budget`, observed spend, explicit bounds, and response-curve spend grids
must all use the same original input units as the channel columns supplied to
`MMMData` or `PanelMMMData`. Epsilon does not convert currencies, time
aggregation levels, or thousands/millions scaling at the optimizer boundary.

The nonlinear solve accepts locally feasible optima from Ipopt; response curves
are smooth interpolations of posterior-mean grids, not a proof of global
concavity.
"""
function optimize_budget(
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
    if results.spec.model_kind === :panel_mmm
        return _optimize_panel_budget(
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
    end

    _reject_time_series_panel_optimization_kwargs(
        "optimize_budget";
        panel_allocation_mode,
        panel_bounds,
        panel_total_bounds,
        channel_panel_bounds,
    )
    problem = _build_budget_optimization_problem(
        results;
        total_budget,
        channels,
        budget_bounds,
        relative_bounds,
        objective,
        grid,
    )
    return _solve_budget_optimization_problem(problem)
end
