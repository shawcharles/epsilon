# Phase 50: Trend And Holiday Prediction-State Lock

Status: Landed

## Objective

Add a focused integration regression lock for fitted time-series trend and
automatic-holiday prediction state.

The 2026-07-19 engineering review found that the former high-risk trend and
holiday state reconstruction bugs appear fixed at source level, but need
integration evidence. This phase proves that a fitted `TimeSeriesMMM` spec
carries the fitted trend origin/scale and holiday period basis into future
`predict(model, new_data)` and replay design construction, rather than
recomputing those date bases from the holdout data alone.

This is correctness evidence, not release preparation, benchmark work, broader
prediction redesign, or a new modelling surface.

## Finding Boundary

The review finding is specific:

- `src/mmm/trend.jl` now persists `trend.__epsilon_state.origin` and `scale` in
  fitted specs and `_trend_features` can replay future dates against that
  fitted basis.
- `src/mmm/holidays.jl` now persists `holidays.__epsilon_state.dates`,
  `period_days`, and `default_period_days` in fitted specs and
  `_holiday_design_matrix` can use the fitted default period for future dates.
- Existing low-level unit tests cover pieces of this behaviour, but the
  prediction path should be locked at the `fit!` / fitted-spec /
  `predict(model, new_data)` boundary.

## File Allowlist

Implementation may touch only:

- `test/model/builder.jl`
- `.planning/phases/50-trend-holiday-prediction-state-lock/PLAN.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`

If the new integration test exposes a source bug, stop and revise this plan
before editing source. Do not silently widen the allowlist.

The pre-existing untracked `.planning/CRITICAL-REVIEW-2026-07-19.md` remains
outside this phase and must not be staged.

## Tasks

### Task 50-01: Add Fitted Prediction-State Integration Test

Add one focused `test/model/builder.jl` testset that fits a small
`TimeSeriesMMM` with:

- `trend = Dict("type" => "linear")`
- automatic pooled holidays
- weekly fitted dates
- future weekly `new_data`

Acceptance criteria:

- [x] The fitted spec contains `trend.__epsilon_state` with the training origin
      and positive training scale.
- [x] Future trend features computed from the fitted spec continue beyond the
      training window and differ from recomputation against holdout dates alone.
- [x] The fitted spec contains `holidays.__epsilon_state.default_period_days`
      equal to the weekly training period.
- [x] Future holiday exposure from the fitted spec uses the weekly default
      period and differs from holdout-only recomputation for a one-row future
      holiday period.
- [x] After `fit!`, poisoning `model.config.trend` and `model.config.holidays`
      does not affect `predict(model, new_data)`, proving posterior prediction
      consumes the fitted artifact spec rather than the mutable live config.
- [x] `predict(model, new_data)` emits future target parameters.

Verification:

- [x] `make test-file FILE=test/model/builder.jl` (`313 / 313`, `3m49.4s`)

### Task 50-02: Planning Closure

Update roadmap and state once the focused model-builder lane passes.

Acceptance criteria:

- [x] `.planning/ROADMAP.md` records Phase 50.
- [x] `.planning/STATE.md` records the landed scope and exact scoped
      verification.
- [x] This plan is marked landed.
- [x] No parity-ledger status moves are made; this is a regression lock over
      already-landed Phase 13 behaviour.
- [x] The plan explicitly records that this is a scoped regression-lock
      checkpoint. It is not a release-prep, parity-ledger, or final pre-merge
      closure gate, so the full suite is intentionally not run for this small
      test/planning-only slice.

Verification:

- [x] `make format-check-touched`
- [x] `git diff --check`
- [x] `git diff --cached --check`
- [x] exact changed-file allowlist check

## Out Of Scope

- Changing trend, holiday, prediction, replay, postmodel, or pipeline source
  semantics unless the focused test exposes a real failure and the plan is
  explicitly revised first.
- Regenerating fixtures or changing reference exporter scripts.
- Panel prediction-state work.
- Stage `35` panel holdout validation.
- Benchmarks, release-prep, docs builds, smoke harness changes, and full-suite
  checks.
- Public API/export changes.
- Any new Abacus parity claim or parity-ledger status movement.

## Verification Plan

Use scoped checks only:

```bash
make test-file FILE=test/model/builder.jl
make format-check-touched
git diff --check
git diff --cached --check
```

No full suite is required. This phase adds one focused regression test inside
an existing model-builder lane and updates planning docs only. It does not
touch exports, shared test namespace imports, dependencies, manifests, docs
build inputs, source runtime semantics, or pipeline runtime.

This is an explicit scoped-checkpoint exception to the broader phase-closing
gate because the slice is test/planning-only and does not move a release,
parity, dependency, export, namespace, or runtime contract. A later release,
pre-merge, shared-namespace, source-semantics, or parity-ledger checkpoint still
requires the broader gate defined in `TECHNICAL-STANDARDS.md`.

## Independent Review Questions

Before implementation, an independent review must check:

- whether this phase should remain test/planning-only unless the test fails;
- whether `test/model/builder.jl` is the right integration boundary;
- whether the assertions prove fitted trend and holiday state are actually used
  for future prediction/replay;
- whether the file allowlist is tight enough;
- whether `CHANGELOG.md` and the parity ledger should stay out of scope; and
- whether the scoped verification plan is sufficient.

Review result before implementation:

- The reviewer approved `test/model/builder.jl` as the right integration
  boundary and agreed the phase should remain test/planning-only unless the new
  test exposes a source bug.
- The reviewer required one plan change before implementation: prediction
  success alone is too weak, so the implementation must poison the mutable live
  config after `fit!` and still require future prediction to succeed from the
  fitted artifact spec.
- The reviewer also required the verification contract to acknowledge the
  normal phase-closing gate. This phase therefore records a scoped
  test/planning-only checkpoint exception and does not claim release-prep,
  pre-merge, source-runtime, shared-namespace, dependency, parity-ledger, or
  final closure evidence.

## Landing Notes

Implemented as one focused integration testset in `test/model/builder.jl`.
The test fits a six-week weekly `TimeSeriesMMM` ending on 2024-01-22, predicts
the 2024-01-29 future holiday row, and verifies:

- fitted trend state uses the 2023-12-18 training origin and 35-day training
  scale, producing a future trend value of `1.2`;
- holdout-only trend recomputation would produce `0.0`;
- fitted holiday state uses the weekly default period, producing exposure
  `1 / 7`;
- holdout-only holiday recomputation would produce `1.0`; and
- posterior prediction still succeeds after mutating the live config to
  unsupported trend/holiday values, proving the path consumes the fitted
  artifact spec.
