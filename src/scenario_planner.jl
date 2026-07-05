using CSV
using DataFrames
using Dates
using Serialization

const _SCENARIO_DEFAULT_RESPONSE_VARIABLE = "total_media_contribution_original_scale"
const _SCENARIO_STORE_SCHEMA_VERSION = 1
const _SCENARIO_STORE_PAYLOAD = "scenario_store.jls"
const _SCENARIO_STORE_SIDECARS = (
    totals = "totals.csv",
    channels = "channels.csv",
    allocations = "allocations.csv",
    metadata = "metadata.csv",
    channel_panel_allocations = "channel_panel_allocations.csv",
)

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
    ManualScenarioEvaluationResult

Typed result returned by [`evaluate_manual_scenario`](@ref).

The result compares observed/current spend against one evaluated
`ManualAllocationScenarioSpec`. Manual evaluation is bounded to time-series
grouped `InferenceResults` and reuses the same response-surface interpolation
machinery as `optimize_budget`; it does not refit a model, run a new optimizer,
simulate a future spend path, or evaluate panel allocation semantics.
"""
struct ManualScenarioEvaluationResult
    metadata::ModelArtifactMetadata
    spec::MMMModelSpec
    coordinate_metadata::ModelCoordinateMetadata
    scenario::ManualAllocationScenarioSpec
    objective::Symbol
    current_spend::Dict{String, Float64}
    manual_spend::Dict{String, Float64}
    current_response::Float64
    manual_response::Float64
    current_default_efficiency::Float64
    manual_default_efficiency::Float64
end

function Base.:(==)(lhs::ManualScenarioEvaluationResult, rhs::ManualScenarioEvaluationResult)
    return lhs.metadata == rhs.metadata &&
        lhs.spec == rhs.spec &&
        lhs.coordinate_metadata == rhs.coordinate_metadata &&
        _manual_scenario_equal(lhs.scenario, rhs.scenario) &&
        lhs.objective == rhs.objective &&
        lhs.current_spend == rhs.current_spend &&
        lhs.manual_spend == rhs.manual_spend &&
        lhs.current_response == rhs.current_response &&
        lhs.manual_response == rhs.manual_response &&
        lhs.current_default_efficiency == rhs.current_default_efficiency &&
        lhs.manual_default_efficiency == rhs.manual_default_efficiency
end

function _manual_scenario_equal(lhs::ManualAllocationScenarioSpec, rhs::ManualAllocationScenarioSpec)
    return lhs.name == rhs.name &&
        lhs.start_date == rhs.start_date &&
        lhs.end_date == rhs.end_date &&
        lhs.scenario_id == rhs.scenario_id &&
        lhs.allocation == rhs.allocation
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
    ScenarioStoreArtifact(plan; metadata, spec, coordinate_metadata)

Typed local scenario-store artifact for a validated [`ScenarioPlanResult`](@ref).

The serialized store is a local Epsilon/Julia artifact. CSV sidecars written by
[`write_scenario_store`](@ref) are for inspection only; loads use the typed
payload as the source of truth.
"""
struct ScenarioStoreArtifact
    schema_version::Int
    metadata::ModelArtifactMetadata
    spec::MMMModelSpec
    coordinate_metadata::ModelCoordinateMetadata
    objective::Symbol
    channel_columns::Vector{String}
    current_baseline::NamedTuple
    totals::DataFrame
    channels::DataFrame
    allocations::DataFrame
    scenario_metadata::DataFrame
    channel_panel_allocations::DataFrame

    function ScenarioStoreArtifact(
            schema_version::Integer,
            metadata::ModelArtifactMetadata,
            spec::MMMModelSpec,
            coordinate_metadata::ModelCoordinateMetadata,
            objective::Symbol,
            channel_columns::AbstractVector{<:AbstractString},
            current_baseline::NamedTuple,
            totals::DataFrame,
            channels::DataFrame,
            allocations::DataFrame,
            scenario_metadata::DataFrame,
            channel_panel_allocations::DataFrame,
        )
        _validate_scenario_store_schema_version(schema_version)
        normalized_channels = String.(channel_columns)
        normalized_channels == spec.channel_columns ||
            throw(ArgumentError("scenario store channel order must match spec.channel_columns"))
        plan = ScenarioPlanResult(
            _copy_scenario_table(totals),
            _copy_scenario_table(channels),
            _copy_scenario_table(allocations),
            _copy_scenario_table(scenario_metadata),
            _copy_scenario_table(channel_panel_allocations),
        )
        derived_objective, derived_channels, derived_baseline = _validate_scenario_store_plan(plan, spec)
        derived_objective == objective ||
            throw(ArgumentError("scenario store objective does not match scenario tables"))
        derived_channels == normalized_channels ||
            throw(ArgumentError("scenario store channel order does not match scenario tables"))
        derived_baseline == current_baseline ||
            throw(ArgumentError("scenario store current baseline fields do not match scenario tables"))
        return new(
            Int(schema_version),
            deepcopy(metadata),
            deepcopy(spec),
            deepcopy(coordinate_metadata),
            objective,
            copy(normalized_channels),
            deepcopy(current_baseline),
            plan.totals,
            plan.channels,
            plan.allocations,
            plan.metadata,
            plan.channel_panel_allocations,
        )
    end
