using Dates
using Epsilon
using Test

@testset "VariationalConfig validates the bounded VI family" begin
    config = VariationalConfig(; max_iters = 25, draws = 12, progressbar = false)
    @test config.family == :meanfield_gaussian

    @test_throws ArgumentError VariationalConfig(family = :fullrank_gaussian)
end

@testset "approximate_fit! supports one bounded TimeSeriesMMM Phase 5 bundle" begin
    model = sample_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        trend = Dict("type" => "linear"),
        events = Dict(
            "columns" => ["promo", "holiday"],
            "priors" => Dict("beta" => EpsilonPrior("Normal"; mu = 0.0, sigma = 0.5)),
        ),
        controls_config = Dict(
            "transform" => "standardize",
            "priors" => Dict("beta" => EpsilonPrior("Normal"; mu = 0.0, sigma = 0.75)),
        ),
        event_values = [1.0 0.0; 0.0 1.0; 0.0 0.0; 1.0 0.0; 0.0 0.0; 0.0 1.0],
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
    )
    config = VariationalConfig(;
        max_iters = 10,
        draws = 7,
        random_seed = 19,
        progressbar = false,
    )

    state = approximate_fit!(model, config)

    @test state isa ModelFitState
    @test state.status == :fit
    @test state.backend == :variational
    @test state.artifact.metadata isa ModelArtifactMetadata
    @test state.artifact.metadata.backend == :variational
    @test state.artifact.metadata.fit_status == :fit
    @test state.artifact.variational_config == config
    @test state.artifact.approximation_family == :meanfield_gaussian
    @test state.artifact.materialized_draws == config.draws
    @test size(state.artifact.chain, 1) == config.draws
    @test :intercept in names(state.artifact.chain, :parameters)
    @test Symbol("beta_controls[1]") in names(state.artifact.chain, :parameters)
    @test Symbol("beta_events[1]") in names(state.artifact.chain, :parameters)
    @test Symbol("beta_seasonality[1]") in names(state.artifact.chain, :parameters)
    @test Symbol("beta_trend[1]") in names(state.artifact.chain, :parameters)

    predictive = Epsilon.predict(model)
    @test size(predictive, 1) == config.draws
    @test Symbol("target[1]") in names(predictive, :parameters)

    grouped = inference_results(model; include_prior = true, include_prior_predictive = true)
    @test grouped isa InferenceResults
    @test grouped.metadata.backend == :variational
    @test grouped.sample_stats.diagnostics === nothing
    @test grouped.sample_stats.sampler_diagnostics === nothing
    @test grouped.sample_stats.sampler_warnings === nothing
    @test grouped.sample_stats.convergence_report === nothing
    @test grouped.sample_stats.convergence_warnings === nothing
    @test :logjoint in names(grouped.sample_stats.internals, :internals)
    @test size(grouped.posterior, 1) == config.draws
    @test size(grouped.posterior_predictive, 1) == config.draws
    @test size(grouped.prior_predictive, 1) == config.draws
    @test :intercept in names(grouped.prior, :parameters)
    @test !(Symbol("target[1]") in names(grouped.prior, :parameters))

    path = tempname()
    save_inference_results(path, grouped)
    loaded = load_inference_results(path)
    @test loaded == grouped
end

@testset "VI grouped inference keeps single-chain grouped artifacts under multichain sampler settings" begin
    model = sample_multichain_time_series_model(; cores = 2)
    config = VariationalConfig(;
        max_iters = 5,
        draws = 6,
        random_seed = 41,
        progressbar = false,
    )

    approximate_fit!(model, config)

    direct_prior = prior_predict(model)
    grouped = inference_results(model; include_prior = true, include_prior_predictive = true)

    @test size(direct_prior, 1) == model.sampler_config.draws * model.sampler_config.chains
    @test size(direct_prior, 3) == 1
    @test size(grouped.posterior, 1) == config.draws
    @test size(grouped.posterior, 3) == 1
    @test size(grouped.posterior_predictive, 1) == config.draws
    @test size(grouped.posterior_predictive, 3) == 1
    @test size(grouped.prior, 1) == config.draws
    @test size(grouped.prior, 3) == 1
    @test size(grouped.prior_predictive, 1) == config.draws
    @test size(grouped.prior_predictive, 3) == 1
end

