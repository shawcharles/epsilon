using Epsilon
using Test

include("helpers.jl")

@testset "budget optimization problem builds bounded MCMC objective surfaces" begin
    model = sample_time_series_model()
    fit!(model)
    grouped = _grouped_results_for_optimization(model)

    total_budget = sum(model.data.channels)
    problem = Epsilon._build_budget_optimization_problem(grouped; total_budget)

    @test problem isa Epsilon.BudgetOptimizationProblem
    @test problem.objective == :total_response
    @test problem.optimized_channels == ["tv", "search"]
    @test isempty(problem.fixed_channels)
    @test length(problem.channel_surfaces) == 2
    @test problem.current_spend ≈ [
        _observed_channel_total(model, "tv"),
        _observed_channel_total(model, "search"),
    ]
    @test problem.constraint_audit.total_budget ≈ total_budget
    @test isfinite(problem.baseline_response)
    @test isfinite(problem.current_response)
    @test problem.current_response ≈ Epsilon._evaluate_budget_objective(problem, problem.current_spend)
    @test all(isfinite, Epsilon._evaluate_budget_objective_gradient(problem, problem.current_spend))
end

@testset "budget optimization problem respects subset-budget semantics" begin
    model = sample_time_series_model()
    fit!(model)
    grouped = _grouped_results_for_optimization(model)

    search_total = _observed_channel_total(model, "search")
    tv_total = _observed_channel_total(model, "tv")
    problem = Epsilon._build_budget_optimization_problem(
        grouped;
        total_budget = search_total,
        channels = ["search"],
    )

    @test problem.optimized_channels == ["search"]
    @test problem.fixed_channels == ["tv"]
    @test problem.current_spend ≈ [search_total]
    @test problem.fixed_spend ≈ [tv_total]
    @test problem.current_response ≈ Epsilon._evaluate_budget_objective(problem, [search_total])
end

@testset "budget optimization problem accepts capped custom grids that cover the feasible domain" begin
    model = sample_time_series_model()
    fit!(model)
    grouped = _grouped_results_for_optimization(model)

    observed_tv = _observed_channel_total(model, "tv")
    observed_search = _observed_channel_total(model, "search")
    tv_cap = observed_tv * 1.1
    total_budget = observed_tv + observed_search

    problem = Epsilon._build_budget_optimization_problem(
        grouped;
        total_budget,
        budget_bounds = Dict("tv" => (upper = tv_cap,)),
        grid = Dict(
            "tv" => [0.0, observed_tv, tv_cap],
            "search" => [0.0, observed_search, total_budget],
        ),
    )

    tv_surface = only(filter(surface -> surface.channel == "tv", problem.channel_surfaces))
    @test tv_surface.spend_grid[end] ≈ tv_cap
    @test tv_surface.effective_upper ≈ tv_cap
end

@testset "budget optimization problem normalizes absolute and relative bounds" begin
    model = sample_time_series_model()
    fit!(model)
    grouped = _grouped_results_for_optimization(model)

    observed_tv = _observed_channel_total(model, "tv")
    problem = Epsilon._build_budget_optimization_problem(
        grouped;
        total_budget = observed_tv,
        channels = ["tv"],
        budget_bounds = Dict("tv" => (lower = 1.0, upper = observed_tv * 2.0)),
        relative_bounds = Dict("tv" => (lower = 0.5, upper = 1.5)),
    )

    constraint = only(problem.constraint_audit.channel_constraints)
    @test constraint.channel == "tv"
    @test constraint.absolute_lower ≈ 1.0
    @test constraint.absolute_upper ≈ observed_tv * 2.0
    @test constraint.relative_lower ≈ 0.5
    @test constraint.relative_upper ≈ 1.5
    @test constraint.effective_lower ≈ max(1.0, observed_tv * 0.5)
    @test constraint.effective_upper ≈ min(observed_tv * 2.0, observed_tv * 1.5)
end

@testset "budget optimization current-response comparison remains defined outside feasible bounds" begin
    model = sample_time_series_model()
    fit!(model)
    grouped = _grouped_results_for_optimization(model)

    observed_tv = _observed_channel_total(model, "tv")
    problem = Epsilon._build_budget_optimization_problem(
        grouped;
        total_budget = observed_tv * 1.25,
        channels = ["tv"],
        budget_bounds = Dict("tv" => (lower = observed_tv * 1.1, upper = observed_tv * 2.0)),
    )

    @test isfinite(problem.current_response)
    @test_throws ArgumentError Epsilon._evaluate_budget_objective(problem, [observed_tv])
end

@testset "budget optimization marginal current response can be audited outside feasible bounds" begin
    surface = Epsilon.BudgetChannelSurface(
        "tv",
        2.0,
        [0.0, 2.0, 5.0, 10.0],
        [0.0, 1.0, 2.0, 3.0],
        5.0,
        10.0,
    )

    @test isfinite(Epsilon._evaluate_channel_surface_derivative_unbounded(surface, 2.0))
    @test_throws ArgumentError Epsilon._evaluate_channel_surface_derivative(surface, 2.0)
