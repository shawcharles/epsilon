const _PanelCoordinateResult = Union{
    InferenceResults,
    ContributionResults,
    DecompositionResults,
    ResponseCurveResults,
    SaturationCurveResults,
    AdstockCurveResults,
    MetricResults,
    PanelBudgetOptimizationResult,
}

panel_coordinates(result::_PanelCoordinateResult) =
    panel_coordinates(result.coordinate_metadata)

panel_axes(result::_PanelCoordinateResult) =
    panel_axes(result.coordinate_metadata)

panel_axis(result::_PanelCoordinateResult) =
    panel_axis(result.coordinate_metadata)

panel_coordinate(result::_PanelCoordinateResult, flat_index::Integer) =
    panel_coordinate(result.coordinate_metadata, flat_index)
