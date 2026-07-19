using Dates
using JSON3
using YAML

const _PIPELINE_SCHEMA_VERSION = 1
const _PIPELINE_STAGE_STATUSES = Set(
    (
        :pending,
        :running,
        :completed,
        :skipped,
        :failed,
        :not_reached,
    )
)
const _PIPELINE_STAGE_SPECS = (
    (key = "metadata", directory = "00_run_metadata", optional = false),
    (key = "prior_sensitivity", directory = "05_prior_sensitivity", optional = true),
    (key = "preflight", directory = "10_pre_diagnostics", optional = false),
    (key = "fit", directory = "20_model_fit", optional = false),
    (key = "assessment", directory = "30_model_assessment", optional = false),
    (key = "validation", directory = "35_holdout_validation", optional = true),
    (key = "decomposition", directory = "40_decomposition", optional = false),
    (key = "diagnostics", directory = "50_diagnostics", optional = false),
    (key = "curves", directory = "60_response_curves", optional = false),
    (key = "optimisation", directory = "70_optimisation", optional = true),
)

"""
    PipelineStageRecord(key, directory; status=:pending, started_at_utc=nothing, finished_at_utc=nothing, artifact_paths=Dict(), warnings=String[], error=nothing)

Typed per-stage manifest record for the bounded Phase 9 pipeline runner.
"""
struct PipelineStageRecord
    key::String
    directory::String
    status::Symbol
    started_at_utc::Union{Nothing, String}
    finished_at_utc::Union{Nothing, String}
    artifact_paths::Dict{String, String}
    warnings::Vector{String}
    error::Union{Nothing, Dict{String, Any}}
end

function Base.:(==)(lhs::PipelineStageRecord, rhs::PipelineStageRecord)
    return lhs.key == rhs.key &&
        lhs.directory == rhs.directory &&
        lhs.status == rhs.status &&
        lhs.started_at_utc == rhs.started_at_utc &&
        lhs.finished_at_utc == rhs.finished_at_utc &&
        lhs.artifact_paths == rhs.artifact_paths &&
        lhs.warnings == rhs.warnings &&
        lhs.error == rhs.error
end

function PipelineStageRecord(
        key,
        directory;
        status::Symbol = :pending,
        started_at_utc = nothing,
        finished_at_utc = nothing,
        artifact_paths = Dict{String, String}(),
        warnings = String[],
        error = nothing,
    )
    _validate_pipeline_stage_status(status)
    _validate_optional_timestamp(started_at_utc, "started_at_utc")
    _validate_optional_timestamp(finished_at_utc, "finished_at_utc")
    return PipelineStageRecord(
        String(key),
        String(directory),
        status,
        isnothing(started_at_utc) ? nothing : String(started_at_utc),
        isnothing(finished_at_utc) ? nothing : String(finished_at_utc),
        Dict{String, String}(String(name) => String(path) for (name, path) in artifact_paths),
        String[String(warning) for warning in warnings],
        _pipeline_error_dict(error),
    )
end

"""
    PipelineRunResult(run_name, run_dir, manifest_path; status=:pending, config_path, started_at_utc, finished_at_utc=nothing, stage_records=PipelineStageRecord[], warnings=String[], error=nothing)

Typed run-level summary for the bounded Phase 9 pipeline runner.

`PipelineRunResult` is the canonical Julia-native summary of one bounded Phase
9 pipeline execution, including stage status, artifact ownership, warnings, and
failure metadata.
"""
struct PipelineRunResult
    run_name::String
    run_dir::String
    manifest_path::String
    status::Symbol
    config_path::String
    started_at_utc::String
    finished_at_utc::Union{Nothing, String}
    stage_records::Vector{PipelineStageRecord}
    warnings::Vector{String}
    error::Union{Nothing, Dict{String, Any}}
end

function Base.:(==)(lhs::PipelineRunResult, rhs::PipelineRunResult)
    return lhs.run_name == rhs.run_name &&
        lhs.run_dir == rhs.run_dir &&
        lhs.manifest_path == rhs.manifest_path &&
        lhs.status == rhs.status &&
        lhs.config_path == rhs.config_path &&
        lhs.started_at_utc == rhs.started_at_utc &&
        lhs.finished_at_utc == rhs.finished_at_utc &&
        lhs.stage_records == rhs.stage_records &&
        lhs.warnings == rhs.warnings &&
        lhs.error == rhs.error
