using Dates
using Epsilon
using Statistics
using Test

function _time_varying_media_test_config(; time_varying_media = nothing, saturation = Dict{String, Any}())
    return ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        saturation = saturation,
        time_varying_media = time_varying_media,
    )
end

function _time_varying_media_test_data(; dates = Date[Date(2024, 1, 1), Date(2024, 1, 8), Date(2024, 1, 15)])
    return MMMData(
        dates = dates,
        target = [10.0, 11.0, 12.0],
        channels = reshape([1.0, 2.0, 3.0], :, 1),
        channel_names = ["tv"],
    )
end

@testset "time-varying media configuration and private state" begin
    eta_prior = EpsilonPrior("Exponential"; lam = 1.5)
    lengthscale_prior = EpsilonPrior("LogNormal"; mu = 0.0, sigma = 0.4)
    time_varying_media = TimeVaryingMediaConfig(
        m = 4,
        L = 8.0,
        time_resolution = 7,
        covariance = :matern32,
        eta_prior = eta_prior,
        lengthscale_prior = lengthscale_prior,
    )

    @test time_varying_media == TimeVaryingMediaConfig(
        m = 4,
        L = 8.0,
        time_resolution = 7,
        covariance = :matern32,
        eta_prior = EpsilonPrior("Exponential"; lam = 1.5),
        lengthscale_prior = EpsilonPrior("LogNormal"; mu = 0.0, sigma = 0.4),
    )

    config = _time_varying_media_test_config(; time_varying_media)
    model = TimeSeriesMMM(config, SamplerConfig(draws = 1, tune = 0, chains = 1, cores = 1), _time_varying_media_test_data())
    spec = build_model(model)
    state = spec.priors["_hsgp_media_spec_state"]

    @test config.extras["time_varying_media"] === time_varying_media
    @test state.training.training_origin == Date(2024, 1, 1)
    @test state.training.training_indices == (0, 1, 2)
    @test state.training.time_resolution == 7
    @test state.training.drop_first === false
    @test state.training.demeaned_basis === false
    @test state.config.eta_prior isa Epsilon._HSGPMediaPriorSnapshot
    @test state.config.lengthscale_prior isa Epsilon._HSGPMediaPriorSnapshot
    @test !(state.config.eta_prior isa EpsilonPrior)
    @test state.config.eta_prior.parameters isa Tuple

    eta_prior.parameters[:lam] = 99.0
    lengthscale_prior.parameters[:sigma] = 99.0
    @test state.config.eta_prior.parameters == ((:lam, 1.5),)
    @test state.config.lengthscale_prior.parameters == ((:mu, 0.0), (:sigma, 0.4))
    @test mean(Epsilon._instantiate_hsgp_media_prior(state.config.eta_prior)) ≈ 1 / 1.5
    @test mean(Epsilon._instantiate_hsgp_media_prior(state.config.lengthscale_prior)) ≈ exp(0.08)
end

