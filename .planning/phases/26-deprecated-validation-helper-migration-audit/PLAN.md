# Phase 26: Deprecated Validation Helper Migration Audit

**Status:** Landed.

## Context

Phases 22 through 24 identified six exported validation helpers as
`deprecation-candidate` APIs and then implemented runtime `Base.depwarn`
wrappers around warning-free internal helpers. Phase 25 added a focused
`Pkg.test` file harness, so this API-governance slice can now be checked with
the `api_exports` lane instead of the full suite.

The current problem is not that the helpers should be removed immediately. The
problem is that the planning records now span multiple phases: the Phase 22 RFC
is historical, the Phase 23/24 runtime-deprecation design is current, and the
triage register still marks the same six symbols as candidates. Phase 26 should
make that state machine explicit and guard it.

## Objective

Record and test a migration-readiness audit for the six deprecated validation
helper exports, without changing exports, warning behaviour, model semantics,
or Abacus parity claims.

## Candidate Set

- `validate_calibration_step_config`
- `validate_cost_per_target_calibration_payload`
- `validate_lift_test_calibration_payload`
- `validate_mmm_data`
- `validate_model_config`
- `validate_sampler_config`

## In Scope

- Add a machine-checkable migration audit table for the six candidates.
- Reconcile wording in the Phase 22 cleanup RFC so it remains historical but no
  longer reads as the current whole truth after Phase 24 warnings landed.
- Extend `test/api_exports.jl` to guard the migration audit against:
  - the triage register at `.planning/API-EXPORT-TRIAGE.md`
    (`<!-- BEGIN PUBLIC API TRIAGE -->`),
  - the Phase 22 cleanup RFC,
  - the Phase 23/24 runtime-deprecation design at
    `.planning/API-RUNTIME-DEPRECATION-DESIGN.md` (`## Source Candidate Set`),
  - the current loaded `Epsilon` export surface filtered to the six deprecated
    validation-helper symbols.
- Record whether each candidate is ready for later unexporting.
- Update changelog, roadmap, state, and phase handoff files.

## Out Of Scope

- Removing exports from `src/Epsilon.jl`.
- Removing functions or changing public signatures.
- Changing deprecation warning text.
- Changing validation behaviour or error messages.
- Changing constructors, loaders, calibration payload builders, model code, or
  Abacus parity status.
- Running the full suite by default.

## Proposed Contract

Add a marked table, likely in `.planning/API-EXPORT-CLEANUP-RFC.md`, with rows
for exactly the six candidates:

```markdown
<!-- BEGIN PUBLIC API DEPRECATION MIGRATION AUDIT -->
| Symbol | Runtime Warning | Migration Path | Replacement Warning-Free | Ready To Unexport | Evidence |
|---|---|---|---|---|---|
...
<!-- END PUBLIC API DEPRECATION MIGRATION AUDIT -->
```

Expected values:

- `Runtime Warning`: `landed`
- `Migration Path`: exact text matching the RFC and triage migration field
- `Replacement Warning-Free`: `guarded`
- `Ready To Unexport`: `no`
- `Evidence`: non-empty phase/test references

The important decision is `Ready To Unexport = no`. Phase 26 should prove the
migration state is coherent, not pretend the package has completed its
deprecation period or that downstream users have had time to react.

## Design Constraints

1. The six helpers remain exported after Phase 26.
2. The six helpers remain `deprecation-candidate` in the triage register.
3. The runtime warning contract remains owned by the existing Phase 23/24
   design document.
4. Existing warning-free replacement-path tests in `test/model/types.jl` and
   `test/model/calibration.jl` remain the behavioural evidence.
5. The new `api_exports` guard validates planning consistency only; it must not
   require broad runtime/model tests.
6. Any wording must be explicit that this is not a stable-v1 API claim and not
   an Abacus parity claim.

## Verification Plan

Targeted only:

```bash
make test-file FILE=test/api_exports.jl
julia --project=@runic -m Runic --check --diff test/api_exports.jl
git diff --check
```

Optional spot checks if the implementation touches wording in runtime design
or candidate docs:

```bash
make test-file FILE=test/model/types.jl
make test-file FILE=test/model/calibration.jl
```

Do not run the full suite unless Phase 26 unexpectedly changes exports,
runtime source files, or shared test imports.

## Tasks

### Task 26-01: Plan Review

Acceptance criteria:

- [x] This plan is reviewed before implementation.
- [x] Must Fix review items are resolved before edits beyond planning files.
- [x] The reviewed scope remains migration audit and guardrail only.

Verification:

- [x] `handoff/ARCHITECT-BRIEF.md` matches this plan.
- [x] `handoff/REVIEW-FEEDBACK.md` records the plan review result.

### Task 26-02: Migration Audit Record

Acceptance criteria:

- [x] A marked migration audit table records all six deprecated helpers.
- [x] The table records runtime warnings as landed.
- [x] The table records replacement paths as warning-free and guarded.
- [x] The table records all six candidates as not ready to unexport yet.
- [x] RFC wording distinguishes historical Phase 22 candidate status from
      current post-Phase-24 runtime-warning status.

Verification:

```bash
git diff -- .planning/API-EXPORT-CLEANUP-RFC.md
```

### Task 26-03: Focused API Guard

Acceptance criteria:

- [x] `test/api_exports.jl` parses the migration audit table.
- [x] The parser requires unique begin/end markers, the exact expected table
      header, exactly six data rows, and no duplicate symbols.
- [x] The guard requires all six deprecated validation-helper symbols to remain
      exported.
- [x] The guard requires exact symbol-set agreement across the filtered
      deprecated-helper export subset, triage candidates, RFC candidates, and
      migration audit rows.
- [x] The guard requires migration text to match triage/RFC values exactly.
- [x] The guard requires `Runtime Warning = landed`,
      `Replacement Warning-Free = guarded`, and `Ready To Unexport = no`.
- [x] The guard requires evidence text to be non-empty.

Verification:

```bash
make test-file FILE=test/api_exports.jl
julia --project=@runic -m Runic --check --diff test/api_exports.jl
git diff --check
```

### Task 26-04: Planning Closure And Review

Acceptance criteria:

- [x] `CHANGELOG.md`, `.planning/ROADMAP.md`, and `.planning/STATE.md` record
      Phase 26 conservatively.
- [x] `handoff/BUILD-LOG.md` and `handoff/REVIEW-REQUEST.md` are written.
- [x] An implementation review is completed before commit.
- [x] All Must Fix items are resolved before commit.
- [x] The commit includes only intended Phase 26 files.

Verification:

```bash
git status --short
git diff --stat
git diff --name-only -- src/
git diff --check
```
