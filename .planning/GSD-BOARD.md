# GSD Board — Epsilon MMM

> Master task board. Updated as work progresses.
> Status: 🔴 Not Started | 🟡 In Progress | 🟢 Done | ⏸️ Blocked

---

## Phase 0: Foundation 🔴

> Scaffold the Julia project, set up CI, establish coding standards.

- [ ] Initialize Julia package structure (`Project.toml`, `src/Epsilon.jl`, `test/`)
- [ ] Add core dependencies to `Project.toml` (Turing, Distributions, DataFrames, etc.)
- [ ] Set up GitHub Actions CI (Julia test matrix: 1.10 LTS + 1.11+)
- [ ] Set up code formatting (JuliaFormatter.jl)
- [ ] Set up Documenter.jl for docs
- [ ] Create `Makefile` with common commands (test, format, docs, benchmark)
- [ ] Establish module structure mirroring architecture plan
- [ ] Add `.gitignore` for Julia artifacts
- [ ] Create initial test fixtures (reference data exported from Abacus)

**Acceptance:** `] test Epsilon` passes, CI green, docs build.

---

## Phase 1: Primitives 🔴

> Port the mathematical building blocks — adstock, saturation, convolution, scaling.

### 1a. Batched Convolution
- [ ] Port `batched_convolution` (Overlap-Add and After modes)
- [ ] Handle 1D, 2D, and 3D input shapes
- [ ] Write parity tests against Abacus reference outputs

### 1b. Adstock Transforms
- [ ] Port Geometric adstock (`α^t` kernel)
- [ ] Port Delayed adstock (`α^((t-θ)²)` kernel)
- [ ] Port Binomial adstock
- [ ] Port Weibull adstock (PDF and CDF modes, with `cumprod` path)
- [ ] Implement optional normalization (`w / sum(w)`)
- [ ] Write parity tests for all 4 adstock types

### 1c. Saturation Transforms
- [ ] Port Logistic saturation (`λ · sigmoid(μ · x) - λ · sigmoid(0)`)
- [ ] Port Tanh saturation (`b · tanh(x / (b · c))`)
- [ ] Port Michaelis-Menten saturation (`a · x / (x + K_m)`)
- [ ] Port Hill saturation (parameterized Hill equation)
- [ ] Write parity tests for all 4 saturation types

### 1d. Scaling & Preprocessing
- [ ] Port `MaxAbsScaler` (target scaling)
- [ ] Port channel normalization logic
- [ ] Port data validation utilities

**Acceptance:** All transforms produce numerically identical outputs to Abacus (within floating-point tolerance).

---

## Phase 2: Priors & Distributions 🔴

> Port the prior specification system and custom distributions.

### 2a. Prior System
- [ ] Design Julia prior struct (`EpsilonPrior` or similar)
- [ ] Map PyMC distribution names → Distributions.jl equivalents
- [ ] Implement prior deserialization from YAML/Dict config
- [ ] Handle `dims` (plate notation) mapping to Turing plates

### 2b. Special Priors
- [ ] Port `MaskedPrior` (apply prior to subset using boolean mask)
- [ ] Port custom distributions: `Scaled`, `SkewStudentT`, `Michaelis`
- [ ] Implement `SpecialPriorRegistry` pattern in Julia (type dispatch)
- [ ] Port `Horseshoe` prior
- [ ] Port `Finnish Horseshoe` prior
- [ ] Port `R2D2` prior (shrinkage)

**Acceptance:** All priors sample correctly, match Abacus distribution shapes.

---

## Phase 3: Model Core 🔴

> The heart of the port — model builder, Turing @model macro, config system.

### 3a. Configuration System
- [ ] Port `ModelConfig` (YAML-driven model specification)
- [ ] Implement config merging (defaults + user overrides)
- [ ] Port sampler config (chains, draws, target_accept, etc.)
- [ ] YAML loading via `YAML.jl`

### 3b. Abstract Model Types
- [ ] Design Julia abstract type hierarchy:
  ```
  AbstractModelBuilder
    └── AbstractRegressionModel
          └── AbstractMMMModel
                └── PanelMMM
  ```
- [ ] Implement `build_model` interface → returns Turing `@model` function
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

## Phase 4: Features 🔴

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

## Phase 5: Inference 🔴

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

## Phase 6: Post-Modeling 🔴

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

## Phase 7: Budget Optimization 🔴

> Port the budget optimizer and constraint system.

- [ ] Port budget optimization objective function
- [ ] Map `scipy.optimize.minimize(method='SLSQP')` → `Optim.jl` or `JuMP.jl`
- [ ] Port constraint types: budget equality, per-channel bounds, ratio constraints
- [ ] Port `BudgetOptimizer` orchestrator
- [ ] Port multi-objective optimization (ROAS vs CPA trade-offs)
- [ ] Port `allocated_response` computation

**Acceptance:** Optimizer finds same optimal allocations as Abacus (within tolerance).

---

## Phase 8: Pipeline 🔴

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

## Phase 9: Plotting 🔴

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

## Phase 10: Validation & Benchmarks 🔴

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
