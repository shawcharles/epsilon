using DataFrames
using Dates

const _SCENARIO_DEFAULT_RESPONSE_VARIABLE = "total_media_contribution_original_scale"

"""
    ScenarioDataArraySpec(values; dims, coords)

Dimension-labelled numeric scenario input used by the bounded non-UI scenario
planner surface.

The v1 planner accepts this type for channel-level manual allocations when the
spec has exactly one `channel` dimension. Richer multi-dimensional allocation
execution is intentionally deferred until the response-curve contract supports
that policy directly.
"""
struct ScenarioDataArraySpec
    values::Array{Float64}
    dims::Vector{String}
    coords::Dict{String, Vector{String}}

    function ScenarioDataArraySpec(
            values::AbstractArray{<:Real};
            dims::AbstractVector{<:AbstractString},
            coords::AbstractDict,
        )
        normalized_dims = String.(dims)
        ndims(values) == length(normalized_dims) ||
            throw(ArgumentError("ScenarioDataArraySpec dims must match values dimensionality"))
        normalized_coords = Dict{String, Vector{String}}()
        for (axis, dim) in enumerate(normalized_dims)
            haskey(coords, dim) ||
                throw(ArgumentError("ScenarioDataArraySpec coords must include dimension $(dim)"))
            coordinate_values = String.(collect(coords[dim]))
            length(coordinate_values) == size(values, axis) ||
                throw(ArgumentError("ScenarioDataArraySpec coordinate length mismatch for $(dim)"))
            normalized_coords[dim] = coordinate_values
        end
        return new(Float64.(values), normalized_dims, normalized_coords)
    end
end

"""
    AbstractScenarioSpec

Abstract supertype for bounded non-UI scenario-planner specifications.
"""
abstract type AbstractScenarioSpec end

"""
    CurrentScenarioSpec(; name, start_date=nothing, end_date=nothing, scenario_id=nothing)

Describe the baseline/current scenario in a non-UI scenario-planner comparison.

Dates may be `Date`, ISO date strings, or `nothing`. When `scenario_id` is not
provided it is deterministically slugified from `name`, matching Abacus's
scenario-store convention.
"""
struct CurrentScenarioSpec <: AbstractScenarioSpec
    name::String
    start_date::Union{Nothing, Date}
    end_date::Union{Nothing, Date}
    scenario_id::String
end

function CurrentScenarioSpec(;
        name::AbstractString,
        start_date = nothing,
        end_date = nothing,
        scenario_id = nothing,
    )
    start = _scenario_date(start_date, "start_date")
    stop = _scenario_date(end_date, "end_date")
    _validate_scenario_window(start, stop)
    return CurrentScenarioSpec(
        String(name),
        start,
        stop,
        _scenario_id(name, scenario_id),
    )
end

"""
    ManualAllocationScenarioSpec(; name, allocation, start_date=nothing, end_date=nothing, scenario_id=nothing)

Describe a manually specified channel-allocation scenario.

`allocation` may be a dictionary mapping channel names to nonnegative spend, or
a one-dimensional `ScenarioDataArraySpec` whose only dimension is `channel`.
This type records validated planner intent; it does not fit or optimize a model
by itself.
"""
struct ManualAllocationScenarioSpec <: AbstractScenarioSpec
    name::String
    start_date::Union{Nothing, Date}
    end_date::Union{Nothing, Date}
    scenario_id::String
    allocation::Dict{String, Float64}
end

function ManualAllocationScenarioSpec(;
        name::AbstractString,
        allocation,
        start_date = nothing,
        end_date = nothing,
        scenario_id = nothing,
    )
    start = _scenario_date(start_date, "start_date")
    stop = _scenario_date(end_date, "end_date")
    _validate_scenario_window(start, stop)
    return ManualAllocationScenarioSpec(
        String(name),
        start,
        stop,
        _scenario_id(name, scenario_id),
        _manual_allocation_mapping(allocation),
    )
end

