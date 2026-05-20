using Distributions
using Epsilon
using Random
using Statistics
using Test

@testset "Scaled distribution" begin
    prior = deserialize_prior(
        Dict(
            "distribution" => "Scaled",
            "base" => Dict("distribution" => "HalfNormal", "sigma" => 1.0),
            "scale" => 2.0,
        ),
    )
    @test prior == EpsilonPrior("Scaled"; base = EpsilonPrior("HalfNormal"; sigma = 1.0), scale = 2.0)

    dist = instantiate_distribution(prior)
    @test dist isa Scaled
    @test isapprox(logpdf(dist, 1.5), logpdf(instantiate_distribution(EpsilonPrior("HalfNormal"; sigma = 1.0)), 0.75) - log(2.0); atol = 1e-12)

    samples = [rand(dist) for _ in 1:128]
    @test all(x -> x >= 0.0, samples)

    bounded = instantiate_distribution(
        EpsilonPrior("Scaled"; base = EpsilonPrior("Uniform"; lower = 1.0, upper = 3.0), scale = 2.0),
    )
    @test minimum(bounded) == 2.0
    @test maximum(bounded) == 6.0
    @test mean(bounded) == 4.0
    @test var(bounded) ≈ 4 / 3 atol = 1e-12 rtol = 1e-12

    nested_special = instantiate_distribution(
        EpsilonPrior("Scaled"; base = LogNormalPrior(; mean = 4.0, std = 3.0), scale = 2.0),
    )
    @test nested_special isa Scaled

    rng = MersenneTwister(17)
    scalar_draw = rand(rng, dist)
    Random.seed!(17)
    default_vector_draws = rand(dist, 5)
    Random.seed!(17)
    default_matrix_draws = rand(dist, 2, 3)
    vector_draws = rand(MersenneTwister(17), dist, 5)
    matrix_draws = rand(MersenneTwister(17), dist, (2, 3))
    vararg_matrix_draws = rand(MersenneTwister(17), dist, 2, 3)

    @test scalar_draw >= 0.0
    @test length(default_vector_draws) == 5
    @test size(default_matrix_draws) == (2, 3)
    @test length(vector_draws) == 5
    @test size(matrix_draws) == (2, 3)
    @test size(vararg_matrix_draws) == (2, 3)
    @test vector_draws == rand(MersenneTwister(17), dist, 5)
    @test matrix_draws == vararg_matrix_draws

    @test_throws ArgumentError instantiate_distribution(
        EpsilonPrior("Scaled"; base = EpsilonPrior("HalfNormal"; sigma = 1.0), scale = EpsilonPrior("HalfNormal"; sigma = 1.0)),
    )
end

@testset "SkewStudentT distribution" begin
    prior = deserialize_prior(
        Dict(
            "distribution" => "SkewStudentT",
            "nu" => 7.0,
            "mu" => 1.5,
            "sigma" => 2.0,
            "alpha" => 0.0,
        ),
    )
    dist = instantiate_distribution(prior)
    @test dist isa SkewStudentT

    mixed = instantiate_distribution(
        EpsilonPrior("SkewStudentT"; nu = 7, mu = 1.5, sigma = 2.0, alpha = 0.0),
    )
    @test mixed isa SkewStudentT

    reference = 1.5 + 2.0 * TDist(7.0)
    for x in (-2.0, 0.0, 1.5, 4.0)
        @test isapprox(pdf(dist, x), pdf(reference, x); atol = 1e-12, rtol = 1e-10)
        @test isapprox(logpdf(dist, x), logpdf(reference, x); atol = 1e-12, rtol = 1e-10)
    end

    draws = [rand(dist) for _ in 1:256]
    @test all(isfinite, draws)

    scalar_draw = rand(MersenneTwister(23), dist)
    Random.seed!(23)
    default_vector_draws = rand(dist, 5)
    Random.seed!(23)
    default_matrix_draws = rand(dist, 2, 3)
    vector_draws = rand(MersenneTwister(23), dist, 5)
    matrix_draws = rand(MersenneTwister(23), dist, (2, 3))
    vararg_matrix_draws = rand(MersenneTwister(23), dist, 2, 3)
    @test isfinite(scalar_draw)
    @test length(default_vector_draws) == 5
    @test size(default_matrix_draws) == (2, 3)
    @test length(vector_draws) == 5
    @test size(matrix_draws) == (2, 3)
    @test size(vararg_matrix_draws) == (2, 3)
    @test vector_draws == rand(MersenneTwister(23), dist, 5)
    @test matrix_draws == vararg_matrix_draws

    @test_throws ArgumentError instantiate_distribution(
        EpsilonPrior("SkewStudentT"; nu = EpsilonPrior("HalfNormal"; sigma = 1.0)),
    )
