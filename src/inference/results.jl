"""
    InferenceSampleStats(; internals=nothing, diagnostics=nothing, sampler_diagnostics=nothing, sampler_warnings=nothing, convergence_report=nothing, convergence_warnings=nothing)

Typed grouped sample-statistics bundle for the canonical `InferenceResults`
surface.
"""
struct InferenceSampleStats{C}
    internals::C
    diagnostics::Union{Nothing, ModelDiagnostics}
    sampler_diagnostics::Union{Nothing, SamplerDiagnostics}
    sampler_warnings::Union{Nothing, SamplerWarnings}
    convergence_report::Union{Nothing, ConvergenceReport}
    convergence_warnings::Union{Nothing, ConvergenceWarnings}
end

function Base.:(==)(lhs::InferenceSampleStats, rhs::InferenceSampleStats)
    return _results_component_equal(lhs.internals, rhs.internals) &&
        lhs.diagnostics == rhs.diagnostics &&
        lhs.sampler_diagnostics == rhs.sampler_diagnostics &&
        lhs.sampler_warnings == rhs.sampler_warnings &&
        lhs.convergence_report == rhs.convergence_report &&
        lhs.convergence_warnings == rhs.convergence_warnings
end

function InferenceSampleStats(;
        internals = nothing,
        diagnostics = nothing,
        sampler_diagnostics = nothing,
        sampler_warnings = nothing,
        convergence_report = nothing,
        convergence_warnings = nothing,
    )
    return InferenceSampleStats{typeof(internals)}(
        internals,
        diagnostics,
        sampler_diagnostics,
        sampler_warnings,
        convergence_report,
        convergence_warnings,
    )
end

"""
    InferenceResults(metadata, spec; posterior=nothing, prior=nothing, posterior_predictive=nothing, prior_predictive=nothing, sample_stats=InferenceSampleStats(), observed_data=nothing)

Canonical grouped inference-artifact surface for fitted MMM models.

`ModelResults` remains the lighter flat convenience container. `InferenceResults`
is the richer grouped surface that preserves posterior draws, optional prior
draws, predictive draws, sampler statistics, observed data, and coordinate
metadata together.
"""
struct InferenceResults{P, Q, R, S, T}
    metadata::ModelArtifactMetadata
    spec::MMMModelSpec
    coordinate_metadata::ModelCoordinateMetadata
    posterior::P
    prior::Q
    posterior_predictive::R
    prior_predictive::S
    sample_stats::InferenceSampleStats
    observed_data::T
end

function Base.:(==)(lhs::InferenceResults, rhs::InferenceResults)
    return lhs.metadata == rhs.metadata &&
        lhs.spec == rhs.spec &&
        lhs.coordinate_metadata == rhs.coordinate_metadata &&
        _results_component_equal(lhs.posterior, rhs.posterior) &&
        _results_component_equal(lhs.prior, rhs.prior) &&
        _results_component_equal(lhs.posterior_predictive, rhs.posterior_predictive) &&
        _results_component_equal(lhs.prior_predictive, rhs.prior_predictive) &&
        lhs.sample_stats == rhs.sample_stats &&
        lhs.observed_data == rhs.observed_data
end

function InferenceResults(
        metadata::ModelArtifactMetadata,
        spec::MMMModelSpec;
        posterior = nothing,
        prior = nothing,
        posterior_predictive = nothing,
        prior_predictive = nothing,
        sample_stats = InferenceSampleStats(),
        observed_data = nothing,
    )
    _validate_result_metadata(
        metadata,
        posterior,
        prior,
        posterior_predictive,
        prior_predictive,
        sample_stats.internals;
        context = "InferenceResults",
    )
    return InferenceResults{
        typeof(posterior),
        typeof(prior),
        typeof(posterior_predictive),
        typeof(prior_predictive),
        typeof(observed_data),
    }(
        metadata,
        spec,
        spec.coordinate_metadata,
        posterior,
        prior,
        posterior_predictive,
        prior_predictive,
        sample_stats,
        observed_data,
    )
