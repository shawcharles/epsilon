using Dates
using Epsilon
using Distributions
using Test
import Turing

function sample_time_series_model(;
        adstock_type = "geometric",
        saturation_type = "logistic",
        target_type = "revenue",
        seasonality = Dict{String, Any}(),
        trend = Dict{String, Any}(),
        events = Dict{String, Any}(),
        holidays = Dict{String, Any}(),
        controls_config = Dict{String, Any}(),
        event_values = nothing,
        dates = 1:6,
    )
    config = ModelConfig(
        date_column = "date",
        target_column = "revenue",
        target_type = target_type,
        channel_columns = ["tv", "search"],
        control_columns = ["price_index"],
        dims = ("geo",),
        adstock = Dict("type" => adstock_type, "l_max" => 8),
        saturation = Dict("type" => saturation_type),
        seasonality = seasonality,
        trend = trend,
        controls = controls_config,
        priors = Dict("intercept" => EpsilonPrior("Normal"; mu = 0.0, sigma = 1.0)),
        events = events,
        holidays = holidays,
    )
    sampler = SamplerConfig(;
        draws = 20,
        tune = 20,
        chains = 1,
        cores = 1,
        target_accept = 0.8,
        random_seed = 7,
        progressbar = false,
        compute_convergence_checks = false,
    )
    data = MMMData(
        dates = dates,
        target = [5.0, 6.5, 7.5, 9.0, 10.0, 11.5],
        channels = [1.0 0.5; 2.0 1.0; 2.5 1.5; 3.0 2.0; 3.5 2.5; 4.0 3.0],
        channel_names = ["tv", "search"],
        controls = [0.2; 0.4; 0.3; 0.6; 0.5; 0.8][:, :],
        control_names = ["price_index"],
        events = event_values,
        event_names = haskey(events, "columns") ? String.(events["columns"]) : String[],
    )
    return TimeSeriesMMM(config, sampler, data)
end

function _write_test_holidays_csv()
    path = tempname() * ".csv"
    write(
        path,
        "ds,holiday,country,year\n" *
            "01/01/2024,New Year,UK,2024\n" *
            "15/01/2024,Promo Day,UK,2024\n" *
            "29/01/2024,Promo Day,UK,2024\n",
    )
    return path
end

function sample_multichain_time_series_model(; cores = 2, compute_convergence_checks = false)
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
        draws = 15,
        tune = 15,
        chains = 2,
        cores = cores,
        target_accept = 0.8,
        random_seed = 11,
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
    return TimeSeriesMMM(config, sampler, data)
end

@testset "TimeSeriesMMM" begin
    model = sample_time_series_model()
    @test model isa TimeSeriesMMM
    @test isnothing(model.built_model)
    @test isnothing(model.fit_state)

    bad_data = MMMData(
        dates = 1:6,
        target = [5.0, 6.5, 7.5, 9.0, 10.0, 11.5],
        channels = [1.0 0.5; 2.0 1.0; 2.5 1.5; 3.0 2.0; 3.5 2.5; 4.0 3.0],
        channel_names = ["search", "tv"],
        controls = [0.2; 0.4; 0.3; 0.6; 0.5; 0.8][:, :],
        control_names = ["price_index"],
    )
    @test_throws ArgumentError TimeSeriesMMM(model.config, model.sampler_config, bad_data)
end

@testset "TimeSeriesMMM calibration construction" begin
    model = sample_time_series_model()
    @test model.calibration === nothing

    lift_test_data = LiftTestCalibrationRows(
        channel = ["tv"],
        x = [1.0],
        delta_x = [0.5],
        delta_y = [0.3],
        sigma = [0.1],
    )
    calibration_steps = [CalibrationStepConfig(method = "add_lift_test_measurements")]

    calibrated_model = TimeSeriesMMM(
        model.config,
        model.sampler_config,
        model.data;
        calibration_steps = calibration_steps,
        lift_test_data = lift_test_data,
    )
    @test calibrated_model.calibration isa TimeSeriesCalibrationInput
    @test calibrated_model.calibration.steps == calibration_steps
    @test calibrated_model.calibration.lift_test == lift_test_data
    @test calibrated_model.calibration.cost_per_target === nothing

    cost_per_target_data = CostPerTargetCalibrationRows(
        gathered_cpt = [2.0],
        targets = [1.5],
        sigma = [0.2],
    )
    combined_model = TimeSeriesMMM(
        model.config,
        model.sampler_config,
        model.data;
        calibration_steps = [
            CalibrationStepConfig(method = "add_lift_test_measurements"),
            CalibrationStepConfig(method = "add_cost_per_target_calibration"),
        ],
        lift_test_data = lift_test_data,
        cost_per_target_data = cost_per_target_data,
    )
    @test combined_model.calibration.lift_test == lift_test_data
    @test combined_model.calibration.cost_per_target == cost_per_target_data

    @test_throws ArgumentError TimeSeriesMMM(
        model.config,
        model.sampler_config,
        model.data;
        calibration_steps = calibration_steps,
    )
    @test_throws ArgumentError TimeSeriesMMM(
        model.config,
        model.sampler_config,
        model.data;
        lift_test_data = lift_test_data,
    )
