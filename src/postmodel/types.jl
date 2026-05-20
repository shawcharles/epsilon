"""
    ContributionResults

Typed draw-level additive contribution surface derived from grouped
`InferenceResults`.

For time-series models, `values` has dimensions `(draw, observation,
component)`. For bounded panel replay, `values` has dimensions
`(draw, time, panel, component)`, where multidimensional panels are represented
on the deterministic flat panel-cell axis. Panel summaries always expose the
fixed `panel_cell` axis plus the declared coordinate columns carried by
`ModelCoordinateMetadata.panel_axes`.
"""
struct ContributionResults{D, T, A}
    metadata::ModelArtifactMetadata
    spec::MMMModelSpec
    coordinate_metadata::ModelCoordinateMetadata
    dates::D
    observed_target::T
    component_names::Vector{String}
    component_kinds::Vector{Symbol}
    values::A
end

function Base.:(==)(lhs::ContributionResults, rhs::ContributionResults)
    return lhs.metadata == rhs.metadata &&
        lhs.spec == rhs.spec &&
        lhs.coordinate_metadata == rhs.coordinate_metadata &&
        lhs.dates == rhs.dates &&
        lhs.observed_target == rhs.observed_target &&
        lhs.component_names == rhs.component_names &&
        lhs.component_kinds == rhs.component_kinds &&
        lhs.values == rhs.values
end

"""
    DecompositionResults

Typed draw-level additive decomposition surface derived from
`ContributionResults`.

`totals` and `shares` are two-dimensional arrays with dimensions `(draw,
component)`. Time-series and panel decomposition artifacts intentionally share
this axis order because panel contributions are aggregated over time and flat
panel cells before component shares are computed.
"""
struct DecompositionResults{A, B}
    metadata::ModelArtifactMetadata
    spec::MMMModelSpec
    coordinate_metadata::ModelCoordinateMetadata
    component_names::Vector{String}
    component_kinds::Vector{Symbol}
    totals::A
    shares::B
end

function Base.:(==)(lhs::DecompositionResults, rhs::DecompositionResults)
    return lhs.metadata == rhs.metadata &&
        lhs.spec == rhs.spec &&
        lhs.coordinate_metadata == rhs.coordinate_metadata &&
        lhs.component_names == rhs.component_names &&
        lhs.component_kinds == rhs.component_kinds &&
        lhs.totals == rhs.totals &&
        lhs.shares == rhs.shares
end

"""
    ResponseCurveResults

Typed draw-level counterfactual response surface for one media channel derived
from grouped `InferenceResults`.

For time-series models, `values` has dimensions `(draw, spend_point)` and
stores total channel contribution in observed target units for each requested
total-spend point. For bounded panel replay, `values` has dimensions
`(draw, panel, spend_point)`; the spend grid is a panel-by-spend-point matrix
generated from a shared historical-scaling `delta_grid`. The `delta_grid`
values are historical spend multipliers, not absolute spend values.
"""
struct ResponseCurveResults{G, H, O, A}
    metadata::ModelArtifactMetadata
    spec::MMMModelSpec
    coordinate_metadata::ModelCoordinateMetadata
    channel::String
    spend_grid::G
    spend_share_grid::H
    observed_total_spend::O
    values::A
end

function Base.:(==)(lhs::ResponseCurveResults, rhs::ResponseCurveResults)
    return lhs.metadata == rhs.metadata &&
        lhs.spec == rhs.spec &&
        lhs.coordinate_metadata == rhs.coordinate_metadata &&
        lhs.channel == rhs.channel &&
        lhs.spend_grid == rhs.spend_grid &&
        lhs.spend_share_grid == rhs.spend_share_grid &&
        lhs.observed_total_spend == rhs.observed_total_spend &&
        lhs.values == rhs.values
end

