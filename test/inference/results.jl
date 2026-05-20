using Epsilon
using Serialization
using Test

function _same_chain_content(lhs, rhs)
    return Array(lhs) == Array(rhs) && names(lhs) == names(rhs)
end

@testset "inference_results for TimeSeriesMMM" begin
    model = sample_results_model()
    new_data = MMMData(
        dates = 1:4,
        target = [4.0, 5.0, 6.0, 7.0],
        channels = [1.0 0.5; 2.0 1.0; 3.0 1.5; 4.0 2.0],
        channel_names = ["tv", "search"],
        controls = [0.2; 0.4; 0.6; 0.8][:, :],
        control_names = ["price_index"],
    )

    grouped = inference_results(model; new_data, include_prior = true, include_prior_predictive = true)
    expected_spec = Epsilon._build_model_spec(
        model.fit_state.artifact.spec,
        new_data;
        control_transform_state = model.fit_state.artifact.runtime.control_transform_state,
    )
    @test grouped isa InferenceResults
    @test grouped.metadata == model.fit_state.artifact.metadata
    @test grouped.spec == expected_spec
    @test grouped.coordinate_metadata == grouped.spec.coordinate_metadata
    @test grouped.observed_data == new_data
    @test grouped.spec.nobs == 4
    @test grouped.coordinate_metadata.coordinates["observation"] == string.(1:4)
    @test _same_chain_content(
        grouped.posterior,
        model.fit_state.artifact.chain[names(model.fit_state.artifact.chain, :parameters)],
    )
    @test size(grouped.posterior_predictive, 1) == model.sampler_config.draws
    @test size(grouped.prior_predictive, 1) == model.sampler_config.draws
    @test Symbol("target[4]") in names(grouped.posterior_predictive, :parameters)
    @test Symbol("target[4]") in names(grouped.prior_predictive, :parameters)
    @test :intercept in names(grouped.prior, :parameters)
    @test !(Symbol("target[1]") in names(grouped.prior, :parameters))
    @test :tree_depth in names(grouped.sample_stats.internals, :internals)
    @test grouped.sample_stats.diagnostics === nothing
end

@testset "inference_results uses the fitted artifact spec after config drift" begin
    model = sample_results_model()
    fitted_spec = model.fit_state.artifact.spec

    model.config.adstock["type"] = "unsupported"
    model.config.saturation["type"] = "unsupported"

    grouped = inference_results(model; include_prior = true, include_prior_predictive = true)

    @test grouped.spec.adstock == fitted_spec.adstock
    @test grouped.spec.saturation == fitted_spec.saturation
    @test size(grouped.posterior_predictive, 1) == model.sampler_config.draws
    @test size(grouped.prior_predictive, 1) == model.sampler_config.draws
end

@testset "inference_results ignores seasonality trend events and controls drift" begin
    model = sample_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        trend = Dict("type" => "linear"),
        events = Dict("columns" => ["promo", "holiday"]),
        controls_config = Dict("transform" => "standardize"),
        event_values = [1.0 0.0; 0.0 1.0; 0.0 0.0; 1.0 0.0; 0.0 0.0; 0.0 1.0],
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
    )
    fit!(model)
    fitted_spec = model.fit_state.artifact.spec

    model.config.seasonality["type"] = "unsupported"
    model.config.trend["type"] = "unsupported"
    empty!(model.config.events)
    model.config.events["columns"] = ["bad_event"]
    model.config.controls["transform"] = "unsupported"

    grouped = inference_results(model; include_prior = true, include_prior_predictive = true)

    @test grouped.spec.seasonality == fitted_spec.seasonality
    @test grouped.spec.trend == fitted_spec.trend
    @test grouped.spec.events == fitted_spec.events
    @test grouped.spec.controls == fitted_spec.controls
    @test size(grouped.posterior_predictive, 1) == model.sampler_config.draws
    @test size(grouped.prior_predictive, 1) == model.sampler_config.draws
end