end

@testset "fit! with tanh saturation" begin

    model = sample_time_series_model(; saturation_type = "tanh")
    state = fit!(model)

    @test state isa ModelFitState
    @test state.backend == :turing
    @test hasproperty(state.artifact, :chain)
    @test state.artifact.metadata isa ModelArtifactMetadata
    @test state.artifact.metadata.backend == :turing
    @test state.artifact.metadata.fit_status == :fit

    predictive = Epsilon.predict(model)
    @test size(predictive, 1) == model.sampler_config.draws
    @test Symbol("target[1]") in predictive.name_map.parameters
end

@testset "fit! with hill saturation" begin
    model = sample_time_series_model(; saturation_type = "hill")
    state = fit!(model)

    @test state isa ModelFitState
    @test state.backend == :turing
    @test hasproperty(state.artifact, :chain)

    predictive = Epsilon.predict(model)
    @test size(predictive, 1) == model.sampler_config.draws
    @test Symbol("target[1]") in predictive.name_map.parameters
end

@testset "post-fit time-series prediction surfaces ignore mutable config drift" begin
    model = sample_time_series_model()
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

@testset "post-fit time-series prediction ignores seasonality trend events and controls drift" begin
    model = sample_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        trend = Dict("type" => "linear"),
        events = Dict("columns" => ["promo", "holiday"]),
        controls_config = Dict("transform" => "standardize"),
        event_values = [1.0 0.0; 0.0 1.0; 0.0 0.0; 1.0 0.0; 0.0 0.0; 0.0 1.0],
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
    )
    fit!(model)

    model.config.seasonality["type"] = "unsupported"
    model.config.trend["type"] = "unsupported"
    empty!(model.config.events)
    model.config.events["columns"] = ["bad_event"]
    model.config.controls["transform"] = "unsupported"

    predictive = Epsilon.predict(model)
    prior = prior_predict(model)

    @test model.fit_state.artifact.spec.seasonality["type"] == "fourier"
    @test model.fit_state.artifact.spec.trend["type"] == "linear"
    @test model.fit_state.artifact.spec.events["columns"] == ["promo", "holiday"]
    @test model.fit_state.artifact.spec.controls["transform"] == "standardize"
    @test size(predictive, 1) == model.sampler_config.draws
    @test size(prior, 1) == model.sampler_config.draws
end

@testset "fit! with fourier seasonality" begin
    model = sample_time_series_model(;
        seasonality = Dict(
            "type" => "fourier",
            "n_order" => 2,
            "priors" => Dict("beta" => EpsilonPrior("Laplace"; mu = 0.0, b = 0.5)),
        ),
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
    )
    state = fit!(model)

    @test state isa ModelFitState
    @test state.backend == :turing
    @test hasproperty(state.artifact, :chain)
    @test state.artifact.runtime.seasonality_type == :fourier
    @test size(state.artifact.runtime.seasonality_features) == (6, 4)
    @test state.artifact.runtime.seasonality_beta_prior isa Laplace
    @test params(state.artifact.runtime.seasonality_beta_prior) == (0.0, 0.5)
    @test state.artifact.spec.coordinate_metadata.coordinates["fourier_mode"] ==
        ["sin_1", "sin_2", "cos_1", "cos_2"]
    @test Symbol("beta_seasonality[1]") in names(state.artifact.chain)

    predictive = Epsilon.predict(model)
    @test size(predictive, 1) == model.sampler_config.draws
    @test Symbol("target[1]") in predictive.name_map.parameters
end

@testset "fit! with pooled automatic holiday component" begin
    holidays_path = _write_test_holidays_csv()
    model = sample_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        holidays = Dict(
            "mode" => "auto",
            "path" => holidays_path,
            "countries" => ["UK"],
            "priors" => Dict("beta" => EpsilonPrior("Normal"; mu = 0.0, sigma = 0.5)),
        ),
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
    )
    state = fit!(model)
    generated_holidays = Epsilon._holiday_design_matrix(model.config.holidays, model.data)
    fitted_holidays = Epsilon._holiday_design_matrix(state.artifact.spec.holidays, model.data)
    holdout = MMMData(
        dates = [Date(2024, 1, 29)],
        target = [1.0],
        channels = [1.0 1.0],
        channel_names = ["tv", "search"],
    )
    holdout_holidays = Epsilon._holiday_design_matrix(state.artifact.spec.holidays, holdout)
    reset_holdout_holidays = Epsilon._holiday_design_matrix(model.config.holidays, holdout)

    @test state.artifact.runtime.nholidays == 1
    @test state.artifact.runtime.holiday_beta_prior isa Normal
    @test params(state.artifact.runtime.holiday_beta_prior) == (0.0, 0.5)
    @test state.artifact.spec.coordinate_metadata.coordinates["holiday"] == ["holiday"]
    @test vec(generated_holidays[:, 1]) ≈ [1 / 7, 0.0, 1 / 7, 0.0, 1 / 7, 0.0]
    @test fitted_holidays ≈ generated_holidays
    @test holdout_holidays[1, 1] ≈ 1 / 7
    @test reset_holdout_holidays[1, 1] ≈ 1.0
    @test Symbol("beta_holidays[1]") in names(state.artifact.chain)

    predictive = Epsilon.predict(model)
    @test size(predictive, 1) == model.sampler_config.draws
