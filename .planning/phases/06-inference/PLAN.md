# Phase 6 Plan — Inference

**Phase:** 6
**Phase Name:** Inference
**Status:** Planned
**Last Reconciled:** 2026-04-22

## Objective

Turn the frozen Phase 5 model surface into a robust inference and inference-artifact
workflow without reopening model-feature scope.

Phase 6 is not where Epsilon invents more MMM features. It is where the package
stops being merely “runnable” and becomes trustworthy as a fitting workflow:

- honest MCMC execution and failure behavior
- richer grouped inference artifacts and predictive outputs
- a bounded first variational-inference path
- explicit support boundaries across `TimeSeriesMMM` and `PanelMMM`

The key constraint is that Phase 6 must harden the existing Phase 4/5 surfaces
rather than redefining them.

## Entry Conditions

Phase 5 is closed and the following are already in place:

- frozen supported feature matrix for `TimeSeriesMMM` and `PanelMMM`
- canonical `ModelConfig`, `SamplerConfig`, `MMMData`, and `PanelMMMData`
- runnable Turing-backed `fit!` for `TimeSeriesMMM` and `PanelMMM`
- `predict` and `prior_predict` on the current model paths
- typed `ModelResults`, fit artifacts, metadata, and save/load
- typed convergence reports, convergence warnings, sampler diagnostics, and
  sampler warnings
- bounded multi-chain execution behavior and seeded reproducibility checks

Phase 6 must build on those surfaces rather than replacing them.

## Current Base To Harden

The current inference-adjacent surface is real but still transitional:

- canonical fit entry points:
  - `fit!(model::TimeSeriesMMM)`
  - `fit!(model::PanelMMM)`
- canonical MCMC config surface:
  - `SamplerConfig`
  - YAML `fit` block
- current predictive surface:
  - `predict(model; new_data=...)`
  - `prior_predict(model; new_data=...)`
- current typed artifact/results surface:
  - fit artifact metadata
  - `ModelResults`
  - save/load for model and results
- current diagnostics surface:
  - `model_diagnostics`
  - `convergence_report`
  - `convergence_warnings`
  - `sampler_diagnostics`
  - `sampler_warnings`

What is still missing is a truthful inference layer on top of that base:

- a dedicated inference module structure
- grouped inference export beyond the current flat results container
- bounded variational inference
- explicit backend support rules and failure policy

## Starting Support Matrix

Phase 6 starts from the following already-implemented baseline:

| Surface | `TimeSeriesMMM` | `PanelMMM` | Notes |
|---|---|---|---|
| `fit!` via current Turing MCMC path | Supported | Supported | Current canonical MCMC entry point |
| `predict` / `prior_predict` | Supported | Supported | On the frozen Phase 5 feature surface |
| `ModelResults` | Supported | Supported | Flat typed results container |
| current diagnostics and warning helpers | Supported | Supported | Exposed through fit artifacts and `ModelResults` |
| grouped inference export | Not Yet Supported | Not Yet Supported | Phase 6 `06-02` scope |
| VI | Not Yet Supported | Not Yet Supported | Phase 6 `06-03`, time-series first |

Phase 6 must keep this starting matrix explicit. It must not imply that panel VI,
grouped panel export, or backend parity already exist merely because the panel
MCMC path can fit and predict.

## Phase 6 Contract

Phase 6 must preserve these contracts:

- `SamplerConfig` remains the canonical external MCMC configuration object.
- the YAML `fit` block remains the canonical external MCMC config mapping.
- `fit!` remains the canonical MCMC entry point; Phase 6 must not hide a VI mode
  behind the existing MCMC path.
- `ModelResults` remains the lighter flat convenience surface introduced in
  Phase 4; Phase 6 must not silently redefine it into the grouped contract.
- Phase 6 must not widen the frozen Phase 5 feature matrix.

Phase 6 is allowed to introduce:

- `src/inference/` as the canonical module layer for new inference ownership
- `InferenceResults` as the canonical grouped inference-results/export surface
- `inference_results(model; ...)` plus matching save/load helpers as the public
  grouped-artifact access path
- a bounded explicit VI entry point:
  - `approximate_fit!(model, config::VariationalConfig = VariationalConfig())`
