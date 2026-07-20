using Dates
using Distributions
using Epsilon
import MCMCChains
using Random
using Statistics
using Test
import Turing

const _FORWARDDIFF_AVAILABLE = !isnothing(Base.find_package("ForwardDiff"))
_FORWARDDIFF_AVAILABLE && @eval using ForwardDiff

include(joinpath(@__DIR__, "..", "fixtures", "golden", "hsgp_time_varying_media_cases.jl"))

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

    hsgp_spec = build_model(model)
    hsgp_spec.saturation["type"] = "michaelis_menten"
    @test_throws ArgumentError Epsilon._turing_runtime(hsgp_spec, model.data)

    model.config.saturation["type"] = "michaelis_menten"
    @test_throws ArgumentError build_model(model)
    @test_throws ArgumentError fit!(model)

    lift_test_data = LiftTestCalibrationRows(
        channel = ["tv"],
        x = [1.0],
        delta_x = [0.5],
        delta_y = [0.3],
        sigma = [0.1],
    )
    calibrated_model = TimeSeriesMMM(
        _time_varying_media_test_config(; saturation = Dict("type" => "logistic")),
        SamplerConfig(draws = 1, tune = 0, chains = 1, cores = 1),
        _time_varying_media_test_data();
        calibration_steps = [CalibrationStepConfig(method = "add_lift_test_measurements")],
        lift_test_data,
    )
    calibrated_model.config.extras["time_varying_media"] = config
    @test_throws ArgumentError fit!(calibrated_model)
end