end

function ScenarioStoreArtifact(
        plan::ScenarioPlanResult;
        metadata::ModelArtifactMetadata,
        spec::MMMModelSpec,
        coordinate_metadata::ModelCoordinateMetadata,
    )
    objective, channel_columns, current_baseline = _validate_scenario_store_plan(plan, spec)
    return ScenarioStoreArtifact(
        _SCENARIO_STORE_SCHEMA_VERSION,
        metadata,
        spec,
        coordinate_metadata,
        objective,
        channel_columns,
        current_baseline,
        plan.totals,
        plan.channels,
        plan.allocations,
        plan.metadata,
        plan.channel_panel_allocations,
    )
end

"""
    write_scenario_store(path, plan; metadata, spec, coordinate_metadata)

Write a local scenario store directory for `plan`.

The writer replaces the typed payload and known CSV sidecars. It removes stale
`channel_panel_allocations.csv` sidecars when the current plan has no panel
allocation table.
"""
function write_scenario_store(
        path::AbstractString,
        plan::ScenarioPlanResult;
        metadata::ModelArtifactMetadata,
        spec::MMMModelSpec,
        coordinate_metadata::ModelCoordinateMetadata,
    )
    store = ScenarioStoreArtifact(plan; metadata, spec, coordinate_metadata)
    mkpath(path)
    _write_scenario_store_payload(path, store)
    _write_scenario_store_sidecars(path, store)
    return path
end

"""
    load_scenario_store(path)::ScenarioStoreArtifact

Load and validate the typed scenario-store payload from `path`.
"""
function load_scenario_store(path::AbstractString)::ScenarioStoreArtifact
    payload_path = joinpath(path, _SCENARIO_STORE_PAYLOAD)
    payload = try
        open(deserialize, payload_path)
    catch err
        throw(ArgumentError("could not load scenario store payload from $(payload_path): $(sprint(showerror, err))"))
    end
    return _scenario_store_from_payload(payload)
end

"""
    scenario_store_plan(store)::ScenarioPlanResult

Project a typed scenario store back to a copied [`ScenarioPlanResult`](@ref).
"""
function scenario_store_plan(store::ScenarioStoreArtifact)
    return ScenarioPlanResult(
        _copy_scenario_table(store.totals),
        _copy_scenario_table(store.channels),
        _copy_scenario_table(store.allocations),
        _copy_scenario_table(store.scenario_metadata),
        _copy_scenario_table(store.channel_panel_allocations),
    )
end

"""
    assert_scenario_store_compatible(lhs, rhs)

Reject scenario stores that cannot be compared under the same model, coordinate,
objective, channel-order, and current-baseline contract.
"""
function assert_scenario_store_compatible(lhs::ScenarioStoreArtifact, rhs::ScenarioStoreArtifact)
    lhs.channel_columns == rhs.channel_columns ||
        throw(ArgumentError("scenario stores are incompatible: channel order differs"))
    lhs.objective == rhs.objective ||
        throw(ArgumentError("scenario stores are incompatible: objective differs"))
    lhs.current_baseline == rhs.current_baseline ||
        throw(ArgumentError("scenario stores are incompatible: current baseline differs"))
    lhs.metadata == rhs.metadata ||
        throw(ArgumentError("scenario stores are incompatible: model metadata differs"))
    lhs.spec == rhs.spec ||
        throw(ArgumentError("scenario stores are incompatible: model spec differs"))
    lhs.coordinate_metadata == rhs.coordinate_metadata ||
        throw(ArgumentError("scenario stores are incompatible: coordinate metadata differs"))
    return nothing
end

"""
    scenario_plan(result; current_scenario=..., optimized_scenario=nothing)
    scenario_plan(result, evaluation/evaluations; current_scenario=..., optimized_scenario=nothing)

Build deterministic scenario-planner comparison tables from a solved
`BudgetOptimizationResult` or `PanelBudgetOptimizationResult`.

This function is intentionally a reporting/planning projection. It does not
simulate new spend paths, refit models, or solve another optimization problem.
For panel results it preserves the v1 historical-share policy already encoded
by `optimize_budget`.

When supplied with already evaluated manual-allocation scenarios, the combined
overload returns one plan with current, manual, and optimised scenarios after
verifying that all artifacts share the same model metadata, spec, coordinate
metadata, objective, and current baseline.
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

function scenario_plan(
        result::_BudgetOptimizationResultLike,
        evaluation::ManualScenarioEvaluationResult;
        current_scenario::CurrentScenarioSpec = CurrentScenarioSpec(name = "Current"),
        optimized_scenario::Union{Nothing, FixedBudgetOptimizedScenarioSpec} = nothing,
    )
    return scenario_plan(result, [evaluation]; current_scenario, optimized_scenario)
end

function scenario_plan(
        result::_BudgetOptimizationResultLike,
        evaluations::AbstractVector{<:ManualScenarioEvaluationResult};
        current_scenario::CurrentScenarioSpec = CurrentScenarioSpec(name = "Current"),
        optimized_scenario::Union{Nothing, FixedBudgetOptimizedScenarioSpec} = nothing,
    )
    normalized = _validated_manual_evaluations(evaluations)
    _validate_manual_evaluations_match_optimization(result, normalized)
    optimized = _optimized_scenario_spec(result, current_scenario, optimized_scenario)

    manual_plan = scenario_plan(normalized; current_scenario)
    optimized_plan = scenario_plan(result; current_scenario, optimized_scenario = optimized)
    totals = vcat(manual_plan.totals, _without_current_rows(optimized_plan.totals))
    channels = _combined_scenario_channels_table(manual_plan.channels, optimized_plan.channels, result.spec.channel_columns)
    allocations = vcat(manual_plan.allocations, optimized_plan.allocations; cols = :union)
    metadata = vcat(manual_plan.metadata, _without_current_rows(optimized_plan.metadata); cols = :union)
    return ScenarioPlanResult(totals, channels, allocations, metadata, optimized_plan.channel_panel_allocations)
end

"""
    scenario_plan(evaluation; current_scenario=...)
    scenario_plan(evaluations; current_scenario=...)

