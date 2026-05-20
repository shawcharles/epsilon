# Phase 7 Plan — Post-Modeling

**Phase:** 7
**Phase Name:** Post-Modeling
**Status:** Complete
**Last Reconciled:** 2026-04-22

## Objective

Turn the frozen Phase 6 inference artifacts into the analyst-facing outputs that
make a fitted MMM useful after sampling, without reopening inference or model
scope.

Phase 7 is where Epsilon starts producing downstream business outputs from the
canonical grouped artifact contract:

- contributions over time
- decomposition and attribution shares
- response curves
- business metrics such as ROAS and CPA
- summary tables for analyst consumption

The key constraints are:

- Phase 7 must consume the Phase 6 `InferenceResults` contract directly rather
  than inventing a second posterior or results format.
- Phase 7 must settle the deterministic replay contract up front instead of
  leaving contribution and response-term recovery to implementation-time design.

## Entry Conditions

Phase 6 is closed and the following are already in place:

- truthful MCMC support for the frozen Phase 5 `TimeSeriesMMM` and bounded
  `PanelMMM` surfaces
- canonical grouped `InferenceResults`
- bounded explicit VI through `approximate_fit!` and `VariationalConfig`
- frozen inference support matrix across model type, backend, predictive
  surface, grouped export, and diagnostics availability
- typed `MMMData`, `PanelMMMData`, `MMMModelSpec`, coordinate metadata, and fit
  metadata
- save/load for grouped inference artifacts

Phase 7 must build on those contracts instead of redefining them.

## Current Base To Extend

The current analyst-facing base is still intentionally bounded:

- canonical grouped artifact:
  - `InferenceResults`
- current supported inference rows:
  - `TimeSeriesMMM` + Turing MCMC
  - `PanelMMM` + Turing MCMC
  - `TimeSeriesMMM` + bounded VI
- `07-01`, `07-02`, and `07-03` landed:
  - `src/postmodel/`
  - `ContributionResults`
  - `DecompositionResults`
  - `ResponseCurveResults`
  - `MetricResults`
  - `contribution_results(results::InferenceResults)`
  - `decomposition_results(results::InferenceResults)`
  - `response_curve_results(results::InferenceResults; channel, grid)`
  - `metric_results(results::InferenceResults; channel, grid)`
  - `summary_table(result)`
- the Phase 7 support matrix is now explicit and frozen

Phase 7 must add one coherent post-model layer on top of that base.

## Deterministic Replay Contract

Phase 7 resolves the post-model deterministic contract explicitly:

- `InferenceResults` remains the canonical input artifact.
- Phase 7 does **not** widen `InferenceResults` with new deterministic groups.
- Phase 7 does **not** depend on `generated_quantities()` as the public contract
  for contributions or response outputs.
- Phase 7 computes deterministic post-model quantities by replaying the frozen
  Phase 5 time-series transform and additive-term logic from:
  - `InferenceResults.posterior`
  - `InferenceResults.observed_data`
  - `InferenceResults.spec`
  - `InferenceResults.coordinate_metadata`
- `posterior_predictive`, `prior`, `prior_predictive`, and sample-stat groups
  are not required inputs for the canonical Phase 7 outputs.
- Any `InferenceResults` object missing `posterior`, `observed_data`, or `spec`
  must fail explicitly on Phase 7 entry points.

This contract makes Phase 7 execution-safe without reopening the frozen Phase 6
artifact surface.

## Phase 7 Output Contract

Phase 7 fixes the following contracts up front:

- `InferenceResults` is the canonical input surface for post-modeling.
- Phase 7 must not create a second canonical artifact contract based on raw
  `Chains`, ad hoc `NamedTuple`s, or backend-specific inference objects.
- New ownership belongs under:
  - `src/postmodel/`
  - `test/postmodel/`
- Phase 7 should expose typed post-model output surfaces before adding summary
  tables or exported views.
