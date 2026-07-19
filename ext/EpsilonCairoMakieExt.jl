module EpsilonCairoMakieExt

using CairoMakie
using Epsilon
using Statistics

import Epsilon:
    _BudgetOptimizationResultLike,
    _draw_level_summary,
    _load_pipeline_serialized,
    adstock_curve_plot,
    budget_optimization_plot,
    contribution_area_plot,
    contribution_plot,
    decomposition_plot,
    epsilon_theme,
    observed_fitted_plot,
    posterior_density_plot,
    prior_posterior_plot,
    residual_diagnostics_plot,
    response_curve_plot,
    saturation_curve_plot,
    trace_plot,
    write_plot_bundle

include("../src/plotting/theme.jl")
include("../src/plotting/diagnostics.jl")
include("../src/plotting/postmodel.jl")
include("../src/plotting/optimization.jl")
include("../src/plotting/bundle.jl")

function _save_pipeline_plot_impl!(
        artifact_paths::Dict{String, String},
        warnings::Vector{String},
        stage::AbstractString,
        artifact_key::AbstractString,
        absolute_path::AbstractString,
        relative_path::AbstractString,
        plot_kind::Symbol,
        args...;
        kwargs...,
    )
    figure = _pipeline_plot_figure(plot_kind, args...; kwargs...)
    _save_bundle_figure(absolute_path, figure)
    artifact_paths[String(artifact_key)] = String(relative_path)
    return artifact_paths
end

function _pipeline_plot_figure(plot_kind::Symbol, args...; kwargs...)
    plot_kind === :trace && return trace_plot(args...; kwargs...)
    plot_kind === :observed_fitted && return observed_fitted_plot(args...; kwargs...)
    plot_kind === :fit_timeseries && return _fit_timeseries_plot(args...; kwargs...)
    plot_kind === :posterior_predictive && return _posterior_predictive_plot(args...; kwargs...)
    plot_kind === :residual_diagnostics && return residual_diagnostics_plot(args...; kwargs...)
    plot_kind === :contribution && return contribution_plot(args...; kwargs...)
    plot_kind === :contribution_area && return contribution_area_plot(args...; kwargs...)
    plot_kind === :decomposition && return decomposition_plot(args...; kwargs...)
    plot_kind === :posterior_density && return posterior_density_plot(args...; kwargs...)
    plot_kind === :prior_posterior && return prior_posterior_plot(args...; kwargs...)
    plot_kind === :response_curve && return response_curve_plot(args...; kwargs...)
    plot_kind === :saturation_curve && return saturation_curve_plot(args...; kwargs...)
    plot_kind === :adstock_curve && return adstock_curve_plot(args...; kwargs...)
    plot_kind === :budget_optimization && return budget_optimization_plot(args...; kwargs...)
    plot_kind === :prior_predictive && return _prior_predictive_plot(args...; kwargs...)
    plot_kind === :holdout_validation && return _holdout_validation_plot(args...; kwargs...)
    plot_kind === :residuals_acf && return _residuals_acf_plot(args...; kwargs...)
    plot_kind === :fit_scatter && return _fit_scatter_plot(args...; kwargs...)
    plot_kind === :residuals_hist && return _residuals_hist_plot(args...; kwargs...)
    plot_kind === :residuals_timeseries && return _residuals_timeseries_plot(args...; kwargs...)
    plot_kind === :residuals_vs_fitted && return _residuals_vs_fitted_plot(args...; kwargs...)
    plot_kind === :panel_observed_fitted && return _panel_observed_fitted_plot(args...; kwargs...)
    plot_kind === :panel_fit_timeseries && return _panel_fit_timeseries_plot(args...; kwargs...)
    plot_kind === :panel_posterior_predictive && return _panel_posterior_predictive_plot(args...; kwargs...)
    plot_kind === :panel_residuals_timeseries && return _panel_residuals_timeseries_plot(args...; kwargs...)
    plot_kind === :panel_residual_diagnostics && return _panel_residual_diagnostics_plot(args...; kwargs...)
    plot_kind === :panel_curve && return _panel_curve_plot(args...; kwargs...)
    plot_kind === :panel_contribution && return _panel_contribution_plot(args...; kwargs...)
    plot_kind === :panel_contribution_area && return _panel_contribution_area_plot(args...; kwargs...)
    plot_kind === :panel_decomposition && return _panel_decomposition_plot(args...; kwargs...)
    throw(ArgumentError("unknown pipeline plot kind `$(plot_kind)`"))
