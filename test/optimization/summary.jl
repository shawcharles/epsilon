include("../fixtures/golden/optimization/cases.jl")

using Epsilon
using Statistics
using Test

const _OPTIMIZATION_SUCCESS_STATUSES = Set(
    [
        :optimal,
        :locally_solved,
        :almost_optimal,
        :almost_locally_solved,
    ]
)

function _optimization_fixture_shell(case)
    coordinates = Dict(
        "date" => ["2024-01-01"],
        "channel" => copy(case.all_channels),
    )
    coordinate_metadata = ModelCoordinateMetadata(
        "date",
        (),
        coordinates,
        Dict{String, Tuple{Vararg{String}}}(),
    )
    spec = MMMModelSpec(
        :time_series_mmm,
        1,
        length(case.all_channels),
        0,
        (),
        coordinate_metadata,
        "revenue",
        case.target_type,
        copy(case.all_channels),
        String[],
        Dict(channel => index for (index, channel) in enumerate(case.all_channels)),
        Dict{String, Int}(),
        ones(length(case.all_channels)),   # channel_scale
        1.0,                               # target_scale
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
        "2026-04-22T00:00:00Z",
        "TimeSeriesMMM",
        :mcmc,
        :success,
    )
    return metadata, coordinate_metadata, spec
end

function _lookup_value(case, field::Symbol, channel::AbstractString)
    index = findfirst(==(String(channel)), case.all_channels)
    isnothing(index) && error("missing channel $(channel)")
    values = getproperty(case, field)
    return Float64(values[index])
end

function _optimized_constraint(case, optimized_index::Integer)
    absolute_lower = case.absolute_lower[optimized_index]
    absolute_upper = case.absolute_upper[optimized_index]
    relative_lower = case.relative_lower[optimized_index]
    relative_upper = case.relative_upper[optimized_index]
    effective_upper = case.effective_upper[optimized_index]

    return Epsilon.BudgetChannelConstraint(
        case.optimized_channels[optimized_index],
        _lookup_value(case, :current_spend_all, case.optimized_channels[optimized_index]),
        isnan(absolute_lower) ? nothing : Float64(absolute_lower),
        isnan(absolute_upper) ? nothing : Float64(absolute_upper),
        isnan(relative_lower) ? nothing : Float64(relative_lower),
        isnan(relative_upper) ? nothing : Float64(relative_upper),
        Float64(case.effective_lower[optimized_index]),
        isnan(effective_upper) ? nothing : Float64(effective_upper),
    )
end

function _fixture_problem(case)
    metadata, coordinate_metadata, spec = _optimization_fixture_shell(case)
    constraints = [
        _optimized_constraint(case, index) for index in eachindex(case.optimized_channels)
    ]
    audit = Epsilon.BudgetConstraintAudit(
        Float64(case.total_budget),
        copy(case.optimized_channels),
        copy(case.fixed_channels),
        constraints,
    )
    surfaces = Epsilon.BudgetChannelSurface[
        Epsilon.BudgetChannelSurface(
                case.optimized_channels[index],
                _lookup_value(case, :current_spend_all, case.optimized_channels[index]),
                copy(case.spend_grids[index]),
                copy(case.response_grids[index]),
                Float64(case.effective_lower[index]),
                isnan(case.effective_upper[index]) ? nothing : Float64(case.effective_upper[index]),
            ) for index in eachindex(case.optimized_channels)
    ]
    current_spend = [
        _lookup_value(case, :current_spend_all, channel) for channel in case.optimized_channels
    ]
    fixed_spend = [
        _lookup_value(case, :current_spend_all, channel) for channel in case.fixed_channels
    ]
    return Epsilon.BudgetOptimizationProblem(
        metadata,
        spec,
        coordinate_metadata,
        :total_response,
        Float64(case.total_budget),
        copy(case.optimized_channels),
        copy(case.fixed_channels),
        current_spend,
        fixed_spend,
        0.0,
        Float64(case.fixed_response),
        Float64(case.expected_current_response),
        surfaces,
        audit,
    )