@testset "time-varying media validation and unsupported runtime paths" begin
    eta_prior = EpsilonPrior("Gamma"; alpha = 2.0, beta = 1.0)
    lengthscale_prior = EpsilonPrior("HalfNormal"; sigma = 3.0)
    overflowing_bigfloat = BigFloat(floatmax(Float64)) * BigFloat(2)
    overflowing_integer = big(typemax(Int)) * 2
    config = TimeVaryingMediaConfig(
        m = 3,
        L = 6.0,
        time_resolution = 7,
        covariance = :expquad,
        eta_prior = eta_prior,
        lengthscale_prior = lengthscale_prior,
    )

    @test_throws ArgumentError TimeVaryingMediaConfig(
        m = 0,
        L = 6.0,
        time_resolution = 7,
        eta_prior = eta_prior,
        lengthscale_prior = lengthscale_prior,
    )
    @test_throws ArgumentError TimeVaryingMediaConfig(
        m = 3,
        L = Inf,
        time_resolution = 7,
        eta_prior = eta_prior,
        lengthscale_prior = lengthscale_prior,
    )
    @test_throws ArgumentError TimeVaryingMediaConfig(
        m = 3,
        L = overflowing_bigfloat,
        time_resolution = 7,
        eta_prior = eta_prior,
        lengthscale_prior = lengthscale_prior,
    )
    @test_throws ArgumentError TimeVaryingMediaConfig(
        m = overflowing_bigfloat,
        L = 6.0,
        time_resolution = 7,
        eta_prior = eta_prior,
        lengthscale_prior = lengthscale_prior,
    )
    @test_throws ArgumentError TimeVaryingMediaConfig(
        m = 3,
        L = 6.0,
        time_resolution = overflowing_bigfloat,
        eta_prior = eta_prior,
        lengthscale_prior = lengthscale_prior,
    )
    @test_throws ArgumentError TimeVaryingMediaConfig(
        m = overflowing_integer,
        L = 6.0,
        time_resolution = 7,
        eta_prior = eta_prior,
        lengthscale_prior = lengthscale_prior,
    )
    @test_throws ArgumentError TimeVaryingMediaConfig(
        m = 3,
        L = 6.0,
        time_resolution = overflowing_integer,
        eta_prior = eta_prior,
        lengthscale_prior = lengthscale_prior,
    )
    @test_throws ArgumentError TimeVaryingMediaConfig(
        m = 3.0,
        L = 6.0,
        time_resolution = 7,
        eta_prior = eta_prior,
        lengthscale_prior = lengthscale_prior,
    )
    @test_throws ArgumentError TimeVaryingMediaConfig(
        m = 3,
        L = 6.0,
        time_resolution = 7.0,
        eta_prior = eta_prior,
        lengthscale_prior = lengthscale_prior,
    )
    @test_throws ArgumentError TimeVaryingMediaConfig(
        m = 3,
        L = 6.0,
        time_resolution = 7,
        eta_prior = EpsilonPrior("Exponential"; lam = overflowing_bigfloat),
        lengthscale_prior = lengthscale_prior,
    )
    @test_throws ArgumentError TimeVaryingMediaConfig(
        m = 3,
        L = 6.0,
        time_resolution = 0,
        eta_prior = eta_prior,
        lengthscale_prior = lengthscale_prior,
    )
    @test_throws ArgumentError TimeVaryingMediaConfig(
        m = 3,
        L = 6.0,
        time_resolution = 7,
        covariance = :periodic,
        eta_prior = eta_prior,
        lengthscale_prior = lengthscale_prior,
    )
    @test_throws ArgumentError TimeVaryingMediaConfig(
        m = 3,
        L = 6.0,
        time_resolution = 7,
        eta_prior = EpsilonPrior("Normal"; mu = 0.0, sigma = 1.0),
        lengthscale_prior = lengthscale_prior,
    )
    @test_throws ArgumentError TimeVaryingMediaConfig(
        m = 3,
        L = 6.0,
        time_resolution = 7,
        eta_prior = EpsilonPrior("Exponential"; lam = [1.0]),
        lengthscale_prior = lengthscale_prior,
    )

    model = TimeSeriesMMM(
        _time_varying_media_test_config(; time_varying_media = config),
        SamplerConfig(draws = 1, tune = 0, chains = 1, cores = 1),
        _time_varying_media_test_data(),
    )
    @test_throws ArgumentError fit!(model)
    @test_throws ArgumentError prior_predict(model)
    @test_throws ArgumentError approximate_fit!(model)

    @test_throws ArgumentError TimeSeriesMMM(
        _time_varying_media_test_config(; time_varying_media = config),
        SamplerConfig(draws = 1, tune = 0, chains = 1, cores = 1),
        _time_varying_media_test_data(; dates = [1, 2, 3]),
    )
    @test_throws ArgumentError TimeSeriesMMM(
        _time_varying_media_test_config(; time_varying_media = config),
        SamplerConfig(draws = 1, tune = 0, chains = 1, cores = 1),
        _time_varying_media_test_data(; dates = Date[Date(2024, 1, 1), Date(2024, 1, 8), Date(2024, 1, 16)]),
    )
    @test_throws ArgumentError _time_varying_media_test_config(
        time_varying_media = config,
        saturation = Dict("type" => "michaelis_menten"),
    )
end
