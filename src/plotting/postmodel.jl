"""
    contribution_plot(results::ContributionResults; channels=nothing)

Render HDI-aware time-series media contribution plots from a bounded
`ContributionResults` surface.

This Phase 10 surface currently supports only time-series post-model results.
By default it renders all media-channel components. `channels` may be one
channel name or a collection of channel names.
"""
function contribution_plot(results::ContributionResults; channels = nothing)
    _require_time_series_postmodel_plot(results, "contribution_plot")
    selected = _selected_media_component_indices(results; channels, action = "contribution_plot")
    means, lowers, uppers = _contribution_component_summary(results, selected)
    x_values = collect(1:length(results.dates))
    figure = nothing
    axes = Axis[]

    with_theme(epsilon_theme()) do
        figure, axes = _parameter_figure(
            length(selected);
            size = (1100, 300 * ceil(Int, length(selected) / min(2, max(1, length(selected))))),
        )
        for (local_index, component_index) in enumerate(selected)
            ax = axes[local_index]
            component_name = results.component_names[component_index]
            band!(
                ax,
                x_values,
                view(lowers, :, local_index),
                view(uppers, :, local_index);
                color = _transparent_color(_component_color(local_index), 0.18),
                label = "90% interval",
            )
            lines!(
                ax,
                x_values,
                view(means, :, local_index);
                color = _component_color(local_index),
                label = "Mean",
            )
            hlines!(ax, [0.0]; color = _EPSILON_NEGATIVE_COLOR, linestyle = :dash)
            ax.title = "Contribution: $(_component_label(component_name))"
            ax.xlabel = "Observation"
            ax.ylabel = "Contribution"
            _apply_time_axis_ticks!(ax, results.dates)
            local_index == 1 && axislegend(ax; position = :rb)
        end
    end

    return figure
end

"""
    contribution_area_plot(results::ContributionResults; channels=nothing)

Render a stacked additive contribution breakdown through time from
`ContributionResults`.

This Phase 10 surface preserves the additive interpretation of the closed Phase
7 contribution contract. When `channels` selects a subset of media channels,
unselected media contributions are aggregated into an `"media:other"` series
rather than dropped.
"""
function contribution_area_plot(results::ContributionResults; channels = nothing)
    _require_time_series_postmodel_plot(results, "contribution_area_plot")
    series_names, values = _area_plot_series(results; channels, action = "contribution_area_plot")
    x_values = collect(1:length(results.dates))
    figure = nothing

    with_theme(epsilon_theme()) do
        figure = Figure(size = (1120, 620))
        ax = Axis(
            figure[1, 1];
            title = "Contribution breakdown",
            xlabel = "Observation",
            ylabel = "Contribution",
        )
        _stacked_signed_area!(ax, x_values, values, series_names)
        hlines!(ax, [0.0]; color = _EPSILON_NEGATIVE_COLOR, linestyle = :dash)
        _apply_time_axis_ticks!(ax, results.dates)
        axislegend(ax; position = :rb)
    end

    return figure
end

"""
    decomposition_plot(results::DecompositionResults)

Render a bounded decomposition figure in observed target units from
`DecompositionResults`.

This Phase 10 surface currently supports only time-series decomposition
results.
"""
function decomposition_plot(results::DecompositionResults)
    _require_time_series_postmodel_plot(results, "decomposition_plot")
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
            title = "Decomposition",
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

"""
    response_curve_plot(results::ResponseCurveResults)

Render the bounded Phase 7 response-curve surface from `ResponseCurveResults`.

The plot is anchored to the stored total-spend grid in original units and
includes a marginal-response view when at least two spend points are available.
"""
function response_curve_plot(results::ResponseCurveResults)
    _require_time_series_postmodel_plot(results, "response_curve_plot")
    return _curve_family_plot(
        results;
        action = "response_curve_plot",
        title = "Response curve: $(results.channel)",
        ylabel = "Contribution",
        line_label = "Mean response",
        marginal_title = "Marginal response",
        marginal_ylabel = "Incremental response / spend",
        marginal_label = "Mean marginal response",
        line_color = _EPSILON_NEUTRAL_COLOR,
        marginal_color = _EPSILON_POSITIVE_COLOR,
    )
end

