using Dates
using Epsilon
using Statistics
using Test

function _recovery_draws(chain, name::Symbol)
    return vec(Float64.(Array(chain[name])))
end

function _central_interval(draws::AbstractVector{<:Real}; probability = 0.95)
    alpha = (1.0 - probability) / 2.0
    return quantile(draws, alpha), quantile(draws, 1.0 - alpha)
end

@testset "synthetic time-series fit recovers simple media coefficient" begin
    n = 28
    channel = collect(range(0.05, 1.0; length = n))
    true_intercept = 0.25
    true_beta = 1.35
    deterministic_noise = 0.02 .* sin.(1:n)
    target = true_intercept .+ (true_beta .* channel) .+ deterministic_noise

    config = ModelConfig(
        date_column = "date",
        target_column = "revenue",
        target_type = "revenue",
        channel_columns = ["tv"],
        adstock = Dict("type" => "none"),
        saturation = Dict("type" => "none"),
        priors = Dict(
            "intercept" => EpsilonPrior("Normal"; mu = 0.0, sigma = 1.0),
            "beta_media" => EpsilonPrior("HalfNormal"; sigma = 2.0, dims = ("channel",)),
            "sigma" => EpsilonPrior("HalfNormal"; sigma = 0.3),
        ),
    )
    sampler = SamplerConfig(;
        draws = 60,
        tune = 60,
        chains = 1,
        cores = 1,
        target_accept = 0.85,
        random_seed = 123,
        progressbar = false,
        compute_convergence_checks = false,
    )
    data = MMMData(
        dates = Date(2024, 1, 1) .+ Day.(0:(n - 1)),
        target = target,
        channels = reshape(channel, n, 1),
        channel_names = ["tv"],
    )

    state = fit!(TimeSeriesMMM(config, sampler, data))

    @test state.status == :fit
    @test Symbol("beta_media[1]") in names(state.artifact.chain, :parameters)

    target_scale = state.artifact.spec.target_scale
    channel_scale = only(state.artifact.spec.channel_scale)
    scaled_true_intercept = true_intercept / target_scale
    scaled_true_beta = true_beta * channel_scale / target_scale

    intercept_draws = _recovery_draws(state.artifact.chain, :intercept)
    beta_draws = _recovery_draws(state.artifact.chain, Symbol("beta_media[1]"))
    intercept_lower, intercept_upper = _central_interval(intercept_draws)
    beta_lower, beta_upper = _central_interval(beta_draws)

    @test intercept_lower < scaled_true_intercept < intercept_upper
    @test beta_lower < scaled_true_beta < beta_upper
    @test abs(mean(intercept_draws) - scaled_true_intercept) < 0.05
    @test abs(mean(beta_draws) - scaled_true_beta) < 0.08
    @test mean(_recovery_draws(state.artifact.chain, :sigma)) < 0.05
end
