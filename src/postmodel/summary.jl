using DataFrames
using Dates
using Statistics

const _SUMMARY_LOWER_PROB = 0.05
const _SUMMARY_UPPER_PROB = 0.95

function _finite_equal_tailed_summary(values::AbstractVector)
    finite_values = Float64[value for value in values if isfinite(value)]
    isempty(finite_values) && return (NaN, NaN, NaN)
    return (
        mean(finite_values),
        quantile(finite_values, _SUMMARY_LOWER_PROB),
        quantile(finite_values, _SUMMARY_UPPER_PROB),
    )
end

function _draw_level_summary(values::AbstractArray)
    ndims(values) >= 2 ||
        throw(ArgumentError("summary_table expects draw-level arrays with at least two dimensions"))

    ndraws = size(values, 1)
    ndraws > 0 || throw(ArgumentError("summary_table requires at least one draw"))

    matrix = reshape(Float64.(values), ndraws, :)
    mean_values = Vector{Float64}(undef, size(matrix, 2))
    lower_values = similar(mean_values)
    upper_values = similar(mean_values)

    for column in axes(matrix, 2)
        summary = _finite_equal_tailed_summary(view(matrix, :, column))
        mean_values[column] = summary[1]
        lower_values[column] = summary[2]
        upper_values[column] = summary[3]
    end

    trailing_dims = Base.tail(size(values))
    return (
        reshape(mean_values, trailing_dims...),
        reshape(lower_values, trailing_dims...),
        reshape(upper_values, trailing_dims...),
    )
end

function _include_summary_date_column(dates)
    isempty(dates) && return false
    return first(dates) isa Union{Date, DateTime}
end

function _panel_summary_axis(metadata::ModelCoordinateMetadata, npanels::Integer)
    axis = _panel_axis_for_summary(metadata, npanels)
    return (
        panel_column = axis.name,
        panel_names = axis.values,
        legacy_panel_column = _legacy_panel_column(metadata),
        coordinate_columns = axis.coordinate_columns,
    )
end

function _panel_axis_for_summary(
        metadata::ModelCoordinateMetadata,
        npanels::Integer,
    )
    if length(metadata.panel_axes) == 1
        axis = panel_axis(metadata)
        length(axis.values) == Int(npanels) && return axis
    end
    return PanelAxis(name = "panel_cell", values = string.(1:Int(npanels)))
end

function _legacy_panel_column(metadata::ModelCoordinateMetadata)
    length(metadata.panel_dims) > 1 && return "panel"
    return nothing
end

function _panel_column_pairs(panel_axis, panels::Vector{String})
    columns = Pair{Symbol, Any}[
        Symbol(panel_axis.panel_column) => panels,
    ]
    if !isnothing(panel_axis.legacy_panel_column)
        push!(columns, Symbol(panel_axis.legacy_panel_column) => panels)
    end
    return columns
end

function summary_table(results::ContributionResults)
    _validate_postmodel_axes(results)
    mean_values, lower_values, upper_values = _draw_level_summary(results.values)
    nobs = size(results.values, 2)
    ncomponents = length(results.component_names)

    if ndims(results.values) == 4
        npanels = size(results.values, 3)
        nrows = nobs * npanels * ncomponents
        panel_axis = _panel_summary_axis(results.coordinate_metadata, npanels)
        panel_names = panel_axis.panel_names
        coordinate_columns = panel_axis.coordinate_columns

        observations = Vector{Int}(undef, nrows)
        panels = Vector{String}(undef, nrows)
        panel_coordinates = [
            column.first => Vector{String}(undef, nrows) for column in coordinate_columns
        ]
        components = Vector{String}(undef, nrows)
        means = Vector{Float64}(undef, nrows)
        lower_5 = Vector{Float64}(undef, nrows)
        upper_95 = Vector{Float64}(undef, nrows)
        row = 1

        for observation in 1:nobs
            for panel in 1:npanels
                for component in 1:ncomponents
                    observations[row] = observation
                    panels[row] = panel_names[panel]
                    for (coordinate_index, column) in enumerate(coordinate_columns)
                        panel_coordinates[coordinate_index].second[row] = column.second[panel]
                    end
                    components[row] = results.component_names[component]
                    means[row] = mean_values[observation, panel, component]
                    lower_5[row] = lower_values[observation, panel, component]
                    upper_95[row] = upper_values[observation, panel, component]
                    row += 1
                end
            end
        end

        if _include_summary_date_column(results.dates)
            date_values = collect(results.dates)
            dates = Vector{eltype(date_values)}(undef, nrows)
            row = 1
            for observation in 1:nobs
                for _ in 1:(npanels * ncomponents)
                    dates[row] = date_values[observation]
                    row += 1
                end
            end
            columns = Pair{Symbol, Any}[
                :observation => observations,
                :date => dates,
            ]
            append!(columns, _panel_column_pairs(panel_axis, panels))
            append!(columns, [Symbol(column.first) => column.second for column in panel_coordinates])
            append!(
                columns,
                Pair{Symbol, Any}[
                    :component => components,
                    :mean => means,
                    :lower_5 => lower_5,
                    :upper_95 => upper_95,
                ],
            )
            return DataFrame(columns)
        end

        columns = Pair{Symbol, Any}[
            :observation => observations,
        ]
        append!(columns, _panel_column_pairs(panel_axis, panels))
        append!(columns, [Symbol(column.first) => column.second for column in panel_coordinates])
        append!(
            columns,
            Pair{Symbol, Any}[
                :component => components,
                :mean => means,
                :lower_5 => lower_5,
                :upper_95 => upper_95,
            ],
        )
        return DataFrame(columns)
    end

    nrows = nobs * ncomponents

    observations = Vector{Int}(undef, nrows)
    components = Vector{String}(undef, nrows)
    means = Vector{Float64}(undef, nrows)
    lower_5 = Vector{Float64}(undef, nrows)
    upper_95 = Vector{Float64}(undef, nrows)
    row = 1

    for observation in 1:nobs
        for component in 1:ncomponents
            observations[row] = observation
            components[row] = results.component_names[component]
            means[row] = mean_values[observation, component]
            lower_5[row] = lower_values[observation, component]
            upper_95[row] = upper_values[observation, component]
            row += 1
        end
    end

    if _include_summary_date_column(results.dates)
        date_values = collect(results.dates)
        dates = Vector{eltype(date_values)}(undef, nrows)
        row = 1
        for observation in 1:nobs
            for _ in 1:ncomponents
                dates[row] = date_values[observation]
                row += 1
            end
        end
        return DataFrame(;
            observation = observations,
            date = dates,
            component = components,
            mean = means,
            lower_5,
            upper_95,
        )
    end

    return DataFrame(;
        observation = observations,
        component = components,
        mean = means,
        lower_5,
        upper_95,
    )