"""
    saturation_curve_plot(results::SaturationCurveResults)

Render the bounded Stage 60 saturation-only surface from
`SaturationCurveResults`.
"""
function saturation_curve_plot(results::SaturationCurveResults)
    _require_time_series_postmodel_plot(results, "saturation_curve_plot")
    return _curve_family_plot(
        results;
        action = "saturation_curve_plot",
        title = "Saturation curve: $(results.channel)",
        ylabel = "Contribution",
        line_label = "Mean saturation response",
        marginal_title = "Marginal saturation response",
        marginal_ylabel = "Incremental contribution / spend",
        marginal_label = "Mean marginal saturation response",
        line_color = _EPSILON_NEUTRAL_COLOR,
        marginal_color = _EPSILON_POSITIVE_COLOR,
    )
end

"""
    adstock_curve_plot(results::AdstockCurveResults)

Render the bounded Stage 60 adstock-only surface from `AdstockCurveResults`.
"""
function adstock_curve_plot(results::AdstockCurveResults)
    _require_time_series_postmodel_plot(results, "adstock_curve_plot")
    return _curve_family_plot(
        results;
        action = "adstock_curve_plot",
        title = "Adstock curve: $(results.channel)",
        ylabel = "Carryover",
        line_label = "Mean adstock carryover",
        marginal_title = "Marginal carryover",
        marginal_ylabel = "Incremental carryover / spend",
        marginal_label = "Mean marginal carryover",
        line_color = _EPSILON_NEUTRAL_COLOR,
        marginal_color = _EPSILON_POSITIVE_COLOR,
    )
end

function _require_time_series_postmodel_plot(results, action::AbstractString)
    results.spec.model_kind === :time_series_mmm ||
        throw(
        ArgumentError(
            "$action currently supports only time-series post-model results; panel post-model plotting is unsupported in the bounded Phase 10 surface",
        ),
    )
    return results
end

function _selected_media_component_indices(
        results::ContributionResults;
        channels,
        action::AbstractString,
    )
    media_indices = findall(==(:media), results.component_kinds)
    isempty(media_indices) &&
        throw(ArgumentError("$action requires at least one media contribution component"))
    isnothing(channels) && return media_indices

    selected_channels = _normalize_channel_selection(channels, action)
    selected_indices = Int[]
    for channel in selected_channels
        component_name = "media:$(channel)"
        index = findfirst(==(component_name), results.component_names)
        isnothing(index) &&
            throw(
            ArgumentError(
                "$action requested channel `$(channel)` but it is not present in the contribution results",
            ),
        )
        push!(selected_indices, index)
    end
    return selected_indices
end

function _normalize_channel_selection(channels, action::AbstractString)
    values = if channels isa AbstractString || channels isa Symbol
        (channels,)
    elseif channels isa AbstractVector || channels isa Tuple
        channels
    else
        throw(
            ArgumentError(
                "$action expects `channels` to be `nothing`, one channel name, or a vector/tuple of channel names",
            ),
        )
    end
    normalized = String[String(value) for value in values]
    isempty(normalized) && throw(ArgumentError("$action requires at least one channel"))
    unique!(normalized)
    return normalized
end

function _contribution_component_summary(results::ContributionResults, indices::Vector{Int})
    selected_values = results.values[:, :, indices]
    means, lowers, uppers = _draw_level_summary(selected_values)
    return Float64.(means), Float64.(lowers), Float64.(uppers)
end

function _area_plot_series(
        results::ContributionResults;
        channels,
        action::AbstractString,
    )
    mean_values, _, _ = _draw_level_summary(results.values)
    component_indices = collect(eachindex(results.component_names))
    if isnothing(channels)
        return copy(results.component_names), Float64.(mean_values)
    end

    selected_media = Set(_selected_media_component_indices(results; channels, action))
    series_names = String[]
    series_columns = Vector{Vector{Float64}}()
    other_media = zeros(Float64, size(mean_values, 1))

    for component_index in component_indices
        name = results.component_names[component_index]
        kind = results.component_kinds[component_index]
        column = Float64.(mean_values[:, component_index])
        if kind === :media
            if component_index in selected_media
                push!(series_names, name)
                push!(series_columns, column)
            else
                other_media .+= column
            end
        else
            push!(series_names, name)
            push!(series_columns, column)
        end
    end

    if any(x -> !iszero(x), other_media)
        push!(series_names, "media:other")
        push!(series_columns, other_media)
    end

    return series_names, hcat(series_columns...)
end

