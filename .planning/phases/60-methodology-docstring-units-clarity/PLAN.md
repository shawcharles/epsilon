# Phase 60: Methodology Docstring Units Clarity

Status: Implemented

## Objective

Close the small documentation gaps left by the recent critical review without
changing ROADMAP, STATE, parity ledger, exports, fixtures, or runtime
behaviour.

The target is narrow:

- make the `binomial_adstock` public docstring state the exact lag-weight
  formula implemented by Epsilon; and
- clarify original-unit spend/budget/allocation semantics on the public
  optimisation and scenario-planner surfaces that expose those values.

## Current Boundary

`MMMData`, `PanelMMMData`, and `optimize_budget` already document that channel
arrays, observed spend, `total_budget`, bounds, and spend grids must use the
same original input units and time aggregation level.

The remaining weak spots are:

- `binomial_adstock` says only "Apply binomial adstock" and does not expose the
  implemented kernel formula;
- optimisation result/problem structs expose `current_spend`,
  `optimized_spend`, `fixed_spend`, and `constraint_audit` fields without
  restating the unit contract; and
- scenario-planner allocation specs/results expose manual/fixed-budget spend
  values without restating that they must be in the same original channel units
  as the fitted model and response surfaces.

## Scope

In scope:

- Update docstrings in `src/transforms/adstock.jl` for `binomial_adstock`.
- Update docstrings in `src/optimization/types.jl` for budget optimisation
  problem/result structs where spend fields are exposed.
- Update docstrings in `src/scenario_planner.jl` for manual allocation,
  fixed-budget scenario, manual evaluation result, data-array spec, and
  scenario-plan table surfaces.
- Add a short `CHANGELOG.md` note under `Unreleased` documenting this
  clarification.

Out of scope:

- Changing any adstock formula, optimisation behaviour, scenario evaluation
  behaviour, fixtures, tests, exports, docs inventory, ROADMAP, STATE, or
  parity ledger.
- Adding formula citations that claim external literature provenance beyond
  the implemented Epsilon/reference-fixture formula.
- Scrubbing historical `Abacus` references from the repo; that is a future
  deliberate cleanup, not this phase.
- Running the full test suite.

## File Allowlist

Implementation may touch only:

- `src/transforms/adstock.jl`
- `src/optimization/types.jl`
- `src/scenario_planner.jl`
- `CHANGELOG.md`
- `.planning/phases/60-methodology-docstring-units-clarity/PLAN.md`

The pre-existing untracked `.planning/CRITICAL-REVIEW-2026-07-19.md` remains
outside this phase and must not be staged.

## Tasks

### Task 60-01: Plan Review

Acceptance criteria:

- [x] Independent reviewer confirms the phase is documentation-only.
- [x] Reviewer confirms the file allowlist is tight.
- [x] Reviewer confirms no broader Abacus-reference scrub belongs in this
      slice.

Verification:

- [x] Review result is recorded in this plan before implementation.

### Task 60-02: Binomial Formula Docstring

Acceptance criteria:

- [x] `binomial_adstock` docstring states the implemented lag-weight formula
      `w_l = (1 - l / (l_max + 1))^(1 / alpha - 1)` for zero-based lag
      `l = 0, ..., l_max - 1`.
- [x] The docstring states that `alpha` must satisfy `0 < alpha <= 1`.
- [x] The docstring states that optional `normalize=true` rescales the lag
      weights after formula construction.
- [x] No implementation code changes.

Verification:

- [x] `test/transforms/adstock.jl` remains passing.

### Task 60-03: Spend/Budget Unit Docstrings

Acceptance criteria:

- [x] Budget optimisation typed surfaces clarify that spend, budget, bounds,
      and spend grids are in the same original channel units and aggregation
      level as the fitted input data.
- [x] Scenario allocation specs/results clarify that manual allocations and
      fixed budgets use those same original channel units.
- [x] `ScenarioDataArraySpec` and `ScenarioPlanResult` docstrings clarify the
      same original-unit contract for allocation/table spend values.
