using Distributions
using Epsilon
using Test

include(joinpath(@__DIR__, "..", "fixtures", "abacus", "calibration_alignment_cases.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "abacus", "calibration_unaligned_cases.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "abacus", "calibration_monotonic_cases.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "abacus", "calibration_channel_scaling_cases.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "abacus", "calibration_target_scaling_cases.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "abacus", "calibration_combined_scaling_cases.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "abacus", "lift_test_likelihood_cases.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "abacus", "cost_per_target_cases.jl"))

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
