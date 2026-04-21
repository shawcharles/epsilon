using Distributions
using Epsilon
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

    reference = 1.5 + 2.0 * TDist(7.0)
    for x in (-2.0, 0.0, 1.5, 4.0)
        @test isapprox(pdf(dist, x), pdf(reference, x); atol = 1e-12, rtol = 1e-10)
    end

    draws = [rand(dist) for _ in 1:256]
    @test all(isfinite, draws)
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