end

@testset "fit! allows pooled holidays and manual events to coexist" begin
    holidays_path = _write_test_holidays_csv()
    model = sample_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        events = Dict(
            "columns" => ["promo"],
            "priors" => Dict("beta" => EpsilonPrior("Normal"; mu = 0.0, sigma = 0.5)),
        ),
        holidays = Dict(
            "mode" => "auto",
            "path" => holidays_path,
            "countries" => ["UK"],
        ),
        event_values = [0.0; 1.0; 0.0; 1.0; 0.0; 0.0][:, :],
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
    )
    state = fit!(model)

    @test state.artifact.runtime.nevents == 1
    @test state.artifact.runtime.nholidays == 1
    @test state.artifact.spec.coordinate_metadata.coordinates["event"] == ["promo"]
    @test state.artifact.spec.coordinate_metadata.coordinates["holiday"] == ["holiday"]
    @test Symbol("beta_events[1]") in names(state.artifact.chain)
    @test Symbol("beta_holidays[1]") in names(state.artifact.chain)

    predictive = Epsilon.predict(model)
    @test size(predictive, 1) == model.sampler_config.draws
end

@testset "public holiday configs reject fitted Epsilon state" begin
    holidays_path = _write_test_holidays_csv()
    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        holidays = Dict(
            "mode" => "auto",
            "path" => holidays_path,
            "countries" => ["UK"],
            "__epsilon_state" => Dict(
                "dates" => [Date(2024, 1, 1)],
                "period_days" => [7],
                "default_period_days" => 7,
            ),
        ),
    )
end

@testset "fit! with linear trend and fourier seasonality" begin
    model = sample_time_series_model(;
        seasonality = Dict(
            "type" => "fourier",
            "n_order" => 2,
        ),
        trend = Dict(
            "type" => "linear",
            "priors" => Dict("beta" => EpsilonPrior("Normal"; mu = 0.0, sigma = 0.25)),
        ),
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
    )
    state = fit!(model)

    @test state isa ModelFitState
    @test state.backend == :turing
    @test hasproperty(state.artifact, :chain)
    @test state.artifact.runtime.trend_type == :linear
    @test size(state.artifact.runtime.trend_features) == (6, 1)
    @test state.artifact.runtime.trend_features[:, 1] ≈ collect(range(0.0, 1.0; length = 6))
    @test state.artifact.runtime.trend_beta_prior isa Normal
    @test params(state.artifact.runtime.trend_beta_prior) == (0.0, 0.25)
    @test state.artifact.spec.coordinate_metadata.coordinates["trend_term"] == ["linear"]
    @test haskey(state.artifact.spec.trend, "__epsilon_state")
    holdout = MMMData(
        dates = [Date(2024, 2, 12)],
        target = [1.0],
        channels = [1.0 1.0],
        channel_names = ["tv", "search"],
        controls = [0.0][:, :],
        control_names = ["price_index"],
    )
    holdout_runtime, _ = Epsilon._turing_runtime(
        state.artifact.spec,
        holdout;
        control_transform_state = state.artifact.runtime.control_transform_state,
    )
    @test holdout_runtime.trend_features[1, 1] ≈ 1.2
    @test Symbol("beta_trend[1]") in names(state.artifact.chain)

    predictive = Epsilon.predict(model)
    @test size(predictive, 1) == model.sampler_config.draws
    @test Symbol("target[1]") in predictive.name_map.parameters
end

@testset "fit! with changepoint trend and fourier seasonality" begin
    model = sample_time_series_model(;
        seasonality = Dict(
            "type" => "fourier",
            "n_order" => 2,
        ),
        trend = Dict(
            "type" => "changepoint",
            "n_changepoints" => 3,
            "priors" => Dict("delta" => EpsilonPrior("Laplace"; mu = 0.0, b = 0.15)),
        ),
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
    )
    state = fit!(model)

    @test state isa ModelFitState
    @test state.backend == :turing
    @test hasproperty(state.artifact, :chain)
    @test state.artifact.runtime.trend_type == :changepoint
    @test size(state.artifact.runtime.trend_features) == (6, 3)
    @test state.artifact.runtime.trend_features[:, 1] ≈ collect(range(0.0, 1.0; length = 6))
    @test state.artifact.runtime.trend_features[:, 2] ≈ [0.0, 0.0, 1 / 15, 4 / 15, 7 / 15, 2 / 3]
    @test state.artifact.runtime.trend_features[:, 3] ≈ [0.0, 0.0, 0.0, 0.0, 2 / 15, 1 / 3]
    @test state.artifact.runtime.trend_delta_prior isa Laplace
    @test params(state.artifact.runtime.trend_delta_prior) == (0.0, 0.15)
    @test state.artifact.spec.coordinate_metadata.coordinates["trend_term"] ==
        ["changepoint_1", "changepoint_2", "changepoint_3"]
    @test Symbol("delta_trend[1]") in names(state.artifact.chain)

    predictive = Epsilon.predict(model)
    @test size(predictive, 1) == model.sampler_config.draws
    @test Symbol("target[1]") in predictive.name_map.parameters