end

function PipelineRunResult(
        run_name,
        run_dir,
        manifest_path;
        status::Symbol = :pending,
        config_path,
        started_at_utc,
        finished_at_utc = nothing,
        stage_records = PipelineStageRecord[],
        warnings = String[],
        error = nothing,
    )
    _validate_pipeline_stage_status(status)
    _validate_nonempty_string(run_name, "run_name")
    _validate_nonempty_string(run_dir, "run_dir")
    _validate_nonempty_string(manifest_path, "manifest_path")
    _validate_nonempty_string(config_path, "config_path")
    _validate_nonempty_string(started_at_utc, "started_at_utc")
    _validate_optional_timestamp(finished_at_utc, "finished_at_utc")
    return PipelineRunResult(
        String(run_name),
        String(run_dir),
        String(manifest_path),
        status,
        String(config_path),
        String(started_at_utc),
        isnothing(finished_at_utc) ? nothing : String(finished_at_utc),
        PipelineStageRecord[record for record in stage_records],
        String[String(warning) for warning in warnings],
        _pipeline_error_dict(error),
    )
end

"""
    PipelineValidationResult(; holdout_rows, train_date_start, train_date_end, holdout_date_start, holdout_date_end, observed, fitted_mean, residuals, metrics)

Typed blocked-holdout artifact surface reserved for Phase 9 validation stage
outputs.
"""
struct PipelineValidationResult
    holdout_rows::Int
    train_date_start::String
    train_date_end::String
    holdout_date_start::String
    holdout_date_end::String
    observed::Vector{Float64}
    fitted_mean::Vector{Float64}
    residuals::Vector{Float64}
    metrics::Dict{String, Float64}
end

function Base.:(==)(lhs::PipelineValidationResult, rhs::PipelineValidationResult)
    return lhs.holdout_rows == rhs.holdout_rows &&
        lhs.train_date_start == rhs.train_date_start &&
        lhs.train_date_end == rhs.train_date_end &&
        lhs.holdout_date_start == rhs.holdout_date_start &&
        lhs.holdout_date_end == rhs.holdout_date_end &&
        lhs.observed == rhs.observed &&
        lhs.fitted_mean == rhs.fitted_mean &&
        lhs.residuals == rhs.residuals &&
        lhs.metrics == rhs.metrics
end

function PipelineValidationResult(;
        holdout_rows::Integer,
        train_date_start,
        train_date_end,
        holdout_date_start,
        holdout_date_end,
        observed,
        fitted_mean,
        residuals,
        metrics,
    )
    Int(holdout_rows) > 0 || throw(ArgumentError("holdout_rows must be positive"))
    all(name -> haskey(metrics, name), ("mae", "rmse", "bias")) ||
        throw(ArgumentError("metrics must include mae, rmse, and bias"))
    observed_vec = Float64[Float64(value) for value in observed]
    fitted_vec = Float64[Float64(value) for value in fitted_mean]
    residual_vec = Float64[Float64(value) for value in residuals]
    length(observed_vec) == length(fitted_vec) &&
        length(fitted_vec) == length(residual_vec) ||
        throw(ArgumentError("observed, fitted_mean, and residuals must have matching length"))
    return PipelineValidationResult(
        Int(holdout_rows),
        String(train_date_start),
        String(train_date_end),
        String(holdout_date_start),
        String(holdout_date_end),
        observed_vec,
        fitted_vec,
        residual_vec,
        Dict{String, Float64}(String(key) => Float64(value) for (key, value) in metrics),
    )
end

