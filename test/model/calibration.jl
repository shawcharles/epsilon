using Distributions
using Epsilon
using ForwardDiff
using ReverseDiff
using Test

include(joinpath(@__DIR__, "..", "fixtures", "abacus", "calibration_alignment_cases.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "abacus", "calibration_unaligned_cases.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "abacus", "calibration_monotonic_cases.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "abacus", "calibration_channel_scaling_cases.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "abacus", "calibration_target_scaling_cases.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "abacus", "calibration_combined_scaling_cases.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "abacus", "lift_test_likelihood_cases.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "abacus", "cost_per_target_cases.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "abacus", "calibration_integration_cases.jl"))

_calibration_coord_dict(nt) = Dict{String, AbstractVector}(string(k) => collect(v) for (k, v) in pairs(nt))

@testset "CalibrationStepConfig validation" begin
    config = CalibrationStepConfig(method = "add_lift_test_measurements")
    @test config.method == "add_lift_test_measurements"
    @test config.params == Dict{String, Any}()

    with_params = CalibrationStepConfig(
        method = "add_cost_per_target_calibration",
        params = Dict("name" => "cpt"),
    )
    @test with_params.params == Dict{String, Any}("name" => "cpt")
    @test with_params == CalibrationStepConfig(
        method = "add_cost_per_target_calibration",
        params = Dict("name" => "cpt"),
    )

    @test_throws ArgumentError CalibrationStepConfig(method = "")
    @test_throws ArgumentError CalibrationStepConfig(method = "unsupported_method")
    @test_throws ArgumentError CalibrationStepConfig(
        method = "add_lift_test_measurements",
        params = Dict("dist" => "Gamma"),
    )
end

@testset "validate_lift_test_columns" begin
    @test validate_lift_test_columns(["x", "delta_x", "delta_y", "sigma"]) === nothing
    @test validate_lift_test_columns(["sigma", "delta_y", "x", "delta_x", "date"]) === nothing
    @test_throws ArgumentError validate_lift_test_columns(["x", "delta_x"])
end

@testset "exact_row_indices aligned" begin
    for case in ABACUS_CALIBRATION_ALIGNMENT_CASES
        coords = _calibration_coord_dict(case.coords)
        df = _calibration_coord_dict(case.df)
        @test exact_row_indices(coords, df) == case.expected_indices_1based
    end

    @test_throws ArgumentError exact_row_indices(
        Dict{String, AbstractVector}("channel" => [1, 2]),
        Dict{String, AbstractVector}("region" => ["A"]),
    )
    @test_throws ArgumentError exact_row_indices(
        Dict{String, AbstractVector}("channel" => [1, 2]),
        Dict{String, AbstractVector}("channel" => [1, 2], "geo" => ["A"]),
    )
end

@testset "exact_row_indices unaligned" begin
    for case in ABACUS_CALIBRATION_UNALIGNED_CASES
        coords = _calibration_coord_dict(case.coords)
        df = _calibration_coord_dict(case.df)
        err = nothing
        try
            exact_row_indices(coords, df)
        catch caught
            err = caught
        end
        @test err isa UnalignedValuesError
        @test err.unaligned_values == case.expected_unaligned_1based
    end
end

@testset "assert_monotonic_lift" begin
    for case in ABACUS_CALIBRATION_MONOTONIC_CASES
        if case.expect_error
            @test_throws NonMonotonicError assert_monotonic_lift(case.delta_x, case.delta_y)
        else
            @test assert_monotonic_lift(case.delta_x, case.delta_y) === nothing
        end
    end

    @test_throws ArgumentError assert_monotonic_lift([1.0, 2.0], [1.0])
    @test_throws ArgumentError assert_monotonic_lift([1.0, Inf], [1.0, 2.0])
end