function _stacked_signed_area!(
        ax::Axis,
        x_values,
        values::AbstractMatrix,
        labels::Vector{String},
    )
    positive_base = zeros(Float64, size(values, 1))
    negative_base = zeros(Float64, size(values, 1))
    for index in axes(values, 2)
        series = Float64.(values[:, index])
        color = _component_color(index)
        positive_part = max.(series, 0.0)
        negative_part = min.(series, 0.0)
        if any(x -> !iszero(x), positive_part)
            upper = positive_base .+ positive_part
            band!(
                ax,
                x_values,
                positive_base,
                upper;
                color = color,
                label = _component_label(labels[index]),
            )
            positive_base = upper
        end
        if any(x -> !iszero(x), negative_part)
            lower = negative_base .+ negative_part
            band!(ax, x_values, lower, negative_base; color = color)
            negative_base = lower
        end
    end
    return
end

function _marginal_response_summary(results::ResponseCurveResults)
    return _marginal_curve_summary(results)
end

function _marginal_curve_summary(results)
    length(results.spend_grid) >= 2 || return nothing
    delta_spend = diff(results.spend_grid)
    delta_spend .= Float64.(delta_spend)
    marginal_values = diff(results.values; dims = 2) ./ reshape(delta_spend, 1, :)
    means, lowers, uppers = _draw_level_summary(marginal_values)
    midpoints = (results.spend_grid[1:(end - 1)] .+ results.spend_grid[2:end]) ./ 2
    return (
        midpoints,
        vec(Float64.(means)),
        vec(Float64.(lowers)),
        vec(Float64.(uppers)),
    )
end

function _curve_family_plot(
        results;
        action::AbstractString,
        title::AbstractString,
        ylabel::AbstractString,
        line_label::AbstractString,
        marginal_title::AbstractString,
        marginal_ylabel::AbstractString,
        marginal_label::AbstractString,
        line_color,
        marginal_color,
    )
    response_mean, response_lower, response_upper = _draw_level_summary(results.values)
    mean_response = vec(response_mean)
    lower_response = vec(response_lower)
    upper_response = vec(response_upper)
    marginal = _marginal_curve_summary(results)
    figure = nothing

    with_theme(epsilon_theme()) do
        has_marginal = !isnothing(marginal)
        figure = Figure(size = has_marginal ? (1120, 700) : (980, 520))
        ax_response = Axis(
            figure[1, 1];
            title,
            xlabel = "Total spend",
            ylabel,
        )
        band!(
            ax_response,
            results.spend_grid,
            lower_response,
            upper_response;
            color = RGBAf(_EPSILON_NEUTRAL_COLOR.r, _EPSILON_NEUTRAL_COLOR.g, _EPSILON_NEUTRAL_COLOR.b, 0.18),
            label = "90% interval",
        )
        lines!(
            ax_response,
            results.spend_grid,
            mean_response;
            color = line_color,
            label = line_label,
        )
        vlines!(
            ax_response,
            [results.observed_total_spend];
            color = _EPSILON_POSITIVE_COLOR,
            linestyle = :dash,
            label = "Observed spend",
        )
        axislegend(ax_response; position = :rb)

        if has_marginal
            midpoints, marginal_mean, marginal_lower, marginal_upper = marginal
            ax_marginal = Axis(
                figure[2, 1];
                title = marginal_title,
                xlabel = "Total spend",
                ylabel = marginal_ylabel,
            )
            band!(
                ax_marginal,
                midpoints,
                marginal_lower,
                marginal_upper;
                color = RGBAf(
                    marginal_color.r,
                    marginal_color.g,
                    marginal_color.b,
                    0.18,
                ),
                label = "90% interval",
            )
            lines!(
                ax_marginal,
                midpoints,
                marginal_mean;
                color = marginal_color,
                label = marginal_label,
            )
            axislegend(ax_marginal; position = :rb)
        end
    end

    return figure
end

function _component_color(index::Integer)
    return _EPSILON_CATEGORICAL_PALETTE[((Int(index) - 1) % length(_EPSILON_CATEGORICAL_PALETTE)) + 1]
end

function _transparent_color(color, alpha::Real)
    rgb = RGBf(color)
    return RGBAf(rgb.r, rgb.g, rgb.b, Float32(alpha))
end

function _signed_component_color(value::Real)
    return value >= 0 ? _EPSILON_POSITIVE_COLOR : _EPSILON_NEGATIVE_COLOR
end

function _component_label(name::AbstractString)
    return replace(String(name), ':' => ' ')
end

function _component_labels(names::Vector{String})
    return [_component_label(name) for name in names]
end