end

function _nan_aware_approx(lhs, rhs; atol = 1.0e-6, rtol = 1.0e-6)
    return all(isapprox.(lhs, rhs; atol, rtol) .| (isnan.(lhs) .& isnan.(rhs)))
end

function _scaled_reference_spend(case)
    optimized_current = [
        _lookup_value(case, :current_spend_all, channel) for channel in case.optimized_channels
    ]
    current_total = sum(optimized_current)
    if isapprox(current_total, 0.0; atol = sqrt(eps(Float64)))
        return zeros(Float64, length(optimized_current))
    end
    return (optimized_current ./ current_total) .* Float64(case.total_budget)
end

function _surface_lookup(problem)
    return Dict(surface.channel => surface for surface in problem.channel_surfaces)
end

function _expected_marginal_response(problem, spend_mapping; bounded::Bool)
    surfaces = _surface_lookup(problem)
    values = Dict{String, Float64}()
    for channel in problem.optimized_channels
        surface = surfaces[channel]
        values[channel] = if bounded
            Epsilon._evaluate_channel_surface_derivative(surface, spend_mapping[channel])
        else
            Epsilon._evaluate_channel_surface_derivative_unbounded(surface, spend_mapping[channel])
        end
    end
    return values
end

function _allocation_evaluation_shell(;
        allocation_kind = :current,
        objective = :total_response,
        response_draws = [100.0, 110.0, 90.0, 100.0],
        allocation = Dict("tv" => 100.0, "search" => 50.0),
    )
    case = only(filter(case -> case.name == "all_channel_fixed_budget", GOLDEN_OPTIMIZATION_FIXTURES.cases))
    metadata, coordinate_metadata, spec = _optimization_fixture_shell(case)
    total_budget = sum(values(allocation))
    expected_response = mean(response_draws)
    return BudgetAllocationEvaluationResult(
        metadata,
        spec,
        coordinate_metadata,
        objective,
        allocation_kind,
        copy(allocation),
        total_budget,
        Float64.(response_draws),
        expected_response,
        expected_response / total_budget,
    )
end

@testset "budget utility functions score posterior draws" begin
    response_draws = [100.0, 120.0, 95.0, 105.0]
    reference_draws = [100.0, 110.0, 90.0, 100.0]

    default_spec = BudgetUtilitySpec()
    @test default_spec.utility == :mean_response
    @test default_spec.interval_probability ≈ 0.9
    @test default_spec.risk_aversion ≈ 1.0
    @test budget_utility_value(response_draws) ≈ mean(response_draws)
    @test budget_utility_value(response_draws, default_spec) ≈ mean(response_draws)

    lower_spec = BudgetUtilitySpec(:lower_interval_response; interval_probability = 0.5)
    @test budget_utility_value(response_draws, lower_spec) ≈ quantile(response_draws, 0.25)
    @test budget_utility_value(
        response_draws;
        utility = :lower_interval_response,
        interval_probability = 0.5,
    ) ≈ quantile(response_draws, 0.25)

    improvement_spec = BudgetUtilitySpec(:probability_of_improvement)
    @test budget_utility_value(
        response_draws,
        improvement_spec;
        reference_draws,
    ) ≈ 0.75

    risk_spec = BudgetUtilitySpec(:risk_adjusted_response; risk_aversion = 0.5)
    @test budget_utility_value(response_draws, risk_spec) ≈ mean(response_draws) - (0.5 * std(response_draws))
    @test budget_utility_value(
        [42.0],
        BudgetUtilitySpec(:risk_adjusted_response; risk_aversion = 3.0),
    ) ≈ 42.0

    current = _allocation_evaluation_shell(response_draws = reference_draws)
    manual = _allocation_evaluation_shell(
        allocation_kind = :manual,
        response_draws = response_draws,
        allocation = Dict("tv" => 90.0, "search" => 60.0),
    )
    @test budget_utility_value(manual) ≈ mean(response_draws)
    @test budget_utility_value(manual, risk_spec) ≈ mean(response_draws) - (0.5 * std(response_draws))
    @test budget_utility_value(manual, improvement_spec; reference = current) ≈ 0.75
    @test budget_utility_value(
        manual;
        utility = :probability_of_improvement,
        reference = current,
    ) ≈ 0.75

    @test_throws ArgumentError BudgetUtilitySpec(:unsupported)
    @test_throws ArgumentError BudgetUtilitySpec(:lower_interval_response; interval_probability = 1.0)
    @test_throws ArgumentError BudgetUtilitySpec(:risk_adjusted_response; risk_aversion = -1.0)
    @test_throws ArgumentError budget_utility_value(Float64[])
    @test_throws ArgumentError budget_utility_value([1.0, Inf])
    @test_throws ArgumentError BudgetUtilitySpec(1)
    @test_throws ArgumentError budget_utility_value(["not numeric"])
    @test_throws ArgumentError budget_utility_value(response_draws, improvement_spec)
    @test_throws ArgumentError budget_utility_value(
        response_draws,
        improvement_spec;
        reference_draws = [1.0, 2.0],
    )
    @test_throws ArgumentError budget_utility_value(
        manual,
        improvement_spec;
        reference = _allocation_evaluation_shell(objective = :other),
    )
