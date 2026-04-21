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
- [x] Implement `SpecialPriorRegistry` pattern in Julia (type dispatch)
- [x] Port `Horseshoe` prior
- [x] Port `Finnish Horseshoe` prior
- [x] Port `R2D2` prior (shrinkage)

**Acceptance:** Supported prior configs deserialize and instantiate correctly,
and the helper math needed by the future model layer is validated. Dims-to-plate
mapping remains a Phase 4 concern.

---

## Phase 4: Model Core 🟡

> The heart of the port — model builder, Turing @model macro, config system.

### 3a. Configuration System
- [x] Port `ModelConfig` (YAML-driven model specification)
- [ ] Implement config merging (defaults + user overrides)
- [x] Port sampler config (chains, draws, target_accept, etc.)
- [x] YAML loading via `YAML.jl`

### 3b. Abstract Model Types
- [x] Design Julia abstract type hierarchy:
  ```
  AbstractModelBuilder
    └── AbstractRegressionModel
          └── AbstractMMMModel
                └── PanelMMM
  ```
- [x] Implement builder/orchestration shell types for the base time-series MMM path
- [x] Implement `build_model` interface → returns a backend-agnostic MMM specification pending the later Turing `@model` layer
- [ ] Implement `fit` interface → runs MCMC sampling
- [ ] Implement `predict` interface → posterior predictive

### 3c. Turing Model Specification
- [ ] Translate `pm.Model()` context manager → Turing `@model` macro
- [ ] Map `pm.MutableData` → function arguments in `@model`
- [ ] Map `pm.Deterministic` → tracking via `Turing.@addlogprob!` or returned values
- [ ] Map `pm.sample()` → `Turing.sample(model, NUTS(), MCMCThreads(), N, chains)`
- [ ] Handle coordinate/dimension system (PyMC dims → Turing plate indexing)

### 3d. IO & Serialization
- [ ] Implement model save/load (JLSO.jl or JLD2.jl)
- [ ] Port InferenceData concept → MCMCChains.Chains + metadata dict
- [ ] Implement results export (CSV, NetCDF)

**Acceptance:** Can specify, sample, and save a basic regression model via YAML config.

---

## Phase 5: Features 🔴

> Port all MMM-specific modeling features.

### 4a. Seasonality
- [ ] Port Fourier seasonality (sin/cos pairs for yearly/weekly)
- [ ] Port HSGP (Hilbert Space Gaussian Process) seasonality
  - [ ] Evaluate: use `AbstractGPs.jl` + custom HSGP, or port manually
  - [ ] Implement spectral density computation
  - [ ] Implement basis function construction

### 4b. Trend
- [ ] Port linear trend component (intercept + slope · time_index)
- [ ] Port time-varying parameters (TVP) — random walk / GP-based

### 4c. Events & Holidays
- [ ] Port event/holiday effect modeling
- [ ] Port holiday feature matrix generation from CSV

### 4d. Panel Data
- [ ] Port `PanelMMM` — multi-geo / multi-brand hierarchical model
- [ ] Implement hierarchical priors (group-level + geo-level offsets)
- [ ] Handle panel indexing and data layout

### 4e. Controls & Additive Effects
- [ ] Port control variable handling (linear regression on controls)
- [ ] Port additive effect component

**Acceptance:** Can build and sample a full-featured MMM with seasonality + trend + events + media channels.

---

## Phase 6: Inference 🔴

> Sampling, variational inference, predictive checks, diagnostics.

### 5a. MCMC Sampling
- [ ] NUTS sampling via `Turing.sample(NUTS(), ...)`
- [ ] Multi-chain parallel sampling (`MCMCThreads()` or `MCMCDistributed()`)
- [ ] Sampler configuration from YAML (draws, chains, target_accept, init)

### 5b. Variational Inference
- [ ] ADVI via `AdvancedVI.jl`
- [ ] Port `approximate_fit()` workflow

### 5c. Predictive Sampling
- [ ] Prior predictive: `predict(model, prior_chain)`
- [ ] Posterior predictive: `predict(model, posterior_chain)`

