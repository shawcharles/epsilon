using Epsilon
using Test

@testset "MaxAbsScaler" begin
    @testset "vector scaling" begin
        scaler = MaxAbsScaler()
        data = [1.0, -2.0, 4.0]
        scaled = fit_transform!(scaler, data)
        @test scaled ≈ [0.25, -0.5, 1.0] atol = 1.0e-12 rtol = 1.0e-12
        @test Epsilon.inverse_transform(scaler, scaled) ≈ data atol = 1.0e-12 rtol = 1.0e-12
    end

    @testset "matrix scaling" begin
        scaler = MaxAbsScaler()
        data = [1.0 2.0 0.0; 4.0 -1.0 0.0]
        scaled = fit_transform!(scaler, data)
        @test scaled ≈ [0.25 1.0 0.0; 1.0 -0.5 0.0] atol = 1.0e-12 rtol = 1.0e-12
        @test Epsilon.inverse_transform(scaler, scaled) ≈ data atol = 1.0e-12 rtol = 1.0e-12
    end

    @testset "fitted requirement" begin
        @test_throws ArgumentError Epsilon.transform(MaxAbsScaler(), [1.0, 2.0])
    end

    @testset "shape validation" begin
        vector_scaler = MaxAbsScaler()
        fit!(vector_scaler, [1.0, 2.0, 3.0])
        @test_throws ArgumentError Epsilon.transform(vector_scaler, [1.0 2.0; 3.0 4.0])
        @test_throws ArgumentError Epsilon.inverse_transform(
            vector_scaler,
            [1.0 2.0; 3.0 4.0],
        )

        matrix_scaler = MaxAbsScaler()
        fit!(matrix_scaler, [1.0 2.0; 3.0 4.0])
        @test_throws ArgumentError Epsilon.transform(matrix_scaler, [1.0, 2.0])
        @test_throws ArgumentError Epsilon.transform(
            matrix_scaler,
            [1.0 2.0 3.0; 4.0 5.0 6.0],
        )
        @test_throws ArgumentError Epsilon.inverse_transform(matrix_scaler, [1.0, 2.0])
    end
end

@testset "StandardScaler" begin
    @testset "vector scaling" begin
        scaler = StandardScaler()
        data = [1.0, 2.0, 3.0, 4.0]
        scaled = fit_transform!(scaler, data)
        @test isapprox(sum(scaled) / length(scaled), 0.0; atol = 1.0e-12)
        @test isapprox(sqrt(sum(scaled .^ 2) / length(scaled)), 1.0; atol = 1.0e-12)
        @test Epsilon.inverse_transform(scaler, scaled) ≈ data atol = 1.0e-12 rtol = 1.0e-12
    end

    @testset "shape validation" begin
        vector_scaler = StandardScaler()
        fit!(vector_scaler, [1.0, 2.0, 3.0, 4.0])
        @test_throws ArgumentError Epsilon.transform(vector_scaler, [1.0 2.0; 3.0 4.0])
        @test_throws ArgumentError Epsilon.inverse_transform(
            vector_scaler,
            [1.0 2.0; 3.0 4.0],
        )

        matrix_scaler = StandardScaler()
        fit!(matrix_scaler, [1.0 2.0; 3.0 4.0])
        @test_throws ArgumentError Epsilon.transform(matrix_scaler, [1.0, 2.0])
        @test_throws ArgumentError Epsilon.transform(
            matrix_scaler,
            [1.0 2.0 3.0; 4.0 5.0 6.0],
        )
        @test_throws ArgumentError Epsilon.inverse_transform(matrix_scaler, [1.0, 2.0])
    end
end

@testset "wrapper helpers" begin
    @testset "target scaling" begin
        wrapper = MaxAbsScaleTarget()
        scaled = max_abs_scale_target_data(wrapper, [2.0, 4.0, 8.0])
        @test scaled ≈ [0.25, 0.5, 1.0] atol = 1.0e-12 rtol = 1.0e-12
        @test wrapper.target_transformer.scale == [8.0]
    end

    @testset "channel scaling" begin
        wrapper = MaxAbsScaleChannels([1, 3])
        data = [1.0 10.0 5.0; 2.0 20.0 10.0]
        scaled = max_abs_scale_channel_data(wrapper, data)
        @test scaled ≈ [0.5 10.0 0.5; 1.0 20.0 1.0] atol = 1.0e-12 rtol = 1.0e-12
    end

    @testset "control scaling" begin
        wrapper = StandardizeControls([2, 3])
        data = [1.0 10.0 5.0; 2.0 20.0 7.0; 3.0 30.0 9.0]
        scaled = standardize_control_data(wrapper, data)
        @test scaled[:, 1] == data[:, 1]
        @test isapprox(sum(scaled[:, 2]) / size(scaled, 1), 0.0; atol = 1.0e-12)
        @test isapprox(sum(scaled[:, 3]) / size(scaled, 1), 0.0; atol = 1.0e-12)
    end

    @testset "channel normalization" begin
        data = [1.0 2.0; 2.0 4.0]
        scaled, wrapper = normalize_channel_columns(data, [1, 2])
        @test scaled ≈ [0.5 0.5; 1.0 1.0] atol = 1.0e-12 rtol = 1.0e-12
        @test wrapper.channel_transformer.scale == [2.0, 4.0]
    end
end

@testset "validation utilities" begin
    @test validate_target_data([1.0, 2.0]) === nothing
    @test_throws ArgumentError validate_target_data(Float64[])

    @test validate_column_indices(3, [1, 2], "channel_columns") === nothing
    @test_throws ArgumentError validate_column_indices(3, Int[], "channel_columns")
    @test_throws ArgumentError validate_column_indices(3, [1, 1], "channel_columns")
    @test_throws ArgumentError validate_column_indices(3, [1, 4], "channel_columns")
    @test_throws ArgumentError validate_column_indices(3, [1.5], "channel_columns")
    @test_throws ArgumentError MaxAbsScaleChannels([1.5])
    @test_throws ArgumentError StandardizeControls([1.5])
    @test_throws ArgumentError validate_channel_values([1.0 2.0; 3.0 4.0], [3])

    @test_logs (:warn, "channel_columns contain negative values") validate_channel_values(
        [-1.0 2.0; 3.0 4.0],
        [1],
    )
end