end

@testset "budget allocation decision summaries compare posterior draws" begin
    current = _allocation_evaluation_shell()
    manual = _allocation_evaluation_shell(
        allocation_kind = :manual,
        response_draws = [100.0, 120.0, 95.0, 105.0],
        allocation = Dict("tv" => 90.0, "search" => 60.0),
    )

    summary = budget_allocation_decision_summary(
        current,
        manual;
        interval_probability = 0.5,
    )
    uplift = manual.response_draws .- current.response_draws
    uplift_pct = uplift ./ current.response_draws

    @test summary isa BudgetAllocationDecisionSummary
    @test summary.metadata == manual.metadata
    @test summary.spec == manual.spec
    @test summary.coordinate_metadata == manual.coordinate_metadata
    @test summary.objective == :total_response
    @test summary.reference_allocation_kind == :current
    @test summary.allocation_kind == :manual
    @test summary.allocation == manual.allocation
    @test summary.total_budget ≈ 150.0
    @test summary.interval_probability ≈ 0.5
    @test summary.response_mean ≈ mean(manual.response_draws)
    @test summary.response_median ≈ median(manual.response_draws)
    @test summary.response_std ≈ std(manual.response_draws)
    @test summary.response_interval_lower ≈ quantile(manual.response_draws, 0.25)
    @test summary.response_interval_upper ≈ quantile(manual.response_draws, 0.75)
    @test summary.uplift_mean ≈ mean(uplift)
    @test summary.uplift_median ≈ median(uplift)
    @test summary.uplift_std ≈ std(uplift)
    @test summary.uplift_interval_lower ≈ quantile(uplift, 0.25)
    @test summary.uplift_interval_upper ≈ quantile(uplift, 0.75)
    @test summary.uplift_pct_mean ≈ mean(uplift_pct)
    @test summary.uplift_pct_median ≈ median(uplift_pct)
    @test summary.uplift_pct_interval_lower ≈ quantile(uplift_pct, 0.25)
    @test summary.uplift_pct_interval_upper ≈ quantile(uplift_pct, 0.75)
    @test summary.probability_beats_reference ≈ 0.75

    current_summary = budget_allocation_decision_summary(current, current)
    @test current_summary.uplift_mean ≈ 0.0
    @test current_summary.uplift_median ≈ 0.0
    @test current_summary.uplift_std ≈ 0.0
    @test current_summary.probability_beats_reference ≈ 0.0

    table = budget_allocation_decision_table(current, current, manual; interval_probability = 0.5)
    @test names(table) == [
        "allocation_kind",
        "reference_allocation_kind",
        "objective",
        "total_budget",
        "response_mean",
        "response_median",
        "response_std",
        "response_interval_lower",
        "response_interval_upper",
        "uplift_mean",
        "uplift_median",
        "uplift_std",
        "uplift_interval_lower",
        "uplift_interval_upper",
        "uplift_pct_mean",
        "uplift_pct_median",
        "uplift_pct_interval_lower",
        "uplift_pct_interval_upper",
        "probability_beats_reference",
        "interval_probability",
    ]
    @test table.allocation_kind == [:current, :manual]
    @test table.reference_allocation_kind == [:current, :current]
    @test table.uplift_mean[1] ≈ 0.0
    @test table.uplift_mean[2] ≈ summary.uplift_mean
    @test table.probability_beats_reference == [0.0, 0.75]

    vector_table = budget_allocation_decision_table(current, [manual])
    @test size(vector_table, 1) == 1
    @test vector_table.allocation_kind == [:manual]

    @test_throws ArgumentError budget_allocation_decision_summary(
        current,
        manual;
        interval_probability = 1.0,
    )
    @test_throws ArgumentError budget_allocation_decision_summary(
        current,
        _allocation_evaluation_shell(objective = :other),
    )
    @test_throws ArgumentError budget_allocation_decision_summary(
        current,
        _allocation_evaluation_shell(response_draws = [100.0, 101.0]),
    )
