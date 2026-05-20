# Architecture — Epsilon MMM

> System architecture for the Julia port of Abacus.

---

## Design Principles

1. **Julia-native** — Don't just transliterate Python. Use Julia idioms: multiple dispatch, parametric types, broadcasting, macros where appropriate.
2. **Composition over inheritance** — Python Abacus uses deep class hierarchies. Julia favours composition via types and dispatch.
3. **Autodiff-friendly** — All transforms and model code must work with `ForwardDiff.jl` and `ReverseDiff.jl` (Turing's backends). No in-place mutation in hot paths.
4. **Test-driven parity** — Every component has reference tests against Abacus outputs.
5. **Modular and layered** — Each layer is independently usable and testable.

---

## Module Structure

The lists below distinguish the files that exist today from modules that are
planned for later phases. Do not treat planned files as implemented code.

### Implemented Today

```
Epsilon.jl                          # Main module
├── src/
│   ├── Epsilon.jl                  # Package entry point, exports
│   │
│   ├── transforms/                 # Layer 1: Mathematical primitives
│   │   ├── adstock.jl              # Geometric, Delayed, Binomial, Weibull
│   │   ├── saturation.jl           # Logistic, Tanh, Michaelis-Menten, Hill
│   │   ├── convolution.jl          # batched_convolution
│   │   └── scaling.jl              # MaxAbsScaler, normalization
│   │
│   ├── distributions/              # Layer 2: Prior & distribution system
│   │   ├── priors.jl               # EpsilonPrior, prior specification
│   │   ├── special.jl              # Scaled, SkewStudentT, special-prior helpers
│   │   ├── shrinkage.jl            # Horseshoe, Finnish Horseshoe, R2D2
│   │   ├── masked.jl               # MaskedPrior
│   │
│   ├── model/                      # Layer 3: Model specification core
│   │   ├── types.jl                # Abstract types, ModelConfig, SamplerConfig
│   │   ├── config.jl               # YAML config loading
│   │   ├── builder.jl              # Typed builders, specs, fit state
│   │   ├── io.jl                   # Model artifact save/load
│   │   ├── results.jl              # Typed results surface
│   │   └── diagnostics.jl          # Typed diagnostics and warnings
│   │
│   ├── mmm/                        # Layer 4: Current runnable MMM path
│   │   ├── seasonality.jl          # Fourier seasonality basis builders
│   │   ├── trend.jl                # Linear and changepoint trend helpers
│   │   ├── events.jl               # Manual and generated event matrices
│   │   ├── controls.jl             # Richer control-matrix handling
│   │   ├── media.jl                # Deterministic media transform chain
│   │   ├── model.jl                # Bounded Turing-backed TimeSeriesMMM
│   │   └── panel.jl                # Bounded Turing-backed PanelMMM
│
├── test/
│   ├── runtests.jl                 # Test entry point
│   ├── transforms/                 # Parity tests for transforms
│   ├── distributions/              # Prior/distribution tests
│   ├── model/                      # Model builder tests
│   └── fixtures/                    # Reference data from Abacus
│
├── docs/                            # Documenter.jl docs
├── Project.toml                     # Julia package manifest
├── Makefile                         # Common commands
└── README.md
```

### Landed In Phase 6

Phase 6 established a settled module-ownership target for new inference work.
Some inference-adjacent behavior still lives under `src/model/` and `src/mmm/`
for the bounded runnable backend, but the canonical Phase 6 inference layer now
lands under:

- `src/inference/`
  - `mcmc.jl` — canonical MCMC wrapper and execution-policy ownership
  - `diagnostics.jl` — warning/failure taxonomy and diagnostics ownership
  - `results.jl` — grouped `InferenceResults` surface and persistence helpers
  - `vi.jl` — explicit VI API and `VariationalConfig`
- `test/inference/`

### Phase 8 Landed

Phase 8 landed under:

- `src/optimization/`
  - `types.jl` — typed optimization result and config/constraint surfaces
  - `objective.jl` — budget-allocation objective ownership on top of the frozen Phase 7 response surface
  - `constraints.jl` — supported budget, bound, and reference-relative guardrail primitives
  - `optimizer.jl` — orchestration / solver-facing optimization ownership
  - `summary.jl` — comparison and audit projections over `BudgetOptimizationResult`
- `test/optimization/`

Phase 8 must consume the frozen Phase 7 response and metric surfaces directly.
It should not re-derive business outputs from raw posterior artifacts or reopen
post-model semantics.

The canonical planned Phase 8 entry points are:

- `optimize_budget(results::InferenceResults; total_budget, channels=nothing, budget_bounds=nothing, relative_bounds=nothing, objective=:total_response, grid=nothing)`
- `BudgetOptimizationResult`
- `budget_impact_table(result::BudgetOptimizationResult)`
- `budget_audit_table(result::BudgetOptimizationResult)`

### Phase 9 Landed

Phase 9 landed under:

- `src/pipeline/`
  - `config.jl` — YAML-driven pipeline config ownership, combined CSV ingestion rules, and runner-only validation
  - `context.jl` — typed pipeline context, `PipelineRunResult` / `PipelineStageRecord`, and manifest ownership
  - `stages.jl` — ordered pipeline stage ownership built on the closed Phases 6-8 surfaces:
    - `00_run_metadata`
    - `10_pre_diagnostics`
    - `20_model_fit`
    - `30_model_assessment`
    - `35_holdout_validation`
    - `40_decomposition`
    - `50_diagnostics`
    - `60_response_curves`
    - `70_optimisation`
  - `run.jl` — orchestration entry point with full-sample mainline ownership and a separate holdout-validation branch
  - `cli.jl` — `pipeline_main(args = ARGS)` and CLI parsing over the same `run_pipeline` path
- `bin/epsilon` — thin repo wrapper for `epsilon run config.yml`
- `test/pipeline/`

The bounded Phase 9 contract is now fixed as:

- time-series first
- MCMC-only
- one combined CSV dataset path with fixed date parsing, chronological sorting,
  duplicate-date rejection, and YAML-declared column ordering
- Julia-native serialized stage artifacts plus schema-fixed CSV / JSON / YAML
  sidecars
- `run_manifest.json` plus `PipelineRunResult` as the canonical run-level
  result surface
- `35_holdout_validation` as a side branch that never overwrites Stage `20`
  full-sample fit artifacts
- no panel or YAML-driven VI pipeline surface
- no separate report/plot stage hidden inside the Phase 9 runner

### Phase 10 Landed

Phase 10 landed under:

- `src/plotting/`
  - `theme.jl` — canonical CairoMakie theme ownership
  - `diagnostics.jl` — grouped inference diagnostic plots
  - `postmodel.jl` — contribution, decomposition, and response plots
  - `optimization.jl` — bounded budget-optimization comparison plots
  - `bundle.jl` — post-hoc static plot export over `PipelineRunResult`
- `test/plotting/`

The bounded Phase 10 contract is now:

- return Makie `Figure` objects
- use `CairoMakie` as the canonical backend
- keep `write_plot_bundle(run)` as a post-hoc helper, not a second pipeline
  path
- preserve stage-local plot artifacts as part of the closed Phase 9 successful
  run-directory contract
- stay intentionally smaller than the Abacus Dash surface

### Phase 11 Landed

Phase 11 landed under:

- `scripts/`
  - `export_abacus_validation_fixtures.py`
- `test/validation/`
  - final release-gate parity / regression harness
- `test/fixtures/abacus/validation/`
  - compact final validation fixtures
- `benchmark/`
  - benchmark runner, suites, and published result snapshots
- `docs/`
  - release-validation methodology
  - benchmark methodology and published results
  - v1.0.0-rc1 readiness checklist

The bounded Phase 11 contract:

- validate the closed Phases 2-10 surfaces rather than widening them
- distinguish Abacus-comparable parity rows from bounded Epsilon-only
  contract-validation rows
- publish benchmark methodology and results honestly instead of requiring
  universal speed wins
- close the v1 release-doc and readiness-checklist surface

### Phase 12 Planned

Phase 12 does not introduce a brand-new top-level product layer. It is a
remediation phase that will touch the existing comparable-row ownership areas:

- `src/mmm/`
  - scaling/model-space alignment in the bounded time-series fit path
- `src/model/` and `src/inference/`
  - typed artifact/spec metadata needed for explicit original-scale
    reconstruction
- `src/postmodel/`
  - corrected deterministic replay and Stage 60 curve ownership
- `src/optimization/`
  - optimization semantics on top of the corrected curve/model-space contract
- `src/pipeline/` and `examples/demo/`
  - runnable demo and pipeline comparability fixes
- `test/validation/`
  - repaired final validation harness over the corrected comparable row

Phase 12 should repair the existing layer contracts rather than add a parallel
second implementation path.

### Planned Later

These modules remain planned and should be implemented only as their roadmap
phases open:

- no additional planned runtime layers beyond the current roadmap; Phase 12 is
  a repair phase across existing layers, not a new product layer

## Layer Dependency Graph

```
Layer 9: Plotting ──────────────────────────────┐
Layer 8: Pipeline ──────────────────────────────┤
Layer 7: Optimization ──────────────────────────┤
Layer 6: Post-Model Analysis ───────────────────┤
Layer 5: Inference (MCMC/VI) ───────────────────┤
Layer 4: MMM Components ────────────────────────┤
Layer 3: Model Core (Builder/Config) ───────────┤
Layer 2: Distributions & Priors ────────────────┤
Layer 1: Transforms (Adstock/Saturation) ───────┘
```

Each layer depends only on layers below it. This enables:
- **Independent testing** — test transforms without needing Turing
- **Incremental porting** — ship lower layers first, build up
- **Flexible use** — users can use transforms directly without the full pipeline

---

## Key Architecture Decisions

### AD1: Composition over Inheritance

**Abacus (Python):**
```python
class PanelMMM(BaseValidateMMM, MMMModelBuilder, RegressionModelBuilder, ModelBuilder):
    ...  # 5-level inheritance chain
```

**Epsilon (Julia):**
```julia
# Abstract type hierarchy (shallow)
abstract type AbstractModel end
abstract type AbstractMMMModel <: AbstractModel end

# Concrete type with composition
mutable struct PanelMMM <: AbstractMMMModel
    config::ModelConfig
    sampler_config::SamplerConfig
    data::PanelMMMData
    built_model::Union{Nothing, MMMModelSpec}
    fit_state::Union{Nothing, ModelFitState}
end

# Behaviour via multiple dispatch
build_model(m::PanelMMM) = ...
fit!(m::PanelMMM) = ...
predict(m::PanelMMM, new_data) = ...
```

### AD2: @model Macro Strategy

Two options for the Turing `@model`:

**Option A: Single Monolithic @model** (simpler)
```julia
@model function mmm(X, y, config)
    # All priors, transforms, likelihood in one function
    intercept ~ Normal(0, config.intercept_prior_sigma)
    beta_media ~ filldist(Normal(0, 1), config.n_channels)
    # ... everything inline
end
```

**Option B: Composable Components** (more flexible, mirrors Abacus)
```julia
@model function mmm(X, y, components)
    mu = zeros(length(y))
    for component in components
        mu .+= apply(component, X)  # Each component adds to mean
    end
    sigma ~ truncated(Normal(0, 1), 0, Inf)
    y ~ MvNormal(mu, sigma^2 * I)
end
```

**Decision:** Start with Option A for simplicity, refactor to Option B once the core works. The current codebase is still closer to Option A, with `src/mmm/media.jl` extracted as the first composition boundary. Option B remains the long-term target.

### AD6: Phase 5 Panel Path Uses `PanelMMM`

**Context:** Phase 5 needs to add the first supported panel / hierarchical MMM
path, but widening `TimeSeriesMMM` to absorb panel semantics would blur the
single-series contract established in Phase 4 and reopen model-core scope.

**Decision:** Phase 5 introduces `PanelMMM <: AbstractMMMModel` as the first
supported panel target type. `TimeSeriesMMM` remains the single-series path.
Shared helpers may be extracted when useful, but Phase 5 should not treat a
large model-type refactor as the default implementation strategy.

**Consequences:**
- Phase 5 can add panel dims, coordinates, indexing, and hierarchical priors
  without overloading the current `TimeSeriesMMM` contract.
- The package will carry distinct single-series and panel MMM entry points.
- Any later attempt to merge those paths must be a separate design decision,
  not an implicit side effect of 05-03 implementation.

### AD3: Deterministic Tracking

Abacus uses `pm.Deterministic` extensively to track intermediate values (channel
contributions, transformed media, etc.). In Epsilon, Phase 7 does not make
`generated_quantities()` the public contract for those quantities. The canonical
post-model contract is deterministic replay from grouped posterior draws,
observed data, and typed model spec/coordinates.

`generated_quantities()` may still be used internally when useful, but it is not
the stable artifact boundary that later phases consume:

```julia
@model function mmm(X, y, ...)
    # ... sampling statements ...
    media_transformed = adstock_saturation(X_media, alpha, lam)
    channel_contrib = media_transformed .* beta
    mu = intercept .+ sum(channel_contrib, dims=2)
    y ~ MvNormal(vec(mu), sigma^2 * I)
    
    # Return deterministics for post-hoc extraction
    return (; channel_contrib, media_transformed, mu)
end

# After sampling, post-model code may replay deterministic terms from the
# grouped posterior artifact instead of depending on `generated_quantities()`:
results = inference_results(model)
contrib = contribution_results(results)
```

### AD4: Data Layout

**Abacus:** Pandas DataFrame → NumPy arrays, column-major (Fortran order)
**Epsilon:** DataFrames.jl → Julia arrays, also column-major ✅

Julia and NumPy/Pandas both use column-major storage, so array layouts are naturally compatible. This simplifies parity testing.

### AD5: Configuration System

Port the YAML-driven config system using `YAML.jl`:

```yaml
# epsilon_config.yaml
model:
  intercept:
    prior: Normal
    params: {mu: 0, sigma: 2}
  channels:
    adstock: geometric
    saturation: logistic
    prior:
      beta: {dist: HalfNormal, sigma: 1}
      alpha: {dist: Beta, alpha: 1, beta: 3}
      lam: {dist: Gamma, alpha: 3, beta: 1}

sampler:
  draws: 2000
  chains: 4
  target_accept: 0.9
```

```julia
config = YAML.load_file("epsilon_config.yaml")
model_config = ModelConfig(config["model"])
sampler_config = SamplerConfig(config["sampler"])
```

---

## Performance Expectations

Based on Julia vs Python benchmarks for similar workloads:

| Operation | Expected Speedup | Why |
|---|---|---|
| Model compilation | 1x (one-time JIT cost) | Julia's first-call latency |
| NUTS sampling | 3-10x | Native compiled gradients vs PyTensor graph |
| Adstock/saturation | 10-50x | Native Julia loops vs Python/PyTensor overhead |
| Budget optimization | 5-20x | JuMP/Ipopt vs scipy |
| Data preprocessing | 2-5x | DataFrames.jl vs Pandas |
| Overall pipeline | 3-10x | Compound effect across all stages |

**Note:** Julia has "time-to-first-plot" latency (compilation on first call). Subsequent calls are fast. For production pipelines this is amortized. For interactive use, consider `PackageCompiler.jl` to pre-compile.

---

## Testing Strategy

### Unit Tests (per-layer)
- Transforms: numerical parity with Abacus (export reference arrays)
- Distributions: sample statistics match, logpdf values match
- Model: log-probability evaluation matches PyMC model

### Integration Tests
- End-to-end: fit a small model on synthetic data, check posterior means converge
- Pipeline: run full pipeline on test dataset, compare artifacts

### Parity Tests
- Run identical model in both Abacus and Epsilon on same data/seed
- Compare: posterior means, posterior SDs, contribution shares, ROAS estimates
- Tolerance: means within 2σ of sampling noise, deterministics within 1e-6

### Benchmarks
- `BenchmarkTools.jl` for micro-benchmarks (transforms, convolution)
- Wall-clock timing for macro-benchmarks (full pipeline)
- Track over time with `PkgBenchmark.jl` only if the Phase 11 benchmark layer
  needs it; it is not part of the minimum closeout contract
