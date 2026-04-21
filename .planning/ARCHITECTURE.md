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
│   │   ├── special.jl              # Scaled, SkewStudentT, Michaelis dist
│   │   ├── shrinkage.jl            # Horseshoe, Finnish Horseshoe, R2D2
│   │   ├── masked.jl               # MaskedPrior
│   │   └── registry.jl             # Prior registry (type dispatch)
│   │
│   ├── model/                      # Layer 3: Model specification core
│   │   ├── types.jl                # Abstract types, ModelConfig, SamplerConfig
│   │   ├── config.jl               # YAML config loading & merging
│   │   ├── builder.jl              # Model builder interface
│   │   └── io.jl                   # Save/load models and chains
│   │
│   ├── mmm/                        # Layer 4: MMM-specific model components
│   │   ├── model.jl                # Turing @model for MMM
│   │   ├── panel.jl                # PanelMMM (hierarchical / multi-geo)
│   │   ├── seasonality.jl          # Fourier features
│   │   ├── hsgp.jl                 # Hilbert Space Gaussian Process
│   │   ├── trend.jl                # Linear trend, TVP
│   │   ├── events.jl               # Holiday / event effects
│   │   ├── controls.jl             # Control variables
│   │   └── media.jl                # Media channel component (adstock + saturation)
│   │
│   ├── inference/                   # Layer 5: Sampling & inference
│   │   ├── mcmc.jl                 # NUTS sampling wrapper
│   │   ├── vi.jl                   # Variational inference (ADVI)
│   │   ├── predictive.jl           # Prior/posterior predictive
│   │   └── diagnostics.jl          # R-hat, ESS, convergence checks
│   │
│   ├── postmodel/                   # Layer 6: Post-modeling analysis
│   │   ├── contributions.jl        # Channel contribution decomposition
│   │   ├── response_curves.jl      # Response curve computation
│   │   ├── metrics.jl              # ROAS, mROAS, CPA, mCPA
│   │   ├── decomposition.jl        # Waterfall decomposition
│   │   └── summary.jl              # Model summary tables
│   │
│   ├── optimization/                # Layer 7: Budget optimization
│   │   ├── optimizer.jl            # BudgetOptimizer
│   │   ├── constraints.jl          # Budget, bounds, ratio constraints
│   │   └── objective.jl            # Objective functions (max ROAS, min CPA)
│   │
│   ├── pipeline/                    # Layer 8: End-to-end pipeline
│   │   ├── runner.jl               # Pipeline orchestrator
│   │   ├── config.jl               # Pipeline YAML config
│   │   ├── context.jl              # PipelineContext, manifest
│   │   ├── stages/                 # Individual pipeline stages
│   │   │   ├── metadata.jl         # Stage 00
│   │   │   ├── preflight.jl        # Stage 10
│   │   │   ├── fit.jl              # Stage 20
│   │   │   ├── assessment.jl       # Stage 30
│   │   │   ├── validation.jl       # Stage 35
│   │   │   ├── decomposition.jl    # Stage 40
│   │   │   ├── optimization.jl     # Stage 50
│   │   │   └── report.jl           # Stage 60
│   │   └── cli.jl                  # Command-line interface
│   │
│   └── plotting/                    # Layer 9: Visualization
│       ├── contributions.jl        # Contribution time series, waterfall
│       ├── response.jl             # Response curves
│       ├── diagnostics.jl          # Trace, posterior, residuals
│       ├── optimization.jl         # Budget comparison plots
│       └── theme.jl                # Epsilon plot theme (Makie)
│
├── test/
│   ├── runtests.jl                 # Test entry point
│   ├── transforms/                 # Parity tests for transforms
│   ├── distributions/              # Prior/distribution tests
│   ├── model/                      # Model builder tests
│   ├── mmm/                        # MMM model tests
│   ├── inference/                   # Sampling tests
│   ├── postmodel/                   # Decomposition/metrics tests
│   ├── optimization/                # Budget optimizer tests
│   ├── pipeline/                    # Pipeline integration tests
│   └── fixtures/                    # Reference data from Abacus
│
├── docs/                            # Documenter.jl docs
├── benchmark/                       # BenchmarkTools.jl benchmarks
├── Project.toml                     # Julia package manifest
├── Makefile                         # Common commands
└── README.md
```

---

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
struct PanelMMM <: AbstractMMMModel
    config::ModelConfig
    sampler_config::SamplerConfig
    data::MMMData
    chain::Union{Nothing, Chains}
end

# Behaviour via multiple dispatch
build_model(m::PanelMMM) = ...
fit!(m::PanelMMM) = ...
predict(m::PanelMMM, X_new) = ...
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

**Decision:** Start with Option A for simplicity, refactor to Option B once the core works. Option B is the long-term target (matches Abacus's composable component architecture).

### AD3: Deterministic Tracking

Abacus uses `pm.Deterministic` extensively to track intermediate values (channel contributions, transformed media, etc.). In Turing, this requires `generated_quantities`:

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

# After sampling:
chain = sample(model, NUTS(), 2000)
gq = generated_quantities(model, chain)  # Extract deterministics
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
- Track over time with `PkgBenchmark.jl`
