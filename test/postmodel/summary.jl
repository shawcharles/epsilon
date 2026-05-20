include("../fixtures/abacus/postmodel_summary_cases.jl")

using Dates
using Epsilon
using Test

function _summary_parity_grouped_results()
    model = feature_matrix_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
        random_seed = 310,
    )
    fit!(model)
    return _grouped_results_for_postmodel(model)
end

function _nan_aware_approx(lhs, rhs; atol = 1.0e-8, rtol = 1.0e-8)
    return all(isapprox.(lhs, rhs; atol, rtol) .| (isnan.(lhs) .& isnan.(rhs)))
end

function _row_major_values(matrix::AbstractMatrix)
    values = Float64[]
    for row in axes(matrix, 1)
        for column in axes(matrix, 2)
            push!(values, matrix[row, column])
        end
    end
    return values
end

function _metric_summary_values(matrix::AbstractMatrix, metric_names::AbstractVector{<:AbstractString})
    values = Float64[]
    fixture_metric_names = sort(collect(metric_names))
    metric_columns = Dict(name => index for (index, name) in pairs(fixture_metric_names))

    for point in axes(matrix, 1)
        for metric_name in metric_names
            push!(values, matrix[point, metric_columns[metric_name]])
        end
    end
    return values
end

@testset "summary_table follows truthful Phase 7 schemas" begin
    model = feature_matrix_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
        random_seed = 311,
    )
    fit!(model)
    grouped = _grouped_results_for_postmodel(model)
    observed_total = sum(model.data.channels[:, 1])

    contribution_table = summary_table(contribution_results(grouped))
    @test names(contribution_table) ==
        ["observation", "date", "component", "mean", "lower_5", "upper_95"]

    decomposition_table = summary_table(decomposition_results(grouped))
    @test names(decomposition_table) == [
        "component",
        "total_mean",
        "total_lower_5",
        "total_upper_95",
        "share_mean",
        "share_lower_5",
        "share_upper_95",
    ]

    curve_table = summary_table(
        response_curve_results(grouped; channel = "tv", grid = [0.0, observed_total]),
    )
    @test names(curve_table) == [
        "channel",
        "spend",
        "spend_share",
        "observed_total_spend",
        "mean",
        "lower_5",
        "upper_95",
    ]

    metric_table = summary_table(
        metric_results(grouped; channel = "tv", grid = [0.0, observed_total / 2, observed_total]),
    )
    @test names(metric_table) ==
        ["channel", "spend", "metric", "mean", "lower_5", "upper_95"]
end

@testset "summary_table omits date column for non-date observation coordinates" begin
    model = feature_matrix_time_series_model(; random_seed = 312)
    fit!(model)
    grouped = _grouped_results_for_postmodel(model)
    table = summary_table(contribution_results(grouped))

    @test names(table) == ["observation", "component", "mean", "lower_5", "upper_95"]
end

@testset "summary_table parity matches retained Abacus summary semantics on canonical draw-level surfaces" begin
    grouped = _summary_parity_grouped_results()

    contribution_fixture = ABACUS_POSTMODEL_SUMMARY_FIXTURES.contribution
    contribution_results_fixture = ContributionResults(
        grouped.metadata,
        grouped.spec,
        grouped.coordinate_metadata,
        Date.(contribution_fixture.dates),
        zeros(length(contribution_fixture.dates)),
        contribution_fixture.component_names,
        [:intercept, :media, :seasonality],
        contribution_fixture.values,
    )
    contribution_table = summary_table(contribution_results_fixture)
    expected_observation = repeat(collect(1:length(contribution_fixture.dates)); inner = length(contribution_fixture.component_names))
    expected_dates = repeat(Date.(contribution_fixture.dates); inner = length(contribution_fixture.component_names))
    expected_components = repeat(contribution_fixture.component_names; outer = length(contribution_fixture.dates))

    @test contribution_table.observation == expected_observation
    @test contribution_table.date == expected_dates
    @test contribution_table.component == expected_components
    @test contribution_table.mean ≈ vec(permutedims(contribution_fixture.mean, (2, 1)))
    @test contribution_table.lower_5 ≈ vec(permutedims(contribution_fixture.lower_5, (2, 1)))
    @test contribution_table.upper_95 ≈ vec(permutedims(contribution_fixture.upper_95, (2, 1)))

    decomposition_results_fixture = DecompositionResults(
        grouped.metadata,
        grouped.spec,
        grouped.coordinate_metadata,
        contribution_fixture.component_names,
        [:intercept, :media, :seasonality],
        contribution_fixture.totals,
        contribution_fixture.shares,
    )
    decomposition_table = summary_table(decomposition_results_fixture)
    @test decomposition_table.component == contribution_fixture.component_names
    @test decomposition_table.total_mean ≈ vec(contribution_fixture.total_mean)
    @test decomposition_table.total_lower_5 ≈ vec(contribution_fixture.total_lower_5)
    @test decomposition_table.total_upper_95 ≈ vec(contribution_fixture.total_upper_95)
    @test decomposition_table.share_mean ≈ vec(contribution_fixture.share_mean)
    @test decomposition_table.share_lower_5 ≈ vec(contribution_fixture.share_lower_5)
    @test decomposition_table.share_upper_95 ≈ vec(contribution_fixture.share_upper_95)

    response_fixture = ABACUS_POSTMODEL_SUMMARY_FIXTURES.response
    curves = ResponseCurveResults(
        grouped.metadata,
        grouped.spec,
        grouped.coordinate_metadata,
        response_fixture.channel,
        response_fixture.spend_grid,
        response_fixture.spend_grid ./ response_fixture.observed_total_spend,
        response_fixture.observed_total_spend,
        response_fixture.values,
    )
    curve_table = summary_table(curves)

    @test curve_table.channel == fill(response_fixture.channel, length(response_fixture.spend_grid))
    @test curve_table.spend == response_fixture.spend_grid
    @test curve_table.mean ≈ vec(response_fixture.mean)
    @test curve_table.lower_5 ≈ vec(response_fixture.lower_5)
    @test curve_table.upper_95 ≈ vec(response_fixture.upper_95)

    metrics = metric_results(curves)
    @test metrics.metric_names == response_fixture.metric_names
    @test _nan_aware_approx(metrics.values, response_fixture.metric_values)

    metric_table = summary_table(metrics)
    expected_spend = repeat(response_fixture.spend_grid; inner = length(response_fixture.metric_names))
    expected_metric_names = repeat(response_fixture.metric_names; outer = length(response_fixture.spend_grid))

    @test metric_table.channel == fill(response_fixture.channel, length(expected_metric_names))
    @test metric_table.spend == expected_spend
    @test metric_table.metric == expected_metric_names
    @test _nan_aware_approx(
        metric_table.mean,
        _metric_summary_values(response_fixture.metric_mean, response_fixture.metric_names),
    )
    @test _nan_aware_approx(
        metric_table.lower_5,
        _metric_summary_values(response_fixture.metric_lower_5, response_fixture.metric_names),
    )
    @test _nan_aware_approx(
        metric_table.upper_95,
        _metric_summary_values(response_fixture.metric_upper_95, response_fixture.metric_names),
    )