@testset "scale_channel_lift_measurements" begin
    for case in ABACUS_CALIBRATION_CHANNEL_SCALING_CASES
        transform = matrix -> matrix .* reshape(case.scale, 1, :)
        result = scale_channel_lift_measurements(
            case.df.channel,
            case.df.x,
            case.df.delta_x,
            case.channel_columns,
            transform,
        )
        @test result.channel == case.expected.channel
        @test result.x ≈ case.expected.x
        @test result.delta_x ≈ case.expected.delta_x
    end

    @test_throws ArgumentError scale_channel_lift_measurements(
        String["unknown"],
        Float64[1.0],
        Float64[1.0],
        String["organic", "paid"],
        matrix -> matrix,
    )
    @test_throws ArgumentError scale_channel_lift_measurements(
        String["organic"],
        Float64[1.0],
        Float64[1.0],
        String["organic", "organic"],
        matrix -> matrix,
    )
    @test_throws ArgumentError scale_channel_lift_measurements(
        String["organic"],
        Float64[1.0],
        Float64[1.0],
        String["organic"],
        matrix -> matrix[:, 1],
    )
    @test_throws ArgumentError scale_channel_lift_measurements(
        String["organic"],
        Float64[Inf],
        Float64[1.0],
        String["organic"],
        matrix -> matrix,
    )
end

@testset "scale_target_for_lift_measurements" begin
    for case in ABACUS_CALIBRATION_TARGET_SCALING_CASES
        result = scale_target_for_lift_measurements(case.target, matrix -> matrix ./ case.scale)
        @test result ≈ case.expected
    end

    @test_throws ArgumentError scale_target_for_lift_measurements(Float64[1.0, 2.0], matrix -> matrix[1:1, :])
    @test_throws ArgumentError scale_target_for_lift_measurements(Float64[1.0, NaN], matrix -> matrix)
end

@testset "scale_lift_measurements" begin
    for case in ABACUS_CALIBRATION_COMBINED_SCALING_CASES
        result = scale_lift_measurements(
            case.df.channel,
            case.df.x,
            case.df.delta_x,
            case.df.delta_y,
            case.df.sigma,
            case.channel_columns,
            matrix -> matrix .* case.channel_transform_scale,
            matrix -> matrix ./ case.target_transform_scale,
        )
        @test result.channel == case.expected.channel
        @test result.x ≈ case.expected.x
        @test result.delta_x ≈ case.expected.delta_x
        @test result.delta_y ≈ case.expected.delta_y
        @test result.sigma ≈ case.expected.sigma
    end

    @test_throws ArgumentError scale_lift_measurements(
        String["organic"],
        Float64[1.0],
        Float64[1.0],
        Float64[1.0],
        Float64[-0.1],
        String["organic"],
        matrix -> matrix,
        matrix -> matrix,
    )
end

@testset "gamma_shape_scale and lift_test_gamma_distribution" begin
    params = gamma_shape_scale(2.0, 0.5)
    @test params.shape ≈ 2.0^2 / 0.5^2
    @test params.scale ≈ 0.5^2 / 2.0

    dist = lift_test_gamma_distribution(2.0, 0.5)
    @test mean(dist) ≈ 2.0
    @test std(dist) ≈ 0.5

    @test_throws ArgumentError gamma_shape_scale(-1.0, 0.5)
    @test_throws ArgumentError gamma_shape_scale(1.0, -0.5)
    @test_throws ArgumentError gamma_shape_scale(1.0, Inf)
end

@testset "lift_test_likelihood_terms" begin
    for case in ABACUS_LIFT_TEST_LIKELIHOOD_CASES
        saturation_fn = x -> centered_logistic_saturation(x, case.lam)
        terms = lift_test_likelihood_terms(saturation_fn, case.x, case.delta_x, case.delta_y, case.sigma)
        @test terms.mu ≈ case.expected_mu
        @test terms.observed ≈ case.expected_observed
        @test terms.logp ≈ case.expected_logp atol = 1.0e-6
    end

    @test_throws ArgumentError lift_test_estimated_lift(x -> x[1:1], Float64[1.0, 2.0], Float64[0.5, 0.5])
    @test_throws ArgumentError lift_test_likelihood_terms(
        x -> x,
        Float64[1.0],
        Float64[0.0],
        Float64[0.0],
        Float64[1.0],
    )
    @test_throws ArgumentError lift_test_likelihood_terms(
        x -> x,
        Float64[1.0],
        Float64[1.0],
        Float64[1.0],
        Float64[0.0],
    )
end

