using Epsilon
using Test

include("helpers.jl")

const _SUCCESS_SOLVER_STATUSES = Set(
    [
        :optimal,
        :locally_solved,
        :almost_optimal,
        :almost_locally_solved,
    ]
)

@testset "optimize_budget solves bounded MCMC allocations" begin
    model = sample_time_series_model()
    fit!(model)
    grouped = _grouped_results_for_optimization(model)

    total_budget = sum(model.data.channels)
    result = optimize_budget(grouped; total_budget)

    @test result isa BudgetOptimizationResult
    @test result.objective == :total_response
    @test result.optimized_channels == ["tv", "search"]
    @test isempty(result.fixed_channels)
    @test result.solver_status in _SUCCESS_SOLVER_STATUSES
    @test haskey(result.convergence_metadata, "termination_status")
    @test result.current_spend["tv"] ≈ _observed_channel_total(model, "tv")
    @test result.current_spend["search"] ≈ _observed_channel_total(model, "search")
    @test sum(values(result.optimized_spend)) ≈ total_budget
    @test result.optimized_response + 1.0e-6 >= result.current_response
    @test result.objective_value ≈ result.optimized_response atol = 1.0e-5 rtol = 1.0e-5
    @test isfinite(result.current_default_efficiency)
    @test isfinite(result.optimized_default_efficiency)
    @test result.constraint_audit.total_budget ≈ total_budget
end

@testset "optimize_budget keeps unselected channels fixed" begin
    model = sample_time_series_model()
    fit!(model)
    grouped = _grouped_results_for_optimization(model)

    search_total = _observed_channel_total(model, "search")
    tv_total = _observed_channel_total(model, "tv")
    result = optimize_budget(
        grouped;
        total_budget = search_total,
        channels = ["search"],
    )

    @test result.optimized_channels == ["search"]
    @test result.fixed_channels == ["tv"]
    @test result.current_spend["tv"] ≈ tv_total
    @test result.optimized_spend["tv"] ≈ tv_total
    @test result.current_spend["search"] ≈ search_total
    @test result.optimized_spend["search"] ≈ search_total
    @test result.objective_value ≈ result.optimized_response atol = 1.0e-5 rtol = 1.0e-5
end

@testset "optimize_budget respects bounded channel allocations" begin
    model = sample_time_series_model()
    fit!(model)
    grouped = _grouped_results_for_optimization(model)

    observed_tv = _observed_channel_total(model, "tv")
    observed_search = _observed_channel_total(model, "search")
    total_budget = observed_tv + observed_search
    result = optimize_budget(
        grouped;
        total_budget,
        budget_bounds = Dict("tv" => (upper = observed_tv * 0.75,)),
    )

    @test result.optimized_spend["tv"] <= observed_tv * 0.75 + 1.0e-6
    @test result.optimized_spend["search"] >= observed_search - 1.0e-6
    @test sum(values(result.optimized_spend)) ≈ total_budget
end

@testset "optimize_budget uses CPA-style default efficiency for conversion targets" begin
    model = sample_time_series_model(; target_type = "conversion")
    fit!(model)
    grouped = _grouped_results_for_optimization(model)

    total_budget = sum(model.data.channels)
    result = optimize_budget(grouped; total_budget)

    @test result.current_default_efficiency ≈ sum(values(result.current_spend)) / result.current_response
    @test result.optimized_default_efficiency ≈ sum(values(result.optimized_spend)) / result.optimized_response
end

@testset "optimize_budget fails explicitly on unsupported inputs" begin
    model = sample_time_series_model()
    fit!(model)
    grouped = _grouped_results_for_optimization(model)

    @test_throws ArgumentError optimize_budget(grouped; total_budget = 1.0, objective = :roas)
    @test_throws ArgumentError optimize_budget(
        grouped;
        total_budget = 1.0,
        panel_allocation_mode = :free_panel,
    )
end

@testset "optimize_budget supports panel historical-share allocations" begin
    panel = sample_panel_model()
    fit!(panel)
    panel_grouped = inference_results(
        panel;
        include_prior = false,
        include_posterior_predictive = false,
        include_prior_predictive = false,
    )

    total_budget = sum(panel.data.channels)
    result = optimize_budget(panel_grouped; total_budget)

    @test result isa PanelBudgetOptimizationResult
    @test result.panel_allocation_mode == :historical_shares
    @test result.solver_status in _SUCCESS_SOLVER_STATUSES
    @test result.optimized_response + 1.0e-6 >= result.current_response
    @test sum(values(result.optimized_spend)) ≈ total_budget
    @test result.historical_panel_shares * ones(length(result.panel_names)) ≈ ones(length(result.spec.channel_columns))
    @test sum(result.optimized_channel_panel_spend; dims = 2)[:] ≈ [
        result.optimized_spend[channel] for channel in result.spec.channel_columns
    ]

    @test_throws ArgumentError optimize_budget(
        panel_grouped;
        total_budget,
        panel_allocation_mode = :free_panel,
    )
    @test_throws ArgumentError optimize_budget(
        panel_grouped;
        total_budget,
        panel_total_bounds = Dict("north" => (upper = total_budget,)),
    )
end
