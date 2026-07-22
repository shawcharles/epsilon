using Dates
using Serialization

const _MODEL_IO_SCHEMA_VERSION = 1
const _MODEL_PAYLOAD_SCHEMA_VERSION = 2

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

Julia serialization artifacts are trusted-local only: deserialization executes
before Epsilon can validate the restored structure. Model payload schema v2
validates retained HSGP media state after deserialization before restoring a
model lifecycle.
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

Julia serialization artifacts are trusted-local only: deserialization can
execute code before Epsilon validates the restored structure. Load only `.jls`
artifacts written by trusted local Epsilon runs. Epsilon validates model payload
lifecycle state after deserialization, including retained HSGP media state in
schema-v2 envelopes.
"""
function load_model(path::AbstractString)
    payload = open(deserialize, path)
    return _model_from_payload(payload)
end

function _model_io_payload(model::TimeSeriesMMM)
    return (
        schema_version = _MODEL_IO_SCHEMA_VERSION,
        model_payload_schema_version = _MODEL_PAYLOAD_SCHEMA_VERSION,
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
        model_payload_schema_version = _MODEL_PAYLOAD_SCHEMA_VERSION,
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

    config = get(payload, :config, nothing)
    config isa ModelConfig || throw(ArgumentError("serialized model payload must include ModelConfig"))
    sampler_config = get(payload, :sampler_config, nothing)
    sampler_config isa SamplerConfig ||
        throw(ArgumentError("serialized model payload must include SamplerConfig"))
    data = get(payload, :data, nothing)
    built_model = get(payload, :built_model, nothing)
    fit_state = _restore_fit_state(get(payload, :fit_state, nothing))
    calibration = get(payload, :calibration, nothing)
    payload_version = _model_payload_schema_version(payload)

    _validate_model_envelope_fit_state(metadata, fit_state)

    _validate_model_payload_hsgp_state(
        payload_version,
        model_type,
        config,
        data,
        built_model,
        fit_state,
        calibration,
    )

    model = if model_type == "TimeSeriesMMM"
        data isa MMMData || throw(ArgumentError("TimeSeriesMMM payload must include MMMData"))
        TimeSeriesMMM(config, sampler_config, data)
    elseif model_type == "PanelMMM"
        data isa PanelMMMData || throw(ArgumentError("PanelMMM payload must include PanelMMMData"))
        PanelMMM(config, sampler_config, data)
    else
        throw(ArgumentError("unsupported serialized model type"))
    end
    model.built_model = built_model
    model.fit_state = fit_state
    model isa TimeSeriesMMM && (model.calibration = calibration)
    return model
end

function _model_payload_schema_version(payload::NamedTuple)
    version = get(payload, :model_payload_schema_version, 1)
    version isa Integer && !(version isa Bool) ||
        throw(ArgumentError("serialized model payload schema discriminator must be an integer"))
    version in (1, _MODEL_PAYLOAD_SCHEMA_VERSION) ||
        throw(ArgumentError("unsupported serialized model payload schema version"))
    return Int(version)
end

function _validate_model_payload_hsgp_state(
        payload_version::Int,
        model_type::AbstractString,
        config::ModelConfig,
        data,
        built_model,
        fit_state,
        calibration,
    )
    configured = !isnothing(_time_varying_media_config(config))
    built_spec = _serialized_model_spec(built_model, "built_model")
    artifact_spec = _serialized_fit_artifact_spec(fit_state)
    built_has_state = _spec_has_hsgp_media_state(built_spec)
    artifact_has_state = _spec_has_hsgp_media_state(artifact_spec)

    if payload_version == 1
        !(configured || built_has_state || artifact_has_state) || throw(
            ArgumentError("legacy model payload schema v1 does not support HSGP media state"),
        )
        return nothing
    end

    if !configured
        !(built_has_state || artifact_has_state) || throw(
            ArgumentError("ordinary model payloads must not contain HSGP media state"),
        )
        return nothing
    end

    model_type == "TimeSeriesMMM" || throw(
        ArgumentError("time_varying_media model payloads support only TimeSeriesMMM"),
    )
    data isa MMMData || throw(ArgumentError("time_varying_media model payloads require MMMData"))
    _reject_hsgp_media_calibration(config, calibration)

    if isnothing(fit_state)
        isnothing(artifact_spec) || throw(
            ArgumentError("unfitted HSGP media model payloads must not include an artifact spec"),
        )
        isnothing(built_spec) && return nothing
        _validate_hsgp_media_state_for_model_data(built_spec, data, "built_model")
        return nothing
    end

    fit_state.status === :fit || throw(
        ArgumentError("HSGP media model payload fit state must have status :fit"),
    )
    !isnothing(built_spec) || throw(
        ArgumentError("fitted HSGP media model payloads must include built_model state"),
    )
    !isnothing(artifact_spec) || throw(
        ArgumentError("fitted HSGP media model payloads must include an artifact spec"),
    )
    built_state = _validate_hsgp_media_state_for_model_data(built_spec, data, "built_model")
    artifact_state = _validate_hsgp_media_state_for_model_data(
        artifact_spec,
        data,
        "fit artifact spec",
    )
    _hsgp_media_spec_states_equal(built_state, artifact_state) || throw(
        ArgumentError("fitted HSGP media built_model and artifact spec state must match"),
    )
    return nothing
end

function _serialized_model_spec(value, label::AbstractString)
    isnothing(value) && return nothing
    value isa MMMModelSpec || throw(ArgumentError("serialized $label must be MMMModelSpec or nothing"))
    return value
end

function _serialized_fit_artifact_spec(fit_state::Nothing)
    return nothing
end

function _serialized_fit_artifact_spec(fit_state::ModelFitState)
    artifact = fit_state.artifact
    isnothing(artifact) && return nothing
    hasproperty(artifact, :spec) || return nothing
    return _serialized_model_spec(getproperty(artifact, :spec), "fit state artifact spec")
end

_spec_has_hsgp_media_state(::Nothing) = false

function _spec_has_hsgp_media_state(spec::MMMModelSpec)
    return haskey(spec.priors, _HSGP_MEDIA_SPEC_STATE_KEY)
end

function _validate_embedded_hsgp_media_spec(spec::MMMModelSpec)
    _spec_has_hsgp_media_state(spec) || return nothing
    spec.model_kind === :time_series_mmm || throw(
        ArgumentError("HSGP media state is valid only for time-series model specifications"),
    )
    state = spec.priors[_HSGP_MEDIA_SPEC_STATE_KEY]
    state isa _HSGPMediaSpecState || throw(
        ArgumentError("$(_HSGP_MEDIA_SPEC_STATE_KEY) must contain _HSGPMediaSpecState"),
    )
    _validate_hsgp_media_spec_state_canonical(state)
    return state
end

function _validate_hsgp_media_state_for_model_data(
        spec::MMMModelSpec,
        data::MMMData,
        label::AbstractString,
    )
    state = _validate_embedded_hsgp_media_spec(spec)
    isnothing(state) && throw(ArgumentError("$label must contain HSGP media state"))
    training = state.training
    dates = data.dates
    dates isa AbstractVector && all(date -> date isa Date, dates) || throw(
        ArgumentError("$label HSGP media state requires MMMData.dates to contain Date values"),
    )
    training_dates = Date[date for date in dates]
    isempty(training_dates) && throw(ArgumentError("$label HSGP media state requires non-empty training dates"))
    expected_indices = _infer_hsgp_time_index(
        training_dates,
        training_dates;
        time_resolution = training.time_resolution,
    )
    expected_centre = minimum(expected_indices) / 2 + maximum(expected_indices) / 2
    training.training_origin == first(training_dates) || throw(
        ArgumentError("$label HSGP media training origin does not match model data"),
    )
    training.training_indices == Tuple(expected_indices) || throw(
        ArgumentError("$label HSGP media cadence indices do not match model data"),
    )
    training.training_centre == Float64(expected_centre) || throw(
        ArgumentError("$label HSGP media training centre does not match model data"),
    )
    return state
end

function _validate_hsgp_media_spec_state_canonical(state::_HSGPMediaSpecState)
    config = state.config
    _hsgp_media_int(config.m, "HSGP media snapshot m")
    _hsgp_media_float64(config.L, "HSGP media snapshot L"; positive = true)
    _hsgp_media_int(config.time_resolution, "HSGP media snapshot time_resolution")
    config.covariance in _HSGP_MEDIA_COVARIANCES || throw(
        ArgumentError("HSGP media snapshot covariance is unsupported"),
    )
    _validate_hsgp_media_spec_state(state)
    _validate_hsgp_media_prior_snapshot_canonical(config.eta_prior, "eta_prior")
    _validate_hsgp_media_prior_snapshot_canonical(
        config.lengthscale_prior,
        "lengthscale_prior",
    )
    return state
end

function _validate_hsgp_media_prior_snapshot_canonical(
        snapshot::_HSGPMediaPriorSnapshot,
        label::AbstractString,
    )
    distribution = String(snapshot.distribution)
    distribution in _HSGP_MEDIA_PRIOR_DISTRIBUTIONS || throw(
        ArgumentError("$label snapshot has an unsupported distribution"),
    )
    parameters = snapshot.parameters
    expected_names = if distribution == "Exponential"
        (:lam,)
    elseif distribution == "Gamma"
        (:alpha, :beta)
    elseif distribution == "HalfNormal"
        (:sigma,)
    else
        (:mu, :sigma)
    end
    length(parameters) == length(expected_names) || throw(
        ArgumentError("$label snapshot has an invalid parameter count"),
    )
    all(parameters[index][1] == expected_names[index] for index in eachindex(expected_names)) || throw(
        ArgumentError("$label snapshot parameter names are not canonical"),
    )
    for (name, value) in parameters
        value isa Float64 && isfinite(value) || throw(
            ArgumentError("$label snapshot parameter $name must be a finite Float64"),
        )
        (distribution == "LogNormal" && name == :mu || value > 0.0) || throw(
            ArgumentError("$label snapshot parameter $name must be positive"),
        )
    end
    prior = EpsilonPrior(distribution, Dict{Symbol, Any}(parameters))
    _validate_hsgp_media_prior(prior, label)
    _instantiate_hsgp_media_prior(snapshot)
    return snapshot
end

function _hsgp_media_spec_states_equal(
        lhs::_HSGPMediaSpecState,
        rhs::_HSGPMediaSpecState,
    )
    lhs_config = lhs.config
    rhs_config = rhs.config
    lhs_training = lhs.training
    rhs_training = rhs.training
    return lhs_config.m == rhs_config.m &&
        lhs_config.L == rhs_config.L &&
        lhs_config.time_resolution == rhs_config.time_resolution &&
        lhs_config.covariance == rhs_config.covariance &&
        _hsgp_media_prior_snapshots_equal(lhs_config.eta_prior, rhs_config.eta_prior) &&
        _hsgp_media_prior_snapshots_equal(
        lhs_config.lengthscale_prior,
        rhs_config.lengthscale_prior,
    ) &&
        lhs_training.training_origin == rhs_training.training_origin &&
        lhs_training.time_resolution == rhs_training.time_resolution &&
        lhs_training.training_indices == rhs_training.training_indices &&
        lhs_training.training_centre == rhs_training.training_centre &&
        lhs_training.m == rhs_training.m &&
        lhs_training.L == rhs_training.L &&
        lhs_training.covariance == rhs_training.covariance &&
        lhs_training.drop_first == rhs_training.drop_first &&
        lhs_training.demeaned_basis == rhs_training.demeaned_basis
end

function _hsgp_media_prior_snapshots_equal(
        lhs::_HSGPMediaPriorSnapshot,
        rhs::_HSGPMediaPriorSnapshot,
    )
    return lhs.distribution == rhs.distribution && lhs.parameters == rhs.parameters
end


function _restore_fit_state(state_payload::Nothing)
    return nothing
end

function _restore_fit_state(state_payload::NamedTuple)
    all(name -> hasproperty(state_payload, name), (:status, :backend, :artifact, :message)) ||
        throw(ArgumentError("serialized fit state payload is incomplete"))
    state_payload.status isa Symbol || throw(ArgumentError("serialized fit state status must be a Symbol"))
    state_payload.backend isa Symbol || throw(ArgumentError("serialized fit state backend must be a Symbol"))
    _validate_backend_policy(state_payload.backend; context = "serialized fit state")
    state_payload.message isa AbstractString ||
        throw(ArgumentError("serialized fit state message must be a string"))
    return ModelFitState(
        state_payload.status,
        state_payload.backend;
        artifact = state_payload.artifact,
        message = state_payload.message,
    )
end

function _validate_backend_policy(
        backend::Union{Nothing, Symbol};
        context::AbstractString,
        allow_fixture::Bool = false,
        allow_unfitted::Bool = false,
    )
    backend === :turing && return nothing
    allow_fixture && backend === :fixture && return nothing
    allow_unfitted && isnothing(backend) && return nothing
    allowed = allow_fixture ? "Turing/MCMC or deterministic fixture" : "Turing/MCMC"
    allow_unfitted && (allowed *= ", or an unfitted no-chain container")
    throw(ArgumentError("$context supports only $allowed"))
end

function _validate_result_metadata(
        metadata::ModelArtifactMetadata,
        components...;
        context::AbstractString,
    )
    allow_unfitted = isnothing(metadata.fit_status) && all(isnothing, components)
    return _validate_backend_policy(
        metadata.backend;
        context,
        allow_fixture = true,
        allow_unfitted,
    )
end

function _validate_model_envelope_fit_state(
        metadata::ModelArtifactMetadata,
        fit_state::Union{Nothing, ModelFitState},
    )
    if isnothing(fit_state)
        isnothing(metadata.backend) && isnothing(metadata.fit_status) ||
            throw(ArgumentError("serialized model metadata must be unfitted when no fit state is present"))
        return nothing
    end

    metadata.backend === fit_state.backend ||
        throw(ArgumentError("serialized model metadata backend must match the restored fit state backend"))
    metadata.fit_status === fit_state.status ||
        throw(ArgumentError("serialized model metadata fit status must match the restored fit state status"))
    return nothing
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
    _validate_backend_policy(
        metadata.backend;
        context = "serialized artifact metadata",
        allow_fixture = true,
        allow_unfitted = isnothing(metadata.fit_status),
    )
    return nothing
end
