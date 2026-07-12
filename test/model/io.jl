using Epsilon
using Test
using Serialization
using Dates
using Random

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

function _hsgp_io_config()
    return TimeVaryingMediaConfig(
        m = 2,
        L = 6.0,
        time_resolution = 7,
        covariance = :expquad,
        eta_prior = EpsilonPrior("Exponential"; lam = 1.5),
        lengthscale_prior = EpsilonPrior("LogNormal"; mu = 0.0, sigma = 0.4),
    )
end

function _hsgp_io_data(; dates = Date[Date(2024, 1, 1), Date(2024, 1, 8), Date(2024, 1, 15)])
    n = length(dates)
    return MMMData(
        dates = dates,
        target = collect(10.0:(9.0 + n)),
        channels = reshape(collect(1.0:n), :, 1),
        channel_names = ["tv"],
    )
end

function _hsgp_io_model(; fitted = false)
    config = ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        time_varying_media = _hsgp_io_config(),
    )
    sampler = SamplerConfig(
        draws = 2,
        tune = 0,
        chains = 1,
        cores = 1,
        random_seed = 734,
        progressbar = false,
        compute_convergence_checks = false,
    )
    model = TimeSeriesMMM(config, sampler, _hsgp_io_data())
    fitted ? fit!(model) : build_model(model)
    return model
end

function _write_model_payload(path, payload)
    open(path, "w") do io
        serialize(io, payload)
    end
    return path
end

@testset "save_model/load_model" begin
    model = sample_persisted_model()
    path = tempname()

    saved_path = save_model(path, model)
    @test saved_path == path
    payload = open(deserialize, path)
    @test payload.model_payload_schema_version == 2
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

@testset "model payload v1 and v2 HSGP lifecycle validation" begin
    ordinary = sample_persisted_model()
    ordinary_path = tempname()
    save_model(ordinary_path, ordinary)
    ordinary_payload = open(deserialize, ordinary_path)
    legacy_ordinary = Base.structdiff(
        ordinary_payload,
        NamedTuple{(:model_payload_schema_version,)},
    )
    @test load_model(_write_model_payload(tempname(), legacy_ordinary)) isa TimeSeriesMMM
    @test_throws ArgumentError load_model(
        _write_model_payload(tempname(), (; ordinary_payload..., model_payload_schema_version = 99)),
    )

    configured = TimeSeriesMMM(
        ModelConfig(
            date_column = "date",
            target_column = "revenue",
            channel_columns = ["tv"],
            time_varying_media = _hsgp_io_config(),
        ),
        SamplerConfig(draws = 1, tune = 0, chains = 1, cores = 1),
        _hsgp_io_data(),
    )
    configured_path = tempname()
    save_model(configured_path, configured)
    configured_payload = open(deserialize, configured_path)
    @test load_model(configured_path).built_model === nothing
    @test_throws ArgumentError load_model(
        _write_model_payload(
            tempname(),
            Base.structdiff(configured_payload, NamedTuple{(:model_payload_schema_version,)}),
        ),
    )

    built = _hsgp_io_model()
    built_path = tempname()
    save_model(built_path, built)
    built_payload = open(deserialize, built_path)
    @test load_model(built_path).built_model == built.built_model
    missing_built_state = Epsilon._build_model_spec(
        built.built_model,
        built.data,
    )
    delete!(missing_built_state.priors, "_hsgp_media_spec_state")
    @test_throws ArgumentError load_model(
        _write_model_payload(tempname(), (; built_payload..., built_model = missing_built_state)),
    )

    fitted = _hsgp_io_model(; fitted = true)
    fitted_path = tempname()
    save_model(fitted_path, fitted)
    fitted_payload = open(deserialize, fitted_path)
    loaded = load_model(fitted_path)
    @test loaded.fit_state.artifact.spec.priors["_hsgp_media_spec_state"] ==
        loaded.built_model.priors["_hsgp_media_spec_state"]

    mismatched_state = Epsilon._HSGPMediaSpecState(
        fitted.built_model.priors["_hsgp_media_spec_state"].config,
        Epsilon._HSGPTimeSeriesTrainingState(
            Date(2024, 1, 8),
            7,
            (0, 1, 2),
            1.0,
            2,
            6.0,
            :expquad,
            false,
            false,
        ),
    )
    mismatched_spec = Epsilon._build_model_spec(fitted.built_model, fitted.data)
    mismatched_spec.priors["_hsgp_media_spec_state"] = mismatched_state
    @test_throws ArgumentError load_model(
        _write_model_payload(tempname(), (; fitted_payload..., built_model = mismatched_spec)),
    )

    paired_artifact_spec = Epsilon._build_model_spec(fitted.built_model, fitted.data)
    paired_state = paired_artifact_spec.priors["_hsgp_media_spec_state"]
    paired_artifact_spec.priors["_hsgp_media_spec_state"] = Epsilon._HSGPMediaSpecState(
        Epsilon._HSGPMediaConfigSnapshot(
            paired_state.config.m,
            paired_state.config.L,
            paired_state.config.time_resolution,
            paired_state.config.covariance,
            Epsilon._HSGPMediaPriorSnapshot(:Exponential, ((:lam, 2.0),)),
            paired_state.config.lengthscale_prior,
        ),
        paired_state.training,
    )
    paired_artifact = (; fitted_payload.fit_state.artifact..., spec = paired_artifact_spec)
    paired_fit_state = (; fitted_payload.fit_state..., artifact = paired_artifact)
    @test_throws ArgumentError load_model(
        _write_model_payload(tempname(), (; fitted_payload..., fit_state = paired_fit_state)),
    )

    corrupt_prior_state = Epsilon._HSGPMediaSpecState(
        Epsilon._HSGPMediaConfigSnapshot(
            2,
            6.0,
            7,
            :expquad,
            Epsilon._HSGPMediaPriorSnapshot(:Exponential, ((:rate, 1.5),)),
            fitted.built_model.priors["_hsgp_media_spec_state"].config.lengthscale_prior,
        ),
        fitted.built_model.priors["_hsgp_media_spec_state"].training,
    )
    corrupt_spec = Epsilon._build_model_spec(fitted.built_model, fitted.data)
    corrupt_spec.priors["_hsgp_media_spec_state"] = corrupt_prior_state
    @test_throws ArgumentError load_model(
        _write_model_payload(tempname(), (; fitted_payload..., built_model = corrupt_spec)),
    )

    fitted.config.extras["time_varying_media"].eta_prior.parameters[:lam] = 9.0
    new_data = _hsgp_io_data(; dates = Date[Date(2024, 1, 22), Date(2024, 1, 29)])
    Random.seed!(981)
    expected = predict(fitted, new_data)
    mutated_path = tempname()
    save_model(mutated_path, fitted)
    Random.seed!(981)
    actual = predict(load_model(mutated_path), new_data)
    @test Array(actual) == Array(expected)

    calibrated = _hsgp_io_model()
    calibrated.calibration = TimeSeriesCalibrationInput(CalibrationStepConfig[], nothing, nothing)
    calibrated_path = tempname()
    save_model(calibrated_path, calibrated)
    @test_throws ArgumentError load_model(calibrated_path)