- stricter warning and failure policy around the current MCMC path

Phase 6 also settles the following contracts up front:

- `InferenceResults` is the only canonical grouped artifact surface for Phase 6.
- `InferenceResults` must organize:
  - posterior draws
  - prior draws where available
  - posterior predictive draws
  - prior predictive draws
  - sample statistics / sampler internals
  - observed data
  - coordinate metadata
  - artifact metadata
- NetCDF / ArviZ-native interchange is explicitly deferred from Phase 6.
- VI is a Julia API only in Phase 6. The YAML `fit` block remains MCMC-only,
  and there is no Phase 6 YAML VI contract.
- `VariationalConfig` must own the draw/materialization controls needed to
  produce predictive samples and grouped artifacts from a VI fit.

## In Scope

- MCMC workflow hardening on the current supported Phase 5 surface
- grouped inference artifact export, including predictive groups
- bounded variational inference
- explicit support matrix for inference backend × model type × artifact surface
- dedicated `src/inference/` and `test/inference/` structure as the canonical
  ownership layer for Phase 6 inference work
- honest docs and failure behavior for unsupported combinations

## Not In Scope

The following remain outside Phase 6:

- new model-feature combinations beyond the frozen Phase 5 matrix
- HSGP reconsideration
- new panel feature breadth
- post-model contributions, decomposition, response curves, or business metrics
- budget optimization
- pipeline orchestration / CLI end-to-end workflow
- plotting/report presentation layers

Those belong to Phases 7-10.

## Execution Order

### 06-01: MCMC Hardening And Failure Policy

**Goal:** make the current MCMC path truthful, reproducible, and explicit about
warnings versus failures.

**Outcome (2026-04-22):**
- `src/inference/mcmc.jl` now owns the shared MCMC execution policy, seeded RNG
  handling, diagnostics bundling, and failed-fit state transitions for both
  `TimeSeriesMMM` and `PanelMMM`
- successful fit artifacts now carry an explicit `execution_plan` in addition to
  `execution_backend`, so single-chain, serial, and threaded execution behavior
  is no longer inferred only from a message string
- failed `fit!` calls now replace stale successful fit state with
  `ModelFitState(status = :error, ...)` instead of leaving an old valid artifact
  in place
- `predict` and `model_results` now fail explicitly when the most recent `fit!`
  failed, rather than surfacing misleading downstream artifact or alignment
  errors
- panel convenience diagnostics now work through `model_diagnostics`,
  `sampler_diagnostics`, `convergence_report`, and `convergence_warnings` on a
  fitted `PanelMMM`
- dedicated negative and execution-policy coverage now lives in `test/inference/`

**Scope:**
- introduce the first dedicated `src/inference/` MCMC ownership layer without
  rewriting working model code purely for directory churn
- keep `SamplerConfig` and the YAML `fit` block canonical
- harden execution-mode behavior, warning policy, and malformed-config handling
- make support boundaries explicit across `TimeSeriesMMM` and `PanelMMM`
- ensure current diagnostics/warnings are surfaced through one coherent fit path
- freeze one explicit warning-versus-failure taxonomy:
  - invalid config, unsupported model/backend combinations, or impossible
    execution requests fail before sampling
  - completed fits with threshold breaches surface typed warnings and preserve
    a successful fit state
  - aborted or incomplete sampling fails and must not fabricate a successful
    fit artifact

**Acceptance:**
- every supported Phase 5 bundle still fits through the canonical MCMC path
- MCMC warnings and failures are documented and covered by dedicated negative
  tests rather than only happy-path smoke tests
- threaded versus serial execution policy is explicit and tested
- seeded reproducibility and config semantics remain truthful
- new MCMC-facing ownership lives under `src/inference/` while the public API
  remains stable

### 06-02: Grouped Results Export And Predictive Grouping

**Goal:** land the richer grouped inference artifact surface deferred from
Phase 4.

**Outcome (2026-04-22):**
- `src/inference/results.jl` now owns the canonical grouped
  `InferenceResults` surface, together with `InferenceSampleStats`,
  `inference_results(model; ...)`, and grouped-artifact save/load helpers
