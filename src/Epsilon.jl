module Epsilon

include("exports.jl")
include("includes.jl")

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

Project a typed post-model result surface into an analyst-ready `DataFrame`.

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
