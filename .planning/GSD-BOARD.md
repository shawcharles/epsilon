# GSD Board — Epsilon MMM

> Master task board. Updated as work progresses.
> Status: 🔴 Not Started | 🟡 In Progress | 🟢 Done | ⏸️ Blocked

---

## Phase 1: Foundation 🟢

> Stabilize the package foundation, make the quality gate truthful, and align
> contributor-facing docs with the repo layout.

- [x] Initialize Julia package structure (`Project.toml`, `src/Epsilon.jl`, `test/`)
- [x] Add starter dependencies to `Project.toml` (test extras and current foundation requirements)
- [x] Set up code formatting with `Runic.jl`
- [x] Set up Documenter.jl for docs
- [x] Create `Makefile` with common commands
- [x] Establish module structure mirroring the architecture plan
- [x] Add `.gitignore` for Julia artifacts
- [x] Point contributor docs at `TECHNICAL-STANDARDS.md`
- [x] Make `make test` green locally (`Aqua.jl` stale-deps and compat findings)
- [x] Make `make docs` green locally (canonical API docs inclusion)
- [x] Create initial test fixtures (reference data exported from Abacus)

**Acceptance:** `make test` passes, `make docs` passes, and the repo is ready
to start transform work without foundation churn.

---

## Phase 2: Primitives 🟢

> Port the mathematical building blocks — adstock, saturation, convolution, scaling.

### 1a. Batched Convolution
- [x] Port `batched_convolution` (Overlap-Add and After modes)
- [x] Handle 1D, 2D, and 3D input shapes
- [x] Write parity tests against Abacus reference outputs

### 1b. Adstock Transforms
- [x] Port Geometric adstock (`α^t` kernel)
- [x] Port Delayed adstock (`α^((t-θ)²)` kernel)
- [x] Port Binomial adstock
- [x] Port Weibull adstock (PDF and CDF modes, with `cumprod` path)
- [x] Implement optional normalization (`w / sum(w)`)
- [x] Write parity tests for all 4 adstock types

### 1c. Saturation Transforms
- [x] Port Logistic saturation (`λ · sigmoid(μ · x) - λ · sigmoid(0)`)
- [x] Port Tanh saturation (`b · tanh(x / (b · c))`)
- [x] Port Michaelis-Menten saturation (`a · x / (x + K_m)`)
- [x] Port Hill saturation (parameterized Hill equation)
- [x] Write parity tests for all 4 saturation types

### 1d. Scaling & Preprocessing
- [x] Port `MaxAbsScaler` (target scaling)
- [x] Port channel normalization logic
- [x] Port data validation utilities

**Acceptance:** All transforms produce numerically identical outputs to Abacus (within floating-point tolerance).

---

## Phase 3: Priors & Distributions 🟢

> Port the prior specification system and custom distributions.

### 2a. Prior System
- [x] Design Julia prior struct (`EpsilonPrior` or similar)
- [x] Map PyMC distribution names → Distributions.jl equivalents
- [x] Implement prior deserialization from YAML/Dict config
- [ ] Handle `dims` (plate notation) mapping to Turing plates

### 2b. Special Priors
- [x] Port `MaskedPrior` (apply prior to subset using boolean mask)
- [x] Port current Abacus special priors used in config compatibility (`LogNormalPrior`, `LaplacePrior`)
- [x] Port custom distributions: `Scaled`, `SkewStudentT`
- [x] Decide that no separate Michaelis prior/distribution type is required beyond the already-ported Michaelis-Menten saturation path
- [x] Implement the Julia-side special-prior compatibility layer in `special.jl`
- [x] Port `Horseshoe` prior
- [x] Port `Finnish Horseshoe` prior
- [x] Port `R2D2` prior (shrinkage)

**Acceptance:** Supported prior configs deserialize and instantiate correctly,
and the helper math needed by the future model layer is validated. Dims-to-plate
mapping now rolls forward as a Phase 5 concern.

---

## Phase 4: Model Core 🟢

> The heart of the port — model builder, Turing @model macro, config system.