- DataFrames are required in Phase 7 only for analyst-ready summary-table
  projections; the canonical typed APIs must not depend on DataFrames for their
  primary return types.

The bounded typed output families for Phase 7 are:

- contribution results
- decomposition results
- response-curve results
- marketing-metric results
- summary-table projections of those typed results

The canonical public entry points are:

- `contribution_results(results::InferenceResults)`
- `decomposition_results(results::InferenceResults)`
- `response_curve_results(results::InferenceResults; channel, grid)`
- `metric_results(results::InferenceResults; channel, grid)`
- `summary_table(result)`

The canonical typed result surfaces are:

- `ContributionResults`
- `DecompositionResults`
- `ResponseCurveResults`
- `MetricResults`

Phase 7 summary-table projections are additive views over those typed results,
not separate canonical stores.

Typed result surfaces must preserve draw-level values as the canonical contract.
`summary_table(result)` must return a `DataFrame` projection with:

- posterior mean columns by default
- equal-tailed `lower_5` / `upper_95` interval columns by default

The default Phase 7 summary-table schemas are:

- contributions:
  - `observation`
  - `date` when the grouped artifact carries date-like observation coordinates
  - `component`
  - `mean`
  - `lower_5`
  - `upper_95`
- decomposition:
  - `component`
  - `total_mean`
  - `total_lower_5`
  - `total_upper_95`
  - `share_mean`
  - `share_lower_5`
  - `share_upper_95`
- response curves:
  - `channel`
  - `spend`
  - `mean`
  - `lower_5`
  - `upper_95`
- metrics:
  - `channel`
  - `spend`
  - `metric`
  - `mean`
  - `lower_5`
  - `upper_95`

Phase 7 also settles these support boundaries:

- Time-series post-modeling is the Phase 7 baseline.
- `TimeSeriesMMM` grouped artifacts from both supported MCMC and supported VI
  rows are in scope for all canonical Phase 7 outputs because those outputs
  depend only on `posterior`, `observed_data`, `spec`, and coordinate metadata.
- Panel post-modeling is explicitly deferred from Phase 7. The bounded panel MMM
  fit path remains supported for inference, but Phase 7 will not invent panel
  decomposition, panel response, or panel metric semantics prematurely.
- Phase 7 outputs remain in the observed target units already present in
  `InferenceResults`. The current supported model path does not introduce a
  separate target-scaling contract, so Phase 7 must not invent an artificial
  inverse-scaling layer.

## Starting Support Matrix

Phase 7 starts from the following explicit baseline:

| Surface | `TimeSeriesMMM` + MCMC | `TimeSeriesMMM` + VI | `PanelMMM` + MCMC | Notes |
|---|---|---|---|---|
| grouped `InferenceResults` | Supported | Supported | Supported | Phase 6 baseline |
| flat `ModelResults` | Supported | Unsupported | Supported | Flat surface is not the Phase 7 contract |
| post-model outputs | Not Yet Supported | Not Yet Supported | Not Yet Supported | Phase 7 scope |

Phase 7 closes with the following intended support matrix:

| Surface | `TimeSeriesMMM` + MCMC | `TimeSeriesMMM` + VI | `PanelMMM` + MCMC | Notes |
|---|---|---|---|---|
| contributions / shares | Supported | Supported | Unsupported | Time-series first |
| decomposition | Supported | Supported | Unsupported | Built from the same additive contribution contract |
| response curves | Supported | Supported | Unsupported | Supported media channels only |
| marketing metrics | Supported | Supported | Unsupported | Derived from the same response surface |
| summary tables | Supported | Supported | Unsupported | DataFrame projections of typed outputs |

Panel post-modeling stays explicitly unsupported unless a later phase reopens it
truthfully.

## Required `InferenceResults` Fields By Output

