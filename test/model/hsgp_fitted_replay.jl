using Epsilon
using ForwardDiff
using Statistics
using Test

include(joinpath(@__DIR__, "..", "fixtures", "golden", "hsgp_fitted_replay_cases.jl"))

@testset "HSGP fitted positive multiplier replay fixtures" begin
    for case in GOLDEN_HSGP_FITTED_REPLAY_FIXTURES.cases
        @testset "$(case.name)" begin
            state = Epsilon._fit_hsgp_positive_multiplier_state(
                case.training_x,
                case.sqrt_psd,
                case.z;
                m = case.m,
                L = case.L,
                drop_first = case.drop_first,
                demeaned_basis = case.demeaned_basis,
            )
            training_replay = Epsilon._hsgp_replay_positive_multiplier(case.training_x, state)
            prediction_replay = Epsilon._hsgp_replay_positive_multiplier(case.prediction_x, state)
            training_basis = Epsilon._hsgp_basis_matrix(
                case.training_x;
                m = case.m,
                L = case.L,
                drop_first = case.drop_first,
                demeaned_basis = case.demeaned_basis,
            )

            @test state.training_centre ≈ case.expected_training_centre
            @test collect(state.training_raw_mean) ≈ case.expected_training_raw_mean atol = 1.0e-12 rtol = 1.0e-12
            if case.demeaned_basis
                if isempty(state.basis_offset)
                    @test isempty(case.expected_basis_offset)
                else
                    @test collect(state.basis_offset) ≈ case.expected_basis_offset atol = 1.0e-12 rtol = 1.0e-12
                end
            else
                @test isnothing(state.basis_offset)
            end
            @test training_replay ≈ case.expected_training_multiplier atol = 1.0e-12 rtol = 1.0e-12
            @test prediction_replay ≈ case.expected_replay_multiplier atol = 1.0e-12 rtol = 1.0e-12
            @test training_replay ≈ Epsilon._hsgp_positive_multiplier(
                training_basis,
                case.sqrt_psd,
                case.z,
            ) atol = 1.0e-12 rtol = 1.0e-12
            @test all(isfinite, prediction_replay)
            @test all(>(0), prediction_replay)
        end
    end
end

@testset "HSGP fitted replay retains training geometry" begin
    case = only(filter(case -> case.name == "asymmetric_vector_outside_boundary", GOLDEN_HSGP_FITTED_REPLAY_FIXTURES.cases))
    state = Epsilon._fit_hsgp_positive_multiplier_state(
        case.training_x,
        case.sqrt_psd,
        case.z;
        m = case.m,
        L = case.L,
    )
    replay = Epsilon._hsgp_replay_positive_multiplier(case.prediction_x, state)
    prediction_local_basis = Epsilon._hsgp_basis_matrix(
        case.prediction_x;
        m = case.m,
        L = case.L,
    )
    prediction_local_raw = Epsilon._hsgp_stable_softplus.(
        Epsilon._hsgp_latent(prediction_local_basis, case.sqrt_psd, case.z),
    )

    @test any(abs.(case.prediction_x .- state.training_centre) .> case.L)
    @test !(replay ≈ prediction_local_raw ./ Epsilon._hsgp_materialize_training_raw_mean(state))
    @test !(replay ≈ prediction_local_raw ./ mean(prediction_local_raw; dims = 1))

    demeaned_case = only(filter(case -> case.name == "demeaned_basis_replay", GOLDEN_HSGP_FITTED_REPLAY_FIXTURES.cases))
    demeaned_state = Epsilon._fit_hsgp_positive_multiplier_state(
        demeaned_case.training_x,
        demeaned_case.sqrt_psd,
        demeaned_case.z;
        m = demeaned_case.m,
        L = demeaned_case.L,
        demeaned_basis = true,
    )
    prediction_raw_basis = Epsilon._hsgp_basis_matrix_at_centre(
        demeaned_case.prediction_x,
        demeaned_state.training_centre;
        m = demeaned_case.m,
        L = demeaned_case.L,
    )
    prediction_local_offset = vec(mean(prediction_raw_basis; dims = 1))
    prediction_local_raw = Epsilon._hsgp_stable_softplus.(
        (prediction_raw_basis .- permutedims(prediction_local_offset)) *
            Epsilon._hsgp_materialize_weighted_coefficients(demeaned_state),
    )
    @test !(collect(demeaned_state.basis_offset) ≈ prediction_local_offset)
    @test !(Epsilon._hsgp_replay_positive_multiplier(demeaned_case.prediction_x, demeaned_state) ≈ prediction_local_raw ./ Epsilon._hsgp_materialize_training_raw_mean(demeaned_state))
end

