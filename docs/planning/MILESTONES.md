# Milestones — Epsilon MMM

> Phase definitions, acceptance criteria, and estimated timelines.

---

## Overview

```
M0 ──── M1 ──── M2 ──── M3 ──── M4 ──── M5 ──── M6 ──── M7 ──── M8 ──── M9 ──── M10
Found.  Prims   Prior   Core    Feat    Infer   Post    Optim   Pipe    Plot    Valid
~1wk    ~1wk    ~1wk    ~2wk    ~2wk    ~1wk    ~1wk    ~1wk    ~2wk    ~1.5wk  ~1wk
                                                                                 ────
                                                                          Total: ~14-16 weeks
```

---

## M0: Foundation ⏱️ ~1 week

**Goal:** Runnable Julia package with CI, tests, docs scaffold, and coding standards.

**Deliverables:**
- [ ] `Project.toml` with Phase 0 dependencies (DataFrames, CSV, Statistics, Test)
- [ ] `src/Epsilon.jl` — package entry point with module structure
- [ ] `test/runtests.jl` — test harness that passes
- [ ] GitHub Actions CI: test on Julia 1.10 + 1.11
- [ ] `.JuliaFormatter.toml` for consistent code style
- [ ] `Makefile` with `test`, `format`, `docs` targets
- [ ] `.gitignore` for Julia artifacts
- [ ] Documenter.jl docs skeleton

**Acceptance:** `] test Epsilon` green. CI green. `make docs` builds.

**Tag:** `v0.0.1-dev`

---

## M1: Primitives ⏱️ ~1 week

**Goal:** All mathematical transforms ported and parity-tested.

**Deliverables:**
- [ ] `src/transforms/convolution.jl` — batched convolution (both modes)
- [ ] `src/transforms/adstock.jl` — 4 adstock types + normalization
- [ ] `src/transforms/saturation.jl` — 4 saturation types
- [ ] `src/transforms/scaling.jl` — MaxAbsScaler
- [ ] `test/transforms/` — parity tests against Abacus reference arrays
- [ ] `test/fixtures/` — reference data exported from Abacus

**Acceptance:** All transforms match Abacus output within `atol=1e-10, rtol=1e-8`.

**Tag:** `v0.1.0-dev`

---

## M2: Priors & Distributions ⏱️ ~1 week

**Goal:** Complete prior specification system with all standard and custom distributions.

**Deliverables:**
- [ ] `src/distributions/priors.jl` — `EpsilonPrior` struct, YAML deserialization
- [ ] `src/distributions/special.jl` — Scaled, SkewStudentT, Michaelis
- [ ] `src/distributions/shrinkage.jl` — Horseshoe, Finnish Horseshoe, R2D2
- [ ] `src/distributions/masked.jl` — MaskedPrior
- [ ] Distribution name mapping (PyMC → Distributions.jl, handling parameterization differences)
- [ ] Tests for all distributions: `rand`, `logpdf`, moment checks

**Acceptance:** All priors sample correctly. logpdf matches PyMC for same parameters.

**Tag:** `v0.2.0-dev`

---

## M3: Model Core ⏱️ ~2 weeks

**Goal:** Working model builder with Turing `@model`, YAML config, and basic regression.

**Deliverables:**
- [ ] `src/model/types.jl` — `AbstractModel` hierarchy, `ModelConfig`, `SamplerConfig`, `MMMData`
- [ ] `src/model/config.jl` — YAML loading, config merging
- [ ] `src/model/builder.jl` — `build_model`, `fit!`, `predict` interfaces
- [ ] `src/model/io.jl` — save/load via JLD2
- [ ] `src/mmm/model.jl` — basic Turing `@model` for time-series MMM
- [ ] `src/mmm/media.jl` — media channel component (adstock → saturation → scale)
- [ ] Integration test: build + sample a simple 3-channel MMM on synthetic data

**Acceptance:** Can load YAML config, build model, run NUTS, get posterior chains. Chains mix well (R-hat < 1.05).

**Tag:** `v0.3.0-dev`

---

## M4: Features ⏱️ ~2 weeks

**Goal:** All MMM features: seasonality, trend, events, controls, panel/hierarchical.

**Deliverables:**
- [ ] `src/mmm/seasonality.jl` — Fourier features
- [ ] `src/mmm/hsgp.jl` — HSGP seasonality (high risk — spike early)
- [ ] `src/mmm/trend.jl` — linear trend + TVP
- [ ] `src/mmm/events.jl` — holiday/event effects
- [ ] `src/mmm/controls.jl` — control variable regression
- [ ] `src/mmm/panel.jl` — PanelMMM with hierarchical priors
- [ ] Integration test: full-featured MMM with all components

