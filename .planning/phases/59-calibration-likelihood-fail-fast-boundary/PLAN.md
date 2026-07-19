# Phase 59: Calibration Likelihood Fail-Fast Boundary

Status: Implemented

## Objective

Lock the boundary between user/config calibration invalidity and sampler-state
invalidity for the bounded `TimeSeriesMMM` calibration likelihood path.

Malformed calibration supplied through constructor keywords, public config
parsing, or `ModelConfig.extras["calibration"]` must fail before sampling.
Invalid sampled states encountered inside the Turing model may continue to map
to `-Inf` through `Turing.@addlogprob!`, because that preserves DynamicPPL's
fixed-model-evaluation invariants and avoids hard failures during NUTS/AD
probes.

## Current Boundary

Constructor keyword data already uses eager validated row constructors:

- `LiftTestCalibrationRows`
- `CostPerTargetCalibrationRows`
- `CalibrationStepConfig`
- `_build_calibration_input`

Resolved model-space payloads already validate when built through:

- `build_lift_test_calibration_payload`
- `build_cost_per_target_calibration_payload`
- `_resolve_calibration_spec`

The Turing path in `_time_series_mmm_model` intentionally catches
`ArgumentError` from calibration log-density helpers and contributes `-Inf`.
That behaviour must remain for invalid sampled states.

The risk is the lower-level positional struct path: callers or internal config
state can construct `TimeSeriesCalibrationInput`, `MMMCalibrationSpec`,
`LiftTestCalibrationPayload`, or `CostPerTargetCalibrationPayload` directly
with invalid values, and the current `ModelConfig.extras["calibration"]`
boundary only checks the top-level type.

## Scope

In scope:

- Add internal validators for `TimeSeriesCalibrationInput` and
  `MMMCalibrationSpec` if the audit confirms they are missing.
- Reuse existing row/payload validators rather than duplicating validation
  logic.
- Validate `ModelConfig.extras["calibration"]` before a `TimeSeriesMMM` accepts
  it.
- Validate the resolved calibration spec before `_fit_time_series_mmm!` passes
  payloads to `_time_series_mmm_model`.
- Reject lift-test calibration with non-`logistic` saturation before the Turing
  model object is constructed.
- Add focused tests proving invalid hand-built raw inputs and resolved payloads
  fail before sampling.
- Add one focused test proving the model-level `ArgumentError` to `-Inf`
  mapping still applies for invalid sampled saturation states, using a valid
  payload and invalid sampled parameter values rather than a malformed payload.

Out of scope:

- Removing the `try`/`catch -> -Inf` blocks from `_time_series_mmm_model`.
- Adding panel calibration.
- Adding or reopening variational inference.
- Expanding YAML schema semantics beyond existing calibration blocks.
- Changing calibration maths, scaling semantics, fixture exporters, public
  exports, docs inventory, ROADMAP, STATE, or the parity ledger.
- Trusted-local model deserialization boundaries in `src/model/io.jl`; those
  remain outside this phase and should be handled separately if needed.
- Running the full test suite.

## File Allowlist

Implementation may touch only:

- `src/mmm/calibration.jl`
- `src/model/builder.jl`
- `src/mmm/model.jl`
- `test/model/calibration.jl`
- `test/model/builder.jl`
- `.planning/phases/59-calibration-likelihood-fail-fast-boundary/PLAN.md`

The pre-existing untracked `.planning/CRITICAL-REVIEW-2026-07-19.md` remains
outside this phase and must not be staged.

## Tasks

### Task 59-01: Audit And Plan Review

Acceptance criteria:

- [x] Identify every calibration acceptance boundary from constructor/config
      input to `_time_series_mmm_model`.
- [x] Confirm which invalid states are user/config errors and which are sampled
      model states.
- [x] Get independent review approval before implementation.

Verification:

- [x] Reviewer explicitly approves the boundary and scoped test strategy.

### Task 59-02: Boundary Validators

Acceptance criteria:

- [x] `TimeSeriesCalibrationInput` validation rejects repeated/mismatched steps
      and invalid directly constructed row payloads.
- [x] `MMMCalibrationSpec` validation rejects invalid directly constructed
      resolved payloads.
- [x] Resolved lift-test payload validation checks channel indices against the
      model's channel count, not only positive indexing.
- [x] `ModelConfig.extras["calibration"]` validates its
      `TimeSeriesCalibrationInput` before `TimeSeriesMMM` stores it.
- [x] `_fit_time_series_mmm!` validates resolved specs before model creation.
- [x] Lift-test calibration with non-`logistic` saturation fails before
      `_time_series_mmm_model` construction.