"""
    SaturationCurveResults

Typed draw-level saturation-only surface for one media channel derived from
grouped `InferenceResults`.

For time-series models, `values` has dimensions `(draw, spend_point)`. For
bounded panel replay, `values` has dimensions `(draw, panel, spend_point)` and
uses the same shared historical-scaling delta grid as
`ResponseCurveResults`. The panel `spend_grid` axis order is always
`(panel, spend_point)`.
"""
struct SaturationCurveResults{G, H, O, A}
    metadata::ModelArtifactMetadata
    spec::MMMModelSpec
    coordinate_metadata::ModelCoordinateMetadata
    channel::String
    spend_grid::G
    spend_share_grid::H
    observed_total_spend::O
    values::A
end

function Base.:(==)(lhs::SaturationCurveResults, rhs::SaturationCurveResults)
    return lhs.metadata == rhs.metadata &&
        lhs.spec == rhs.spec &&
        lhs.coordinate_metadata == rhs.coordinate_metadata &&
        lhs.channel == rhs.channel &&
        lhs.spend_grid == rhs.spend_grid &&
        lhs.spend_share_grid == rhs.spend_share_grid &&
        lhs.observed_total_spend == rhs.observed_total_spend &&
        lhs.values == rhs.values
end

"""
    AdstockCurveResults

Typed draw-level adstock-only surface for one media channel derived from
grouped `InferenceResults`.

For time-series models, `values` has dimensions `(draw, spend_point)`. For
bounded panel replay, `values` has dimensions `(draw, panel, spend_point)` and
uses the same shared historical-scaling delta grid as
`ResponseCurveResults`. The panel `spend_grid` axis order is always
`(panel, spend_point)`.
"""
struct AdstockCurveResults{G, H, O, A}
    metadata::ModelArtifactMetadata
    spec::MMMModelSpec
    coordinate_metadata::ModelCoordinateMetadata
    channel::String
    spend_grid::G
    spend_share_grid::H
    observed_total_spend::O
    values::A
end

function Base.:(==)(lhs::AdstockCurveResults, rhs::AdstockCurveResults)
    return lhs.metadata == rhs.metadata &&
        lhs.spec == rhs.spec &&
        lhs.coordinate_metadata == rhs.coordinate_metadata &&
        lhs.channel == rhs.channel &&
        lhs.spend_grid == rhs.spend_grid &&
        lhs.spend_share_grid == rhs.spend_share_grid &&
        lhs.observed_total_spend == rhs.observed_total_spend &&
        lhs.values == rhs.values
end

"""
    MetricResults

Typed draw-level marketing-metric surface derived from `ResponseCurveResults`.

For time-series curves, `values` has dimensions `(draw, spend_point, metric)`.
For bounded panel curves, `values` has dimensions `(draw, panel, spend_point,
metric)`. Panel metrics inherit the response-curve `spend_grid` axis order:
`(panel, spend_point)`.
"""
struct MetricResults{G, A}
    metadata::ModelArtifactMetadata
    spec::MMMModelSpec
    coordinate_metadata::ModelCoordinateMetadata
    channel::String
    spend_grid::G
    metric_names::Vector{String}
    default_metric::Symbol
    values::A
end

function Base.:(==)(lhs::MetricResults, rhs::MetricResults)
    return lhs.metadata == rhs.metadata &&
        lhs.spec == rhs.spec &&
        lhs.coordinate_metadata == rhs.coordinate_metadata &&
        lhs.channel == rhs.channel &&
        lhs.spend_grid == rhs.spend_grid &&
        lhs.metric_names == rhs.metric_names &&
        lhs.default_metric == rhs.default_metric &&
        lhs.values == rhs.values
end

function _postmodel_axis_error(result_name::AbstractString, message::AbstractString)
    throw(ArgumentError("$result_name axis contract violation: $message"))
end

function _validate_draw_count(result_name::AbstractString, values)
    size(values, 1) > 0 ||
        _postmodel_axis_error(result_name, "the draw axis must contain at least one draw")
    return nothing
end