"""
    FixedBudgetOptimizedScenarioSpec(; name, total_budget, ...)

Describe an optimized fixed-budget scenario for comparison/reporting.

The actual allocation is supplied by an existing `BudgetOptimizationResult` or
`PanelBudgetOptimizationResult` passed to `scenario_plan`. The spec preserves
planner metadata such as the requested budget, response variable, and optional
constraint dictionaries without re-solving the optimization problem.
"""
struct FixedBudgetOptimizedScenarioSpec <: AbstractScenarioSpec
    name::String
    start_date::Union{Nothing, Date}
    end_date::Union{Nothing, Date}
    scenario_id::String
    total_budget::Float64
    response_variable::String
    budget_bounds::Dict{String, Any}
    spend_constraints::Dict{String, Any}
    default_constraints::Dict{String, Any}
end

function FixedBudgetOptimizedScenarioSpec(;
        name::AbstractString,
        total_budget,
        start_date = nothing,
        end_date = nothing,
        scenario_id = nothing,
        response_variable::AbstractString = _SCENARIO_DEFAULT_RESPONSE_VARIABLE,
        budget_bounds = Dict{String, Any}(),
        spend_constraints = Dict{String, Any}(),
        default_constraints = Dict{String, Any}(),
    )
    budget = Float64(total_budget)
    isfinite(budget) && budget > 0.0 ||
        throw(ArgumentError("FixedBudgetOptimizedScenarioSpec total_budget must be positive and finite"))
    start = _scenario_date(start_date, "start_date")
    stop = _scenario_date(end_date, "end_date")
    _validate_scenario_window(start, stop)
    return FixedBudgetOptimizedScenarioSpec(
        String(name),
        start,
        stop,
        _scenario_id(name, scenario_id),
        budget,
        String(response_variable),
        _string_key_dict(budget_bounds, "budget_bounds"),
        _string_key_dict(spend_constraints, "spend_constraints"),
        _string_key_dict(default_constraints, "default_constraints"),
    )
end

"""
    ScenarioPlanResult

Abacus-like non-UI scenario comparison tables derived from a solved Epsilon
budget optimization result.

`totals`, `channels`, `allocations`, and `metadata` mirror the reusable
business-planning store shape from Abacus. `channel_panel_allocations` is empty
for time-series results and populated for bounded panel historical-share
optimization results.
"""
struct ScenarioPlanResult
    totals::DataFrame
    channels::DataFrame
    allocations::DataFrame
    metadata::DataFrame
    channel_panel_allocations::DataFrame
end

"""
    scenario_plan(result; current_scenario=..., optimized_scenario=nothing)

Build deterministic scenario-planner comparison tables from a solved
`BudgetOptimizationResult` or `PanelBudgetOptimizationResult`.

This function is intentionally a reporting/planning projection. It does not
simulate new spend paths, refit models, or solve another optimization problem.
For panel results it preserves the v1 historical-share policy already encoded
by `optimize_budget`.
"""
function scenario_plan(
        result::_BudgetOptimizationResultLike;
        current_scenario::CurrentScenarioSpec = CurrentScenarioSpec(name = "Current"),
        optimized_scenario::Union{Nothing, FixedBudgetOptimizedScenarioSpec} = nothing,
    )
    optimized = isnothing(optimized_scenario) ? FixedBudgetOptimizedScenarioSpec(
            name = "Optimized",
            start_date = current_scenario.start_date,
            end_date = current_scenario.end_date,
            total_budget = result.constraint_audit.total_budget,
        ) : optimized_scenario

    totals = _scenario_totals_table(result, current_scenario, optimized)
    channels = _scenario_channels_table(result, current_scenario, optimized)
    allocations = _scenario_allocations_table(result, current_scenario, optimized)
    metadata = _scenario_metadata_table(result, current_scenario, optimized)
    channel_panel_allocations = _scenario_channel_panel_allocations(result, current_scenario, optimized)
    return ScenarioPlanResult(totals, channels, allocations, metadata, channel_panel_allocations)
end

function _scenario_date(value, field::AbstractString)
    isnothing(value) && return nothing
    value isa Date && return value
    value isa AbstractString && return Date(String(value))
    throw(ArgumentError("scenario $(field) must be a Date, ISO date string, or nothing"))
end

function _validate_scenario_window(start::Union{Nothing, Date}, stop::Union{Nothing, Date})
    if !isnothing(start) && !isnothing(stop) && stop < start
        throw(ArgumentError("scenario end_date must be on or after start_date"))
    end
    return nothing