end

@testset "fit! with events, linear trend, and fourier seasonality" begin
    model = sample_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        trend = Dict("type" => "linear"),
        events = Dict(
            "columns" => ["promo", "holiday"],
            "priors" => Dict("beta" => EpsilonPrior("Normal"; mu = 0.0, sigma = 0.5)),
        ),
        event_values = [1.0 0.0; 0.0 1.0; 0.0 0.0; 1.0 0.0; 0.0 0.0; 0.0 1.0],
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
    )
    state = fit!(model)

    @test state isa ModelFitState
    @test state.backend == :turing
    @test hasproperty(state.artifact, :chain)
    @test state.artifact.runtime.nevents == 2
    @test state.artifact.runtime.event_beta_prior isa Normal
    @test params(state.artifact.runtime.event_beta_prior) == (0.0, 0.5)
    @test state.artifact.spec.coordinate_metadata.coordinates["event"] == ["promo", "holiday"]
    @test Symbol("beta_events[1]") in names(state.artifact.chain)

    predictive = Epsilon.predict(model)
    @test size(predictive, 1) == model.sampler_config.draws
    @test Symbol("target[1]") in predictive.name_map.parameters
end

@testset "fit! with generated event windows" begin
    model = sample_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        trend = Dict("type" => "changepoint", "n_changepoints" => 3),
        events = Dict(
            "windows" => [
                Dict("name" => "promo", "start_date" => "2024-01-08", "end_date" => "2024-01-15"),
                Dict("name" => "holiday", "start_date" => "2024-01-29"),
            ],
            "priors" => Dict("beta" => EpsilonPrior("Normal"; mu = 0.0, sigma = 0.5)),
        ),
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
    )
    state = fit!(model)

    @test state isa ModelFitState
    @test state.backend == :turing
    @test hasproperty(state.artifact, :chain)
    @test state.artifact.runtime.nevents == 2
    @test state.artifact.spec.coordinate_metadata.coordinates["event"] == ["promo", "holiday"]
    @test state.artifact.runtime.event_beta_prior isa Normal
    @test params(state.artifact.runtime.event_beta_prior) == (0.0, 0.5)

    generated_events = Epsilon._event_design_matrix(model.config.events, model.data)
    @test generated_events[:, 1] == [0.0, 1.0, 1.0, 0.0, 0.0, 0.0]
    @test generated_events[:, 2] == [0.0, 0.0, 0.0, 0.0, 1.0, 0.0]
    @test Symbol("beta_events[1]") in names(state.artifact.chain)

    predictive = Epsilon.predict(model)
    @test size(predictive, 1) == model.sampler_config.draws
    @test Symbol("target[1]") in predictive.name_map.parameters
end

@testset "fit! with standardized controls" begin
    model = sample_time_series_model(;
        controls_config = Dict(
            "transform" => "standardize",
            "priors" => Dict("beta" => EpsilonPrior("Normal"; mu = 0.0, sigma = 0.75)),
        ),
    )
    state = fit!(model)

    @test state isa ModelFitState
    @test state.backend == :turing
    @test hasproperty(state.artifact, :chain)
    @test state.artifact.runtime.controls_transform == :standardize
    @test state.artifact.runtime.control_beta_prior isa Normal
    @test params(state.artifact.runtime.control_beta_prior) == (0.0, 0.75)
    @test state.artifact.runtime.control_transform_state.mean ≈ [0.4666666666666666]
    @test state.artifact.runtime.control_transform_state.scale ≈ [0.19720265943665388]

    new_data = MMMData(
        dates = 1:4,
        target = [4.0, 5.0, 6.0, 7.0],
        channels = [1.0 0.5; 2.0 1.0; 3.0 1.5; 4.0 2.0],
        channel_names = ["tv", "search"],
        controls = [0.1; 0.2; 0.3; 0.4][:, :],
        control_names = ["price_index"],
    )
    runtime, transformed_controls = Epsilon._turing_runtime(
        model.config,
        new_data;
        control_transform_state = state.artifact.runtime.control_transform_state,
    )

    @test runtime.controls_transform == :standardize
    @test transformed_controls ≈ (
        [0.1; 0.2; 0.3; 0.4][:, :] .-
            reshape(state.artifact.runtime.control_transform_state.mean, 1, :)
    ) ./
        reshape(state.artifact.runtime.control_transform_state.scale, 1, :)

    predictive = Epsilon.predict(model, new_data)
    @test size(predictive, 1) == model.sampler_config.draws
    @test Symbol("target[1]") in predictive.name_map.parameters
end