| Output | Required `InferenceResults` fields | MCMC-only dependency | VI support |
|---|---|---|---|
| contributions / shares | `posterior`, `observed_data`, `spec`, `coordinate_metadata` | No | Supported |
| decomposition | `posterior`, `observed_data`, `spec`, `coordinate_metadata` | No | Supported |
| response curves | `posterior`, `observed_data`, `spec`, `coordinate_metadata` | No | Supported |
| marketing metrics | same fields as response curves, or a canonical `ResponseCurveResults` object | No | Supported |
| summary tables | the corresponding typed Phase 7 result object | No | Supported |

Outputs must fail explicitly on grouped artifacts that do not satisfy those
field requirements.

## In Scope

- `src/postmodel/` and `test/postmodel/` as the canonical ownership layer for
  analyst outputs
- deterministic replay helpers for time-series additive terms and media-response
  terms on top of the frozen Phase 5 contract
- channel/media contributions over time on the supported time-series surface
- additive decomposition consistent with the frozen Phase 5 feature matrix:
  - intercept
  - media contributions by channel
  - control contributions by control column where present
  - event contributions by event column/window where present
  - aggregate seasonality contribution where present
  - aggregate trend contribution where present
- contribution shares derived from that same additive decomposition
- response-curve generation for supported time-series media channels
- marketing metrics such as ROAS, mROAS, CPA, and mCPA
- analyst-ready summary tables derived from typed post-model outputs
- Abacus parity coverage for the supported Phase 7 time-series surface

## Not In Scope

The following remain outside Phase 7:

- new MMM feature combinations beyond the frozen Phase 5 matrix
- inference-contract changes or new backend semantics
- panel post-modeling semantics and outputs
- budget optimization
- pipeline orchestration and CLI/export workflow
- plotting/report presentation layers
- NetCDF / ArviZ-native grouped interchange

Those belong to Phases 8-10 or later bounded follow-up work.

## Execution Order

### 07-01: Contributions And Decomposition Baseline

**Goal:** establish one truthful additive post-model baseline for supported
time-series grouped artifacts.

**Scope:**

- create the first `src/postmodel/` module ownership layer
- create the deterministic replay helper layer that re-materializes modeled
  additive terms from grouped posterior draws, spec, and observed data
- add typed contribution and decomposition result surfaces
- compute additive contributions in observed target units from
  `InferenceResults`
- keep contribution semantics traceable to the modeled additive terms rather
  than introducing heuristic attribution logic
- add contribution-share calculations on top of the same contribution baseline
- add the first waterfall/decomposition summary view

**Acceptance:**

- the deterministic replay contract is implemented without widening
  `InferenceResults` and without making `generated_quantities()` the public
  Phase 7 dependency
- supported time-series grouped artifacts for `TS-00`, `TS-03`, `TS-04`, and
  `TS-05` can produce time-indexed additive contributions in observed target
  units
- contributions and decomposition stay traceable to the current modeled terms:
  intercept, media, controls, events, seasonality, and trend where present
- contribution shares are derived from the same additive baseline instead of a
  second inconsistent formula path
- dedicated negative tests prove panel artifacts fail honestly on this Phase 7
  surface

**Update 2026-04-22:** `07-01` is complete. The current implementation lives in
`src/postmodel/{types,replay,contributions,decomposition}.jl` and adds
time-series contribution/decomposition support for the required `TS-00`,
`TS-03`, `TS-04`, and `TS-05` grouped-artifact bundles plus bounded
time-series VI coverage. Resolved standardized-control replay state is carried
inside `InferenceResults.spec.controls` so deterministic replay remains
faithful on grouped `new_data` artifacts without widening `InferenceResults`.

### 07-02: Response Curves And Business Metrics

**Goal:** turn fitted posteriors into actionable response and efficiency
outputs on the same bounded time-series surface.

**Scope:**

- add typed response-curve and metric result surfaces
- compute response curves for supported media channels from the same canonical
  deterministic replay path rather than a second backend-specific mechanism
- keep metric calculations derived from the same response surface rather than
  duplicating business logic in separate formulas
- add ROAS, mROAS, CPA, and mCPA on the current bounded time-series surface

**Acceptance:**