end

function _scenario_id(name::AbstractString, scenario_id)
    isnothing(scenario_id) || return String(scenario_id)
    slug = replace(lowercase(strip(String(name))), r"[^a-z0-9]+" => "-")
    slug = replace(slug, r"^-+|-+$" => "")
    return isempty(slug) ? "scenario" : slug
end

function _string_key_dict(values, field::AbstractString)
    values isa AbstractDict ||
        throw(ArgumentError("FixedBudgetOptimizedScenarioSpec $(field) must be a dictionary"))
    return Dict{String, Any}(String(key) => value for (key, value) in values)
end

function _manual_allocation_mapping(allocation::AbstractDict)
    mapping = Dict{String, Float64}()
    for (channel, value) in allocation
        spend = Float64(value)
        isfinite(spend) && spend >= 0.0 ||
            throw(ArgumentError("manual allocation for $(channel) must be nonnegative and finite"))
        mapping[String(channel)] = spend
    end
    isempty(mapping) && throw(ArgumentError("manual allocation must include at least one channel"))
    return mapping
end

function _manual_allocation_mapping(allocation::ScenarioDataArraySpec)
    allocation.dims == ["channel"] ||
        throw(ArgumentError("manual allocation ScenarioDataArraySpec must have exactly one channel dimension"))
    channels = allocation.coords["channel"]
    values = vec(allocation.values)
    return _manual_allocation_mapping(Dict(channel => values[index] for (index, channel) in enumerate(channels)))
end

function _scenario_total_spend(spend::AbstractDict{String, Float64})
    return sum(values(spend))
end

function _scenario_efficiency_metric(spec::MMMModelSpec)
    return String(_default_metric_name(spec))
end

function _scenario_response_delta(current::Real, optimized::Real)
    return Float64(optimized) - Float64(current)
end

function _scenario_totals_table(
        result::_BudgetOptimizationResultLike,
        current::CurrentScenarioSpec,
        optimized::FixedBudgetOptimizedScenarioSpec,
    )
    current_total_spend = _scenario_total_spend(result.current_spend)
    optimized_total_spend = _scenario_total_spend(result.optimized_spend)
    return DataFrame(
        scenario_id = [current.scenario_id, optimized.scenario_id],
        scenario_name = [current.name, optimized.name],
        scenario_type = ["current", "fixed_budget_optimized"],
        total_spend = [current_total_spend, optimized_total_spend],
        expected_response = [result.current_response, result.optimized_response],
        response_delta_vs_baseline = [0.0, _scenario_response_delta(result.current_response, result.optimized_response)],
        spend_delta_vs_baseline = [0.0, optimized_total_spend - current_total_spend],
        default_efficiency_metric = fill(_scenario_efficiency_metric(result.spec), 2),
        default_efficiency = [result.current_default_efficiency, result.optimized_default_efficiency],
        default_efficiency_delta_vs_baseline = [
            0.0,
            result.optimized_default_efficiency - result.current_default_efficiency,
        ],
        objective = fill(String(result.objective), 2),
    )
end

function _scenario_channels_table(
        result::_BudgetOptimizationResultLike,
        current::CurrentScenarioSpec,
        optimized::FixedBudgetOptimizedScenarioSpec,
    )
    current_total_spend = _scenario_total_spend(result.current_spend)
    optimized_total_spend = _scenario_total_spend(result.optimized_spend)
    current_response, optimized_response = _channel_response_lookup(result)

    scenario_id = String[]
    scenario_name = String[]
    scenario_type = String[]
    channel = String[]
    spend = Float64[]
    spend_share = Float64[]
    expected_response = Union{Missing, Float64}[]
    default_efficiency_metric = String[]
    for channel_name in result.spec.channel_columns
        push!(scenario_id, current.scenario_id)
        push!(scenario_name, current.name)
        push!(scenario_type, "current")
        push!(channel, channel_name)
        push!(spend, result.current_spend[channel_name])
        push!(spend_share, _safe_metric_ratio(result.current_spend[channel_name], current_total_spend))
        push!(expected_response, get(current_response, channel_name, missing))
        push!(default_efficiency_metric, _scenario_efficiency_metric(result.spec))

        push!(scenario_id, optimized.scenario_id)
        push!(scenario_name, optimized.name)
        push!(scenario_type, "fixed_budget_optimized")
        push!(channel, channel_name)
        push!(spend, result.optimized_spend[channel_name])
        push!(spend_share, _safe_metric_ratio(result.optimized_spend[channel_name], optimized_total_spend))
        push!(expected_response, get(optimized_response, channel_name, missing))
        push!(default_efficiency_metric, _scenario_efficiency_metric(result.spec))
    end

    return DataFrame(;
        scenario_id,
        scenario_name,
        scenario_type,
        channel,
        spend,
        spend_share,
        expected_response,
        default_efficiency_metric,
    )
