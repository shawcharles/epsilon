using Epsilon
using Test

@testset "fit! stores explicit MCMC execution plan" begin
    model = sample_multichain_time_series_model(; cores = 1)
    state = fit!(model)

    @test hasproperty(state.artifact, :execution_plan)
    @test state.artifact.execution_plan isa Epsilon.MCMCExecutionPlan
    @test state.artifact.execution_plan.mode == :serial
    @test state.artifact.execution_plan.requested_chains == model.sampler_config.chains
    @test state.artifact.execution_plan.requested_cores == model.sampler_config.cores
    @test state.artifact.execution_plan.effective_cores == min(model.sampler_config.cores, model.sampler_config.chains)
    @test state.artifact.execution_plan.available_threads == Base.Threads.nthreads()
end

@testset "fit! failure replaces stale successful state for TimeSeriesMMM" begin
    model = sample_time_series_model()
    fit!(model)

    model.data = MMMData(
        dates = model.data.dates,
        target = model.data.target,
        channels = model.data.channels,
        channel_names = ["search", "tv"],
        controls = model.data.controls,
        control_names = model.data.control_names,
    )

    fit_error = try
        fit!(model)
        nothing
    catch err
        err
    end

    @test fit_error isa ArgumentError
    @test model.fit_state.status == :error
    @test model.fit_state.backend == :turing
    @test isnothing(model.fit_state.artifact)
    @test occursin("failed before producing a valid Turing artifact", model.fit_state.message)

    predict_error = try
        Epsilon.predict(model)
        nothing
    catch err
        err
    end
    @test predict_error isa ArgumentError
    @test occursin("last fit! failed", sprint(showerror, predict_error))

    results_error = try
        model_results(model)
        nothing
    catch err
        err
    end
    @test results_error isa ArgumentError
    @test occursin("last fit! failed", sprint(showerror, results_error))
end

@testset "fit! failure replaces stale successful state for PanelMMM" begin
    model = sample_panel_model()
    fit!(model)

    model.config = ModelConfig(
        date_column = model.config.date_column,
        target_column = model.config.target_column,
        target_type = model.config.target_type,
        channel_columns = model.config.channel_columns,
        control_columns = model.config.control_columns,
        dims = model.config.dims,
        adstock = model.config.adstock,
        saturation = model.config.saturation,
        seasonality = model.config.seasonality,
        trend = Dict("type" => "linear"),
        events = model.config.events,
        controls = model.config.controls,
        priors = model.config.priors,
        extras = model.config.extras,
    )

    fit_error = try
        fit!(model)
        nothing
    catch err
        err
    end

    @test fit_error isa ArgumentError
    @test model.fit_state.status == :error
    @test model.fit_state.backend == :turing
    @test isnothing(model.fit_state.artifact)
    @test occursin("failed before producing a valid Turing artifact", model.fit_state.message)

    diagnostics_error = try
        model_diagnostics(model)
        nothing
    catch err
        err
    end
    @test diagnostics_error isa ArgumentError
    @test occursin("last fit! failed", sprint(showerror, diagnostics_error))
end

@testset "panel diagnostics helpers work on fitted PanelMMM" begin
    model = sample_panel_model()
    fit!(model)

    diagnostics = model_diagnostics(model)
    sampler = sampler_diagnostics(model)
    report = convergence_report(model; rhat_threshold = 10.0, ess_threshold = 0.0)
    warnings = convergence_warnings(model; rhat_threshold = 10.0, ess_threshold = 0.0)

    @test diagnostics isa ModelDiagnostics
    @test sampler isa SamplerDiagnostics
    @test report isa ConvergenceReport
    @test warnings isa ConvergenceWarnings
    @test diagnostics.metadata.model_type == "PanelMMM"
    @test sampler.metadata.model_type == "PanelMMM"
    @test report.metadata.model_type == "PanelMMM"
    @test warnings.metadata.model_type == "PanelMMM"
end