end

@testset "budget optimization problem rejects malformed contract inputs" begin
    model = sample_time_series_model()
    fit!(model)
    grouped = _grouped_results_for_optimization(model)
    observed_tv = _observed_channel_total(model, "tv")
    observed_search = _observed_channel_total(model, "search")

    @test_throws ArgumentError Epsilon._build_budget_optimization_problem(
        grouped;
        total_budget = observed_tv,
        channels = ["tv", "tv"],
    )
    @test_throws ArgumentError Epsilon._build_budget_optimization_problem(
        grouped;
        total_budget = observed_tv,
        channels = ["email"],
    )
    @test_throws ArgumentError Epsilon._build_budget_optimization_problem(
        grouped;
        total_budget = observed_tv,
        channels = ["tv"],
        objective = :roas,
    )
    @test_throws ArgumentError Epsilon._build_budget_optimization_problem(
        grouped;
        total_budget = observed_tv,
        channels = ["tv"],
        budget_bounds = Dict("tv" => (lower = observed_tv, upper = observed_tv / 2)),
    )
    @test_throws ArgumentError Epsilon._build_budget_optimization_problem(
        grouped;
        total_budget = observed_tv * 3,
        channels = ["tv"],
        budget_bounds = Dict("tv" => (upper = observed_tv * 1.2,)),
    )
    @test_throws ArgumentError Epsilon._build_budget_optimization_problem(
        grouped;
        total_budget = observed_search,
        channels = ["search"],
        grid = Dict("tv" => [0.0, observed_tv]),
    )
    @test_throws ArgumentError Epsilon._build_budget_optimization_problem(
        grouped;
        total_budget = observed_tv + observed_search,
        grid = Dict{Any, Any}(
            :tv => [0.0, observed_tv, observed_tv + observed_search],
            "tv" => [0.0, observed_tv, observed_tv + observed_search],
            "search" => [0.0, observed_search, observed_tv + observed_search],
        ),
    )
    @test_throws ArgumentError Epsilon._build_budget_optimization_problem(
        grouped;
        total_budget = observed_tv * 1.2,
        channels = ["tv"],
        budget_bounds = Dict("tv" => (lower = observed_tv * 1.1, upper = observed_tv * 2.0)),
        grid = Dict("tv" => [observed_tv * 1.1, observed_tv * 1.2, observed_tv * 1.5]),
    )

    panel = sample_panel_model()
    fit!(panel)
    panel_grouped = inference_results(
        panel;
        include_prior = false,
        include_posterior_predictive = false,
        include_prior_predictive = false,
    )
    @test_throws ArgumentError Epsilon._build_budget_optimization_problem(
        panel_grouped;
        total_budget = 1.0,
    )
end

@testset "panel budget optimization problem preserves historical-share response semantics" begin
    panel = sample_panel_model()
    fit!(panel)
    grouped = _grouped_results_for_optimization(panel)

    total_budget = sum(panel.data.channels)
    problem = Epsilon._build_panel_budget_optimization_problem(grouped; total_budget)

    @test problem isa Epsilon.BudgetOptimizationProblem
    @test problem.objective == :total_response
    @test problem.optimized_channels == ["tv", "search"]
    @test isempty(problem.fixed_channels)
    @test problem.current_spend ≈ [
        _observed_channel_total(panel, "tv"),
        _observed_channel_total(panel, "search"),
    ]
    @test problem.constraint_audit.total_budget ≈ total_budget
    @test all(length(surface.spend_grid) == length(surface.response_grid) for surface in problem.channel_surfaces)
    @test problem.current_response ≈ Epsilon._evaluate_budget_objective(problem, problem.current_spend)
    @test_throws ArgumentError Epsilon._build_panel_budget_optimization_problem(
        grouped;
        total_budget,
        panel_allocation_mode = :free_panel,
    )
    @test_throws ArgumentError Epsilon._build_panel_budget_optimization_problem(
        grouped;
        total_budget,
        channel_panel_bounds = Dict("tv" => Dict("north" => (upper = 1.0,))),
    )
end

@testset "budget optimization objective rejects duplicate semantic allocation keys" begin
    model = sample_time_series_model()
    fit!(model)
    grouped = _grouped_results_for_optimization(model)

    total_budget = sum(model.data.channels)
    problem = Epsilon._build_budget_optimization_problem(grouped; total_budget)

    @test_throws ArgumentError Epsilon._evaluate_budget_objective(
        problem,
        Dict{Any, Any}(
            :tv => _observed_channel_total(model, "tv"),
            "tv" => _observed_channel_total(model, "tv"),
            "search" => _observed_channel_total(model, "search"),
        ),
    )
end