end

@testset "LogNormalPrior" begin
    prior = LogNormalPrior(; mu = 4.0, sigma = 3.0, dims = ("channel",))
    @test prior == LogNormalPrior(; mean = 4.0, std = 3.0, dims = ("channel",))

    dist = instantiate_distribution(prior)
    @test dist isa LogNormal
    @test isapprox(mean(dist), 4.0; atol = 1e-10)
    @test isapprox(std(dist), 3.0; atol = 1e-10)

    payload = Epsilon.to_dict(prior)
    @test deserialize_prior(payload) == prior
end

@testset "LaplacePrior" begin
    prior = LaplacePrior(; mu = 1.5, b = 2.5, dims = ("geo",), centered = false)
    dist = instantiate_distribution(prior)
    @test dist isa Laplace
    @test mean(dist) == 1.5
    @test scale(dist) == 2.5

    payload = Epsilon.to_dict(prior)
    @test deserialize_prior(payload) == prior
end

@testset "special prior validation" begin
    @test_throws ArgumentError LogNormalPrior(; alpha = 1.0, beta = 2.0)
    @test_throws ArgumentError LogNormalPrior(; mean = 1.0, mu = 1.0, std = 2.0)
    @test_throws ArgumentError LogNormalPrior(; mean = 1.0, std = 2.0, sigma = 2.0)
    @test_throws ArgumentError LaplacePrior(; alpha = 1.0, beta = 2.0)
    @test_throws ArgumentError deserialize_prior(Dict("special_prior" => "Nope"))
end

@testset "MaskedPrior" begin
    base = EpsilonPrior("Normal"; mu = 0.0, sigma = 1.0, dims = ("country", "channel"))
    masked = MaskedPrior(
        base,
        [true false; false true];
        mask_dims = ("country", "channel"),
        active_dim = "active_country_channel",
    )

    @test active_count(masked) == 2
    @test expand_masked_values(masked, [10.0, 20.0]) == [10.0 0.0; 0.0 20.0]

    payload = Epsilon.to_dict(masked)
    @test deserialize_prior(payload) == masked

    @test_throws ArgumentError MaskedPrior(
        base,
        [true false; false true];
        mask_dims = ("channel", "country"),
    )
    @test_throws ArgumentError expand_masked_values(masked, [1.0])
    @test_throws ArgumentError instantiate_distribution(masked)
end

@testset "masked prior detection stays narrow" begin
    config = Dict(
        "distribution" => "Normal",
        "mu" => 0.0,
        "sigma" => 1.0,
        "prior" => "not a masked prior payload",
        "mask" => [true, false],
    )
    parsed = deserialize_prior(config)
    @test parsed == EpsilonPrior("Normal"; mu = 0.0, sigma = 1.0, prior = "not a masked prior payload", mask = [true, false])
end

@testset "model config with special priors" begin
    config = Dict(
        "lam" => Dict(
            "special_prior" => "LogNormalPrior",
            "kwargs" => Dict("mu" => 1.0, "sigma" => 2.0),
            "dims" => ["channel"],
        ),
        "masked" => Dict(
            "class" => "MaskedPrior",
            "data" => Dict(
                "prior" => Dict("distribution" => "Normal", "mu" => 0.0, "sigma" => 1.0, "dims" => ["channel"]),
                "mask" => [true, false, true],
                "mask_dims" => ["channel"],
                "active_dim" => "active_channel",
            ),
        ),
    )

    parsed = deserialize_model_config(config)
    @test parsed["lam"] == LogNormalPrior(; mean = 1.0, std = 2.0, dims = ("channel",))
    @test parsed["masked"] ==
          MaskedPrior(
        EpsilonPrior("Normal"; mu = 0.0, sigma = 1.0, dims = ("channel",)),
        [true, false, true];
        mask_dims = ("channel",),
        active_dim = "active_channel",
    )
end
