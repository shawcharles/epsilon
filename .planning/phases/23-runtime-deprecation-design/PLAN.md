# Phase 23: Runtime Deprecation Design

**Status:** Landed.

## Context

Phase 22 created a candidate-only public API cleanup RFC for six exported
validation helpers. It deliberately did not remove exports, add runtime
warnings, or change behaviour.

The next useful release-prep slice is to design the future runtime deprecation
path before implementing it. The current implementation calls all six
candidate validators from constructors or payload builders, so a naive
`Base.depwarn` inside each validator would warn during normal supported
workflows. Phase 23 prevents that mistake by recording the required wrapper and
internal-helper split, warning texts, tests, and rollback criteria before any
runtime change lands.

## Objective

Create a reviewed implementation design for future runtime deprecation warnings
for the six Phase 22 validation-helper candidates, without changing package
runtime behaviour, exports, tests, user-facing docs, or Abacus parity claims.

## In Scope

- Add `.planning/API-RUNTIME-DEPRECATION-DESIGN.md`.
- Record the six Phase 22 candidate symbols and their future migration targets:
  - `validate_calibration_step_config`
  - `validate_cost_per_target_calibration_payload`
  - `validate_lift_test_calibration_payload`
  - `validate_mmm_data`
  - `validate_model_config`
  - `validate_sampler_config`
- Define the future implementation sequence for runtime deprecation:
  - audit internal calls;
  - split public warning wrappers from unexported internal validation helpers;
  - move internal constructors/builders to warning-free helper calls;
  - emit warnings only from public wrapper calls;
  - preserve existing return values and exception behaviour after the warning.
- Specify future warning text patterns, test expectations, documentation timing,
  and rollback criteria.
- Update `.planning/ROADMAP.md`, `.planning/STATE.md`, and `CHANGELOG.md`
  conservatively to record this design-only phase.
- Refresh ignored Three Man Team handoff files for plan review and
  implementation review.

## Out Of Scope

- Editing `src/`, including `src/Epsilon.jl`.
- Editing `test/`, including `test/api_exports.jl`.
- Adding `Base.depwarn`, `@deprecate`, stderr capture, or warning tests.
- Removing, renaming, reordering, or unexporting symbols.
- Changing constructors, builders, validation semantics, modelling semantics,
  or Abacus parity evidence.
- Updating user-facing docs to announce actual runtime deprecations.
- Moving the package identity/public exports ledger row.
- Running broad benchmarks or release certification.

## Design Constraints

1. Future warnings must fire only when a user directly calls the public
   validation-helper wrapper.
2. Supported constructors, loaders, and payload builders must not emit
   deprecation warnings as a side effect of valid use.
3. Public wrappers must continue to return `nothing` on valid input and throw
   the same validation errors on invalid input after warning emission.
4. If a validator is internally called today, the future implementation must
   first introduce an unexported core helper and update internal call sites.
5. The deprecation path must stay pre-v1 and staged: warning first, then
   possible unexport/removal only after a separate approved phase.
6. Future warnings must preserve the exact validation exception type and
   message after emission.
7. The design must not imply that the six migration targets are a fully frozen
   v1 API. They are the preferred existing public workflows for this cleanup
   slice.

## Planned Future Runtime Implementation Contract

A later implementation phase may add runtime warnings only if it satisfies this
contract:

1. Introduce warning-free internal helpers for each candidate whose current
   implementation is called internally.
2. Keep the existing public function names as thin wrappers that call
   `Base.depwarn` and then delegate to the internal helper.
3. Ensure constructors, loaders, and payload builders call the internal helper,
   not the public warning wrapper.
4. Preserve exact validation exception types and messages after warning
   emission.
5. Add focused tests proving:
   - direct public calls warn;
   - valid direct calls still return `nothing`;
   - invalid direct calls still throw the same `ArgumentError` with the same
     message;
   - constructors/builders using the same validation path do not warn;
   - the six symbols remain exported until a later approved unexport phase.
6. Update user-facing API docs and changelog only when runtime warnings actually
   land.

## Tasks

### Task 23-01: Plan Review

Acceptance criteria:

- [x] This plan is reviewed by an independent subagent before implementation.
- [x] Must Fix review items are resolved before design-document work starts.
- [x] The reviewed plan keeps Phase 23 design-only.

Verification:

- [x] `.planning/phases/23-runtime-deprecation-design/handoff/ARCHITECT-BRIEF.md`
      matches the reviewed plan.
- [x] `.planning/phases/23-runtime-deprecation-design/handoff/REVIEW-FEEDBACK.md`
      records the plan review result.

**Status:** Landed. Independent plan review found no Must Fix items. Two
Should Fix items were incorporated before design-document implementation:
phase-local handoff paths are explicit, and future warnings must preserve exact
validation exception types and messages.

### Task 23-02: Runtime Deprecation Design Document

Acceptance criteria:

- [x] `.planning/API-RUNTIME-DEPRECATION-DESIGN.md` exists.
- [x] The document lists all six Phase 22 candidates exactly once.
- [x] Each candidate has a migration target, future warning text, internal-call
      handling requirement, future tests, and rollback note.
- [x] The document states that Phase 23 makes no runtime or export change.

Verification:

- [x] Manual review against `.planning/API-EXPORT-CLEANUP-RFC.md` confirms the
      same six candidates and migration targets.

**Status:** Landed. `.planning/API-RUNTIME-DEPRECATION-DESIGN.md` records the
future deprecation contract for the six Phase 22 validation-helper candidates,
including exact warning text, wrapper/internal-helper split requirements,
targeted future tests, documentation timing, and rollback criteria.

### Task 23-03: Planning Closure

Acceptance criteria:

- [x] `.planning/ROADMAP.md`, `.planning/STATE.md`, and `CHANGELOG.md` record
      Phase 23 as a design-only phase.
- [x] `.planning/ABACUS-PARITY-LEDGER.md` is left unchanged unless review finds
      a specific consistency issue.
- [x] No `src/`, `test/`, or `docs/src` files are edited.

Verification:

- [x] `git diff --check`
- [x] `git diff --cached --check`

No Julia test lane is required for Phase 23 if it remains planning-only. A
future runtime deprecation phase that touches `src/`, exports, public API docs,
or export-surface tests must run targeted API/export tests and any directly
affected model/config tests.

**Status:** Landed. The final diff is planning/changelog only. The parity ledger
and executable package files were not edited.

### Task 23-04: Implementation Review And Commit

Acceptance criteria:

- [x] Builder writes
      `.planning/phases/23-runtime-deprecation-design/handoff/REVIEW-REQUEST.md`.
- [x] Reviewer writes
      `.planning/phases/23-runtime-deprecation-design/handoff/REVIEW-FEEDBACK.md`.
- [x] All Must Fix items are resolved before commit.
- [x] The commit includes only the intended Phase 23 planning/design files.

Verification:

```bash
git status --short
git diff --stat
git diff --check
```

**Status:** Landed. Implementation review found no Must Fix or Should Fix
items. The reviewer approved scoped verification for this markdown-only phase
and noted that `git diff --cached --check` should be run after staging so new
untracked markdown files are covered.