end

@testset "budget optimization summary projections follow public schemas" begin
    case = only(filter(case -> case.name == "mixed_bounds_subset_optimization", GOLDEN_OPTIMIZATION_FIXTURES.cases))
    problem = _fixture_problem(case)
    result = Epsilon._solve_budget_optimization_problem(problem)
    expected_current_marginal_response = _expected_marginal_response(
        problem,
        result.current_spend;
        bounded = false,
    )
    expected_optimized_marginal_response = _expected_marginal_response(
        problem,
        result.optimized_spend;
        bounded = true,
    )

    impact = budget_impact_table(result)
    @test names(impact) == [
        "channel",
        "optimized",
        "current_spend",
        "optimized_spend",
        "spend_delta",
        "current_share",
        "optimized_share",
        "optimized_vs_current_pct",
    ]
    @test impact.channel == ["tv", "search", "social"]
    @test impact.optimized == [true, false, true]
    @test impact.current_spend[2] ≈ impact.optimized_spend[2]
    @test sum(impact.current_share) ≈ 1.0
    @test sum(impact.optimized_share) ≈ 1.0

    audit = budget_audit_table(result)
    @test names(audit) == [
        "channel",
        "current_spend",
        "scaled_reference_spend",
        "absolute_lower",
        "absolute_upper",
        "relative_lower",
        "relative_upper",
        "effective_lower",
        "effective_upper",
        "optimized_spend",
        "optimized_within_bounds",
        "optimized_minus_lower_bound",
        "upper_bound_minus_optimized",
        "optimized_vs_current_pct",
        "optimized_vs_scaled_reference_pct",
        "current_share",
        "scaled_reference_share",
        "optimized_share",
    ]
    @test audit.channel == ["tv", "social"]
    @test all(audit.optimized_within_bounds)
    @test sum(audit.optimized_share) ≈ 1.0

    diagnostics = optimization_diagnostics(result)
    @test diagnostics isa BudgetOptimizationDiagnostics
    @test diagnostics.objective == :total_response
    @test diagnostics.solver_status in _OPTIMIZATION_SUCCESS_STATUSES
    @test diagnostics.optimized_channels == ["tv", "social"]
    @test diagnostics.fixed_channels == ["search"]
    @test diagnostics.current_total_spend ≈ sum(values(result.current_spend))
    @test diagnostics.optimized_total_spend ≈ sum(values(result.optimized_spend))
    @test diagnostics.spend_delta ≈ diagnostics.optimized_total_spend - diagnostics.current_total_spend
    @test diagnostics.current_response ≈ result.current_response
    @test diagnostics.optimized_response ≈ result.optimized_response
    @test diagnostics.response_delta ≈ result.optimized_response - result.current_response
    @test diagnostics.response_lift_pct ≈ diagnostics.response_delta / result.current_response
    @test diagnostics.default_efficiency_delta ≈
        result.optimized_default_efficiency - result.current_default_efficiency
    @test diagnostics.current_marginal_response == expected_current_marginal_response
    @test diagnostics.optimized_marginal_response == expected_optimized_marginal_response
    @test diagnostics.convergence_metadata == result.convergence_metadata
    @test diagnostics.constraint_audit == result.constraint_audit

    diagnostics_table = optimization_diagnostics_table(result)
    @test names(diagnostics_table) == [
        "channel",
        "optimized",
        "fixed",
        "solver_status",
        "objective",
        "current_spend",
        "optimized_spend",
        "spend_delta",
        "spend_delta_pct",
        "current_spend_share",
        "optimized_spend_share",
        "lower_bound_active",
        "upper_bound_active",
        "current_marginal_response",
        "optimized_marginal_response",
        "current_marginal_roas",
        "optimized_marginal_roas",
        "current_marginal_cpa",
        "optimized_marginal_cpa",
        "current_total_response",
        "optimized_total_response",
        "total_response_delta",
        "total_response_lift_pct",
        "current_default_efficiency",
        "optimized_default_efficiency",
        "default_efficiency_delta",
        "default_efficiency_lift_pct",
    ]
    @test diagnostics_table.channel == ["tv", "search", "social"]
    @test diagnostics_table.optimized == [true, false, true]
    @test diagnostics_table.fixed == [false, true, false]
    @test all(diagnostics_table.solver_status .== result.solver_status)
    @test all(diagnostics_table.objective .== result.objective)
    @test diagnostics_table.current_spend ≈ [
        result.current_spend[channel] for channel in diagnostics_table.channel
    ]
    @test diagnostics_table.optimized_spend ≈ [
        result.optimized_spend[channel] for channel in diagnostics_table.channel
    ]
    @test diagnostics_table.spend_delta ≈ diagnostics_table.optimized_spend .- diagnostics_table.current_spend
    @test sum(diagnostics_table.current_spend_share) ≈ 1.0
    @test sum(diagnostics_table.optimized_spend_share) ≈ 1.0
    @test diagnostics_table.lower_bound_active == [false, false, false]
    @test diagnostics_table.upper_bound_active == [true, false, false]
    @test diagnostics_table.current_marginal_response[1] ≈ expected_current_marginal_response["tv"]
    @test diagnostics_table.optimized_marginal_response[1] ≈ expected_optimized_marginal_response["tv"]
    @test isnan(diagnostics_table.current_marginal_response[2])
    @test isnan(diagnostics_table.optimized_marginal_response[2])
    @test diagnostics_table.current_marginal_roas[1] ≈ diagnostics_table.current_marginal_response[1]
    @test diagnostics_table.optimized_marginal_roas[1] ≈ diagnostics_table.optimized_marginal_response[1]
    @test all(isnan, diagnostics_table.current_marginal_cpa)
    @test all(isnan, diagnostics_table.optimized_marginal_cpa)
    @test all(diagnostics_table.current_total_response .≈ result.current_response)
    @test all(diagnostics_table.optimized_total_response .≈ result.optimized_response)
    @test all(diagnostics_table.total_response_delta .≈ result.optimized_response - result.current_response)