@testset "inference_results preserves diagnostics metadata when available" begin
    model = sample_persisted_model(; compute_convergence_checks = true, chains = 2)
    grouped = inference_results(
        model;
        include_prior = false,
        include_posterior_predictive = false,
        include_prior_predictive = false,
    )

    @test grouped.sample_stats.diagnostics isa ModelDiagnostics
    @test grouped.sample_stats.sampler_diagnostics isa SamplerDiagnostics
    @test grouped.sample_stats.sampler_warnings isa SamplerWarnings
    @test grouped.sample_stats.convergence_report isa ConvergenceReport
    @test grouped.sample_stats.convergence_warnings isa ConvergenceWarnings
    @test grouped.sample_stats.diagnostics.metadata == grouped.metadata
end

@testset "inference_results for PanelMMM" begin
    model = sample_panel_model()
    fit!(model)

    grouped = inference_results(model; include_prior = true, include_prior_predictive = true)

    @test grouped isa InferenceResults
    @test grouped.metadata.model_type == "PanelMMM"
    @test grouped.spec.model_kind == :panel_mmm
    @test grouped.coordinate_metadata.coordinates["geo"] == ["north", "south"]
    @test grouped.observed_data == model.data
    @test Symbol("panel_intercept_offset[1]") in names(grouped.posterior, :parameters)
    @test Symbol("target[1, 1]") in names(grouped.posterior_predictive, :parameters)
    @test Symbol("target[1, 1]") in names(grouped.prior_predictive, :parameters)
end

@testset "panel inference_results uses the fitted artifact spec after config drift" begin
    model = sample_panel_model()
    fit!(model)
    fitted_spec = model.fit_state.artifact.spec

    model.config.adstock["type"] = "unsupported"
    model.config.saturation["type"] = "unsupported"

    grouped = inference_results(model; include_prior = true, include_prior_predictive = true)

    @test grouped.spec.adstock == fitted_spec.adstock
    @test grouped.spec.saturation == fitted_spec.saturation
    @test Symbol("target[1, 1]") in names(grouped.posterior_predictive, :parameters)
    @test Symbol("target[1, 1]") in names(grouped.prior_predictive, :parameters)
end

@testset "save_inference_results/load_inference_results" begin
    model = sample_results_model(; adstock_type = "delayed", saturation_type = "michaelis_menten")
    grouped = inference_results(model; include_prior = true, include_prior_predictive = true)
    path = tempname()

    saved_path = save_inference_results(path, grouped)
    @test saved_path == path

    payload = open(deserialize, path)
    @test payload.metadata isa ModelArtifactMetadata
    @test payload.spec isa MMMModelSpec
    @test payload.coordinate_metadata isa Epsilon.ModelCoordinateMetadata
    @test payload.sample_stats isa InferenceSampleStats

    loaded = load_inference_results(path)
    @test loaded isa InferenceResults
    @test loaded == grouped
end

@testset "save_inference_results/load_inference_results allows observed_data = nothing" begin
    model = sample_results_model()
    grouped = inference_results(
        model;
        include_prior = false,
        include_posterior_predictive = false,
        include_prior_predictive = false,
    )
    minimal = InferenceResults(
        grouped.metadata,
        grouped.spec;
        posterior = grouped.posterior,
        prior = nothing,
        posterior_predictive = nothing,
        prior_predictive = nothing,
        sample_stats = InferenceSampleStats(),
        observed_data = nothing,
    )
    path = tempname()

    save_inference_results(path, minimal)
    loaded = load_inference_results(path)

    @test loaded == minimal
    @test isnothing(loaded.observed_data)
end

@testset "load_inference_results rejects incompatible artifact versions" begin
    model = sample_results_model()
    grouped = inference_results(
        model;
        include_prior = false,
        include_posterior_predictive = false,
        include_prior_predictive = false,
    )
    path = tempname()
    save_inference_results(path, grouped)
    payload = open(deserialize, path)
    metadata = payload.metadata

    bad_metadata = ModelArtifactMetadata(
        metadata.schema_version,
        v"0.0.0",
        metadata.julia_version,
        metadata.created_at_utc,
        metadata.model_type,
        metadata.backend,
        metadata.fit_status,
    )
    open(path, "w") do io
        serialize(io, (; payload..., metadata = bad_metadata))
    end
    @test_throws ArgumentError load_inference_results(path)
end