end

function summary_table(results::DecompositionResults)
    _validate_postmodel_axes(results)
    total_mean, total_lower, total_upper = _draw_level_summary(results.totals)
    share_mean, share_lower, share_upper = _draw_level_summary(results.shares)
    return DataFrame(;
        component = copy(results.component_names),
        total_mean = vec(total_mean),
        total_lower_5 = vec(total_lower),
        total_upper_95 = vec(total_upper),
        share_mean = vec(share_mean),
        share_lower_5 = vec(share_lower),
        share_upper_95 = vec(share_upper),
    )
end

function _panel_curve_summary_table(results, mean_values, lower_values, upper_values)
    npanels, npoints = size(mean_values)
    panel_axis = _panel_summary_axis(results.coordinate_metadata, npanels)
    panel_names = panel_axis.panel_names
    coordinate_columns = panel_axis.coordinate_columns

    nrows = npanels * npoints
    panels = Vector{String}(undef, nrows)
    panel_coordinates = [
        column.first => Vector{String}(undef, nrows) for column in coordinate_columns
    ]
    channels = fill(results.channel, nrows)
    deltas = Vector{Float64}(undef, nrows)
    spend = Vector{Float64}(undef, nrows)
    observed_total_spend = Vector{Float64}(undef, nrows)
    means = Vector{Float64}(undef, nrows)
    lower_5 = Vector{Float64}(undef, nrows)
    upper_95 = Vector{Float64}(undef, nrows)
    spend_grid = Matrix{Float64}(results.spend_grid)
    observed_spend = Vector{Float64}(results.observed_total_spend)
    row = 1

    for panel in 1:npanels
        for point in 1:npoints
            panels[row] = panel_names[panel]
            for (coordinate_index, column) in enumerate(coordinate_columns)
                panel_coordinates[coordinate_index].second[row] = column.second[panel]
            end
            deltas[row] = results.spend_share_grid[point]
            spend[row] = spend_grid[panel, point]
            observed_total_spend[row] = observed_spend[panel]
            means[row] = mean_values[panel, point]
            lower_5[row] = lower_values[panel, point]
            upper_95[row] = upper_values[panel, point]
            row += 1
        end
    end

    columns = Pair{Symbol, Any}[]
    append!(columns, _panel_column_pairs(panel_axis, panels))
    append!(columns, [Symbol(column.first) => column.second for column in panel_coordinates])
    append!(
        columns,
        Pair{Symbol, Any}[
            :channel => channels,
            :delta => deltas,
            :spend => spend,
            :observed_total_spend => observed_total_spend,
            :mean => means,
            :lower_5 => lower_5,
            :upper_95 => upper_95,
        ],
    )
    return DataFrame(columns)
end

