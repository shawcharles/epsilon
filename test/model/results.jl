using Epsilon
using Dates
using Serialization
using Test

isdefined(@__MODULE__, :sample_results_model) || include("sample_models.jl")

@testset "model_results" begin
    model = sample_results_model(; adstock_type = "weibull_pdf", saturation_type = "hill")
    results = model_results(model)

    @test results isa ModelResults
    @test results.metadata isa ModelArtifactMetadata
    @test results.metadata.model_type == "TimeSeriesMMM"
    @test results.metadata.backend == :turing
    @test results.spec == model.fit_state.artifact.spec
    @test size(results.chain, 1) == model.sampler_config.draws
    @test size(results.posterior_predictive, 1) == model.sampler_config.draws
    @test Symbol("target[1]") in results.posterior_predictive.name_map.parameters
    @test results.prior_predictive === nothing
end

@testset "model_results without predictive" begin
    model = sample_results_model()
    results = model_results(model; include_posterior_predictive = false)

    @test results.posterior_predictive === nothing
    @test results.prior_predictive === nothing
    @test size(results.chain, 1) == model.sampler_config.draws
end

@testset "model_results with prior predictive" begin
    model = sample_results_model()
    results = model_results(model; include_posterior_predictive = false, include_prior_predictive = true)

    @test results.posterior_predictive === nothing
    @test size(results.prior_predictive, 1) == model.sampler_config.draws
    @test Symbol("target[1]") in results.prior_predictive.name_map.parameters
end

@testset "model_results uses a spec matching new_data" begin
    model = sample_results_model()
    new_data = MMMData(
        dates = 1:4,
        target = [4.0, 5.0, 6.0, 7.0],
        channels = [1.0 0.5; 2.0 1.0; 3.0 1.5; 4.0 2.0],
        channel_names = ["tv", "search"],
        controls = [0.2; 0.4; 0.6; 0.8][:, :],
        control_names = ["price_index"],
    )

    results = model_results(model; new_data, include_prior_predictive = true)

    @test results.spec.nobs == 4
    @test results.spec.coordinate_metadata.coordinates["observation"] == string.(1:4)
    @test Symbol("target[4]") in results.posterior_predictive.name_map.parameters
    @test Symbol("target[4]") in results.prior_predictive.name_map.parameters
end

@testset "model_results uses the fitted artifact spec after config drift" begin
    model = sample_results_model()
    fitted_spec = model.fit_state.artifact.spec

    model.config.adstock["type"] = "unsupported"
    model.config.saturation["type"] = "unsupported"

    results = model_results(model)

    @test results.spec.adstock == fitted_spec.adstock
    @test results.spec.saturation == fitted_spec.saturation
    @test size(results.posterior_predictive, 1) == model.sampler_config.draws
end

@testset "model_results ignores seasonality trend events and controls drift" begin
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

    results = model_results(model)

    @test results.spec.seasonality == fitted_spec.seasonality
    @test results.spec.trend == fitted_spec.trend
    @test results.spec.events == fitted_spec.events
    @test results.spec.controls == fitted_spec.controls
    @test size(results.posterior_predictive, 1) == model.sampler_config.draws
end

@testset "save_results/load_results" begin
    model = sample_results_model(; adstock_type = "delayed", saturation_type = "michaelis_menten")
    results = model_results(model; include_prior_predictive = true)
    path = tempname()

    saved_path = save_results(path, results)
    @test saved_path == path

    payload = open(deserialize, path)
    @test payload.schema_version == 1
    @test !haskey(payload, :model_payload_schema_version)
    @test payload.metadata isa ModelArtifactMetadata
    @test payload.spec isa MMMModelSpec

    loaded = load_results(path)
    @test loaded isa ModelResults
    @test loaded == results
    @test size(loaded.posterior_predictive, 1) == model.sampler_config.draws
    @test size(loaded.prior_predictive, 1) == model.sampler_config.draws
end

