using Dates
using Epsilon
using Test

@testset "events config validation" begin
    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        events = Dict("columns" => []),
    )

    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        events = Dict("columns" => ["launch", "launch"]),
    )

    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        events = Dict(
            "columns" => ["launch"],
            "windows" => [Dict("name" => "holiday", "start_date" => "2024-01-01")],
        ),
    )

    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        events = Dict(
            "windows" => [Dict("name" => "holiday", "start_date" => "2024-01-03", "end_date" => "2024-01-01")],
        ),
    )
end

@testset "generated event windows" begin
    config = Dict{String, Any}(
        "windows" => [
            Dict("name" => "promo", "start_date" => "2024-01-08", "end_date" => "2024-01-15"),
            Dict("name" => "holiday", "start_date" => "2024-01-29"),
        ],
    )
    data = MMMData(
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
        target = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
        channels = [1.0; 2.0; 3.0; 4.0; 5.0; 6.0][:, :],
        channel_names = ["tv"],
    )

    @test Epsilon._events_columns(config) == ["promo", "holiday"]
    matrix = Epsilon._event_design_matrix(config, data)
    @test size(matrix) == (6, 2)
    @test matrix[:, 1] == [0.0, 1.0, 1.0, 0.0, 0.0, 0.0]
    @test matrix[:, 2] == [0.0, 0.0, 0.0, 0.0, 1.0, 0.0]

    numeric_data = MMMData(
        dates = 1:6,
        target = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
        channels = [1.0; 2.0; 3.0; 4.0; 5.0; 6.0][:, :],
        channel_names = ["tv"],
    )
    @test_throws ArgumentError Epsilon._event_design_matrix(config, numeric_data)

    time_data = MMMData(
        dates = [Time(1), Time(2), Time(3), Time(4), Time(5), Time(6)],
        target = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
        channels = [1.0; 2.0; 3.0; 4.0; 5.0; 6.0][:, :],
        channel_names = ["tv"],
    )
    @test_throws ArgumentError Epsilon._event_design_matrix(config, time_data)
end