function _validate_component_axis(
        result_name::AbstractString,
        component_names::AbstractVector,
        component_kinds::AbstractVector,
        ncomponents::Integer,
    )
    length(component_names) == ncomponents ||
        _postmodel_axis_error(
        result_name,
        "`component_names` must match the component axis length",
    )
    length(component_kinds) == ncomponents ||
        _postmodel_axis_error(
        result_name,
        "`component_kinds` must match the component axis length",
    )
    return nothing
end

function _validate_panel_axis_metadata(
        result_name::AbstractString,
        metadata::ModelCoordinateMetadata,
        npanels::Integer,
    )
    isempty(metadata.panel_dims) &&
        _postmodel_axis_error(result_name, "panel-shaped artifacts require declared panel dimensions")
    length(metadata.panel_axes) == 1 ||
        _postmodel_axis_error(result_name, "panel-shaped artifacts require exactly one flat panel axis")

    axis = only(metadata.panel_axes)
    axis.name == "panel_cell" ||
        _postmodel_axis_error(result_name, "the flat panel axis must be named `panel_cell`")
    length(axis.values) == npanels ||
        _postmodel_axis_error(result_name, "`panel_cell` values must match the panel axis length")
    length(axis.coordinate_columns) == length(metadata.panel_dims) ||
        _postmodel_axis_error(
        result_name,
        "panel coordinate columns must match declared panel dimensions",
    )

    for (dimension, column) in zip(metadata.panel_dims, axis.coordinate_columns)
        column.first == dimension ||
            _postmodel_axis_error(
            result_name,
            "panel coordinate columns must stay in declared panel-dimension order",
        )
        length(column.second) == npanels ||
            _postmodel_axis_error(
            result_name,
            "panel coordinate column `$dimension` must match the panel axis length",
        )
    end

    return nothing
end

function _validated_panel_spend_grid(result_name::AbstractString, spend_grid)
    try
        return Matrix{Float64}(spend_grid)
    catch err
        err isa InterruptException && rethrow()
        _postmodel_axis_error(
            result_name,
            "`spend_grid` must be a numeric matrix with axes (panel, spend_point)",
        )
    end
end

function _validate_postmodel_axes(results::ContributionResults)
    result_name = "ContributionResults"
    nd = ndims(results.values)
    if results.spec.model_kind === :panel_mmm
        nd == 4 ||
            _postmodel_axis_error(
            result_name,
            "panel contribution values must have axes (draw, time, panel, component)",
        )
        _validate_draw_count(result_name, results.values)
        _validate_panel_axis_metadata(result_name, results.coordinate_metadata, size(results.values, 3))
        _validate_component_axis(
            result_name,
            results.component_names,
            results.component_kinds,
            size(results.values, 4),
        )
        return nothing
    end

    nd == 3 ||
        _postmodel_axis_error(
        result_name,
        "time-series contribution values must have axes (draw, observation, component)",
    )
    _validate_draw_count(result_name, results.values)
    _validate_component_axis(
        result_name,
        results.component_names,
        results.component_kinds,
        size(results.values, 3),
    )
    return nothing
end

function _validate_postmodel_axes(results::DecompositionResults)
    result_name = "DecompositionResults"
    ndims(results.totals) == 2 ||
        _postmodel_axis_error(result_name, "`totals` must have axes (draw, component)")
    ndims(results.shares) == 2 ||
        _postmodel_axis_error(result_name, "`shares` must have axes (draw, component)")
    size(results.totals) == size(results.shares) ||
        _postmodel_axis_error(result_name, "`totals` and `shares` must have matching axes")
    _validate_draw_count(result_name, results.totals)
    _validate_component_axis(
        result_name,
        results.component_names,
        results.component_kinds,
        size(results.totals, 2),
    )
    return nothing
end

