include(joinpath(@__DIR__, "..", "fixtures", "abacus", "binomial_adstock_cases.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "abacus", "geometric_adstock_cases.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "abacus", "delayed_adstock_cases.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "abacus", "weibull_adstock_cases.jl"))

using Epsilon
using Test

@testset "binomial_adstock" begin
    @testset "abacus parity" begin
        for case in ABACUS_BINOMIAL_ADSTOCK_CASES
            actual = binomial_adstock(
                case.x,
                case.alpha,
                case.l_max;
                normalize = case.normalize,
                axis = case.axis,
                mode = case.mode,
            )
            @test size(actual) == size(case.expected)
            @test actual ≈ case.expected atol = 1.0e-12 rtol = 1.0e-12
        end
    end

    @testset "parameter validation" begin
        @test_throws ArgumentError binomial_adstock([1.0, 2.0], 0.0, 3)
        @test_throws ArgumentError binomial_adstock([1.0, 2.0], -0.1, 3)
        @test_throws ArgumentError binomial_adstock([1.0, 2.0], 1.1, 3)
        @test_throws ArgumentError binomial_adstock([1.0, 2.0], [0.1, 0.0], 3)
        @test_throws ArgumentError binomial_adstock([1.0, 2.0], 0.5, 0)
    end

    @testset "eltype preservation" begin
        actual = binomial_adstock(Float32[1, 2, 3], Float32(0.5), 3)
        @test eltype(actual) == Float32
    end
end

@testset "geometric_adstock" begin
    @testset "abacus parity" begin
        for case in ABACUS_GEOMETRIC_ADSTOCK_CASES
            actual = geometric_adstock(
                case.x,
                case.alpha,
                case.l_max;
                normalize = case.normalize,
                axis = case.axis,
                mode = case.mode,
            )
            @test size(actual) == size(case.expected)
            @test actual ≈ case.expected atol = 1.0e-12 rtol = 1.0e-12
        end
    end

    @testset "parameter validation" begin
        @test_throws ArgumentError geometric_adstock([1.0, 2.0], -0.1, 3)
        @test_throws ArgumentError geometric_adstock([1.0, 2.0], 1.1, 3)
        @test_throws ArgumentError geometric_adstock([1.0, 2.0], [0.1, 1.2], 3)
        @test_throws ArgumentError geometric_adstock([1.0, 2.0], 0.5, 0)
    end
end

@testset "delayed_adstock" begin
    @testset "abacus parity" begin
        for case in ABACUS_DELAYED_ADSTOCK_CASES
            actual = delayed_adstock(
                case.x,
                case.alpha,
                case.theta,
                case.l_max;
                normalize = case.normalize,
                axis = case.axis,
                mode = case.mode,
            )
            @test size(actual) == size(case.expected)
            @test actual ≈ case.expected atol = 1.0e-12 rtol = 1.0e-12
        end
    end

    @testset "parameter validation" begin
        @test_throws ArgumentError delayed_adstock([1.0, 2.0], -0.1, 1, 3)
        @test_throws ArgumentError delayed_adstock([1.0, 2.0], 1.1, 1, 3)
        @test_throws ArgumentError delayed_adstock([1.0, 2.0], [0.1, 1.2], [0, 1], 3)
        @test_throws ArgumentError delayed_adstock([1.0, 2.0], 0.5, 1, 0)
    end

    @testset "zero-sum normalized kernels stay finite" begin
        actual = delayed_adstock([1.0, 2.0, 3.0], 0.0, 10, 3; normalize = true)
        @test all(isfinite, actual)
        @test actual == zeros(3)
    end
end

@testset "weibull_adstock" begin
    @testset "abacus parity" begin
        for case in ABACUS_WEIBULL_ADSTOCK_CASES
            actual = weibull_adstock(
                case.x,
                case.lam,
                case.k,
                case.l_max;
                axis = case.axis,
                mode = case.mode,
                type = case.type,
                normalize = case.normalize,
            )
            @test size(actual) == size(case.expected)
            @test actual ≈ case.expected atol = 1.0e-12 rtol = 1.0e-12
        end
    end

    @testset "type parsing" begin
        x = [1.0, 2.0, 3.0]
        @test weibull_adstock(x, 1.0, 1.0, 3; type = "PDF") ==
            weibull_adstock(x, 1.0, 1.0, 3; type = Epsilon.PDF)
        @test weibull_adstock(x, 1.0, 1.0, 3; type = :cdf) ==
            weibull_adstock(x, 1.0, 1.0, 3; type = Epsilon.CDF)
        @test weibull_adstock(x, 1.0, 1.0, 3; type = :pdf) ==
            weibull_adstock(x, 1.0, 1.0, 3; type = Epsilon.PDF)
        @test_throws ArgumentError weibull_adstock(x, 1.0, 1.0, 3; type = "PMF")
    end

    @testset "parameter validation" begin
        @test_throws ArgumentError weibull_adstock([1.0, 2.0], 0.0, 1.0, 3)
        @test_throws ArgumentError weibull_adstock([1.0, 2.0], 1.0, 0.0, 3)
        @test_throws ArgumentError weibull_adstock([1.0, 2.0], [0.5, -1.0], [1.0, 1.0], 3)
        @test_throws ArgumentError weibull_adstock([1.0, 2.0], [1.0, 1.0], [0.5, -1.0], 3)
        @test_throws ArgumentError weibull_adstock([1.0, 2.0], 1.0, 1.0, 0)
    end

    @testset "single-lag normalized PDF stays finite" begin
        x = [2.0, 4.0, 6.0]
        actual = weibull_adstock(x, 1.0, 1.0, 1; type = Epsilon.PDF, normalize = true)
        @test all(isfinite, actual)
        @test actual == x
    end

    @testset "cdf contract preserves leading self-retention term" begin
        actual = weibull_adstock([1.0, 0.0, 0.0, 0.0], 1.0, 1.0, 1; type = Epsilon.CDF)
        @test actual[1] == 1.0
        @test actual[2] > 0.0
    end
end
