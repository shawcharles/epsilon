# Phase 52: Saturation Media Domain Contract

Status: Landed

## Objective

Close the remaining media-domain ambiguity from the engineering review without
breaking fixture-backed transform behaviour.

The review correctly noted a tension: MMM media inputs and response grids are
business-spend surfaces and must be finite and nonnegative, but not every
low-level saturation primitive currently has the same mathematical domain.
`hill_function` already rejects negative `x`. `centered_logistic_saturation`
currently accepts negative `x` through its stable tanh implementation, and
`tanh_saturation` intentionally has signed reference fixtures. This phase makes
the contract explicit and locks it in tests.

## Contract Boundary

Preserve:

- `MMMData` and `PanelMMMData` reject negative channel values;
- public response, saturation, adstock, and metric curve grids reject negative
  spend values;
- `tanh_saturation` remains a signed mathematical primitive because committed
  reference fixtures include negative `x` cases;
- existing nonnegative fixture-backed saturation outputs remain unchanged; and
- shared public curve spend-grid validation stays in `src/postmodel/replay.jl`,
  while panel curve dispatch and `delta_grid` routing stays in
  `src/postmodel/response_curves.jl`.

Change:

- `centered_logistic_saturation` / `logistic_saturation` reject negative `x`
  with `ArgumentError`;
- `michaelis_menten` rejects negative `x` with `ArgumentError`;
- docstrings and release-facing docs distinguish low-level signed transform
  behaviour from MMM media/spend-domain behaviour.

Do not change:

- adstock, model fitting, posterior replay numerics for valid nonnegative media;
- fixture exporter scripts or generated fixtures;
- parity ledger status;
- HSGP, calibration, optimisation, pipeline stages, or release/benchmark gates.

## File Allowlist

Implementation may touch only:

- `src/transforms/saturation.jl`
- `test/transforms/saturation.jl`
- `test/model/types.jl`
- `test/postmodel/response_curves.jl`
- `docs/src/index.md`
- `docs/src/release.md`
- `CHANGELOG.md`
- `.planning/phases/52-saturation-media-domain-contract/PLAN.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`

The pre-existing untracked `.planning/CRITICAL-REVIEW-2026-07-19.md` remains
outside this phase and must not be staged.

## Tasks

### Task 52-01: Lock Saturation Primitive Domains

Acceptance criteria:

- [x] `centered_logistic_saturation` rejects scalar and array negative `x`.
- [x] `logistic_saturation` inherits the same rejection through the alias.
- [x] `michaelis_menten` rejects negative `x`.
- [x] `tanh_saturation` keeps signed-input behaviour and has an explicit test
      explaining the reference-backed contract.
- [x] Existing fixture parity tests for valid saturation inputs still pass.

Verification:

- [x] `make test-file FILE=test/transforms/saturation.jl` (`78 / 78`, `8.4s`)

### Task 52-02: Lock MMM Media And Curve Spend Domains

Acceptance criteria:

- [x] `MMMData` negative-channel rejection is asserted with the concrete error
      message.
- [x] `PanelMMMData` negative-channel rejection is asserted with the concrete
      error message.
- [x] Time-series curve APIs reject negative spend grids before replaying any
      saturation family for `response_curve_results`,
      `saturation_curve_results`, `adstock_curve_results`, and
      `metric_results`.
- [x] Panel `delta_grid` curve APIs reject negative values before replaying any
      saturation family for `response_curve_results`,
      `saturation_curve_results`, `adstock_curve_results`, and
      `metric_results`.

Verification:

- [x] `make test-file FILE=test/model/types.jl` (`72 / 72`, `13.6s`)
- [x] `make test-file FILE=test/postmodel/response_curves.jl` (`57 / 57`, `1m48.2s`)

### Task 52-03: Documentation And State Closure

Acceptance criteria:

- [x] Saturation docstrings state the primitive-domain split clearly.
- [x] Docs state that `centered_logistic_saturation`,
      `logistic_saturation`, `michaelis_menten`, and `hill_function` require
      nonnegative `x`, while `tanh_saturation` remains signed as a low-level
      primitive.
- [x] Release-facing docs no longer imply only `hill_function` owns negative
      input rejection.
- [x] Changelog records the pre-v1 domain hardening.
- [x] Roadmap and state record Phase 52 as a bounded contract lock.
- [x] Parity ledger is not changed.

Verification:

- [x] `make format-check-touched`
- [x] `git diff --check`
- [x] `git diff --cached --check`
- [x] exact changed-file allowlist check

## Out Of Scope

- Full-suite or docs-build gates.
- Benchmark or release evidence refresh.
- Changing generated reference fixtures.
- Removing signed `tanh_saturation` support.
- Changing model or postmodel numerics for valid nonnegative media/spend grids.
- Adding new public APIs.
- Changing calibration, HSGP, optimisation, or pipeline execution behaviour.

## Verification Plan

Use scoped checks only:

```bash
make test-file FILE=test/transforms/saturation.jl
make test-file FILE=test/model/types.jl
make test-file FILE=test/postmodel/response_curves.jl
make format-check-touched
git diff --check
git diff --cached --check
```

No full suite is required. This slice touches transform-domain validation,
focused tests, docs, changelog, and planning state only. It does not touch
exports, shared test imports, dependencies, manifests, samplers, model graph
construction, generated fixtures, or parity-ledger status.

## Independent Review Questions

Before implementation, an independent review must check:

- whether rejecting negative centred-logistic and Michaelis-Menten `x` is a
  coherent pre-v1 behaviour change;
- whether signed `tanh_saturation` should be preserved because the current
  reference fixtures require it;
- whether the media-domain tests cover the actual public MMM paths;
- whether documentation sufficiently separates mathematical transform
  primitives from media/spend surfaces; and
- whether the file allowlist and scoped verification are tight enough.

## Review Result Before Implementation

Independent review approved the behavioural direction with no Must Fix items.
The reviewer required the implementation to make the response-curve test
coverage explicit for all four public curve entry points on both time-series
`grid` and panel `delta_grid`, to assert the concrete negative-channel
constructor error message for both `MMMData` and `PanelMMMData`, and to make
the docs spell out the domain split: centred logistic, logistic alias,
Michaelis-Menten, and Hill require nonnegative `x`; tanh remains signed as a
low-level reference-backed primitive.

## Landing Notes

Implemented as a bounded pre-v1 contract lock:

- `centered_logistic_saturation` and the compatibility
  `logistic_saturation` alias now reject negative `x`;
- `michaelis_menten` now rejects negative `x`;
- `tanh_saturation` remains signed because committed fixtures explicitly cover
  negative inputs;
- `MMMData`, `PanelMMMData`, and all four public curve/metric entry points now
  have focused nonnegative-domain assertions; and
- `test/postmodel/response_curves.jl` is now self-contained under
  `make test-file FILE=test/postmodel/response_curves.jl` by defining its
  tiny feature-matrix helper locally when the full model layer has not already
  loaded it.
