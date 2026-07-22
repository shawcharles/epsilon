using DataFrames
using Statistics

function _channel_constraint_lookup(audit::BudgetConstraintAudit)
    return Dict(constraint.channel => constraint for constraint in audit.channel_constraints)
end

const _BudgetOptimizationResultLike = Union{BudgetOptimizationResult, PanelBudgetOptimizationResult}

function _optimized_subset_total_spend(result::_BudgetOptimizationResultLike)
    return sum(result.current_spend[channel] for channel in result.optimized_channels),
        sum(result.optimized_spend[channel] for channel in result.optimized_channels)
end

function _optimization_bound_flags(
        constraint::Union{Nothing, BudgetChannelConstraint},
        optimized_spend::Real,
    )
    isnothing(constraint) && return (false, false)
    tolerance = _bound_projection_tolerance()
    lower_active = abs(Float64(optimized_spend) - constraint.effective_lower) <= tolerance
    upper_active = !isnothing(constraint.effective_upper) &&
        abs(Float64(optimized_spend) - Float64(constraint.effective_upper)) <= tolerance
    return lower_active, upper_active
end

function _marginal_response_lookup(
        result::_BudgetOptimizationResultLike,
        metadata_key::AbstractString,
    )
    raw = get(result.convergence_metadata, String(metadata_key), nothing)
    values = Dict{String, Float64}()
    raw isa AbstractDict || return values
    for (channel, value) in pairs(raw)
        values[String(channel)] = Float64(value)
    end
    return values
end

function _channel_marginal_response(
        lookup::AbstractDict{String, Float64},
        channel::AbstractString,
    )
    return get(lookup, String(channel), NaN)
end

function _is_conversion_target(result::_BudgetOptimizationResultLike)
    return lowercase(result.spec.target_type) == "conversion"
end

function _marginal_roas(result::_BudgetOptimizationResultLike, marginal_response::Real)
    _is_conversion_target(result) && return NaN
    return Float64(marginal_response)
end

function _marginal_cpa(result::_BudgetOptimizationResultLike, marginal_response::Real)
    _is_conversion_target(result) || return NaN
    return _safe_metric_ratio(1.0, marginal_response)
end

function _validate_decision_interval_probability(interval_probability)
    probability = Float64(interval_probability)
    isfinite(probability) && 0.0 < probability < 1.0 ||
        throw(ArgumentError("budget allocation decision summaries require interval_probability in (0, 1)"))
    return probability
end

function _validate_budget_allocation_decision_inputs(
        reference::BudgetAllocationEvaluationResult,
        candidate::BudgetAllocationEvaluationResult,
        action::AbstractString,
    )
    reference.metadata == candidate.metadata ||
        throw(ArgumentError("$action requires matching allocation-evaluation metadata"))
    reference.spec == candidate.spec ||
        throw(ArgumentError("$action requires matching allocation-evaluation model specs"))
    reference.coordinate_metadata == candidate.coordinate_metadata ||
        throw(ArgumentError("$action requires matching allocation-evaluation coordinate metadata"))
    reference.objective == candidate.objective ||
        throw(ArgumentError("$action requires matching allocation-evaluation objectives"))
    isempty(reference.response_draws) &&
        throw(ArgumentError("$action requires nonempty reference response draws"))
    isempty(candidate.response_draws) &&
        throw(ArgumentError("$action requires nonempty candidate response draws"))
    length(reference.response_draws) == length(candidate.response_draws) ||
        throw(ArgumentError("$action requires reference and candidate response draws with matching length"))
    all(isfinite, reference.response_draws) ||
        throw(ArgumentError("$action requires finite reference response draws"))
    all(isfinite, candidate.response_draws) ||
        throw(ArgumentError("$action requires finite candidate response draws"))
    return nothing
end

function _decision_interval_bounds(values::AbstractVector{<:Real}, interval_probability::Real)
    alpha = (1.0 - Float64(interval_probability)) / 2.0
    return Float64(quantile(values, alpha)),
        Float64(quantile(values, 1.0 - alpha))
end

function _decision_std(values::AbstractVector{<:Real})
    length(values) <= 1 && return 0.0
    return Float64(std(values))
end

function _decision_draw_summary(values::AbstractVector{<:Real}, interval_probability::Real)
    lower, upper = _decision_interval_bounds(values, interval_probability)
    return (
        mean = Float64(mean(values)),
        median = Float64(median(values)),
        std = _decision_std(values),
        lower = lower,
        upper = upper,
    )