end

function _channel_response_lookup(result::BudgetOptimizationResult)
    return Dict{String, Float64}(), Dict{String, Float64}()
end

function _channel_response_lookup(result::PanelBudgetOptimizationResult)
    current = Dict{String, Float64}()
    optimized = Dict{String, Float64}()
    for (channel_index, channel) in enumerate(result.spec.channel_columns)
        current[channel] = sum(result.current_channel_panel_response[channel_index, :])
        optimized[channel] = sum(result.optimized_channel_panel_response[channel_index, :])
    end
    return current, optimized
end

function _scenario_allocations_table(
        result::_BudgetOptimizationResultLike,
        current::CurrentScenarioSpec,
        optimized::FixedBudgetOptimizedScenarioSpec,
    )
    table = budget_impact_table(result)
    table[!, :baseline_scenario_id] = fill(current.scenario_id, nrow(table))
    table[!, :optimized_scenario_id] = fill(optimized.scenario_id, nrow(table))
    select!(
        table,
        :baseline_scenario_id,
        :optimized_scenario_id,
        :channel,
        :optimized,
        :current_spend,
        :optimized_spend,
        :spend_delta,
        :current_share,
        :optimized_share,
        :optimized_vs_current_pct,
    )
    return table
end

function _scenario_metadata_table(
        result::_BudgetOptimizationResultLike,
        current::CurrentScenarioSpec,
        optimized::FixedBudgetOptimizedScenarioSpec,
    )
    base_fields = (
        model_type = result.metadata.model_type,
        inference_backend = String(result.metadata.backend),
        objective = String(result.objective),
        default_efficiency_metric = _scenario_efficiency_metric(result.spec),
    )
    metadata = DataFrame(
        scenario_id = [current.scenario_id, optimized.scenario_id],
        scenario_name = [current.name, optimized.name],
        scenario_type = ["current", "fixed_budget_optimized"],
        start_date = [_date_string(current.start_date), _date_string(optimized.start_date)],
        end_date = [_date_string(current.end_date), _date_string(optimized.end_date)],
        requested_total_budget = [NaN, optimized.total_budget],
        response_variable = ["", optimized.response_variable],
        solver_status = ["", String(result.solver_status)],
        model_type = fill(base_fields.model_type, 2),
        inference_backend = fill(base_fields.inference_backend, 2),
        objective = fill(base_fields.objective, 2),
        default_efficiency_metric = fill(base_fields.default_efficiency_metric, 2),
    )
    if result isa PanelBudgetOptimizationResult
        metadata[!, :panel_allocation_mode] = fill(String(result.panel_allocation_mode), 2)
    end
    return metadata
end

function _date_string(value::Union{Nothing, Date})
    return isnothing(value) ? "" : string(value)
end

function _scenario_channel_panel_allocations(
        result::BudgetOptimizationResult,
        current::CurrentScenarioSpec,
        optimized::FixedBudgetOptimizedScenarioSpec,
    )
    return DataFrame()
end

function _scenario_channel_panel_allocations(
        result::PanelBudgetOptimizationResult,
        current::CurrentScenarioSpec,
        optimized::FixedBudgetOptimizedScenarioSpec,
    )
    table = panel_budget_allocation_table(result)
    table[!, :baseline_scenario_id] = fill(current.scenario_id, nrow(table))
    table[!, :optimized_scenario_id] = fill(optimized.scenario_id, nrow(table))
    return table
end