### 5d. Diagnostics
- [ ] R-hat, ESS, MCSE via `MCMCDiagnosticTools.jl`
- [ ] Divergence detection
- [ ] Port convergence warning system

**Acceptance:** MCMC produces well-mixed chains; diagnostics flag issues correctly.

---

## Phase 7: Post-Modeling 🔴

> Contribution decomposition, response curves, attribution.

- [ ] Port channel contribution extraction
- [ ] Port `compute_mean_contributions_over_time` (wide DataFrame)
- [ ] Port contribution share computation (percentage attribution)
- [ ] Port response curve computation (counterfactual spend → response)
- [ ] Port ROAS/mROAS/CPA/mCPA metrics
- [ ] Port waterfall decomposition
- [ ] Port inverse-scaling (contributions back to original target scale)

**Acceptance:** Decomposition and metrics match Abacus outputs for identical model fits.

---

## Phase 8: Budget Optimization 🔴

> Port the budget optimizer and constraint system.

- [ ] Port budget optimization objective function
- [ ] Map `scipy.optimize.minimize(method='SLSQP')` → `Optim.jl` or `JuMP.jl`
- [ ] Port constraint types: budget equality, per-channel bounds, ratio constraints
- [ ] Port `BudgetOptimizer` orchestrator
- [ ] Port multi-objective optimization (ROAS vs CPA trade-offs)
- [ ] Port `allocated_response` computation

**Acceptance:** Optimizer finds same optimal allocations as Abacus (within tolerance).

---

## Phase 9: Pipeline 🔴

> YAML-driven end-to-end pipeline (9 stages).

- [ ] Port pipeline config loading (YAML.jl)
- [ ] Port `PipelineContext` and `PipelineManifest`
- [ ] Port Stage 00: Metadata
- [ ] Port Stage 10: Preflight (prior predictive)
- [ ] Port Stage 20: Fit (MCMC sampling)
- [ ] Port Stage 30: Assessment (in-sample fit quality)
- [ ] Port Stage 35: Validation (blocked holdout)
- [ ] Port Stage 40: Decomposition
- [ ] Port Stage 50: Optimization
- [ ] Port Stage 60: Report (summary artifacts)
- [ ] Port CLI interface (`epsilon run config.yaml`)

**Acceptance:** `epsilon run` produces a complete results directory matching Abacus pipeline output.

---

## Phase 10: Plotting 🔴

> Visualization layer using Makie.jl.

- [ ] Port channel contribution time series plot (with HDI bands)
- [ ] Port waterfall decomposition plot
- [ ] Port response curves plot
- [ ] Port trace/posterior plots
- [ ] Port prior vs posterior comparison
- [ ] Port observed vs fitted time series
- [ ] Port residual diagnostics (histogram, Q-Q, residuals vs fitted)
- [ ] Port budget optimization comparison plots
- [ ] Port stacked area contribution breakdown

**Acceptance:** All plots render correctly and are publication-quality.

---

## Phase 11: Validation & Benchmarks 🔴

> Ensure numerical parity with Abacus; benchmark performance gains.

- [ ] Create reference test suite: run Abacus on test datasets, export all intermediates
- [ ] Numerical parity tests for transforms (adstock, saturation) — max |Δ| < 1e-10
- [ ] Numerical parity for model log-probability evaluation
- [ ] Statistical parity for posterior samples (same posterior means ± sampling noise)
- [ ] Performance benchmarks: Abacus vs Epsilon on identical model/data
  - [ ] Model build time
  - [ ] MCMC sampling time (wall clock, ESS/sec)
  - [ ] Budget optimization time
  - [ ] End-to-end pipeline time
- [ ] Memory usage comparison
- [ ] Document benchmark results

**Acceptance:** Epsilon is numerically correct AND measurably faster than Abacus.

---

## Stretch Goals 🔴

- [ ] Interactive model explorer (Dash.jl or Genie.jl equivalent of scenario planner)
- [ ] GPU-accelerated sampling (CUDA.jl + Turing)
- [ ] Distributed panel fitting across multiple machines
- [ ] Python interop layer (PythonCall.jl) for gradual migration
- [ ] R interop (RCall.jl) for stakeholders using R