end

function _prior_predictive_plot(
        chain,
        data::MMMData,
        target_label::AbstractString,
    )
    predictive_matrix = Epsilon._target_draw_matrix(chain, nobs(data))
    fitted_mean, fitted_lower, fitted_upper = Epsilon._column_summary(predictive_matrix)
    observed = Float64.(collect(data.target))
    x_values = collect(1:nobs(data))
    figure = nothing

    with_theme(epsilon_theme()) do
        figure = Figure(size = (1020, 520))
        ax = Axis(
            figure[1, 1];
            title = "Prior predictive",
            xlabel = "Observation",
            ylabel = target_label,
        )
        band!(
            ax,
            x_values,
            fitted_lower,
            fitted_upper;
            color = RGBAf(_EPSILON_NEUTRAL_COLOR.r, _EPSILON_NEUTRAL_COLOR.g, _EPSILON_NEUTRAL_COLOR.b, 0.18),
            label = "90% prior interval",
        )
        lines!(ax, x_values, fitted_mean; color = _EPSILON_NEUTRAL_COLOR, label = "Prior mean")
        scatter!(ax, x_values, observed; color = _EPSILON_POSITIVE_COLOR, label = "Observed")
        _apply_time_axis_ticks!(ax, data.dates)
        axislegend(ax; position = :rb)
    end

    return figure
end

function _holdout_validation_plot(
        holdout_data::MMMData,
        fitted_mean::AbstractVector,
        fitted_lower::AbstractVector,
        fitted_upper::AbstractVector,
        target_label::AbstractString,
    )
    observed = Float64.(collect(holdout_data.target))
    x_values = collect(1:nobs(holdout_data))
    figure = nothing

    with_theme(epsilon_theme()) do
        figure = Figure(size = (1020, 520))
        ax = Axis(
            figure[1, 1];
            title = "Blocked holdout validation",
            xlabel = "Observation",
            ylabel = target_label,
        )
        band!(
            ax,
            x_values,
            fitted_lower,
            fitted_upper;
            color = RGBAf(_EPSILON_NEUTRAL_COLOR.r, _EPSILON_NEUTRAL_COLOR.g, _EPSILON_NEUTRAL_COLOR.b, 0.18),
            label = "90% posterior interval",
        )
        lines!(ax, x_values, fitted_mean; color = _EPSILON_NEUTRAL_COLOR, label = "Fitted mean")
        scatter!(ax, x_values, observed; color = _EPSILON_POSITIVE_COLOR, label = "Observed")
        _apply_time_axis_ticks!(ax, holdout_data.dates)
        axislegend(ax; position = :rb)
    end

    return figure
end

function _residuals_acf_plot(residuals::AbstractVector)
    max_lag = max(1, min(12, length(residuals) - 1))
    lags = collect(1:max_lag)
    acf_values = [Epsilon._lag_autocorrelation(residuals, lag) for lag in lags]
    figure = nothing

    with_theme(epsilon_theme()) do
        figure = Figure(size = (720, 520))
        ax = Axis(
            figure[1, 1];
            title = "Residual autocorrelation",
            xlabel = "Lag",
            ylabel = "ACF",
        )
        barplot!(ax, lags, acf_values; color = _EPSILON_NEUTRAL_COLOR)
        hlines!(ax, [0.0]; color = _EPSILON_NEGATIVE_COLOR, linestyle = :dash)
    end

    return figure
