# Public API Export Cleanup RFC

Phase 22 records candidate-only public API cleanup decisions for a small slice
of the current loaded `Epsilon` export surface. It does not remove exports,
rename symbols, or change behaviour.

That Phase 22 statement is historical. Phase 24 has since landed runtime
`Base.depwarn` wrappers for the same six validation helpers while preserving
exports and warning-free replacement workflows. The cleanup table below remains
the source record for the candidate decision and migration text; the migration
audit table records the current post-Phase-24 readiness state.

The candidates below are limited to exported validation helpers whose checks are
already reached through higher-level public constructors or builder workflows.
They remained exported in Phase 22 and remain exported after Phase 24. A later
breaking/removal phase still needs separate approval before any `@deprecate`,
export removal, or behaviour change beyond the landed runtime warning wrappers.

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

## Migration Readiness Audit

The current state is deliberately not "ready to unexport". Runtime warnings and
warning-free replacements are now guarded, but the project has not completed a
deprecation period, changed docs inventory rows, or made a stable-v1 API
decision.

<!-- BEGIN PUBLIC API DEPRECATION MIGRATION AUDIT -->
| Symbol | Runtime Warning | Migration Path | Replacement Warning-Free | Ready To Unexport | Evidence |
|---|---|---|---|---|---|
| `validate_calibration_step_config` | landed | Use `CalibrationStepConfig` construction or `load_public_config` calibration parsing. | guarded | no | Phase 24 runtime wrapper; test/model/calibration.jl replacement-path coverage; Phase 26 api_exports audit guard. |
| `validate_cost_per_target_calibration_payload` | landed | Use `build_cost_per_target_calibration_payload`. | guarded | no | Phase 24 runtime wrapper; test/model/calibration.jl replacement-path coverage; Phase 26 api_exports audit guard. |
| `validate_lift_test_calibration_payload` | landed | Use `build_lift_test_calibration_payload`. | guarded | no | Phase 24 runtime wrapper; test/model/calibration.jl replacement-path coverage; Phase 26 api_exports audit guard. |
| `validate_mmm_data` | landed | Use `MMMData` construction before building `TimeSeriesMMM`. | guarded | no | Phase 24 runtime wrapper; test/model/types.jl replacement-path coverage; Phase 26 api_exports audit guard. |
| `validate_model_config` | landed | Use `ModelConfig` construction or `load_model_config`. | guarded | no | Phase 24 runtime wrapper; test/model/types.jl replacement-path coverage; Phase 26 api_exports audit guard. |
| `validate_sampler_config` | landed | Use `SamplerConfig` construction or `load_sampler_config`. | guarded | no | Phase 24 runtime wrapper; test/model/types.jl replacement-path coverage; Phase 26 api_exports audit guard. |
<!-- END PUBLIC API DEPRECATION MIGRATION AUDIT -->

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
