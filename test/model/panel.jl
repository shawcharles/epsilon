using Epsilon
using Dates
using Test

include("sample_models.jl")

@testset "PanelMMM" begin
    model = sample_panel_model()
    @test model isa PanelMMM
    @test isnothing(model.built_model)
    @test isnothing(model.fit_state)

    @test_throws ArgumentError PanelMMM(
        ModelConfig(
            date_column = "date",
            target_column = "revenue",
            channel_columns = ["tv", "search"],
            dims = (),
            adstock = Dict("type" => "geometric", "l_max" => 8),
            saturation = Dict("type" => "logistic"),
        ),
        model.sampler_config,
        model.data,
    )

    seasonal = PanelMMM(
        ModelConfig(
            date_column = "date",
            target_column = "revenue",
            channel_columns = ["tv", "search"],
            dims = ("geo",),
            adstock = Dict("type" => "geometric", "l_max" => 8),
            saturation = Dict("type" => "logistic"),
            seasonality = Dict("type" => "fourier", "n_order" => 2),
        ),
        model.sampler_config,
        model.data,
    )
    @test seasonal isa PanelMMM
end

@testset "PanelMMM rejects calibration keyword arguments" begin
    model = sample_panel_model()
    lift_test_data = LiftTestCalibrationRows(
        channel = ["tv"],
        x = [1.0],
        delta_x = [0.5],
        delta_y = [0.3],
        sigma = [0.1],
    )
    calibration_steps = [CalibrationStepConfig(method = "add_lift_test_measurements")]

    @test_throws MethodError PanelMMM(
        model.config,
        model.sampler_config,
        model.data;
        calibration_steps = calibration_steps,
        lift_test_data = lift_test_data,
    )
    @test_throws MethodError PanelMMM(
        model.config,
        model.sampler_config,
        model.data;
        lift_test_data = lift_test_data,
    )

    parsed_config = ModelConfig(
        date_column = model.config.date_column,
        target_column = model.config.target_column,
        target_type = model.config.target_type,
        channel_columns = model.config.channel_columns,
        dims = model.config.dims,
        adstock = model.config.adstock,
        saturation = model.config.saturation,
        priors = model.config.priors,
        extras = Dict(
            "calibration" => TimeSeriesCalibrationInput(
                calibration_steps,
                lift_test_data,
                nothing,
            ),
        ),
    )
    @test_throws ArgumentError PanelMMM(parsed_config, model.sampler_config, model.data)
end

@testset "build_model for PanelMMM" begin
    model = sample_panel_model()
    spec = build_model(model)
    metadata = spec.coordinate_metadata

    @test spec.model_kind == :panel_mmm
    @test spec.nobs == 12
    @test ntime(model.data) == 6
    @test npanels(model.data) == 2
    @test npanel_observations(model.data) == spec.nobs
    @test spec.nchannels == 2
    @test metadata.observation_dim == "time"
    @test metadata.panel_dims == ("geo",)
    @test metadata.coordinates["time"] == string.(1:6)
    @test metadata.coordinates["panel_cell"] == ["north", "south"]
    @test metadata.coordinates["geo"] == ["north", "south"]
    @test metadata.coordinates["channel"] == ["tv", "search"]
    @test metadata.named_dims["target"] == ("time", "geo")
    @test metadata.named_dims["channels"] == ("time", "channel", "geo")
    @test metadata.named_dims["beta_media"] == ("channel",)
    @test metadata.named_dims["panel_intercept_offset"] == ("geo",)
    axis = panel_axis(spec)
    @test axis == PanelAxis(
        name = "panel_cell",
        values = ["north", "south"],
        coordinate_columns = ["geo" => ["north", "south"]],
    )
    @test panel_axes(spec) == [axis]
    coordinates = panel_coordinates(spec)
    @test coordinates == [
        PanelCoordinate(1, "north", (geo = "north",)),
        PanelCoordinate(2, "south", (geo = "south",)),
    ]
    @test panel_coordinates(metadata) == coordinates
    @test panel_coordinate(spec, 2) == PanelCoordinate(2, "south", (geo = "south",))
    @test_throws BoundsError panel_coordinate(spec, 3)
    @test spec.channel_scale ≈ [4.0 3.1; 3.0 2.1]
    @test spec.target_scale ≈ [11.5, 8.0]
    @test model.built_model == spec
end

@testset "PanelMMM respects panel-indexed prior dimensions" begin
    model = sample_panel_model()
    config = ModelConfig(
        date_column = "date",
        target_column = "revenue",
        target_type = "revenue",
        channel_columns = model.config.channel_columns,
        dims = ("geo",),
        adstock = Dict(
            "type" => "geometric",
            "l_max" => 4,
            "priors" => Dict(
                "alpha" => EpsilonPrior("Beta"; alpha = 1, beta = 3, dims = ("geo", "channel")),
            ),
        ),
        saturation = Dict(
            "type" => "logistic",
            "priors" => Dict(
                "lam" => EpsilonPrior("Gamma"; alpha = 3, beta = 1, dims = ("channel",)),
            ),
        ),
        priors = Dict(
            "intercept" => EpsilonPrior("Normal"; mu = 0, sigma = 2, dims = ("geo",)),
            "beta_media" => EpsilonPrior("HalfNormal"; sigma = 1, dims = ("geo", "channel")),
            "likelihood" => EpsilonPrior(
                "Normal";
                sigma = EpsilonPrior("HalfNormal"; sigma = 2, dims = ("geo",)),
                dims = ("time", "geo"),
            ),
        ),
    )
    panel_model = PanelMMM(config, model.sampler_config, model.data)
    spec = build_model(panel_model)
    runtime = Epsilon._panel_turing_runtime(spec, panel_model.data)

    @test spec.coordinate_metadata.named_dims["intercept"] == ("geo",)
    @test spec.coordinate_metadata.named_dims["sigma"] == ("geo",)
    @test spec.coordinate_metadata.named_dims["alpha"] == ("geo", "channel")
    @test spec.coordinate_metadata.named_dims["beta_media"] == ("geo", "channel")
    @test runtime.intercept_shape == :panel
    @test runtime.sigma_shape == :panel
    @test runtime.alpha_shape == :channel_panel
    @test runtime.media_beta_shape == :channel_panel
    @test runtime.nintercepts == length(model.data.panel_names)
    @test runtime.nsigmas == length(model.data.panel_names)
    @test runtime.nalpha == length(model.data.panel_names) * length(model.data.channel_names)
    @test runtime.nmedia_beta == length(model.data.panel_names) * length(model.data.channel_names)
