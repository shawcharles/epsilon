using Epsilon
using Test

@testset "HorseshoePrior" begin
    prior = HorseshoePrior(; scale = 2.0, dims = ("channel",))
    @test prior == deserialize_prior(Epsilon.to_dict(prior))

    coeffs = horseshoe_coefficients(prior, [1.0, -2.0], [0.5, 1.5], 0.25)
    @test coeffs ≈ [0.25, -1.5] atol = 1.0e-12 rtol = 1.0e-12

    @test_throws ArgumentError HorseshoePrior(; scale = 0.0)
    @test_throws ArgumentError instantiate_distribution(prior)
end

@testset "FinnishHorseshoePrior" begin
    prior = FinnishHorseshoePrior(; scale = 1.5, slab_scale = 2.5, slab_df = 4.0, dims = ("channel",))
    @test prior == deserialize_prior(Epsilon.to_dict(prior))

    local_scales = [0.5, 4.0]
    lambda_tilde = regularized_local_scales(prior, local_scales, 2.0)
    @test all(lambda_tilde .> 0)
    @test lambda_tilde[1] < local_scales[1]
    @test lambda_tilde[2] < local_scales[2]

    coeffs = finnish_horseshoe_coefficients(prior, [1.0, -1.0], local_scales, 2.0)
    @test coeffs ≈ 1.5 .* [lambda_tilde[1] * 2.0, -lambda_tilde[2] * 2.0] atol = 1.0e-12 rtol = 1.0e-12

    @test_throws ArgumentError FinnishHorseshoePrior(; slab_scale = -1.0)
    @test_throws ArgumentError instantiate_distribution(prior)
end

@testset "R2D2Prior" begin
    prior = R2D2Prior(; mean_R2 = 0.4, concentration = 2.0, scale = 3.0, dims = ("channel",))
    @test prior == deserialize_prior(Epsilon.to_dict(prior))

    variances = r2d2_variance_weights(prior, [1.0, 3.0], 2.0)
    @test variances ≈ [4.5, 13.5] atol = 1.0e-12 rtol = 1.0e-12

    coeffs = r2d2_coefficients(prior, [2.0, -1.0], [1.0, 3.0], 2.0)
    @test coeffs ≈ [2.0 * sqrt(4.5), -sqrt(13.5)] atol = 1.0e-12 rtol = 1.0e-12

    @test_throws ArgumentError R2D2Prior(; mean_R2 = 1.2)
    @test_throws ArgumentError r2d2_variance_weights(prior, [-1.0, 1.0], 2.0)
    @test_throws ArgumentError r2d2_variance_weights(prior, [0.0, 0.0], 2.0)
    @test_throws ArgumentError r2d2_variance_weights(prior, [1.0, 3.0], -2.0)
    @test_throws ArgumentError instantiate_distribution(prior)
end
