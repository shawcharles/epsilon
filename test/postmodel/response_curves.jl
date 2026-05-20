using Dates
using Epsilon
using Test

function _grouped_results_for_response_curves(model; new_data = model.data)
    return inference_results(
        model;
        new_data,
        include_prior = false,
        include_posterior_predictive = false,
        include_prior_predictive = false,
    )
end

function _metric_index(results::MetricResults, name::AbstractString)
    index = findfirst(==(String(name)), results.metric_names)
    isnothing(index) && error("missing marketing metric $(name)")
    return index
end

@testset "response_curve_results supports TS-00 media-only grouped artifacts" begin
    model = feature_matrix_time_series_model(; random_seed = 211)
    fit!(model)
    grouped = _grouped_results_for_response_curves(model)
    observed_total = sum(model.data.channels[:, 1])
    grid = [0.0, observed_total / 2, observed_total, observed_total * 1.5]
    results = response_curve_results(grouped; channel = "tv", grid)
    saturation = saturation_curve_results(grouped; channel = "tv", grid)
    adstock = adstock_curve_results(grouped; channel = "tv", grid)

    @test results isa ResponseCurveResults
    @test saturation isa SaturationCurveResults
    @test adstock isa AdstockCurveResults
    @test results.channel == "tv"
    @test results.spend_grid == grid
    @test results.spend_share_grid ≈ [0.0, 0.5, 1.0, 1.5]
    @test results.observed_total_spend ≈ observed_total
    @test size(results.values) == (model.sampler_config.draws, length(grid))
    @test size(saturation.values) == (model.sampler_config.draws, length(grid))
    @test size(adstock.values) == (model.sampler_config.draws, length(grid))
    @test results.values[:, 1] ≈ zeros(model.sampler_config.draws)
    @test saturation.values[:, 1] ≈ zeros(model.sampler_config.draws)
    @test adstock.values[:, 1] ≈ zeros(model.sampler_config.draws)
    @test all(isfinite, results.values)
    @test all(isfinite, saturation.values)
    @test all(isfinite, adstock.values)
end

@testset "response_curve_results supports TS-03 TS-04 and TS-05 grouped artifacts" begin
    manual_model = feature_matrix_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        trend = Dict("type" => "linear"),
        events = Dict("columns" => ["promo", "holiday"]),
        event_values = [1.0 0.0; 0.0 1.0; 0.0 0.0; 1.0 0.0; 0.0 0.0; 0.0 1.0],
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
        random_seed = 212,
    )
    fit!(manual_model)
    manual_grouped = _grouped_results_for_response_curves(manual_model)
    manual_total = sum(manual_model.data.channels[:, 2])
    manual_curve = response_curve_results(
        manual_grouped;
        channel = "search",
        grid = [0.0, manual_total],
    )

    @test size(manual_curve.values) == (manual_model.sampler_config.draws, 2)
    @test manual_curve.values[:, 1] ≈ zeros(manual_model.sampler_config.draws)

    changepoint_model = feature_matrix_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        trend = Dict("type" => "changepoint", "n_changepoints" => 3),
        events = Dict(
            "windows" => [
                Dict("name" => "promo", "start_date" => "2024-01-08", "end_date" => "2024-01-15"),
                Dict("name" => "holiday", "start_date" => "2024-01-29"),
            ],
        ),
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
        random_seed = 213,
    )
    fit!(changepoint_model)
    changepoint_grouped = _grouped_results_for_response_curves(changepoint_model)
    changepoint_total = sum(changepoint_model.data.channels[:, 1])
    changepoint_curve = response_curve_results(
        changepoint_grouped;
        channel = "tv",
        grid = [0.0, changepoint_total / 2, changepoint_total],
    )

    @test size(changepoint_curve.values) == (changepoint_model.sampler_config.draws, 3)

    standardized_model = feature_matrix_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        controls_config = Dict("transform" => "standardize"),
        include_controls = true,
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
        random_seed = 214,
    )
    fit!(standardized_model)

    new_data = MMMData(
        dates = Date(2024, 2, 12):Day(7):Date(2024, 3, 4),
        target = [4.5, 5.5, 6.5, 7.5],
        channels = [1.0 0.75; 1.5 1.0; 2.0 1.25; 2.5 1.5],
        channel_names = ["tv", "search"],
        controls = [0.1; 0.2; 0.3; 0.4][:, :],
        control_names = ["price_index"],
    )
    standardized_grouped = _grouped_results_for_response_curves(
        standardized_model;
        new_data,
    )
    standardized_total = sum(new_data.channels[:, 1])
    standardized_curve = response_curve_results(
        standardized_grouped;
        channel = "tv",
        grid = [0.0, standardized_total],
    )

    @test standardized_curve.observed_total_spend ≈ standardized_total
    @test size(standardized_curve.values) == (standardized_model.sampler_config.draws, 2)
end

@testset "response_curve_results supports Michaelis-Menten media replay" begin
    model = sample_time_series_model(; saturation_type = "michaelis_menten")
    fit!(model)
    grouped = _grouped_results_for_response_curves(model)
    observed_total = sum(model.data.channels[:, 1])
    results = response_curve_results(grouped; channel = "tv", grid = [0.0, observed_total])
    saturation = saturation_curve_results(grouped; channel = "tv", grid = [0.0, observed_total])

    @test results isa ResponseCurveResults
    @test saturation isa SaturationCurveResults
    @test size(results.values) == (model.sampler_config.draws, 2)
    @test size(saturation.values) == (model.sampler_config.draws, 2)
    @test all(isfinite, results.values)
    @test all(isfinite, saturation.values)