end

@testset "summary_table closes the supported time-series post-model matrix" begin
    weekly_dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5)
    cases = [
        (
            "TS-00",
            feature_matrix_time_series_model(; dates = weekly_dates, random_seed = 313),
        ),
        (
            "TS-01",
            feature_matrix_time_series_model(;
                seasonality = Dict("type" => "fourier", "n_order" => 2),
                dates = weekly_dates,
                random_seed = 314,
            ),
        ),
        (
            "TS-02",
            feature_matrix_time_series_model(;
                seasonality = Dict("type" => "fourier", "n_order" => 2),
                trend = Dict("type" => "linear"),
                dates = weekly_dates,
                random_seed = 315,
            ),
        ),
        (
            "TS-03",
            feature_matrix_time_series_model(;
                seasonality = Dict("type" => "fourier", "n_order" => 2),
                trend = Dict("type" => "linear"),
                events = Dict("columns" => ["promo", "holiday"]),
                event_values = [1.0 0.0; 0.0 1.0; 0.0 0.0; 1.0 0.0; 0.0 0.0; 0.0 1.0],
                dates = weekly_dates,
                random_seed = 316,
            ),
        ),
        (
            "TS-04",
            feature_matrix_time_series_model(;
                seasonality = Dict("type" => "fourier", "n_order" => 2),
                trend = Dict("type" => "changepoint", "n_changepoints" => 3),
                events = Dict(
                    "windows" => [
                        Dict("name" => "promo", "start_date" => "2024-01-08", "end_date" => "2024-01-15"),
                        Dict("name" => "holiday", "start_date" => "2024-01-29"),
                    ],
                ),
                dates = weekly_dates,
                random_seed = 317,
            ),
        ),
        (
            "TS-05",
            feature_matrix_time_series_model(;
                seasonality = Dict("type" => "fourier", "n_order" => 2),
                controls_config = Dict("transform" => "standardize"),
                include_controls = true,
                dates = weekly_dates,
                random_seed = 318,
            ),
        ),
    ]

    for (case_name, model) in cases
        @testset "$(case_name)" begin
            fit!(model)
            grouped = _grouped_results_for_postmodel(model)
            observed_total = sum(model.data.channels[:, 1])

            @test size(summary_table(contribution_results(grouped)), 1) > 0
            @test size(summary_table(decomposition_results(grouped)), 1) > 0
            @test size(
                summary_table(
                    response_curve_results(grouped; channel = "tv", grid = [0.0, observed_total]),
                ),
                1,
            ) > 0
            @test size(
                summary_table(
                    metric_results(
                        grouped;
                        channel = "tv",
                        grid = [0.0, observed_total / 2, observed_total],
                    ),
                ),
                1,
            ) > 0
        end
    end
end

@testset "summary_table supports bounded VI-backed time-series grouped artifacts" begin
    model = sample_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        trend = Dict("type" => "linear"),
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
    )
    vi_config = VariationalConfig(;
        max_iters = 25,
        draws = 12,
        random_seed = 319,
        progressbar = false,
    )
    approximate_fit!(model, vi_config)
    grouped = _grouped_results_for_postmodel(model)
    observed_total = sum(model.data.channels[:, 1])

    @test size(summary_table(contribution_results(grouped)), 1) > 0
    @test size(summary_table(decomposition_results(grouped)), 1) > 0
    @test size(
        summary_table(
            response_curve_results(grouped; channel = "tv", grid = [0.0, observed_total]),
        ),
        1,
    ) > 0
    @test size(
        summary_table(
            metric_results(grouped; channel = "tv", grid = [0.0, observed_total / 2, observed_total]),
        ),
        1,
    ) > 0
end