@testset "fit! with michaelis-menten saturation" begin
    model = sample_time_series_model(; saturation_type = "michaelis_menten")
    state = fit!(model)

    @test state isa ModelFitState
    @test state.backend == :turing
    @test hasproperty(state.artifact, :chain)

    predictive = Epsilon.predict(model)
    @test size(predictive, 1) == model.sampler_config.draws
    @test Symbol("target[1]") in predictive.name_map.parameters
end

@testset "fit! with delayed adstock" begin
    model = sample_time_series_model(; adstock_type = "delayed")
    state = fit!(model)

    @test state isa ModelFitState
    @test state.backend == :turing
    @test hasproperty(state.artifact, :chain)

    predictive = Epsilon.predict(model)
    @test size(predictive, 1) == model.sampler_config.draws
    @test Symbol("target[1]") in predictive.name_map.parameters
end

@testset "fit! with binomial adstock" begin
    model = sample_time_series_model(; adstock_type = "binomial")
    state = fit!(model)

    @test state isa ModelFitState
    @test state.backend == :turing
    @test hasproperty(state.artifact, :chain)

    predictive = Epsilon.predict(model)
    @test size(predictive, 1) == model.sampler_config.draws
    @test Symbol("target[1]") in predictive.name_map.parameters
end

@testset "fit! with weibull pdf adstock" begin
    model = sample_time_series_model(; adstock_type = "weibull_pdf")
    state = fit!(model)

    @test state isa ModelFitState
    @test state.backend == :turing
    @test hasproperty(state.artifact, :chain)

    predictive = Epsilon.predict(model)
    @test size(predictive, 1) == model.sampler_config.draws
    @test Symbol("target[1]") in predictive.name_map.parameters
end

@testset "fit! with weibull cdf adstock" begin
    model = sample_time_series_model(; adstock_type = "weibull_cdf")
    state = fit!(model)

    @test state isa ModelFitState
    @test state.backend == :turing
    @test hasproperty(state.artifact, :chain)

    predictive = Epsilon.predict(model)
    @test size(predictive, 1) == model.sampler_config.draws
    @test Symbol("target[1]") in predictive.name_map.parameters
end

@testset "build_model" begin
    model = sample_time_series_model()
    spec = build_model(model)
    metadata = spec.coordinate_metadata

    @test spec isa MMMModelSpec
    @test spec.model_kind == :time_series_mmm
    @test spec.nobs == 6
    @test spec.nchannels == 2
    @test spec.ncontrols == 1
    @test metadata.observation_dim == "observation"
    @test metadata.panel_dims == ("geo",)
    @test metadata.coordinates["observation"] == string.(1:6)
    @test metadata.coordinates["channel"] == ["tv", "search"]
    @test metadata.coordinates["control"] == ["price_index"]
    @test metadata.named_dims["target"] == ("observation",)
    @test metadata.named_dims["channels"] == ("observation", "channel")
    @test metadata.named_dims["controls"] == ("observation", "control")
    @test metadata.named_dims["beta_media"] == ("channel",)
    @test metadata.named_dims["beta_controls"] == ("control",)
    @test spec.channel_indices == Dict("tv" => 1, "search" => 2)
    @test spec.control_indices == Dict("price_index" => 1)
    @test model.built_model == spec
end

@testset "build_model with fourier seasonality" begin
    model = sample_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
    )
    spec = build_model(model)
    metadata = spec.coordinate_metadata

    @test spec.seasonality["type"] == "fourier"
    @test spec.seasonality["n_order"] == 2
    @test metadata.coordinates["fourier_mode"] == ["sin_1", "sin_2", "cos_1", "cos_2"]
    @test metadata.named_dims["seasonality_features"] == ("observation", "fourier_mode")
    @test metadata.named_dims["beta_seasonality"] == ("fourier_mode",)
end

@testset "build_model with linear trend" begin
    model = sample_time_series_model(;
        trend = Dict("type" => "linear"),
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
    )
    spec = build_model(model)
    metadata = spec.coordinate_metadata

    @test spec.trend["type"] == "linear"
    @test metadata.coordinates["trend_term"] == ["linear"]
    @test metadata.named_dims["trend_features"] == ("observation", "trend_term")
    @test metadata.named_dims["beta_trend"] == ("trend_term",)
end

@testset "build_model with changepoint trend" begin
    model = sample_time_series_model(;
        trend = Dict("type" => "changepoint", "n_changepoints" => 3),
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
    )
    spec = build_model(model)
    metadata = spec.coordinate_metadata

    @test spec.trend["type"] == "changepoint"
    @test spec.trend["n_changepoints"] == 3
    @test metadata.coordinates["trend_term"] == ["changepoint_1", "changepoint_2", "changepoint_3"]
    @test metadata.named_dims["trend_features"] == ("observation", "trend_term")
    @test metadata.named_dims["delta_trend"] == ("trend_term",)
end

