# Phase 4 Plan — Model Core

**Phase:** 4
**Phase Name:** Model Core
**Status:** Complete
**Last Reconciled:** 2026-04-21

## Objective

Close Phase 4 around a truthful, testable model-core contract:

- typed config, data, and model objects
- a minimal runnable Turing-backed `TimeSeriesMMM`
- prior and posterior predictive paths
- serializable model and results artifacts
- typed diagnostics, convergence reporting, and sampler warnings

Phase 4 is no longer about proving that the first model can run at all. That
work already exists in the codebase. The remaining job is to make the phase
boundary explicit, reconcile planning with implementation, and leave a stable
handoff to Phase 5 and Phase 6.

## Implemented Today

The following Phase 4 surface already exists and should be treated as landed
code, not future scope:

- `src/model/types.jl`
  - `AbstractModel`, `AbstractRegressionModel`, `AbstractMMMModel`
  - `ModelConfig`, `SamplerConfig`, `MMMData`
- `src/model/config.jl`
  - YAML-backed config loading
  - deterministic config merging with precedence `defaults < config < overrides`
- `src/model/builder.jl`
  - `TimeSeriesMMM`
  - `MMMModelSpec`
  - `ModelCoordinateMetadata`
  - `build_model`, `fit!`, `predict`
- `src/mmm/model.jl`
  - minimal runnable Turing-backed MMM
  - NUTS sampling
  - single-chain, serial multi-chain, and threaded multi-chain execution modes
  - prior predictive and posterior predictive support
- `src/mmm/media.jl`
  - deterministic media transform chain for the current runtime path
- `src/model/io.jl`
  - typed model save/load with artifact metadata
- `src/model/results.jl`
  - typed `ModelResults`
  - results save/load
- `src/model/diagnostics.jl`
  - typed parameter diagnostics
  - typed convergence reports and warnings
  - typed sampler diagnostics and warnings

## Supported Runtime Surface

The current Turing-backed model-core path is intentionally narrow and should be
documented that way:

- model type: `TimeSeriesMMM`
- transform support in the runtime path:
  - adstock: `none`, `geometric`, `delayed`, `binomial`, `weibull_pdf`, `weibull_cdf`
  - saturation: `none`, `logistic`, `tanh`, `michaelis_menten`, `hill`
- current typed metadata surface:
  - observation/channel/control coordinates
  - named-dimension metadata for the current time-series model tensors

This is sufficient for a real minimal MMM core. It is not yet the full Phase 5
feature set.

## Not In Scope For Phase 4

The following items are explicitly deferred and should not be smuggled back
into Phase 4:

- seasonality, trend, events, controls expansion beyond the current minimal path
- panel and hierarchical model structure
- HSGP feature work
- ADVI and a broader variational inference workflow
- post-modeling outputs, budget optimization, pipeline orchestration, and plotting
- a full InferenceData-compatible export layer unless it is required to stabilize
  the existing model-core contract

## Remaining Work To Close Phase 4

### 04-05a: Planning and Boundary Reconciliation

- [x] make the roadmap, milestone docs, architecture docs, and state tracking
  match the current codebase
- [x] document the true Phase 4 exit criteria
- [x] distinguish clearly between:
  - current model-core capabilities
  - Phase 5 feature expansion
  - Phase 6 inference hardening

### 04-05b: Closeout Decision On Structured Results Export

- [x] decide whether richer grouped export belongs to:
  - late Phase 4 as model-core stabilization, or
  - Phase 6 as inference/reporting hardening
- **Decision:** richer grouped results export belongs to **Phase 6**, not late
  Phase 4.
- **Rationale:** the current Phase 4 contract already covers model build/fit,
  prior and posterior predictive paths, model/results persistence, and typed
  diagnostics. Grouped export is an inference/reporting concern that depends on
  stabilizing additional result groups and warning/diagnostic policy, so
  keeping it in Phase 4 would blur the Model Core boundary.

### 04-05c: Freeze The Minimal Supported Contract

- [x] stop widening the Phase 4 runtime path unless a change is required to
  keep the current minimal contract coherent
- [x] treat further feature expansion as Phase 5 work by default
- [x] treat broader inference workflow work as Phase 6 by default

## Exit Criteria

Phase 4 can be closed when all of the following are true:

- a user can load YAML config and typed MMM data into validated Julia model objects
- a user can build a backend-agnostic `MMMModelSpec`
- a user can fit a minimal Turing-backed `TimeSeriesMMM`
- a user can run both prior predictive and posterior predictive sampling
- a user can save and load both model artifacts and typed results artifacts
- typed diagnostics, convergence reports, and sampler warnings are available for
  the fitted model path
- the supported runtime transform surface is documented honestly
- remaining feature growth and inference hardening are explicitly handed off to
  Phase 5 and Phase 6

## Handoff To Next Phases

### Phase 5

Phase 5 should build on the current model-core contract by adding:

- seasonality and trend
- events and controls beyond the current minimal path
- panel and hierarchical structure
- HSGP after an explicit strategy decision

### Phase 6

Phase 6 should harden the fitting workflow by focusing on:

- broader inference execution and configuration behavior
- variational inference
- richer diagnostics policy and failure handling
- grouped or externalized results export

## Closeout Result

Phase 4 is complete. The phase boundary is now:

- **Phase 4:** typed model-core contract for a minimal runnable MMM
- **Phase 5:** broaden model structure and MMM features
- **Phase 6:** harden inference workflows and export richer grouped results

## Verification Anchor

Planning-only reconciliation for this phase should keep these repo-level checks
truthful:

- `make test`
- `make docs`
