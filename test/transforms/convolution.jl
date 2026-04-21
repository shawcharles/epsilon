include(joinpath(@__DIR__, "..", "fixtures", "abacus", "batched_convolution_cases.jl"))

using Epsilon
using Test

@testset "batched_convolution" begin
    @testset "abacus parity" begin
        for case in ABACUS_BATCHED_CONVOLUTION_CASES
            actual = batched_convolution(case.x, case.w, case.axis, case.mode)
            @test size(actual) == size(case.expected)
            @test actual ≈ case.expected atol = 1e-12 rtol = 1e-12
        end
    end

    @testset "invalid mode" begin
        @test_throws ArgumentError batched_convolution([1.0, 2.0], [1.0, 0.5], 1, "InvalidMode")
    end
end