- supported time-series grouped artifacts for `TS-00`, `TS-03`, `TS-04`, and
  `TS-05` can produce a counterfactual response curve for a named media channel
- ROAS, mROAS, CPA, and mCPA can be computed from the same response surface and
  are documented honestly
- unsupported panel post-model requests and unsupported malformed inputs fail
  explicitly
- no Phase 8 optimizer semantics are smuggled into Phase 7 metric code

**Update 2026-04-22:** `07-02` is complete. The current implementation lives in
`src/postmodel/{response_curves,metrics}.jl` and adds
`response_curve_results(results; channel, grid)` plus
`metric_results(results; channel, grid)` on the bounded time-series grouped
surface for both supported MCMC and supported VI rows. The frozen contract uses
total-spend grids in original units, preserves the observed temporal spend
shape for the selected media channel, and derives ROAS, mROAS, CPA, and mCPA
from that same response surface. Panel post-model requests continue to fail
explicitly.

### 07-03: Parity Coverage, Summary Tables, And Closeout

**Goal:** make the Phase 7 post-model surface testable, documented, and ready
for Phase 8 consumers.

**Scope:**

- add Abacus parity tests for the supported post-model outputs
- add DataFrame summary-table projections for the typed result surfaces
- freeze the truthful Phase 7 support matrix
- document the Phase 7 to Phase 8 handoff explicitly:
  - Phase 8 must consume the frozen response/metric surface rather than
    re-deriving business outputs from raw posterior objects

**Acceptance:**

- supported Phase 7 outputs match Abacus for the same posterior draws on agreed
  fixtures within `1e-6`
- closeout coverage spans the frozen supported time-series matrix `TS-00`
  through `TS-05`
- summary tables exist as documented DataFrame projections of typed post-model
  outputs
- docs state clearly that post-modeling remains time-series first and that panel
  outputs are not part of the closed Phase 7 surface
- the post-model support matrix is explicit before Phase 8 begins

**Update 2026-04-22:** `07-03` is complete. The current implementation adds
`src/postmodel/summary.jl`, `summary_table(result)`, Abacus-backed parity
fixtures for the retained summary semantics, and explicit support-matrix
coverage across the frozen supported time-series MCMC and VI rows. Public docs
now state the truthful post-model matrix, and panel post-model outputs remain
explicitly unsupported at Phase 7 closeout.

## Dependencies And Handoff

Phase 7 depends on the frozen Phase 6 contracts:

- `InferenceResults`
- `approximate_fit!`
- `VariationalConfig`
- `src/inference/`
- the explicit warning/failure taxonomy

Phase 8 must depend on Phase 7 rather than bypass it:

- optimization must consume the frozen Phase 7 response/metric surface
- optimization must not reopen post-model semantics or compute a parallel
  response contract directly from raw posterior objects

## Deliverables

At minimum, Phase 7 should leave the repo with:

- `src/postmodel/types.jl`
- `src/postmodel/replay.jl`
- `src/postmodel/contributions.jl`
- `src/postmodel/decomposition.jl`
- `src/postmodel/response_curves.jl`
- `src/postmodel/metrics.jl`
- `src/postmodel/summary.jl`
- `test/postmodel/`
- docs for the supported post-model outputs
- parity and negative coverage for the truthful Phase 7 surface

## Exit Criteria

Phase 7 is complete only when all of the following are true:

- analysts can compute supported contributions and decomposition from grouped
  time-series fits
- analysts can compute supported response curves and business metrics from the
  same grouped time-series fits
- the post-modeling surface consumes `InferenceResults` directly and does not
  redefine the inference contract
- the deterministic replay contract is implemented without widening
  `InferenceResults`
- summary tables and Abacus parity coverage exist for the supported time-series
  surface
- the frozen support matrix is explicit across `TimeSeriesMMM` MCMC,
  `TimeSeriesMMM` VI, and unsupported `PanelMMM` post-modeling rows
- panel post-modeling remains explicitly unsupported unless separately planned
  and delivered
