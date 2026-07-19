# Public API

This page inventories the symbols currently exported by `Epsilon`. It is a
support-status map for a pre-release library, not a promise that every exported
symbol has the same stability level.

Support bands:

- `core`: stable supported Epsilon surface.
- `bounded`: supported for the documented bounded slice only.
- `compatibility`: retained for migration, legacy naming, or Julia package
  conventions.
- `scaffolded`: public because implementation exists, but broader support or
  API stability is still being reviewed.

Support status is the current documented scope, not a v1 API freeze.

## Inventory

The table between the markers below is checked by the test suite. Every current
export must appear exactly once.

Plotting exports are part of the public API, but their concrete CairoMakie
methods are loaded through the optional `EpsilonCairoMakieExt` extension. Use
`using Epsilon, CairoMakie` before calling plotting functions or
`write_plot_bundle(run)`.

<!-- BEGIN PUBLIC API INVENTORY -->
| Symbol | Domain | Support |
|---|---|---|
| `AbstractMMMModel` | Model core | scaffolded |
| `AbstractModel` | Model core | scaffolded |
| `AbstractRegressionModel` | Model core | scaffolded |
| `AbstractScenarioSpec` | Scenario planning | bounded |
| `AdstockCurveResults` | Post-model results | core |
| `After` | Event windows | scaffolded |
| `Before` | Event windows | scaffolded |
| `BudgetOptimizationResult` | Budget optimization | scaffolded |
| `CalibrationStepConfig` | Calibration | scaffolded |
| `ContributionResults` | Post-model results | core |
| `ConvMode` | Transforms | core |
| `ConvergenceIssue` | Diagnostics | scaffolded |
| `ConvergenceReport` | Diagnostics | scaffolded |
| `ConvergenceWarning` | Diagnostics | scaffolded |
| `ConvergenceWarnings` | Diagnostics | scaffolded |
| `CostPerTargetCalibrationPayload` | Calibration | scaffolded |
| `CostPerTargetCalibrationRows` | Calibration | scaffolded |
| `CurrentScenarioSpec` | Scenario planning | bounded |
| `DecompositionResults` | Post-model results | core |
| `EpsilonPrior` | Priors and distributions | scaffolded |
| `FinnishHorseshoePrior` | Priors and distributions | scaffolded |
| `FixedBudgetOptimizedScenarioSpec` | Scenario planning | bounded |
| `HorseshoePrior` | Priors and distributions | scaffolded |
| `InferenceResults` | Inference | scaffolded |
| `InferenceSampleStats` | Inference | scaffolded |
| `LaplacePrior` | Priors and distributions | scaffolded |
| `LiftTestCalibrationPayload` | Calibration | scaffolded |
| `LiftTestCalibrationRows` | Calibration | scaffolded |
| `LogNormalPrior` | Priors and distributions | scaffolded |
| `MMMCalibrationSpec` | Calibration | scaffolded |
| `MMMData` | Model data | scaffolded |
| `MMMModelSpec` | Model specification | scaffolded |
| `ManualAllocationScenarioSpec` | Scenario planning | bounded |
| `ManualScenarioEvaluationResult` | Scenario planning | bounded |
| `MaskedPrior` | Priors and distributions | scaffolded |
| `MaxAbsScaleChannels` | Transforms | core |
| `MaxAbsScaleTarget` | Transforms | core |
| `MaxAbsScaler` | Transforms | core |
| `MetricResults` | Post-model results | core |
| `ModelArtifactMetadata` | Model artifacts | scaffolded |
| `ModelConfig` | Configuration | scaffolded |
| `ModelConfigError` | Configuration | scaffolded |
| `ModelCoordinateMetadata` | Model artifacts | scaffolded |
| `ModelDiagnostics` | Diagnostics | scaffolded |
| `ModelFitState` | Model lifecycle | scaffolded |
| `ModelResults` | Model lifecycle | scaffolded |
| `NonMonotonicError` | Calibration | scaffolded |
| `Overlap` | Event windows | scaffolded |
| `PanelAxis` | Panel metadata | bounded |
| `PanelBudgetOptimizationResult` | Budget optimization | bounded |
| `PanelCoordinate` | Panel metadata | bounded |
| `PanelMMM` | Model core | bounded |
| `PanelMMMData` | Model data | bounded |
| `ParameterDiagnostics` | Diagnostics | scaffolded |
| `PipelineRunConfig` | Pipeline | scaffolded |
| `PipelineRunResult` | Pipeline | scaffolded |
| `PipelineStageRecord` | Pipeline | scaffolded |
| `PipelineValidationResult` | Pipeline | scaffolded |
| `R2D2Prior` | Priors and distributions | scaffolded |
| `ResponseCurveResults` | Post-model results | core |
| `SamplerConfig` | Inference | scaffolded |
| `SamplerDiagnostics` | Diagnostics | scaffolded |
| `SamplerWarning` | Diagnostics | scaffolded |
| `SamplerWarnings` | Diagnostics | scaffolded |
| `SaturationCurveResults` | Post-model results | core |
| `Scaled` | Transforms | core |
| `ScenarioDataArraySpec` | Scenario planning | bounded |
| `ScenarioPlanResult` | Scenario planning | bounded |
| `ScenarioStoreArtifact` | Scenario planning | bounded |
| `SkewStudentT` | Priors and distributions | scaffolded |
| `StandardScaler` | Transforms | core |
| `StandardizeControls` | Transforms | core |
| `TimeSeriesCalibrationInput` | Calibration | scaffolded |
| `TimeSeriesMMM` | Model core | bounded |
| `TimeVaryingMediaConfig` | Configuration | bounded |
| `UnalignedValuesError` | Calibration | scaffolded |
| `WeibullType` | Transforms | core |
| `active_count` | Priors and distributions | scaffolded |
| `adstock_curve_plot` | Plotting | bounded |
| `adstock_curve_results` | Post-model results | core |
| `assert_monotonic_lift` | Calibration | scaffolded |
| `assert_scenario_store_compatible` | Scenario planning | bounded |
| `batched_convolution` | Transforms | core |
| `binomial_adstock` | Transforms | core |
| `budget_audit_table` | Budget optimization | scaffolded |
| `budget_impact_table` | Budget optimization | scaffolded |
| `budget_optimization_plot` | Plotting | bounded |
| `build_cost_per_target_calibration_payload` | Calibration | scaffolded |
| `build_lift_test_calibration_payload` | Calibration | scaffolded |
| `build_model` | Model builders | scaffolded |
| `centered_logistic_saturation` | Transforms | bounded |
| `contribution_area_plot` | Plotting | bounded |
| `contribution_plot` | Plotting | bounded |
| `contribution_results` | Post-model results | core |
| `convergence_report` | Diagnostics | scaffolded |
| `convergence_warnings` | Diagnostics | scaffolded |
| `cost_per_target_penalties` | Calibration | scaffolded |
| `cost_per_target_total_penalty` | Calibration | scaffolded |
| `decomposition_plot` | Plotting | bounded |
| `decomposition_results` | Post-model results | core |
| `delayed_adstock` | Transforms | core |
| `deserialize_model_config` | Serialization | scaffolded |
| `deserialize_prior` | Priors and distributions | scaffolded |
| `epsilon_theme` | Plotting | bounded |
| `epsilon_version` | Package identity | compatibility |
| `evaluate_manual_scenario` | Scenario planning | bounded |
| `exact_row_indices` | Calibration | scaffolded |
| `expand_masked_values` | Priors and distributions | scaffolded |
| `finnish_horseshoe_coefficients` | Priors and distributions | scaffolded |
| `fit!` | Model lifecycle | scaffolded |
| `fit_transform!` | Transforms | core |
| `fourier_features` | Seasonality | scaffolded |
| `gamma_shape_scale` | Calibration | scaffolded |
| `geometric_adstock` | Transforms | core |
| `has_convergence_issues` | Diagnostics | scaffolded |
| `has_convergence_warnings` | Diagnostics | scaffolded |
| `has_numerical_errors` | Diagnostics | scaffolded |
| `has_sampler_warnings` | Diagnostics | scaffolded |
| `hill_function` | Transforms | core |
| `horseshoe_coefficients` | Priors and distributions | scaffolded |
| `inference_results` | Inference | scaffolded |
| `instantiate_distribution` | Priors and distributions | scaffolded |
| `inverse_transform` | Transforms | core |
| `lift_test_estimated_lift` | Calibration | scaffolded |
| `lift_test_estimated_lift_ad` | Calibration | scaffolded |
| `lift_test_gamma_distribution` | Calibration | scaffolded |
| `lift_test_likelihood_terms` | Calibration | scaffolded |
| `lift_test_log_density` | Calibration | scaffolded |
| `lift_test_payload_log_density` | Calibration | scaffolded |
| `load_inference_results` | Serialization | scaffolded |
| `load_model` | Serialization | scaffolded |
| `load_model_config` | Configuration | scaffolded |
| `load_public_config` | Configuration | scaffolded |
| `load_results` | Serialization | scaffolded |
| `load_sampler_config` | Inference | scaffolded |
| `load_scenario_store` | Scenario planning | bounded |
| `logistic_saturation` | Transforms | compatibility |
| `max_abs_scale_channel_data` | Transforms | core |
| `max_abs_scale_target_data` | Transforms | core |
| `metric_results` | Post-model results | core |
| `michaelis_menten` | Transforms | core |
| `model_config_from_dict` | Configuration | scaffolded |
| `model_diagnostics` | Diagnostics | scaffolded |
| `model_results` | Model lifecycle | scaffolded |
| `nobs` | Model data | compatibility |
| `normalize_channel_columns` | Model data | scaffolded |
| `npanel_observations` | Model data | bounded |
| `npanels` | Model data | bounded |
| `ntime` | Model data | bounded |
| `observed_fitted_plot` | Plotting | bounded |
| `optimize_budget` | Budget optimization | scaffolded |
| `panel_axes` | Panel metadata | bounded |
| `panel_axis` | Panel metadata | bounded |
| `panel_coordinate` | Panel metadata | bounded |
| `panel_coordinates` | Panel metadata | bounded |
| `pipeline_main` | Pipeline | scaffolded |
| `posterior_density_plot` | Plotting | bounded |
| `predict` | Model lifecycle | scaffolded |
| `prior_posterior_plot` | Plotting | bounded |
| `prior_predict` | Model lifecycle | scaffolded |
| `r2d2_coefficients` | Priors and distributions | scaffolded |
| `r2d2_variance_weights` | Priors and distributions | scaffolded |
| `regularized_local_scales` | Priors and distributions | scaffolded |
| `residual_diagnostics_plot` | Plotting | bounded |
| `response_curve_plot` | Plotting | bounded |
| `response_curve_results` | Post-model results | core |
| `run_pipeline` | Pipeline | scaffolded |
| `sampler_config_from_dict` | Inference | scaffolded |
| `sampler_diagnostics` | Diagnostics | scaffolded |
| `sampler_warnings` | Diagnostics | scaffolded |
| `saturation_curve_plot` | Plotting | bounded |
| `saturation_curve_results` | Post-model results | core |
| `save_inference_results` | Serialization | scaffolded |
| `save_model` | Serialization | scaffolded |
| `save_results` | Serialization | scaffolded |
| `scale_channel_lift_measurements` | Calibration | scaffolded |
| `scale_lift_measurements` | Calibration | scaffolded |
| `scale_target_for_lift_measurements` | Calibration | scaffolded |
| `scenario_plan` | Scenario planning | bounded |
| `scenario_store_plan` | Scenario planning | bounded |
| `standardize_control_data` | Transforms | core |
| `summary_table` | Post-model results | bounded |
| `tanh_saturation` | Transforms | core |
| `trace_plot` | Plotting | bounded |
| `transform` | Transforms | core |
| `validate_calibration_step_config` | Calibration | scaffolded |
| `validate_channel_values` | Validation | bounded |
| `validate_column_indices` | Validation | scaffolded |
| `validate_cost_per_target_calibration_payload` | Calibration | scaffolded |
| `validate_lift_test_calibration_payload` | Calibration | scaffolded |
| `validate_lift_test_columns` | Calibration | scaffolded |
| `validate_mmm_data` | Model data | scaffolded |
| `validate_model_config` | Configuration | scaffolded |
| `validate_panel_mmm_data` | Model data | bounded |
| `validate_sampler_config` | Inference | scaffolded |
| `validate_target_data` | Model data | scaffolded |
| `weibull_adstock` | Transforms | core |
| `write_plot_bundle` | Plotting | bounded |
| `write_scenario_store` | Scenario planning | bounded |
<!-- END PUBLIC API INVENTORY -->

