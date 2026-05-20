using Dates
using Epsilon
using Test

function _scenario_test_result(; target_type = "revenue")
    channels = ["tv", "search"]
    coordinates = Dict("date" => ["2024-01-01"], "channel" => channels)
    coordinate_metadata = ModelCoordinateMetadata(
        "date",
        (),
        coordinates,
        Dict{String, Tuple{Vararg{String}}}(),
    )
    spec = MMMModelSpec(
        :time_series_mmm,
        1,
        length(channels),
        0,
        (),
        coordinate_metadata,
        "sales",
        target_type,
        channels,
        String[],
        Dict(channel => index for (index, channel) in enumerate(channels)),
        Dict{String, Int}(),
        ones(length(channels)),
        1.0,
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
    )
    metadata = ModelArtifactMetadata(
        1,
        epsilon_version(),
        VERSION,
        "2026-05-19T00:00:00Z",
        "TimeSeriesMMM",
        :mcmc,
        :success,
    )
    audit = Epsilon.BudgetConstraintAudit(
        150.0,
        channels,
        String[],
        Epsilon.BudgetChannelConstraint[
            Epsilon.BudgetChannelConstraint("tv", 100.0, nothing, nothing, nothing, nothing, 0.0, nothing),
            Epsilon.BudgetChannelConstraint("search", 50.0, nothing, nothing, nothing, nothing, 0.0, nothing),
        ],
    )
    return BudgetOptimizationResult(
        metadata,
        spec,
        coordinate_metadata,
        :total_response,
        channels,
        String[],
        Dict("tv" => 100.0, "search" => 50.0),
        Dict("tv" => 120.0, "search" => 30.0),
        80.0,
        92.0,
        80.0 / 150.0,
        92.0 / 150.0,
        :locally_solved,
        92.0,
        Dict{String, Any}("termination_status" => "LOCALLY_SOLVED"),
        audit,
    )
end

@testset "scenario planner specs validate bounded Abacus-like semantics" begin
    current = CurrentScenarioSpec(name = "Status Quo FY24", start_date = "2024-01-01", end_date = Date(2024, 1, 31))
    @test current.scenario_id == "status-quo-fy24"
    @test current.start_date == Date(2024, 1, 1)
    @test current.end_date == Date(2024, 1, 31)

    data_array = ScenarioDataArraySpec(
        [10.0, 20.0];
        dims = ["channel"],
        coords = Dict("channel" => ["tv", "search"]),
    )
    manual = ManualAllocationScenarioSpec(name = "Manual Mix", allocation = data_array)
    @test manual.scenario_id == "manual-mix"
    @test manual.allocation == Dict("tv" => 10.0, "search" => 20.0)

    optimized = FixedBudgetOptimizedScenarioSpec(name = "Optimized Mix", total_budget = 30.0)
    @test optimized.scenario_id == "optimized-mix"
    @test optimized.response_variable == "total_media_contribution_original_scale"

    @test_throws ArgumentError CurrentScenarioSpec(name = "bad", start_date = "2024-02-01", end_date = "2024-01-01")
    @test_throws ArgumentError ScenarioDataArraySpec([1.0 2.0]; dims = ["channel"], coords = Dict("channel" => ["tv"]))
    @test_throws ArgumentError ManualAllocationScenarioSpec(name = "bad", allocation = Dict("tv" => -1.0))
    @test_throws ArgumentError FixedBudgetOptimizedScenarioSpec(name = "bad", total_budget = 0.0)
end

@testset "scenario_plan projects optimizer results into comparison tables" begin
    result = _scenario_test_result()
    current = CurrentScenarioSpec(name = "Current Plan", start_date = "2024-01-01", end_date = "2024-01-31")
    optimized = FixedBudgetOptimizedScenarioSpec(
        name = "Optimized Plan",
        start_date = "2024-01-01",
        end_date = "2024-01-31",
        total_budget = 150.0,
    )

    plan = scenario_plan(result; current_scenario = current, optimized_scenario = optimized)
    @test plan isa ScenarioPlanResult
    @test names(plan.totals) == [
        "scenario_id",
        "scenario_name",
        "scenario_type",
        "total_spend",
        "expected_response",
        "response_delta_vs_baseline",
        "spend_delta_vs_baseline",
        "default_efficiency_metric",
        "default_efficiency",
        "default_efficiency_delta_vs_baseline",
        "objective",
    ]
    @test plan.totals.scenario_id == ["current-plan", "optimized-plan"]
    @test plan.totals.expected_response == [80.0, 92.0]
    @test plan.totals.response_delta_vs_baseline == [0.0, 12.0]
    @test plan.totals.default_efficiency_metric == ["roas", "roas"]

    @test size(plan.channels, 1) == 4
    @test plan.channels.channel == ["tv", "tv", "search", "search"]
    @test all(ismissing, plan.channels.expected_response)

    @test names(plan.allocations) == [
        "baseline_scenario_id",
        "optimized_scenario_id",
        "channel",
        "optimized",
        "current_spend",
        "optimized_spend",
        "spend_delta",
        "current_share",
        "optimized_share",
        "optimized_vs_current_pct",
    ]
    @test plan.allocations.spend_delta == [20.0, -20.0]
    @test plan.metadata.solver_status == ["", "locally_solved"]
    @test isempty(plan.channel_panel_allocations)
end

@testset "scenario_plan labels conversion efficiency as CPA" begin
    result = _scenario_test_result(; target_type = "conversion")
    plan = scenario_plan(result)
    @test plan.totals.default_efficiency_metric == ["cpa", "cpa"]
    @test plan.channels.default_efficiency_metric == fill("cpa", 4)
end