end

@testset "optimization matches retained golden fixtures" begin
    atol = 1.0e-5
    rtol = 1.0e-5

    for case in GOLDEN_OPTIMIZATION_FIXTURES.cases
        @testset "$(case.name)" begin
            problem = _fixture_problem(case)
            result = Epsilon._solve_budget_optimization_problem(problem)

            @test result.solver_status in _OPTIMIZATION_SUCCESS_STATUSES
            @test result.optimized_channels == case.optimized_channels
            @test result.fixed_channels == case.fixed_channels

            for channel in case.all_channels
                expected_current = _lookup_value(case, :current_spend_all, channel)
                expected_optimized = _lookup_value(case, :expected_optimized_spend_all, channel)
                @test result.current_spend[channel] ≈ expected_current atol = atol rtol = rtol
                @test result.optimized_spend[channel] ≈ expected_optimized atol = atol rtol = rtol
            end

            @test result.current_response ≈ case.expected_current_response atol = atol rtol = rtol
            @test result.optimized_response ≈ case.expected_optimized_response atol = atol rtol = rtol
            @test result.current_default_efficiency ≈ case.expected_current_default_efficiency atol = atol rtol = rtol
            @test result.optimized_default_efficiency ≈ case.expected_optimized_default_efficiency atol = atol rtol = rtol

            impact = budget_impact_table(result)
            @test impact.channel == case.all_channels
            @test impact.optimized == [channel in Set(case.optimized_channels) for channel in case.all_channels]
            @test impact.current_spend ≈ case.current_spend_all atol = atol rtol = rtol
            @test impact.optimized_spend ≈ case.expected_optimized_spend_all atol = atol rtol = rtol
            @test _nan_aware_approx(
                impact.optimized_vs_current_pct,
                (case.expected_optimized_spend_all ./ case.current_spend_all) .- 1.0;
                atol,
                rtol,
            )

            expected_current_total = sum(case.current_spend_all)
            expected_optimized_total = sum(case.expected_optimized_spend_all)
            @test _nan_aware_approx(
                impact.current_share,
                case.current_spend_all ./ expected_current_total;
                atol,
                rtol,
            )
            @test _nan_aware_approx(
                impact.optimized_share,
                case.expected_optimized_spend_all ./ expected_optimized_total;
                atol,
                rtol,
            )

            audit = budget_audit_table(result)
            expected_current_subset = [
                _lookup_value(case, :current_spend_all, channel) for channel in case.optimized_channels
            ]
            expected_optimized_subset = [
                _lookup_value(case, :expected_optimized_spend_all, channel) for channel in case.optimized_channels
            ]
            expected_scaled_reference = _scaled_reference_spend(case)

            @test audit.channel == case.optimized_channels
            @test audit.current_spend ≈ expected_current_subset atol = atol rtol = rtol
            @test audit.scaled_reference_spend ≈ expected_scaled_reference atol = atol rtol = rtol
            @test _nan_aware_approx(audit.absolute_lower, case.absolute_lower; atol, rtol)
            @test _nan_aware_approx(audit.absolute_upper, case.absolute_upper; atol, rtol)
            @test _nan_aware_approx(audit.relative_lower, case.relative_lower; atol, rtol)
            @test _nan_aware_approx(audit.relative_upper, case.relative_upper; atol, rtol)
            @test audit.effective_lower ≈ case.effective_lower atol = atol rtol = rtol
            @test _nan_aware_approx(audit.effective_upper, case.effective_upper; atol, rtol)
            @test audit.optimized_spend ≈ expected_optimized_subset atol = atol rtol = rtol
            @test all(audit.optimized_within_bounds)
            @test _nan_aware_approx(
                audit.optimized_vs_current_pct,
                (expected_optimized_subset ./ expected_current_subset) .- 1.0;
                atol,
                rtol,
            )
            @test _nan_aware_approx(
                audit.optimized_vs_scaled_reference_pct,
                (expected_optimized_subset ./ expected_scaled_reference) .- 1.0;
                atol,
                rtol,
            )
            @test _nan_aware_approx(
                audit.current_share,
                expected_current_subset ./ sum(expected_current_subset);
                atol,
                rtol,
            )
            @test _nan_aware_approx(
                audit.scaled_reference_share,
                expected_scaled_reference ./ sum(expected_scaled_reference);
                atol,
                rtol,
            )
            @test _nan_aware_approx(
                audit.optimized_share,
                expected_optimized_subset ./ sum(expected_optimized_subset);
                atol,
                rtol,
            )

            diagnostics = optimization_diagnostics(result)
            @test diagnostics.current_total_spend ≈ expected_current_total atol = atol rtol = rtol
            @test diagnostics.optimized_total_spend ≈ expected_optimized_total atol = atol rtol = rtol
            @test diagnostics.spend_delta ≈ expected_optimized_total - expected_current_total atol = atol rtol = rtol
            @test diagnostics.response_delta ≈
                case.expected_optimized_response - case.expected_current_response atol = atol rtol = rtol
            @test diagnostics.current_marginal_response == _expected_marginal_response(
                problem,
                result.current_spend;
                bounded = false,
            )
            @test diagnostics.optimized_marginal_response == _expected_marginal_response(
                problem,
                result.optimized_spend;
                bounded = true,
            )

            diagnostics_table = optimization_diagnostics_table(result)
            @test diagnostics_table.channel == case.all_channels
            @test diagnostics_table.optimized == [channel in Set(case.optimized_channels) for channel in case.all_channels]
            @test diagnostics_table.fixed == [!(channel in Set(case.optimized_channels)) for channel in case.all_channels]
            @test diagnostics_table.current_spend ≈ case.current_spend_all atol = atol rtol = rtol
            @test diagnostics_table.optimized_spend ≈ case.expected_optimized_spend_all atol = atol rtol = rtol
            @test diagnostics_table.spend_delta ≈
                case.expected_optimized_spend_all .- case.current_spend_all atol = atol rtol = rtol
            @test all(diagnostics_table.current_total_response .≈ case.expected_current_response)
            @test all(diagnostics_table.optimized_total_response .≈ case.expected_optimized_response)
            @test all(diagnostics_table.total_response_delta .≈ diagnostics.response_delta)
            for channel in case.optimized_channels
                row = only(filter(:channel => ==(channel), diagnostics_table))
                @test isfinite(row.current_marginal_response)
                @test isfinite(row.optimized_marginal_response)
                @test row.current_marginal_roas ≈ row.current_marginal_response
                @test row.optimized_marginal_roas ≈ row.optimized_marginal_response
                @test isnan(row.current_marginal_cpa)
                @test isnan(row.optimized_marginal_cpa)
            end
            for channel in case.fixed_channels
                row = only(filter(:channel => ==(channel), diagnostics_table))
                @test !row.lower_bound_active
                @test !row.upper_bound_active
                @test isnan(row.current_marginal_response)
                @test isnan(row.optimized_marginal_response)
            end
        end
    end
