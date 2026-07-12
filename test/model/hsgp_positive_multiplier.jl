using Epsilon
using ForwardDiff
using Test

include(joinpath(@__DIR__, "..", "fixtures", "abacus", "hsgp_positive_multiplier_cases.jl"))

@testset "HSGP positive multiplier parity" begin
    for case in ABACUS_HSGP_POSITIVE_MULTIPLIER_FIXTURES.softplus_cases
        @testset "softplus $(case.name)" begin
            @test Epsilon._hsgp_stable_softplus.(case.values) ≈ case.expected atol = 1.0e-14 rtol = 1.0e-14
        end
    end

    for case in ABACUS_HSGP_POSITIVE_MULTIPLIER_FIXTURES.projection_cases
        @testset "$(case.name)" begin
            latent = Epsilon._hsgp_latent(case.phi, case.sqrt_psd, case.z)
            raw = Epsilon._hsgp_stable_softplus.(latent)
            @test latent ≈ case.expected_latent atol = 1.0e-12 rtol = 1.0e-12
            @test raw ≈ case.expected_softplus atol = 1.0e-12 rtol = 1.0e-12

            if isnothing(case.expected_error)
                multiplier = Epsilon._hsgp_positive_multiplier(case.phi, case.sqrt_psd, case.z)
                @test multiplier ≈ case.expected_multiplier atol = 1.0e-12 rtol = 1.0e-12
                @test all(isfinite, multiplier)
                @test all(>(0), multiplier)
                if case.name == "zero_retained_modes_matrix"
                    @test all(==(1.0), multiplier)
                end
            else
                @test case.expected_error in (:nonpositive_raw_entry, :nonpositive_raw_mean)
                @test_throws ArgumentError Epsilon._hsgp_positive_multiplier(
                    case.phi,
                    case.sqrt_psd,
                    case.z,
                )
            end
        end
    end
end

@testset "HSGP positive multiplier contracts and autodiff" begin
    phi = Float64[0.25 0.5; 0.5 -0.25; 0.75 0.125]
    sqrt_psd = Float64[1.2, 0.8]
    vector_z = Float64[-0.5, 0.25]
    matrix_z = Float64[-0.5 0.75; 0.25 -0.125]

    @test size(Epsilon._hsgp_latent(phi, sqrt_psd, vector_z)) == (3,)
    @test size(Epsilon._hsgp_latent(phi, sqrt_psd, matrix_z)) == (3, 2)
    @test Epsilon._hsgp_positive_multiplier(
        zeros(3, 0),
        Float64[],
        Float64[],
    ) == ones(3)

    @test_throws ArgumentError Epsilon._hsgp_latent(zeros(0, 1), [1.0], [0.0])
    @test_throws ArgumentError Epsilon._hsgp_latent(phi, [-1.0, 0.8], vector_z)
    @test_throws ArgumentError Epsilon._hsgp_latent(phi, [1.2, Inf], vector_z)
    @test_throws ArgumentError Epsilon._hsgp_latent(phi, sqrt_psd, [0.0])
    @test_throws ArgumentError Epsilon._hsgp_latent(phi, sqrt_psd, zeros(3, 1))
    @test_throws ArgumentError Epsilon._hsgp_latent(phi, sqrt_psd, zeros(2, 0))
    @test_throws ArgumentError Epsilon._hsgp_latent([NaN 0.0], sqrt_psd, vector_z)
    @test_throws ArgumentError Epsilon._hsgp_latent(phi, sqrt_psd, [NaN, 0.0])
    @test_throws ArgumentError Epsilon._hsgp_stable_softplus(NaN)

    observation_weights = Float64[1.0, 2.0, 4.0]
    z_objective(z) = sum(
        observation_weights .* Epsilon._hsgp_positive_multiplier(phi, sqrt_psd, z),
    )
    z_gradient = ForwardDiff.gradient(z_objective, vector_z)
    @test all(isfinite, z_gradient)

    parameter_objective(parameters) = begin
        weights = Epsilon._hsgp_sqrt_psd(
            2,
            6.0;
            covariance = :expquad,
            eta = parameters[1],
            lengthscale = parameters[2],
        )
        multiplier = Epsilon._hsgp_positive_multiplier(phi, weights, vector_z)
        sum(observation_weights .* multiplier)
    end
    parameter_gradient = ForwardDiff.gradient(parameter_objective, Float64[1.1, 2.2])
    @test all(isfinite, parameter_gradient)

    for symbol in (:_hsgp_latent, :_hsgp_stable_softplus, :_hsgp_positive_multiplier)
        @test isdefined(Epsilon, symbol)
        @test !(symbol in names(Epsilon; all = false, imported = false))
    end
    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        seasonality = Dict("type" => "hsgp", "m" => 10),
    )
end
