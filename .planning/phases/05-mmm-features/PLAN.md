# Phase 5 Plan — MMM Features

**Phase:** 5
**Phase Name:** MMM Features
**Status:** Completed
**Last Reconciled:** 2026-04-22

## Objective

Broaden Epsilon from a minimal runnable MMM core into a practical MMM feature
layer without reopening Phase 4 scope.

Phase 5 is where the package grows beyond the current media-only time-series
path and becomes capable of real feature composition:

- seasonality
- trend
- events and richer controls
- panel and hierarchical structure

The key constraint is that this work must extend the current typed model-core
contract rather than replacing it. Phase 5 is feature expansion, not another
round of model-core redesign.

## Entry Conditions

Phase 4 is closed and the following are already in place:

- typed config, sampler, data, and model types
- deterministic config merging
- a runnable Turing-backed `TimeSeriesMMM`
- prior and posterior predictive support
- typed model/results artifacts
- typed diagnostics, convergence reports, and sampler warnings
- the current runtime surface for adstock and saturation transforms

Phase 5 must build on those interfaces.

## Current Base To Extend

The current feature baseline is intentionally narrow:

- model type:
  - `TimeSeriesMMM`
- current deterministic media path:
  - adstock: `none`, `geometric`, `delayed`, `binomial`, `weibull_pdf`,
    `weibull_cdf`
  - saturation: `none`, `logistic`, `tanh`, `michaelis_menten`, `hill`
- current non-media additive path:
  - seasonality: `none`, `fourier`
- current metadata surface:
  - observation/channel/control coordinates
  - named dimensions for the time-series path, including Fourier mode metadata

Phase 5 extends that base with non-media MMM features and broader model
structure.

## Phase 5 Config Contract

Phase 5 must extend the current public config surface rather than replacing it.
The minimum supported feature contract for the phase is:

- existing top-level blocks remain canonical:
  - `data`
  - `target`
  - `media`
  - `dimensions`
  - `priors`
  - `fit`
- `media.channels` remains the canonical media-column list
- `media.controls` remains the canonical control-column list
- `dimensions.panel` remains the canonical panel-dimension declaration when a
  panel model path is enabled

The Phase 5 feature blocks to add are:

- `seasonality`
  - required key: `type`
  - supported values in the current Phase 5 surface:
    - `none`
    - `fourier`
  - required key for the supported Fourier baseline:
    - `n_order`
  - supported nested prior path:
    - `priors.beta`
  - `hsgp` is deferred from the supported Phase 5 surface by ADR-010
- `trend`
  - required key: `type`
  - supported values:
    - `linear`
    - `changepoint`
  - required key for the supported changepoint path:
    - `n_changepoints`
  - supported nested prior paths:
    - `priors.beta` for `trend.type = "linear"`
    - `priors.delta` for `trend.type = "changepoint"`
  - `trend.include_intercept` is not supported on the current
    `TimeSeriesMMM` path; the model intercept remains the only supported
    intercept term
- `events`
  - supported keys for the current model path:
    - `columns` for manual event matrices
    - `windows` for generated inclusive date-window event matrices
  - supported nested prior path:
    - `priors.beta`
- `controls`
  - optional feature-specific block for richer control behavior beyond the
    existing `media.controls` column list
  - Phase 5 must document exactly what extra control options are supported
    rather than treating “richer controls” as open-ended

Explicit non-goals for the Phase 5 config contract:

- no undocumented feature-specific aliases
- no hidden compatibility layer that silently invents unsupported combinations
- no public `hsgp` config path if the 05-01 gate chooses bounded defer

The phase must finish with one explicit supported feature-combination matrix
covering:

- time-series + Fourier
- time-series + one supported trend path
- time-series + one supported event path
- time-series + one supported richer-control path
- one supported small panel/hierarchical path

## In Scope

- Fourier seasonality on the current time-series path
- explicit HSGP strategy decision before downstream feature work depends on it
- linear trend and bounded time-varying trend scope
- event and holiday effects
- richer control-variable handling
- panel and hierarchical MMM structure
- typed config/model/data expansion required to support those features
- integration tests proving supported feature combinations actually sample

## Not In Scope

The following remain outside Phase 5:

- grouped results export
- variational inference hardening
- broader inference wrappers and failure policy
- post-model contributions and business metrics
- budget optimization
- pipeline orchestration and CLI workflows
- plotting/report surfaces

Those belong to Phases 6-10 and should not be smuggled back into Phase 5.

## Execution Order

### 05-01: Seasonality Baseline And HSGP Decision Gate

**Goal:** land a truthful seasonality baseline and force the HSGP decision early.

**Outcome (2026-04-21):**
- Fourier seasonality is now supported on the current `TimeSeriesMMM` path.
- The supported public config contract is `seasonality.type = "fourier"` with
  required `n_order` and optional `seasonality.priors.beta`.
- HSGP is bounded-deferred from the supported Phase 5 surface by ADR-010.

