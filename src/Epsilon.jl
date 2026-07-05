module Epsilon

export deserialize_model_config
export deserialize_prior
export EpsilonPrior
export expand_masked_values
export After
export Before
export AbstractMMMModel
export AbstractModel
export AbstractRegressionModel
export build_model
export fit!
export active_count
export binomial_adstock
export ConvMode
export convergence_report
export convergence_warnings
export ConvergenceIssue
export ConvergenceReport
export ConvergenceWarning
export ConvergenceWarnings
export centered_logistic_saturation
export Overlap
export FinnishHorseshoePrior
export finnish_horseshoe_coefficients
export InferenceResults
export InferenceSampleStats
export LaplacePrior
export LogNormalPrior
export MaxAbsScaleChannels
export MaxAbsScaleTarget
export MaxAbsScaler
export MaskedPrior
export ModelConfigError
export HorseshoePrior
export horseshoe_coefficients
export Scaled
export SkewStudentT
export R2D2Prior
export r2d2_coefficients
export r2d2_variance_weights
export regularized_local_scales
export StandardizeControls
export StandardScaler
export WeibullType
export batched_convolution
export delayed_adstock
export epsilon_theme
export epsilon_version
export fourier_features
export geometric_adstock
export hill_function
export instantiate_distribution
export inference_results
export inverse_transform
export logistic_saturation
export max_abs_scale_channel_data
export max_abs_scale_target_data
export michaelis_menten
export MMMData
export PanelMMMData
export ModelArtifactMetadata
export ModelCoordinateMetadata
export PanelAxis
export PanelCoordinate
export panel_axis
export panel_axes
export panel_coordinate
export panel_coordinates
export model_diagnostics
export prior_predict
export predict
export model_results
export sampler_diagnostics
export sampler_warnings
export ModelDiagnostics
export MMMModelSpec
export ModelConfig
export model_config_from_dict
export ModelFitState
export ModelResults
export PipelineRunConfig
export PipelineRunResult
export PipelineStageRecord
export PipelineValidationResult
export pipeline_main
export normalize_channel_columns
export npanel_observations
export npanels
export nobs
export ntime
export ParameterDiagnostics
export approximate_fit!
export run_pipeline
export CalibrationStepConfig
export validate_calibration_step_config
export UnalignedValuesError
export NonMonotonicError
export exact_row_indices
export validate_lift_test_columns
export assert_monotonic_lift
export scale_channel_lift_measurements
export scale_target_for_lift_measurements
export scale_lift_measurements
export gamma_shape_scale
export lift_test_gamma_distribution
export lift_test_estimated_lift
export lift_test_likelihood_terms
export lift_test_estimated_lift_ad
export lift_test_log_density
export lift_test_payload_log_density
export cost_per_target_penalties
export cost_per_target_total_penalty
export LiftTestCalibrationPayload
export validate_lift_test_calibration_payload
export build_lift_test_calibration_payload
export CostPerTargetCalibrationPayload
export validate_cost_per_target_calibration_payload
export build_cost_per_target_calibration_payload
export LiftTestCalibrationRows
export CostPerTargetCalibrationRows
export TimeSeriesCalibrationInput
export MMMCalibrationSpec

export SamplerDiagnostics
export SamplerWarning
export SamplerWarnings
export has_convergence_issues
export has_convergence_warnings
export has_numerical_errors
export has_sampler_warnings
export load_model_config
export load_model
export load_public_config
export load_inference_results
export load_results
export load_sampler_config
export save_model
export save_inference_results
export save_results
export SamplerConfig
export sampler_config_from_dict
export standardize_control_data
export tanh_saturation
export PanelMMM
export TimeSeriesMMM
export transform
export fit_transform!
export ContributionResults
export contribution_area_plot
export contribution_plot
export budget_optimization_plot
export DecompositionResults
export ResponseCurveResults
export SaturationCurveResults
export AdstockCurveResults
export MetricResults
export contribution_results
export budget_audit_table
export budget_impact_table
export decomposition_plot
export decomposition_results
export response_curve_results
export saturation_curve_results
export adstock_curve_results
export response_curve_plot
export saturation_curve_plot
export adstock_curve_plot
export residual_diagnostics_plot
export metric_results
export BudgetOptimizationResult
export PanelBudgetOptimizationResult
export optimize_budget
export ScenarioDataArraySpec
export AbstractScenarioSpec
export CurrentScenarioSpec
export ManualAllocationScenarioSpec
export ManualScenarioEvaluationResult
export evaluate_manual_scenario
export FixedBudgetOptimizedScenarioSpec
export ScenarioPlanResult
export scenario_plan
export observed_fitted_plot
export posterior_density_plot
export prior_posterior_plot
export summary_table
export trace_plot
export write_plot_bundle
export validate_channel_values
export validate_column_indices
export validate_model_config
export validate_mmm_data
export validate_panel_mmm_data
export validate_sampler_config
export validate_target_data
export VariationalConfig
export weibull_adstock

include("distributions/priors.jl")
include("distributions/special.jl")
include("distributions/masked.jl")
include("distributions/shrinkage.jl")
include("model/types.jl")
include("model/config.jl")
include("mmm/seasonality.jl")
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
include("inference/vi.jl")
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
prior_predict(model::TimeSeriesMMM, new_data::MMMData = model.data) =
    _prior_predict_time_series_mmm(model, new_data)

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
    approximate_fit!(model::TimeSeriesMMM, config::VariationalConfig = VariationalConfig())
    approximate_fit!(model::PanelMMM, config::VariationalConfig = VariationalConfig())

Run the bounded explicit variational-inference path.

- `TimeSeriesMMM` currently supports mean-field Gaussian ADVI and materializes
  `config.draws` posterior draws into the stored fit artifact.
- `PanelMMM` variational inference is not supported in the current Phase 6
  surface.
"""
approximate_fit!

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
