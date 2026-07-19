# Phase 54: Optimization Projection Tolerance Guard

Status: Implemented

## Objective

Document and lock the bounded optimizer's post-solve allocation projection
contract without changing optimizer mathematics.

The engineering review noted that `_project_to_constraint_bounds` is a sensible
Ipopt hygiene layer but under-documented: after solve, Epsilon snaps allocation
values that are within `1.0e-6` of effective bounds, then rebalances the fixed
total-budget equality through channels with available slack. The tolerance is
used for bound snapping and final remaining-residual acceptance; it is not a
cap on the amount that can be redistributed when valid slack exists. This is
not a second optimizer and not a semantic change to constraints; it is a
deterministic post-solve cleanup for numerical residuals.

Phase 53 migrated the JuMP nonlinear API. Phase 54 should make this projection
contract explicit and test the edge cases directly.

## Current Boundary

Already covered:

- `MMMData` and `PanelMMMData` docstrings state that channel arrays are stored
  in caller-supplied original units and downstream spend-like arguments must use
  those same units and aggregation levels.
- `optimize_budget` docstring states that `total_budget`, observed spend,
  bounds, and response-curve spend grids must use the same original input units.
- `test/optimization/objective.jl` already has one projection test proving
  total-budget equality after multiple bound snaps.

This phase adds:

- a small source comment/docstring around the projection tolerance;
- focused tests for both positive and negative residual rebalance paths;
- a focused test that impossible post-projection residuals fail explicitly; and
- changelog wording that documents the guard without claiming a solver or
  modelling change.

## File Allowlist

Implementation may touch only:

- `src/optimization/optimizer.jl`
- `test/optimization/objective.jl`
- `CHANGELOG.md`
- `.planning/phases/54-optimization-projection-tolerance-guard/PLAN.md`

The pre-existing untracked `.planning/CRITICAL-REVIEW-2026-07-19.md` remains
outside this phase and must not be staged.

Do not update `.planning/ROADMAP.md` or `.planning/STATE.md` in this
implementation commit; doing so would convert this narrow guard slice into a
phase-closing checkpoint with a full-suite expectation.

## Tasks

### Task 54-01: Document Projection Tolerance Contract

Acceptance criteria:

- [x] `src/optimization/optimizer.jl` explains why post-solve projection exists.
- [x] The tolerance value `1.0e-6` is documented as a bound-snap and final
      remaining-residual tolerance for solver artefacts.
- [x] Wording distinguishes bound snapping, bounded slack rebalance, and
      fail-closed final residual handling.
- [x] Wording states that projection rebalances only through available
      effective-bound slack and fails closed if it cannot preserve the
      fixed-budget equality inside tolerance.
- [x] No solver settings, objective construction, bounds, result schemas, or
      public APIs change.

Verification:

- [x] `make test-optimization`

### Task 54-02: Guard Rebalance And Failure Edges

Acceptance criteria:

- [x] Tests prove positive residuals are rebalanced only into channels with
      upper-bound slack.
- [x] Tests prove negative residuals are rebalanced only out of channels above
      effective lower bounds.
- [x] Tests prove impossible residuals throw the existing explicit
      `ErrorException` from `_project_to_constraint_bounds`.
- [x] Tests assert final sums, effective bounds, and that channels without
      relevant slack do not absorb the residual through `_project_to_constraint_bounds`
      rather than direct `_rebalance_projected_allocation!` calls.
- [x] Existing optimizer objective tests still pass.

Verification:

- [x] `make test-optimization`

### Task 54-03: Changelog And Hygiene

Acceptance criteria:

- [x] `CHANGELOG.md` records the projection-tolerance guard/documentation
      without claiming changed optimiser semantics.
- [x] `.planning/ROADMAP.md` and `.planning/STATE.md` remain untouched.
- [x] Parity ledger remains untouched.

Verification:

- [x] `make test-optimization`
- [x] `make format-check-touched`
- [x] `git diff --check`
- [x] `git diff --cached --check`
- [x] exact changed-file allowlist check

## Out Of Scope

- Changing the projection tolerance value.
- Changing solver settings, objective semantics, result metadata, or allocation
  projection logic.
- Changing JuMP/Ipopt dependencies or compat bounds.
- Benchmarking or performance claims.
- Full-suite, docs-build, release-gate, benchmark, pipeline, or parity-ledger
  changes.
- Roadmap/state closure docs.

## Verification Plan

Use scoped checks only:

```bash
make test-optimization
make format-check-touched
git diff --check
git diff --cached --check
```

No full suite is required because this slice does not update `.planning/STATE.md`
or `.planning/ROADMAP.md`, change exports, alter shared test imports, touch
dependencies/manifests, change model fitting, update pipeline stages, or modify
generated fixtures.

## Independent Review Questions

Before implementation, an independent review must check:

- whether the projection contract is described accurately;
- whether the proposed positive, negative, and impossible residual tests cover
  the meaningful edge cases without overfitting implementation details;
- whether `make test-optimization` is sufficient scoped verification; and
- whether the file allowlist is tight enough.

## Review Result Before Implementation

Independent review found one Must Fix in the draft plan: it incorrectly said
projection repairs only small residuals. The current implementation uses
`1.0e-6` for bound snapping and final remaining-residual tolerance, but it can
rebalance larger positive or negative residuals when effective-bound slack
exists. The plan was corrected before implementation. The reviewer approved the
test shape after that correction, provided the tests target
`_project_to_constraint_bounds` directly and assert final sums, effective
bounds, and no residual absorption by channels without relevant slack.

## Landing Notes

- Added a source comment inside `_project_to_constraint_bounds` documenting the
  projection as post-solve hygiene, with separate bound-snap, slack-rebalance,
  and fail-closed residual semantics.
- Added focused projection tests for positive residuals, negative residuals,
  and impossible residuals through `_project_to_constraint_bounds`.
- Recorded the guard in `CHANGELOG.md` without claiming changed optimiser
  semantics.
- Deliberately left `.planning/ROADMAP.md`, `.planning/STATE.md`, and
  `.planning/ABACUS-PARITY-LEDGER.md` untouched so this remains a narrow
  implementation slice rather than a phase-closing checkpoint.

Scoped verification:

```bash
make test-optimization
# Epsilon.jl: 252 passed / 252 total, 1m26.0s

make format-check-touched
git diff --check
# both passed with no output

git diff --cached --check
git diff --cached --name-only | sort
# staged allowlist matched the four approved Phase 54 files

git diff --cached | rg -i "password|secret|api_key|token"
# no matches
```