end

@testset "optimization diagnostics report marginal CPA for conversion targets" begin
    case = merge(
        only(filter(case -> case.name == "all_channel_fixed_budget", GOLDEN_OPTIMIZATION_FIXTURES.cases)),
        (target_type = "conversion",),
    )
    problem = _fixture_problem(case)
    result = Epsilon._solve_budget_optimization_problem(problem)
    table = optimization_diagnostics_table(result)

    @test all(isnan, table.current_marginal_roas)
    @test all(isnan, table.optimized_marginal_roas)
    @test all(table.current_marginal_cpa .≈ 1.0 ./ table.current_marginal_response)
    @test all(table.optimized_marginal_cpa .≈ 1.0 ./ table.optimized_marginal_response)
end

@testset "optimization diagnostics mark active solved bounds" begin
    case = only(filter(case -> case.name == "absolute_bound_constrained", GOLDEN_OPTIMIZATION_FIXTURES.cases))
    problem = _fixture_problem(case)
    result = Epsilon._solve_budget_optimization_problem(problem)

    table = optimization_diagnostics_table(result)
    tv_row = only(filter(:channel => ==("tv"), table))
    search_row = only(filter(:channel => ==("search"), table))

    @test tv_row.optimized
    @test tv_row.upper_bound_active
    @test !tv_row.lower_bound_active
    @test !search_row.upper_bound_active
end