mutable struct PipelineContext
    config::PipelineRunConfig
    run_name::String
    output_dir::String
    run_dir::String
    manifest_path::String
    dataset_path::String
    source_yaml::String
    raw_config::Dict{String, Any}
    resolved_config::Dict{String, Any}
    model_config_dict::Dict{String, Any}
    model_config::ModelConfig
    sampler_config::SamplerConfig
    prior_sensitivity_config::Union{Nothing, Dict{String, Any}}
    validation_config::Union{Nothing, Dict{String, Any}}
    optimization_config::Union{Nothing, Dict{String, Any}}
    data_manifest::Dict{String, Any}
    data::Union{Nothing, MMMData, PanelMMMData}
    model::Union{Nothing, TimeSeriesMMM, PanelMMM}
    grouped_results::Union{Nothing, InferenceResults}
    flat_results::Union{Nothing, ModelResults}
    stage_records::Vector{PipelineStageRecord}
    started_at_utc::String
    finished_at_utc::Union{Nothing, String}
    status::Symbol
    warnings::Vector{String}
    error::Union{Nothing, Dict{String, Any}}
end

function _validate_pipeline_stage_status(status::Symbol)
    status in _PIPELINE_STAGE_STATUSES ||
        throw(
        ArgumentError(
            "pipeline status must be one of $(join(String.(sort!(collect(_PIPELINE_STAGE_STATUSES))), ", "))",
        ),
    )
    return nothing
end

function _validate_optional_timestamp(value, name::AbstractString)
    isnothing(value) && return nothing
    _validate_nonempty_string(String(value), name)
    return nothing
end

function _pipeline_error_dict(error)
    isnothing(error) && return nothing
    error isa AbstractDict || throw(ArgumentError("pipeline error payloads must be mappings"))
    normalized = Dict{String, Any}(String(key) => value for (key, value) in error)
    for key in ("type", "message", "stage")
        haskey(normalized, key) ||
            throw(ArgumentError("pipeline error payloads must include type, message, and stage"))
    end
    return normalized
end

