module Epsilon

include("exports.jl")

include("distributions/priors.jl")
include("distributions/special.jl")
include("distributions/masked.jl")
include("distributions/shrinkage.jl")
include("model/types.jl")
include("model/config.jl")
include("mmm/seasonality.jl")
include("mmm/hsgp.jl")
include("mmm/trend.jl")
include("mmm/events.jl")
include("mmm/holidays.jl")
include("mmm/controls.jl")
include("mmm/calibration.jl")
include("model/builder.jl")
include("model/io.jl")

include("model/results.jl")
include("model/diagnostics.jl")
include("inference/mcmc.jl")
include("inference/diagnostics.jl")
include("inference/results.jl")
include("mmm/media.jl")
include("mmm/model.jl")
include("mmm/panel.jl")
include("postmodel/types.jl")
include("postmodel/replay.jl")
include("postmodel/contributions.jl")
include("postmodel/decomposition.jl")
include("postmodel/response_curves.jl")
include("postmodel/metrics.jl")
include("postmodel/summary.jl")
include("optimization/types.jl")
include("optimization/constraints.jl")
include("optimization/objective.jl")
include("optimization/optimizer.jl")
include("optimization/panel.jl")
include("optimization/summary.jl")
include("scenario_planner.jl")
include("pipeline/config.jl")
include("pipeline/context.jl")
include("pipeline/stages.jl")
include("pipeline/run.jl")
include("pipeline/cli.jl")
include("plotting/theme.jl")
include("plotting/diagnostics.jl")
include("plotting/postmodel.jl")
include("plotting/optimization.jl")
include("plotting/bundle.jl")
include("transforms/convolution.jl")
include("transforms/adstock.jl")
include("transforms/saturation.jl")
include("transforms/scaling.jl")

"""
    epsilon_version()

Return the installed Epsilon package version.
"""
epsilon_version() = pkgversion(@__MODULE__)

"""
    prior_predict(model, new_data=model.data)

Generate prior predictive samples for a typed MMM model.
"""
function prior_predict(model::TimeSeriesMMM, new_data::MMMData = model.data)
    return _prior_predict_time_series_mmm(model, new_data)
end

prior_predict(model::PanelMMM, new_data::PanelMMMData = model.data) =
    _prior_predict_panel_mmm(model, new_data)

panel_coordinates(results::InferenceResults) = panel_coordinates(results.coordinate_metadata)
panel_coordinates(results::ContributionResults) = panel_coordinates(results.coordinate_metadata)
panel_coordinates(results::DecompositionResults) = panel_coordinates(results.coordinate_metadata)
panel_coordinates(results::ResponseCurveResults) = panel_coordinates(results.coordinate_metadata)
panel_coordinates(results::SaturationCurveResults) = panel_coordinates(results.coordinate_metadata)
panel_coordinates(results::AdstockCurveResults) = panel_coordinates(results.coordinate_metadata)
panel_coordinates(results::MetricResults) = panel_coordinates(results.coordinate_metadata)
panel_coordinates(result::PanelBudgetOptimizationResult) = panel_coordinates(result.coordinate_metadata)

panel_axes(results::InferenceResults) = panel_axes(results.coordinate_metadata)
panel_axes(results::ContributionResults) = panel_axes(results.coordinate_metadata)
panel_axes(results::DecompositionResults) = panel_axes(results.coordinate_metadata)
panel_axes(results::ResponseCurveResults) = panel_axes(results.coordinate_metadata)
panel_axes(results::SaturationCurveResults) = panel_axes(results.coordinate_metadata)
panel_axes(results::AdstockCurveResults) = panel_axes(results.coordinate_metadata)
panel_axes(results::MetricResults) = panel_axes(results.coordinate_metadata)
panel_axes(result::PanelBudgetOptimizationResult) = panel_axes(result.coordinate_metadata)

panel_axis(results::InferenceResults) = panel_axis(results.coordinate_metadata)
panel_axis(results::ContributionResults) = panel_axis(results.coordinate_metadata)
panel_axis(results::DecompositionResults) = panel_axis(results.coordinate_metadata)
panel_axis(results::ResponseCurveResults) = panel_axis(results.coordinate_metadata)
panel_axis(results::SaturationCurveResults) = panel_axis(results.coordinate_metadata)
panel_axis(results::AdstockCurveResults) = panel_axis(results.coordinate_metadata)
panel_axis(results::MetricResults) = panel_axis(results.coordinate_metadata)
panel_axis(result::PanelBudgetOptimizationResult) = panel_axis(result.coordinate_metadata)

panel_coordinate(results::InferenceResults, flat_index::Integer) =
    panel_coordinate(results.coordinate_metadata, flat_index)
panel_coordinate(results::ContributionResults, flat_index::Integer) =
    panel_coordinate(results.coordinate_metadata, flat_index)
panel_coordinate(results::DecompositionResults, flat_index::Integer) =
    panel_coordinate(results.coordinate_metadata, flat_index)
panel_coordinate(results::ResponseCurveResults, flat_index::Integer) =
    panel_coordinate(results.coordinate_metadata, flat_index)
panel_coordinate(results::SaturationCurveResults, flat_index::Integer) =
    panel_coordinate(results.coordinate_metadata, flat_index)
panel_coordinate(results::AdstockCurveResults, flat_index::Integer) =
    panel_coordinate(results.coordinate_metadata, flat_index)
panel_coordinate(results::MetricResults, flat_index::Integer) =
    panel_coordinate(results.coordinate_metadata, flat_index)
panel_coordinate(result::PanelBudgetOptimizationResult, flat_index::Integer) =
    panel_coordinate(result.coordinate_metadata, flat_index)

"""
    fit!(model::TimeSeriesMMM)
    fit!(model::PanelMMM)
    fit!(scaler::Union{MaxAbsScaler, StandardScaler}, data)

Fit an MMM model or preprocessing scaler in-place.

- `fit!(model::TimeSeriesMMM)` runs the configured sampling backend and stores
  the resulting fit artifact on `model`.
- `fit!(model::PanelMMM)` runs the bounded hierarchical panel sampling backend
  and stores the resulting fit artifact on `model`.
- `fit!(scaler, data)` estimates scaling parameters from vector or matrix data
  for later `transform` or `inverse_transform` calls.
"""
fit!

"""
    summary_table(result)

Project a typed Phase 7 post-model result surface into an analyst-ready
`DataFrame`.

Current supported methods are:

- `summary_table(results::ContributionResults)`
- `summary_table(results::DecompositionResults)`
- `summary_table(results::ResponseCurveResults)`
- `summary_table(results::SaturationCurveResults)`
- `summary_table(results::AdstockCurveResults)`
- `summary_table(results::MetricResults)`
"""
summary_table

end
