# Build Log: Phase 26 Deprecated Validation Helper Migration Audit

## Scope

Implemented the reviewed Phase 26 migration-audit slice for the six deprecated
validation-helper exports. No runtime/source/model/calibration files were
edited.

## Files Changed

- `.planning/API-EXPORT-CLEANUP-RFC.md`
- `test/api_exports.jl`
- `CHANGELOG.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/26-deprecated-validation-helper-migration-audit/PLAN.md`
- `.planning/phases/26-deprecated-validation-helper-migration-audit/handoff/ARCHITECT-BRIEF.md`
- `.planning/phases/26-deprecated-validation-helper-migration-audit/handoff/REVIEW-FEEDBACK.md`
- `.planning/phases/26-deprecated-validation-helper-migration-audit/handoff/BUILD-LOG.md`
- `.planning/phases/26-deprecated-validation-helper-migration-audit/handoff/REVIEW-REQUEST.md`

## Implementation Notes

- Reworded the cleanup RFC introduction so Phase 22 remains historical
  candidate-governance context while Phase 24 runtime warnings are recognised
  as landed.
- Added a marked `PUBLIC API DEPRECATION MIGRATION AUDIT` table for exactly
  the six deprecated validation-helper exports.
- Recorded all six candidates as:
  - `Runtime Warning = landed`
  - `Replacement Warning-Free = guarded`
  - `Ready To Unexport = no`
- Extended `test/api_exports.jl` to parse and guard the audit table against:
  - the current loaded export surface filtered to the six deprecated helpers,
  - the public API triage register,
  - the Phase 22 cleanup RFC candidate table,
  - the Phase 23/24 runtime-deprecation design source candidate set.
- Guarded parser structure: unique markers through the existing marked-table
  helper, exact header/separator, exactly six rows, and no duplicate symbols.

## Verification

Passed:

```bash
make test-file FILE=test/api_exports.jl
julia --project=@runic -m Runic --check --diff test/api_exports.jl
git diff --name-only -- src/
git diff --check
```

`git diff --name-only -- src/` produced no output, confirming no source/runtime
files changed.

## Known Gaps

- The helpers remain exported and intentionally remain `deprecation-candidate`.
- Actual unexporting remains a separate future breaking/removal phase.
- The full suite was not run because this phase changes planning/API guard
  consistency only and does not touch exports, source files, or shared imports.

## Review Outcome

Implementation review cleared with no Must Fix or Should Fix items.