### 3a. Configuration System
- [x] Port `ModelConfig` (YAML-driven model specification)
- [x] Implement deterministic config merging (base defaults + YAML config + explicit overrides)
- [x] Port sampler config (chains, draws, target_accept, etc.)
- [x] YAML loading via `YAML.jl`

### 3b. Typed Model Types & Orchestration
- [x] Design Julia abstract type hierarchy:
  ```
  AbstractModel
    └── AbstractRegressionModel
          └── AbstractMMMModel
                └── TimeSeriesMMM
  ```
- [x] Implement builder/orchestration shell types for the base time-series MMM path
- [x] Implement `build_model` interface → returns a backend-agnostic MMM specification pending the later Turing `@model` layer
- [x] Implement `fit` interface → runs MCMC sampling for the minimal time-series MMM path
- [x] Implement `predict` interface → posterior predictive for the minimal time-series MMM path
- [x] Add typed coordinate metadata for the current time-series tensors

### 3c. Turing Model Specification
- [x] Translate the first base MMM path into a Turing `@model`
- [x] Map the initial data path to `@model` function arguments
- [x] Map posterior predictive generation to Turing's `predict` workflow
- [x] Run the first Turing-backed sample path in tests
- [x] Support the current minimal media runtime path:
  - [x] adstock: geometric, delayed, binomial, Weibull PDF/CDF
  - [x] saturation: logistic, tanh, Michaelis-Menten, hill
- [ ] Extend coordinate/dimension support beyond the current time-series metadata surface (defer broader plate work to Phase 5)

### 3d. Lifecycle, Results & Diagnostics
- [x] Implement model save/load for typed model artifacts and fitted chains
- [x] Implement typed results object and results save/load
- [x] Implement prior predictive path
- [x] Implement typed parameter diagnostics
- [x] Implement typed convergence report and warnings
- [x] Implement typed sampler diagnostics and warnings
- [x] Implement multi-chain execution mode selection (`single`, `serial`, `threads`)
- [x] Decide that richer grouped export moves to Phase 6 rather than expanding Phase 4

### 3e. Phase 4 Closeout
- [x] Create the first executable per-phase plan doc at `.planning/phases/04-model-core/PLAN.md`
- [x] Reconcile final Phase 4 exit criteria with the implemented model-core surface
- [x] Freeze the minimal supported Phase 4 contract before widening Phase 5/6 scope

**Acceptance:**
- Incremental checkpoint: can load YAML config, validate typed MMM data, and build a backend-agnostic model spec.
- Current capability: can run a minimal Turing-backed MMM, produce prior and posterior predictive output, persist typed model/results artifacts, and inspect typed diagnostics and warnings.
- Phase exit: current capabilities are documented honestly, and remaining feature/inference growth is handed off cleanly to Phases 5 and 6.

---

## Phase 5: Features 🟢

> Broaden the current minimal MMM into a practical feature surface without
> reopening Phase 4 model-core scope.

### 5a. Seasonality Baseline + HSGP Decision Gate
- [x] Add deterministic time-index / seasonal feature builders
- [x] Port Fourier seasonality baseline
- [x] Integrate Fourier seasonality into the current `TimeSeriesMMM` path
- [x] Resolve the HSGP strategy early in the phase
- [x] Record an ADR choosing the accepted bounded defer path
- [x] Freeze the supported `seasonality` config keys before 5b starts

### 5b. Trend, Events & Controls
- [x] Port linear trend component
- [x] Decide and bound the first supported time-varying trend path
- [x] Port the first bounded event-effect modeling path
- [x] Port holiday/event feature matrix generation
- [x] Broaden control-variable handling beyond the current minimal path
- [x] Document the supported keys for `trend`, `events`, and richer `controls`

### 5c. Panel & Hierarchical Structure
- [x] Port the first supported `PanelMMM` / hierarchical MMM path
- [x] Expand coordinate metadata and dims/plates beyond the current time-series surface
- [x] Implement hierarchical priors / group-level offsets
- [x] Handle panel indexing and data layout with synthetic panel tests
- [x] Keep `TimeSeriesMMM` as the single-series path during Phase 5