@testset "lift_test_log_density" begin
    for case in ABACUS_LIFT_TEST_LIKELIHOOD_CASES
        saturation_fn = x -> centered_logistic_saturation(x, case.lam)
        total = lift_test_log_density(saturation_fn, case.x, case.delta_x, case.delta_y, case.sigma)
        @test total ≈ sum(case.expected_logp) atol = 1.0e-6
    end

    # Zero estimated lift (saturation_fn(x + delta_x) == saturation_fn(x)) must be
    # rejected rather than producing a degenerate Gamma mean.
    @test_throws ArgumentError lift_test_log_density(
        x -> x,
        Float64[1.0],
        Float64[0.0],
        Float64[0.05],
        Float64[0.01],
    )

    # Non-positive sigma must be rejected.
    @test_throws ArgumentError lift_test_log_density(
        x -> x,
        Float64[1.0],
        Float64[0.5],
        Float64[0.05],
        Float64[0.0],
    )
    @test_throws ArgumentError lift_test_log_density(
        x -> x,
        Float64[1.0],
        Float64[0.5],
        Float64[0.05],
        Float64[-1.0],
    )

    # Non-finite inputs must be rejected.
    @test_throws ArgumentError lift_test_log_density(
        x -> x,
        Float64[NaN],
        Float64[0.5],
        Float64[0.05],
        Float64[0.01],
    )
    @test_throws ArgumentError lift_test_log_density(
        x -> x,
        Float64[1.0],
        Float64[Inf],
        Float64[0.05],
        Float64[0.01],
    )
    @test_throws ArgumentError lift_test_log_density(
        x -> x,
        Float64[1.0],
        Float64[0.5],
        Float64[NaN],
        Float64[0.01],
    )
end

@testset "lift_test_payload_log_density" begin
    saturation_fn = (x_row, param_row) -> centered_logistic_saturation(x_row, param_row)

    for case in ABACUS_LIFT_TEST_LIKELIHOOD_CASES
        payload = LiftTestCalibrationPayload(
            fill(1, length(case.x)),
            case.x,
            case.delta_x,
            case.delta_y,
            case.sigma,
        )
        total = lift_test_payload_log_density(saturation_fn, payload, [case.lam])
        @test total ≈ sum(case.expected_logp) atol = 1.0e-6
    end

    # A two-channel payload must select each row's own channel parameter.
    two_channel_payload = LiftTestCalibrationPayload(
        [2, 1],
        Float64[1.0, 3.0],
        Float64[0.5, -1.0],
        Float64[0.05, -0.02],
        Float64[0.01, 0.005],
    )
    channel_param = [1.2, 0.5]
    total = lift_test_payload_log_density(saturation_fn, two_channel_payload, channel_param)
    expected = lift_test_log_density(
        x -> centered_logistic_saturation.(x, channel_param[two_channel_payload.channel_index]),
        two_channel_payload.x,
        two_channel_payload.delta_x,
        two_channel_payload.delta_y,
        two_channel_payload.sigma,
    )
    @test total ≈ expected

    # Channel-index mismatch: channel_index refers to a channel beyond
    # channel_param's length and must fail closed with a clear ArgumentError
    # rather than a raw BoundsError.
    mismatched_payload = LiftTestCalibrationPayload([1, 2], Float64[1.0, 1.0], Float64[0.5, 0.5], Float64[0.05, 0.05], Float64[0.01, 0.01])
    @test_throws ArgumentError lift_test_payload_log_density(saturation_fn, mismatched_payload, [1.0])
end

@testset "lift_test_log_density autodiff smoke test" begin
    x = Float64[1.0, 2.0, 3.0]
    delta_x = Float64[0.5, 1.0, -0.5]
    delta_y = Float64[0.05, 0.08, -0.03]
    sigma = Float64[0.01, 0.02, 0.01]

    objective(theta) = lift_test_log_density(
        z -> centered_logistic_saturation(z, theta[1]),
        x,
        delta_x,
        delta_y,
        sigma,
    )
    params = [0.8]

    forward = ForwardDiff.gradient(objective, params)
    reverse = ReverseDiff.gradient(objective, params)

    @test all(isfinite, forward)
    @test all(isfinite, reverse)
    @test forward ≈ reverse atol = 1.0e-8 rtol = 1.0e-8
end

