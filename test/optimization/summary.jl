include("../fixtures/golden/optimization/cases.jl")

using Epsilon
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

@testset "budget optimization summary projections follow public schemas" begin
    model = sample_time_series_model()
    fit!(model)
    grouped = _grouped_results_for_optimization(model)

    result = optimize_budget(
        grouped;
        total_budget = _observed_channel_total(model, "search"),
        channels = ["search"],
        budget_bounds = Dict("search" => (lower = 0.0, upper = _observed_channel_total(model, "search") * 1.2)),
        relative_bounds = Dict("search" => (lower = 0.8, upper = 1.1)),
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
    @test impact.channel == ["tv", "search"]
    @test impact.optimized == [false, true]
    @test impact.current_spend[1] ≈ impact.optimized_spend[1]
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
    @test audit.channel == ["search"]
    @test only(audit.optimized_within_bounds)
    @test sum(audit.optimized_share) ≈ 1.0
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
        end
    end
end