**Scope:**
- add deterministic time-index / seasonal feature builders
- integrate Fourier seasonality into the current `TimeSeriesMMM` path
- spike HSGP feasibility against the Julia GP ecosystem and current Turing
  model path
- record an ADR choosing one of:
  - implement HSGP in Phase 5, or
  - defer HSGP behind a bounded follow-up without blocking other supported
    Phase 5 features

**Acceptance:**
- a synthetic time-series dataset can be fit with `seasonality.type = "fourier"`
  and the supported Fourier config keys documented in this plan
- one integration test proves Fourier seasonality composes with the current
  media path on `TimeSeriesMMM`
- the HSGP strategy is resolved by ADR using the decision rubric in
  `RISKS-AND-DECISIONS.md`
- downstream Phase 5 plans do not depend on an unresolved HSGP question or an
  implicit `hsgp` config contract

### 05-02: Trend, Events, And Controls

**Goal:** add the main non-seasonal additive feature layer for practical MMM use.

**Outcome (partial, 2026-04-22):**
- a bounded `trend.type = "linear"` path is now supported on the current
  `TimeSeriesMMM` surface
- a bounded `trend.type = "changepoint"` path is now supported with required
  `trend.n_changepoints` and optional `trend.priors.delta`
- the current public trend contract is `trend.type = "linear"` with optional
  `trend.priors.beta`, or `trend.type = "changepoint"` with
  `trend.n_changepoints` and optional `trend.priors.delta`
- a first supported event-matrix path is now available through
  `events.columns` with optional `events.priors.beta`
- a first generated holiday/event feature-matrix path is now available through
  `events.windows`, using named inclusive date windows on Date/DateTime-like
  `MMMData.dates`
- a first richer-control path is now available through
  `controls.transform = "standardize"` with optional `controls.priors.beta`,
  layered on top of the canonical `media.controls` column list

**Scope:**
- linear trend component
- bounded time-varying trend decision and minimal supported path
- event / holiday design-matrix support
- richer control-variable handling beyond the current minimal regression path
- typed config/data/model updates required for those feature blocks

**Acceptance:**
- one documented `trend.type = "linear"` path can be configured and sampled on
  a synthetic time-series dataset
- one documented `trend.type = "changepoint"` path can be configured and
  sampled on a synthetic time-series dataset
- one documented event-matrix path can be configured through `events.columns`
  and sampled on a synthetic time-series dataset
- one documented generated event-matrix path can be configured through
  `events.windows` and sampled on a synthetic time-series dataset
- one documented richer-control path can be configured and sampled on a
  synthetic time-series dataset
- at least one integration test covers a supported combination of media +
  Fourier + one additional Phase 5 feature block

### 05-03: Panel And Hierarchical Structure

**Goal:** expand from single-series MMM to the first supported panel/hierarchical path.

**Outcome (2026-04-22):**
- `PanelMMM <: AbstractMMMModel` is now the first supported panel target type.
- the current bounded panel contract uses `PanelMMMData` with one declared
  panel dimension, a shared time axis, shared media coefficients, and centered
  hierarchical panel intercept offsets
- the current supported panel path reuses the existing bounded adstock and
  saturation surface, but does not yet expose panel seasonality, trend,
  events, or richer controls
- typed coordinate metadata, fit/predict/prior-predict, typed results, and
  save/load now all work on the supported small panel path

**Scope:**
- confirm the Phase 5 panel architecture before implementation:
  - Phase 5 will introduce `PanelMMM <: AbstractMMMModel`
  - `TimeSeriesMMM` remains the single-series path and must not absorb panel
    semantics
  - a broader compositional refactor is allowed only if explicitly required and
    recorded as a separate decision, not assumed by default
- introduce panel-oriented typed model/data surface
- expand coordinate metadata and dims/plates beyond the current time-series
  path
- implement hierarchical priors / offsets needed for small panel MMMs
- validate data layout, indexing, and posterior wiring on small synthetic panel
  cases before scaling

**Acceptance:**
- the panel architecture decision is recorded before 05-03 implementation
  starts, with `PanelMMM` as the Phase 5 target type unless explicitly revised
  by ADR
- a small synthetic panel case (for example 2 geos × 2 channels) can be built
  and sampled through the supported panel path
- hierarchical priors/offsets are covered by dedicated synthetic tests
- dims, coordinates, and indexing behavior for that supported panel path are
  documented explicitly rather than described as “honest metadata”

### 05-04: Feature Integration And Phase Closeout

**Goal:** freeze the supported Phase 5 feature contract and hand off inference/reporting work cleanly.

**Outcome (2026-04-22):**
- the supported Phase 5 surface is now frozen as an explicit feature-bundle
  matrix rather than an implied set of feature flags
- supported rows are covered by dedicated integration tests in
  `test/model/feature_matrix.jl`
- unsupported panel/HSGP combinations are now listed explicitly in the public
  docs and planning surface
