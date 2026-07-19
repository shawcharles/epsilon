# Public API

This page inventories the symbols currently exported by `Epsilon`. It is a
support-status map, not a claim of broad upstream package or API parity. Use
the validation ledger for method-specific evidence.

Support bands:

- `core`: stable supported Epsilon surface.
- `bounded`: supported for the documented bounded slice only.
- `compatibility`: retained for migration, legacy naming, or Julia package
  conventions.
- `scaffolded`: public because implementation exists, but broader support or
  reference-parity evidence is incomplete.

Support status is the current documented scope. Lifecycle triage is tracked
separately in `.planning/API-EXPORT-TRIAGE.md`; it records whether an export is
an intended public candidate, bounded surface, compatibility surface, or
pre-v1 review item, and it is not a v1 API freeze.

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
symbol is exported today and has some implementation behind it; it does not
mean that the whole corresponding reference area has been proven equivalent.

The strongest parity evidence is concentrated in lower-level transforms and in
the bounded post-model result surfaces already tracked in the parity ledger.
Panel, calibration, scenario-planner, pipeline, optimization, inference, and
configuration entries should be read with their documented scope limits.

## Time-Varying Media Configuration

```@docs
Epsilon.TimeVaryingMediaConfig
```
