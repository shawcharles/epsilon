# Phase 24: Runtime Deprecation Wrappers

**Status:** Landed.

## Context

Phase 22 marked six exported validation helpers as candidate-only public API
cleanup targets. Phase 23 designed the runtime-deprecation path and identified
the main implementation risk: the current public validators are also called by
supported constructors and payload builders. Adding `Base.depwarn` directly to
those validator bodies would warn during the replacement workflows users are
supposed to migrate toward.

## Objective

Implement runtime deprecation warnings for the six Phase 22 validation-helper
candidates by splitting each current validator into a warning-free internal
helper plus a public warning wrapper. Preserve exports, validation semantics,
return values, and exact validation exception messages.

## In Scope

- `src/mmm/calibration.jl`
  - `validate_calibration_step_config`
  - `validate_lift_test_calibration_payload`
  - `validate_cost_per_target_calibration_payload`
- `src/model/types.jl`
  - `validate_sampler_config`
  - `validate_model_config`
  - `validate_mmm_data`
- Focused tests in:
  - `test/model/calibration.jl`
  - `test/model/types.jl`
- Public docstrings for the six validators, because runtime behaviour changes.
- Conservative updates to `CHANGELOG.md`, `.planning/ROADMAP.md`,
  `.planning/STATE.md`, `.planning/API-RUNTIME-DEPRECATION-DESIGN.md`, and
  `.planning/ABACUS-PARITY-LEDGER.md` only as needed to record the landed
  runtime-warning slice.
- Phase-local Three Man Team handoff files.

## Out Of Scope

- Removing, renaming, reordering, or unexporting any symbol in `src/Epsilon.jl`.
- Editing `docs/src/api.md` inventory rows or changing support bands.
- Broad public API cleanup beyond the six candidates.
- Changing constructors, builders, loaders, validation predicates, model
  semantics, inference semantics, calibration likelihood behaviour, or Abacus
  parity claims.
- Reopening panel validation, scenario planning, benchmarks, release tagging,
  or export removal.
- Running the full suite unless implementation unexpectedly touches exports,
  shared test namespace behaviour, or wider package infrastructure.

## Invariants

1. Direct public calls to each `validate_*` candidate emit a deprecation
   warning.
2. Direct valid public calls still return `nothing`.
3. Direct invalid public calls still throw the same `ArgumentError` type and
   exact message as before, after warning emission.
4. Supported constructors, loaders, and payload builders do not emit
   deprecation warnings during valid use.
5. The six symbols remain exported and present in the API inventory.
6. No numerical, modelling, scaling, AD, or Abacus parity semantics change.

## Implementation Pattern

For each candidate:

1. Move the current validation body into an unexported `_validate_*` helper.
2. Update internal constructors/builders/loaders to call the helper.
3. Keep the public `validate_*` method as a thin wrapper:
   - call `Base.depwarn` with the exact Phase 23 warning text;
   - delegate to the internal helper;
   - return the helper result.
4. Update tests to exercise both the public warning wrapper and the silent
   replacement workflow.
5. Use explicit warning assertions (`@test_deprecated`, `@test_logs`, or
   equivalent), not visible-stderr inspection.
6. For invalid direct public calls, assert exact `ArgumentError` message text,
   not only exception type.

Use manual wrappers rather than `@deprecate` so the function behaviour and
method signature remain intact through the pre-v1 warning period.

## Warning Texts

Use the warning texts recorded in `.planning/API-RUNTIME-DEPRECATION-DESIGN.md`
without broadening the claim that these APIs are removed. Each warning should
say the function remains exported for this release and may be unexported before
v1.

## Verification Plan

Targeted checks only:

```bash
julia --depwarn=yes --project=. test/model/calibration.jl
julia --depwarn=yes --project=. test/model/types.jl
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["api_exports", "basic"])'
julia --project=@runic -m Runic --check --diff src/mmm/calibration.jl src/model/types.jl test/model/calibration.jl test/model/types.jl
git diff --check
```