Verification:

- [x] Focused calibration or builder tests cover malformed direct construction
      paths.

### Task 59-03: Preserve Sampler Invalid-State Semantics

Acceptance criteria:

- [x] Existing `Turing.@addlogprob!` invalid sampled-state behaviour remains
      unchanged.
- [x] A focused model evaluation test demonstrates an invalid sampled
      lift-test state contributes `-Inf` rather than throwing.

Verification:

- [x] No early return is introduced in `_time_series_mmm_model`.
- [x] Model evaluation still touches the same stochastic statements as the
      calibrated path.

## Verification

Use scoped checks only:

```bash
JULIA_PKG_SERVER_REGISTRY_PREFERENCE=eager make test-file FILE=test/model/calibration.jl
JULIA_PKG_SERVER_REGISTRY_PREFERENCE=eager make test-file FILE=test/model/builder.jl
make format-check-touched
git diff --check
git diff --cached --check
git diff --cached --name-only | sort
git status --short --branch
```

No full suite is required because this phase changes only calibration boundary
validation and focused model-layer tests. It does not add/remove exports, touch
shared test imports, change dependencies, regenerate fixtures, alter pipeline
stage execution, or update release/parity state.

## Independent Review Questions

Before implementation, an independent reviewer must check:

- whether validating `ModelConfig.extras["calibration"]` and resolved
  `MMMCalibrationSpec` is sufficient to prevent malformed user/config data from
  being masked by `@addlogprob! -Inf`;
- whether positional constructors should remain available but guarded by
  boundary validation, rather than changing struct constructors in a
  compatibility-impacting way;
- whether the model-level `ArgumentError -> -Inf` catch blocks should remain;
- whether the proposed tests are sufficient and scoped; and
- whether the file allowlist is tight enough.

## Independent Review Result

The independent reviewer approved the boundary and scoped verification strategy
with required tightening before implementation:

- Keep the user/config versus sampled-state split: malformed calibration data
  must throw before sampling, while invalid sampled states inside
  `_time_series_mmm_model` should continue to contribute `-Inf`.
- Add concrete validators for `TimeSeriesCalibrationInput`,
  `MMMCalibrationSpec`, direct positional raw row payloads, and direct
  positional resolved payloads.
- Validate `ModelConfig.extras["calibration"]` beyond top-level type.
- Validate the resolved calibration spec before `_time_series_mmm_model`
  construction, with model context for lift-test channel-index upper bounds.
- Reject lift-test calibration with non-`logistic` saturation before Turing
  model construction rather than inside the model body.
- Preserve the existing `try`/`catch -> -Inf` blocks and avoid early returns
  inside `_time_series_mmm_model`.
- Test `-Inf` preservation with a valid payload plus invalid conditioned
  sampled saturation values, not with a malformed payload.
- Keep `src/model/io.jl`, docs, ROADMAP, STATE, parity ledger, fixtures, and
  full-suite verification out of scope.

## Landing Notes

- Added private row validators for direct positional
  `LiftTestCalibrationRows` and `CostPerTargetCalibrationRows`; keyword
  constructors now route through those validators and reject empty rows.
- Added private validators for `TimeSeriesCalibrationInput` and
  `MMMCalibrationSpec`, reusing the existing step, row, and payload checks.
- Rejected empty direct calibration input/spec values, because absence of
  calibration is represented as `nothing`.
- Added model-context resolved-spec validation for lift-test channel-index
  upper bounds and saturation type.
- Validated `ModelConfig.extras["calibration"]` before `TimeSeriesMMM` accepts
  opaque programmatic calibration state.
- Moved lift-test plus non-`logistic` saturation rejection to the
  `TimeSeriesMMM` construction boundary while preserving the defensive runtime
  check inside `_time_series_mmm_model`.
- Preserved the existing model-level `try`/`catch -> -Inf` blocks and added a
  focused test proving a valid lift-test payload with invalid sampled `lam`
  values evaluates to `-Inf` without throwing.
- Left `src/model/io.jl`, docs, ROADMAP, STATE, parity ledger, fixtures, and
  full-suite verification untouched.

Scoped verification:

```bash
JULIA_PKG_SERVER_REGISTRY_PREFERENCE=eager make test-file FILE=test/model/calibration.jl
# Epsilon.jl: 166 passed / 166 total, 17.3s

JULIA_PKG_SERVER_REGISTRY_PREFERENCE=eager make test-file FILE=test/model/builder.jl
# Epsilon.jl: 316 passed / 316 total, 3m49.5s

make format-check-touched
git diff --check
# both passed with no output
```
