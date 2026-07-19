# Phase 61: AD-Safety Validation Audit

Status: Implemented

## Objective

Close the small AD-safety concern from the July critical review by auditing
numeric validation boundaries and fixing only validation casts that sit on
typed model data construction paths.

The target is narrow:

- replace validation-only `Float64(value)` finiteness/nonnegativity checks in
  `MMMData` and `PanelMMMData` validation with generic `Real`/`isfinite` and
  native comparison checks; and
- add focused `ForwardDiff` constructor tests proving those data containers can
  carry AD scalar arrays through validation without narrowing or throwing.

## Current Boundary

The initial audit found several concrete `Float64` surfaces. Most are not AD
paths:

- CSV/pipeline ingestion intentionally converts DataFrame columns into concrete
  `Float64` arrays.
- Optimisation interpolation, JuMP registration, allocation results, summaries,
  and scenario tables intentionally materialise original-unit user-facing
  values as `Float64`.
- HSGP prior/config helpers intentionally coerce user priors and persisted
  model-spec state into finite scalar configuration values.
- Postmodel replay and reporting intentionally materialise chain values and
  tabular outputs.

The model data validators are different: `MMMData` and `PanelMMMData` are
parametric over caller-supplied array types, but `_validate_numeric_values`
currently checks finiteness through `Float64(value)`, and
`_validate_nonnegative_values` checks nonnegativity through `Float64(value)`.
That is a validation-only narrowing point on a container type that otherwise
advertises generic numeric arrays.

## Scope

In scope:

- `src/model/types.jl`
  - Update `_validate_numeric_values` to require `value isa Real` and
    `isfinite(value)` without `Float64` conversion.
  - Update `_validate_nonnegative_values` to check `value isa Real` and
    `value >= zero(value)` using the native scalar type, without `Float64`
    conversion.
  - Keep `_validate_numeric_values` before `_validate_nonnegative_values` on
    channel arrays so non-finite channels retain the finite-numeric error
    message and negative finite channels retain the nonnegative error message.
- `test/model/types.jl`
  - Add focused `ForwardDiff` smoke tests for `MMMData` and `PanelMMMData`
    construction with AD scalar arrays.
  - Preserve existing error messages for non-finite and negative values.
- `CHANGELOG.md`
  - Add a small `Unreleased` note for the AD-safety validator hardening.
- This plan file.

Out of scope:

- Changing CSV ingestion, pipeline stage materialisation, optimisation
  interpolation/JuMP code, postmodel summaries, result structs, fixtures,
  generated fixture exporters, exports, ROADMAP, STATE, parity ledger, or
  public API names.
- Broad concrete-array refactors.
- Any full-suite test run.
- Staging the pre-existing `.gitignore` drift or the untracked
  `.planning/CRITICAL-REVIEW-2026-07-19.md`.

## File Allowlist

Implementation may touch only:

- `src/model/types.jl`
- `test/model/types.jl`
- `CHANGELOG.md`
- `.planning/phases/61-ad-safety-validation-audit/PLAN.md`

The following local files are explicitly non-phase drift and must remain
unstaged:

- `.gitignore`
- `.planning/CRITICAL-REVIEW-2026-07-19.md`

## Tasks

### Task 61-01: Plan Review

Acceptance criteria:

- [x] Independent reviewer confirms the scoped AD boundary is correct.
- [x] Reviewer confirms concrete `Float64` ingestion/result/optimisation paths
      should remain out of scope.
- [x] Reviewer confirms the test plan is sufficient without running the full
      suite.

Verification:

- [x] Review result is recorded in this plan before implementation.

### Task 61-02: Generic Validator Semantics

Acceptance criteria:

- [x] `_validate_numeric_values` no longer converts values to `Float64` solely
      to test finiteness.
- [x] `_validate_nonnegative_values` no longer converts values to `Float64`
      solely to test sign.
- [x] Existing public error messages for non-finite and negative data remain
      unchanged.
- [x] No data container field types, constructor signatures, or public API
      names change.

Verification:

- [x] Existing `test/model/types.jl` invalid-data tests remain passing.

### Task 61-03: Focused AD Smoke Tests

Acceptance criteria:

- [x] `MMMData` construction succeeds inside a `ForwardDiff.gradient` objective
      when target and channel arrays contain dual scalars.
- [x] `PanelMMMData` construction succeeds inside a `ForwardDiff.gradient`
      objective when target and channel arrays contain dual scalars.
- [x] Gradients are finite and equal to the expected simple linear objective
      values.

Verification:

- [x] `make test-file FILE=test/model/types.jl` passes.
- [x] `make format-check-touched` passes.
- [x] `git diff --check` passes.
- [x] `git diff --name-only | sort` confirms only allowlisted files plus known
      pre-existing local drift are present.
- [x] `git diff --cached --check` passes before commit.
- [x] `git diff --cached --name-only | sort` confirms the staged allowlist.
- [x] `git status --short --branch` is checked before commit.

## Independent Review Questions

Before implementation, an independent reviewer must check:

- whether `MMMData` and `PanelMMMData` validation is genuinely an AD-sensitive
  boundary;
- whether replacing `Float64(value)` with native `isfinite(value)` and native
  comparisons changes any intended user-facing validation semantics;
- whether the tests should use constructor-level AD smoke tests rather than a
  Turing fit;
- whether `CHANGELOG.md` is appropriate for this small hardening change; and
- whether any broader concrete `Float64` cleanup should be split into a future
  phase rather than included here.

## Independent Review Result

The independent reviewer approved the plan with two tightening points:

- The AD-sensitive boundary is correctly scoped to the parametric
  `MMMData`/`PanelMMMData` validators; CSV ingestion, HSGP config coercion,
  optimisation/JuMP, postmodel replay, summaries, and result materialisation
  should remain concrete and out of scope.
- Task 61-02 should explicitly preserve the existing validator ordering so
  non-finite channel arrays still produce the finite-numeric error and finite
  negative channel arrays still produce the nonnegative error.
- Task 61-03 should use constructor-level `ForwardDiff.gradient` objectives
  rather than Turing fits. The reviewer recommended exact simple-gradient
  objectives: `sum(data.target) + 2sum(data.channels)` for `MMMData`, and
  `sum(data.target) + 3sum(data.channels)` for `PanelMMMData`, with positive
  seed parameters and finite/equality assertions.
- `make test-file FILE=test/model/types.jl` is the correct scoped verification
  command because `ForwardDiff` is available through the package test target.

## Landing Notes

- Replaced validation-only `Float64(value)` casts in `src/model/types.jl` with
  native `isfinite(value)` and `value >= zero(value)` checks guarded by
  `value isa Real`.
- Preserved the existing validation order for channel arrays:
  finite-numeric validation still runs before nonnegative validation.
- Added two constructor-level `ForwardDiff.gradient` smoke tests in
  `test/model/types.jl`, covering `MMMData` and `PanelMMMData` with AD scalar
  target/channel arrays and exact simple-gradient expectations.
- Added a short `CHANGELOG.md` note under `Unreleased / Changed`.
- Left CSV/pipeline ingestion, optimisation/JuMP code, HSGP config coercion,
  postmodel materialisation, exports, ROADMAP, STATE, parity ledger, fixtures,
  and generated artifacts untouched.
- Left non-phase local drift unstaged: `.gitignore` currently adds
  `graphify-out/`, and `.planning/CRITICAL-REVIEW-2026-07-19.md` remains
  untracked.

Scoped verification:

```bash
make test-file FILE=test/model/types.jl
# Epsilon.jl: 76 passed / 76 total, 14.6s

make format-check-touched
git diff --check
# both passed with no output

git diff --name-only | sort
# .gitignore
# CHANGELOG.md
# src/model/types.jl
# test/model/types.jl

git ls-files --others --exclude-standard | sort
# .planning/CRITICAL-REVIEW-2026-07-19.md
# .planning/phases/61-ad-safety-validation-audit/PLAN.md
```