Project evaluated manual-allocation scenarios into deterministic non-UI
scenario-planner tables.

This overload consumes one or more `ManualScenarioEvaluationResult` values.
It reports the supplied current scenario plus each evaluated manual allocation
as `scenario_type = "manual_allocation"`. It does not refit, optimize, simulate
future spend paths, or solve optimization. Use `scenario_plan(result, evaluations)`
when compatible manual evaluations and a solved fixed-budget optimization
result should be compared in one plan.
"""
function scenario_plan(
        evaluation::ManualScenarioEvaluationResult;
        current_scenario::CurrentScenarioSpec = CurrentScenarioSpec(name = "Current"),
    )
    return scenario_plan([evaluation]; current_scenario)
end

function scenario_plan(
        evaluations::AbstractVector{<:ManualScenarioEvaluationResult};
        current_scenario::CurrentScenarioSpec = CurrentScenarioSpec(name = "Current"),
    )
    normalized = _validated_manual_evaluations(evaluations)
    totals = _manual_scenario_totals_table(normalized, current_scenario)
    channels = _manual_scenario_channels_table(normalized, current_scenario)
    allocations = _manual_scenario_allocations_table(normalized, current_scenario)
    metadata = _manual_scenario_metadata_table(normalized, current_scenario)
    return ScenarioPlanResult(totals, channels, allocations, metadata, DataFrame())
end

function _copy_scenario_table(table::DataFrame)
    return copy(table; copycols = true)
end

function _write_scenario_store_payload(path::AbstractString, store::ScenarioStoreArtifact)
    payload_path = joinpath(path, _SCENARIO_STORE_PAYLOAD)
    isfile(payload_path) && rm(payload_path)
    open(payload_path, "w") do io
        serialize(io, store)
    end
    return payload_path
end

function _write_scenario_store_sidecars(path::AbstractString, store::ScenarioStoreArtifact)
    _write_scenario_store_sidecar(path, _SCENARIO_STORE_SIDECARS.totals, store.totals)
    _write_scenario_store_sidecar(path, _SCENARIO_STORE_SIDECARS.channels, store.channels)
    _write_scenario_store_sidecar(path, _SCENARIO_STORE_SIDECARS.allocations, store.allocations)
    _write_scenario_store_sidecar(path, _SCENARIO_STORE_SIDECARS.metadata, store.scenario_metadata)
    panel_path = joinpath(path, _SCENARIO_STORE_SIDECARS.channel_panel_allocations)
    if isempty(store.channel_panel_allocations)
        isfile(panel_path) && rm(panel_path)
    else
        _write_scenario_store_sidecar(
            path,
            _SCENARIO_STORE_SIDECARS.channel_panel_allocations,
            store.channel_panel_allocations,
        )
    end
    return nothing
end

function _write_scenario_store_sidecar(path::AbstractString, filename::AbstractString, table::DataFrame)
    sidecar_path = joinpath(path, filename)
    isfile(sidecar_path) && rm(sidecar_path)
    CSV.write(sidecar_path, table)
    return sidecar_path
end

function _scenario_store_from_payload(payload)
    if payload isa ScenarioStoreArtifact
        return ScenarioStoreArtifact(
            payload.schema_version,
            payload.metadata,
            payload.spec,
            payload.coordinate_metadata,
            payload.objective,
            payload.channel_columns,
            payload.current_baseline,
            payload.totals,
            payload.channels,
            payload.allocations,
            payload.scenario_metadata,
            payload.channel_panel_allocations,
        )
    end
    if payload isa NamedTuple && :schema_version in propertynames(payload)
        _validate_scenario_store_schema_version(payload.schema_version)
    end
    throw(ArgumentError("scenario store payload must be a ScenarioStoreArtifact"))
end

function _validate_scenario_store_schema_version(schema_version)
    schema_version == _SCENARIO_STORE_SCHEMA_VERSION ||
        throw(ArgumentError("unsupported scenario store schema version: $(schema_version)"))
    return nothing
end

function _validate_scenario_store_plan(plan::ScenarioPlanResult, spec::MMMModelSpec)
    _validate_scenario_store_table_columns(
        plan.totals,
        [
            "scenario_id",
            "scenario_name",
            "scenario_type",
            "total_spend",
            "expected_response",
            "response_delta_vs_baseline",
            "spend_delta_vs_baseline",
            "default_efficiency_metric",
            "default_efficiency",
            "default_efficiency_delta_vs_baseline",
            "objective",
        ],
        "scenario totals",
    )
    _validate_scenario_store_table_columns(
        plan.channels,
        [
            "scenario_id",
            "scenario_name",
            "scenario_type",
            "channel",
            "spend",
            "spend_share",
            "expected_response",
            "default_efficiency_metric",
        ],
        "scenario channels",
    )
    _validate_scenario_store_table_columns(
        plan.metadata,
        [
            "scenario_id",
            "scenario_name",
            "scenario_type",
            "start_date",
            "end_date",
            "requested_total_budget",
            "response_variable",
            "solver_status",
            "model_type",
            "inference_backend",
            "objective",
            "default_efficiency_metric",
        ],
        "scenario metadata",
    )
    current_baseline = _scenario_store_current_baseline(plan)
    objective = _scenario_store_objective(plan.totals, plan.metadata)
    scenario_ids, scenario_types = _scenario_store_scenario_types(plan.totals, plan.metadata)
    channel_columns = _scenario_store_channel_order(plan.channels, spec.channel_columns, "scenario channels")
    _scenario_store_channel_order(plan.allocations, spec.channel_columns, "scenario allocations")
    isempty(plan.channel_panel_allocations) ||
        _scenario_store_channel_order(plan.channel_panel_allocations, spec.channel_columns, "scenario channel-panel allocations")
    _validate_scenario_store_current_channels(plan.channels, current_baseline.scenario_id, spec.channel_columns)
    _validate_scenario_store_baseline_ids(plan.allocations, current_baseline.scenario_id, "scenario allocations")
    _validate_scenario_store_allocations(
        plan.allocations,
        scenario_ids,
        scenario_types,
        current_baseline.scenario_id,
        spec.channel_columns,
    )
    _validate_scenario_store_panel_allocations(plan.channel_panel_allocations)
    isempty(plan.channel_panel_allocations) ||
        _validate_scenario_store_baseline_ids(
        plan.channel_panel_allocations,
        current_baseline.scenario_id,
        "scenario channel-panel allocations",
    )
    return objective, channel_columns, current_baseline
end

function _validate_scenario_store_table_columns(table::DataFrame, required::AbstractVector{String}, label::AbstractString)
    missing_columns = setdiff(required, names(table))
    isempty(missing_columns) ||
        throw(ArgumentError("$(label) table is missing required columns: $(join(missing_columns, ", "))"))
    isempty(table) &&
        throw(ArgumentError("$(label) table must contain at least one row"))
    return nothing
end

function _scenario_store_current_baseline(plan::ScenarioPlanResult)
    total_rows = findall(==("current"), String.(plan.totals.scenario_type))
    length(total_rows) == 1 ||
        throw(ArgumentError("scenario store totals must contain exactly one current baseline row"))
    metadata_rows = findall(==("current"), String.(plan.metadata.scenario_type))
    length(metadata_rows) == 1 ||
        throw(ArgumentError("scenario store metadata must contain exactly one current baseline row"))
    total = plan.totals[only(total_rows), :]
    metadata = plan.metadata[only(metadata_rows), :]
    String(total.scenario_id) == String(metadata.scenario_id) ||
        throw(ArgumentError("scenario store current baseline id must match totals and metadata"))
    String(total.scenario_name) == String(metadata.scenario_name) ||
        throw(ArgumentError("scenario store current baseline name must match totals and metadata"))
    return (
        scenario_id = String(total.scenario_id),
        scenario_name = String(total.scenario_name),
        scenario_type = "current",
        total_spend = Float64(total.total_spend),
        expected_response = Float64(total.expected_response),
        default_efficiency_metric = String(total.default_efficiency_metric),
        default_efficiency = Float64(total.default_efficiency),
        start_date = String(metadata.start_date),
        end_date = String(metadata.end_date),
    )
end

function _scenario_store_objective(totals::DataFrame, metadata::DataFrame)
    total_objectives = unique(String.(totals.objective))
    length(total_objectives) == 1 ||
        throw(ArgumentError("scenario store totals must contain one consistent objective"))
    metadata_objectives = unique(String.(metadata.objective))
    length(metadata_objectives) == 1 ||
        throw(ArgumentError("scenario store metadata must contain one consistent objective"))
    only(total_objectives) == only(metadata_objectives) ||
        throw(ArgumentError("scenario store objective must match totals and metadata"))
    return Symbol(only(total_objectives))
end

function _scenario_store_scenario_types(totals::DataFrame, metadata::DataFrame)
    totals_order, totals_types = _scenario_store_scenario_type_mapping(totals, "scenario totals")
    metadata_order, metadata_types = _scenario_store_scenario_type_mapping(metadata, "scenario metadata")
    totals_order == metadata_order ||
        throw(ArgumentError("scenario store scenario ids must match totals and metadata"))
    totals_types == metadata_types ||
        throw(ArgumentError("scenario store scenario types must match totals and metadata"))
    return totals_order, totals_types
end

function _scenario_store_scenario_type_mapping(table::DataFrame, label::AbstractString)
    _validate_scenario_store_table_columns(table, ["scenario_id", "scenario_type"], label)
    order = String[]
    mapping = Dict{String, String}()
    for row in eachrow(table)
        scenario_id = String(row.scenario_id)
        isempty(scenario_id) &&
            throw(ArgumentError("$(label) scenario_id values must be non-empty"))
        haskey(mapping, scenario_id) &&
            throw(ArgumentError("$(label) scenario_id values must be unique"))
        scenario_type = String(row.scenario_type)
        isempty(scenario_type) &&
            throw(ArgumentError("$(label) scenario_type values must be non-empty"))
        push!(order, scenario_id)
        mapping[scenario_id] = scenario_type
    end
    return order, mapping
end

function _scenario_store_channel_order(table::DataFrame, expected::AbstractVector{String}, label::AbstractString)
    _validate_scenario_store_table_columns(table, ["channel"], label)
    channels = String[]
    for channel in String.(table.channel)
        channel in channels || push!(channels, channel)
    end
    channels == expected ||
        throw(ArgumentError("$(label) channel order must match spec.channel_columns"))
    return channels
end

function _validate_scenario_store_current_channels(
        channels::DataFrame,
        current_scenario_id::AbstractString,
        expected_channels::AbstractVector{String},
    )
    current_rows = channels[String.(channels.scenario_type) .== "current", :]
    nrow(current_rows) == length(expected_channels) ||
        throw(ArgumentError("scenario channels must contain exactly one current row per channel"))
    current_rows.scenario_id == fill(String(current_scenario_id), nrow(current_rows)) ||
        throw(ArgumentError("scenario channels current rows must use the current baseline id"))
    String.(current_rows.channel) == expected_channels ||
        throw(ArgumentError("scenario channels current rows must follow spec.channel_columns"))
    return nothing
end

function _validate_scenario_store_allocations(
        allocations::DataFrame,
        scenario_ids::AbstractVector{String},
        scenario_types::AbstractDict{String, String},
        current_scenario_id::AbstractString,
        expected_channels::AbstractVector{String},
    )
    _validate_scenario_store_table_columns(
        allocations,
        ["baseline_scenario_id", "channel", "current_spend", "spend_delta", "current_share"],
        "scenario allocations",
    )
    optimized_shape = all(
        name -> name in names(allocations), [
            "optimized_scenario_id",
            "optimized",
            "optimized_spend",
            "optimized_share",
            "optimized_vs_current_pct",
        ]
    )
    manual_shape = all(
        name -> name in names(allocations), [
            "scenario_id",
            "scenario_type",
            "scenario_spend",
            "scenario_share",
            "scenario_vs_current_pct",
        ]
    )
    optimized_shape || manual_shape ||
        throw(ArgumentError("scenario allocations table must include optimized or manual allocation columns"))
    expected_noncurrent = [scenario_id for scenario_id in scenario_ids if scenario_id != String(current_scenario_id)]
    isempty(expected_noncurrent) &&
        throw(ArgumentError("scenario allocations require at least one non-current scenario"))
    channels_by_scenario = Dict{String, Vector{String}}(scenario_id => String[] for scenario_id in expected_noncurrent)
    for row in eachrow(allocations)
        has_optimized = optimized_shape && !_scenario_store_missing_or_empty(row.optimized_scenario_id)
        has_manual = manual_shape && !_scenario_store_missing_or_empty(row.scenario_id)
        !(has_optimized && has_manual) ||
            throw(ArgumentError("scenario allocation rows must identify exactly one scenario id"))
        has_optimized || has_manual ||
            throw(ArgumentError("scenario allocation rows must identify a scenario id"))
        scenario_id = has_optimized ? String(row.optimized_scenario_id) : String(row.scenario_id)
        haskey(scenario_types, scenario_id) ||
            throw(ArgumentError("scenario allocation rows must reference scenario ids present in totals and metadata"))
        scenario_id != String(current_scenario_id) ||
            throw(ArgumentError("scenario allocation rows must not reference the current baseline scenario"))
        scenario_type = scenario_types[scenario_id]
        if has_optimized
            scenario_type == "fixed_budget_optimized" ||
                throw(ArgumentError("optimized allocation rows must reference fixed_budget_optimized scenarios"))
        else
            scenario_type == "manual_allocation" ||
                throw(ArgumentError("manual allocation rows must reference manual_allocation scenarios"))
        end
        haskey(channels_by_scenario, scenario_id) ||
            throw(ArgumentError("scenario allocation rows include an unexpected non-current scenario"))
        push!(channels_by_scenario[scenario_id], String(row.channel))
    end
    for scenario_id in expected_noncurrent
        get(channels_by_scenario, scenario_id, String[]) == expected_channels ||
            throw(ArgumentError("scenario allocations must contain exactly one row per channel for scenario $(scenario_id)"))
    end
    return nothing
end

function _validate_scenario_store_panel_allocations(channel_panel_allocations::DataFrame)
    isempty(channel_panel_allocations) && return nothing
    _validate_scenario_store_table_columns(
        channel_panel_allocations,
        [
            "baseline_scenario_id",
            "optimized_scenario_id",
            "channel",
            "panel_cell",
            "current_spend",
            "optimized_spend",
            "spend_delta",
        ],
        "scenario channel-panel allocations",
    )
    return nothing
end

function _validate_scenario_store_baseline_ids(table::DataFrame, current_scenario_id::AbstractString, label::AbstractString)
    all(String.(table.baseline_scenario_id) .== String(current_scenario_id)) ||
        throw(ArgumentError("$(label) baseline_scenario_id values must match the current baseline id"))
    return nothing
end

function _scenario_store_missing_or_empty(value)
    ismissing(value) && return true
    return isempty(String(value))
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

"""
    evaluate_manual_scenario(results, scenario; objective=:total_response, grid=nothing)

