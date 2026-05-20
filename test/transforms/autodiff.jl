using Epsilon
using ForwardDiff
using ReverseDiff
using Test

@testset "transform autodiff smoke tests" begin
    @testset "batched_convolution gradients over weights" begin
        x = [1.0, 2.0, 3.0, 4.0]
        objective(w) = sum(batched_convolution(x, w, 1, After))
        params = [0.7, 0.2, 0.1]

        forward = ForwardDiff.gradient(objective, params)
        reverse = ReverseDiff.gradient(objective, params)

        @test all(isfinite, forward)
        @test all(isfinite, reverse)
        @test forward ≈ reverse atol = 1.0e-9 rtol = 1.0e-9
    end

    @testset "geometric_adstock gradients over alpha" begin
        x = [1.0, 3.0, 2.0, 4.0]
        objective(theta) = sum(geometric_adstock(x, theta[1], 4; normalize = true))
        params = [0.4]

        forward = ForwardDiff.gradient(objective, params)
        reverse = ReverseDiff.gradient(objective, params)

        @test all(isfinite, forward)
        @test all(isfinite, reverse)
        @test forward ≈ reverse atol = 1.0e-9 rtol = 1.0e-9
    end

    @testset "centered_logistic_saturation gradients over lambda" begin
        x = [0.5, 1.0, 1.5, 2.0]
        objective(theta) = sum(centered_logistic_saturation(x, theta[1]))
        params = [0.8]

        forward = ForwardDiff.gradient(objective, params)
        reverse = ReverseDiff.gradient(objective, params)

        @test all(isfinite, forward)
        @test all(isfinite, reverse)
        @test forward ≈ reverse atol = 1.0e-9 rtol = 1.0e-9
    end
end
