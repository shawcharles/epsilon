# Phase 13 Plan - Prediction-State and Contract Remediation

**Status:** Completed
**Created:** 2026-04-24
**Last Reconciled:** 2026-04-24
**Source Review:** `.planning/reviews/code-review-v4.md`

## Objective

Close the concrete risks found in the Phase 12 external code review before
release preparation resumes. This phase is a remediation pass, not a feature
expansion: preserve the bounded v1 surface, repair prediction/replay state
contracts, tighten invalid-input behavior, and make the pipeline config
contract reject misleading YAML.

## Entry Conditions

- Phase 12 is complete.
- Release branch/tag work is paused.
- `code-review-v4.md` findings are accepted as the remediation scope.
- Abacus remains the reference where semantics match, but native coherent
  Epsilon behavior remains acceptable where semantics intentionally differ.

## Frozen Scope

- Trend prediction/replay must use fitted trend normalization and basis state,
  not state recomputed from `new_data`.
- Holiday prediction/replay must use fitted calendar-period exposure state, not
  state recomputed from arbitrary holdout slices.
- Media inputs must have one documented nonnegative-domain contract across
  constructors, transforms, prediction, and pipeline validation.
- Pipeline YAML must reject unknown top-level run keys that currently look like
  valid configuration but are silently ignored.
- Panel post-model semantics and `nobs` interpretation remain a residual risk
  unless one of the above fixes touches them directly.

## Non-Goals

- No Plotly Dash parity.
- No HSGP implementation.
- No widened panel post-modeling contract.
- No new inference backend or sampler surface.
- No broad redesign of `InferenceResults` beyond the state required to make
  prediction and deterministic replay coherent.

## Phase Contract

Fitted feature state must be explicit and replayable. The final design can add
typed fields, typed resolved-state wrappers, or reserved metadata keys, but it
must satisfy these constraints:

- `fit!`, `predict`, `prior_predict`, grouped `InferenceResults`,
  flat `ModelResults`, deterministic post-model replay, `save_model`,
  `load_model`, `save_results`, `load_results`, and pipeline validation must
  agree on the same fitted trend and holiday state.
- Direct config parsing must remain human-readable, but prediction-time state
  must not depend on the incidental date span of `new_data`.
- Serialization must preserve enough state for a loaded model or loaded
  results artifact to reproduce the same replay basis.
- Abacus-compatible semantics should be used for trend state where they match;
  the automatic pooled-holiday design remains Epsilon-native unless a separate
  compatibility mode is added.
- Unfitted `prior_predict(model, new_data)` must use state resolved from
  `model.data`, not from `new_data`, when date-derived feature state is needed;
  if no fitted/model-data state can be resolved, it must fail with a clear
  `ArgumentError`.
- Full predictive values may still vary with media adstock carryover when
  `new_data` changes. Phase 13 invariance claims apply specifically to
  trend/holiday design matrices, or to end-to-end predictive tests with adstock
  disabled.

## Required State Details

Trend state must be serialized explicitly rather than implied by dates. The
Phase 13 implementation should introduce a typed state or equivalently stable
serialized representation with at least:

- fitted origin value (`Date`, `DateTime`, or numeric) and origin kind;
- position unit (`Dates.value(date - origin)` for time-like dates, raw numeric
  delta for numeric dates);
- positive normalization denominator from the fitted span, with the
  one-observation fitted case recorded and handled deterministically;
- normalized changepoint locations for changepoint trends;
- trend term names and feature column order.

Holiday state must be serialized explicitly enough to make one-row and short
holdouts deterministic. The Phase 13 implementation should introduce a typed
state or equivalently stable serialized representation with at least:

- resolved holiday dates/countries used by the fitted model;
- fitted default observation-period length in days from the training dates;
- fitted per-row period lengths for in-sample replay, if replaying the training
  design needs exact row-level intervals;
- prediction policy for future rows: use the fitted default observation period
  rather than inferring a period from the holdout slice length.

Pipeline YAML must have a top-level allowlist. For pipeline runs, accepted
top-level keys are `data`, `target`, `media`, `dimensions`, `seasonality`,
`trend`, `events`, `holidays`, `controls`, `priors`, `fit`, `validation`, and
`optimization`. Intentional future/opaque values must live under a documented
`extras` key only if Phase 13 explicitly adds that key; otherwise unknown
top-level keys must fail. YAML must accept `optimization`; stage directory names
may continue to use the existing `optimisation` spelling.

## Plans