- `InferenceResults` now preserves grouped posterior draws, optional prior
  draws, posterior predictive draws, prior predictive draws, sampler internals,
  typed diagnostics metadata, observed data, and coordinate metadata without
  redefining the flatter `ModelResults` container
- grouped export now works on both the supported `TimeSeriesMMM` path and the
  bounded `PanelMMM` path
- grouped-artifact persistence is covered through round-trip save/load tests
- the public docs now describe `ModelResults` as the flat convenience surface
  and `InferenceResults` as the canonical grouped artifact for later Phase 6/7
  consumers

**Scope:**
- introduce `InferenceResults` as the only canonical grouped surface in
  Phase 6, together with `inference_results(model; ...)` and matching save/load
  helpers
- keep the grouped surface Julia-native first and explicitly defer NetCDF /
  ArviZ-native interchange from Phase 6
- preserve the additive relationship between `ModelResults` and
  `InferenceResults` rather than leaving two undocumented artifact stacks
- ensure save/load round-trips grouped inference artifacts honestly
- make grouped export work on the supported MCMC time-series and bounded panel
  paths before Phase 7 depends on it

**Acceptance:**
- one typed grouped inference-results surface, `InferenceResults`, exists and is
  documented
- the relationship between `ModelResults` and `InferenceResults` is explicit
- grouped export preserves predictive outputs, diagnostics metadata, observed
  data, and coordinates
- grouped export works for the supported time-series path and the bounded panel
  path where MCMC is already supported
- docs state clearly that ArviZ / NetCDF-style interchange is explicitly
  deferred from Phase 6
- Phase 7 handoff text names `InferenceResults` as the canonical artifact
  surface it must consume

### 06-03: Variational Inference Baseline

**Goal:** add one bounded and honest VI path without pretending backend parity
where it does not exist.

**Outcome (2026-04-22):**
- `src/inference/vi.jl` now owns the bounded explicit VI path through
  `approximate_fit!(model, config::VariationalConfig = VariationalConfig())`
- `VariationalConfig` now fixes the current external VI contract to
  mean-field Gaussian ADVI with explicit iteration count, posterior draw
  materialization count, seeded RNG support, and progress control
- supported `TimeSeriesMMM` VI fits now materialize posterior draws into a
  standard named `Chains` artifact, so grouped export can keep using the
  canonical `InferenceResults` surface instead of introducing a second
  posterior container
- `InferenceResults` now works on bounded variational fit states for
  `TimeSeriesMMM`, including grouped posterior draws, prior draws, and
  posterior/prior predictive groups
- `PanelMMM` VI remains explicitly unsupported and now fails through a typed
  variational error-state contract instead of leaving stale successful fit
  state behind
- flat `ModelResults` and the MCMC-specific diagnostics/warning helpers remain
  honestly Turing-only rather than pretending that VI draws carry MCMC sampler
  semantics

**Scope:**
- implement the explicit VI entry point
  `approximate_fit!(model, config::VariationalConfig = VariationalConfig())`
  rather than overloading `fit!`
- keep the VI surface Julia-only in Phase 6; there is no YAML VI contract and
  no Phase 6 change to the canonical YAML `fit` block
- target `AdvancedVI.jl` / ADVI first
- support `TimeSeriesMMM` first unless `PanelMMM` falls out naturally without a
  new public contract
- define how `VariationalConfig` controls draw materialization and predictive
  generation for VI-backed grouped artifacts
- integrate supported VI fits into the same `InferenceResults` grouped surface
- document unsupported model/backend combinations explicitly

**Acceptance:**
- at least one supported `TimeSeriesMMM` Phase 5 bundle can be fit through
  `approximate_fit!`
- `VariationalConfig` and its predictive/materialization semantics are
  documented
- supported VI fits can materialize `InferenceResults`
- VI artifacts/results are distinguishable from MCMC artifacts/results
- unsupported VI combinations fail honestly and early
- docs and tests define the actual VI support boundary rather than implying full
  backend parity, and `PanelMMM` VI is not implied unless implemented and
  tested

### 06-04: Inference Closeout And Handoff

**Goal:** freeze the truthful Phase 6 inference contract and hand off cleanly to
Phase 7.

**Outcome (2026-04-22):**
- the Phase 6 inference surface is now frozen as an explicit support matrix
  across model type, backend, predictive surface, grouped export availability,
  and diagnostics availability
