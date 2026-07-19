# Phase 53: JuMP Nonlinear Operator Migration

Status: Implemented

## Objective

Remove the remaining legacy JuMP nonlinear API usage from the bounded budget
optimizer without changing optimisation semantics.

The engineering review identified `JuMP.register` and
`JuMP.set_nonlinear_objective` in `src/optimization/optimizer.jl` as a
medium-risk dependency-upgrade issue. Epsilon currently pins JuMP `1.30.0` and
Ipopt `1.14.1`; the installed JuMP manual documents the replacement
user-defined operator API as `@operator` / `add_nonlinear_operator`, and the
standard nonlinear objective surface as `@objective(model, Max, expression)`.

This phase is an internal optimisation implementation migration only. It must
not redesign allocation semantics, constraints, interpolation, solver
tolerances, panel historical-share behaviour, result schemas, or public API.

## Current Source Boundary

Current legacy points:

- `_register_channel_operator!` calls
  `JuMP.register(model, operator_name, 1, evaluate, gradient, hessian)`.
- `_objective_expression` builds a raw `Expr` tree from operator symbols and
  allocation variables.
- `_build_optimizer_model` calls
  `JuMP.set_nonlinear_objective(model, JuMP.MAX_SENSE, expr)`.

Replacement contract:

- `_register_channel_operator!` should return JuMP nonlinear operator objects
  created with `JuMP.add_nonlinear_operator(model, 1, evaluate, gradient,
  hessian; name = operator_name)` or an equivalent current JuMP API.
- `_objective_expression` should build a JuMP nonlinear expression from those
  callable operator objects and allocation variables, not a raw `Expr`.
- `_build_optimizer_model` should set the objective with
  `JuMP.@objective(model, Max, expression)`.
- The analytic interpolation derivative and second-derivative functions must
  remain supplied to JuMP.

## File Allowlist

Implementation may touch only:

- `src/optimization/optimizer.jl`
- `test/optimization/optimizer.jl`
- `CHANGELOG.md`
- `.planning/phases/53-jump-nonlinear-operator-migration/PLAN.md`

The pre-existing untracked `.planning/CRITICAL-REVIEW-2026-07-19.md` remains
outside this phase and must not be staged.

## Tasks

### Task 53-01: Migrate Optimizer Nonlinear Construction

Acceptance criteria:

- [x] `src/optimization/optimizer.jl` no longer calls `JuMP.register`.
- [x] `src/optimization/optimizer.jl` no longer calls
      `JuMP.set_nonlinear_objective`.
- [x] `_register_channel_operator!` preserves one univariate operator per
      optimised channel and still supplies analytic first and second
      derivatives.
- [x] `_objective_expression` no longer constructs raw `Expr` objects.
- [x] `_build_optimizer_model` still returns `(model, allocation)` and keeps
      the same bounds, start values, total-budget equality, Ipopt silent
      settings, and local-feasible solve handling.

Verification:

- [x] `make test-optimization` (`238 / 238`, `1m26.0s`)
- [x] `! rg "JuMP\\.(register|set_nonlinear_objective)" src/optimization/optimizer.jl`

### Task 53-02: Behaviour Lock And Hygiene

Acceptance criteria:

- [x] Existing time-series allocation tests continue to pass.
- [x] Existing unselected-channel and bounded-channel tests continue to pass.
- [x] Existing conversion-target efficiency test continues to pass.
- [x] Existing unsupported-input tests continue to pass.
- [x] Existing panel historical-share optimisation tests continue to pass.
- [x] Changelog records the internal JuMP API migration without claiming solver
      or modelling changes.
- [x] `.planning/ROADMAP.md` and `.planning/STATE.md` are not updated in this
      implementation commit, avoiding the phase-closing full-suite gate for a
      narrow internal optimizer migration.

Verification:

- [x] `make test-optimization` (`238 / 238`, `1m26.0s`)
- [x] `! rg "JuMP\\.(register|set_nonlinear_objective)" src/optimization/optimizer.jl`
- [x] `make format-check-touched`
- [x] `git diff --check`
- [x] `git diff --cached --check`
- [x] exact changed-file allowlist check

## Out Of Scope

- Changing objective semantics, interpolation surfaces, or response-curve grid
  construction.
- Changing `_project_to_constraint_bounds`, solver tolerances, local optimum
  caveats, or result metadata.
- Changing JuMP/Ipopt compat bounds or dependency versions.
- Changing panel historical-share semantics or adding free panel allocation.
- Benchmarking or performance claims.
- Full-suite, docs-build, release-gate, benchmark, pipeline, or parity-ledger
  changes.

## Verification Plan

Use scoped checks only:

```bash
make test-optimization
! rg "JuMP\\.(register|set_nonlinear_objective)" src/optimization/optimizer.jl
make format-check-touched
git diff --check
git diff --cached --check
```

No full suite is required. This slice touches only the optimisation nonlinear
model-construction internals, the optimisation test lane if a focused lock is
needed, changelog, and this phase plan. It deliberately does not update
`.planning/ROADMAP.md` or `.planning/STATE.md`; that avoids turning this narrow
internal migration into a phase-closing checkpoint requiring the expensive
full-suite gate. It does not touch exports, shared test imports, dependencies,
manifests, model fitting, postmodel surfaces, pipeline stages, generated
fixtures, docs build inputs, benchmarks, or parity-ledger status.

## Independent Review Questions

Before implementation, an independent review must check:

- whether `add_nonlinear_operator` or `@operator` is the right replacement for
  the current dynamic per-channel operator names;
- whether `_objective_expression` can safely return a JuMP nonlinear expression
  rather than a raw `Expr`;
- whether using `JuMP.@objective(model, Max, expression)` preserves the current
  maximisation sense;
- whether `make test-optimization` is the right scoped verification lane; and
- whether the file allowlist is tight enough.

## Review Result Before Implementation

Independent review approved the core migration direction with no Must Fix
items. The reviewer recommended `JuMP.add_nonlinear_operator` rather than
`@operator` because Epsilon creates one dynamic operator name per optimised
channel. The reviewer also required an explicit grep verification proving that
`JuMP.register` and `JuMP.set_nonlinear_objective` were removed. To respect the
project's scoped-test preference and avoid a phase-closing full-suite gate for
this narrow internal migration, the implementation allowlist was tightened to
exclude `.planning/ROADMAP.md` and `.planning/STATE.md`.

## Landing Notes

Implemented as a narrow internal optimizer migration:

- `_register_channel_operator!` now creates dynamic univariate JuMP nonlinear
  operator objects with `JuMP.add_nonlinear_operator`;
- analytic interpolation value, first-derivative, and second-derivative
  callbacks are still supplied and explicitly return `Float64`;
- `_objective_expression` now composes callable JuMP operator objects with the
  allocation variables instead of constructing raw `Expr` calls;
- `_build_optimizer_model` now sets the maximisation objective via
  `JuMP.@objective(model, Max, objective)`; and
- `.planning/ROADMAP.md` and `.planning/STATE.md` were intentionally left
  unchanged so this implementation commit remains scoped and does not require a
  phase-closing full-suite gate.