end

function _fit_scatter_plot(
        observed::AbstractVector,
        fitted_mean::AbstractVector,
        target_label::AbstractString,
    )
    lower = min(minimum(observed), minimum(fitted_mean))
    upper = max(maximum(observed), maximum(fitted_mean))
    figure = nothing

    with_theme(epsilon_theme()) do
        figure = Figure(size = (720, 560))
        ax = Axis(
            figure[1, 1];
            title = "Observed vs fitted",
            xlabel = "Observed $target_label",
            ylabel = "Fitted $target_label",
        )
        lines!(ax, [lower, upper], [lower, upper]; color = _EPSILON_NEUTRAL_COLOR, linestyle = :dash)
        scatter!(ax, observed, fitted_mean; color = _EPSILON_POSITIVE_COLOR)
    end

    return figure
end

function _residuals_hist_plot(residuals::AbstractVector)
    figure = nothing

    with_theme(epsilon_theme()) do
        figure = Figure(size = (720, 520))
        ax = Axis(
            figure[1, 1];
            title = "Residual histogram",
            xlabel = "Residual",
            ylabel = "Count",
        )
        hist!(ax, residuals; bins = max(5, min(20, length(residuals))))
        vlines!(ax, [0.0]; color = _EPSILON_NEGATIVE_COLOR, linestyle = :dash)
    end

    return figure
end

function _residuals_timeseries_plot(dates, residuals::AbstractVector)
    x_values = collect(eachindex(residuals))
    figure = nothing

    with_theme(epsilon_theme()) do
        figure = Figure(size = (1020, 520))
        ax = Axis(
            figure[1, 1];
            title = "Residuals over time",
            xlabel = "Observation",
            ylabel = "Residual",
        )
        hlines!(ax, [0.0]; color = _EPSILON_NEGATIVE_COLOR, linestyle = :dash)
        lines!(ax, x_values, residuals; color = _EPSILON_NEUTRAL_COLOR)
        scatter!(ax, x_values, residuals; color = _EPSILON_NEUTRAL_COLOR)
        _apply_time_axis_ticks!(ax, dates)
    end

    return figure
end

function _panel_observed_fitted_plot(
        data::PanelMMMData,
        observed::AbstractVector,
        fitted_mean::AbstractVector,
        fitted_lower::AbstractVector,
        fitted_upper::AbstractVector,
        target_column::AbstractString,
        ;
        title_prefix::AbstractString = "",
        point_observed::Bool = true,
        fitted_label::AbstractString = "Fitted mean",
    )
    ntime_value, npanels_value = size(data.target)
    x_values = collect(1:ntime_value)
    panel_count = min(npanels_value, 9)
    ncols = min(3, panel_count)
    nrows = ceil(Int, panel_count / ncols)
    figure = nothing

    with_theme(epsilon_theme()) do
        figure = Figure(size = (360 * ncols, 280 * nrows))
        for panel_index in 1:panel_count
            row = cld(panel_index, ncols)
            col = mod1(panel_index, ncols)
            indices = ((panel_index - 1) * ntime_value + 1):(panel_index * ntime_value)
            ax = Axis(
                figure[row, col];
                title = "$(title_prefix)$(data.panel_names[panel_index])",
                xlabel = "Observation",
                ylabel = target_column,
            )
            band!(
                ax,
                x_values,
                fitted_lower[indices],
                fitted_upper[indices];
                color = RGBAf(_EPSILON_NEUTRAL_COLOR.r, _EPSILON_NEUTRAL_COLOR.g, _EPSILON_NEUTRAL_COLOR.b, 0.18),
            )
            if point_observed
                lines!(ax, x_values, fitted_mean[indices]; color = _EPSILON_NEUTRAL_COLOR, label = fitted_label)
                scatter!(ax, x_values, observed[indices]; color = _EPSILON_POSITIVE_COLOR, label = "Observed")
            else
                lines!(ax, x_values, observed[indices]; color = _EPSILON_POSITIVE_COLOR, label = "Observed")
                lines!(ax, x_values, fitted_mean[indices]; color = _EPSILON_NEUTRAL_COLOR, label = fitted_label)
            end
            _apply_time_axis_ticks!(ax, data.dates)
        end
    end

    return figure
