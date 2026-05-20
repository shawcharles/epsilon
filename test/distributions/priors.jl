using Distributions
using Epsilon
using Test

@testset "deserialize_prior" begin
    @testset "distribution syntax" begin
        prior = deserialize_prior(
            Dict(
                "distribution" => "Normal",
                "mu" => 0.0,
                "sigma" => 1.0,
                "dims" => ["channel", "geo"],
            ),
        )

        @test prior ==
              EpsilonPrior(
            "Normal";
            mu = 0.0,
            sigma = 1.0,
            dims = ("channel", "geo"),
        )
    end

    @testset "legacy dist syntax" begin
        prior = deserialize_prior(
            Dict(
                "dist" => "Normal",
                "kwargs" => Dict(
                    "mu" => Dict(
                        "dist" => "HalfNormal",
                        "kwargs" => Dict("sigma" => 2.0),
                    ),
                    "sigma" => 1.0,
                ),
                "dims" => "channel",
                "centered" => false,
            ),
        )

        @test prior ==
              EpsilonPrior(
            "Normal";
            mu = EpsilonPrior("HalfNormal"; sigma = 2.0),
            sigma = 1.0,
            dims = ("channel",),
            centered = false,
        )
    end

    @testset "invalid mappings" begin
        @test_throws ArgumentError deserialize_prior(Dict("value" => 1))
        @test_throws ArgumentError deserialize_prior(
            Dict("dist" => "Normal", "distribution" => "Normal"),
        )
        @test_throws ArgumentError deserialize_prior(Dict("distribution" => "Unknown"))
    end
end

@testset "deserialize_model_config" begin
    config = Dict(
        "beta" => Dict("distribution" => "Normal", "mu" => 0.0, "sigma" => 1.0),
        "alpha" => Dict(
            "dist" => "Gamma",
            "kwargs" => Dict(
                "alpha" => 3.0,
                "beta" => Dict("distribution" => "HalfNormal", "sigma" => 1.5),
            ),
            "dims" => ["channel"],
        ),
        "dropout_covariate_cols" => ["channel", "tier"],
        "other_config" => Dict("key" => "value"),
        "scalar" => 4,
    )

    parsed = deserialize_model_config(config; non_distributions = ["other_config"])

    @test parsed["beta"] == EpsilonPrior("Normal"; mu = 0.0, sigma = 1.0)
    @test parsed["alpha"] ==
          EpsilonPrior(
        "Gamma";
        alpha = 3.0,
        beta = EpsilonPrior("HalfNormal"; sigma = 1.5),
        dims = ("channel",),
    )
    @test parsed["dropout_covariate_cols"] == ["channel", "tier"]
    @test parsed["other_config"] == Dict("key" => "value")
    @test parsed["scalar"] == 4
end

@testset "deserialize_model_config errors" begin
    config = Dict(
        "good" => Dict("distribution" => "Normal", "mu" => 0.0, "sigma" => 1.0),
        "bad_name" => Dict("distribution" => "Nope", "mu" => 0.0, "sigma" => 1.0),
        "bad_shape" => Dict("dist" => 4),
    )

    @test_throws ModelConfigError deserialize_model_config(config)
end

@testset "instantiate_distribution" begin
    normal = instantiate_distribution(EpsilonPrior("Normal"; mu = 2.0, sigma = 3.0))
    @test normal isa Normal
    @test mean(normal) == 2.0
    @test std(normal) == 3.0

    halfnormal = instantiate_distribution(EpsilonPrior("HalfNormal"; sigma = 2.0))
    @test halfnormal isa Truncated

    beta_dist = instantiate_distribution(EpsilonPrior("Beta"; alpha = 2.0, beta = 5.0))
    @test beta_dist isa Beta

    gamma_prior = EpsilonPrior("Gamma"; alpha = 3.0, beta = 2.0)
    gamma_dist = instantiate_distribution(gamma_prior)
    @test gamma_dist isa Gamma
    @test isapprox(mean(gamma_dist), 1.5; atol = 1e-12)

    exponential = instantiate_distribution(EpsilonPrior("Exponential"; lam = 4.0))
    @test exponential isa Exponential
    @test isapprox(mean(exponential), 0.25; atol = 1e-12)

    uniform = instantiate_distribution(EpsilonPrior("Uniform"; lower = -1.0, upper = 3.0))
    @test uniform isa Uniform

    cauchy = instantiate_distribution(EpsilonPrior("Cauchy"; mu = 0.0, beta = 2.0))
    @test cauchy isa Cauchy

    halfcauchy = instantiate_distribution(EpsilonPrior("HalfCauchy"; beta = 3.0))
    @test halfcauchy isa Truncated

    student_t = instantiate_distribution(EpsilonPrior("StudentT"; nu = 7.0, mu = 1.0, sigma = 2.0))
    @test isapprox(mean(student_t), 1.0; atol = 1e-12)
    @test isapprox(std(student_t), 2.0 * std(TDist(7.0)); atol = 1e-12)

    lognormal = instantiate_distribution(EpsilonPrior("LogNormal"; mu = 0.5, sigma = 0.25))
    @test lognormal isa LogNormal

    weibull = instantiate_distribution(EpsilonPrior("Weibull"; alpha = 2.0, beta = 4.0))
    @test weibull isa Weibull

    truncated = instantiate_distribution(
        EpsilonPrior("TruncatedNormal"; mu = 1.0, sigma = 2.0, lower = 0.0, upper = 5.0),
    )
    @test rand(truncated) isa Float64

    @test_throws ArgumentError instantiate_distribution(
        EpsilonPrior("Normal"; mu = EpsilonPrior("HalfNormal"; sigma = 1.0), sigma = 1.0),
    )
end