end

function _validated_utility_draws(draws::AbstractVector, action::AbstractString, label::AbstractString)
    isempty(draws) && throw(ArgumentError("$action requires nonempty $label"))
    values = try
        Float64.(collect(draws))
    catch
        throw(ArgumentError("$action requires numeric $label"))
    end
    all(isfinite, values) || throw(ArgumentError("$action requires finite $label"))
    return values
end

function _validated_reference_draws(
        response_draws::AbstractVector{Float64},
        reference_draws,
        action::AbstractString,
    )
    isnothing(reference_draws) &&
        throw(ArgumentError("$action utility :probability_of_improvement requires reference_draws"))
    reference_values = _validated_utility_draws(
        reference_draws,
        action,
        "reference response draws",
    )
    length(reference_values) == length(response_draws) ||
        throw(ArgumentError("$action requires response_draws and reference_draws with matching length"))
    return reference_values
end

function _lower_interval_probability(spec::BudgetUtilitySpec)
    return (1.0 - spec.interval_probability) / 2.0
end

"""
    budget_utility_value(response_draws; utility=:mean_response, reference_draws=nothing, interval_probability=0.9, risk_aversion=1.0)
    budget_utility_value(response_draws, spec::BudgetUtilitySpec; reference_draws=nothing)
    budget_utility_value(candidate::BudgetAllocationEvaluationResult, spec=BudgetUtilitySpec(); reference=nothing)

Evaluate a supported budget utility over posterior total-response draws.

This is a pure decision helper. It does not solve an optimisation problem and
does not refit the model. `:probability_of_improvement` requires paired
reference draws.
"""
function budget_utility_value(
        response_draws::AbstractVector;
        utility = :mean_response,
        reference_draws = nothing,
        interval_probability = 0.9,
        risk_aversion = 1.0,
    )
    return budget_utility_value(
        response_draws,
        BudgetUtilitySpec(
            utility;
            interval_probability,
            risk_aversion,
        );
        reference_draws,
    )
end

function budget_utility_value(
        response_draws::AbstractVector,
        spec::BudgetUtilitySpec;
        reference_draws = nothing,
    )
    action = "budget_utility_value"
    values = _validated_utility_draws(response_draws, action, "response draws")
    if spec.utility === :mean_response
        return Float64(mean(values))
    elseif spec.utility === :lower_interval_response
        return Float64(quantile(values, _lower_interval_probability(spec)))
    elseif spec.utility === :probability_of_improvement
        reference_values = _validated_reference_draws(values, reference_draws, action)
        return Float64(mean(values .> reference_values))
    elseif spec.utility === :risk_adjusted_response
        return Float64(mean(values) - (spec.risk_aversion * _decision_std(values)))
    end
    throw(ArgumentError("unsupported budget utility `$(spec.utility)`"))
end

function budget_utility_value(
        candidate::BudgetAllocationEvaluationResult,
        spec::BudgetUtilitySpec;
        reference = nothing,
    )
    reference_draws = nothing
    if !isnothing(reference)
        reference isa BudgetAllocationEvaluationResult ||
            throw(ArgumentError("budget_utility_value reference must be a BudgetAllocationEvaluationResult"))
        _validate_budget_allocation_decision_inputs(reference, candidate, "budget_utility_value")
        reference_draws = reference.response_draws
    end
    return budget_utility_value(
        candidate.response_draws,
        spec;
        reference_draws,
    )
end

function budget_utility_value(
        candidate::BudgetAllocationEvaluationResult;
        utility = :mean_response,
        reference = nothing,
        interval_probability = 0.9,
        risk_aversion = 1.0,
    )
    return budget_utility_value(
        candidate,
        BudgetUtilitySpec(
            utility;
            interval_probability,
            risk_aversion,
        );
        reference,
    )
end

function _uplift_pct_draws(
        candidate::BudgetAllocationEvaluationResult,
        reference::BudgetAllocationEvaluationResult,
    )
    return Float64[
        _safe_metric_ratio(
                candidate.response_draws[index] - reference.response_draws[index],
                reference.response_draws[index],
            ) for index in eachindex(reference.response_draws)
    ]
end