end

@testset "response_curve_results rejects grouped artifacts missing beta_media outside Michaelis-Menten" begin
    model = sample_time_series_model()
    fit!(model)
    grouped = _grouped_results_for_response_curves(model)
    keep = filter(!=(Symbol("beta_media[1]")), names(grouped.posterior, :parameters))
    bad_grouped = InferenceResults(
        grouped.metadata,
        grouped.spec;
        posterior = grouped.posterior[keep],
        prior = grouped.prior,
        posterior_predictive = grouped.posterior_predictive,
        prior_predictive = grouped.prior_predictive,
        sample_stats = grouped.sample_stats,
        observed_data = grouped.observed_data,
    )

    @test_throws ArgumentError response_curve_results(
        bad_grouped;
        channel = "tv",
        grid = [0.0, sum(model.data.channels[:, 1])],
    )
    @test_throws ArgumentError saturation_curve_results(
        bad_grouped;
        channel = "tv",
        grid = [0.0, sum(model.data.channels[:, 1])],
    )
end

@testset "metric_results supports bounded MCMC and VI grouped artifacts" begin
    model = feature_matrix_time_series_model(; random_seed = 215)
    fit!(model)
    grouped = _grouped_results_for_response_curves(model)
    observed_total = sum(model.data.channels[:, 1])
    grid = [0.0, observed_total / 2, observed_total, observed_total * 1.5]
    metrics = metric_results(grouped; channel = "tv", grid)

    @test metrics isa MetricResults
    @test metrics.channel == "tv"
    @test metrics.metric_names == ["roas", "mroas", "cpa", "mcpa"]
    @test metrics.default_metric == :roas
    @test size(metrics.values) == (model.sampler_config.draws, length(grid), 4)
    @test all(isnan, metrics.values[:, 1, _metric_index(metrics, "roas")])
    @test all(isnan, metrics.values[:, 1, _metric_index(metrics, "cpa")])

    roas = metrics.values[:, 2:end, _metric_index(metrics, "roas")]
    cpa = metrics.values[:, 2:end, _metric_index(metrics, "cpa")]
    @test roas .* cpa ≈ ones(size(roas))

    mroas = metrics.values[:, :, _metric_index(metrics, "mroas")]
    mcpa = metrics.values[:, :, _metric_index(metrics, "mcpa")]
    finite_mask = isfinite.(mroas) .& isfinite.(mcpa)
    @test all((mroas .* mcpa)[finite_mask] .≈ 1.0)

    vi_model = sample_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        trend = Dict("type" => "linear"),
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
    )
    vi_config = VariationalConfig(;
        max_iters = 25,
        draws = 12,
        random_seed = 216,
        progressbar = false,
    )
    approximate_fit!(vi_model, vi_config)
    vi_grouped = _grouped_results_for_response_curves(vi_model)
    vi_total = sum(vi_model.data.channels[:, 2])
    vi_metrics = metric_results(
        vi_grouped;
        channel = "search",
        grid = [0.0, vi_total / 2, vi_total],
    )

    @test size(vi_metrics.values) == (vi_config.draws, 3, 4)
end

@testset "metric_results defaults to CPA semantics for conversion targets" begin
    model = sample_time_series_model(; target_type = "conversion")
    fit!(model)
    grouped = _grouped_results_for_response_curves(model)
    observed_total = sum(model.data.channels[:, 1])
    metrics = metric_results(grouped; channel = "tv", grid = [0.0, observed_total / 2, observed_total])

    @test metrics.default_metric == :cpa
end

@testset "response curves and metrics reject unsupported artifacts and malformed inputs" begin
    model = feature_matrix_time_series_model(; random_seed = 217)
    fit!(model)
    grouped = _grouped_results_for_response_curves(model)

    @test_throws ArgumentError response_curve_results(grouped; channel = "radio", grid = [0.0, 1.0])
    @test_throws ArgumentError response_curve_results(grouped; channel = "tv", grid = [0.0, 1.0, 1.0])
    @test_throws ArgumentError saturation_curve_results(grouped; channel = "radio", grid = [0.0, 1.0])
    adstock_single = adstock_curve_results(grouped; channel = "tv", grid = [1.0])
    @test adstock_single isa AdstockCurveResults
    @test size(adstock_single.values) == (model.sampler_config.draws, 1)
    @test_throws ArgumentError metric_results(grouped; channel = "tv", grid = [1.0])

    panel = sample_panel_model()
    fit!(panel)
    panel_grouped = _grouped_results_for_response_curves(panel)
    @test_throws ArgumentError response_curve_results(panel_grouped; channel = "tv", grid = [0.0, 1.0])
    @test_throws ArgumentError saturation_curve_results(panel_grouped; channel = "tv", grid = [0.0, 1.0])
    @test_throws ArgumentError adstock_curve_results(panel_grouped; channel = "tv", grid = [0.0, 1.0])
    @test_throws ArgumentError metric_results(panel_grouped; channel = "tv", grid = [0.0, 1.0])
end
