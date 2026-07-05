# Architect Brief: Phase 23 Runtime Deprecation Design

## Goal

Review and then implement a design-only phase for future runtime deprecation of
the six Phase 22 public validation-helper candidates. Phase 23 must not change
runtime behaviour, exports, tests, user-facing docs, or Abacus parity claims.

## Candidate Set

The candidate set is fixed by `.planning/API-EXPORT-CLEANUP-RFC.md`:

- `validate_calibration_step_config`
- `validate_cost_per_target_calibration_payload`
- `validate_lift_test_calibration_payload`
- `validate_mmm_data`
- `validate_model_config`
- `validate_sampler_config`

## Key Risk

All six validators are currently called internally by constructors or payload
builders. Adding warnings directly to the existing methods would warn during
normal supported workflows. The future implementation therefore needs public
warning wrappers plus warning-free internal validation helpers before any
runtime warning is introduced.

## Phase Boundary

In scope:

- `.planning/API-RUNTIME-DEPRECATION-DESIGN.md`
- `.planning/phases/23-runtime-deprecation-design/PLAN.md`
- conservative updates to `.planning/ROADMAP.md`, `.planning/STATE.md`, and
  `CHANGELOG.md`
- ignored handoff files

Out of scope:

- `src/`
- `test/`
- `docs/src`
- runtime warnings
- export removal
- parity ledger movement unless review identifies a consistency defect

## Verification

For this design-only phase, use:

```bash
git diff --check
```

Do not run the full suite unless executable package files are unexpectedly
changed. A later implementation phase should run targeted API/export tests and
affected model/config tests.
