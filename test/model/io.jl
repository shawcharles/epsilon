using Epsilon
using Test
using Serialization

function sample_persisted_model(; compute_convergence_checks = false, chains = 1)
    config = ModelConfig(
        date_column = "date",
        target_column = "revenue",
        target_type = "revenue",
        channel_columns = ["tv", "search"],
        control_columns = ["price_index"],
        dims = ("geo",),
        adstock = Dict("type" => "geometric", "l_max" => 8),
        saturation = Dict("type" => "logistic"),
        priors = Dict("intercept" => EpsilonPrior("Normal"; mu = 0.0, sigma = 1.0)),
    )
    sampler = SamplerConfig(;
        draws = 20,
        tune = 20,
        chains = chains,
        cores = 1,
        target_accept = 0.8,
        progressbar = false,
        compute_convergence_checks = compute_convergence_checks,
    )
    data = MMMData(
        dates = 1:6,
        target = [5.0, 6.5, 7.5, 9.0, 10.0, 11.5],
        channels = [1.0 0.5; 2.0 1.0; 2.5 1.5; 3.0 2.0; 3.5 2.5; 4.0 3.0],
        channel_names = ["tv", "search"],
        controls = [0.2; 0.4; 0.3; 0.6; 0.5; 0.8][:, :],
        control_names = ["price_index"],
    )
    model = TimeSeriesMMM(config, sampler, data)
    fit!(model)
    return model
end

@testset "save_model/load_model" begin
    model = sample_persisted_model()
    path = tempname()

    saved_path = save_model(path, model)
    @test saved_path == path
    payload = open(deserialize, path)
    @test payload.metadata isa ModelArtifactMetadata
    @test payload.metadata.schema_version == 1
    @test payload.metadata.model_type == "TimeSeriesMMM"
    @test payload.metadata.backend == :turing
    @test payload.metadata.fit_status == :fit

    loaded = load_model(path)
    @test loaded isa TimeSeriesMMM
    @test loaded.config == model.config
    @test loaded.sampler_config == model.sampler_config
    @test loaded.data == model.data
    @test loaded.built_model == model.built_model
    @test loaded.built_model.coordinate_metadata.panel_dims == ("geo",)
    @test loaded.built_model.coordinate_metadata.coordinates["channel"] == ["tv", "search"]
    @test loaded.built_model.coordinate_metadata.named_dims["channels"] == ("observation", "channel")
    @test loaded.fit_state.status == :fit
    @test loaded.fit_state.backend == :turing
    @test hasproperty(loaded.fit_state.artifact, :chain)
    @test loaded.fit_state.artifact.metadata isa ModelArtifactMetadata
    @test loaded.fit_state.artifact.metadata.model_type == "TimeSeriesMMM"
    @test loaded.fit_state.artifact.metadata.backend == :turing
    @test size(loaded.fit_state.artifact.chain, 1) == model.sampler_config.draws

    predictive = Epsilon.predict(loaded)
    @test size(predictive, 1) == loaded.sampler_config.draws
end

@testset "save_model/load_model with convergence report" begin
    model = sample_persisted_model(; compute_convergence_checks = true, chains = 2)
    path = tempname()

    save_model(path, model)
    loaded = load_model(path)

    @test loaded.fit_state.artifact.diagnostics isa ModelDiagnostics
    @test loaded.fit_state.artifact.sampler_diagnostics isa SamplerDiagnostics
    @test loaded.fit_state.artifact.sampler_warnings isa SamplerWarnings
    @test loaded.fit_state.artifact.convergence_report isa ConvergenceReport
    @test loaded.fit_state.artifact.convergence_warnings isa ConvergenceWarnings
    @test loaded.fit_state.artifact.sampler_diagnostics.max_tree_depth >= 0
    @test loaded.fit_state.artifact.sampler_warnings.summary.nwarnings >= 0
    @test loaded.fit_state.artifact.convergence_report.summary.nparameters > 0
    @test loaded.fit_state.artifact.convergence_warnings.summary.nwarnings >= 0
end

@testset "save_model/load_model for PanelMMM" begin
    model = sample_panel_model()
    fit!(model)
    path = tempname()

    saved_path = save_model(path, model)
    @test saved_path == path
    payload = open(deserialize, path)
    @test payload.metadata.model_type == "PanelMMM"

    loaded = load_model(path)
    @test loaded isa PanelMMM
    @test loaded.config == model.config
    @test loaded.sampler_config == model.sampler_config
    @test loaded.data == model.data
    @test loaded.built_model == model.built_model
    @test loaded.built_model.model_kind == :panel_mmm
    @test loaded.built_model.coordinate_metadata.coordinates["geo"] == ["north", "south"]
    @test loaded.built_model.coordinate_metadata.named_dims["target"] == ("time", "geo")
    @test loaded.fit_state.status == :fit
    @test loaded.fit_state.backend == :turing
    @test loaded.fit_state.artifact.metadata.model_type == "PanelMMM"

    predictive = Epsilon.predict(loaded)
    @test size(predictive, 1) == loaded.sampler_config.draws
end

@testset "load_model rejects incompatible artifact versions" begin
    model = sample_persisted_model()
    path = tempname()
    save_model(path, model)
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
    @test_throws ArgumentError load_model(path)

    bad_metadata = ModelArtifactMetadata(
        metadata.schema_version,
        metadata.epsilon_version,
        v"0.0.0",
        metadata.created_at_utc,
        metadata.model_type,
        metadata.backend,
        metadata.fit_status,
    )
    open(path, "w") do io
        serialize(io, (; payload..., metadata = bad_metadata))
    end
    @test_throws ArgumentError load_model(path)
end
