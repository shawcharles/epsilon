# Architect Brief: Phase 26 Deprecated Validation Helper Migration Audit

## Step Name

Phase 26: Deprecated Validation Helper Migration Audit.

## Objective

Make the post-Phase-24 state of the six deprecated validation-helper exports
explicit and machine-checked, without unexporting anything or changing runtime
behaviour.

## Files In Scope

- `.planning/API-EXPORT-CLEANUP-RFC.md`
- `test/api_exports.jl`
- `CHANGELOG.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/26-deprecated-validation-helper-migration-audit/PLAN.md`
- `.planning/phases/26-deprecated-validation-helper-migration-audit/handoff/*`

## Read-Only Evidence Sources

- `.planning/API-EXPORT-TRIAGE.md`
  (`<!-- BEGIN PUBLIC API TRIAGE -->`)
- `.planning/API-RUNTIME-DEPRECATION-DESIGN.md`
  (`## Source Candidate Set`)
- current loaded `Epsilon` export surface, filtered to the six deprecated
  validation-helper symbols

## Files Out Of Scope

- `src/Epsilon.jl`
- `src/model/types.jl`
- `src/mmm/calibration.jl`
- `Project.toml`
- model, inference, calibration, pipeline, plotting, optimisation, and
  transform implementation files
- API docs inventory rows unless the review identifies a concrete contradiction

## Constraints

- Do not remove or rename exports.
- Do not change deprecation warning text.
- Do not change validation semantics or error messages.
- Keep all six symbols as `deprecation-candidate`.
- Keep the audit conclusion as "not ready to unexport yet".
- Preserve the Phase 22 RFC as historical governance context while adding the
  current migration-audit layer.
- Use focused verification only unless scope expands into source/runtime/export
  changes.

## Acceptance Criteria

- A marked migration audit table exists for exactly the six deprecated
  validation helpers.
- `test/api_exports.jl` guards that table against the filtered deprecated-
  helper export subset, triage register, cleanup RFC, and runtime-deprecation
  design.
- The parser requires unique markers, exact columns, exactly six data rows, and
  no duplicate symbols.
- The guard requires warning status `landed`, replacement status `guarded`,
  unexport readiness `no`, exact migration text agreement, and non-empty
  evidence.
- Planning/changelog wording avoids stable-v1 or Abacus parity overclaiming.
- No runtime source files are changed.

## Verification Commands

```bash
make test-file FILE=test/api_exports.jl
julia --project=@runic -m Runic --check --diff test/api_exports.jl
git diff --name-only -- src/
git diff --check
```

Optional only if implementation touches behavioural warning tests:

```bash
make test-file FILE=test/model/types.jl
make test-file FILE=test/model/calibration.jl
```