### 5d. Integration & Closeout
- [x] Land the accepted HSGP path or document the bounded defer outcome from 5a
- [x] Add feature-combination integration coverage for the supported Phase 5 surface
- [x] Reconcile docs and planning with the actual supported feature contract
- [x] Freeze the supported feature matrix, including unsupported combinations, before Phase 6 inference hardening

**Acceptance:** Can build and sample the supported Phase 5 MMM feature surface
truthfully, with:
- [x] explicit supported config keys
- [x] one documented feature-combination matrix
- [x] HSGP explicitly resolved
- [x] one supported small `PanelMMM` path
- [x] feature-combination coverage in place before Phase 6 begins

---

## Phase 6: Inference 🟢

> MCMC hardening, grouped inference export, bounded variational inference, closeout.

### 6a. MCMC Sampling
- [x] Harden the current `fit!`-backed NUTS workflow without inventing a second MCMC surface
- [x] Make warning versus failure behavior explicit, test-covered, and owned under `src/inference/`
- [x] Keep YAML `fit` config and `SamplerConfig` truthful across supported execution modes

### 6b. Grouped Results Export
- [x] Land the richer grouped inference export deferred from Phase 4 as the canonical `InferenceResults` surface
- [x] Group posterior/prior draws, predictive draws, sample stats, observed data, coordinates, and metadata under that one typed surface
- [x] Keep NetCDF / ArviZ-native interchange explicitly deferred from Phase 6

### 6c. Variational Inference
- [x] ADVI via `AdvancedVI.jl`
- [x] Add the explicit bounded VI entry point `approximate_fit!` plus `VariationalConfig` instead of hiding VI behind `fit!`
- [x] Keep the Phase 6 VI contract Julia-only and honest if it is time-series only

### 6d. Inference Closeout
- [x] Freeze the supported inference matrix across model type, backend, predictive path, and grouped export availability
- [x] Add one test-covered row per supported inference combination
- [x] Hand off post-model consumers cleanly to Phase 7 on top of `InferenceResults`

**Acceptance:** Supported inference workflows are documented honestly,
`InferenceResults` exists as the canonical grouped artifact surface, bounded VI
support is explicit through `approximate_fit!`, and diagnostics/failure
behavior are test-covered.

---

## Phase 7: Post-Modeling 🟢

> Contribution decomposition, response curves, business metrics, summary tables.

### 7a. Contributions And Decomposition
- [x] Create the `src/postmodel/` ownership layer and typed post-model output surfaces
- [x] Freeze deterministic replay from `InferenceResults.posterior` + observed data + spec instead of inventing a second artifact contract
- [x] Support additive time-series contributions in observed target units from canonical `InferenceResults`
- [x] Add contribution-share computation and waterfall decomposition on top of the same additive baseline

### 7b. Response Curves And Business Metrics
- [x] Add counterfactual response-curve computation for supported time-series media channels
- [x] Add ROAS, mROAS, CPA, and mCPA derived from the same response surface
- [x] Keep panel post-model outputs explicitly unsupported in the bounded Phase 7 surface

### 7c. Parity And Summary Tables
- [x] Add Abacus parity coverage for supported post-model outputs
- [x] Add DataFrame summary-table projections for typed post-model results
- [x] Hand off Phase 8 to the frozen Phase 7 response/metric surface rather than raw posterior reinvention

**Acceptance:** Supported time-series decomposition, response, and metric outputs
match Abacus on agreed fixtures for the same posterior draws while consuming
canonical `InferenceResults` instead of a parallel posterior/result format.

---

## Phase 8: Budget Optimization 🟢

> Fixed-budget time-series-first optimizer on top of the frozen Phase 7 response / metric surface.

- [x] Freeze the bounded optimization contract: fixed budget, posterior-mean response objective, and time-series-only support matrix
- [x] Use `JuMP.jl + Ipopt.jl` as the canonical constrained solver path
- [x] Support total-budget equality, per-channel absolute bounds, and reference-relative lower/upper spend guardrails
- [x] Add typed optimization result surfaces and optimizer orchestration
- [x] Add Abacus parity coverage plus comparison/audit outputs for the supported optimization surface