- [x] **13-01: Freeze fitted feature-state contract.**
  Define where resolved trend and holiday state live, how it is serialized,
  how grouped results expose it, and which public APIs must consume it.
  Files likely touched: `src/model/builder.jl`, `src/model/types.jl`,
  `src/model/io.jl`, `src/model/results.jl`, `src/mmm/model.jl`,
  `src/mmm/trend.jl`, `src/mmm/holidays.jl`, `src/inference/results.jl`,
  docs support-matrix pages, and focused tests.
  Acceptance: a maintainer-facing contract exists in code/docs, old artifacts
  either load with an explicit compatibility path or fail with a clear
  schema/version error when they are deserializable, and follow-on
  implementation plans have no unresolved state-location ambiguity.
  `Serialization` payloads that fail before schema inspection must be
  documented as unsupported pre-Phase-13 artifacts rather than silently
  accepted.

- [x] **13-02: Implement trend-state prediction/replay remediation.**
  Persist fitted trend anchor/scale/basis metadata and make prediction,
  posterior/prior predictive paths, grouped inference export, deterministic
  replay, and validation holdouts consume that fitted state.
  Tests must include short holdout and one-row `new_data` cases whose trend
  basis differs from a recomputed holdout-only basis.
  Acceptance: trend design matrices used by prediction and replay are invariant
  to holdout slice length except for the rows being predicted, and saved/loaded
  artifacts preserve the same behavior. End-to-end predictive tests should
  disable adstock or assert the trend component/design directly so media
  carryover does not mask the contract being tested.

- [x] **13-03: Implement holiday exposure-state prediction/replay remediation.**
  Persist the fitted holiday period/exposure state needed by the pooled
  automatic-holiday component and make validation and replay use that state for
  holdouts.
  Tests must include one-row and short holdouts crossing the existing failure
  mode, plus save/load coverage for holiday-bearing artifacts.
  Acceptance: holiday exposure in prediction/replay is derived from fitted
  calendar state, not from the date span of `new_data`; one-row future holdouts
  use the fitted default observation period.

- [x] **13-04: Harden the media input contract.**
  Decide and enforce the nonnegative media-domain rule consistently for
  `MMMData`, `PanelMMMData`, direct `predict`, the model media path, standalone
  `hill_function`, and pipeline preflight.
  Tests must cover negative media values at construction, config/pipeline
  validation, direct API prediction, and transform-level failure surfaces.
  Acceptance: users get deterministic validation errors before domain errors or
  silent invalid model inputs can occur. The v1 contract is no signed media:
  media/channel arrays must be finite and nonnegative; `hill_function` must
  reject negative `x` with an `ArgumentError` before Julia can raise a raw
  fractional-power `DomainError`.

- [x] **13-05: Tighten pipeline YAML contract.**
  Reject unknown top-level pipeline keys that are not in the Phase 13 allowlist.
  Tests must cover misspelled stage/config keys and still allow documented
  model-level extras only if Phase 13 introduces an explicit `extras` key.
  Acceptance: a typo in a pipeline run key cannot silently disable or bypass an
  intended stage or option; `validaton` and `optimisation` in YAML fail with a
  clear message, while `optimization` remains the only accepted optimization
  config key.

- [x] **13-06: Revalidate docs and release gate.**
  Re-run focused regression suites plus the full release-quality checks,
  reconcile docs/readiness language, and update review notes with the final
  disposition of each finding.
  Acceptance: `make test`, `make docs`, and `make format-check` pass locally;
  docs no longer describe pre-remediation prediction-state behavior; release
  prep is either unblocked or a new blocker is recorded explicitly.

## Verification

- Focused tests for fitted trend-state reuse.
- Focused tests for fitted holiday exposure reuse.
- Focused tests for negative media rejection across direct and pipeline paths.
- Focused tests for unknown pipeline YAML top-level keys.
- Serialization round trips for any new fitted-state fields.
- Schema-version or simulated stale-payload tests for model/results artifacts.
- Explicit unfitted `prior_predict(model, new_data)` state-resolution tests.
- Final gate: `make test`, `make docs`, `make format-check`.

## Exit Criteria

- All four actionable code-review findings are fixed or explicitly reclassified
  with evidence.
- The implementation and docs agree on prediction/replay state behavior.
- Pipeline config errors are deterministic for unsupported top-level keys.
- Release prep can resume with Phase 13 recorded in `STATE.md`, `ROADMAP.md`,
  and the review disposition notes.
