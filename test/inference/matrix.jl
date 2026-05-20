using Epsilon
using Test

@testset "Phase 6 inference matrix row TS-MCMC" begin
    model = sample_time_series_model()
    state = fit!(model)

    @test state.backend == :turing

    predictive = Epsilon.predict(model)
    prior = Epsilon.prior_predict(model)
    flat = model_results(model)
    grouped = inference_results(model)
    diagnostics = model_diagnostics(model)
    sampler = sampler_diagnostics(model)
    report = convergence_report(model; rhat_threshold = 10.0, ess_threshold = 0.0)

    @test size(predictive, 1) == model.sampler_config.draws
    @test size(prior, 1) == model.sampler_config.draws
    @test flat isa ModelResults
    @test grouped isa InferenceResults
    @test diagnostics isa ModelDiagnostics
    @test sampler isa SamplerDiagnostics
    @test report isa ConvergenceReport
end

@testset "Phase 6 inference matrix row P-MCMC" begin
    model = sample_panel_model()
    state = fit!(model)

    @test state.backend == :turing

    predictive = Epsilon.predict(model)
    prior = Epsilon.prior_predict(model)
    flat = model_results(model)
    grouped = inference_results(model)
    diagnostics = model_diagnostics(model)
    sampler = sampler_diagnostics(model)
    report = convergence_report(model; rhat_threshold = 10.0, ess_threshold = 0.0)

    @test size(predictive, 1) == model.sampler_config.draws
    @test size(prior, 1) == model.sampler_config.draws
    @test flat isa ModelResults
    @test grouped isa InferenceResults
    @test diagnostics isa ModelDiagnostics
    @test sampler isa SamplerDiagnostics
    @test report isa ConvergenceReport
end

@testset "Phase 6 inference matrix row TS-VI" begin
    model = sample_time_series_model()
    vi_config = VariationalConfig(;
        max_iters = 5,
        draws = 6,
        random_seed = 31,
        progressbar = false,
    )
    state = approximate_fit!(model, vi_config)

    @test state.backend == :variational

    predictive = Epsilon.predict(model)
    direct_prior = Epsilon.prior_predict(model)
    grouped = inference_results(model; include_prior = true, include_prior_predictive = true)

    @test size(predictive, 1) == vi_config.draws
    @test size(direct_prior, 1) == model.sampler_config.draws
    @test size(grouped.posterior_predictive, 1) == vi_config.draws
    @test size(grouped.prior_predictive, 1) == vi_config.draws
    @test grouped isa InferenceResults

    flat_error = try
        model_results(model)
        nothing
    catch err
        err
    end
    diagnostics_error = try
        model_diagnostics(model)
        nothing
    catch err
        err
    end
    sampler_error = try
        sampler_diagnostics(model)
        nothing
    catch err
        err
    end
    convergence_report_error = try
        convergence_report(model)
        nothing
    catch err
        err
    end
    convergence_warnings_error = try
        convergence_warnings(model)
        nothing
    catch err
        err
    end

    @test flat_error isa ArgumentError
    @test diagnostics_error isa ArgumentError
    @test sampler_error isa ArgumentError
    @test convergence_report_error isa ArgumentError
    @test convergence_warnings_error isa ArgumentError
    @test occursin("Turing-backed fit states", sprint(showerror, flat_error))
    @test occursin("Turing-backed fit states", sprint(showerror, diagnostics_error))
    @test occursin("Turing-backed fit states", sprint(showerror, sampler_error))
    @test occursin("Turing-backed fit states", sprint(showerror, convergence_report_error))
    @test occursin("Turing-backed fit states", sprint(showerror, convergence_warnings_error))
end

@testset "Phase 6 inference matrix unsupported rows" begin
    panel = sample_panel_model()
    panel_error = try
        approximate_fit!(
            panel,
            VariationalConfig(; max_iters = 5, draws = 5, random_seed = 37, progressbar = false),
        )
        nothing
    catch err
        err
    end

    @test panel_error isa ArgumentError
    @test occursin("PanelMMM variational inference is not supported", sprint(showerror, panel_error))
end
