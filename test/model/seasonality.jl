using Dates
using Epsilon
using Test

@testset "fourier_features" begin
    dayofperiod = [0.0, 91.3125]
    features = fourier_features(dayofperiod, 365.25, 2)

    @test size(features) == (2, 4)
    @test features[:, 1] ≈ sin.(2π .* dayofperiod ./ 365.25)
    @test features[:, 2] ≈ sin.(4π .* dayofperiod ./ 365.25)
    @test features[:, 3] ≈ cos.(2π .* dayofperiod ./ 365.25)
    @test features[:, 4] ≈ cos.(4π .* dayofperiod ./ 365.25)
    @test_throws ArgumentError fourier_features(dayofperiod, 0.0, 2)
    @test_throws ArgumentError fourier_features(dayofperiod, 365.25, 0)
end

@testset "seasonality config validation" begin
    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        seasonality = Dict("type" => "fourier"),
    )

    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        seasonality = Dict("type" => "hsgp", "m" => 10),
    )

    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        seasonality = Dict("type" => "fourier", "n_order" => 2, "priors" => Any[]),
    )
end

@testset "seasonality date validation" begin
    @test_throws ArgumentError Epsilon._seasonality_features(
        Dict{String, Any}("type" => "fourier", "n_order" => 2),
        [Time(1), Time(2)],
    )
end
