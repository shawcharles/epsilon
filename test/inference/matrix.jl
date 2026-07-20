using Epsilon
using Test

@testset "inference matrix row TS-MCMC" begin
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

@testset "inference matrix row P-MCMC" begin
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
