using Epsilon
using Test

function sample_time_series_model()
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
    sampler = SamplerConfig(; draws = 1500, tune = 500, chains = 2, cores = 1, target_accept = 0.9)
    data = MMMData(
        dates = 1:3,
        target = [10.0, 12.0, 14.0],
        channels = [1.0 2.0; 3.0 4.0; 5.0 6.0],
        channel_names = ["tv", "search"],
        controls = [7.0; 8.0; 9.0][:, :],
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
        dates = 1:3,
        target = [10.0, 12.0, 14.0],
        channels = [1.0 2.0; 3.0 4.0; 5.0 6.0],
        channel_names = ["search", "tv"],
        controls = [7.0; 8.0; 9.0][:, :],
        control_names = ["price_index"],
    )
    @test_throws ArgumentError TimeSeriesMMM(model.config, model.sampler_config, bad_data)
end

@testset "build_model" begin
    model = sample_time_series_model()
    spec = build_model(model)

    @test spec isa MMMModelSpec
    @test spec.model_kind == :time_series_mmm
    @test spec.nobs == 3
    @test spec.nchannels == 2
    @test spec.ncontrols == 1
    @test spec.channel_indices == Dict("tv" => 1, "search" => 2)
    @test spec.control_indices == Dict("price_index" => 1)
    @test model.built_model == spec
end

@testset "fit!" begin
    model = sample_time_series_model()
    state = fit!(model)

    @test state isa ModelFitState
    @test state.status == :deferred
    @test state.backend == :unimplemented
    @test state.artifact isa MMMModelSpec
    @test occursin("Sampling backend is not implemented yet", state.message)
    @test model.fit_state == state
end

@testset "predict" begin
    model = sample_time_series_model()
    error = try
        predict(model)
        nothing
    catch err
        err
    end
    @test error isa ErrorException
    @test occursin("predict is not implemented yet for TimeSeriesMMM", sprint(showerror, error))
end