@testset "build_model with events" begin
    model = sample_time_series_model(;
        events = Dict("columns" => ["promo", "holiday"]),
        event_values = [1.0 0.0; 0.0 1.0; 0.0 0.0; 1.0 0.0; 0.0 0.0; 0.0 1.0],
    )
    spec = build_model(model)
    metadata = spec.coordinate_metadata

    @test spec.events["columns"] == ["promo", "holiday"]
    @test metadata.coordinates["event"] == ["promo", "holiday"]
    @test metadata.named_dims["events"] == ("observation", "event")
    @test metadata.named_dims["beta_events"] == ("event",)
end

@testset "build_model with generated event windows" begin
    model = sample_time_series_model(;
        events = Dict(
            "windows" => [
                Dict("name" => "promo", "start_date" => "2024-01-08", "end_date" => "2024-01-15"),
                Dict("name" => "holiday", "start_date" => "2024-01-29"),
            ],
        ),
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
    )
    spec = build_model(model)
    metadata = spec.coordinate_metadata

    @test length(spec.events["windows"]) == 2
    @test metadata.coordinates["event"] == ["promo", "holiday"]
    @test metadata.named_dims["events"] == ("observation", "event")
    @test metadata.named_dims["beta_events"] == ("event",)
end

@testset "build_model with controls config" begin
    model = sample_time_series_model(;
        controls_config = Dict("transform" => "standardize"),
    )
    spec = build_model(model)

    @test spec.controls["transform"] == "standardize"
end

@testset "generated event windows require omitted MMMData.events" begin
    config = ModelConfig(
        date_column = "date",
        target_column = "revenue",
        target_type = "revenue",
        channel_columns = ["tv", "search"],
        control_columns = ["price_index"],
        dims = ("geo",),
        adstock = Dict("type" => "geometric", "l_max" => 8),
        saturation = Dict("type" => "logistic"),
        events = Dict(
            "windows" => [
                Dict("name" => "promo", "start_date" => "2024-01-08", "end_date" => "2024-01-15"),
            ],
        ),
    )
    data = MMMData(
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
        target = [5.0, 6.5, 7.5, 9.0, 10.0, 11.5],
        channels = [1.0 0.5; 2.0 1.0; 2.5 1.5; 3.0 2.0; 3.5 2.5; 4.0 3.0],
        channel_names = ["tv", "search"],
        controls = [0.2; 0.4; 0.3; 0.6; 0.5; 0.8][:, :],
        control_names = ["price_index"],
        events = [1.0; 0.0; 0.0; 1.0; 0.0; 0.0][:, :],
        event_names = ["promo"],
    )

    @test_throws ArgumentError TimeSeriesMMM(
        config,
        sample_time_series_model().sampler_config,
        data,
    )
end

@testset "fit!" begin
    model = sample_time_series_model()
    state = fit!(model)

    @test state isa ModelFitState
    @test state.status == :fit
    @test state.backend == :turing
    @test state.artifact.spec isa MMMModelSpec
    @test hasproperty(state.artifact, :chain)
    @test state.artifact.metadata isa ModelArtifactMetadata
    @test state.artifact.metadata.model_type == "TimeSeriesMMM"
    @test state.artifact.metadata.backend == :turing
    @test state.artifact.metadata.fit_status == :fit
    @test state.artifact.diagnostics === nothing
    @test state.artifact.sampler_diagnostics === nothing
    @test state.artifact.sampler_warnings === nothing
    @test state.artifact.convergence_report === nothing
    @test state.artifact.convergence_warnings === nothing
    @test size(state.artifact.chain, 1) == model.sampler_config.draws
    @test occursin("current Turing NUTS path", state.message)
    @test occursin("single-chain execution", state.message)
    @test model.fit_state == state
end

@testset "fit! multi-chain execution honors available backend" begin
    model = sample_multichain_time_series_model()
    state = fit!(model)

    @test state isa ModelFitState
    @test state.backend == :turing
    @test hasproperty(state.artifact, :execution_backend)
    @test size(state.artifact.chain, 3) == model.sampler_config.chains

    if Base.Threads.nthreads() > 1
        @test state.artifact.execution_backend == :threads
        @test occursin("threaded multi-chain execution", state.message)
    else
        @test state.artifact.execution_backend == :serial
        @test occursin("serial multi-chain execution", state.message)
    end
end

@testset "fit! multi-chain execution respects cores gate" begin
    model = sample_multichain_time_series_model(; cores = 1)
    state = fit!(model)

    @test state.artifact.execution_backend == :serial
    @test occursin("serial multi-chain execution", state.message)
end