end

function _panel_fit_timeseries_plot(
        data::PanelMMMData,
        observed::AbstractVector,
        fitted_mean::AbstractVector,
        fitted_lower::AbstractVector,
        fitted_upper::AbstractVector,
        target_column::AbstractString,
    )
    return _panel_observed_fitted_plot(
        data,
        observed,
        fitted_mean,
        fitted_lower,
        fitted_upper,
        target_column;
        title_prefix = "Fit over time: ",
        point_observed = false,
    )
end

function _panel_posterior_predictive_plot(
        data::PanelMMMData,
        observed::AbstractVector,
        fitted_mean::AbstractVector,
        fitted_lower::AbstractVector,
        fitted_upper::AbstractVector,
        target_column::AbstractString,
    )
    return _panel_observed_fitted_plot(
        data,
        observed,
        fitted_mean,
        fitted_lower,
        fitted_upper,
        target_column;
        title_prefix = "Posterior predictive: ",
        point_observed = true,
        fitted_label = "Predictive mean",
    )
end

function _panel_residuals_timeseries_plot(data::PanelMMMData, residuals::AbstractVector)
    ntime_value, npanels_value = size(data.target)
    x_values = collect(1:ntime_value)
    panel_count = min(npanels_value, 9)
    ncols = min(3, panel_count)
    nrows = ceil(Int, panel_count / ncols)
    figure = nothing

    with_theme(epsilon_theme()) do
        figure = Figure(size = (360 * ncols, 260 * nrows))
        for panel_index in 1:panel_count
            row = cld(panel_index, ncols)
            col = mod1(panel_index, ncols)
            indices = ((panel_index - 1) * ntime_value + 1):(panel_index * ntime_value)
            ax = Axis(
                figure[row, col];
                title = data.panel_names[panel_index],
                xlabel = "Observation",
                ylabel = "Residual",
            )
            hlines!(ax, [0.0]; color = _EPSILON_NEGATIVE_COLOR, linestyle = :dash)
            lines!(ax, x_values, residuals[indices]; color = _EPSILON_NEUTRAL_COLOR)
            scatter!(ax, x_values, residuals[indices]; color = _EPSILON_NEUTRAL_COLOR)
            _apply_time_axis_ticks!(ax, data.dates)
        end
    end

    return figure
end

function _panel_residual_diagnostics_plot(
        data::PanelMMMData,
        residuals::AbstractVector,
        fitted_mean::AbstractVector,
    )
    ntime_value, npanels_value = size(data.target)
    panel_mean_residuals = [
        mean(view(residuals, ((panel - 1) * ntime_value + 1):(panel * ntime_value))) for
            panel in 1:npanels_value
    ]
    figure = nothing

    with_theme(epsilon_theme()) do
        figure = Figure(size = (1180, 700))
        ax_panel = Axis(
            figure[1, 1];
            title = "Mean residual by panel",
            xlabel = "Panel",
            ylabel = "Mean residual",
        )
        barplot!(ax_panel, collect(1:npanels_value), panel_mean_residuals; color = _EPSILON_NEUTRAL_COLOR)
        hlines!(ax_panel, [0.0]; color = _EPSILON_NEGATIVE_COLOR, linestyle = :dash)
        ax_panel.xticks = (collect(1:npanels_value), data.panel_names)

        ax_fitted = Axis(
            figure[1, 2];
            title = "Residual vs fitted",
            xlabel = "Fitted mean",
            ylabel = "Residual",
        )
        scatter!(ax_fitted, fitted_mean, residuals; color = _EPSILON_POSITIVE_COLOR)
        hlines!(ax_fitted, [0.0]; color = _EPSILON_NEGATIVE_COLOR, linestyle = :dash)

        ax_hist = Axis(
            figure[2, 1:2];
            title = "Residual distribution",
            xlabel = "Residual",
            ylabel = "Count",
        )
        hist!(ax_hist, residuals; bins = max(5, min(30, length(residuals))))
        vlines!(ax_hist, [0.0]; color = _EPSILON_NEGATIVE_COLOR, linestyle = :dash)
    end

    return figure