- [x] Changelog records the documentation clarification without implying a
      behaviour change.

Verification:

- [x] `make format-check-touched` passes.
- [x] `git diff --check` passes.

## Verification

Use scoped checks only:

```bash
JULIA_PKG_SERVER_REGISTRY_PREFERENCE=eager make test-file FILE=test/transforms/adstock.jl
make docs
make format-check-touched
git diff --check
git diff --name-only | sort
git diff --cached --check
git diff --cached --name-only | sort
git status --short --branch
```

No full suite is required because this phase edits docstrings and changelog
text only. It does not alter runtime code, exports, tests, dependencies,
fixtures, generated docs, or shared test imports. `make docs` is included
because these docstrings are rendered into the authored documentation.

## Independent Review Questions

Before implementation, an independent reviewer must check:

- whether the binomial formula wording accurately matches
  `_binomial_adstock_weights`;
- whether unit clarification belongs on the optimisation and scenario
  docstrings rather than additional runtime validation;
- whether any authored docs page is necessary in this slice;
- whether the changelog note is appropriate for a doc-only clarification; and
- whether the file allowlist is tight enough.

## Independent Review Result

The independent reviewer approved the plan as a documentation-only slice with
the following tightening:

- The planned binomial formula matches `_binomial_adstock_weights`; the
  docstring should also state the existing `0 < alpha <= 1` validation range.
- Spend/budget/allocation unit semantics belong in docstrings because currency,
  aggregation, and thousands/millions scaling are semantic contracts that
  runtime validation cannot infer.
- `ScenarioDataArraySpec` and `ScenarioPlanResult` should be included because
  they expose allocation and scenario spend table values.
- Authored docs pages (`README.md`, `docs/src/index.md`, `docs/src/release.md`,
  and `docs/src/api.md`) should remain out of scope; the public symbols are
  already rendered from docstrings through existing `@docs` blocks.
- The changelog note belongs under `Unreleased / Changed` and must avoid
  implying runtime behaviour changed.
- Add `make docs` and an unstaged `git diff --name-only | sort` allowlist check
  to verification.
- Keep non-allowlisted local files unstaged, including the pre-existing
  untracked `.planning/CRITICAL-REVIEW-2026-07-19.md` and any other local drift
  if present.

## Landing Notes

- Updated `binomial_adstock`'s public docstring with the implemented zero-based
  lag-weight formula, the existing `0 < alpha <= 1` range, and the
  post-construction `normalize=true` semantics.
- Clarified original-unit spend/budget/bounds/grid semantics on budget
  optimisation constraint, problem, surface, and result docstrings.
- Clarified original-unit allocation and scenario table semantics on
  `ScenarioDataArraySpec`, `ManualAllocationScenarioSpec`,
  `ManualScenarioEvaluationResult`, `FixedBudgetOptimizedScenarioSpec`, and
  `ScenarioPlanResult`.
- Added a short `CHANGELOG.md` note under `Unreleased / Changed` stating that
  these are docstring clarifications with no runtime behaviour change.
- Left runtime code, exports, fixtures, authored docs pages, ROADMAP, STATE,
  and parity ledger untouched.
- Left non-phase local drift unstaged: `.gitignore` currently adds
  `graphify-out/`, and `.planning/CRITICAL-REVIEW-2026-07-19.md` remains
  untracked.

Scoped verification:

```bash
JULIA_PKG_SERVER_REGISTRY_PREFERENCE=eager make test-file FILE=test/transforms/adstock.jl
# Epsilon.jl: 101 passed / 101 total, 17.5s

make docs
# completed successfully; Documenter warned that index.html is near the size
# threshold and skipped deployment because no build environment was detected

make format-check-touched
git diff --check
# both passed with no output

git diff --name-only | sort
# .gitignore
# CHANGELOG.md
# src/optimization/types.jl
# src/scenario_planner.jl
# src/transforms/adstock.jl
```