function summary_table(results::ResponseCurveResults)
    _validate_postmodel_axes(results)
    mean_values, lower_values, upper_values = _draw_level_summary(results.values)
    if ndims(results.values) == 3
        return _panel_curve_summary_table(results, mean_values, lower_values, upper_values)
    end

    npoints = length(results.spend_grid)
    return DataFrame(;
        channel = fill(results.channel, npoints),
        spend = copy(results.spend_grid),
        spend_share = copy(results.spend_share_grid),
        observed_total_spend = fill(results.observed_total_spend, npoints),
        mean = vec(mean_values),
        lower_5 = vec(lower_values),
        upper_95 = vec(upper_values),
    )
end

function summary_table(results::SaturationCurveResults)
    _validate_postmodel_axes(results)
    mean_values, lower_values, upper_values = _draw_level_summary(results.values)
    if ndims(results.values) == 3
        return _panel_curve_summary_table(results, mean_values, lower_values, upper_values)
    end

    npoints = length(results.spend_grid)
    return DataFrame(;
        channel = fill(results.channel, npoints),
        spend = copy(results.spend_grid),
        spend_share = copy(results.spend_share_grid),
        observed_total_spend = fill(results.observed_total_spend, npoints),
        mean = vec(mean_values),
        lower_5 = vec(lower_values),
        upper_95 = vec(upper_values),
    )
end

function summary_table(results::AdstockCurveResults)
    _validate_postmodel_axes(results)
    mean_values, lower_values, upper_values = _draw_level_summary(results.values)
    if ndims(results.values) == 3
        return _panel_curve_summary_table(results, mean_values, lower_values, upper_values)
    end

    npoints = length(results.spend_grid)
    return DataFrame(;
        channel = fill(results.channel, npoints),
        spend = copy(results.spend_grid),
        spend_share = copy(results.spend_share_grid),
        observed_total_spend = fill(results.observed_total_spend, npoints),
        mean = vec(mean_values),
        lower_5 = vec(lower_values),
        upper_95 = vec(upper_values),
    )
end

function summary_table(results::MetricResults)
    _validate_postmodel_axes(results)
    mean_values, lower_values, upper_values = _draw_level_summary(results.values)
    if ndims(results.values) == 4
        npanels, npoints, nmetrics = size(mean_values)
        panel_axis = _panel_summary_axis(results.coordinate_metadata, npanels)
        panel_names = panel_axis.panel_names
        coordinate_columns = panel_axis.coordinate_columns
        nrows = npanels * npoints * nmetrics

        panels = Vector{String}(undef, nrows)
        panel_coordinates = [
            column.first => Vector{String}(undef, nrows) for column in coordinate_columns
        ]
        channels = fill(results.channel, nrows)
        spend = Vector{Float64}(undef, nrows)
        metrics = Vector{String}(undef, nrows)
        means = Vector{Float64}(undef, nrows)
        lower_5 = Vector{Float64}(undef, nrows)
        upper_95 = Vector{Float64}(undef, nrows)
        spend_grid = Matrix{Float64}(results.spend_grid)
        row = 1

        for panel in 1:npanels
            for point in 1:npoints
                for metric in 1:nmetrics
                    panels[row] = panel_names[panel]
                    for (coordinate_index, column) in enumerate(coordinate_columns)
                        panel_coordinates[coordinate_index].second[row] = column.second[panel]
                    end
                    spend[row] = spend_grid[panel, point]
                    metrics[row] = results.metric_names[metric]
                    means[row] = mean_values[panel, point, metric]
                    lower_5[row] = lower_values[panel, point, metric]
                    upper_95[row] = upper_values[panel, point, metric]
                    row += 1
                end
            end
        end

        columns = Pair{Symbol, Any}[]
        append!(columns, _panel_column_pairs(panel_axis, panels))
        append!(columns, [Symbol(column.first) => column.second for column in panel_coordinates])
        append!(
            columns,
            Pair{Symbol, Any}[
                :channel => channels,
                :spend => spend,
                :metric => metrics,
                :mean => means,
                :lower_5 => lower_5,
                :upper_95 => upper_95,
            ],
        )
        return DataFrame(columns)
    end

    npoints = length(results.spend_grid)
    nmetrics = length(results.metric_names)
    nrows = npoints * nmetrics

    channels = fill(results.channel, nrows)
    spend = Vector{Float64}(undef, nrows)
    metrics = Vector{String}(undef, nrows)
    means = Vector{Float64}(undef, nrows)
    lower_5 = Vector{Float64}(undef, nrows)
    upper_95 = Vector{Float64}(undef, nrows)
    row = 1

    for point in 1:npoints
        for metric in 1:nmetrics
            spend[row] = results.spend_grid[point]
            metrics[row] = results.metric_names[metric]
            means[row] = mean_values[point, metric]
            lower_5[row] = lower_values[point, metric]
            upper_95[row] = upper_values[point, metric]
            row += 1
        end
    end

    return DataFrame(;
        channel = channels,
        spend,
        metric = metrics,
        mean = means,
        lower_5,
        upper_95,
    )
end