@testset "cost_per_target penalties" begin
    for case in ABACUS_COST_PER_TARGET_CASES
        penalties = cost_per_target_penalties(case.gathered_cpt, case.targets, case.sigma)
        @test penalties ≈ case.expected_penalties
        @test cost_per_target_total_penalty(case.gathered_cpt, case.targets, case.sigma) ≈
            case.expected_total_penalty

        @test_throws ArgumentError cost_per_target_penalties(
            case.gathered_cpt,
            case.targets,
            vcat(case.sigma, 1.0),
        )
        @test_throws ArgumentError cost_per_target_penalties(
            case.gathered_cpt,
            case.targets,
            fill(0.0, length(case.sigma)),
        )
    end
end

@testset "LiftTestCalibrationPayload construction and validation" begin
    channel_columns = ["organic", "paid"]
    scale = [2.0, 5.0]
    channel_transform = matrix -> matrix .* reshape(scale, 1, :)
    target_scale = 10.0
    target_transform = matrix -> matrix ./ target_scale

    payload = build_lift_test_calibration_payload(
        channel = ["paid", "organic"],
        x = [1.0, 2.0],
        delta_x = [0.5, 1.0],
        delta_y = [1.0, 2.0],
        sigma = [0.1, 0.2],
        channel_columns = channel_columns,
        channel_transform = channel_transform,
        target_transform = target_transform,
    )

    @test payload isa LiftTestCalibrationPayload
    @test payload.channel_index == [2, 1]
    @test payload.x ≈ [1.0 * scale[2], 2.0 * scale[1]]
    @test payload.delta_x ≈ [0.5 * scale[2], 1.0 * scale[1]]
    @test payload.delta_y ≈ [1.0 / target_scale, 2.0 / target_scale]
    @test payload.sigma ≈ [0.1 / target_scale, 0.2 / target_scale]
    @test validate_lift_test_calibration_payload(payload) === nothing
    @test payload == LiftTestCalibrationPayload(
        payload.channel_index,
        payload.x,
        payload.delta_x,
        payload.delta_y,
        payload.sigma,
    )

    # Non-monotonic delta_x/delta_y rows must be rejected before scaling.
    @test_throws NonMonotonicError build_lift_test_calibration_payload(
        channel = ["organic"],
        x = [1.0],
        delta_x = [1.0],
        delta_y = [-1.0],
        sigma = [0.1],
        channel_columns = channel_columns,
        channel_transform = channel_transform,
        target_transform = target_transform,
    )

    # Unknown channel labels must be rejected.
    @test_throws ArgumentError build_lift_test_calibration_payload(
        channel = ["unknown"],
        x = [1.0],
        delta_x = [1.0],
        delta_y = [1.0],
        sigma = [0.1],
        channel_columns = channel_columns,
        channel_transform = channel_transform,
        target_transform = target_transform,
    )

    # Non-positive scaled sigma must be rejected.
    @test_throws ArgumentError build_lift_test_calibration_payload(
        channel = ["organic"],
        x = [1.0],
        delta_x = [1.0],
        delta_y = [1.0],
        sigma = [0.0],
        channel_columns = channel_columns,
        channel_transform = channel_transform,
        target_transform = target_transform,
    )

    # Direct struct validation: mismatched lengths, non-positive channel_index,
    # and non-finite/non-positive fields must all be rejected.
    @test_throws ArgumentError validate_lift_test_calibration_payload(
        LiftTestCalibrationPayload([1, 2], [1.0], [1.0, 1.0], [1.0, 1.0], [0.1, 0.1]),
    )
    @test_throws ArgumentError validate_lift_test_calibration_payload(
        LiftTestCalibrationPayload([0], [1.0], [1.0], [1.0], [0.1]),
    )
    @test_throws ArgumentError validate_lift_test_calibration_payload(
        LiftTestCalibrationPayload([1], [Inf], [1.0], [1.0], [0.1]),
    )
    @test_throws ArgumentError validate_lift_test_calibration_payload(
        LiftTestCalibrationPayload([1], [1.0], [1.0], [1.0], [-0.1]),
    )
    @test_throws ArgumentError validate_lift_test_calibration_payload(
        LiftTestCalibrationPayload(Int[], Float64[], Float64[], Float64[], Float64[]),
    )