end

"""
    inference_results(model; new_data=model.data, include_prior=true, include_posterior_predictive=true, include_prior_predictive=true)

Extract the canonical grouped inference-results artifact from a fitted model.

This grouped surface is additive to `model_results(model; ...)`: the existing
`ModelResults` container remains the flatter convenience view, while
`InferenceResults` preserves grouped posterior, prior, predictive, sample-stat,
and observed-data content together for supported Turing-backed fits.
"""
function inference_results(
        model::TimeSeriesMMM;
        new_data::MMMData = model.data,
        include_prior::Bool = true,
        include_posterior_predictive::Bool = true,
        include_prior_predictive::Bool = true,
    )
    state = _require_successful_posterior_fit(model.fit_state, "inference_results")
    artifact = _require_grouped_inference_artifact(state.artifact)

    posterior_predictive = include_posterior_predictive ? predict(model, new_data) : nothing
    prior_chain = if include_prior || include_prior_predictive
        _prior_predict_time_series_mmm(
            model,
            new_data;
            draws_override = nothing,
            chains_override = nothing,
            cores_override = nothing,
        )
    else
        nothing
    end
    control_transform_state = hasproperty(artifact, :runtime) &&
        hasproperty(artifact.runtime, :control_transform_state) ?
        artifact.runtime.control_transform_state : nothing
    spec = _build_model_spec(
        artifact.spec,
        new_data;
        control_transform_state,
    )
    return InferenceResults(
        artifact.metadata,
        spec;
        posterior = _parameter_chain(artifact.chain),
        prior = include_prior ? _non_target_chain(prior_chain) : nothing,
        posterior_predictive,
        prior_predictive = include_prior_predictive ? _target_chain(prior_chain) : nothing,
        sample_stats = _grouped_sample_stats(artifact),
        observed_data = new_data,
    )
end

function inference_results(
        model::PanelMMM;
        new_data::PanelMMMData = model.data,
        include_prior::Bool = true,
        include_posterior_predictive::Bool = true,
        include_prior_predictive::Bool = true,
    )
    state = _require_successful_posterior_fit(model.fit_state, "inference_results")
    artifact = _require_grouped_inference_artifact(state.artifact)

    posterior_predictive = include_posterior_predictive ? predict(model, new_data) : nothing
    prior_chain = (include_prior || include_prior_predictive) ? prior_predict(model, new_data) : nothing
    spec = _build_model_spec(artifact.spec, new_data)
    return InferenceResults(
        artifact.metadata,
        spec;
        posterior = _parameter_chain(artifact.chain),
        prior = include_prior ? _non_target_chain(prior_chain) : nothing,
        posterior_predictive,
        prior_predictive = include_prior_predictive ? _target_chain(prior_chain) : nothing,
        sample_stats = _grouped_sample_stats(artifact),
        observed_data = new_data,
    )
end

"""
    save_inference_results(path, results)

Serialize a grouped `InferenceResults` artifact to `path`.
"""
function save_inference_results(path::AbstractString, results::InferenceResults)
    payload = (
        schema_version = _MODEL_IO_SCHEMA_VERSION,
        metadata = results.metadata,
        spec = results.spec,
        coordinate_metadata = results.coordinate_metadata,
        posterior = results.posterior,
        prior = results.prior,
        posterior_predictive = results.posterior_predictive,
        prior_predictive = results.prior_predictive,
        sample_stats = results.sample_stats,
        observed_data = results.observed_data,
    )
    open(path, "w") do io
        serialize(io, payload)
    end
    return path
end