function _pipeline_timestamp_utc()
    return Dates.format(now(UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
end

function _pipeline_run_stamp()
    return Dates.format(now(UTC), dateformat"yyyymmdd_HHMMSS")
end

function _create_pipeline_run_directory(
        output_dir::AbstractString,
        run_name::AbstractString;
        run_stamp::AbstractString = _pipeline_run_stamp(),
    )
    mkpath(output_dir)
    base_dir = joinpath(String(output_dir), "$(String(run_name))_$(String(run_stamp))")
    candidate = base_dir
    suffix = 2
    while true
        try
            mkdir(candidate)
            return candidate
        catch err
            if ispath(candidate)
                candidate = "$(base_dir)_$(suffix)"
                suffix += 1
                continue
            end
            rethrow(err)
        end
    end
    return
end

function _default_pipeline_run_name(config::PipelineRunConfig)
    !isnothing(config.run_name) && return config.run_name
    return splitext(basename(config.config_path))[1]
end

function _pipeline_stage_directory(key::AbstractString)
    for spec in _PIPELINE_STAGE_SPECS
        spec.key == key && return spec.directory
    end
    throw(ArgumentError("unknown pipeline stage key `$key`"))
end

function _pipeline_stage_optional(key::AbstractString)
    for spec in _PIPELINE_STAGE_SPECS
        spec.key == key && return Bool(spec.optional)
    end
    throw(ArgumentError("unknown pipeline stage key `$key`"))
end

function _initial_pipeline_stage_records(
        prior_sensitivity_config::Union{Nothing, Dict{String, Any}},
        validation_config::Union{Nothing, Dict{String, Any}},
        optimization_config::Union{Nothing, Dict{String, Any}},
    )
    records = PipelineStageRecord[]
    for spec in _PIPELINE_STAGE_SPECS
        status = if spec.key == "prior_sensitivity" && !_pipeline_stage_enabled(prior_sensitivity_config)
            :skipped
        elseif spec.key == "validation" && !_pipeline_stage_enabled(validation_config)
            :skipped
        elseif spec.key == "optimisation" && !_pipeline_stage_enabled(optimization_config)
            :skipped
        else
            :pending
        end
        push!(records, PipelineStageRecord(spec.key, spec.directory; status))
    end
    return records
end

function _pipeline_context(
        config::PipelineRunConfig,
        loaded,
    )
    run_name = _default_pipeline_run_name(config)
    output_dir = abspath(config.output_dir)
    run_dir = _create_pipeline_run_directory(output_dir, run_name)
    manifest_path = joinpath(run_dir, "run_manifest.json")
    started_at_utc = _pipeline_timestamp_utc()
    return PipelineContext(
        config,
        run_name,
        output_dir,
        run_dir,
        manifest_path,
        loaded.dataset_path,
        loaded.source_yaml,
        loaded.raw_config,
        loaded.resolved_config,
        loaded.model_config_dict,
        loaded.model_config,
        loaded.sampler_config,
        loaded.prior_sensitivity_config,
        loaded.validation_config,
        loaded.optimization_config,
        _pipeline_data_manifest(loaded.model_config),
        nothing,
        nothing,
        nothing,
        nothing,
        _initial_pipeline_stage_records(
            loaded.prior_sensitivity_config,
            loaded.validation_config,
            loaded.optimization_config,
        ),
        started_at_utc,
        nothing,
        :pending,
        String[],
        nothing,
    )
end

function _pipeline_model_type(model_config::ModelConfig)
    return isempty(model_config.dims) ? "TimeSeriesMMM" : "PanelMMM"
end

function _pipeline_data_manifest(model_config::ModelConfig)
    event_columns = if haskey(model_config.events, "columns")
        String[String(value) for value in model_config.events["columns"]]
    else
        String[]
    end
    return Dict{String, Any}(
        "n_rows" => nothing,
        "date_column" => model_config.date_column,
        "date_type" => nothing,
        "date_min" => nothing,
        "date_max" => nothing,
        "target_column" => model_config.target_column,
        "channel_columns" => copy(model_config.channel_columns),
        "control_columns" => copy(model_config.control_columns),
        "event_columns" => event_columns,
        "panel_dims" => collect(model_config.dims),
        "panel_columns" => collect(model_config.dims),
        "n_time" => nothing,
        "n_panels" => nothing,
        "panel_names" => String[],
    )
end

function _pipeline_stage_record_dict(record::PipelineStageRecord)
    return Dict{String, Any}(
        "key" => record.key,
        "directory" => record.directory,
        "status" => String(record.status),
        "started_at_utc" => record.started_at_utc,
        "finished_at_utc" => record.finished_at_utc,
        "artifact_paths" => copy(record.artifact_paths),
        "warnings" => copy(record.warnings),
        "error" => isnothing(record.error) ? nothing : copy(record.error),
    )
end

function _pipeline_manifest_dict(context::PipelineContext)
    stages = Dict{String, Any}()
    for record in context.stage_records
        stages[record.key] = _pipeline_stage_record_dict(record)
    end
    return Dict{String, Any}(
        "schema_version" => _PIPELINE_SCHEMA_VERSION,
        "run_name" => context.run_name,
        "status" => String(context.status),
        "config_path" => abspath(context.config.config_path),
        "run_dir" => context.run_dir,
        "output_dir" => context.output_dir,
        "started_at_utc" => context.started_at_utc,
        "finished_at_utc" => context.finished_at_utc,
        "model_type" => _pipeline_model_type(context.model_config),
        "data" => copy(context.data_manifest),
        "stages" => stages,
        "warnings" => copy(context.warnings),
        "error" => isnothing(context.error) ? nothing : copy(context.error),
    )
end

function _stage_index(context::PipelineContext, key::AbstractString)
    index = findfirst(record -> record.key == key, context.stage_records)
    isnothing(index) && throw(ArgumentError("unknown pipeline stage key `$key`"))
    return index
end

function _set_stage_record!(
        context::PipelineContext,
        key::AbstractString;
        status = nothing,
        started_at_utc = nothing,
        finished_at_utc = nothing,
        artifact_paths = nothing,
        warnings = nothing,
        error = nothing,
    )
    index = _stage_index(context, key)
    current = context.stage_records[index]
    updated = PipelineStageRecord(
        current.key,
        current.directory;
        status = isnothing(status) ? current.status : status,
        started_at_utc = isnothing(started_at_utc) ? current.started_at_utc : started_at_utc,
        finished_at_utc = isnothing(finished_at_utc) ? current.finished_at_utc : finished_at_utc,
        artifact_paths = isnothing(artifact_paths) ? current.artifact_paths : artifact_paths,
        warnings = isnothing(warnings) ? current.warnings : warnings,
        error = isnothing(error) ? current.error : error,
    )
    context.stage_records[index] = updated
    return updated
end

function _append_pipeline_warning!(context::PipelineContext, warning::AbstractString)
    push!(context.warnings, String(warning))
    return nothing
end

function _pipeline_relative_stage_artifact(key::AbstractString, filename::AbstractString)
    return joinpath(_pipeline_stage_directory(key), filename)
end

function _stage_directory_path(context::PipelineContext, key::AbstractString)
    return joinpath(context.run_dir, _pipeline_stage_directory(key))
end

function _write_pipeline_text(path::AbstractString, value::AbstractString)
    mkpath(dirname(path))
    open(path, "w") do io
        write(io, value)
    end
    return path
end

function _write_pipeline_yaml(path::AbstractString, value)
    mkpath(dirname(path))
    YAML.write_file(path, value)
    return path
end

function _write_pipeline_json(path::AbstractString, value)
    mkpath(dirname(path))
    open(path, "w") do io
        write(io, JSON3.write(value))
    end
    return path
end

function _skipped_pipeline_stage_reason(context::PipelineContext, key::AbstractString)
    key == "prior_sensitivity" && return if isnothing(context.prior_sensitivity_config)
        "prior_sensitivity is not configured"
    elseif !_pipeline_stage_enabled(context.prior_sensitivity_config)
        "prior_sensitivity.enabled is false"
    else
        "prior_sensitivity was skipped before execution"
    end
    key == "validation" && return if isnothing(context.validation_config)
        "validation is not configured"
    elseif !_pipeline_stage_enabled(context.validation_config)
        "validation.enabled is false"
    else
        "validation was skipped before execution"
    end
    key == "optimisation" && return if isnothing(context.optimization_config)
        "optimization is not configured"
    elseif !_pipeline_stage_enabled(context.optimization_config)
        "optimization.enabled is false"
    else
        "optimisation was skipped before execution"
    end
    return "stage was skipped before execution"
end

function _write_skipped_stage_marker!(
        context::PipelineContext,
        key::AbstractString;
        reason::AbstractString = _skipped_pipeline_stage_reason(context, key),
        generated_at_utc::AbstractString = _pipeline_timestamp_utc(),
    )
    index = _stage_index(context, key)
    record = context.stage_records[index]
    marker_relative_path = _pipeline_relative_stage_artifact(record.key, "SKIPPED.json")
    marker = Dict{String, Any}(
        "schema_version" => _PIPELINE_SCHEMA_VERSION,
        "stage" => record.key,
        "directory" => record.directory,
        "status" => "skipped",
        "reason" => String(reason),
        "optional" => _pipeline_stage_optional(record.key),
        "generated_at_utc" => String(generated_at_utc),
    )
    _write_pipeline_json(joinpath(context.run_dir, marker_relative_path), marker)
    artifact_paths = merge(record.artifact_paths, Dict("skipped_marker" => marker_relative_path))
    _set_stage_record!(context, record.key; artifact_paths)
    return marker
end

function _write_skipped_stage_markers!(context::PipelineContext)
    generated_at_utc = _pipeline_timestamp_utc()
    for record in collect(context.stage_records)
        record.status == :skipped || continue
        _write_skipped_stage_marker!(
            context,
            record.key;
            reason = _skipped_pipeline_stage_reason(context, record.key),
            generated_at_utc,
        )
    end
    return nothing
end

function _write_pipeline_manifest!(context::PipelineContext)
    _write_pipeline_json(context.manifest_path, _pipeline_manifest_dict(context))
    return context.manifest_path
end

function _pipeline_run_result(context::PipelineContext)
    return PipelineRunResult(
        context.run_name,
        context.run_dir,
        context.manifest_path;
        status = context.status,
        config_path = abspath(context.config.config_path),
        started_at_utc = context.started_at_utc,
        finished_at_utc = context.finished_at_utc,
        stage_records = context.stage_records,
        warnings = context.warnings,
        error = context.error,
    )
end

function _pipeline_error_payload(err, stage::Union{Nothing, AbstractString})
    return Dict{String, Any}(
        "type" => string(nameof(typeof(err))),
        "message" => sprint(showerror, err),
        "stage" => isnothing(stage) ? nothing : String(stage),
    )
end
