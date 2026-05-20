"""
    ModelResults(metadata, spec, chain; posterior_predictive=nothing, prior_predictive=nothing)

Typed flat fitted-results container for the current MMM model path.

`ModelResults` remains the lighter convenience surface. For the richer grouped
artifact introduced in Phase 6, use `InferenceResults` via
`inference_results(model; ...)`.
"""
struct ModelResults{C, P, Q}
    metadata::ModelArtifactMetadata
    spec::MMMModelSpec
    chain::C
    posterior_predictive::P
    prior_predictive::Q
end

function Base.:(==)(lhs::ModelResults, rhs::ModelResults)
    return lhs.metadata == rhs.metadata &&
           lhs.spec == rhs.spec &&
           _results_component_equal(lhs.chain, rhs.chain) &&
           _results_component_equal(lhs.posterior_predictive, rhs.posterior_predictive) &&
           _results_component_equal(lhs.prior_predictive, rhs.prior_predictive)
end

_results_component_equal(::Nothing, ::Nothing) = true

function _results_component_equal(lhs, rhs)
    lhs == rhs && return true
    try
        return Array(lhs) == Array(rhs) && names(lhs) == names(rhs)
    catch
        return false
    end
end

function ModelResults(
    metadata::ModelArtifactMetadata,
    spec::MMMModelSpec,
    chain;
    posterior_predictive = nothing,
    prior_predictive = nothing,
)
    return ModelResults{typeof(chain), typeof(posterior_predictive), typeof(prior_predictive)}(
        metadata,
        spec,
        chain,
        posterior_predictive,
        prior_predictive,
    )
end

"""
    model_results(model; new_data=model.data, include_posterior_predictive=true, include_prior_predictive=false)

Extract the flat convenience results object from a Turing-backed fitted model.

The richer grouped `InferenceResults` surface is the backend-agnostic artifact
entry point for supported variational fits.
"""
function model_results(
    model::TimeSeriesMMM;
    new_data::MMMData = model.data,
    include_posterior_predictive::Bool = true,
    include_prior_predictive::Bool = false,
)
    state = _require_successful_turing_fit(model.fit_state, "model_results")

    artifact = state.artifact
    hasproperty(artifact, :spec) ||
        throw(ArgumentError("fit artifact must include a model specification"))
    hasproperty(artifact, :chain) ||
        throw(ArgumentError("fit artifact must include posterior chains"))
    hasproperty(artifact, :metadata) ||
        throw(ArgumentError("fit artifact must include typed metadata"))

    posterior_predictive = include_posterior_predictive ? _predict_time_series_mmm(model, new_data) : nothing
    prior_predictive = include_prior_predictive ? _prior_predict_time_series_mmm(model, new_data) : nothing
    control_transform_state = hasproperty(artifact, :runtime) &&
                              hasproperty(artifact.runtime, :control_transform_state) ?
        artifact.runtime.control_transform_state : nothing
    spec = _build_model_spec(
        artifact.spec,
        new_data;
        control_transform_state,
    )
    return ModelResults(
        artifact.metadata,
        spec,
        artifact.chain;
        posterior_predictive,
        prior_predictive,
    )
end

function model_results(
    model::PanelMMM;
    new_data::PanelMMMData = model.data,
    include_posterior_predictive::Bool = true,
    include_prior_predictive::Bool = false,
)
    state = _require_successful_turing_fit(model.fit_state, "model_results")

    artifact = state.artifact
    hasproperty(artifact, :spec) ||
        throw(ArgumentError("fit artifact must include a model specification"))
    hasproperty(artifact, :chain) ||
        throw(ArgumentError("fit artifact must include posterior chains"))
    hasproperty(artifact, :metadata) ||
        throw(ArgumentError("fit artifact must include typed metadata"))

    posterior_predictive = include_posterior_predictive ? _predict_panel_mmm(model, new_data) : nothing
    prior_predictive = include_prior_predictive ? _prior_predict_panel_mmm(model, new_data) : nothing
    spec = _build_model_spec(artifact.spec, new_data)
    return ModelResults(
        artifact.metadata,
        spec,
        artifact.chain;
        posterior_predictive,
        prior_predictive,
    )
end

"""
    save_results(path, results)

Serialize a typed results object to `path`.
"""
function save_results(path::AbstractString, results::ModelResults)
    payload = (
        schema_version = _MODEL_IO_SCHEMA_VERSION,
        metadata = results.metadata,
        spec = results.spec,
        chain = results.chain,
        posterior_predictive = results.posterior_predictive,
        prior_predictive = results.prior_predictive,
    )
    open(path, "w") do io
        serialize(io, payload)
    end
    return path
end

"""
    load_results(path)

Load a serialized `ModelResults` object from `path`.
"""
function load_results(path::AbstractString)
    payload = open(deserialize, path)
    payload isa NamedTuple || throw(ArgumentError("serialized results payload must be a named tuple"))
    get(payload, :schema_version, nothing) == _MODEL_IO_SCHEMA_VERSION ||
        throw(ArgumentError("unsupported results artifact schema version"))
    metadata = get(payload, :metadata, nothing)
    metadata isa ModelArtifactMetadata ||
        throw(ArgumentError("serialized results payload must include ModelArtifactMetadata"))
    _validate_artifact_metadata(metadata)
    spec = get(payload, :spec, nothing)
    spec isa MMMModelSpec ||
        throw(ArgumentError("serialized results payload must include MMMModelSpec"))
    chain = get(payload, :chain, nothing)
    return ModelResults(
        metadata,
        spec,
        chain;
        posterior_predictive = get(payload, :posterior_predictive, nothing),
        prior_predictive = get(payload, :prior_predictive, nothing),
    )
end
