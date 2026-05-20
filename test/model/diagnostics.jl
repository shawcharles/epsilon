using Epsilon
using Test

function sample_diagnostics_model()
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
        cores = 1,
        target_accept = 0.8,
        random_seed = 9,
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
    model = TimeSeriesMMM(config, sampler, data)
    fit!(model)
    return model
end

@testset "model_diagnostics from results" begin
    model = sample_diagnostics_model()
    results = model_results(model; include_posterior_predictive = false)
    diagnostics = model_diagnostics(results)

    @test diagnostics isa ModelDiagnostics
    @test diagnostics.metadata == results.metadata
    @test haskey(diagnostics.parameter_diagnostics, "intercept")
    @test haskey(diagnostics.parameter_diagnostics, "sigma")
    @test diagnostics.parameter_diagnostics["intercept"] isa ParameterDiagnostics
    @test !ismissing(diagnostics.parameter_diagnostics["intercept"].rhat)
    @test diagnostics.parameter_diagnostics["intercept"].ess_bulk > 0
    @test diagnostics.parameter_diagnostics["intercept"].ess_tail > 0
    @test diagnostics.parameter_diagnostics["intercept"].mcse_mean >= 0
end

@testset "model_diagnostics from model" begin
    model = sample_diagnostics_model()
    diagnostics = model_diagnostics(model)

    @test diagnostics isa ModelDiagnostics
    @test diagnostics.metadata.model_type == "TimeSeriesMMM"
    @test haskey(diagnostics.parameter_diagnostics, "beta_media[1]")
end

@testset "sampler_diagnostics from results" begin
    model = sample_diagnostics_model()
    results = model_results(model; include_posterior_predictive = false)
    diagnostics = sampler_diagnostics(results)

    @test diagnostics isa SamplerDiagnostics
    @test diagnostics.metadata == results.metadata
    @test diagnostics.numerical_error_count >= 0
    @test 0.0 <= diagnostics.numerical_error_rate <= 1.0
    @test diagnostics.mean_abs_hamiltonian_energy_error >= 0.0
    @test diagnostics.max_abs_hamiltonian_energy_error >= 0.0
    @test diagnostics.max_abs_max_hamiltonian_energy_error >= 0.0
    @test diagnostics.max_tree_depth >= 0
    @test diagnostics.mean_tree_depth >= 0.0
    @test diagnostics.max_n_steps >= 0
    @test diagnostics.mean_n_steps >= 0.0
    @test diagnostics.mean_acceptance_rate >= 0.0
    @test diagnostics.mean_step_size >= 0.0
end

@testset "sampler_diagnostics from model" begin
    model = sample_diagnostics_model()
    diagnostics = sampler_diagnostics(model)

    @test diagnostics isa SamplerDiagnostics
    @test diagnostics.metadata.model_type == "TimeSeriesMMM"
    @test !has_numerical_errors(diagnostics) || diagnostics.numerical_error_count > 0
end

@testset "sampler_warnings from diagnostics" begin
    model = sample_diagnostics_model()
    diagnostics = sampler_diagnostics(model)
    warnings = sampler_warnings(
        diagnostics;
        numerical_error_threshold = -1,
        energy_error_threshold = -1.0,
        tree_depth_threshold = 0,
        acceptance_rate_threshold = 2.0,
    )

    @test warnings isa SamplerWarnings
    @test warnings.metadata == diagnostics.metadata
    @test warnings.summary.nwarnings == length(warnings.warnings)
    @test warnings.summary.high > 0
    @test warnings.summary.medium > 0
    @test has_sampler_warnings(warnings)
    @test warnings.warnings[1] isa SamplerWarning
    @test !isempty(warnings.warnings[1].message)
    @test warnings.warnings[1].severity in (:high, :medium)
end

@testset "sampler_warnings from model" begin
    model = sample_diagnostics_model()
    warnings = sampler_warnings(
        model;
        numerical_error_threshold = typemax(Int),
        energy_error_threshold = typemax(Float64),
        tree_depth_threshold = typemax(Int),
        acceptance_rate_threshold = 0.0,
    )

    @test warnings isa SamplerWarnings
    @test isempty(warnings.warnings)
    @test warnings.summary.nwarnings == 0
    @test !has_sampler_warnings(warnings)
end

@testset "convergence_report from results" begin
    model = sample_diagnostics_model()
    results = model_results(model; include_posterior_predictive = false)
    report = convergence_report(results; rhat_threshold = 1.0, ess_threshold = 1.0e6)

    @test report isa ConvergenceReport
    @test report.metadata == results.metadata
    @test report.summary.nparameters > 0
    @test report.summary.nissues == length(report.issues)
    @test report.summary.rhat_threshold == 1.0
    @test report.summary.ess_threshold == 1.0e6
    @test report.summary.rhat_failures > 0
    @test report.summary.ess_bulk_failures > 0
    @test report.summary.ess_tail_failures > 0
    @test !isempty(report.summary.flagged_parameters)
    @test has_convergence_issues(report)
    @test report.issues[1] isa ConvergenceIssue
    @test report.issues[1].metric in (:rhat, :ess_bulk, :ess_tail)
end

@testset "convergence_report from model" begin
    model = sample_diagnostics_model()
    report = convergence_report(model; rhat_threshold = 10.0, ess_threshold = 0.0)

    @test report isa ConvergenceReport
    @test report.summary.nparameters > 0
    @test isempty(report.issues)
    @test !has_convergence_issues(report)
end

@testset "convergence_warnings from report" begin
    model = sample_diagnostics_model()
    results = model_results(model; include_posterior_predictive = false)
    warnings = convergence_warnings(results; rhat_threshold = 1.0, ess_threshold = 1.0e6)

    @test warnings isa ConvergenceWarnings
    @test warnings.metadata == results.metadata
    @test warnings.summary.nwarnings == length(warnings.warnings)
    @test warnings.summary.high > 0
    @test warnings.summary.medium > 0
    @test !isempty(warnings.summary.flagged_parameters)
    @test has_convergence_warnings(warnings)
    @test warnings.warnings[1] isa ConvergenceWarning
    @test !isempty(warnings.warnings[1].message)
    @test warnings.warnings[1].severity in (:high, :medium)
end

@testset "convergence_warnings from model" begin
    model = sample_diagnostics_model()
    warnings = convergence_warnings(model; rhat_threshold = 10.0, ess_threshold = 0.0)

    @test warnings isa ConvergenceWarnings
    @test isempty(warnings.warnings)
    @test warnings.summary.nwarnings == 0
    @test !has_convergence_warnings(warnings)
end