"""
    load_inference_results(path)

Load a serialized `InferenceResults` artifact from `path`.
"""
function load_inference_results(path::AbstractString)
    payload = open(deserialize, path)
    payload isa NamedTuple ||
        throw(ArgumentError("serialized inference-results payload must be a named tuple"))
    get(payload, :schema_version, nothing) == _MODEL_IO_SCHEMA_VERSION ||
        throw(ArgumentError("unsupported inference-results artifact schema version"))

    metadata = get(payload, :metadata, nothing)
    metadata isa ModelArtifactMetadata ||
        throw(
        ArgumentError(
            "serialized inference-results payload must include ModelArtifactMetadata",
        ),
    )
    _validate_artifact_metadata(metadata)

    spec = get(payload, :spec, nothing)
    spec isa MMMModelSpec ||
        throw(ArgumentError("serialized inference-results payload must include MMMModelSpec"))

    coordinate_metadata = get(payload, :coordinate_metadata, nothing)
    coordinate_metadata isa ModelCoordinateMetadata ||
        throw(
        ArgumentError(
            "serialized inference-results payload must include ModelCoordinateMetadata",
        ),
    )
    coordinate_metadata == spec.coordinate_metadata ||
        throw(
        ArgumentError(
            "serialized inference-results coordinate metadata must match the stored MMMModelSpec",
        ),
    )
    _validate_embedded_hsgp_media_spec(spec)

    sample_stats = get(payload, :sample_stats, nothing)
    sample_stats isa InferenceSampleStats ||
        throw(
        ArgumentError(
            "serialized inference-results payload must include InferenceSampleStats",
        ),
    )

    observed_data = get(payload, :observed_data, nothing)
    observed_data isa Union{Nothing, MMMData, PanelMMMData} ||
        throw(
        ArgumentError(
            "serialized inference-results payload must include nothing, MMMData, or PanelMMMData",
        ),
    )

    return InferenceResults(
        metadata,
        spec;
        posterior = get(payload, :posterior, nothing),
        prior = get(payload, :prior, nothing),
        posterior_predictive = get(payload, :posterior_predictive, nothing),
        prior_predictive = get(payload, :prior_predictive, nothing),
        sample_stats = sample_stats,
        observed_data = observed_data,
    )
end

function _require_grouped_inference_artifact(artifact)
    hasproperty(artifact, :metadata) ||
        throw(ArgumentError("fit artifact must include typed metadata"))
    hasproperty(artifact, :spec) ||
        throw(ArgumentError("fit artifact must include a model specification"))
    hasproperty(artifact, :chain) ||
        throw(ArgumentError("fit artifact must include posterior chains"))
    return artifact
end

function _grouped_sample_stats(artifact)
    chain = artifact.chain
    return InferenceSampleStats(
        internals = _internal_chain(chain),
        diagnostics = hasproperty(artifact, :diagnostics) ? artifact.diagnostics : nothing,
        sampler_diagnostics = hasproperty(artifact, :sampler_diagnostics) ? artifact.sampler_diagnostics : nothing,
        sampler_warnings = hasproperty(artifact, :sampler_warnings) ? artifact.sampler_warnings : nothing,
        convergence_report = hasproperty(artifact, :convergence_report) ? artifact.convergence_report : nothing,
        convergence_warnings = hasproperty(artifact, :convergence_warnings) ? artifact.convergence_warnings : nothing,
    )
end

function _parameter_chain(chain)
    parameter_names = names(chain, :parameters)
    isempty(parameter_names) && return nothing
    return chain[parameter_names]
end

function _internal_chain(chain)
    internal_names = names(chain, :internals)
    isempty(internal_names) && return nothing
    return chain[internal_names]
end

function _target_chain(chain)
    isnothing(chain) && return nothing
    target_names = filter(name -> startswith(String(name), "target["), names(chain, :parameters))
    isempty(target_names) && return nothing
    return chain[target_names]
end

function _non_target_chain(chain)
    isnothing(chain) && return nothing
    parameter_names = filter(
        name -> !startswith(String(name), "target["),
        names(chain, :parameters),
    )
    isempty(parameter_names) && return nothing
    return chain[parameter_names]
end