**Acceptance:** Can fit a panel MMM with Fourier seasonality, trend, events, controls, and media channels. Posterior makes statistical sense.

**Tag:** `v0.4.0-dev`

---

## M5: Inference ⏱️ ~1 week

**Goal:** Robust sampling wrapper, VI support, predictive checks, diagnostics.

**Deliverables:**
- [ ] `src/inference/mcmc.jl` — NUTS wrapper with config-driven parameters
- [ ] `src/inference/vi.jl` — ADVI via AdvancedVI
- [ ] `src/inference/predictive.jl` — prior/posterior predictive sampling
- [ ] `src/inference/diagnostics.jl` — R-hat, ESS, divergence warnings
- [ ] Multi-chain parallel sampling (MCMCThreads)

**Acceptance:** Sampling from YAML config. Diagnostics correctly flag poorly-mixed chains. Prior/posterior predictive generates valid samples.

**Tag:** `v0.5.0-dev`

---

## M6: Post-Modeling ⏱️ ~1 week

**Goal:** Contribution decomposition, response curves, and all marketing metrics.

**Deliverables:**
- [ ] `src/postmodel/contributions.jl` — channel contributions, shares
- [ ] `src/postmodel/response_curves.jl` — counterfactual response computation
- [ ] `src/postmodel/metrics.jl` — ROAS, mROAS, CPA, mCPA
- [ ] `src/postmodel/decomposition.jl` — waterfall decomposition
- [ ] `src/postmodel/summary.jl` — summary table generation
- [ ] Parity tests against Abacus decomposition outputs

**Acceptance:** Contributions and metrics match Abacus for same posterior draws (within 1e-6).

**Tag:** `v0.6.0-dev`

---

## M7: Budget Optimization ⏱️ ~1 week

**Goal:** Working budget optimizer with constraints via JuMP.

**Deliverables:**
- [ ] `src/optimization/optimizer.jl` — BudgetOptimizer
- [ ] `src/optimization/constraints.jl` — budget, bounds, ratio constraints
- [ ] `src/optimization/objective.jl` — maximize response, maximize ROAS
- [ ] Integration with JuMP + Ipopt
- [ ] Parity test: same optimal allocation as Abacus

**Acceptance:** Optimizer finds correct allocation. Handles all constraint types. Results match Abacus within tolerance.

**Tag:** `v0.7.0-dev`

---

## M8: Pipeline ⏱️ ~2 weeks

**Goal:** End-to-end YAML-driven pipeline matching Abacus's 9-stage workflow.

**Deliverables:**
- [ ] `src/pipeline/` — all stages (00–60)
- [ ] `src/pipeline/runner.jl` — orchestrator with timing and error handling
- [ ] `src/pipeline/cli.jl` — `epsilon run config.yaml` CLI
- [ ] Output directory structure matching Abacus
- [ ] Full integration test: run pipeline on test dataset

**Acceptance:** `epsilon run` produces complete, correct results directory. All stages execute in order.

**Tag:** `v0.8.0-dev`

---

## M9: Plotting ⏱️ ~1.5 weeks

**Goal:** All visualizations ported to Makie.jl.

**Deliverables:**
- [ ] `src/plotting/` — all plot types
- [ ] Epsilon visual theme (consistent colours, fonts, styling)
- [ ] Contribution time series with HDI bands
- [ ] Waterfall decomposition
- [ ] Response curves
- [ ] Diagnostics (trace, posterior, residuals)
- [ ] Budget optimization comparison

**Acceptance:** All plots render correctly. Visual output is publication-quality.

**Tag:** `v0.9.0-dev`

---

## M10: Validation & Benchmarks ⏱️ ~1 week

**Goal:** Numerical parity confirmed. Performance benchmarked and documented.

**Deliverables:**
- [ ] Full parity test suite (transforms, log-prob, posteriors, metrics)
- [ ] Performance benchmarks (sampling time, ESS/sec, pipeline wall-clock)
- [ ] Memory usage comparison
- [ ] Benchmark results documentation
- [ ] Final README with usage examples

**Acceptance:** All parity tests pass. Epsilon is faster than Abacus on all benchmarks. Documentation is complete.

**Tag:** `v1.0.0-rc1`

---

## Release: v1.0.0

**Criteria for v1.0:**
- All 10 milestones achieved ✅
- CI green on Julia 1.10 + 1.11 ✅
- Documentation complete with examples ✅
- At least one real-world dataset tested ✅
- No known regressions vs Abacus ✅
- Performance benchmarks published ✅