@testset "fit! computes convergence checks when enabled" begin
    model = sample_multichain_time_series_model(; cores = 1, compute_convergence_checks = true)
    state = fit!(model)

    @test state.artifact.diagnostics isa ModelDiagnostics
    @test state.artifact.sampler_diagnostics isa SamplerDiagnostics
    @test state.artifact.sampler_warnings isa SamplerWarnings
    @test state.artifact.convergence_report isa ConvergenceReport
    @test state.artifact.convergence_warnings isa ConvergenceWarnings
    @test state.artifact.sampler_diagnostics.max_tree_depth >= 0
    @test state.artifact.sampler_diagnostics.max_n_steps >= 0
    @test state.artifact.sampler_diagnostics.max_abs_max_hamiltonian_energy_error >= 0.0
    @test state.artifact.sampler_warnings.summary.nwarnings >= 0
    @test state.artifact.convergence_report.summary.nparameters > 0
    @test state.artifact.convergence_report.summary.rhat_threshold == 1.05
    @test state.artifact.convergence_report.summary.ess_threshold == 100.0
    @test state.artifact.convergence_warnings.summary.nwarnings >= 0
    @test occursin("Sampler internals recorded", state.message)
    @test occursin("sampler warnings", state.message)
    @test occursin("Convergence checks completed", state.message)
    @test occursin("convergence warnings", state.message)
end

@testset "predict" begin
    model = sample_time_series_model()
    @test_throws ArgumentError Epsilon.predict(model)

    fit!(model)
    predictive = Epsilon.predict(model)
    @test size(predictive, 1) == model.sampler_config.draws
    @test Symbol("target[1]") in predictive.name_map.parameters
end

@testset "prior_predict" begin
    model = sample_time_series_model()
    predictive = Epsilon.prior_predict(model)

    @test size(predictive, 1) == model.sampler_config.draws
    @test Symbol("target[1]") in predictive.name_map.parameters
    @test :intercept in predictive.name_map.parameters
end

@testset "fit! honors random_seed deterministically" begin
    first_model = sample_time_series_model()
    second_model = sample_time_series_model()

    first_state = fit!(first_model)
    second_state = fit!(second_model)

    @test Array(first_state.artifact.chain) == Array(second_state.artifact.chain)
    @test names(first_state.artifact.chain) == names(second_state.artifact.chain)
end

@testset "fit! honors random_seed deterministically for serial multi-chain" begin
    first_model = sample_multichain_time_series_model(; cores = 1)
    second_model = sample_multichain_time_series_model(; cores = 1)

    first_state = fit!(first_model)
    second_state = fit!(second_model)

    @test first_state.artifact.execution_backend == :serial
    @test second_state.artifact.execution_backend == :serial
    @test Array(first_state.artifact.chain) == Array(second_state.artifact.chain)
    @test names(first_state.artifact.chain) == names(second_state.artifact.chain)
end

@testset "prior_predict honors random_seed deterministically" begin
    first_model = sample_time_series_model()
    second_model = sample_time_series_model()

    first_predictive = Epsilon.prior_predict(first_model)
    second_predictive = Epsilon.prior_predict(second_model)

    @test Array(first_predictive) == Array(second_predictive)
    @test names(first_predictive) == names(second_predictive)
end

@testset "fit! uses controls.priors.beta over default control prior" begin
    config = ModelConfig(
        date_column = "date",
        target_column = "revenue",
        target_type = "revenue",
        channel_columns = ["tv", "search"],
        control_columns = ["price_index"],
        controls = Dict(
            "transform" => "standardize",
            "priors" => Dict("beta" => EpsilonPrior("Normal"; mu = 5.0, sigma = 6.0)),
        ),
        dims = ("geo",),
        adstock = Dict("type" => "geometric", "l_max" => 8),
        saturation = Dict("type" => "logistic"),
        priors = Dict("intercept" => EpsilonPrior("Normal"; mu = 0.0, sigma = 1.0)),
    )
    model = TimeSeriesMMM(config, sample_time_series_model().sampler_config, sample_time_series_model().data)
    state = fit!(model)

    @test state.artifact.runtime.control_beta_prior isa Normal
    @test params(state.artifact.runtime.control_beta_prior) == (5.0, 6.0)
end

@testset "fit! attaches resolved calibration spec to the artifact" begin
    model = sample_time_series_model()
    state = fit!(model)
    @test state.artifact.calibration === nothing

    lift_test_data = LiftTestCalibrationRows(
        channel = ["tv"],
        x = [1.0],
        delta_x = [0.5],
        delta_y = [0.3],
        sigma = [0.1],
    )
    calibrated_model = TimeSeriesMMM(
        model.config,
        model.sampler_config,
        model.data;
        calibration_steps = [CalibrationStepConfig(method = "add_lift_test_measurements")],
        lift_test_data = lift_test_data,
    )
    calibrated_state = fit!(calibrated_model)

    @test calibrated_state isa ModelFitState
    @test calibrated_state.status == :fit
    @test calibrated_state.artifact.calibration isa MMMCalibrationSpec

    expected = Epsilon._resolve_calibration_spec(
        calibrated_model.config,
        calibrated_model.calibration,
        calibrated_state.artifact.spec.channel_scale,
        calibrated_state.artifact.spec.target_scale,
    )
    @test calibrated_state.artifact.calibration == expected
    @test calibrated_state.artifact.calibration.lift_test isa LiftTestCalibrationPayload
    @test calibrated_state.artifact.calibration.cost_per_target === nothing

    predictive = Epsilon.predict(calibrated_model)
    @test size(predictive, 1) == calibrated_model.sampler_config.draws
end

