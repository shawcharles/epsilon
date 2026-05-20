using CairoMakie
using Dates
using Epsilon
using Test

function _plot_axes(figure)
    return [content for content in figure.content if content isa Axis]
end

function _assert_plot_saves(figure, stem::AbstractString)
    mktempdir() do directory
        for extension in ("png", "svg", "pdf")
            path = joinpath(directory, "$(stem).$(extension)")
            save(path, figure)
            @test isfile(path)
        end
    end
end

@testset "epsilon_theme returns a Makie Theme" begin
    @test epsilon_theme() isa Theme
end

@testset "trace_plot returns a Figure for MCMC-backed grouped inference" begin
    model = sample_multichain_time_series_model(; cores = 1)
    fit!(model)
    grouped = inference_results(model; include_prior = true, include_prior_predictive = true)

    figure = trace_plot(grouped; max_parameters = 3)
    axes = _plot_axes(figure)

    @test figure isa Figure
    @test length(axes) == 3
    @test [axes[1].title[], axes[2].title[], axes[3].title[]] ==
          ["alpha[1]", "alpha[2]", "beta_controls[1]"]
    _assert_plot_saves(figure, "trace")
end

@testset "trace_plot rejects VI-backed grouped inference honestly" begin
    model = sample_time_series_model()
    approximate_fit!(
        model,
        VariationalConfig(; max_iters = 5, draws = 6, random_seed = 31, progressbar = false),
    )
    grouped = inference_results(model; include_prior = true, include_prior_predictive = true)

    err = try
        trace_plot(grouped)
        nothing
    catch caught
        caught
    end

    @test err isa ArgumentError
    @test occursin("MCMC-backed", sprint(showerror, err))
end

@testset "posterior_density_plot supports grouped VI posterior draws" begin
    model = sample_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        trend = Dict("type" => "linear"),
        events = Dict("columns" => ["promo", "holiday"]),
        controls_config = Dict("transform" => "standardize"),
        event_values = [1.0 0.0; 0.0 1.0; 0.0 0.0; 1.0 0.0; 0.0 0.0; 0.0 1.0],
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
    )
    approximate_fit!(
        model,
        VariationalConfig(; max_iters = 5, draws = 6, random_seed = 37, progressbar = false),
    )
    grouped = inference_results(model; include_prior = true, include_prior_predictive = true)

    figure = posterior_density_plot(grouped; max_parameters = 2)
    axes = _plot_axes(figure)

    @test figure isa Figure
    @test length(axes) == 2
    @test [axes[1].title[], axes[2].title[]] == ["alpha[1]", "alpha[2]"]
    _assert_plot_saves(figure, "posterior_density")
end

@testset "prior_posterior_plot requires grouped prior draws" begin
    model = sample_results_model()
    grouped = inference_results(model; include_prior = true, include_prior_predictive = true)
    figure = prior_posterior_plot(grouped; parameter = :intercept)
    axes = _plot_axes(figure)

    @test figure isa Figure
    @test length(axes) == 1
    @test axes[1].title[] == "Prior vs posterior: intercept"
    _assert_plot_saves(figure, "prior_posterior")

    no_prior = inference_results(
        model;
        include_prior = false,
        include_posterior_predictive = false,
        include_prior_predictive = false,
    )
    err = try
        prior_posterior_plot(no_prior; parameter = :intercept)
        nothing
    catch caught
        caught
    end

    @test err isa ArgumentError
    @test occursin("InferenceResults.prior", sprint(showerror, err))
end

@testset "observed_fitted_plot and residual_diagnostics_plot support time-series grouped inference" begin
    model = sample_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        trend = Dict("type" => "linear"),
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
    )
    fit!(model)
    grouped = inference_results(model; include_prior = true, include_prior_predictive = true)

    observed_fitted = observed_fitted_plot(grouped)
    residuals = residual_diagnostics_plot(grouped)

    @test observed_fitted isa Figure
    @test residuals isa Figure
    @test length(_plot_axes(observed_fitted)) == 1
    @test length(_plot_axes(residuals)) == 3
    @test _plot_axes(observed_fitted)[1].title[] == "Observed vs fitted"
    @test _plot_axes(residuals)[1].title[] == "Residual through time"
    _assert_plot_saves(observed_fitted, "observed_fitted")
    _assert_plot_saves(residuals, "residual_diagnostics")
end

@testset "time-series diagnostic plots reject panel grouped inference honestly" begin
    model = sample_panel_model()
    fit!(model)
    grouped = inference_results(model; include_prior = true, include_prior_predictive = true)

    observed_fitted_error = try
        observed_fitted_plot(grouped)
        nothing
    catch caught
        caught
    end
    residual_error = try
        residual_diagnostics_plot(grouped)
        nothing
    catch caught
        caught
    end

    @test observed_fitted_error isa ArgumentError
    @test residual_error isa ArgumentError
    @test occursin("time-series", sprint(showerror, observed_fitted_error))
    @test occursin("time-series", sprint(showerror, residual_error))
end