@testset "HSGP fitted replay state ownership and contracts" begin
    x_training = Float64[0.0, 1.0, 7.0, 10.0]
    sqrt_psd = Float64[1.1, 0.8]
    z = Float64[-0.4, 0.2]
    state = Epsilon._fit_hsgp_positive_multiplier_state(
        x_training,
        sqrt_psd,
        z;
        m = 2,
        L = 7.0,
    )
    baseline = Epsilon._hsgp_replay_positive_multiplier(Float64[9.5, 13.0], state)
    sqrt_psd .= 100.0
    z .= -100.0
    @test Epsilon._hsgp_replay_positive_multiplier(Float64[9.5, 13.0], state) == baseline
    @test state.weighted_coefficients isa Tuple
    @test state.training_raw_mean isa Tuple
    @test_throws MethodError setindex!(state.weighted_coefficients, 0.0, 1)
    @test_throws MethodError setindex!(state.training_raw_mean, 0.0, 1)

    demeaned_state = Epsilon._fit_hsgp_positive_multiplier_state(
        x_training,
        Float64[1.1, 0.8],
        Float64[-0.4, 0.2];
        m = 2,
        L = 7.0,
        demeaned_basis = true,
    )
    @test demeaned_state.basis_offset isa Tuple
    @test_throws MethodError setindex!(demeaned_state.basis_offset, 0.0, 1)

    @test_throws ArgumentError Epsilon._fit_hsgp_positive_multiplier_state(
        Float64[NaN],
        Float64[1.0],
        Float64[0.0];
        m = 1,
        L = 1.0,
    )
    @test_throws ArgumentError Epsilon._fit_hsgp_positive_multiplier_state(
        Float64[0.0, 1.0],
        Float64[1.0],
        Float64[0.0, 1.0];
        m = 2,
        L = 1.0,
    )
    @test_throws ArgumentError Epsilon._fit_hsgp_positive_multiplier_state(
        Float64[0.0, 1.0],
        Float64[1.0],
        Float64[-2000.0];
        m = 1,
        L = 1.0,
    )
    prediction_underflow_state = Epsilon._fit_hsgp_positive_multiplier_state(
        Float64[0.0, 1.0],
        Float64[1.0],
        Float64[2000.0];
        m = 1,
        L = 1.0,
    )
    @test_throws ArgumentError Epsilon._hsgp_replay_positive_multiplier(
        Float64[2.5],
        prediction_underflow_state,
    )

    malformed_state = Epsilon._HSGPPositiveMultiplierState(
        1,
        1.0,
        false,
        false,
        0.0,
        nothing,
        (1.0,),
        Float64,
        (1, 1),
        false,
        (0.0,),
    )
    @test_throws ArgumentError Epsilon._hsgp_replay_positive_multiplier(Float64[0.0], malformed_state)

    mismatched_coefficient_type_state = Epsilon._HSGPPositiveMultiplierState(
        1,
        1.0,
        false,
        false,
        0.0,
        nothing,
        (1.9,),
        Int,
        (1, 1),
        false,
        (1.0,),
    )
    @test_throws ArgumentError Epsilon._hsgp_replay_positive_multiplier(
        Float64[0.0],
        mismatched_coefficient_type_state,
    )
end

@testset "HSGP fitted replay autodiff" begin
    x_training = Float64[0.0, 1.0, 7.0, 10.0]
    x_prediction = Float64[9.5, 13.0]
    sqrt_psd = Float64[1.1, 0.8]
    observation_weights = Float64[1.0, 2.0]

    z_gradient = ForwardDiff.gradient(
        z -> sum(
            observation_weights .* Epsilon._hsgp_replay_positive_multiplier(
                x_prediction,
                Epsilon._fit_hsgp_positive_multiplier_state(
                    x_training,
                    sqrt_psd,
                    z;
                    m = 2,
                    L = 7.0,
                ),
            ),
        ),
        Float64[-0.4, 0.2],
    )
    @test all(isfinite, z_gradient)

    hyperparameter_gradient = ForwardDiff.gradient(
        parameters -> begin
            weights = Epsilon._hsgp_sqrt_psd(
                2,
                7.0;
                covariance = :expquad,
                eta = parameters[1],
                lengthscale = parameters[2],
            )
            state = Epsilon._fit_hsgp_positive_multiplier_state(
                x_training,
                weights,
                Float64[-0.4, 0.2];
                m = 2,
                L = 7.0,
            )
            sum(observation_weights .* Epsilon._hsgp_replay_positive_multiplier(x_prediction, state))
        end,
        Float64[1.1, 2.2],
    )
    @test all(isfinite, hyperparameter_gradient)

    for symbol in (
            :_HSGPPositiveMultiplierState,
            :_fit_hsgp_positive_multiplier_state,
            :_hsgp_replay_positive_multiplier,
        )
        @test isdefined(Epsilon, symbol)
        @test !(symbol in names(Epsilon; all = false, imported = false))
    end
end