@testset "panel model_results" begin
    model = sample_panel_model()
    fit!(model)
    results = model_results(model; include_prior_predictive = true)

    @test results isa ModelResults
    @test results.metadata.model_type == "PanelMMM"
    @test results.spec.model_kind == :panel_mmm
    @test results.spec.coordinate_metadata.coordinates["geo"] == ["north", "south"]
    @test size(results.chain, 1) == model.sampler_config.draws
    @test size(results.posterior_predictive, 1) == model.sampler_config.draws
    @test size(results.prior_predictive, 1) == model.sampler_config.draws
    @test Symbol("target[1, 1]") in results.posterior_predictive.name_map.parameters
    @test Symbol("target[1, 1]") in results.prior_predictive.name_map.parameters
end

@testset "panel model_results uses the fitted artifact spec after config drift" begin
    model = sample_panel_model()
    fit!(model)
    fitted_spec = model.fit_state.artifact.spec

    model.config.adstock["type"] = "unsupported"
    model.config.saturation["type"] = "unsupported"

    results = model_results(model)

    @test results.spec.adstock == fitted_spec.adstock
    @test results.spec.saturation == fitted_spec.saturation
    @test size(results.posterior_predictive, 1) == model.sampler_config.draws
end

@testset "load_results rejects incompatible artifact versions" begin
    model = sample_results_model()
    results = model_results(model)
    path = tempname()
    save_results(path, results)
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
    @test_throws ArgumentError load_results(path)
end

@testset "ModelResults backend policy is fail-closed" begin
    model = sample_results_model()
    results = model_results(model; include_posterior_predictive = false)
    metadata = results.metadata
    retired_metadata = ModelArtifactMetadata(
        metadata.schema_version,
        metadata.epsilon_version,
        metadata.julia_version,
        metadata.created_at_utc,
        metadata.model_type,
        :variational,
        metadata.fit_status,
    )
    unknown_metadata = ModelArtifactMetadata(
        metadata.schema_version,
        metadata.epsilon_version,
        metadata.julia_version,
        metadata.created_at_utc,
        metadata.model_type,
        :unknown,
        metadata.fit_status,
    )
    unfitted_metadata = Epsilon._artifact_metadata("TimeSeriesMMM")

    @test_throws ArgumentError ModelResults(retired_metadata, results.spec, results.chain)
    @test_throws ArgumentError ModelResults(unknown_metadata, results.spec, results.chain)
    @test_throws ArgumentError ModelResults(unfitted_metadata, results.spec, results.chain)
    @test_throws ArgumentError ModelResults(
        unfitted_metadata,
        results.spec,
        nothing;
        posterior_predictive = results.chain,
    )
    @test ModelResults(Epsilon._artifact_metadata("TimeSeriesMMM"), results.spec, nothing) isa ModelResults

    path = tempname()
    open(path, "w") do io
        serialize(io, (; schema_version = 1, metadata = retired_metadata, spec = results.spec, chain = results.chain, posterior_predictive = nothing, prior_predictive = nothing))
    end
    @test_throws ArgumentError load_results(path)

    open(path, "w") do io
        serialize(io, (; schema_version = 1, metadata = unfitted_metadata, spec = results.spec, chain = nothing, posterior_predictive = results.chain, prior_predictive = nothing))
    end
    @test_throws ArgumentError load_results(path)
end

@testset "load_results rejects malformed embedded HSGP state" begin
    config = ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        time_varying_media = TimeVaryingMediaConfig(
            m = 2,
            L = 6.0,
            time_resolution = 7,
            eta_prior = EpsilonPrior("Exponential"; lam = 1.5),
            lengthscale_prior = EpsilonPrior("LogNormal"; mu = 0.0, sigma = 0.4),
        ),
    )
    data = MMMData(
        dates = Date[Date(2024, 1, 1), Date(2024, 1, 8)],
        target = [10.0, 11.0],
        channels = reshape([1.0, 2.0], :, 1),
        channel_names = ["tv"],
    )
    spec = build_model(TimeSeriesMMM(config, SamplerConfig(draws = 1, tune = 0, chains = 1, cores = 1), data))
    spec.priors["_hsgp_media_spec_state"] = :corrupt
    results = ModelResults(Epsilon._artifact_metadata("TimeSeriesMMM"), spec, nothing)
    path = tempname()
    save_results(path, results)
    @test_throws ArgumentError load_results(path)
end