- README/docs now distinguish the three supported inference rows
  (`INF-TS-MCMC`, `INF-P-MCMC`, `INF-TS-VI`) from the explicit unsupported
  rows instead of leaving the backend boundary implicit
- dedicated matrix coverage now lives in `test/inference/matrix.jl`, with one
  test-covered row per supported inference combination plus explicit negative
  coverage for unsupported panel VI
- the direct `prior_predict(model)` semantics are now documented honestly for
  VI-backed fits: the direct helper remains backend-agnostic and uses
  `SamplerConfig.draws`, while grouped VI prior draws and prior predictive
  groups inside `InferenceResults` use `VariationalConfig.draws`
- the planning backbone now records Phase 6 as complete and hands the repo off
  to Phase 7 post-modeling work without reopening the settled grouped-artifact
  or explicit VI contracts

**Scope:**
- reconcile docs, roadmap, milestones, and board with the implemented Phase 6
  surface
- freeze the support matrix across:
  - model type
  - inference backend
  - predictive surface
  - grouped export availability
- close any remaining open inference-surface questions by either implementing
  them or deferring them explicitly
- hand off downstream consumption work to Phase 7

**Acceptance:**
- the supported Phase 6 inference surface is documented as a concrete matrix
- every supported row in that matrix has dedicated tests
- unsupported combinations are listed explicitly
- remaining post-modeling work is handed off to Phase 7 without reopening
  inference scope

## Settled Contracts

### Grouped Artifact Contract

Phase 6 no longer treats grouped export as an implementation-time design gate.
The contract is fixed before execution:

- `InferenceResults` is the canonical grouped artifact surface.
- `inference_results(model; ...)` is the public grouped materialization entry
  point.
- `save_inference_results` / `load_inference_results` (or one equivalently
  named helper pair) own grouped-artifact persistence.
- `ModelResults` remains supported as a flat convenience surface and must not be
  treated as the grouped contract.
- NetCDF / ArviZ-native interchange is deferred from Phase 6.

### VI Public Contract

Phase 6 no longer leaves the VI surface implicit:

- `approximate_fit!` is the explicit VI entry point.
- `VariationalConfig` is the external VI configuration object.
- YAML `fit` remains MCMC-only in Phase 6.
- `TimeSeriesMMM` is the default first support target.
- `PanelMMM` VI support is optional and must not be implied unless implemented.

### Module Ownership Contract

Inference-adjacent behavior currently spans `src/model/` and `src/mmm/`.
Phase 6 will introduce `src/inference/` as the canonical ownership layer for
new inference work, but it may do so incrementally.

Accepted rule:

- move or wrap behavior only when it clarifies ownership or enables new Phase 6
  capability
- do not churn working code purely for directory purity

### Warning And Failure Contract

Phase 6 must use one explicit warning-versus-error taxonomy:

- invalid config, unsupported combinations, or impossible execution requests are
  errors before sampling starts
- completed fits with diagnostic threshold breaches surface typed warnings and
  preserve a valid fit state
- aborted or incomplete sampling is an error and must not leave behind a fake
  successful fit artifact

## Exit Criteria

Phase 6 is complete only when all of the following are true:

- supported MCMC workflows are hardened and documented honestly
- grouped inference export exists as `InferenceResults` and is usable by later
  phases
- a bounded VI path exists through `approximate_fit!` with explicit support
  limits
- failure behavior and unsupported combinations are tested and documented
- the Phase 6 inference support matrix is frozen before Phase 7 begins

## Handoff To Later Phases

### Phase 7

Phase 7 must consume `InferenceResults` and the hardened predictive workflows
from Phase 6. It must not introduce a parallel posterior artifact format or
re-open backend semantics.

### Phases 8-10

Optimization, pipeline, and plotting should treat the Phase 6 artifact surface
as canonical rather than re-opening backend semantics.

## Verification Anchor

Phase 6 remains planning-complete only if implementation later preserves the
repository quality gate:

- `make test`
- `make docs`

As Phase 6 opens, new inference-focused coverage should live under:

- `test/inference/` for new wrappers, grouped export, and VI behavior
- `test/model/` only when extending the current model-integrated surfaces