end

function _panel_curve_summary(results)
    ndims(results.values) == 3 ||
        throw(ArgumentError("panel curve plots require values with dimensions (draw, panel, point)"))
    ndraws, npanels_value, npoints = size(results.values)
    matrix = reshape(Float64.(results.values), ndraws * npanels_value, npoints)
    return Epsilon._column_summary(matrix)
end

function _panel_curve_plot(results, title::AbstractString)
    mean_values, lower_values, upper_values = _panel_curve_summary(results)
    x_values = collect(results.spend_share_grid)
    figure = nothing

    with_theme(epsilon_theme()) do
        figure = Figure(size = (980, 560))
        ax = Axis(
            figure[1, 1];
            title,
            xlabel = "Historical spend multiplier",
            ylabel = "Curve value",
        )
        band!(
            ax,
            x_values,
            lower_values,
            upper_values;
            color = RGBAf(_EPSILON_NEUTRAL_COLOR.r, _EPSILON_NEUTRAL_COLOR.g, _EPSILON_NEUTRAL_COLOR.b, 0.18),
            label = "90% interval",
        )
        lines!(ax, x_values, mean_values; color = _EPSILON_NEUTRAL_COLOR, label = results.channel)
        scatter!(ax, x_values, mean_values; color = _EPSILON_POSITIVE_COLOR)
        hlines!(ax, [0.0]; color = _EPSILON_NEGATIVE_COLOR, linestyle = :dash)
        axislegend(ax; position = :rb)
    end

    return figure
end

function _panel_contribution_component_totals(results::ContributionResults)
    ndims(results.values) == 4 ||
        throw(ArgumentError("panel contribution plots require contribution values with dimensions (draw, time, panel, component)"))

    selected = findall(==(:media), results.component_kinds)
    isempty(selected) && (selected = collect(eachindex(results.component_names)))
    totals = Matrix{Float64}(undef, size(results.values, 1), length(selected))
    for (local_index, component_index) in enumerate(selected)
        summed = sum(view(results.values, :, :, :, component_index); dims = (2, 3))
        totals[:, local_index] .= vec(summed)
    end
    return selected, Epsilon._column_summary(totals)
end

function _panel_media_contribution_timeseries(results::ContributionResults)
    ndims(results.values) == 4 ||
        throw(ArgumentError("panel media contribution plots require contribution values with dimensions (draw, time, panel, component)"))

    selected = findall(==(:media), results.component_kinds)
    isempty(selected) && (selected = collect(eachindex(results.component_names)))
    ntime_value = size(results.values, 2)
    means = Matrix{Float64}(undef, ntime_value, length(selected))
    lowers = similar(means)
    uppers = similar(means)
    for (local_index, component_index) in enumerate(selected)
        summed = dropdims(
            sum(view(results.values, :, :, :, component_index); dims = 3);
            dims = 3,
        )
        mean_values, lower_values, upper_values = Epsilon._column_summary(summed)
        means[:, local_index] .= mean_values
        lowers[:, local_index] .= lower_values
        uppers[:, local_index] .= upper_values
    end
    return selected, means, lowers, uppers
end

