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

function _manual_scenario_problem(; optimized_channels = ["tv", "search"], total_budget = 150.0, target_type = "revenue")
    shell = _scenario_test_result(; target_type)
    fixed_channels = [channel for channel in shell.spec.channel_columns if !(channel in Set(optimized_channels))]
    current_spend = Dict("tv" => 100.0, "search" => 50.0)
    surfaces = Dict(
        "tv" => Epsilon.BudgetChannelSurface(
            "tv",
            100.0,
            [0.0, 200.0],
            [0.0, 100.0],
            0.0,
            200.0,
        ),
        "search" => Epsilon.BudgetChannelSurface(
            "search",
            50.0,
            [0.0, 100.0],
            [0.0, 60.0],
            0.0,
            100.0,
        ),
    )
    current_response_by_channel = Dict("tv" => 50.0, "search" => 30.0)
    optimized_surfaces = [surfaces[channel] for channel in optimized_channels]
    optimized_current_spend = [current_spend[channel] for channel in optimized_channels]
    fixed_spend = [current_spend[channel] for channel in fixed_channels]
    fixed_response = sum(current_response_by_channel[channel] for channel in fixed_channels; init = 0.0)
    baseline_response = 20.0
    optimized_current_response = sum(current_response_by_channel[channel] for channel in optimized_channels; init = 0.0)
    return Epsilon.BudgetOptimizationProblem(
        shell.metadata,
        shell.spec,
        shell.coordinate_metadata,
        :total_response,
        total_budget,
        optimized_channels,
        fixed_channels,
        optimized_current_spend,
        fixed_spend,
        baseline_response,
        fixed_response,
        baseline_response + fixed_response + optimized_current_response,
        optimized_surfaces,
        Epsilon.BudgetConstraintAudit(
            total_budget,
            optimized_channels,
            fixed_channels,
            Epsilon.BudgetChannelConstraint[
                Epsilon.BudgetChannelConstraint(channel, current_spend[channel], nothing, nothing, nothing, nothing, 0.0, surfaces[channel].effective_upper)
                    for channel in optimized_channels
            ],
        ),
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

@testset "manual scenario evaluation reuses bounded response surfaces" begin
    problem = _manual_scenario_problem()
    scenario = ManualAllocationScenarioSpec(
        name = "Manual Mix",
        allocation = Dict("tv" => 120.0, "search" => 30.0),
    )

    evaluation = Epsilon._evaluate_manual_scenario(problem, scenario)
    @test evaluation isa ManualScenarioEvaluationResult
    @test evaluation.scenario.scenario_id == "manual-mix"
    @test evaluation.current_spend == Dict("tv" => 100.0, "search" => 50.0)
    @test evaluation.manual_spend == Dict("tv" => 120.0, "search" => 30.0)
    @test evaluation.current_response == 100.0
    @test evaluation.manual_response == 98.0
    @test evaluation.manual_response - evaluation.current_response == -2.0
    @test evaluation.current_default_efficiency == 100.0 / 150.0
    @test evaluation.manual_default_efficiency == 98.0 / 150.0
end

@testset "manual scenario evaluation holds omitted channels fixed" begin
    problem = _manual_scenario_problem(; optimized_channels = ["tv"], total_budget = 120.0)
    scenario = ManualAllocationScenarioSpec(
        name = "TV Upweight",
        allocation = Dict("tv" => 120.0),
    )

    evaluation = Epsilon._evaluate_manual_scenario(problem, scenario)
    @test evaluation.current_spend == Dict("tv" => 100.0, "search" => 50.0)
    @test evaluation.manual_spend == Dict("tv" => 120.0, "search" => 50.0)
    @test evaluation.current_response == 100.0
    @test evaluation.manual_response == 110.0
    @test evaluation.manual_default_efficiency == 110.0 / 170.0
end

@testset "manual scenario evaluation fails closed on invalid contracts" begin
    problem = _manual_scenario_problem(; total_budget = 280.0)
    invalid_channel = ManualAllocationScenarioSpec(
        name = "Unknown",
        allocation = Dict("podcast" => 10.0),
    )
    zero_total = ManualAllocationScenarioSpec(
        name = "Zero",
        allocation = Dict("tv" => 0.0),
    )
    out_of_domain = ManualAllocationScenarioSpec(
        name = "Too High",
        allocation = Dict("tv" => 250.0, "search" => 30.0),
    )

    @test_throws ArgumentError Epsilon._manual_evaluation_channels(problem.spec, invalid_channel)
    @test_throws ArgumentError Epsilon._manual_evaluation_total_budget(zero_total)
    @test_throws ArgumentError Epsilon._evaluate_manual_scenario(problem, out_of_domain)
end

@testset "scenario_plan projects manual evaluations into comparison tables" begin
    full_problem = _manual_scenario_problem()
    full_scenario = ManualAllocationScenarioSpec(
        name = "Manual Mix",
        allocation = Dict("tv" => 120.0, "search" => 30.0),
        start_date = "2024-01-01",
        end_date = "2024-01-31",
    )
    subset_problem = _manual_scenario_problem(; optimized_channels = ["tv"], total_budget = 120.0)
    subset_scenario = ManualAllocationScenarioSpec(
        name = "TV Upweight",
        allocation = Dict("tv" => 120.0),
        start_date = "2024-01-01",
        end_date = "2024-01-31",
    )
    full_evaluation = Epsilon._evaluate_manual_scenario(full_problem, full_scenario)
    subset_evaluation = Epsilon._evaluate_manual_scenario(subset_problem, subset_scenario)
    current = CurrentScenarioSpec(
        name = "Current Plan",
        start_date = "2024-01-01",
        end_date = "2024-01-31",
    )

    plan = scenario_plan([full_evaluation, subset_evaluation]; current_scenario = current)
    @test plan isa ScenarioPlanResult
    @test isempty(plan.channel_panel_allocations)

    @test plan.totals.scenario_id == ["current-plan", "manual-mix", "tv-upweight"]
    @test plan.totals.scenario_type == ["current", "manual_allocation", "manual_allocation"]
    @test plan.totals.total_spend == [150.0, 150.0, 170.0]
    @test plan.totals.expected_response == [100.0, 98.0, 110.0]
    @test plan.totals.response_delta_vs_baseline == [0.0, -2.0, 10.0]
    @test plan.totals.spend_delta_vs_baseline == [0.0, 0.0, 20.0]

    @test names(plan.channels) == [
        "scenario_id",
        "scenario_name",
        "scenario_type",
        "channel",
        "spend",
        "spend_share",
        "expected_response",
        "default_efficiency_metric",
    ]
    @test size(plan.channels, 1) == 6
    @test plan.channels.scenario_type == [
        "current",
        "manual_allocation",
        "manual_allocation",
        "current",
        "manual_allocation",
        "manual_allocation",
    ]
    @test plan.channels.channel == ["tv", "tv", "tv", "search", "search", "search"]
    @test plan.channels.spend == [100.0, 120.0, 120.0, 50.0, 30.0, 50.0]

    @test names(plan.allocations) == [
        "baseline_scenario_id",
        "scenario_id",
        "scenario_type",
        "channel",
        "current_spend",
        "scenario_spend",
        "spend_delta",
        "current_share",
        "scenario_share",
        "scenario_vs_current_pct",
    ]
    @test size(plan.allocations, 1) == 4
    @test plan.allocations.scenario_id == ["manual-mix", "manual-mix", "tv-upweight", "tv-upweight"]
    @test plan.allocations.scenario_type == fill("manual_allocation", 4)
    @test plan.allocations.spend_delta == [20.0, -20.0, 20.0, 0.0]

    @test plan.metadata.scenario_id == ["current-plan", "manual-mix", "tv-upweight"]
    @test plan.metadata.scenario_type == ["current", "manual_allocation", "manual_allocation"]
    @test isnan(plan.metadata.requested_total_budget[1])
    @test plan.metadata.requested_total_budget[2:3] == [150.0, 170.0]
    @test plan.metadata.solver_status == ["", "", ""]
end

@testset "scenario_plan manual projection validates inputs" begin
    @test_throws ArgumentError scenario_plan(ManualScenarioEvaluationResult[])
end
