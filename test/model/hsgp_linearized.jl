using Epsilon
using ForwardDiff
using ReverseDiff
using Statistics
using Test

include(joinpath(@__DIR__, "..", "fixtures", "abacus", "hsgp_linearized_cases.jl"))

@testset "HSGP linearised geometry parity" begin
    for case in ABACUS_HSGP_LINEARIZED_FIXTURES.geometry_cases
        @testset "$(case.name)" begin
            frequencies = Epsilon._hsgp_frequencies(
                case.m,
                case.L;
                drop_first = case.drop_first,
            )
            phi = Epsilon._hsgp_basis_matrix(
                case.x;
                m = case.m,
                L = case.L,
                drop_first = case.drop_first,
                demeaned_basis = case.demeaned_basis,
            )
            sqrt_psd = Epsilon._hsgp_sqrt_psd(
                case.m,
                case.L;
                covariance = case.covariance,
                eta = case.eta,
                lengthscale = case.lengthscale,
                drop_first = case.drop_first,
            )

            expected_modes = collect((1 + Int(case.drop_first)):case.m)
            @test frequencies ≈ π .* expected_modes ./ (2 * case.L)
            @test phi ≈ case.expected_phi atol = 1.0e-12 rtol = 1.0e-12
            @test sqrt_psd ≈ case.expected_sqrt_psd atol = 1.0e-12 rtol = 1.0e-12
            @test size(phi) == (length(case.x), length(sqrt_psd))
            @test length(frequencies) == length(sqrt_psd)
            if case.demeaned_basis
                @test vec(mean(phi; dims = 1)) ≈ zeros(size(phi, 2)) atol = 1.0e-12
            end
        end
    end
end

@testset "HSGP linearised geometry contracts" begin
    asymmetric_x = Float64[0.0, 1.0, 10.0]
    range_centre = (minimum(asymmetric_x) + maximum(asymmetric_x)) / 2
    mean_centre = mean(asymmetric_x)
    phi = Epsilon._hsgp_basis_matrix(asymmetric_x; m = 3, L = 12.0)
    expected_range_centre = inv(sqrt(12.0)) .* sin.(
        (asymmetric_x .- range_centre .+ 12.0) .* permutedims(π .* (1:3) ./ 24.0),
    )
    expected_mean_centre = inv(sqrt(12.0)) .* sin.(
        (asymmetric_x .- mean_centre .+ 12.0) .* permutedims(π .* (1:3) ./ 24.0),
    )
    @test phi ≈ expected_range_centre
    @test !(phi ≈ expected_mean_centre)

    zero_mode_basis = Epsilon._hsgp_basis_matrix(
        asymmetric_x;
        m = 1,
        L = 12.0,
        drop_first = true,
        demeaned_basis = true,
    )
    zero_mode_psd = Epsilon._hsgp_sqrt_psd(
        1,
        12.0;
        covariance = :expquad,
        eta = 1.0,
        lengthscale = 2.5,
        drop_first = true,
    )
    @test size(zero_mode_basis) == (length(asymmetric_x), 0)
    @test isempty(zero_mode_psd)

    @test_throws ArgumentError Epsilon._hsgp_frequencies(0, 1.0)
    @test_throws ArgumentError Epsilon._hsgp_frequencies(1.5, 1.0)
    @test_throws ArgumentError Epsilon._hsgp_frequencies(1, 0.0)
    @test_throws ArgumentError Epsilon._hsgp_frequencies(1, Inf)
    @test all(isfinite, Epsilon._hsgp_frequencies(1, 1.0e308))
    @test_throws ArgumentError Epsilon._hsgp_frequencies(1, nextfloat(0.0))
    @test_throws ArgumentError Epsilon._hsgp_basis_matrix(Float64[]; m = 1, L = 1.0)
    @test_throws ArgumentError Epsilon._hsgp_basis_matrix([0.0, NaN]; m = 1, L = 1.0)
    @test_throws ArgumentError Epsilon._hsgp_basis_matrix([0.0, Inf]; m = 1, L = 1.0)
    @test all(
        isfinite,
        Epsilon._hsgp_basis_matrix([1.0e308, 1.1e308]; m = 1, L = 1.0e308),
    )
    @test_throws ArgumentError Epsilon._hsgp_basis_matrix(
        [0.0, 1.0e308];
        m = 1,
        L = 1.0e-307,
    )
    @test_throws ArgumentError Epsilon._hsgp_basis_matrix(
        BigFloat[big"1e1000", big"1.1e1000"];
        m = 1,
        L = 1.0,
    )
    @test_throws ArgumentError Epsilon._hsgp_sqrt_psd(
        1,
        1.0;
        covariance = :unsupported,
        eta = 1.0,
        lengthscale = 1.0,
    )
    @test_throws ArgumentError Epsilon._hsgp_sqrt_psd(
        1,
        1.0;
        covariance = :expquad,
        eta = 0.0,
        lengthscale = 1.0,
    )
    @test_throws ArgumentError Epsilon._hsgp_sqrt_psd(
        1,
        1.0;
        covariance = :expquad,
        eta = 1.0,
        lengthscale = NaN,
    )
    @test all(
        isfinite,
        Epsilon._hsgp_sqrt_psd(
            1,
            12.0;
            covariance = :expquad,
            eta = 1.0e308,
            lengthscale = 1.0e-308,
        ),
    )
    @test all(
        isfinite,
        Epsilon._hsgp_sqrt_psd(
            1,
            12.0;
            covariance = :matern32,
            eta = 1.0e308,
            lengthscale = 1.0e-308,
        ),
    )
    @test all(
        isfinite,
        Epsilon._hsgp_sqrt_psd(
            1,
            12.0;
            covariance = :matern52,
            eta = 1.0e308,
            lengthscale = 1.0e-308,
        ),
    )
    @test all(
        isfinite,
        Epsilon._hsgp_sqrt_psd(
            1,
            1.0e308;
            covariance = :matern52,
            eta = 1.0,
            lengthscale = 1.0e308,
        ),
    )
    for covariance in (:expquad, :matern32, :matern52)
        @test all(
            isfinite,
            Epsilon._hsgp_sqrt_psd(
                1,
                1.0;
                covariance,
                eta = 1.0e308,
                lengthscale = 1.0e308,
            ),
        )
    end