**Acceptance:** Supported time-series optimization outputs match Abacus on the
frozen Phase 8 fixture matrix within the defined Phase 8 tolerances while
consuming the frozen Phase 7 response/metric surface. Panel and pipeline
semantics remain explicitly out of scope for the closed Phase 8 surface.

---

## Phase 9: Pipeline 🟢

> Bounded YAML-driven runner over the frozen model, inference, post-model, and
> optimization contracts.

- [x] Freeze the Phase 9 support matrix as time-series-first and MCMC-only
- [x] Port `PipelineRunConfig`, `PipelineRunResult`, `PipelineStageRecord`, `PipelineValidationResult`, `PipelineContext`, and `run_manifest.json`
- [x] Freeze the combined CSV ingestion contract:
  - [x] required column mapping from YAML to `MMMData`
  - [x] uniform `Date` / `DateTime` parsing
  - [x] chronological sort before model construction
  - [x] duplicate-date rejection
- [x] Port runner-only YAML parsing for:
  - [x] `data.dataset_path`
  - [x] optional `validation`
  - [x] optional `optimization`
- [x] Freeze the manifest and sidecar schemas:
  - [x] `run_manifest.json`
  - [x] `dataset_metadata.json`
  - [x] `model_metadata.json`
  - [x] `posterior_summary.csv`
  - [x] `predictive_summary.csv`
  - [x] `warnings_summary.json`
- [x] Port Stage `00_run_metadata`
- [x] Port Stage `10_pre_diagnostics`
- [x] Port Stage `20_model_fit`
- [x] Port Stage `30_model_assessment`
- [x] Port Stage `35_holdout_validation` as a side branch that does not mutate Stage `20_model_fit`
- [x] Port Stage `40_decomposition`
- [x] Port Stage `50_diagnostics`
- [x] Port Stage `60_response_curves`
- [x] Port Stage `70_optimisation`
- [x] Port CLI interface (`epsilon run config.yaml`) through the same runner path and bounded runtime override set
- [x] Add end-to-end integration coverage for:
  - [x] successful full run without optimization
  - [x] successful full run with optimization
  - [x] skipped optional stages
  - [x] manifest failure semantics
  - [x] explicit panel / YAML-driven VI failure

**Acceptance:** `epsilon run` produces a structured results directory and
truthful manifest for the supported time-series MCMC workflow. CSV ingestion,
manifest/result schemas, and core sidecars are fixed and documented. Validation
and optimization skip honestly when absent or disabled, and validation does
not overwrite the full-sample fit branch. Panel and YAML-driven VI remain
explicitly unsupported in the closed Phase 9 surface.

---

## Phase 10: Plotting 🟢

> Static CairoMakie-based visualization layer over the closed inference,
> post-model, optimization, and pipeline artifact surfaces.

### 10a. Theme And Diagnostic Foundation
- [x] Land `src/plotting/theme.jl`
- [x] Land `src/plotting/diagnostics.jl`
- [x] Export `epsilon_theme`
- [x] Export `trace_plot`
- [x] Export `posterior_density_plot`
- [x] Export `prior_posterior_plot`
- [x] Export `observed_fitted_plot`
- [x] Export `residual_diagnostics_plot`
- [x] Add `test/plotting/diagnostics.jl`

### 10b. Post-Model Plots
- [x] Land `src/plotting/postmodel.jl`
- [x] Export `contribution_plot`
- [x] Export `contribution_area_plot`
- [x] Export `decomposition_plot`
- [x] Export `response_curve_plot`
- [x] Add `test/plotting/postmodel.jl`

### 10c. Optimization And Bundle Export
- [x] Land `src/plotting/optimization.jl`
- [x] Land `src/plotting/bundle.jl`
- [x] Export `budget_optimization_plot`
- [x] Export `write_plot_bundle`
- [x] Add `test/plotting/optimization.jl`
- [x] Add `test/plotting/bundle.jl`