function _panel_contribution_plot(results::ContributionResults)
    selected, summaries = _panel_contribution_component_totals(results)
    total_mean, total_lower, total_upper = summaries
    x_positions = collect(1:length(selected))
    colors = [_signed_component_color(value) for value in total_mean]
    figure = nothing

    with_theme(epsilon_theme()) do
        figure = Figure(size = (1080, 560))
        ax = Axis(
            figure[1, 1];
            title = "Panel media contributions",
            xlabel = "Component",
            ylabel = "Total contribution",
        )
        barplot!(ax, x_positions, total_mean; color = colors)
        errorbars!(
            ax,
            x_positions,
            total_mean,
            total_mean .- total_lower,
            total_upper .- total_mean;
            whiskerwidth = 14,
            color = :black,
        )
        hlines!(ax, [0.0]; color = _EPSILON_NEGATIVE_COLOR, linestyle = :dash)
        ax.xticks = (x_positions, _component_labels(results.component_names[selected]))
        ax.xticklabelrotation = pi / 8
    end

    return figure
end

function _panel_contribution_area_plot(results::ContributionResults)
    selected, means, lowers, uppers = _panel_media_contribution_timeseries(results)
    x_values = collect(1:size(means, 1))
    figure = nothing

    with_theme(epsilon_theme()) do
        figure = Figure(size = (1120, 620))
        ax = Axis(
            figure[1, 1];
            title = "Panel media contribution over time",
            xlabel = "Observation",
            ylabel = "Contribution",
        )
        for (local_index, component_index) in enumerate(selected)
            color = _component_color(local_index)
            band!(
                ax,
                x_values,
                view(lowers, :, local_index),
                view(uppers, :, local_index);
                color = _transparent_color(color, 0.16),
            )
            lines!(
                ax,
                x_values,
                view(means, :, local_index);
                color = color,
                label = _component_label(results.component_names[component_index]),
            )
        end
        hlines!(ax, [0.0]; color = _EPSILON_NEGATIVE_COLOR, linestyle = :dash)
        _apply_time_axis_ticks!(ax, results.dates)
        length(selected) <= 8 && axislegend(ax; position = :rb)
    end

    return figure
end

function _panel_decomposition_plot(results::DecompositionResults)
    mean_totals, lower_totals, upper_totals = _draw_level_summary(results.totals)
    total_mean = vec(mean_totals)
    total_lower = vec(lower_totals)
    total_upper = vec(upper_totals)
    x_positions = collect(1:length(results.component_names))
    colors = [_signed_component_color(value) for value in total_mean]
    figure = nothing

    with_theme(epsilon_theme()) do
        figure = Figure(size = (1080, 560))
        ax = Axis(
            figure[1, 1];
            title = "Panel decomposition",
            xlabel = "Component",
            ylabel = "Total contribution",
        )
        barplot!(ax, x_positions, total_mean; color = colors)
        errorbars!(
            ax,
            x_positions,
            total_mean,
            total_mean .- total_lower,
            total_upper .- total_mean;
            whiskerwidth = 14,
            color = :black,
        )
        hlines!(ax, [0.0]; color = _EPSILON_NEGATIVE_COLOR, linestyle = :dash)
        ax.xticks = (x_positions, _component_labels(results.component_names))
        ax.xticklabelrotation = pi / 8
    end

    return figure
end

function _residuals_vs_fitted_plot(fitted_mean::AbstractVector, residuals::AbstractVector)
    figure = nothing

    with_theme(epsilon_theme()) do
        figure = Figure(size = (720, 560))
        ax = Axis(
            figure[1, 1];
            title = "Residuals vs fitted",
            xlabel = "Fitted",
            ylabel = "Residual",
        )
        hlines!(ax, [0.0]; color = _EPSILON_NEGATIVE_COLOR, linestyle = :dash)
        scatter!(ax, fitted_mean, residuals; color = _EPSILON_POSITIVE_COLOR)
    end

    return figure
end

end
