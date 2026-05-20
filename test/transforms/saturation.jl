include(joinpath(@__DIR__, "..", "fixtures", "abacus", "logistic_saturation_cases.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "abacus", "michaelis_menten_cases.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "abacus", "tanh_saturation_cases.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "abacus", "hill_function_cases.jl"))

using Epsilon
using Test

@testset "centered_logistic_saturation" begin
    @testset "abacus parity" begin
        for case in ABACUS_LOGISTIC_SATURATION_CASES
            actual = centered_logistic_saturation(case.x, case.lam)
            @test size(actual) == size(case.expected)
            @test actual ≈ case.expected atol = 1.0e-12 rtol = 1.0e-12
        end
    end

    @testset "basic behavior" begin
        x = ones(5)
        expected = fill((1 - exp(-1.0)) / (1 + exp(-1.0)), 5)
        @test centered_logistic_saturation(x, 0.0) == zeros(5)
        @test centered_logistic_saturation(x, 1.0) ≈ expected atol = 1.0e-12 rtol = 1.0e-12
        @test maximum(centered_logistic_saturation(range(0.0, 10.0; length = 25), 100.0)) <= 1.0
        @test minimum(centered_logistic_saturation(range(0.0, 10.0; length = 25), 100.0)) >= 0.0
    end

    @testset "large negative inputs stay finite" begin
        actual = centered_logistic_saturation([-1.0e6, 0.0, 1.0e6], 1.0)
        @test all(isfinite, actual)
        @test actual[1] ≈ -1.0 atol = 1.0e-12 rtol = 1.0e-12
        @test actual[2] == 0.0
        @test actual[3] ≈ 1.0 atol = 1.0e-12 rtol = 1.0e-12
    end

    @testset "parameter validation" begin
        @test_throws ArgumentError centered_logistic_saturation([1.0, 2.0], -0.1)
        @test_throws ArgumentError centered_logistic_saturation([1.0, 2.0], [0.5, -0.2])
    end

    @testset "legacy alias" begin
        x = [0.0, 1.0, 2.0]
        @test logistic_saturation(x, 0.75) == centered_logistic_saturation(x, 0.75)
    end
end

@testset "tanh_saturation" begin
    @testset "abacus parity" begin
        for case in ABACUS_TANH_SATURATION_CASES
            actual = tanh_saturation(case.x, case.b, case.c)
            @test size(actual) == size(case.expected)
            @test actual ≈ case.expected atol = 1.0e-12 rtol = 1.0e-12
        end
    end

    @testset "range and inverse behavior" begin
        x = collect(range(-1.0, 1.0; length = 25))
        b = 1.0
        c = 2.0
        y = tanh_saturation(x, b, c)
        @test maximum(y) <= b
        @test minimum(y) >= -b
        @test (b * c) .* atanh.(y ./ b) ≈ x atol = 1.0e-10 rtol = 1.0e-10
    end

    @testset "parameter validation" begin
        @test_throws ArgumentError tanh_saturation([1.0, 2.0], 0.0, 1.0)
        @test_throws ArgumentError tanh_saturation([1.0, 2.0], 1.0, 0.0)
        @test_throws ArgumentError tanh_saturation([1.0, 2.0], [0.5, -0.2], 1.0)
        @test_throws ArgumentError tanh_saturation([1.0, 2.0], 1.0, [0.5, -0.2])
    end
end

@testset "michaelis_menten" begin
    @testset "abacus parity" begin
        for case in ABACUS_MICHAELIS_MENTEN_CASES
            actual = michaelis_menten(case.x, case.alpha, case.lam)
            @test size(actual) == size(case.expected)
            @test actual ≈ case.expected atol = 1.0e-12 rtol = 1.0e-12
        end
    end

    @testset "known examples" begin
        @test isapprox(michaelis_menten(10.0, 100.0, 5.0), 66.66666666666667; atol = 1.0e-12, rtol = 1.0e-12)
        @test isapprox(michaelis_menten(20.0, 100.0, 5.0), 80.0; atol = 1.0e-12, rtol = 1.0e-12)
    end

    @testset "parameter validation" begin
        @test_throws ArgumentError michaelis_menten([1.0, 2.0], 0.0, 1.0)
        @test_throws ArgumentError michaelis_menten([1.0, 2.0], 1.0, 0.0)
        @test_throws ArgumentError michaelis_menten([1.0, 2.0], [1.0, -0.5], 1.0)
        @test_throws ArgumentError michaelis_menten([1.0, 2.0], 1.0, [1.0, -0.5])
    end
end

@testset "hill_function" begin
    @testset "abacus parity" begin
        for case in ABACUS_HILL_FUNCTION_CASES
            actual = hill_function(case.x, case.slope, case.kappa)
            @test size(actual) == size(case.expected)
            @test actual ≈ case.expected atol = 1.0e-12 rtol = 1.0e-12
        end
    end

    @testset "basic behavior" begin
        x = collect(range(0.0, 10.0; length = 100))
        y = hill_function(x, 2.0, 2.0)
        @test all(diff(y) .>= 0)
        @test hill_function(0.0, 2.0, 2.0) == 0.0
        @test hill_function(2.0, 2.0, 2.0) ≈ 0.5 atol = 1.0e-12 rtol = 1.0e-12
        @test hill_function(1.0e6, 2.0, 2.0) ≈ 1.0 atol = 1.0e-10 rtol = 1.0e-10
        @test maximum(hill_function([1.0, 2.0, 3.0], 2.0, 2.0)) <= 1.0
    end

    @testset "parameter validation" begin
        @test_throws ArgumentError hill_function([-1.0, 2.0], 1.5, 1.0)
        @test_throws ArgumentError hill_function([1.0, 2.0], 0.0, 1.0)
        @test_throws ArgumentError hill_function([1.0, 2.0], 1.0, 0.0)
        @test_throws ArgumentError hill_function([1.0, 2.0], [1.0, -0.5], 1.0)
        @test_throws ArgumentError hill_function([1.0, 2.0], 1.0, [1.0, -0.5])
    end
end