@testset "time-varying media Turing placement and retained-grid replay" begin
    time_varying_media = TimeVaryingMediaConfig(
        m = 2,
        L = 6.0,
        time_resolution = 7,
        covariance = :expquad,
        eta_prior = EpsilonPrior("Exponential"; lam = 1.5),
        lengthscale_prior = EpsilonPrior("LogNormal"; mu = 0.0, sigma = 0.4),
    )
    data = _time_varying_media_test_data()
    model = TimeSeriesMMM(
        _time_varying_media_test_config(; time_varying_media),
        SamplerConfig(draws = 2, tune = 0, chains = 1, cores = 1, random_seed = 12, progressbar = false),
        data,
    )
    spec = build_model(model)
    runtime, controls = Epsilon._turing_runtime(spec, data)
    state = spec.priors["_hsgp_media_spec_state"]
    scaled_target = data.target ./ spec.target_scale
    scaled_channels = Epsilon._scale_channels(data.channels, spec.channel_scale)
    turing_model = Epsilon._time_series_mmm_model(
        scaled_target,
        scaled_channels,
        controls,
        nothing,
        nothing,
        runtime,
    )
    fixed_parameters = (
        intercept = 0.2,
        sigma = 0.5,
        beta_media = [0.3],
        hsgp_media_eta = 1.1,
        hsgp_media_lengthscale = 2.2,
        hsgp_media_z = [-0.4, 0.2],
    )
    conditioned = Turing.DynamicPPL.condition(turing_model, fixed_parameters)
    returned, varinfo = Turing.DynamicPPL.evaluate!!(
        conditioned,
        Turing.DynamicPPL.VarInfo(conditioned),
    )

    multiplier = Epsilon._hsgp_media_multiplier(
        state,
        runtime.hsgp_media_current_indices,
        fixed_parameters.hsgp_media_eta,
        fixed_parameters.hsgp_media_lengthscale,
        fixed_parameters.hsgp_media_z,
    )
    baseline_channel = scaled_channels .* reshape(fixed_parameters.beta_media, 1, :)
    expected_media_effect = vec(
        sum(baseline_channel .* reshape(multiplier, :, 1); dims = 2),
    )
    @test returned.media_effect ≈ expected_media_effect atol = 1.0e-12 rtol = 1.0e-12

    expected_mu = fixed_parameters.intercept .+ expected_media_effect
    expected_logjoint =
        logpdf(runtime.intercept_prior, fixed_parameters.intercept) +
        logpdf(runtime.sigma_prior, fixed_parameters.sigma) +
        logpdf(runtime.media_beta_prior, only(fixed_parameters.beta_media)) +
        logpdf(runtime.hsgp_media_eta_prior, fixed_parameters.hsgp_media_eta) +
        logpdf(runtime.hsgp_media_lengthscale_prior, fixed_parameters.hsgp_media_lengthscale) +
        sum(logpdf.(Normal(), fixed_parameters.hsgp_media_z)) +
        sum(logpdf.(Normal.(expected_mu, fixed_parameters.sigma), scaled_target))
    @test Turing.DynamicPPL.getlogjoint(varinfo) ≈ expected_logjoint atol = 1.0e-10 rtol = 1.0e-10

    new_data = _time_varying_media_test_data(
        dates = Date[Date(2024, 1, 22), Date(2024, 1, 29)],
    )
    new_runtime, new_controls = Epsilon._turing_runtime(spec, new_data)
    @test new_runtime.hsgp_media_current_indices == Int[3, 4]
    new_model = Epsilon._time_series_mmm_model(
        Vector{Union{Missing, Float64}}(missing, nobs(new_data)),
        Epsilon._scale_channels(new_data.channels, spec.channel_scale),
        new_controls,
        nothing,
        nothing,
        new_runtime,
    )
    new_conditioned = Turing.DynamicPPL.condition(new_model, fixed_parameters)
    new_returned, _ = Turing.DynamicPPL.evaluate!!(
        new_conditioned,
        Turing.DynamicPPL.VarInfo(new_conditioned),
    )
    expected_new_multiplier = Epsilon._hsgp_media_multiplier(
        state,
        Int[3, 4],
        fixed_parameters.hsgp_media_eta,
        fixed_parameters.hsgp_media_lengthscale,
        fixed_parameters.hsgp_media_z,
    )
    expected_new_media_effect = vec(
        sum(
            Epsilon._scale_channels(new_data.channels, spec.channel_scale) .* reshape(fixed_parameters.beta_media, 1, :) .* reshape(expected_new_multiplier, :, 1);
            dims = 2,
        ),
    )
    @test new_returned.media_effect ≈ expected_new_media_effect atol = 1.0e-12 rtol = 1.0e-12
    @test new_returned.media_effect != returned.media_effect[1:length(new_returned.media_effect)]

    function fixed_hsgp_chain(parameters)
        values = Turing.DynamicPPL.VarNamedTuple(
            (
                Turing.DynamicPPL.@varname(intercept) => parameters.intercept,
                Turing.DynamicPPL.@varname(sigma) => parameters.sigma,
                Turing.DynamicPPL.@varname(beta_media) => parameters.beta_media,
                Turing.DynamicPPL.@varname(hsgp_media_eta) => parameters.hsgp_media_eta,
                Turing.DynamicPPL.@varname(hsgp_media_lengthscale) => parameters.hsgp_media_lengthscale,
                Turing.DynamicPPL.@varname(hsgp_media_z) => parameters.hsgp_media_z,
            ),
        )
        return Turing.AbstractMCMC.from_samples(MCMCChains.Chains, reshape([values], 1, 1))
    end

    training_predictive_model = Epsilon._time_series_mmm_model(
        Vector{Union{Missing, Float64}}(missing, nobs(data)),
        scaled_channels,
        controls,
        nothing,
        nothing,
        runtime,
    )
    changed_eta_parameters = merge(
        fixed_parameters,
        (; hsgp_media_eta = 0.6),
    )
    changed_lengthscale_parameters = merge(
        fixed_parameters,
        (; hsgp_media_lengthscale = 1.1),
    )
    changed_z_parameters = merge(
        fixed_parameters,
        (; hsgp_media_z = [0.6, -0.1]),
    )
    fixed_chain = fixed_hsgp_chain(fixed_parameters)
    changed_eta_chain = fixed_hsgp_chain(changed_eta_parameters)
    changed_lengthscale_chain = fixed_hsgp_chain(changed_lengthscale_parameters)
    changed_z_chain = fixed_hsgp_chain(changed_z_parameters)

    # With a fixed RNG stream, any target difference must come from the HSGP
    # draw consumed by Turing.predict rather than posterior-predictive noise.
    Random.seed!(91)
    training_predictive = Turing.predict(training_predictive_model, fixed_chain)
    Random.seed!(91)
    changed_eta_training_predictive = Turing.predict(training_predictive_model, changed_eta_chain)
    Random.seed!(91)
    changed_lengthscale_training_predictive = Turing.predict(
        training_predictive_model,
        changed_lengthscale_chain,
    )
    Random.seed!(91)
    changed_z_training_predictive = Turing.predict(training_predictive_model, changed_z_chain)
    @test size(Array(training_predictive), 2) == nobs(data)
    @test Array(training_predictive) != Array(changed_eta_training_predictive)
    @test Array(training_predictive) != Array(changed_lengthscale_training_predictive)
    @test Array(training_predictive) != Array(changed_z_training_predictive)

    Random.seed!(91)
    new_predictive = Turing.predict(new_model, fixed_chain)
    Random.seed!(91)
    changed_eta_new_predictive = Turing.predict(new_model, changed_eta_chain)
    Random.seed!(91)
    changed_lengthscale_new_predictive = Turing.predict(new_model, changed_lengthscale_chain)
    Random.seed!(91)
    changed_z_new_predictive = Turing.predict(new_model, changed_z_chain)
    @test size(Array(new_predictive), 2) == nobs(new_data)
    @test Array(new_predictive) != Array(changed_eta_new_predictive)
    @test Array(new_predictive) != Array(changed_lengthscale_new_predictive)
    @test Array(new_predictive) != Array(changed_z_new_predictive)
end

@testset "time-varying media NUTS wiring" begin
    time_varying_media = TimeVaryingMediaConfig(
        m = 2,
        L = 6.0,
        time_resolution = 7,
        eta_prior = EpsilonPrior("Exponential"; lam = 1.0),
        lengthscale_prior = EpsilonPrior("HalfNormal"; sigma = 2.0),
    )
    model = TimeSeriesMMM(
        _time_varying_media_test_config(; time_varying_media),
        SamplerConfig(draws = 2, tune = 1, chains = 1, cores = 1, random_seed = 24, progressbar = false, compute_convergence_checks = false),
        _time_varying_media_test_data(),
    )

    @test !isnothing(prior_predict(model))
    fit!(model)

    chain_parameters = String.(MCMCChains.names(model.fit_state.artifact.chain, :parameters))
    @test "hsgp_media_eta" in chain_parameters
    @test "hsgp_media_lengthscale" in chain_parameters
    @test all("hsgp_media_z[$index]" in chain_parameters for index in 1:2)
    @test !isnothing(prior_predict(model))
    @test !isnothing(predict(model))
end

@testset "time-varying media golden placement fixture" begin
    case = GOLDEN_HSGP_TIME_VARYING_MEDIA_FIXTURES.case

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
