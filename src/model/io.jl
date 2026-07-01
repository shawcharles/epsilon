using Dates
using Serialization

const _MODEL_IO_SCHEMA_VERSION = 1

"""
    ModelArtifactMetadata

Serializable metadata attached to saved and fitted model artifacts.
"""
struct ModelArtifactMetadata
    schema_version::Int
    epsilon_version::VersionNumber
    julia_version::VersionNumber
    created_at_utc::String
    model_type::String
    backend::Union{Nothing, Symbol}
    fit_status::Union{Nothing, Symbol}
end

function Base.:(==)(lhs::ModelArtifactMetadata, rhs::ModelArtifactMetadata)
    return lhs.schema_version == rhs.schema_version &&
           lhs.epsilon_version == rhs.epsilon_version &&
           lhs.julia_version == rhs.julia_version &&
           lhs.created_at_utc == rhs.created_at_utc &&
           lhs.model_type == rhs.model_type &&
           lhs.backend == rhs.backend &&
           lhs.fit_status == rhs.fit_status
end

"""
    save_model(path, model)

Serialize a typed Epsilon model object to `path`.

The current implementation persists the typed model/config/data state plus any
fitted chain artifacts and metadata needed to resume posterior predictive use.
Ephemeral backend closures are rebuilt on demand rather than written to disk.
"""
function save_model(path::AbstractString, model::Union{TimeSeriesMMM, PanelMMM})
    payload = _model_io_payload(model)
    open(path, "w") do io
        serialize(io, payload)
    end
    return path
end

"""
    load_model(path)

Load a serialized Epsilon model object from `path`.
"""
function load_model(path::AbstractString)
    payload = open(deserialize, path)
    return _model_from_payload(payload)
end

function _model_io_payload(model::TimeSeriesMMM)
    return (
        schema_version = _MODEL_IO_SCHEMA_VERSION,
        metadata = _artifact_metadata(
            "TimeSeriesMMM";
            backend = isnothing(model.fit_state) ? nothing : model.fit_state.backend,
            fit_status = isnothing(model.fit_state) ? nothing : model.fit_state.status,
        ),
        model_type = "TimeSeriesMMM",
        config = model.config,
        sampler_config = model.sampler_config,
        data = model.data,
        built_model = model.built_model,
        fit_state = _serializable_fit_state(model.fit_state),
        calibration = model.calibration,
    )
end

function _model_io_payload(model::PanelMMM)

    return (
        schema_version = _MODEL_IO_SCHEMA_VERSION,
        metadata = _artifact_metadata(
            "PanelMMM";
            backend = isnothing(model.fit_state) ? nothing : model.fit_state.backend,
            fit_status = isnothing(model.fit_state) ? nothing : model.fit_state.status,
        ),
        model_type = "PanelMMM",
        config = model.config,
        sampler_config = model.sampler_config,
        data = model.data,
        built_model = model.built_model,
        fit_state = _serializable_fit_state(model.fit_state),
    )
end

function _serializable_fit_state(state::Nothing)
    return nothing
end

function _serializable_fit_state(state::ModelFitState)
    return (
        status = state.status,
        backend = state.backend,
        artifact = _serializable_artifact(state.artifact),
        message = state.message,
    )
end

function _serializable_artifact(artifact)
    if artifact isa NamedTuple
        output = (; artifact...)
        if hasproperty(output, :model)
            fields = Base.structdiff(output, NamedTuple{(:model,)})
            return fields
        end
        return output
    end
    return artifact
end

function _model_from_payload(payload)
    payload isa NamedTuple || throw(ArgumentError("serialized model payload must be a named tuple"))
    get(payload, :schema_version, nothing) == _MODEL_IO_SCHEMA_VERSION ||
        throw(ArgumentError("unsupported model artifact schema version"))
    metadata = get(payload, :metadata, nothing)
    metadata isa ModelArtifactMetadata ||
        throw(ArgumentError("serialized model payload must include ModelArtifactMetadata"))
    model_type = get(payload, :model_type, nothing)
    model_type isa AbstractString || throw(ArgumentError("unsupported serialized model type"))
    _validate_artifact_metadata(metadata; expected_model_type = model_type)

    model = if model_type == "TimeSeriesMMM"
        TimeSeriesMMM(
            payload.config,
            payload.sampler_config,
            payload.data,
        )
    elseif model_type == "PanelMMM"
        PanelMMM(
            payload.config,
            payload.sampler_config,
            payload.data,
        )
    else
        throw(ArgumentError("unsupported serialized model type"))
    end
    model.built_model = get(payload, :built_model, nothing)
    model.fit_state = _restore_fit_state(get(payload, :fit_state, nothing))
    if model isa TimeSeriesMMM
        model.calibration = get(payload, :calibration, nothing)
    end
    return model
end


function _restore_fit_state(state_payload::Nothing)
    return nothing
end

function _restore_fit_state(state_payload::NamedTuple)
    return ModelFitState(
        state_payload.status,
        state_payload.backend;
        artifact = state_payload.artifact,
        message = state_payload.message,
    )
end

function _artifact_metadata(
    model_type::AbstractString;
    backend::Union{Nothing, Symbol} = nothing,
    fit_status::Union{Nothing, Symbol} = nothing,
)
    return ModelArtifactMetadata(
        _MODEL_IO_SCHEMA_VERSION,
        pkgversion(@__MODULE__),
        VERSION,
        Dates.format(now(UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ"),
        String(model_type),
        backend,
        fit_status,
    )
end

function _validate_artifact_metadata(
    metadata::ModelArtifactMetadata;
    expected_model_type::Union{Nothing, AbstractString} = nothing,
)
    metadata.schema_version == _MODEL_IO_SCHEMA_VERSION ||
        throw(ArgumentError("serialized metadata schema version does not match the loader"))
    metadata.epsilon_version == pkgversion(@__MODULE__) ||
        throw(ArgumentError("serialized artifact was created with Epsilon $(metadata.epsilon_version), but the current version is $(pkgversion(@__MODULE__))"))
    metadata.julia_version == VERSION ||
        throw(ArgumentError("serialized artifact was created with Julia $(metadata.julia_version), but the current version is $(VERSION)"))
    if !isnothing(expected_model_type)
        metadata.model_type == expected_model_type ||
            throw(ArgumentError("serialized artifact metadata model type $(metadata.model_type) does not match expected $(expected_model_type)"))
    end
    return nothing
end
