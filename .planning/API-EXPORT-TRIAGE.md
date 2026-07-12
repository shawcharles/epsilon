# Public API Export Triage

This register records the lifecycle disposition of the current loaded `Epsilon`
export surface. It complements `docs/src/api.md`: support status describes the
current documented scope, while lifecycle action describes intended public API
disposition before a stable release.

This is not a v1 API freeze, not a breaking cleanup, and not Abacus behavioural
evidence. Export removals, staged deprecations, and stronger compatibility
claims need separate review.

Lifecycle values:

- `keep-public`: intended v1 public API candidate; not a stability guarantee
  until a stable release is cut.
- `keep-bounded`: supported public API for a documented bounded slice.
- `compatibility`: retained for migration, legacy naming, or Julia package
  convention.
- `review-before-v1`: public today, but needs an explicit keep/deprecate
  decision before a stable release.
- `deprecation-candidate`: likely should be unexported, renamed, or moved
  behind a narrower surface in a later breaking/deprecation phase.
  This is governance status only: it does not add `Base.depwarn`,
  `@deprecate`, export removal, or runtime behaviour change in Phase 22.

<!-- BEGIN PUBLIC API TRIAGE -->
| Symbol | Domain | Support | Lifecycle | Replacement / Migration | Rationale |
|---|---|---|---|---|---|
| `AbstractMMMModel` | Model core | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `AbstractModel` | Model core | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `AbstractRegressionModel` | Model core | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `AbstractScenarioSpec` | Scenario planning | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `AdstockCurveResults` | Post-model results | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `After` | Event windows | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `Before` | Event windows | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `BudgetOptimizationResult` | Budget optimization | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `CalibrationStepConfig` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `ContributionResults` | Post-model results | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `ConvMode` | Transforms | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `ConvergenceIssue` | Diagnostics | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `ConvergenceReport` | Diagnostics | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `ConvergenceWarning` | Diagnostics | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `ConvergenceWarnings` | Diagnostics | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `CostPerTargetCalibrationPayload` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `CostPerTargetCalibrationRows` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `CurrentScenarioSpec` | Scenario planning | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `DecompositionResults` | Post-model results | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `EpsilonPrior` | Priors and distributions | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `FinnishHorseshoePrior` | Priors and distributions | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `FixedBudgetOptimizedScenarioSpec` | Scenario planning | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `HorseshoePrior` | Priors and distributions | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `InferenceResults` | Inference | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `InferenceSampleStats` | Inference | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `LaplacePrior` | Priors and distributions | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `LiftTestCalibrationPayload` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `LiftTestCalibrationRows` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `LogNormalPrior` | Priors and distributions | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `MMMCalibrationSpec` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `MMMData` | Model data | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `MMMModelSpec` | Model specification | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `ManualAllocationScenarioSpec` | Scenario planning | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `ManualScenarioEvaluationResult` | Scenario planning | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `MaskedPrior` | Priors and distributions | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `MaxAbsScaleChannels` | Transforms | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `MaxAbsScaleTarget` | Transforms | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `MaxAbsScaler` | Transforms | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `MetricResults` | Post-model results | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `ModelArtifactMetadata` | Model artifacts | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `ModelConfig` | Configuration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `ModelConfigError` | Configuration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `ModelCoordinateMetadata` | Model artifacts | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `ModelDiagnostics` | Diagnostics | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `ModelFitState` | Model lifecycle | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `ModelResults` | Model lifecycle | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `NonMonotonicError` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `Overlap` | Event windows | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `PanelAxis` | Panel metadata | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `PanelBudgetOptimizationResult` | Budget optimization | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `PanelCoordinate` | Panel metadata | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `PanelMMM` | Model core | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `PanelMMMData` | Model data | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `ParameterDiagnostics` | Diagnostics | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `PipelineRunConfig` | Pipeline | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `PipelineRunResult` | Pipeline | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `PipelineStageRecord` | Pipeline | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `PipelineValidationResult` | Pipeline | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `R2D2Prior` | Priors and distributions | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `ResponseCurveResults` | Post-model results | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `SamplerConfig` | Inference | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `SamplerDiagnostics` | Diagnostics | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `SamplerWarning` | Diagnostics | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `SamplerWarnings` | Diagnostics | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `SaturationCurveResults` | Post-model results | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `Scaled` | Transforms | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `ScenarioDataArraySpec` | Scenario planning | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `ScenarioPlanResult` | Scenario planning | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `ScenarioStoreArtifact` | Scenario planning | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `SkewStudentT` | Priors and distributions | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `StandardScaler` | Transforms | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `StandardizeControls` | Transforms | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `TimeSeriesCalibrationInput` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `TimeSeriesMMM` | Model core | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `TimeVaryingMediaConfig` | Configuration | bounded | keep-bounded | n/a | Programmatic-only TimeSeriesMMM MCMC shared-media HSGP configuration with immutable replay state; YAML/pipeline, panels, VI, calibration, broader HSGP/TVP, and HSGP postmodel calculations remain unsupported. |
| `UnalignedValuesError` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `VariationalConfig` | Inference | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `WeibullType` | Transforms | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `active_count` | Priors and distributions | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `adstock_curve_plot` | Plotting | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `adstock_curve_results` | Post-model results | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `approximate_fit!` | Inference | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `assert_monotonic_lift` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `assert_scenario_store_compatible` | Scenario planning | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `batched_convolution` | Transforms | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `binomial_adstock` | Transforms | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `budget_audit_table` | Budget optimization | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `budget_impact_table` | Budget optimization | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `budget_optimization_plot` | Plotting | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `build_cost_per_target_calibration_payload` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `build_lift_test_calibration_payload` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `build_model` | Model builders | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `centered_logistic_saturation` | Transforms | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `contribution_area_plot` | Plotting | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `contribution_plot` | Plotting | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `contribution_results` | Post-model results | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `convergence_report` | Diagnostics | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `convergence_warnings` | Diagnostics | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `cost_per_target_penalties` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `cost_per_target_total_penalty` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `decomposition_plot` | Plotting | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `decomposition_results` | Post-model results | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `delayed_adstock` | Transforms | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `deserialize_model_config` | Serialization | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `deserialize_prior` | Priors and distributions | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `epsilon_theme` | Plotting | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `epsilon_version` | Package identity | compatibility | compatibility | n/a | Retained for migration, legacy naming, or Julia package convention. |
| `evaluate_manual_scenario` | Scenario planning | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `exact_row_indices` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `expand_masked_values` | Priors and distributions | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `finnish_horseshoe_coefficients` | Priors and distributions | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `fit!` | Model lifecycle | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `fit_transform!` | Transforms | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `fourier_features` | Seasonality | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `gamma_shape_scale` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `geometric_adstock` | Transforms | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `has_convergence_issues` | Diagnostics | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `has_convergence_warnings` | Diagnostics | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `has_numerical_errors` | Diagnostics | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `has_sampler_warnings` | Diagnostics | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `hill_function` | Transforms | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `horseshoe_coefficients` | Priors and distributions | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `inference_results` | Inference | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `instantiate_distribution` | Priors and distributions | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `inverse_transform` | Transforms | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `lift_test_estimated_lift` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `lift_test_estimated_lift_ad` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `lift_test_gamma_distribution` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `lift_test_likelihood_terms` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `lift_test_log_density` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `lift_test_payload_log_density` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `load_inference_results` | Serialization | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `load_model` | Serialization | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `load_model_config` | Configuration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `load_public_config` | Configuration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `load_results` | Serialization | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `load_sampler_config` | Inference | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `load_scenario_store` | Scenario planning | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `logistic_saturation` | Transforms | compatibility | compatibility | n/a | Retained for migration, legacy naming, or Julia package convention. |
| `max_abs_scale_channel_data` | Transforms | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `max_abs_scale_target_data` | Transforms | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `metric_results` | Post-model results | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `michaelis_menten` | Transforms | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `model_config_from_dict` | Configuration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `model_diagnostics` | Diagnostics | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `model_results` | Model lifecycle | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `nobs` | Model data | compatibility | compatibility | n/a | Retained for migration, legacy naming, or Julia package convention. |
| `normalize_channel_columns` | Model data | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `npanel_observations` | Model data | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `npanels` | Model data | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `ntime` | Model data | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `observed_fitted_plot` | Plotting | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `optimize_budget` | Budget optimization | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `panel_axes` | Panel metadata | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `panel_axis` | Panel metadata | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `panel_coordinate` | Panel metadata | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `panel_coordinates` | Panel metadata | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `pipeline_main` | Pipeline | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `posterior_density_plot` | Plotting | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `predict` | Model lifecycle | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `prior_posterior_plot` | Plotting | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `prior_predict` | Model lifecycle | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `r2d2_coefficients` | Priors and distributions | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `r2d2_variance_weights` | Priors and distributions | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `regularized_local_scales` | Priors and distributions | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `residual_diagnostics_plot` | Plotting | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `response_curve_plot` | Plotting | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `response_curve_results` | Post-model results | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `run_pipeline` | Pipeline | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `sampler_config_from_dict` | Inference | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `sampler_diagnostics` | Diagnostics | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `sampler_warnings` | Diagnostics | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `saturation_curve_plot` | Plotting | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `saturation_curve_results` | Post-model results | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `save_inference_results` | Serialization | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `save_model` | Serialization | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `save_results` | Serialization | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `scale_channel_lift_measurements` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `scale_lift_measurements` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `scale_target_for_lift_measurements` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `scenario_plan` | Scenario planning | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `scenario_store_plan` | Scenario planning | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `standardize_control_data` | Transforms | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `summary_table` | Post-model results | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `tanh_saturation` | Transforms | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `trace_plot` | Plotting | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `transform` | Transforms | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `validate_calibration_step_config` | Calibration | scaffolded | deprecation-candidate | Use `CalibrationStepConfig` construction or `load_public_config` calibration parsing. | Implemented and exported today, but final public disposition needs review before v1. |
| `validate_channel_values` | Validation | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `validate_column_indices` | Validation | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `validate_cost_per_target_calibration_payload` | Calibration | scaffolded | deprecation-candidate | Use `build_cost_per_target_calibration_payload`. | Implemented and exported today, but final public disposition needs review before v1. |
| `validate_lift_test_calibration_payload` | Calibration | scaffolded | deprecation-candidate | Use `build_lift_test_calibration_payload`. | Implemented and exported today, but final public disposition needs review before v1. |
| `validate_lift_test_columns` | Calibration | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `validate_mmm_data` | Model data | scaffolded | deprecation-candidate | Use `MMMData` construction before building `TimeSeriesMMM`. | Implemented and exported today, but final public disposition needs review before v1. |
| `validate_model_config` | Configuration | scaffolded | deprecation-candidate | Use `ModelConfig` construction or `load_model_config`. | Implemented and exported today, but final public disposition needs review before v1. |
| `validate_panel_mmm_data` | Model data | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `validate_sampler_config` | Inference | scaffolded | deprecation-candidate | Use `SamplerConfig` construction or `load_sampler_config`. | Implemented and exported today, but final public disposition needs review before v1. |
| `validate_target_data` | Model data | scaffolded | review-before-v1 | n/a | Implemented and exported today, but final public disposition needs review before v1. |
| `weibull_adstock` | Transforms | core | keep-public | n/a | Documented core surface with strongest current Epsilon support. |
| `write_plot_bundle` | Plotting | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
| `write_scenario_store` | Scenario planning | bounded | keep-bounded | n/a | Supported for the documented bounded slice; broader semantics remain out of scope. |
<!-- END PUBLIC API TRIAGE -->
