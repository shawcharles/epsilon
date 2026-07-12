using Dates
using Distributions
using Epsilon
using Statistics
using Test

const _FORWARDDIFF_AVAILABLE = !isnothing(Base.find_package("ForwardDiff"))
_FORWARDDIFF_AVAILABLE && @eval using ForwardDiff

include(joinpath(@__DIR__, "..", "fixtures", "abacus", "hsgp_time_varying_media_cases.jl"))

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
    observation_count = length(dates)
    return MMMData(
        dates = dates,
        target = collect(10.0:(9.0 + observation_count)),
        channels = reshape(collect(1.0:observation_count), :, 1),
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

@testset "time-varying media Abacus placement fixture" begin
    case = ABACUS_HSGP_TIME_VARYING_MEDIA_FIXTURES.case

    @test size(case.baseline_channel_contribution) == (4, 2)
    @test size(case.final_channel_contribution) == size(case.baseline_channel_contribution)
    @test length(case.multiplier) == size(case.baseline_channel_contribution, 1)
    @test case.final_channel_contribution == case.baseline_channel_contribution .* case.multiplier
end

@testset "time-varying media pure runtime multiplier" begin
    config = TimeVaryingMediaConfig(
        m = 4,
        L = 8.0,
        time_resolution = 7,
        covariance = :matern52,
        eta_prior = EpsilonPrior("Exponential"; lam = 1.5),
        lengthscale_prior = EpsilonPrior("LogNormal"; mu = 0.0, sigma = 0.4),
    )
    model = TimeSeriesMMM(
        _time_varying_media_test_config(; time_varying_media = config),
        SamplerConfig(draws = 1, tune = 0, chains = 1, cores = 1),
        _time_varying_media_test_data(; dates = Date[Date(2024, 1, 1), Date(2024, 1, 8), Date(2024, 1, 22), Date(2024, 2, 5)]),
    )
    state = build_model(model).priors["_hsgp_media_spec_state"]
    eta = 1.1
    lengthscale = 2.2
    z = Float64[-0.4, 0.2, 0.1, -0.3]
    current_indices = Int[-2, 1, 4, 7]
    sqrt_psd = Epsilon._hsgp_sqrt_psd(
        state.config.m,
        state.config.L;
        covariance = state.config.covariance,
        eta,
        lengthscale,
        drop_first = state.training.drop_first,
    )
    oracle_state = Epsilon._fit_hsgp_positive_multiplier_state(
        collect(state.training.training_indices),
        sqrt_psd,
        z;
        m = state.training.m,
        L = state.training.L,
        drop_first = state.training.drop_first,
        demeaned_basis = state.training.demeaned_basis,
    )

    training_multiplier = Epsilon._hsgp_media_multiplier(
        state,
        collect(state.training.training_indices),
        eta,
        lengthscale,
        z,
    )
    replay_multiplier = Epsilon._hsgp_media_multiplier(
        state,
        current_indices,
        eta,
        lengthscale,
        z,
    )

    @test mean(training_multiplier) ≈ 1.0 atol = 1.0e-12 rtol = 1.0e-12
    @test replay_multiplier ≈ Epsilon._hsgp_replay_positive_multiplier(current_indices, oracle_state) atol = 1.0e-12 rtol = 1.0e-12
    @test all(isfinite, replay_multiplier)
    @test all(>(0), replay_multiplier)

    @test_throws ArgumentError Epsilon._hsgp_media_multiplier(state, Float64[0.0], eta, lengthscale, z)
    @test_throws ArgumentError Epsilon._hsgp_media_multiplier(state, Int[], eta, lengthscale, z)
    @test_throws ArgumentError Epsilon._hsgp_media_multiplier(state, Int[0], eta, lengthscale, z[1:3])
    @test_throws ArgumentError Epsilon._hsgp_media_multiplier(state, Int[0], eta, lengthscale, Float64[NaN, 0.0, 0.0, 0.0])
    @test_throws ArgumentError Epsilon._hsgp_media_multiplier(state, Int[0], 0.0, lengthscale, z)
    @test_throws ArgumentError Epsilon._hsgp_media_multiplier(state, Int[0], eta, Inf, z)
end

@testset "time-varying media Epsilon-native likelihood and priors" begin
    observed = Float64[1.2, 0.7, 1.8]
    mean_values = Float64[1.0, 0.8, 1.5]
    sigma = 0.3
    likelihood = Normal.(mean_values, sigma)
    manual_log_likelihood = sum(
        -log(sigma) - log(2 * π) / 2 .- (observed .- mean_values) .^ 2 ./ (2 * sigma^2),
    )
    @test sum(logpdf.(likelihood, observed)) ≈ manual_log_likelihood atol = 1.0e-12 rtol = 1.0e-12

    eta_snapshot = Epsilon._HSGPMediaPriorSnapshot(:Exponential, ((:lam, 1.5),))
    lengthscale_snapshot = Epsilon._HSGPMediaPriorSnapshot(:LogNormal, ((:mu, 0.0), (:sigma, 0.4)))
    eta = 1.1
    lengthscale = 2.2
    @test logpdf(Epsilon._instantiate_hsgp_media_prior(eta_snapshot), eta) ≈ logpdf(Exponential(1 / 1.5), eta)
    @test logpdf(Epsilon._instantiate_hsgp_media_prior(lengthscale_snapshot), lengthscale) ≈ logpdf(LogNormal(0.0, 0.4), lengthscale)
end

@testset "time-varying media pure runtime autodiff" begin
    if _FORWARDDIFF_AVAILABLE
        config = TimeVaryingMediaConfig(
            m = 2,
            L = 6.0,
            time_resolution = 7,
            covariance = :expquad,
            eta_prior = EpsilonPrior("Exponential"; lam = 1.0),
            lengthscale_prior = EpsilonPrior("HalfNormal"; sigma = 2.0),
        )
        model = TimeSeriesMMM(
            _time_varying_media_test_config(; time_varying_media = config),
            SamplerConfig(draws = 1, tune = 0, chains = 1, cores = 1),
            _time_varying_media_test_data(),
        )
        state = build_model(model).priors["_hsgp_media_spec_state"]
        gradient = ForwardDiff.gradient(
            parameters -> sum(
                Epsilon._hsgp_media_multiplier(
                    state,
                    Int[0, 1, 2],
                    parameters[1],
                    parameters[2],
                    Float64[-0.4, 0.2],
                ),
            ),
            Float64[1.1, 2.2],
        )
        @test all(isfinite, gradient)
    else
        @test_skip "ForwardDiff is available in the Pkg test target but not direct-project test runs"
    end
end