"""
    budget_allocation_decision_summary(reference, candidate; interval_probability=0.9)

Summarise one evaluated allocation against a reference allocation using paired
posterior total-response draws.

The two inputs must come from compatible `evaluate_budget_allocation` calls over
the same fitted model. Uplift is computed draw-wise as
`candidate.response_draws - reference.response_draws`; percentage uplift is the
draw-wise uplift divided by the reference draw where numerically defined.
"""
function budget_allocation_decision_summary(
        reference::BudgetAllocationEvaluationResult,
        candidate::BudgetAllocationEvaluationResult;
        interval_probability = 0.9,
    )
    action = "budget_allocation_decision_summary"
    probability = _validate_decision_interval_probability(interval_probability)
    _validate_budget_allocation_decision_inputs(reference, candidate, action)

    uplift_draws = candidate.response_draws .- reference.response_draws
    uplift_pct_draws = _uplift_pct_draws(candidate, reference)
    response = _decision_draw_summary(candidate.response_draws, probability)
    uplift = _decision_draw_summary(uplift_draws, probability)
    uplift_pct = _decision_draw_summary(uplift_pct_draws, probability)
    probability_beats_reference = Float64(mean(uplift_draws .> 0.0))

    return BudgetAllocationDecisionSummary(
        candidate.metadata,
        candidate.spec,
        candidate.coordinate_metadata,
        candidate.objective,
        reference.allocation_kind,
        candidate.allocation_kind,
        copy(candidate.allocation),
        candidate.total_budget,
        probability,
        response.mean,
        response.median,
        response.std,
        response.lower,
        response.upper,
        uplift.mean,
        uplift.median,
        uplift.std,
        uplift.lower,
        uplift.upper,
        uplift_pct.mean,
        uplift_pct.median,
        uplift_pct.lower,
        uplift_pct.upper,
        probability_beats_reference,
    )
end

function _budget_allocation_decision_table_row(summary::BudgetAllocationDecisionSummary)
    return (
        allocation_kind = summary.allocation_kind,
        reference_allocation_kind = summary.reference_allocation_kind,
        objective = summary.objective,
        total_budget = summary.total_budget,
        response_mean = summary.response_mean,
        response_median = summary.response_median,
        response_std = summary.response_std,
        response_interval_lower = summary.response_interval_lower,
        response_interval_upper = summary.response_interval_upper,
        uplift_mean = summary.uplift_mean,
        uplift_median = summary.uplift_median,
        uplift_std = summary.uplift_std,
        uplift_interval_lower = summary.uplift_interval_lower,
        uplift_interval_upper = summary.uplift_interval_upper,
        uplift_pct_mean = summary.uplift_pct_mean,
        uplift_pct_median = summary.uplift_pct_median,
        uplift_pct_interval_lower = summary.uplift_pct_interval_lower,
        uplift_pct_interval_upper = summary.uplift_pct_interval_upper,
        probability_beats_reference = summary.probability_beats_reference,
        interval_probability = summary.interval_probability,
    )
end

"""
    budget_allocation_decision_table(reference, candidates...; interval_probability=0.9)

Project posterior decision summaries for evaluated allocations into an
analyst-facing table. If no candidates are supplied, the reference allocation
is summarised against itself.
"""
function budget_allocation_decision_table(
        reference::BudgetAllocationEvaluationResult,
        candidates::BudgetAllocationEvaluationResult...;
        interval_probability = 0.9,
    )
    evaluated = isempty(candidates) ? [reference] : collect(candidates)
    rows = [
        _budget_allocation_decision_table_row(
                budget_allocation_decision_summary(
                    reference,
                    candidate;
                    interval_probability,
                ),
            ) for candidate in evaluated
    ]
    return DataFrame(rows)
end

function budget_allocation_decision_table(
        reference::BudgetAllocationEvaluationResult,
        candidates::AbstractVector{<:BudgetAllocationEvaluationResult};
        interval_probability = 0.9,
    )
    rows = [
        _budget_allocation_decision_table_row(
                budget_allocation_decision_summary(
                    reference,
                    candidate;
                    interval_probability,
                ),
            ) for candidate in candidates
    ]
    return DataFrame(rows)
end