- Phase 5 is now closed; broader inference/export work is handed off to
  Phase 6
- the Phase 6 starting panel baseline is explicit: `P-00` carries bounded MCMC
  `fit!`, `predict`, `prior_predict`, `ModelResults`, save/load, and the
  current diagnostics helpers, while grouped export and VI remain Phase 6 work

**Scope:**
- land the accepted HSGP path if Phase 05-01 chose implementation within Phase 5,
  or explicitly document the bounded defer path if it did not
- add combined feature coverage for the supported Phase 5 surface
- reconcile docs, roadmap, and milestone text with the implemented feature set
- define the truthful boundary between Phase 5 and Phase 6

**Acceptance:**
- the supported Phase 5 feature surface is documented as a concrete feature
  matrix, including unsupported combinations
- feature-combination tests exist for every supported row in that matrix
- remaining inference/export work is explicitly handed off to Phase 6+

## Frozen Phase 5 Feature Matrix

### Supported bundles

| ID | Model | Seasonality | Trend | Events | Controls | Status | Notes |
|---|---|---|---|---|---|---|---|
| `TS-00` | `TimeSeriesMMM` | `none` | `none` | `none` | `none` | Supported | Base time-series media path |
| `TS-01` | `TimeSeriesMMM` | `fourier` | `none` | `none` | `none` | Supported | Requires `seasonality.n_order` |
| `TS-02` | `TimeSeriesMMM` | `fourier` | `linear` | `none` | `none` | Supported | `trend.priors.beta` optional |
| `TS-03` | `TimeSeriesMMM` | `fourier` | `linear` | `events.columns` | `none` | Supported | Manual event matrix via `MMMData.events` |
| `TS-04` | `TimeSeriesMMM` | `fourier` | `changepoint` | `events.windows` | `none` | Supported | Requires `trend.n_changepoints` |
| `TS-05` | `TimeSeriesMMM` | `fourier` | `none` | `none` | `controls.transform = "standardize"` | Supported | Requires `media.controls` |
| `P-00` | `PanelMMM` | `none` | `none` | `none` | `none` | Supported | One panel dim, shared media betas, hierarchical panel intercept offsets |

### Explicitly unsupported in Phase 5

| ID | Model | Combination | Status | Reason |
|---|---|---|---|---|
| `TS-U1` | `TimeSeriesMMM` | `seasonality.type = "hsgp"` | Unsupported | HSGP is deferred from the Phase 5 surface |
| `P-U1` | `PanelMMM` | any panel seasonality | Unsupported | Fourier/HSGP seasonality is not yet exposed on the panel path |
| `P-U2` | `PanelMMM` | any panel trend | Unsupported | Linear/changepoint trend is not yet exposed on the panel path |
| `P-U3` | `PanelMMM` | any panel events | Unsupported | `events.columns` / `events.windows` are not yet exposed on the panel path |
| `P-U4` | `PanelMMM` | any panel richer controls | Unsupported | `controls.transform` is not yet exposed on the panel path |

## Decision Gates

### HSGP Gate

This is the highest-risk Phase 5 item and must be forced at the start of the
phase, not at the end.

By the close of 05-01, the project must have:

- an ADR on HSGP strategy
- a clear implementation or bounded defer path
- no downstream Phase 5 task that quietly assumes HSGP is “probably fine later”
- no public `seasonality.type = "hsgp"` config path unless the gate chooses
  implementation in Phase 5

### Panel Scope Gate

Phase 5 should deliver the first honest panel/hierarchical path, not an
unbounded rewrite of all model types. The phase should start with small,
synthetic panel cases and only widen after typed metadata, indexing, and prior
structure are proven.

Phase 5 resolves this by treating `PanelMMM` as the default panel target type.
Widening `TimeSeriesMMM` to absorb panel semantics is out of scope unless a
later ADR explicitly reverses that choice.

## Exit Criteria

Phase 5 is complete when all of the following are true:

- users can configure and sample supported seasonality features
- the supported Phase 5 config contract is documented with exact keys and
  explicit unsupported combinations
- users can configure and sample supported trend, event, and richer control
  features
- users can build and sample a supported panel/hierarchical MMM path
- the HSGP strategy is resolved and either implemented or explicitly bounded
- supported feature combinations are covered by integration tests
- the feature surface is documented honestly and does not claim broader
  inference/reporting work than the code actually provides

## Handoff To Later Phases

### Phase 6

Phase 6 should take the widened model surface from Phase 5 and harden:

- inference wrappers
- variational inference
- predictive workflow breadth
- diagnostics policy and failure handling
- grouped results export

### Phases 7-10

These phases should consume the supported feature surface from Phase 5 and the
inference/reporting hardening from Phase 6 without having to redefine the model
feature contract.

## Verification Anchor

Phase 5 planning and execution should keep the package-level checks truthful:

- `make test`
- `make docs`