end

@testset "CostPerTargetCalibrationPayload construction and validation" begin
    target_scale = 4.0
    transform = matrix -> matrix ./ target_scale

    payload = build_cost_per_target_calibration_payload(
        gathered_cpt = [1.0, 2.0],
        targets = [1.5, 1.8],
        sigma = [0.2, 0.4],
        transform = transform,
    )

    @test payload isa CostPerTargetCalibrationPayload
    @test payload.gathered_cpt ≈ [1.0, 2.0] ./ target_scale
    @test payload.targets ≈ [1.5, 1.8] ./ target_scale
    @test payload.sigma ≈ [0.2, 0.4] ./ target_scale
    @test validate_cost_per_target_calibration_payload(payload) === nothing
    @test payload == CostPerTargetCalibrationPayload(
        payload.gathered_cpt,
        payload.targets,
        payload.sigma,
    )

    @test_throws ArgumentError build_cost_per_target_calibration_payload(
        gathered_cpt = [1.0, 2.0],
        targets = [1.5],
        sigma = [0.2, 0.4],
        transform = transform,
    )
    @test_throws ArgumentError build_cost_per_target_calibration_payload(
        gathered_cpt = [1.0],
        targets = [1.5],
        sigma = [0.0],
        transform = transform,
    )

    @test_throws ArgumentError validate_cost_per_target_calibration_payload(
        CostPerTargetCalibrationPayload([1.0, 2.0], [1.0], [0.1, 0.1]),
    )
    @test_throws ArgumentError validate_cost_per_target_calibration_payload(
        CostPerTargetCalibrationPayload([Inf], [1.0], [0.1]),
    )
    @test_throws ArgumentError validate_cost_per_target_calibration_payload(
        CostPerTargetCalibrationPayload([1.0], [1.0], [-0.1]),
    )
    @test_throws ArgumentError validate_cost_per_target_calibration_payload(
        CostPerTargetCalibrationPayload(Float64[], Float64[], Float64[]),
    )
end

@testset "calibration integration fixture payloads and log density" begin
    for case in ABACUS_CALIBRATION_INTEGRATION_CASES
        channel_transform = matrix -> matrix ./ reshape(case.channel_scale, 1, :)
        target_transform = matrix -> matrix ./ case.target_scale

        lift_payload = build_lift_test_calibration_payload(
            channel = case.lift.channel,
            x = case.lift.x,
            delta_x = case.lift.delta_x,
            delta_y = case.lift.delta_y,
            sigma = case.lift.sigma,
            channel_columns = case.channel_columns,
            channel_transform = channel_transform,
            target_transform = target_transform,
        )
        @test lift_payload.channel_index == case.expected_lift_payload.channel_index
        @test lift_payload.x ≈ case.expected_lift_payload.x
        @test lift_payload.delta_x ≈ case.expected_lift_payload.delta_x
        @test lift_payload.delta_y ≈ case.expected_lift_payload.delta_y
        @test lift_payload.sigma ≈ case.expected_lift_payload.sigma

        lift_log_density = lift_test_payload_log_density(
            (x_row, lam_row) -> centered_logistic_saturation.(x_row, lam_row),
            lift_payload,
            case.lam,
        )
        @test lift_log_density ≈ case.expected_lift_log_density atol = 1.0e-8

        cost_payload = build_cost_per_target_calibration_payload(
            gathered_cpt = case.cost_per_target.gathered_cpt,
            targets = case.cost_per_target.targets,
            sigma = case.cost_per_target.sigma,
            transform = target_transform,
        )
        @test cost_payload.gathered_cpt ≈ case.expected_cost_per_target_payload.gathered_cpt
        @test cost_payload.targets ≈ case.expected_cost_per_target_payload.targets
        @test cost_payload.sigma ≈ case.expected_cost_per_target_payload.sigma

        cost_log_density = cost_per_target_total_penalty(
            cost_payload.gathered_cpt,
            cost_payload.targets,
            cost_payload.sigma,
        )
        @test cost_log_density ≈ case.expected_cost_per_target_log_density atol = 1.0e-8
        @test lift_log_density + cost_log_density ≈ case.expected_total_log_density atol = 1.0e-8
    end
end
