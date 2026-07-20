using DataFrames

function _channel_constraint_lookup(audit::BudgetConstraintAudit)
    return Dict(constraint.channel => constraint for constraint in audit.channel_constraints)
end

const _BudgetOptimizationResultLike = Union{BudgetOptimizationResult, PanelBudgetOptimizationResult}

function _optimized_subset_total_spend(result::_BudgetOptimizationResultLike)
    return sum(result.current_spend[channel] for channel in result.optimized_channels),
        sum(result.optimized_spend[channel] for channel in result.optimized_channels)
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
