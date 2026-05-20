using Dates
using Epsilon
using Test

@testset "linear trend features" begin
    numeric_features = Epsilon._trend_features(Dict{String, Any}("type" => "linear"), [10.0, 20.0, 30.0])
    @test size(numeric_features) == (3, 1)
    @test numeric_features[:, 1] ≈ [0.0, 0.5, 1.0]

    date_features = Epsilon._trend_features(
        Dict{String, Any}("type" => "linear"),
        Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
    )
    @test size(date_features) == (6, 1)
    @test date_features[:, 1] ≈ collect(range(0.0, 1.0; length = 6))

    @test Epsilon._trend_features(Dict{String, Any}(), 1:3) == zeros(Float64, 3, 0)
    @test_throws ArgumentError Epsilon._trend_features(Dict{String, Any}("type" => "linear"), ["bad", "dates"])
end

@testset "fitted trend state replays the training date basis" begin
    fitted_dates = Date(2024, 1, 1):Day(7):Date(2024, 1, 15)
    holdout_dates = Date(2024, 1, 22):Day(7):Date(2024, 1, 29)

    linear_config = Epsilon._trend_spec_config(Dict{String, Any}("type" => "linear"), fitted_dates)
    @test Epsilon._trend_features(linear_config, holdout_dates)[:, 1] ≈ [1.5, 2.0]
    @test Epsilon._trend_features(Dict{String, Any}("type" => "linear"), holdout_dates)[:, 1] ≈ [0.0, 1.0]

    changepoint_config = Epsilon._trend_spec_config(
        Dict{String, Any}("type" => "changepoint", "n_changepoints" => 2),
        fitted_dates,
    )
    changepoint_holdout = Epsilon._trend_features(changepoint_config, [Date(2024, 1, 22)])
    @test changepoint_holdout[1, 1] ≈ 1.5
    @test changepoint_holdout[1, 2] ≈ 1.0
end

@testset "changepoint trend features" begin
    features = Epsilon._trend_features(
        Dict{String, Any}("type" => "changepoint", "n_changepoints" => 3),
        [10.0, 20.0, 30.0],
    )
    @test size(features) == (3, 3)
    @test features ≈ [
        0.0 0.0 0.0
        0.5 1 / 6 0.0
        1.0 2 / 3 1 / 3
    ]

    date_features = Epsilon._trend_features(
        Dict{String, Any}("type" => "changepoint", "n_changepoints" => 3),
        Date(2024, 1, 1):Day(7):Date(2024, 1, 22),
    )
    @test size(date_features) == (4, 3)
    @test date_features[:, 1] ≈ collect(range(0.0, 1.0; length = 4))
    @test date_features[:, 2] ≈ [0.0, 0.0, 1 / 3, 2 / 3]
    @test date_features[:, 3] ≈ [0.0, 0.0, 0.0, 1 / 3]
end

@testset "trend config validation" begin
    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        trend = Dict("type" => "quadratic"),
    )

    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        trend = Dict("type" => "changepoint"),
    )

    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        trend = Dict("type" => "changepoint", "n_changepoints" => 0),
    )

    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        trend = Dict("type" => "changepoint", "n_changepoints" => 4, "include_intercept" => true),
    )

    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        trend = Dict("type" => "changepoint", "n_changepoints" => 4, "include_intercept" => false),
    )

    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        trend = Dict("type" => "linear", "include_intercept" => true),
    )

    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        trend = Dict("type" => "linear", "__epsilon_state" => Dict("origin" => 1, "scale" => 1.0)),
    )
end