"""
    optimization_diagnostics(result)

Summarise one solved bounded budget optimisation result as typed total-level
diagnostics.

The returned `BudgetOptimizationDiagnostics` records spend, response, default
efficiency, solver, and constraint metadata. It is an audit of an existing
solved allocation; it does not re-run the optimiser or add posterior
uncertainty.
"""
function optimization_diagnostics(result::_BudgetOptimizationResultLike)
    current_total_spend = sum(values(result.current_spend))
    optimized_total_spend = sum(values(result.optimized_spend))
    response_delta = result.optimized_response - result.current_response
    default_efficiency_delta = result.optimized_default_efficiency -
        result.current_default_efficiency
    current_marginal_response = _marginal_response_lookup(
        result,
        "current_marginal_response",
    )
    optimized_marginal_response = _marginal_response_lookup(
        result,
        "optimized_marginal_response",
    )

    return BudgetOptimizationDiagnostics(
        result.metadata,
        result.spec,
        result.coordinate_metadata,
        result.objective,
        result.solver_status,
        copy(result.optimized_channels),
        copy(result.fixed_channels),
        current_total_spend,
        optimized_total_spend,
        optimized_total_spend - current_total_spend,
        result.current_response,
        result.optimized_response,
        response_delta,
        _safe_metric_ratio(response_delta, result.current_response),
        result.current_default_efficiency,
        result.optimized_default_efficiency,
        default_efficiency_delta,
        _safe_metric_ratio(default_efficiency_delta, result.current_default_efficiency),
        current_marginal_response,
        optimized_marginal_response,
        copy(result.convergence_metadata),
        result.constraint_audit,
    )
end

"""
    optimization_diagnostics_table(result)

Project one solved bounded budget optimisation result into an analyst-facing
channel spend and total-response diagnostics table.

Rows follow canonical model channel order. Spend and bound columns are
channel-level. Marginal-response columns are available for optimized channels
when the result was produced by the current solver. Total-response and
efficiency columns are total-result diagnostics repeated on each row so that
CSV exports remain self-contained.
"""
function optimization_diagnostics_table(result::_BudgetOptimizationResultLike)
    diagnostics = optimization_diagnostics(result)
    current_total_spend = diagnostics.current_total_spend
    optimized_total_spend = diagnostics.optimized_total_spend
    optimized_set = Set(result.optimized_channels)
    constraint_lookup = _channel_constraint_lookup(result.constraint_audit)

    rows = NamedTuple[]
    for channel in result.spec.channel_columns
        current_spend = result.current_spend[channel]
        optimized_spend = result.optimized_spend[channel]
        constraint = get(constraint_lookup, channel, nothing)
        lower_bound_active, upper_bound_active = _optimization_bound_flags(
            constraint,
            optimized_spend,
        )
        current_marginal_response = _channel_marginal_response(
            diagnostics.current_marginal_response,
            channel,
        )
        optimized_marginal_response = _channel_marginal_response(
            diagnostics.optimized_marginal_response,
            channel,
        )
        push!(
            rows,
            (
                channel = channel,
                optimized = channel in optimized_set,
                fixed = !(channel in optimized_set),
                solver_status = diagnostics.solver_status,
                objective = diagnostics.objective,
                current_spend = current_spend,
                optimized_spend = optimized_spend,
                spend_delta = optimized_spend - current_spend,
                spend_delta_pct = _safe_metric_ratio(optimized_spend, current_spend) - 1.0,
                current_spend_share = _safe_metric_ratio(current_spend, current_total_spend),
                optimized_spend_share = _safe_metric_ratio(optimized_spend, optimized_total_spend),
                lower_bound_active = lower_bound_active,
                upper_bound_active = upper_bound_active,
                current_marginal_response = current_marginal_response,
                optimized_marginal_response = optimized_marginal_response,
                current_marginal_roas = _marginal_roas(result, current_marginal_response),
                optimized_marginal_roas = _marginal_roas(result, optimized_marginal_response),
                current_marginal_cpa = _marginal_cpa(result, current_marginal_response),
                optimized_marginal_cpa = _marginal_cpa(result, optimized_marginal_response),
                current_total_response = diagnostics.current_response,
                optimized_total_response = diagnostics.optimized_response,
                total_response_delta = diagnostics.response_delta,
                total_response_lift_pct = diagnostics.response_lift_pct,
                current_default_efficiency = diagnostics.current_default_efficiency,
                optimized_default_efficiency = diagnostics.optimized_default_efficiency,
                default_efficiency_delta = diagnostics.default_efficiency_delta,
                default_efficiency_lift_pct = diagnostics.default_efficiency_lift_pct,
            ),
        )
    end

    return DataFrame(rows)