## Reading The Table

Several domains are intentionally still `scaffolded`. That label means the
symbol is exported today and has implementation behind it, but the API may
still change before a stable release.

Panel, calibration, scenario-planner, pipeline, optimization, inference, and
configuration entries should be read with the scope limits documented in
[Support Boundaries](release.md).

## Docstring Reference

```@docs
Epsilon.AbstractMMMModel
Epsilon.AbstractModel
Epsilon.AbstractRegressionModel
Epsilon.AbstractScenarioSpec
Epsilon.AdstockCurveResults
Epsilon.After
Epsilon.Before
Epsilon.BudgetOptimizationResult
Epsilon.CalibrationStepConfig
Epsilon.ContributionResults
Epsilon.ConvMode
Epsilon.ConvergenceIssue
Epsilon.ConvergenceReport
Epsilon.ConvergenceWarning
Epsilon.ConvergenceWarnings
Epsilon.CostPerTargetCalibrationPayload
Epsilon.CostPerTargetCalibrationRows
Epsilon.CurrentScenarioSpec
Epsilon.DecompositionResults
Epsilon.EpsilonPrior
Epsilon.FinnishHorseshoePrior
Epsilon.FixedBudgetOptimizedScenarioSpec
Epsilon.HorseshoePrior
Epsilon.InferenceResults
Epsilon.InferenceSampleStats
Epsilon.LaplacePrior
Epsilon.LiftTestCalibrationPayload
Epsilon.LiftTestCalibrationRows
Epsilon.LogNormalPrior
Epsilon.MMMCalibrationSpec
Epsilon.MMMData
Epsilon.MMMModelSpec
Epsilon.ManualAllocationScenarioSpec
Epsilon.ManualScenarioEvaluationResult
Epsilon.MaskedPrior
Epsilon.MaxAbsScaleChannels
Epsilon.MaxAbsScaleTarget
Epsilon.MaxAbsScaler
Epsilon.MetricResults
Epsilon.ModelArtifactMetadata
Epsilon.ModelConfig
Epsilon.ModelConfigError
Epsilon.ModelCoordinateMetadata
Epsilon.ModelDiagnostics
Epsilon.ModelFitState
Epsilon.ModelResults
Epsilon.NonMonotonicError
Epsilon.Overlap
Epsilon.PanelAxis
Epsilon.PanelBudgetOptimizationResult
Epsilon.PanelCoordinate
Epsilon.PanelMMM
Epsilon.PanelMMMData
Epsilon.ParameterDiagnostics
Epsilon.PipelineRunConfig
Epsilon.PipelineRunResult
Epsilon.PipelineStageRecord
Epsilon.PipelineValidationResult
Epsilon.R2D2Prior
Epsilon.ResponseCurveResults
Epsilon.SamplerConfig
Epsilon.SamplerDiagnostics
Epsilon.SamplerWarning
Epsilon.SamplerWarnings
Epsilon.SaturationCurveResults
Epsilon.Scaled
Epsilon.ScenarioDataArraySpec
Epsilon.ScenarioPlanResult
Epsilon.ScenarioStoreArtifact
Epsilon.SkewStudentT
Epsilon.StandardScaler
Epsilon.StandardizeControls
Epsilon.TimeSeriesCalibrationInput
Epsilon.TimeSeriesMMM
Epsilon.TimeVaryingMediaConfig
Epsilon.UnalignedValuesError
Epsilon.WeibullType
Epsilon.active_count
Epsilon.adstock_curve_plot
Epsilon.adstock_curve_results
Epsilon.assert_monotonic_lift
Epsilon.assert_scenario_store_compatible
Epsilon.batched_convolution
Epsilon.binomial_adstock
Epsilon.budget_audit_table
Epsilon.budget_impact_table
Epsilon.budget_optimization_plot
Epsilon.build_cost_per_target_calibration_payload
Epsilon.build_lift_test_calibration_payload
Epsilon.build_model
Epsilon.centered_logistic_saturation
Epsilon.contribution_area_plot
Epsilon.contribution_plot
Epsilon.contribution_results
Epsilon.convergence_report
Epsilon.convergence_warnings
Epsilon.cost_per_target_penalties
Epsilon.cost_per_target_total_penalty
Epsilon.decomposition_plot
Epsilon.decomposition_results
Epsilon.delayed_adstock
Epsilon.deserialize_model_config
Epsilon.deserialize_prior
Epsilon.epsilon_theme
Epsilon.epsilon_version
Epsilon.evaluate_manual_scenario
Epsilon.exact_row_indices
Epsilon.expand_masked_values
Epsilon.finnish_horseshoe_coefficients
Epsilon.fit!
Epsilon.fit_transform!
Epsilon.fourier_features
Epsilon.gamma_shape_scale
Epsilon.geometric_adstock
Epsilon.has_convergence_issues
Epsilon.has_convergence_warnings
Epsilon.has_numerical_errors
Epsilon.has_sampler_warnings
Epsilon.hill_function
Epsilon.horseshoe_coefficients
Epsilon.inference_results
Epsilon.instantiate_distribution
Epsilon.inverse_transform
Epsilon.lift_test_estimated_lift
Epsilon.lift_test_estimated_lift_ad
Epsilon.lift_test_gamma_distribution
Epsilon.lift_test_likelihood_terms
Epsilon.lift_test_log_density
Epsilon.lift_test_payload_log_density
Epsilon.load_inference_results
Epsilon.load_model
Epsilon.load_model_config
Epsilon.load_public_config
Epsilon.load_results
Epsilon.load_sampler_config
Epsilon.load_scenario_store
Epsilon.logistic_saturation
Epsilon.max_abs_scale_channel_data
Epsilon.max_abs_scale_target_data
Epsilon.metric_results
Epsilon.michaelis_menten
Epsilon.model_config_from_dict
Epsilon.model_diagnostics
Epsilon.model_results
Epsilon.nobs
Epsilon.normalize_channel_columns
Epsilon.npanel_observations
Epsilon.npanels
Epsilon.ntime
Epsilon.observed_fitted_plot
Epsilon.optimize_budget
Epsilon.panel_axes
Epsilon.panel_axis
Epsilon.panel_coordinate
Epsilon.panel_coordinates
Epsilon.pipeline_main
Epsilon.posterior_density_plot
Epsilon.predict
Epsilon.prior_posterior_plot
Epsilon.prior_predict
Epsilon.r2d2_coefficients
Epsilon.r2d2_variance_weights
Epsilon.regularized_local_scales
Epsilon.residual_diagnostics_plot
Epsilon.response_curve_plot
Epsilon.response_curve_results
Epsilon.run_pipeline
Epsilon.sampler_config_from_dict
Epsilon.sampler_diagnostics
Epsilon.sampler_warnings
Epsilon.saturation_curve_plot
Epsilon.saturation_curve_results
Epsilon.save_inference_results
Epsilon.save_model
Epsilon.save_results
Epsilon.scale_channel_lift_measurements
Epsilon.scale_lift_measurements
Epsilon.scale_target_for_lift_measurements
Epsilon.scenario_plan
Epsilon.scenario_store_plan
Epsilon.standardize_control_data
Epsilon.summary_table
Epsilon.tanh_saturation
Epsilon.trace_plot
Epsilon.transform
Epsilon.validate_calibration_step_config
Epsilon.validate_channel_values
Epsilon.validate_column_indices
Epsilon.validate_cost_per_target_calibration_payload
Epsilon.validate_lift_test_calibration_payload
Epsilon.validate_lift_test_columns
Epsilon.validate_mmm_data
Epsilon.validate_model_config
Epsilon.validate_panel_mmm_data
Epsilon.validate_sampler_config
Epsilon.validate_target_data
Epsilon.weibull_adstock
Epsilon.write_plot_bundle
Epsilon.write_scenario_store
```