function _validate_curve_axes(
        result_name::AbstractString,
        spec::MMMModelSpec,
        metadata::ModelCoordinateMetadata,
        spend_grid,
        spend_share_grid,
        observed_total_spend,
        values,
    )
    if spec.model_kind === :panel_mmm
        ndims(values) == 3 ||
            _postmodel_axis_error(
            result_name,
            "panel curve values must have axes (draw, panel, spend_point)",
        )
        _validate_draw_count(result_name, values)
        npanels = size(values, 2)
        npoints = size(values, 3)
        _validate_panel_axis_metadata(result_name, metadata, npanels)
        size(_validated_panel_spend_grid(result_name, spend_grid)) == (npanels, npoints) ||
            _postmodel_axis_error(
            result_name,
            "`spend_grid` must have axes (panel, spend_point) for panel curves",
        )
        length(spend_share_grid) == npoints ||
            _postmodel_axis_error(
            result_name,
            "`spend_share_grid` must match the spend-point axis length",
        )
        length(observed_total_spend) == npanels ||
            _postmodel_axis_error(
            result_name,
            "`observed_total_spend` must match the panel axis length",
        )
        return nothing
    end

    ndims(values) == 2 ||
        _postmodel_axis_error(
        result_name,
        "time-series curve values must have axes (draw, spend_point)",
    )
    _validate_draw_count(result_name, values)
    npoints = size(values, 2)
    length(spend_grid) == npoints ||
        _postmodel_axis_error(result_name, "`spend_grid` must match the spend-point axis length")
    length(spend_share_grid) == npoints ||
        _postmodel_axis_error(
        result_name,
        "`spend_share_grid` must match the spend-point axis length",
    )
    observed_total_spend isa Real ||
        _postmodel_axis_error(result_name, "`observed_total_spend` must be a scalar")
    return nothing
end

function _validate_postmodel_axes(results::ResponseCurveResults)
    return _validate_curve_axes(
        "ResponseCurveResults",
        results.spec,
        results.coordinate_metadata,
        results.spend_grid,
        results.spend_share_grid,
        results.observed_total_spend,
        results.values,
    )
end

function _validate_postmodel_axes(results::SaturationCurveResults)
    return _validate_curve_axes(
        "SaturationCurveResults",
        results.spec,
        results.coordinate_metadata,
        results.spend_grid,
        results.spend_share_grid,
        results.observed_total_spend,
        results.values,
    )
end

function _validate_postmodel_axes(results::AdstockCurveResults)
    return _validate_curve_axes(
        "AdstockCurveResults",
        results.spec,
        results.coordinate_metadata,
        results.spend_grid,
        results.spend_share_grid,
        results.observed_total_spend,
        results.values,
    )
end

function _validate_postmodel_axes(results::MetricResults)
    result_name = "MetricResults"
    if results.spec.model_kind === :panel_mmm
        ndims(results.values) == 4 ||
            _postmodel_axis_error(
            result_name,
            "panel metric values must have axes (draw, panel, spend_point, metric)",
        )
        _validate_draw_count(result_name, results.values)
        npanels = size(results.values, 2)
        npoints = size(results.values, 3)
        nmetrics = size(results.values, 4)
        _validate_panel_axis_metadata(result_name, results.coordinate_metadata, npanels)
        size(_validated_panel_spend_grid(result_name, results.spend_grid)) == (npanels, npoints) ||
            _postmodel_axis_error(
            result_name,
            "`spend_grid` must have axes (panel, spend_point) for panel metrics",
        )
        length(results.metric_names) == nmetrics ||
            _postmodel_axis_error(result_name, "`metric_names` must match the metric axis length")
        return nothing
    end

    ndims(results.values) == 3 ||
        _postmodel_axis_error(
        result_name,
        "time-series metric values must have axes (draw, spend_point, metric)",
    )
    _validate_draw_count(result_name, results.values)
    npoints = size(results.values, 2)
    nmetrics = size(results.values, 3)
    length(results.spend_grid) == npoints ||
        _postmodel_axis_error(result_name, "`spend_grid` must match the spend-point axis length")
    length(results.metric_names) == nmetrics ||
        _postmodel_axis_error(result_name, "`metric_names` must match the metric axis length")
    return nothing
end