end

@testset "HSGP recommendation parity and hardening" begin
    for case in ABACUS_HSGP_LINEARIZED_FIXTURES.recommendation_cases
        approximation = Epsilon._approx_hsgp_hyperparams(
            case.x,
            case.x_center;
            lengthscale_range = (case.lengthscale_lower, case.resolved_lengthscale_upper),
            covariance = case.covariance,
        )
        recommendation = Epsilon._recommend_hsgp_basis(
            case.x,
            case.x_mid;
            lengthscale_lower = case.lengthscale_lower,
            lengthscale_upper = case.lengthscale_upper,
            covariance = case.covariance,
        )
        @test approximation[1] == case.expected_approx_m
        @test approximation[2] ≈ case.expected_approx_c atol = 1.0e-12 rtol = 1.0e-12
        @test recommendation[1] == case.expected_recommendation_m
        @test recommendation[2] ≈ case.expected_recommendation_L atol = 1.0e-12 rtol = 1.0e-12
    end

    x = Float64[0.0, 1.0, 10.0]
    @test_throws ArgumentError Epsilon._approx_hsgp_hyperparams(
        Float64[],
        5.0;
        lengthscale_range = (1.0, 2.0),
        covariance = :expquad,
    )
    @test_throws ArgumentError Epsilon._approx_hsgp_hyperparams(
        [1.0, 1.0],
        1.0;
        lengthscale_range = (1.0, 2.0),
        covariance = :expquad,
    )
    @test_throws ArgumentError Epsilon._approx_hsgp_hyperparams(
        [0.0, NaN],
        1.0;
        lengthscale_range = (1.0, 2.0),
        covariance = :expquad,
    )
    @test_throws ArgumentError Epsilon._approx_hsgp_hyperparams(
        x,
        NaN;
        lengthscale_range = (1.0, 2.0),
        covariance = :expquad,
    )
    @test_throws ArgumentError Epsilon._approx_hsgp_hyperparams(
        x,
        5.0;
        lengthscale_range = (2.0, 1.0),
        covariance = :expquad,
    )
    @test_throws ArgumentError Epsilon._recommend_hsgp_basis(
        x,
        0.0;
        lengthscale_lower = 1.0,
        covariance = :expquad,
    )
    @test_throws ArgumentError Epsilon._recommend_hsgp_basis(
        x,
        5.0;
        lengthscale_lower = 1.0,
        lengthscale_upper = 1.0,
        covariance = :expquad,
    )
    @test_throws ArgumentError Epsilon._approx_hsgp_hyperparams(
        [0.0, 1.0],
        0.0;
        lengthscale_range = (1.0e-308, 1.0e308),
        covariance = :expquad,
    )
end

@testset "HSGP linearised geometry autodiff and support boundary" begin
    objective(theta) = sum(
        Epsilon._hsgp_sqrt_psd(
            4,
            12.0;
            covariance = :matern52,
            eta = theta[1],
            lengthscale = theta[2],
        ),
    )
    params = [1.7, 2.5]
    forward = ForwardDiff.gradient(objective, params)
    reverse = ReverseDiff.gradient(objective, params)

    @test all(isfinite, forward)
    @test all(isfinite, reverse)
    @test forward ≈ reverse atol = 1.0e-9 rtol = 1.0e-9

    for symbol in (
            :_hsgp_frequencies,
            :_hsgp_basis_matrix,
            :_hsgp_sqrt_psd,
            :_approx_hsgp_hyperparams,
            :_recommend_hsgp_basis,
        )
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