end

"""
    budget_impact_table(result::BudgetOptimizationResult)

Project a bounded optimization result into a channel-level current-versus-
optimized spend comparison table.

The returned `DataFrame` spans all modeled channels in canonical model-spec
order. Optimized channels show the solver-backed spend change, while fixed
channels remain unchanged so the comparison surface stays truthful for subset
optimization runs.
"""
function budget_impact_table(result::_BudgetOptimizationResultLike)
    current_total_spend = sum(values(result.current_spend))
    optimized_total_spend = sum(values(result.optimized_spend))
    optimized_set = Set(result.optimized_channels)

    rows = NamedTuple[]
    for channel in result.spec.channel_columns
        current_spend = result.current_spend[channel]
        optimized_spend = result.optimized_spend[channel]
        push!(
            rows,
            (
                channel = channel,
                optimized = channel in optimized_set,
                current_spend = current_spend,
                optimized_spend = optimized_spend,
                spend_delta = optimized_spend - current_spend,
                current_share = _safe_metric_ratio(current_spend, current_total_spend),
                optimized_share = _safe_metric_ratio(optimized_spend, optimized_total_spend),
                optimized_vs_current_pct = _safe_metric_ratio(optimized_spend, current_spend) - 1.0,
            ),
        )
    end

    return DataFrame(rows)
end

"""
    budget_audit_table(result::BudgetOptimizationResult)

Project the normalized bounded optimization constraints plus the solved spend
allocation into an analyst-facing audit table.

The returned `DataFrame` covers only the optimized channel subset because the
bounded constraint contract applies there; held channels are exposed through
`budget_impact_table(result)` and remain fixed at observed spend.
"""
function budget_audit_table(result::_BudgetOptimizationResultLike)
    current_subset_total, optimized_subset_total = _optimized_subset_total_spend(result)
    constraint_lookup = _channel_constraint_lookup(result.constraint_audit)
    scaled_reference = Dict{String, Float64}()
    for channel in result.optimized_channels
        current_spend = result.current_spend[channel]
        scaled_reference[channel] = if isapprox(current_subset_total, 0.0; atol = sqrt(eps(Float64)))
            0.0
        else
            (current_spend / current_subset_total) * result.constraint_audit.total_budget
        end
    end

    rows = NamedTuple[]
    for channel in result.optimized_channels
        constraint = constraint_lookup[channel]
        current_spend = result.current_spend[channel]
        optimized_spend = result.optimized_spend[channel]
        scaled_reference_spend = scaled_reference[channel]
        upper_bound = isnothing(constraint.effective_upper) ? NaN : Float64(constraint.effective_upper)
        push!(
            rows,
            (
                channel = channel,
                current_spend = current_spend,
                scaled_reference_spend = scaled_reference_spend,
                absolute_lower = isnothing(constraint.absolute_lower) ? NaN : Float64(constraint.absolute_lower),
                absolute_upper = isnothing(constraint.absolute_upper) ? NaN : Float64(constraint.absolute_upper),
                relative_lower = isnothing(constraint.relative_lower) ? NaN : Float64(constraint.relative_lower),
                relative_upper = isnothing(constraint.relative_upper) ? NaN : Float64(constraint.relative_upper),
                effective_lower = constraint.effective_lower,
                effective_upper = upper_bound,
                optimized_spend = optimized_spend,
                optimized_within_bounds = (
                    optimized_spend >= constraint.effective_lower - 1.0e-9 &&
                        (isnan(upper_bound) || optimized_spend <= upper_bound + 1.0e-9)
                ),
                optimized_minus_lower_bound = optimized_spend - constraint.effective_lower,
                upper_bound_minus_optimized = isnan(upper_bound) ? NaN : upper_bound - optimized_spend,
                optimized_vs_current_pct = _safe_metric_ratio(optimized_spend, current_spend) - 1.0,
                optimized_vs_scaled_reference_pct = _safe_metric_ratio(optimized_spend, scaled_reference_spend) - 1.0,
                current_share = _safe_metric_ratio(current_spend, current_subset_total),
                scaled_reference_share = _safe_metric_ratio(scaled_reference_spend, result.constraint_audit.total_budget),
                optimized_share = _safe_metric_ratio(optimized_spend, optimized_subset_total),
            ),
        )
    end

    return DataFrame(rows)
