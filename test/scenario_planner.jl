using CSV
using DataFrames
using Dates
using Epsilon
using Serialization
using Test

function _scenario_test_result(; target_type = "revenue", channels = ["tv", "search"])
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

function _scenario_store_test_plan(
        result = _scenario_test_result();
        current = CurrentScenarioSpec(name = "Current Plan", start_date = "2024-01-01", end_date = "2024-01-31"),
    )
    optimized = FixedBudgetOptimizedScenarioSpec(
        name = "Optimized Plan",
        start_date = "2024-01-01",
        end_date = "2024-01-31",
        total_budget = 150.0,
    )
    return scenario_plan(result; current_scenario = current, optimized_scenario = optimized)
end

function _scenario_store_for(result = _scenario_test_result(); plan = _scenario_store_test_plan(result))
    return ScenarioStoreArtifact(
        plan;
        metadata = result.metadata,
        spec = result.spec,
        coordinate_metadata = result.coordinate_metadata,
    )
end

function _scenario_plan_copy(
        plan::ScenarioPlanResult;
        totals = plan.totals,
        channels = plan.channels,
        allocations = plan.allocations,
        metadata = plan.metadata,
        channel_panel_allocations = plan.channel_panel_allocations,
    )
    return ScenarioPlanResult(
        copy(totals; copycols = true),
        copy(channels; copycols = true),
        copy(allocations; copycols = true),
        copy(metadata; copycols = true),
        copy(channel_panel_allocations; copycols = true),
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

function _combined_scenario_test_result()
    problem = _manual_scenario_problem()
    current_spend = Dict("tv" => 100.0, "search" => 50.0)
    optimized_spend = Dict("tv" => 110.0, "search" => 40.0)
    return BudgetOptimizationResult(
        problem.metadata,
        problem.spec,
        problem.coordinate_metadata,
        problem.objective,
        problem.optimized_channels,
        problem.fixed_channels,
        current_spend,
        optimized_spend,
        problem.current_response,
        108.0,
        100.0 / 150.0,
        108.0 / 150.0,
        :locally_solved,
        108.0,
        Dict{String, Any}("termination_status" => "LOCALLY_SOLVED"),
        problem.constraint_audit,
    )
end

function _manual_evaluation_with(
        evaluation::ManualScenarioEvaluationResult;
        metadata = evaluation.metadata,
        spec = evaluation.spec,
        coordinate_metadata = evaluation.coordinate_metadata,
        scenario = evaluation.scenario,
        objective = evaluation.objective,
        current_spend = evaluation.current_spend,
        manual_spend = evaluation.manual_spend,
        current_response = evaluation.current_response,
        manual_response = evaluation.manual_response,
        current_default_efficiency = evaluation.current_default_efficiency,
        manual_default_efficiency = evaluation.manual_default_efficiency,
    )
    return ManualScenarioEvaluationResult(
        metadata,
        spec,
        coordinate_metadata,
        scenario,
        objective,
        current_spend,
        manual_spend,
        current_response,
        manual_response,
        current_default_efficiency,
        manual_default_efficiency,
    )
end

@testset "scenario planner specs validate bounded bounded semantics" begin
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
    @test Epsilon._normalized_full_allocation_mapping(
        _scenario_test_result().spec,
        manual.allocation,
        "evaluate_budget_allocation",
    ) == manual.allocation

    optimized = FixedBudgetOptimizedScenarioSpec(name = "Optimized Mix", total_budget = 30.0)
    @test optimized.scenario_id == "optimized-mix"
    @test optimized.response_variable == "total_media_contribution_original_scale"

    @test_throws ArgumentError CurrentScenarioSpec(name = "bad", start_date = "2024-02-01", end_date = "2024-01-01")
    @test_throws ArgumentError ScenarioDataArraySpec([1.0 2.0]; dims = ["channel"], coords = Dict("channel" => ["tv"]))
    @test_throws ArgumentError ManualAllocationScenarioSpec(name = "bad", allocation = Dict("tv" => -1.0))
    @test_throws ArgumentError Epsilon._normalized_full_allocation_mapping(
        _scenario_test_result().spec,
        Dict("tv" => 10.0),
        "evaluate_budget_allocation",
    )
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

@testset "scenario_plan combines manual evaluations with solved optimization" begin
    result = _combined_scenario_test_result()
    first_scenario = ManualAllocationScenarioSpec(
        name = "Manual Mix",
        allocation = Dict("tv" => 120.0, "search" => 30.0),
        start_date = "2024-01-01",
        end_date = "2024-01-31",
    )
    second_scenario = ManualAllocationScenarioSpec(
        name = "Search Hold",
        allocation = Dict("tv" => 100.0, "search" => 50.0),
        start_date = "2024-01-01",
        end_date = "2024-01-31",
    )
    first_evaluation = Epsilon._evaluate_manual_scenario(_manual_scenario_problem(), first_scenario)
    second_evaluation = Epsilon._evaluate_manual_scenario(_manual_scenario_problem(), second_scenario)
    current = CurrentScenarioSpec(
        name = "Current Plan",
        start_date = "2024-01-01",
        end_date = "2024-01-31",
    )
    optimized = FixedBudgetOptimizedScenarioSpec(
        name = "Optimized Plan",
        start_date = "2024-01-01",
        end_date = "2024-01-31",
        total_budget = 150.0,
    )

    plan = scenario_plan(result, [first_evaluation, second_evaluation]; current_scenario = current, optimized_scenario = optimized)
    single_plan = scenario_plan(result, first_evaluation; current_scenario = current, optimized_scenario = optimized)

    @test plan.totals.scenario_id == ["current-plan", "manual-mix", "search-hold", "optimized-plan"]
    @test plan.totals.scenario_type == ["current", "manual_allocation", "manual_allocation", "fixed_budget_optimized"]
    @test plan.totals.expected_response == [100.0, 98.0, 100.0, 108.0]
    @test plan.totals.response_delta_vs_baseline == [0.0, -2.0, 0.0, 8.0]
    @test single_plan.totals.scenario_id == ["current-plan", "manual-mix", "optimized-plan"]

    @test plan.channels.channel == ["tv", "tv", "tv", "tv", "search", "search", "search", "search"]
    @test plan.channels.scenario_type == [
        "current",
        "manual_allocation",
        "manual_allocation",
        "fixed_budget_optimized",
        "current",
        "manual_allocation",
        "manual_allocation",
        "fixed_budget_optimized",
    ]
    @test plan.channels.spend == [100.0, 120.0, 100.0, 110.0, 50.0, 30.0, 50.0, 40.0]

    @test size(plan.allocations, 1) == 6
    @test plan.allocations.scenario_id[1:4] == ["manual-mix", "manual-mix", "search-hold", "search-hold"]
    @test plan.allocations.optimized_scenario_id[5:6] == ["optimized-plan", "optimized-plan"]
    @test plan.metadata.scenario_id == ["current-plan", "manual-mix", "search-hold", "optimized-plan"]
    @test plan.metadata.solver_status == ["", "", "", "locally_solved"]
    @test isempty(plan.channel_panel_allocations)
end

@testset "scenario_plan rejects combined artifact mismatches" begin
    result = _combined_scenario_test_result()
    scenario = ManualAllocationScenarioSpec(
        name = "Manual Mix",
        allocation = Dict("tv" => 120.0, "search" => 30.0),
    )
    evaluation = Epsilon._evaluate_manual_scenario(_manual_scenario_problem(), scenario)
    different_metadata = ModelArtifactMetadata(
        1,
        epsilon_version(),
        VERSION,
        "2026-05-20T00:00:00Z",
        "TimeSeriesMMM",
        :mcmc,
        :success,
    )
    different_spec = _scenario_test_result(; target_type = "conversion").spec
    different_coordinates = ModelCoordinateMetadata(
        "date",
        (),
        Dict("date" => ["2024-01-01"], "channel" => ["search", "tv"]),
        Dict{String, Tuple{Vararg{String}}}(),
    )

    mismatches = [
        _manual_evaluation_with(evaluation; metadata = different_metadata),
        _manual_evaluation_with(evaluation; spec = different_spec),
        _manual_evaluation_with(evaluation; coordinate_metadata = different_coordinates),
        _manual_evaluation_with(evaluation; objective = :incremental_response),
        _manual_evaluation_with(evaluation; current_spend = Dict("tv" => 99.0, "search" => 50.0)),
        _manual_evaluation_with(evaluation; current_response = 99.0),
        _manual_evaluation_with(evaluation; current_default_efficiency = 0.5),
    ]

    for mismatched in mismatches
        @test_throws ArgumentError scenario_plan(result, mismatched)
    end
end

@testset "scenario store writes typed payload and inspection sidecars" begin
    result = _scenario_test_result()
    plan = _scenario_store_test_plan(result)

    mktempdir() do dir
        @test write_scenario_store(
            dir,
            plan;
            metadata = result.metadata,
            spec = result.spec,
            coordinate_metadata = result.coordinate_metadata,
        ) == dir

        @test isfile(joinpath(dir, "scenario_store.jls"))
        @test isfile(joinpath(dir, "totals.csv"))
        @test isfile(joinpath(dir, "channels.csv"))
        @test isfile(joinpath(dir, "allocations.csv"))
        @test isfile(joinpath(dir, "metadata.csv"))
        @test !isfile(joinpath(dir, "channel_panel_allocations.csv"))
        @test nrow(DataFrame(CSV.File(joinpath(dir, "totals.csv")))) == nrow(plan.totals)

        loaded = load_scenario_store(dir)
        @test loaded isa ScenarioStoreArtifact
        loaded_plan = scenario_store_plan(loaded)
        @test isequal(loaded_plan.totals, plan.totals)
        @test isequal(loaded_plan.channels, plan.channels)
        @test isequal(loaded_plan.allocations, plan.allocations)
        @test isequal(loaded_plan.metadata, plan.metadata)
        @test isempty(loaded_plan.channel_panel_allocations)

        write(joinpath(dir, "channel_panel_allocations.csv"), "stale\n")
        @test isfile(joinpath(dir, "channel_panel_allocations.csv"))
        write_scenario_store(
            dir,
            plan;
            metadata = result.metadata,
            spec = result.spec,
            coordinate_metadata = result.coordinate_metadata,
        )
        @test !isfile(joinpath(dir, "channel_panel_allocations.csv"))

        panel_plan = _scenario_plan_copy(
            plan;
            channel_panel_allocations = DataFrame(
                baseline_scenario_id = ["current-plan", "current-plan"],
                optimized_scenario_id = ["optimized-plan", "optimized-plan"],
                channel = ["tv", "search"],
                panel_cell = ["north", "north"],
                current_spend = [60.0, 40.0],
                optimized_spend = [70.0, 30.0],
                spend_delta = [10.0, -10.0],
            ),
        )
        write_scenario_store(
            dir,
            panel_plan;
            metadata = result.metadata,
            spec = result.spec,
            coordinate_metadata = result.coordinate_metadata,
        )
        @test isfile(joinpath(dir, "channel_panel_allocations.csv"))
        panel_loaded = load_scenario_store(dir)
        @test nrow(scenario_store_plan(panel_loaded).channel_panel_allocations) == 2
    end
end

@testset "scenario store accepts manual and combined scenario plan variants" begin
    current = CurrentScenarioSpec(name = "Current Plan", start_date = "2024-01-01", end_date = "2024-01-31")
    manual_scenario = ManualAllocationScenarioSpec(
        name = "Manual Mix",
        allocation = Dict("tv" => 120.0, "search" => 30.0),
        start_date = "2024-01-01",
        end_date = "2024-01-31",
    )
    manual_evaluation = Epsilon._evaluate_manual_scenario(_manual_scenario_problem(), manual_scenario)
    manual_plan = scenario_plan(manual_evaluation; current_scenario = current)
    manual_store = ScenarioStoreArtifact(
        manual_plan;
        metadata = manual_evaluation.metadata,
        spec = manual_evaluation.spec,
        coordinate_metadata = manual_evaluation.coordinate_metadata,
    )
    @test scenario_store_plan(manual_store).totals.scenario_type == ["current", "manual_allocation"]

    result = _combined_scenario_test_result()
    optimized = FixedBudgetOptimizedScenarioSpec(
        name = "Optimized Plan",
        start_date = "2024-01-01",
        end_date = "2024-01-31",
        total_budget = 150.0,
    )
    combined_plan = scenario_plan(result, manual_evaluation; current_scenario = current, optimized_scenario = optimized)
    combined_store = ScenarioStoreArtifact(
        combined_plan;
        metadata = result.metadata,
        spec = result.spec,
        coordinate_metadata = result.coordinate_metadata,
    )
    @test scenario_store_plan(combined_store).totals.scenario_type == [
        "current",
        "manual_allocation",
        "fixed_budget_optimized",
    ]
end

@testset "scenario store copies plan tables on construction and projection" begin
    result = _scenario_test_result()
    plan = _scenario_store_test_plan(result)
    store = _scenario_store_for(result; plan)

    plan.totals.expected_response[1] = -1.0
    @test store.totals.expected_response[1] == 80.0

    projected = scenario_store_plan(store)
    projected.totals.expected_response[1] = -2.0
    projected.channels.spend[1] = -3.0
    @test store.totals.expected_response[1] == 80.0
    @test store.channels.spend[1] == 100.0
end

@testset "scenario store rejects malformed plans" begin
    result = _scenario_test_result()
    plan = _scenario_store_test_plan(result)

    missing_current = _scenario_plan_copy(plan)
    missing_current.totals.scenario_type[1] = "baseline"
    @test_throws ArgumentError _scenario_store_for(result; plan = missing_current)

    repeated_current_totals = vcat(plan.totals, plan.totals[1:1, :])
    repeated_current = _scenario_plan_copy(plan; totals = repeated_current_totals)
    @test_throws ArgumentError _scenario_store_for(result; plan = repeated_current)

    inconsistent_objective = _scenario_plan_copy(plan)
    inconsistent_objective.metadata.objective[2] = "incremental_response"
    @test_throws ArgumentError _scenario_store_for(result; plan = inconsistent_objective)

    bad_channel_order = _scenario_plan_copy(plan; channels = plan.channels[[3, 4, 1, 2], :])
    @test_throws ArgumentError _scenario_store_for(result; plan = bad_channel_order)

    bad_baseline = _scenario_plan_copy(plan)
    bad_baseline.allocations.baseline_scenario_id[1] = "other-current"
    @test_throws ArgumentError _scenario_store_for(result; plan = bad_baseline)

    malformed_allocations = _scenario_plan_copy(plan; allocations = select(plan.allocations, Not(:optimized_scenario_id)))
    @test_throws ArgumentError _scenario_store_for(result; plan = malformed_allocations)

    unknown_scenario = _scenario_plan_copy(plan)
    unknown_scenario.allocations.optimized_scenario_id[1] = "ghost-plan"
    @test_throws ArgumentError _scenario_store_for(result; plan = unknown_scenario)

    duplicate_allocation = _scenario_plan_copy(plan; allocations = vcat(plan.allocations, plan.allocations[1:1, :]))
    @test_throws ArgumentError _scenario_store_for(result; plan = duplicate_allocation)

    missing_channel_allocation = _scenario_plan_copy(plan; allocations = plan.allocations[1:1, :])
    @test_throws ArgumentError _scenario_store_for(result; plan = missing_channel_allocation)
end

@testset "scenario store load fails closed for unsupported or corrupt payloads" begin
    mktempdir() do dir
        open(joinpath(dir, "scenario_store.jls"), "w") do io
            serialize(io, (; schema_version = 0))
        end
        @test_throws ArgumentError load_scenario_store(dir)

        write(joinpath(dir, "scenario_store.jls"), "not a serialized scenario store")
        @test_throws ArgumentError load_scenario_store(dir)
    end
end

@testset "scenario store compatibility rejects guarded mismatches" begin
    result = _scenario_test_result()
    plan = _scenario_store_test_plan(result)
    reference = _scenario_store_for(result; plan)

    different_metadata = ModelArtifactMetadata(
        1,
        epsilon_version(),
        VERSION,
        "2026-05-20T00:00:00Z",
        "TimeSeriesMMM",
        :mcmc,
        :success,
    )
    metadata_mismatch = ScenarioStoreArtifact(
        plan;
        metadata = different_metadata,
        spec = result.spec,
        coordinate_metadata = result.coordinate_metadata,
    )
    @test_throws ArgumentError assert_scenario_store_compatible(reference, metadata_mismatch)

    spec_result = _scenario_test_result(; target_type = "conversion")
    spec_mismatch = _scenario_store_for(spec_result; plan = _scenario_store_test_plan(spec_result))
    @test_throws ArgumentError assert_scenario_store_compatible(reference, spec_mismatch)

    different_coordinates = ModelCoordinateMetadata(
        "date",
        (),
        Dict("date" => ["2024-01-01"], "channel" => ["tv", "search"], "region" => ["north"]),
        Dict{String, Tuple{Vararg{String}}}(),
    )
    coordinate_mismatch = ScenarioStoreArtifact(
        plan;
        metadata = result.metadata,
        spec = result.spec,
        coordinate_metadata = different_coordinates,
    )
    @test_throws ArgumentError assert_scenario_store_compatible(reference, coordinate_mismatch)

    objective_plan = _scenario_plan_copy(plan)
    objective_plan.totals.objective .= "incremental_response"
    objective_plan.metadata.objective .= "incremental_response"
    objective_mismatch = _scenario_store_for(result; plan = objective_plan)
    @test_throws ArgumentError assert_scenario_store_compatible(reference, objective_mismatch)

    baseline_plan = _scenario_store_test_plan(
        result;
        current = CurrentScenarioSpec(name = "Different Current"),
    )
    baseline_mismatch = _scenario_store_for(result; plan = baseline_plan)
    @test_throws ArgumentError assert_scenario_store_compatible(reference, baseline_mismatch)

    reversed_result = _scenario_test_result(; channels = ["search", "tv"])
    channel_order_mismatch = _scenario_store_for(reversed_result; plan = _scenario_store_test_plan(reversed_result))
    @test_throws ArgumentError assert_scenario_store_compatible(reference, channel_order_mismatch)

    compatible = _scenario_store_for(result; plan)
    @test assert_scenario_store_compatible(reference, compatible) === nothing
end
