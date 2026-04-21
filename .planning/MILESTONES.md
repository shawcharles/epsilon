# Milestones — Epsilon MMM

> Phase definitions, acceptance criteria, and estimated timelines.

---

## Overview

```
M1 ──── M2 ──── M3 ──── M4 ──── M5 ──── M6 ──── M7 ──── M8 ──── M9 ──── M10 ──── M11
Found.  Prims   Prior   Core    Feat    Infer   Post    Optim   Pipe    Plot     Valid
~1wk    ~1wk    ~1wk    ~2wk    ~2wk    ~1wk    ~1wk    ~1wk    ~2wk    ~1.5wk   ~1wk
                                                                                 ────
                                                                          Total: ~14-16 weeks
```

---

## M1: Foundation ⏱️ ~1 week

**Goal:** Runnable Julia package with CI, passing quality gates, docs scaffold,
and aligned contributor standards.

**Deliverables:**
- [x] Canonical contributor docs point to `TECHNICAL-STANDARDS.md`
- [x] `Project.toml` compat and dependency declarations match actual use
- [x] `src/Epsilon.jl` and `test/runtests.jl` form a passing baseline package
- [x] GitHub Actions CI validates Julia 1.10 + 1.11, docs, and formatting
- [x] Runic formatting check is enforced consistently
- [x] `Makefile` targets are truthful and pass locally
- [x] `.gitignore` covers Julia and docs artifacts
- [x] Documenter.jl docs build cleanly with canonical API docs included

**Acceptance:** `make test` green. `make docs` green. CI green.

**Tag:** `v0.0.1-dev`

---

## M2: Primitives ⏱️ ~1 week

**Goal:** All mathematical transforms ported and parity-tested.

**Deliverables:**
- [x] `src/transforms/convolution.jl` — batched convolution (both modes)
- [x] `src/transforms/adstock.jl` — 4 adstock types + normalization
- [x] `src/transforms/saturation.jl` — 4 saturation types
- [x] `src/transforms/scaling.jl` — scaling, normalization, and validation helpers
- [x] `test/transforms/` — parity tests against Abacus reference arrays
- [x] `test/fixtures/` — reference data exported from Abacus

**Acceptance:** All transforms match Abacus output within `atol=1e-10, rtol=1e-8`.

**Tag:** `v0.1.0-dev`

---

## M3: Priors & Distributions ⏱️ ~1 week

**Goal:** Complete the prior specification system and the custom/shrinkage prior recipes required by the port.

**Deliverables:**
- [x] `src/distributions/priors.jl` — `EpsilonPrior` struct, config deserialization
- [x] `src/distributions/special.jl` — special-prior compatibility plus `Scaled` and `SkewStudentT`; no separate Michaelis distribution is required
- [x] `src/distributions/shrinkage.jl` — Horseshoe, Finnish Horseshoe, R2D2
- [x] `src/distributions/masked.jl` — MaskedPrior
- [x] Distribution name mapping (PyMC → Distributions.jl, handling parameterization differences)
- [x] Tests for all currently supported distributions and prior recipes: config deserialization, instantiation, serialization, and helper-math checks

**Acceptance:** Supported prior configs deserialize correctly, Julia-side distribution instantiation is well-tested, and shrinkage/helper formulas are validated for the eventual model layer.

**Tag:** `v0.2.0-dev`

---

## M4: Model Core ⏱️ ~2 weeks

**Goal:** Working model builder with Turing `@model`, YAML config, and basic regression.

**Deliverables:**
- [x] `src/model/types.jl` — `AbstractModel` hierarchy, `ModelConfig`, `SamplerConfig`, `MMMData`
- [ ] `src/model/config.jl` — YAML loading landed; config merging remains
- [ ] `src/model/builder.jl` — builder/orchestration interfaces landed, but `fit!` and `predict` still defer execution until the Turing backend exists
- [ ] `src/model/io.jl` — save/load via JLD2
- [ ] `src/mmm/model.jl` — basic Turing `@model` for time-series MMM
- [ ] `src/mmm/media.jl` — media channel component (adstock → saturation → scale)
- [ ] Integration test: build + sample a simple 3-channel MMM on synthetic data

**Acceptance:** Can load YAML config, build model, run NUTS, get posterior chains. Chains mix well (R-hat < 1.05).

**Tag:** `v0.3.0-dev`

---

## M5: Features ⏱️ ~2 weeks

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

## M6: Inference ⏱️ ~1 week

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

## M7: Post-Modeling ⏱️ ~1 week

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

## M8: Budget Optimization ⏱️ ~1 week

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

## M9: Pipeline ⏱️ ~2 weeks

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

## M10: Plotting ⏱️ ~1.5 weeks

**Goal:** Julia-native visualizations and report artifacts for core MMM outputs,
without reproducing the Abacus Dash app.

**Deliverables:**
- [ ] `src/plotting/` — core plot types needed for diagnostics and analyst
      outputs
- [ ] Epsilon visual theme (consistent colours, fonts, styling)
- [ ] Contribution time series with HDI bands
- [ ] Waterfall decomposition
- [ ] Response curves
- [ ] Diagnostics (trace, posterior, residuals)
- [ ] Budget optimization comparison
- [ ] Optional lightweight static report/export layer in place of Dash parity

**Acceptance:** Core plots render correctly and support interpretation of model
results. No Plotly Dash parity is required for milestone completion.

**Tag:** `v0.9.0-dev`

---

## M11: Validation & Benchmarks ⏱️ ~1 week

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
- All 11 milestones achieved ✅
- CI green on Julia 1.10 + 1.11 ✅
- Documentation complete with examples ✅
- At least one real-world dataset tested ✅
- No known regressions vs Abacus ✅
- Performance benchmarks published ✅