end

"""
    panel_budget_allocation_table(result::PanelBudgetOptimizationResult)

Project panel optimization output into a channel-by-panel allocation audit.
"""
function panel_budget_allocation_table(result::PanelBudgetOptimizationResult)
    channel_values = String[]
    panel_cell_values = String[]
    channel_index_values = Int[]
    panel_index_values = Int[]
    historical_share = Float64[]
    current_spend = Float64[]
    optimized_spend = Float64[]
    spend_delta = Float64[]
    channel_delta = Float64[]
    current_response = Float64[]
    optimized_response = Float64[]
    response_delta = Float64[]
    for (channel_index, channel_name) in enumerate(result.spec.channel_columns)
        for (panel_index, panel_name) in enumerate(result.panel_names)
            push!(channel_values, channel_name)
            push!(panel_cell_values, panel_name)
            push!(channel_index_values, channel_index)
            push!(panel_index_values, panel_index)
            push!(historical_share, result.historical_panel_shares[channel_index, panel_index])
            push!(current_spend, result.current_channel_panel_spend[channel_index, panel_index])
            push!(optimized_spend, result.optimized_channel_panel_spend[channel_index, panel_index])
            push!(
                spend_delta,
                result.optimized_channel_panel_spend[channel_index, panel_index] -
                    result.current_channel_panel_spend[channel_index, panel_index],
            )
            push!(channel_delta, result.channel_delta[channel_name])
            push!(current_response, result.current_channel_panel_response[channel_index, panel_index])
            push!(optimized_response, result.optimized_channel_panel_response[channel_index, panel_index])
            push!(
                response_delta,
                result.optimized_channel_panel_response[channel_index, panel_index] -
                    result.current_channel_panel_response[channel_index, panel_index],
            )
        end
    end
    table = DataFrame(;
        channel = channel_values,
        panel_cell = panel_cell_values,
        panel = panel_cell_values,
        channel_index = channel_index_values,
        panel_index = panel_index_values,
        historical_share,
        current_spend,
        optimized_spend,
        spend_delta,
        channel_delta,
        current_response,
        optimized_response,
        response_delta,
    )
    for column in _panel_budget_coordinate_columns(result)
        table[!, Symbol(column.first)] = [column.second[index] for index in panel_index_values]
    end
    return table
end

function panel_budget_coordinates_table(result::PanelBudgetOptimizationResult)
    table = DataFrame(;
        panel_cell = result.panel_names,
        panel = result.panel_names,
    )
    for column in _panel_budget_coordinate_columns(result)
        table[!, Symbol(column.first)] = column.second
    end
    return table
end

function _panel_budget_coordinate_columns(result::PanelBudgetOptimizationResult)
    if length(result.coordinate_metadata.panel_axes) == 1
        axis = panel_axis(result.coordinate_metadata)
        length(axis.values) == length(result.panel_names) && return axis.coordinate_columns
    end
    return Pair{String, Vector{String}}[
        dim => copy(result.panel_coordinates[dim])
            for dim in result.coordinate_metadata.panel_dims
            if haskey(result.panel_coordinates, dim)
    ]
end

function panel_budget_response_table(result::PanelBudgetOptimizationResult)
    allocation = panel_budget_allocation_table(result)
    grouped = combine(
        groupby(allocation, :panel),
        :current_spend => sum => :current_spend,
        :optimized_spend => sum => :optimized_spend,
        :spend_delta => sum => :spend_delta,
        :current_response => sum => :current_media_response,
        :optimized_response => sum => :optimized_media_response,
        :response_delta => sum => :media_response_delta,
    )
    return grouped
end

function panel_budget_delta_audit_table(result::PanelBudgetOptimizationResult)
    return DataFrame(;
        channel = result.spec.channel_columns,
        current_spend = [result.current_spend[channel] for channel in result.spec.channel_columns],
        optimized_spend = [result.optimized_spend[channel] for channel in result.spec.channel_columns],
        delta = [result.channel_delta[channel] for channel in result.spec.channel_columns],
        delta_in_validity_band = [
            0.0 <= result.channel_delta[channel] <= 2.0 for channel in result.spec.channel_columns
        ],
        panel_allocation_mode = fill(String(result.panel_allocation_mode), length(result.spec.channel_columns)),
    )
end