@testset "post-solve bound projection preserves total-budget equality after multiple snaps" begin
    constraints = [
        Epsilon.BudgetChannelConstraint("tv", 1.0, nothing, 1.0, nothing, nothing, 0.0, 1.0),
        Epsilon.BudgetChannelConstraint("search", 1.0, nothing, 2.0, nothing, nothing, 0.0, 2.0),
        Epsilon.BudgetChannelConstraint("radio", 1.0, nothing, 2.0, nothing, nothing, 0.0, 2.0),
    ]
    allocation = [0.9999996, 1.9999996, 1.4999992]
    projected = Epsilon._project_to_constraint_bounds(allocation, constraints, 4.5)

    @test projected[1] ≈ 1.0 atol = 1.0e-12 rtol = 1.0e-12
    @test sum(projected) ≈ 4.5 atol = 1.0e-10 rtol = 1.0e-10
    @test projected[2] <= 2.0 + 1.0e-12
    @test projected[3] <= 2.0 + 1.0e-12
end

@testset "post-solve bound projection rebalances residuals only through valid slack" begin
    positive_constraints = [
        Epsilon.BudgetChannelConstraint("tv", 1.0, nothing, 1.0, nothing, nothing, 0.0, 1.0),
        Epsilon.BudgetChannelConstraint("search", 1.0, nothing, 2.0, nothing, nothing, 0.0, 2.0),
        Epsilon.BudgetChannelConstraint("radio", 1.0, nothing, 2.0, nothing, nothing, 0.0, 2.0),
    ]
    positive_projected = Epsilon._project_to_constraint_bounds(
        [1.0, 2.0, 1.0],
        positive_constraints,
        4.5,
    )

    @test positive_projected[1] == 1.0
    @test positive_projected[2] == 2.0
    @test positive_projected[3] == 1.5
    @test sum(positive_projected) ≈ 4.5 atol = 1.0e-12 rtol = 0.0
    @test all(positive_projected .>= [constraint.effective_lower for constraint in positive_constraints])
    @test all(positive_projected .<= Float64[something(constraint.effective_upper, Inf) for constraint in positive_constraints])

    negative_constraints = [
        Epsilon.BudgetChannelConstraint("tv", 1.0, nothing, 2.0, nothing, nothing, 1.0, 2.0),
        Epsilon.BudgetChannelConstraint("search", 1.0, nothing, 2.0, nothing, nothing, 0.5, 2.0),
        Epsilon.BudgetChannelConstraint("radio", 1.0, nothing, 2.0, nothing, nothing, 0.0, 2.0),
    ]
    negative_projected = Epsilon._project_to_constraint_bounds(
        [1.0, 0.5, 1.0],
        negative_constraints,
        2.0,
    )

    @test negative_projected[1] == 1.0
    @test negative_projected[2] == 0.5
    @test negative_projected[3] == 0.5
    @test sum(negative_projected) ≈ 2.0 atol = 1.0e-12 rtol = 0.0
    @test all(negative_projected .>= [constraint.effective_lower for constraint in negative_constraints])
    @test all(negative_projected .<= Float64[something(constraint.effective_upper, Inf) for constraint in negative_constraints])
end

@testset "post-solve bound projection fails closed when residual cannot fit bounds" begin
    constraints = [
        Epsilon.BudgetChannelConstraint("tv", 1.0, nothing, 1.0, nothing, nothing, 0.0, 1.0),
        Epsilon.BudgetChannelConstraint("search", 1.0, nothing, 2.0, nothing, nothing, 0.0, 2.0),
        Epsilon.BudgetChannelConstraint("radio", 1.0, nothing, 2.0, nothing, nothing, 0.0, 2.0),
    ]

    @test_throws ErrorException Epsilon._project_to_constraint_bounds(
        [1.0, 2.0, 2.0],
        constraints,
        5.25,
    )

    @test_throws ErrorException Epsilon._project_to_constraint_bounds(
        [0.0, 0.0, 0.0],
        constraints,
        -0.25,
    )
end

@testset "feasible initial allocation does not exceed bounded channels for tolerance residuals" begin
    model = sample_time_series_model()
    fit!(model)
    grouped = _grouped_results_for_optimization(model)
    base_problem = Epsilon._build_budget_optimization_problem(grouped; total_budget = sum(model.data.channels))
    tolerance = sqrt(eps(Float64))
    constraints = [
        Epsilon.BudgetChannelConstraint("tv", 1.0, nothing, 1.0, nothing, nothing, 0.0, 1.0),
        Epsilon.BudgetChannelConstraint("search", 1.0, nothing, 1.0, nothing, nothing, 0.0, 1.0),
    ]
    audit = Epsilon.BudgetConstraintAudit(
        2.0 + tolerance / 2,
        ["tv", "search"],
        String[],
        constraints,
    )
    problem = Epsilon.BudgetOptimizationProblem(
        base_problem.metadata,
        base_problem.spec,
        base_problem.coordinate_metadata,
        base_problem.objective,
        audit.total_budget,
        audit.optimized_channels,
        audit.fixed_channels,
        [1.0, 1.0],
        Float64[],
        base_problem.baseline_response,
        0.0,
        base_problem.current_response,
        base_problem.channel_surfaces,
        audit,
    )

    allocation = Epsilon._feasible_initial_allocation(problem)

    @test all(allocation .<= 1.0)
    @test sum(allocation) ≈ audit.total_budget atol = tolerance rtol = 0.0
end