end

@testset "save_model/load_model preserves TimeSeriesMMM calibration" begin
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
        chains = 1,
        cores = 1,
        target_accept = 0.8,
        progressbar = false,
        compute_convergence_checks = false,
    )
    data = MMMData(
        dates = 1:6,
        target = [5.0, 6.5, 7.5, 9.0, 10.0, 11.5],
        channels = [1.0 0.5; 2.0 1.0; 2.5 1.5; 3.0 2.0; 3.5 2.5; 4.0 3.0],
        channel_names = ["tv", "search"],
        controls = [0.2; 0.4; 0.3; 0.6; 0.5; 0.8][:, :],
        control_names = ["price_index"],
    )
    lift_test_data = LiftTestCalibrationRows(
        channel = ["tv"],
        x = [1.0],
        delta_x = [0.5],
        delta_y = [0.3],
        sigma = [0.1],
    )
    model = TimeSeriesMMM(
        config,
        sampler,
        data;
        calibration_steps = [CalibrationStepConfig(method = "add_lift_test_measurements")],
        lift_test_data = lift_test_data,
    )
    fit!(model)
    path = tempname()

    save_model(path, model)
    loaded = load_model(path)

    @test loaded.calibration isa TimeSeriesCalibrationInput
    @test loaded.calibration == model.calibration
    @test loaded.fit_state.artifact.calibration isa MMMCalibrationSpec
    @test loaded.fit_state.artifact.calibration == model.fit_state.artifact.calibration
end

@testset "load_model defaults calibration to nothing for old-format payloads" begin
    model = sample_persisted_model()
    path = tempname()
    save_model(path, model)
    payload = open(deserialize, path)
    @test haskey(payload, :calibration)
    @test payload.calibration === nothing

    old_format_payload = Base.structdiff(payload, NamedTuple{(:calibration,)})
    @test !haskey(old_format_payload, :calibration)
    old_path = tempname()
    open(old_path, "w") do io
        serialize(io, old_format_payload)
    end

    loaded = load_model(old_path)
    @test loaded isa TimeSeriesMMM
    @test loaded.calibration === nothing
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
    @test payload.model_payload_schema_version == 2

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
