# Public API Export Cleanup RFC

Phase 22 records candidate-only public API cleanup decisions for a small slice
of the current loaded `Epsilon` export surface. It does not remove exports,
add runtime deprecation warnings, rename symbols, or change behaviour.

The candidates below are limited to exported validation helpers whose checks are
already reached through higher-level public constructors or builder workflows.
They remain exported in Phase 22. A later breaking/deprecation phase would need
separate approval before any `Base.depwarn`, `@deprecate`, export removal, or
runtime behaviour change.

<!-- BEGIN PUBLIC API CLEANUP CANDIDATES -->
| Symbol | Current Lifecycle | Proposed Lifecycle | Migration | Rationale | Risk | Decision |
|---|---|---|---|---|---|---|
| `validate_calibration_step_config` | review-before-v1 | deprecation-candidate | Use `CalibrationStepConfig` construction or `load_public_config` calibration parsing. | Public validation helper duplicates the calibration step constructor and YAML parsing validation paths. | low | Candidate only; no runtime or export change in Phase 22. |
| `validate_cost_per_target_calibration_payload` | review-before-v1 | deprecation-candidate | Use `build_cost_per_target_calibration_payload`. | Public validation helper duplicates the cost-per-target payload builder's validated construction path. | low | Candidate only; no runtime or export change in Phase 22. |
| `validate_lift_test_calibration_payload` | review-before-v1 | deprecation-candidate | Use `build_lift_test_calibration_payload`. | Public validation helper duplicates the lift-test payload builder's validated construction path. | low | Candidate only; no runtime or export change in Phase 22. |
| `validate_mmm_data` | review-before-v1 | deprecation-candidate | Use `MMMData` construction before building `TimeSeriesMMM`. | Public validation helper duplicates the typed data constructor validation path for the time-series workflow. | medium | Candidate only; no runtime or export change in Phase 22. |
| `validate_model_config` | review-before-v1 | deprecation-candidate | Use `ModelConfig` construction or `load_model_config`. | Public validation helper duplicates constructor and config-loader validation paths. | medium | Candidate only; no runtime or export change in Phase 22. |
| `validate_sampler_config` | review-before-v1 | deprecation-candidate | Use `SamplerConfig` construction or `load_sampler_config`. | Public validation helper duplicates constructor and sampler-loader validation paths. | medium | Candidate only; no runtime or export change in Phase 22. |
<!-- END PUBLIC API CLEANUP CANDIDATES -->

## Migration Target Notes

The preferred migration targets for these candidates are existing public
constructors or public workflows, not new APIs. `build_lift_test_calibration_payload`
and `build_cost_per_target_calibration_payload` are the bounded payload
construction workflows that also perform scaling and alignment before
validation. `CalibrationStepConfig`, `MMMData`, `ModelConfig`, `SamplerConfig`,
`load_model_config`, `load_sampler_config`, and `load_public_config` are still
pre-v1 review surfaces in the triage register, but they are the higher-level
typed construction and loading workflows this RFC commits to preserving as the
migration path if these narrower validation-helper exports are later removed.

## Non-Candidate Notes

Most `review-before-v1` exports remain unchanged because their migration paths
are not concrete enough for this RFC. Model lifecycle entry points, pipeline
types, diagnostics structs, priors, calibration math helpers, budget
optimization helpers, and serialization functions need separate API design
review before they can be kept, narrowed, or staged for deprecation.

Lower-level transform validators such as `validate_column_indices` and
`validate_target_data` are also left as `review-before-v1`: they are used by
multiple transform workflows, and this phase does not define one replacement
surface precise enough to be an honest migration path.
