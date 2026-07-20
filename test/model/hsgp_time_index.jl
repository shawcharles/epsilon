using Dates
using Epsilon
using Test

include("../fixtures/golden/hsgp_time_index_cases.jl")

@testset "HSGP time-index golden fixture" begin
    for case in GOLDEN_HSGP_TIME_INDEX_CASES
        @testset "$(case.name)" begin
            if isnothing(case.expected_error)
                actual = Epsilon._infer_hsgp_time_index(
                    case.new_dates,
                    case.training_dates;
                    time_resolution = case.time_resolution,
                )
                @test actual isa Vector{Int}
                @test actual == case.expected
            else
                @test occursin("align to the fitted cadence", case.expected_error)
                @test_throws ArgumentError Epsilon._infer_hsgp_time_index(
                    case.new_dates,
                    case.training_dates;
                    time_resolution = case.time_resolution,
                )
            end
        end
    end
end

@testset "HSGP time-index Epsilon contracts" begin
    training_dates = Date[Date(2024, 1, 15), Date(2024, 1, 1), Date(2024, 1, 15)]
    @test Epsilon._infer_hsgp_time_index(
        Date[Date(2024, 1, 15), Date(2024, 1, 8), Date(2024, 1, 22)],
        training_dates;
        time_resolution = 7,
    ) == Int[0, -1, 1]
    @test Epsilon._infer_hsgp_time_index(Date[], training_dates; time_resolution = 7) == Int[]

    @test_throws ArgumentError Epsilon._infer_hsgp_time_index(Date[], Date[]; time_resolution = 7)
    @test_throws ArgumentError Epsilon._infer_hsgp_time_index(Date[Date(2024, 1, 15)], training_dates; time_resolution = 0)
    @test_throws ArgumentError Epsilon._infer_hsgp_time_index(Date[Date(2024, 1, 15)], training_dates; time_resolution = -7)
    @test Epsilon._infer_hsgp_time_index(
        Date[Date(2024, 1, 22)], training_dates; time_resolution = Int32(7)
    ) == Int[1]

    @test isdefined(Epsilon, :_infer_hsgp_time_index)
    @test !(:_infer_hsgp_time_index in names(Epsilon; all = false, imported = false))
    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        seasonality = Dict("type" => "hsgp", "m" => 10),
    )
end