@testset "lift-test calibration adds the expected log-density term to _time_series_mmm_model" begin
    model = sample_time_series_model()
    spec = build_model(model)
    runtime, controls = Epsilon._turing_runtime(model.config, model.data)
    events = Epsilon._event_design_matrix(model.config.events, model.data)
    holidays = Epsilon._holiday_design_matrix(model.config.holidays, model.data)
    scaled_channels = Epsilon._scale_channels(model.data.channels, spec.channel_scale)
    scaled_target = model.data.target ./ spec.target_scale

    lift_test_data = LiftTestCalibrationRows(
        channel = ["tv"],
        x = [1.0],
        delta_x = [0.5],
        delta_y = [0.3],
        sigma = [0.1],
    )
    calibration_input = Epsilon._build_calibration_input(
        [CalibrationStepConfig(method = "add_lift_test_measurements")],
        lift_test_data,
        nothing,
    )
    calibration = Epsilon._resolve_calibration_spec(
        model.config,
        calibration_input,
        spec.channel_scale,
        spec.target_scale,
    )
    lift_test_payload = calibration.lift_test
    @test lift_test_payload isa LiftTestCalibrationPayload

    uncalibrated_model = Epsilon._time_series_mmm_model(
        scaled_target, scaled_channels, controls, events, holidays, runtime,
    )
    calibrated_model = Epsilon._time_series_mmm_model(
        scaled_target, scaled_channels, controls, events, holidays, runtime;
        lift_test_payload = lift_test_payload,
    )

    fixed_params = (;
        intercept = 0.1,
        sigma = 0.5,
        beta_media = [0.3, 0.4],
        alpha = [0.2, 0.25],
        lam = [0.6, 0.7],
        beta_controls = [0.05],
    )

    uncalibrated_conditioned = Turing.DynamicPPL.condition(uncalibrated_model, fixed_params)
    calibrated_conditioned = Turing.DynamicPPL.condition(calibrated_model, fixed_params)

    _, uncalibrated_vi = Turing.DynamicPPL.evaluate!!(
        uncalibrated_conditioned, Turing.DynamicPPL.VarInfo(uncalibrated_conditioned),
    )
    _, calibrated_vi = Turing.DynamicPPL.evaluate!!(
        calibrated_conditioned, Turing.DynamicPPL.VarInfo(calibrated_conditioned),
    )

    uncalibrated_logjoint = Turing.DynamicPPL.getlogjoint(uncalibrated_vi)
    calibrated_logjoint = Turing.DynamicPPL.getlogjoint(calibrated_vi)

    expected_term = lift_test_payload_log_density(
        (x_row, lam_row) -> centered_logistic_saturation.(x_row, lam_row),
        lift_test_payload,
        fixed_params.lam,
    )

    @test calibrated_logjoint - uncalibrated_logjoint ≈ expected_term
    @test expected_term != 0.0
end

@testset "lift-test calibration rejects non-logistic saturation" begin
    model = sample_time_series_model(; saturation_type = "tanh")
    lift_test_data = LiftTestCalibrationRows(
        channel = ["tv"],
        x = [1.0],
        delta_x = [0.5],
        delta_y = [0.3],
        sigma = [0.1],
    )
    calibrated_model = TimeSeriesMMM(
        model.config,
        model.sampler_config,
        model.data;
        calibration_steps = [CalibrationStepConfig(method = "add_lift_test_measurements")],
        lift_test_data = lift_test_data,
    )

    @test_throws ArgumentError fit!(calibrated_model)
end

@testset "fit! with logistic saturation and lift-test calibration is a tiny MCMC smoke test" begin
    model = sample_time_series_model()
    lift_test_data = LiftTestCalibrationRows(
        channel = ["tv"],
        x = [1.0],
        delta_x = [0.5],
        delta_y = [0.3],
        sigma = [0.1],
    )
    calibrated_model = TimeSeriesMMM(
        model.config,
        model.sampler_config,
        model.data;
        calibration_steps = [CalibrationStepConfig(method = "add_lift_test_measurements")],
        lift_test_data = lift_test_data,
    )
    state = fit!(calibrated_model)

    @test state isa ModelFitState
    @test state.status == :fit
    @test state.artifact.calibration isa MMMCalibrationSpec
    @test state.artifact.calibration.lift_test isa LiftTestCalibrationPayload
    @test size(state.artifact.chain, 1) == calibrated_model.sampler_config.draws
end

@testset "fit! rebuilds spec from current model state" begin
    model = sample_time_series_model()
    original_spec = build_model(model)
    @test original_spec.nobs == 6

    model.data = MMMData(
        dates = 1:4,
        target = [5.0, 6.5, 7.5, 9.0],
        channels = [1.0 0.5; 2.0 1.0; 2.5 1.5; 3.0 2.0],
        channel_names = ["tv", "search"],
        controls = [0.2; 0.4; 0.3; 0.6][:, :],
        control_names = ["price_index"],
    )

    state = fit!(model)

    @test state.artifact.spec.nobs == 4
    @test model.built_model == state.artifact.spec
    @test model.built_model != original_spec
end