**Acceptance:** The bounded Phase 10 plotting surface returns Makie `Figure`
objects, exports truthful static files, consumes the closed typed artifact
surfaces from Phases 6-9, remains explicitly smaller than the Abacus Dash
surface, keeps panel post-model/optimization plots and VI trace plots
unsupported, and treats `write_plot_bundle` as a post-hoc deterministic `png`
export helper over successful pipeline runs rather than a second pipeline
path.

---

## Phase 11: Validation & Benchmarks ✅

> Final release gate across parity, benchmarks, and v1.0 readiness.

### 11a. Final Parity Harness
- [x] Freeze the release-gate matrix:
  - [x] Abacus-comparable parity rows
  - [x] bounded Epsilon-only contract-validation rows
- [x] Add `scripts/export_abacus_validation_fixtures.py`
- [x] Add compact final fixtures under `test/fixtures/abacus/validation/`
- [x] Add `test/validation/` release-gate harness
- [x] Reconcile retained transform, post-model, and optimization parity fixtures into the final validation story

### 11b. Benchmarks
- [x] Add `benchmark/` runner and suite ownership
- [x] Measure transform micro-benchmarks
- [x] Measure representative fit / grouped-results / optimization / pipeline workflows
- [x] Publish environment and machine metadata with results
- [x] Document benchmark results honestly

### 11c. Release Readiness
- [x] Reconcile README and docs to the truthful release surface
- [x] Publish validation / benchmark methodology pages
- [x] Add v1.0.0-rc1 readiness checklist
- [x] Record known supported and unsupported rows explicitly

**Acceptance:** The supported Abacus-comparable v1 surface passes the final
parity harness, bounded Epsilon-only supported rows pass explicit
contract-regression checks, benchmark results are published honestly, and the
v1.0.0-rc1 readiness checklist is complete.

---

## Phase 12: Parity Remediation 🟢

> Repair the bounded time-series methodology gap revealed by the targeted audit
> before any release branch or tag resumes.

- [x] Implement Abacus-matching channel/target scaling on the comparable
      time-series fit path
- [x] Carry explicit scale state through specs, grouped artifacts, and runtime
- [x] Rebuild original-scale predictive/contribution outputs on top of the
      corrected scaled model space
- [x] Add the missing Stage 60 curve families: saturation-only, forward-pass,
      and adstock
- [x] Realign Stage 70 optimization semantics with the corrected
      model-space/curve contract
- [x] Reconcile the runnable demo with Abacus holiday/component methodology
- [x] Re-run validation and reconcile release-facing docs only after the
      repaired parity evidence exists

**Acceptance:** The guaranteed Abacus-reference row is again a truthful
Abacus-reference surface rather than a release claim resting on different
model-space semantics, and the holiday-bearing row is documented honestly as a
bounded Epsilon-native/reference row.

---

## Phase 13: Prediction-State and Contract Remediation 🔴

> Repair concrete external code-review findings before release branch or tag
> work resumes.

- [ ] Freeze fitted feature-state contract for trend and holiday replay
- [ ] Persist and reuse fitted trend normalization/basis state in prediction,
      grouped results, deterministic replay, validation, and save/load paths
- [ ] Persist and reuse fitted holiday calendar-period exposure state for
      holdout prediction and replay
- [ ] Enforce one nonnegative media-domain contract across direct APIs,
      transforms, prediction, and pipeline validation
- [ ] Reject unknown top-level pipeline YAML keys that could silently bypass
      intended behavior
- [ ] Re-run focused regressions plus `make test`, `make docs`, and
      `make format-check`

**Acceptance:** Trend and holiday prediction/replay use fitted state rather
than `new_data`-local state, invalid negative media and unsupported pipeline
keys fail deterministically, docs and artifacts reflect the repaired contract,
and release prep is either unblocked or a new blocker is recorded explicitly.

---

## Stretch Goals 🔴

- [ ] Interactive model explorer (Dash.jl or Genie.jl equivalent of scenario planner)
- [ ] GPU-accelerated sampling (CUDA.jl + Turing)
- [ ] Distributed panel fitting across multiple machines
- [ ] Python interop layer (PythonCall.jl) for gradual migration
- [ ] R interop (RCall.jl) for stakeholders using R