Evaluate one manually specified channel allocation against existing fitted
time-series response surfaces.

`results` must be grouped time-series `InferenceResults`. The supplied
`ManualAllocationScenarioSpec` may allocate all channels or a subset of
channels; omitted channels are held at observed spend. The function computes a
deterministic posterior-mean response comparison using the same bounded
response-surface interpolation path as `optimize_budget`. It does not refit the
model, solve an optimization problem, simulate future spend paths, or support
panel manual allocation.
"""
function evaluate_manual_scenario(
        results::InferenceResults,
        scenario::ManualAllocationScenarioSpec;
        objective = :total_response,
        grid = nothing,
    )
    action = "evaluate_manual_scenario"
    channels = _manual_evaluation_channels(results.spec, scenario)
    total_budget = _manual_evaluation_total_budget(scenario)
    problem = _build_budget_optimization_problem(
        results;
        total_budget,
        channels,
        objective,
        grid,
    )
    return _evaluate_manual_scenario(problem, scenario; action)
end

function _manual_evaluation_channels(
        spec::MMMModelSpec,
        scenario::ManualAllocationScenarioSpec,
    )
    provided = collect(keys(scenario.allocation))
    unknown = sort(setdiff(provided, spec.channel_columns))
    isempty(unknown) ||
        throw(
        ArgumentError(
            "evaluate_manual_scenario requires manual allocation channels drawn from `InferenceResults.spec.channel_columns`; unknown channels: $(join(unknown, ", "))",
        ),
    )
    channels = [channel for channel in spec.channel_columns if haskey(scenario.allocation, channel)]
    isempty(channels) &&
        throw(ArgumentError("evaluate_manual_scenario requires at least one known manual allocation channel"))
    return channels
end

function _manual_evaluation_total_budget(scenario::ManualAllocationScenarioSpec)
    total_budget = sum(values(scenario.allocation))
    isfinite(total_budget) && total_budget > 0.0 ||
        throw(ArgumentError("evaluate_manual_scenario requires manual allocation total spend to be positive and finite"))
    return total_budget
end

function _current_spend_mapping(problem::BudgetOptimizationProblem)
    mapping = Dict{String, Float64}()
    for (index, channel) in enumerate(problem.optimized_channels)
        mapping[channel] = problem.current_spend[index]
    end
    for (index, channel) in enumerate(problem.fixed_channels)
        mapping[channel] = problem.fixed_spend[index]
    end
    return mapping
end

function _manual_spend_mapping(
        problem::BudgetOptimizationProblem,
        scenario::ManualAllocationScenarioSpec,
    )
    mapping = _current_spend_mapping(problem)
    for channel in problem.optimized_channels
        mapping[channel] = scenario.allocation[channel]
    end
    return mapping
end

function _evaluate_manual_scenario(
        problem::BudgetOptimizationProblem,
        scenario::ManualAllocationScenarioSpec;
        action::AbstractString = "evaluate_manual_scenario",
    )
    manual_response = _evaluate_budget_objective(problem, scenario.allocation; action)
    current_spend = _current_spend_mapping(problem)
    manual_spend = _manual_spend_mapping(problem, scenario)
    return ManualScenarioEvaluationResult(
        problem.metadata,
        problem.spec,
        problem.coordinate_metadata,
        scenario,
        problem.objective,
        current_spend,
        manual_spend,
        problem.current_response,
        manual_response,
        _default_efficiency(problem, problem.current_response, current_spend),
        _default_efficiency(problem, manual_response, manual_spend),
    )
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

function _validated_manual_evaluations(evaluations::AbstractVector{<:ManualScenarioEvaluationResult})
    isempty(evaluations) &&
        throw(ArgumentError("scenario_plan requires at least one manual scenario evaluation"))
    normalized = collect(evaluations)
    reference = first(normalized)
    for evaluation in normalized[2:end]
        evaluation.metadata == reference.metadata ||
            throw(ArgumentError("scenario_plan requires manual evaluations from the same model artifact"))
        evaluation.spec == reference.spec ||
            throw(ArgumentError("scenario_plan requires manual evaluations with the same model spec"))
        evaluation.coordinate_metadata == reference.coordinate_metadata ||
            throw(ArgumentError("scenario_plan requires manual evaluations with the same coordinate metadata"))
        evaluation.objective == reference.objective ||
            throw(ArgumentError("scenario_plan requires manual evaluations with the same objective"))
        evaluation.current_spend == reference.current_spend ||
            throw(ArgumentError("scenario_plan requires manual evaluations with the same current spend baseline"))
        evaluation.current_response == reference.current_response ||
            throw(ArgumentError("scenario_plan requires manual evaluations with the same current response baseline"))
        evaluation.current_default_efficiency == reference.current_default_efficiency ||
            throw(ArgumentError("scenario_plan requires manual evaluations with the same current efficiency baseline"))
    end
    return normalized
end

function _validate_manual_evaluations_match_optimization(
        result::_BudgetOptimizationResultLike,
        evaluations::AbstractVector{ManualScenarioEvaluationResult},
    )
    reference = first(evaluations)
    result.metadata == reference.metadata ||
        throw(ArgumentError("scenario_plan requires manual evaluations and optimization result from the same model artifact"))
    result.spec == reference.spec ||
        throw(ArgumentError("scenario_plan requires manual evaluations and optimization result with the same model spec"))
    result.coordinate_metadata == reference.coordinate_metadata ||
        throw(ArgumentError("scenario_plan requires manual evaluations and optimization result with the same coordinate metadata"))
    result.objective == reference.objective ||
        throw(ArgumentError("scenario_plan requires manual evaluations and optimization result with the same objective"))
    result.current_spend == reference.current_spend ||
        throw(ArgumentError("scenario_plan requires manual evaluations and optimization result with the same current spend baseline"))
    result.current_response == reference.current_response ||
        throw(ArgumentError("scenario_plan requires manual evaluations and optimization result with the same current response baseline"))
    result.current_default_efficiency == reference.current_default_efficiency ||
        throw(ArgumentError("scenario_plan requires manual evaluations and optimization result with the same current efficiency baseline"))
    return nothing
end

function _optimized_scenario_spec(
        result::_BudgetOptimizationResultLike,
        current_scenario::CurrentScenarioSpec,
        optimized_scenario::Union{Nothing, FixedBudgetOptimizedScenarioSpec},
    )
    isnothing(optimized_scenario) || return optimized_scenario
    return FixedBudgetOptimizedScenarioSpec(
        name = "Optimized",
        start_date = current_scenario.start_date,
        end_date = current_scenario.end_date,
        total_budget = result.constraint_audit.total_budget,
    )
end

function _without_current_rows(table::DataFrame)
    return filter(:scenario_type => !=("current"), table)
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

function _manual_scenario_totals_table(
        evaluations::AbstractVector{ManualScenarioEvaluationResult},
        current::CurrentScenarioSpec,
    )
    reference = first(evaluations)
    current_total_spend = _scenario_total_spend(reference.current_spend)
    scenario_id = [current.scenario_id]
    scenario_name = [current.name]
    scenario_type = ["current"]
    total_spend = [current_total_spend]
    expected_response = [reference.current_response]
    response_delta_vs_baseline = [0.0]
    spend_delta_vs_baseline = [0.0]
    default_efficiency_metric = [_scenario_efficiency_metric(reference.spec)]
    default_efficiency = [reference.current_default_efficiency]
    default_efficiency_delta_vs_baseline = [0.0]
    objective = [String(reference.objective)]

    for evaluation in evaluations
        manual_total_spend = _scenario_total_spend(evaluation.manual_spend)
        push!(scenario_id, evaluation.scenario.scenario_id)
        push!(scenario_name, evaluation.scenario.name)
        push!(scenario_type, "manual_allocation")
        push!(total_spend, manual_total_spend)
        push!(expected_response, evaluation.manual_response)
        push!(response_delta_vs_baseline, _scenario_response_delta(evaluation.current_response, evaluation.manual_response))
        push!(spend_delta_vs_baseline, manual_total_spend - current_total_spend)
        push!(default_efficiency_metric, _scenario_efficiency_metric(evaluation.spec))
        push!(default_efficiency, evaluation.manual_default_efficiency)
        push!(default_efficiency_delta_vs_baseline, evaluation.manual_default_efficiency - evaluation.current_default_efficiency)
        push!(objective, String(evaluation.objective))
    end

    return DataFrame(;
        scenario_id,
        scenario_name,
        scenario_type,
        total_spend,
        expected_response,
        response_delta_vs_baseline,
        spend_delta_vs_baseline,
        default_efficiency_metric,
        default_efficiency,
        default_efficiency_delta_vs_baseline,
        objective,
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

function _manual_scenario_channels_table(
        evaluations::AbstractVector{ManualScenarioEvaluationResult},
        current::CurrentScenarioSpec,
    )
    reference = first(evaluations)
    current_total_spend = _scenario_total_spend(reference.current_spend)

    scenario_id = String[]
    scenario_name = String[]
    scenario_type = String[]
    channel = String[]
    spend = Float64[]
    spend_share = Float64[]
    expected_response = Union{Missing, Float64}[]
    default_efficiency_metric = String[]

    for channel_name in reference.spec.channel_columns
        push!(scenario_id, current.scenario_id)
        push!(scenario_name, current.name)
        push!(scenario_type, "current")
        push!(channel, channel_name)
        push!(spend, reference.current_spend[channel_name])
        push!(spend_share, _safe_metric_ratio(reference.current_spend[channel_name], current_total_spend))
        push!(expected_response, missing)
        push!(default_efficiency_metric, _scenario_efficiency_metric(reference.spec))

        for evaluation in evaluations
            manual_total_spend = _scenario_total_spend(evaluation.manual_spend)
            push!(scenario_id, evaluation.scenario.scenario_id)
            push!(scenario_name, evaluation.scenario.name)
            push!(scenario_type, "manual_allocation")
            push!(channel, channel_name)
            push!(spend, evaluation.manual_spend[channel_name])
            push!(spend_share, _safe_metric_ratio(evaluation.manual_spend[channel_name], manual_total_spend))
            push!(expected_response, missing)
            push!(default_efficiency_metric, _scenario_efficiency_metric(evaluation.spec))
        end
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

function _combined_scenario_channels_table(
        manual_channels::DataFrame,
        optimized_channels::DataFrame,
        channel_columns::AbstractVector{String},
    )
    combined = manual_channels[[], :]
    for channel_name in channel_columns
        append!(combined, manual_channels[manual_channels.channel .== channel_name, :])
        append!(
            combined,
            optimized_channels[
                (optimized_channels.channel .== channel_name) .&
                    (optimized_channels.scenario_type .!= "current"),
                :,
            ],
        )
    end
    return combined
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

function _manual_scenario_allocations_table(
        evaluations::AbstractVector{ManualScenarioEvaluationResult},
        current::CurrentScenarioSpec,
    )
    reference = first(evaluations)
    current_total_spend = _scenario_total_spend(reference.current_spend)

    baseline_scenario_id = String[]
    scenario_id = String[]
    scenario_type = String[]
    channel = String[]
    current_spend = Float64[]
    scenario_spend = Float64[]
    spend_delta = Float64[]
    current_share = Float64[]
    scenario_share = Float64[]
    scenario_vs_current_pct = Float64[]

    for evaluation in evaluations
        manual_total_spend = _scenario_total_spend(evaluation.manual_spend)
        for channel_name in evaluation.spec.channel_columns
            current_channel_spend = evaluation.current_spend[channel_name]
            manual_channel_spend = evaluation.manual_spend[channel_name]
            push!(baseline_scenario_id, current.scenario_id)
            push!(scenario_id, evaluation.scenario.scenario_id)
            push!(scenario_type, "manual_allocation")
            push!(channel, channel_name)
            push!(current_spend, current_channel_spend)
            push!(scenario_spend, manual_channel_spend)
            push!(spend_delta, manual_channel_spend - current_channel_spend)
            push!(current_share, _safe_metric_ratio(current_channel_spend, current_total_spend))
            push!(scenario_share, _safe_metric_ratio(manual_channel_spend, manual_total_spend))
            push!(scenario_vs_current_pct, _safe_metric_ratio(manual_channel_spend, current_channel_spend) - 1.0)
        end
    end

    return DataFrame(;
        baseline_scenario_id,
        scenario_id,
        scenario_type,
        channel,
        current_spend,
        scenario_spend,
        spend_delta,
        current_share,
        scenario_share,
        scenario_vs_current_pct,
    )
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

function _manual_scenario_metadata_table(
        evaluations::AbstractVector{ManualScenarioEvaluationResult},
        current::CurrentScenarioSpec,
    )
    reference = first(evaluations)
    scenario_id = [current.scenario_id]
    scenario_name = [current.name]
    scenario_type = ["current"]
    start_date = [_date_string(current.start_date)]
    end_date = [_date_string(current.end_date)]
    requested_total_budget = [NaN]
    response_variable = [""]
    solver_status = [""]
    model_type = [reference.metadata.model_type]
    inference_backend = [String(reference.metadata.backend)]
    objective = [String(reference.objective)]
    default_efficiency_metric = [_scenario_efficiency_metric(reference.spec)]

    for evaluation in evaluations
        push!(scenario_id, evaluation.scenario.scenario_id)
        push!(scenario_name, evaluation.scenario.name)
        push!(scenario_type, "manual_allocation")
        push!(start_date, _date_string(evaluation.scenario.start_date))
        push!(end_date, _date_string(evaluation.scenario.end_date))
        push!(requested_total_budget, _scenario_total_spend(evaluation.manual_spend))
        push!(response_variable, _SCENARIO_DEFAULT_RESPONSE_VARIABLE)
        push!(solver_status, "")
        push!(model_type, evaluation.metadata.model_type)
        push!(inference_backend, String(evaluation.metadata.backend))
        push!(objective, String(evaluation.objective))
        push!(default_efficiency_metric, _scenario_efficiency_metric(evaluation.spec))
    end

    return DataFrame(;
        scenario_id,
        scenario_name,
        scenario_type,
        start_date,
        end_date,
        requested_total_budget,
        response_variable,
        solver_status,
        model_type,
        inference_backend,
        objective,
        default_efficiency_metric,
    )
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