Rationale: this phase changes public runtime warnings and docstrings for six
existing exported functions, but it does not change export inventory,
cross-file imports, model semantics, or package-wide test namespace behaviour.
Run the full suite only if the implementation touches `src/Epsilon.jl`,
`test/runtests.jl`, shared imports, or unrelated package infrastructure.

## Tasks

### Task 24-01: Plan Review

Acceptance criteria:

- [x] This plan is reviewed by an independent subagent before implementation.
- [x] Must Fix review items are resolved before source edits start.
- [x] The reviewed plan keeps Phase 24 bounded to the six validators.
- [x] Plan-review Should Fix items are incorporated into the Builder brief:
      explicit warning assertions, exact invalid-message assertions, and direct
      public-call coverage for all six wrappers.

Verification:

- [x] `.planning/phases/24-runtime-deprecation-wrappers/handoff/ARCHITECT-BRIEF.md`
      matches the reviewed plan.
- [x] `.planning/phases/24-runtime-deprecation-wrappers/handoff/REVIEW-FEEDBACK.md`
      records the plan review result.

### Task 24-02: Calibration Validator Wrappers

Acceptance criteria:

- [x] Calibration validators are split into `_validate_*` helpers and public
      warning wrappers.
- [x] `CalibrationStepConfig`, `build_lift_test_calibration_payload`, and
      `build_cost_per_target_calibration_payload` use warning-free helpers.
- [x] Public docstrings state the public validator wrapper is deprecated.
- [x] Tests prove direct public calls warn and replacement workflows do not.

Verification:

The direct root-project command above cannot load `ForwardDiff` because
calibration test imports use test-target dependencies. The equivalent targeted
calibration-file check passed through a temporary test environment:

```bash
julia --depwarn=yes --project=. -e 'using Pkg; Pkg.activate(; temp=true); Pkg.develop(path=pwd()); Pkg.add(["ForwardDiff", "ReverseDiff", "Distributions"]); include("test/model/calibration.jl")'
```

### Task 24-03: Model/Data Validator Wrappers

Acceptance criteria:

- [x] `validate_sampler_config`, `validate_model_config`, and
      `validate_mmm_data` are split into `_validate_*` helpers and public
      warning wrappers.
- [x] `SamplerConfig`, `ModelConfig`, `MMMData`, and config loader paths use
      warning-free helpers.
- [x] Public docstrings state the public validator wrapper is deprecated.
- [x] Tests prove direct public calls warn and replacement workflows do not.

Verification:

```bash
julia --depwarn=yes --project=. test/model/types.jl
```

### Task 24-04: API Guard And Planning Closure

Acceptance criteria:

- [x] `api_exports` still passes, proving exports and doc coverage remain
      intact.
- [x] `CHANGELOG.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`,
      `.planning/API-RUNTIME-DEPRECATION-DESIGN.md`, and
      `.planning/ABACUS-PARITY-LEDGER.md` describe the runtime-warning slice
      conservatively.
- [x] No export removal or stronger Abacus API parity claim is made.

Verification:

```bash
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["api_exports", "basic"])'
julia --project=@runic -m Runic --check --diff src/mmm/calibration.jl src/model/types.jl test/model/calibration.jl test/model/types.jl
git diff --check
```

### Task 24-05: Implementation Review And Commit

Acceptance criteria:

- [x] Builder writes
      `.planning/phases/24-runtime-deprecation-wrappers/handoff/REVIEW-REQUEST.md`.
- [x] Reviewer writes
      `.planning/phases/24-runtime-deprecation-wrappers/handoff/REVIEW-FEEDBACK.md`.
- [x] All Must Fix items are resolved before commit.
- [x] The current Builder diff includes only the intended Phase 24 files.

Verification:

```bash
git status --short
git diff --stat
git diff --check
```

**Status:** Landed. Implementation review found no source/test defects and one
planning-doc Must Fix, which was resolved before commit. The reviewer cleared
Phase 24 after the fix. Scoped verification passed; the full suite was not run
because no export list, shared test imports, or broader package infrastructure
changed.