end

@testset "PanelMMM supports panel Fourier and pooled holidays" begin
    tmpdir = mktempdir()
    holidays_path = joinpath(tmpdir, "holidays.csv")
    write(
        holidays_path,
        "ds,holiday,country,year\n" *
            "2024-01-01,New Year's Day,GB,2024\n" *
            "2024-01-08,FR Holiday,FR,2024\n",
    )
    model = sample_panel_model()
    data = PanelMMMData(
        dates = Date(2024, 1, 1) .+ Week.(0:5),
        target = model.data.target,
        channels = model.data.channels,
        panel_names = ["UK", "FR"],
        channel_names = model.data.channel_names,
    )
    config = ModelConfig(
        date_column = "date",
        target_column = "revenue",
        target_type = "revenue",
        channel_columns = model.config.channel_columns,
        dims = ("geo",),
        adstock = model.config.adstock,
        saturation = model.config.saturation,
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        holidays = Dict(
            "mode" => "auto",
            "path" => holidays_path,
            "countries" => ["UK", "FR"],
        ),
        priors = model.config.priors,
    )
    panel_model = PanelMMM(config, model.sampler_config, data)
    spec = build_model(panel_model)
    runtime = Epsilon._panel_turing_runtime(spec, data)

    @test spec.coordinate_metadata.coordinates["fourier_mode"] == ["sin_1", "sin_2", "cos_1", "cos_2"]
    @test spec.coordinate_metadata.coordinates["holiday"] == ["holiday"]
    @test spec.coordinate_metadata.named_dims["seasonality_features"] == ("time", "fourier_mode")
    @test spec.coordinate_metadata.named_dims["beta_seasonality"] == ("geo", "fourier_mode")
    @test spec.coordinate_metadata.named_dims["holidays"] == ("time", "holiday", "geo")
    @test spec.coordinate_metadata.named_dims["beta_holidays"] == ("holiday",)
    @test runtime.seasonality_type == :fourier
    @test runtime.seasonality_beta_shape == :feature_panel
    @test runtime.nseasonality_terms == 4
    @test runtime.nseasonality_beta == 8
    @test runtime.nholidays == 1
    @test runtime.nholiday_beta == 1
    @test size(runtime.holiday_features) == (6, 1, 2)
    @test runtime.holiday_features[1, 1, 1] ≈ 1 / 7
    @test runtime.holiday_features[2, 1, 2] ≈ 1 / 7

    fit_model = PanelMMM(
        config,
        SamplerConfig(;
            draws = 8,
            tune = 8,
            chains = 1,
            cores = 1,
            random_seed = 31,
            progressbar = false,
            compute_convergence_checks = false,
        ),
        data,
    )
    state = fit!(fit_model)
    @test state.status === :fit
    @test Symbol("beta_holidays[1]") in names(state.artifact.chain)
    @test Symbol("beta_seasonality[1]") in names(state.artifact.chain)
end

@testset "fit! PanelMMM" begin
    model = sample_panel_model(; adstock_type = "delayed", saturation_type = "hill")
    state = fit!(model)

    @test state isa ModelFitState
    @test state.backend == :turing
    @test hasproperty(state.artifact, :chain)
    @test state.artifact.metadata isa ModelArtifactMetadata
    @test state.artifact.metadata.model_type == "PanelMMM"
    @test state.artifact.runtime.npanels == 2
    @test state.artifact.runtime.ntime == 6
    @test Symbol("panel_intercept_scale") in names(state.artifact.chain)
    @test Symbol("panel_intercept_offset[1]") in names(state.artifact.chain)
    @test Symbol("intercept[1]") in names(state.artifact.chain)

    predictive = Epsilon.predict(model)
    @test size(predictive, 1) == model.sampler_config.draws
    @test Symbol("target[1, 1]") in predictive.name_map.parameters

    prior = prior_predict(model)
    @test size(prior, 1) == model.sampler_config.draws
    @test Symbol("target[1, 1]") in prior.name_map.parameters

    reordered_data = PanelMMMData(
        dates = 1:6,
        target = model.data.target,
        channels = model.data.channels,
        panel_names = ["south", "north"],
        channel_names = model.data.channel_names,
    )
    @test_throws ArgumentError Epsilon.predict(model, reordered_data)
end

@testset "post-fit panel prediction surfaces ignore mutable config drift" begin
    model = sample_panel_model()
    fit!(model)

    model.config.adstock["type"] = "unsupported"
    model.config.saturation["type"] = "unsupported"

    predictive = Epsilon.predict(model)
    prior = prior_predict(model)

    @test model.fit_state.artifact.spec.adstock["type"] == "geometric"
    @test model.fit_state.artifact.spec.saturation["type"] == "logistic"
    @test size(predictive, 1) == model.sampler_config.draws
    @test size(prior, 1) == model.sampler_config.draws
end