@testset "VI grouped inference uses the fitted artifact spec after config drift" begin
    model = sample_time_series_model()
    config = VariationalConfig(;
        max_iters = 5,
        draws = 6,
        random_seed = 43,
        progressbar = false,
    )
    approximate_fit!(model, config)
    fitted_spec = model.fit_state.artifact.spec

    model.config.adstock["type"] = "unsupported"
    model.config.saturation["type"] = "unsupported"

    grouped = inference_results(model; include_prior = true, include_prior_predictive = true)

    @test grouped.spec.adstock == fitted_spec.adstock
    @test grouped.spec.saturation == fitted_spec.saturation
    @test size(grouped.posterior_predictive, 1) == config.draws
    @test size(grouped.prior_predictive, 1) == config.draws
end

@testset "VI grouped inference ignores seasonality trend events and controls drift" begin
    model = sample_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        trend = Dict("type" => "linear"),
        events = Dict("columns" => ["promo", "holiday"]),
        controls_config = Dict("transform" => "standardize"),
        event_values = [1.0 0.0; 0.0 1.0; 0.0 0.0; 1.0 0.0; 0.0 0.0; 0.0 1.0],
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
    )
    config = VariationalConfig(;
        max_iters = 5,
        draws = 6,
        random_seed = 47,
        progressbar = false,
    )
    approximate_fit!(model, config)
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
    @test size(grouped.posterior_predictive, 1) == config.draws
    @test size(grouped.prior_predictive, 1) == config.draws
end

@testset "model_results stays MCMC-only for variational fit states" begin
    model = sample_time_series_model()
    approximate_fit!(
        model,
        VariationalConfig(; max_iters = 5, draws = 5, random_seed = 23, progressbar = false),
    )

    err = try
        model_results(model)
        nothing
    catch caught
        caught
    end
    diagnostics_error = try
        model_diagnostics(model)
        nothing
    catch caught
        caught
    end
    sampler_error = try
        sampler_diagnostics(model)
        nothing
    catch caught
        caught
    end
    convergence_report_error = try
        convergence_report(model)
        nothing
    catch caught
        caught
    end
    convergence_warnings_error = try
        convergence_warnings(model)
        nothing
    catch caught
        caught
    end

    @test err isa ArgumentError
    @test diagnostics_error isa ArgumentError
    @test sampler_error isa ArgumentError
    @test convergence_report_error isa ArgumentError
    @test convergence_warnings_error isa ArgumentError
    @test occursin("Turing-backed fit states", sprint(showerror, err))
    @test occursin("Turing-backed fit states", sprint(showerror, diagnostics_error))
    @test occursin("Turing-backed fit states", sprint(showerror, sampler_error))
    @test occursin("Turing-backed fit states", sprint(showerror, convergence_report_error))
    @test occursin("Turing-backed fit states", sprint(showerror, convergence_warnings_error))
end

@testset "approximate_fit! rejects unsupported PanelMMM paths honestly" begin
    model = sample_panel_model()
    fit!(model)

    err = try
        approximate_fit!(
            model,
            VariationalConfig(; max_iters = 5, draws = 5, random_seed = 29, progressbar = false),
        )
        nothing
    catch caught
        caught
    end

    @test err isa ArgumentError
    @test occursin("PanelMMM variational inference is not supported", sprint(showerror, err))
    @test model.fit_state.status == :error
    @test model.fit_state.backend == :variational
    @test isnothing(model.fit_state.artifact)
    @test occursin("approximate_fit! failed before producing a valid variational artifact", model.fit_state.message)
end

@testset "approximate_fit! rejects calibrated TimeSeriesMMM honestly" begin
    base_model = sample_time_series_model()
    lift_test_data = LiftTestCalibrationRows(
        channel = ["tv"],
        x = [1.0],
        delta_x = [0.5],
        delta_y = [0.3],
        sigma = [0.1],
    )
    model = TimeSeriesMMM(
        base_model.config,
        base_model.sampler_config,
        base_model.data;
        calibration_steps = [CalibrationStepConfig(method = "add_lift_test_measurements")],
        lift_test_data = lift_test_data,
    )

    err = try
        approximate_fit!(
            model,
            VariationalConfig(; max_iters = 5, draws = 5, random_seed = 53, progressbar = false),
        )
        nothing
    catch caught
        caught
    end

    @test err isa ArgumentError
    @test occursin("approximate_fit! does not support calibrated TimeSeriesMMM models", sprint(showerror, err))
    @test model.fit_state.status == :error
    @test model.fit_state.backend == :variational
    @test isnothing(model.fit_state.artifact)
    @test occursin("approximate_fit! failed before producing a valid variational artifact", model.fit_state.message)
end
