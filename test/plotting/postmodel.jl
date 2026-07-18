using Dates
using Epsilon
using Test

@testset "contribution_plot renders HDI-aware media time-series outputs" begin
    model = feature_matrix_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        trend = Dict("type" => "linear"),
        events = Dict("columns" => ["promo", "holiday"]),
        event_values = [1.0 0.0; 0.0 1.0; 0.0 0.0; 1.0 0.0; 0.0 0.0; 0.0 1.0],
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
        random_seed = 230,
    )
    fit!(model)
    results = contribution_results(_grouped_results_for_postmodel(model))

    figure = contribution_plot(results)
    filtered = contribution_plot(results; channels = "tv")
    axes = _plot_axes(figure)
    filtered_axes = _plot_axes(filtered)

    @test figure isa Figure
    @test filtered isa Figure
    @test length(axes) == 2
    @test [axes[1].title[], axes[2].title[]] == ["Contribution: media tv", "Contribution: media search"]
    @test length(filtered_axes) == 1
    @test filtered_axes[1].title[] == "Contribution: media tv"
    _assert_plot_saves(figure, "contribution_plot")
end

@testset "contribution_area_plot preserves additive contribution semantics" begin
    model = feature_matrix_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        controls_config = Dict("transform" => "standardize"),
        include_controls = true,
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
        random_seed = 231,
    )
    fit!(model)
    results = contribution_results(_grouped_results_for_postmodel(model))

    figure = contribution_area_plot(results; channels = ["tv"])
    axes = _plot_axes(figure)

    @test figure isa Figure
    @test length(axes) == 1
    @test axes[1].title[] == "Contribution breakdown"
    _assert_plot_saves(figure, "contribution_area_plot")
end

@testset "decomposition_plot stays in observed target units" begin
    model = feature_matrix_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        trend = Dict("type" => "changepoint", "n_changepoints" => 3),
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
        random_seed = 232,
    )
    fit!(model)
    results = decomposition_results(_grouped_results_for_postmodel(model))

    figure = decomposition_plot(results)
    axes = _plot_axes(figure)

    @test figure isa Figure
    @test length(axes) == 1
    @test axes[1].title[] == "Decomposition"
    @test axes[1].ylabel[] == "Total contribution"
    _assert_plot_saves(figure, "decomposition_plot")
end

@testset "response_curve_plot supports bounded MCMC and VI post-model rows" begin
    mcmc_model = feature_matrix_time_series_model(; random_seed = 233)
    fit!(mcmc_model)
    observed_total = sum(mcmc_model.data.channels[:, 1])
    mcmc_curve = response_curve_results(
        _grouped_results_for_response_curves(mcmc_model);
        channel = "tv",
        grid = [0.0, observed_total / 2, observed_total, observed_total * 1.5],
    )
    mcmc_saturation = saturation_curve_results(
        _grouped_results_for_response_curves(mcmc_model);
        channel = "tv",
        grid = [0.0, observed_total / 2, observed_total, observed_total * 1.5],
    )
    mcmc_adstock = adstock_curve_results(
        _grouped_results_for_response_curves(mcmc_model);
        channel = "tv",
        grid = [0.0, observed_total / 2, observed_total, observed_total * 1.5],
    )

    mcmc_figure = response_curve_plot(mcmc_curve)
    mcmc_axes = _plot_axes(mcmc_figure)
    @test mcmc_figure isa Figure
    @test length(mcmc_axes) == 2
    @test mcmc_axes[1].title[] == "Response curve: tv"
    @test mcmc_axes[2].title[] == "Marginal response"
    _assert_plot_saves(mcmc_figure, "response_curve_plot")

    saturation_figure = saturation_curve_plot(mcmc_saturation)
    saturation_axes = _plot_axes(saturation_figure)
    @test saturation_figure isa Figure
    @test length(saturation_axes) == 2
    @test saturation_axes[1].title[] == "Saturation curve: tv"
    _assert_plot_saves(saturation_figure, "saturation_curve_plot")

    adstock_figure = adstock_curve_plot(mcmc_adstock)
    adstock_axes = _plot_axes(adstock_figure)
    @test adstock_figure isa Figure
    @test length(adstock_axes) == 2
    @test adstock_axes[1].title[] == "Adstock curve: tv"
    _assert_plot_saves(adstock_figure, "adstock_curve_plot")

end

@testset "post-model plotting rejects panel-shaped results honestly" begin
    metadata = ModelArtifactMetadata(
        1,
        epsilon_version(),
        VERSION,
        "2026-04-23T00:00:00Z",
        "PanelMMM",
        :turing,
        :fit,
    )
    coordinate_metadata = ModelCoordinateMetadata(
        "time",
        ("geo",),
        Dict("time" => ["1", "2"], "geo" => ["north", "south"]),
        Dict("target" => ("time", "geo")),
    )
    spec = MMMModelSpec(
        :panel_mmm,
        2,
        1,
        0,
        ("geo",),
        coordinate_metadata,
        "revenue",
        "revenue",
        ["tv"],
        String[],
        Dict("tv" => 1),
        Dict{String, Int}(),
        Float64[],   # channel_scale: deferred for panel
        1.0,         # target_scale: deferred for panel
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
    )

    contribution_like = ContributionResults(
        metadata,
        spec,
        coordinate_metadata,
        1:2,
        [1.0, 2.0],
        ["intercept", "media:tv"],
        [:intercept, :media],
        ones(3, 2, 2),
    )
    decomposition_like = DecompositionResults(
        metadata,
        spec,
        coordinate_metadata,
        ["intercept", "media:tv"],
        [:intercept, :media],
        ones(3, 2),
        fill(0.5, 3, 2),
    )
    curve_like = ResponseCurveResults(
        metadata,
        spec,
        coordinate_metadata,
        "tv",
        [0.0, 1.0],
        [0.0, 1.0],
        1.0,
        ones(3, 2),
    )
    saturation_like = SaturationCurveResults(
        metadata,
        spec,
        coordinate_metadata,
        "tv",
        [0.0, 1.0],
        [0.0, 1.0],
        1.0,
        ones(3, 2),
    )
    adstock_like = AdstockCurveResults(
        metadata,
        spec,
        coordinate_metadata,
        "tv",
        [0.0, 1.0],
        [0.0, 1.0],
        1.0,
        ones(3, 2),
    )

    @test_throws ArgumentError contribution_plot(contribution_like)
    @test_throws ArgumentError contribution_area_plot(contribution_like)
    @test_throws ArgumentError decomposition_plot(decomposition_like)
    @test_throws ArgumentError response_curve_plot(curve_like)
    @test_throws ArgumentError saturation_curve_plot(saturation_like)
    @test_throws ArgumentError adstock_curve_plot(adstock_like)
end
