# Dependencies — Epsilon MMM

> Julia package dependencies, version strategy, and rationale.

---

## Core Dependencies

This document mixes dependencies that are already in `Project.toml` with
dependencies planned for later phases. "Required From" means the earliest phase
that should introduce the package, not the current repository state.

These are required for the main `Epsilon.jl` package:

| Package | Purpose | Abacus Equivalent | Required From |
|---|---|---|---|
| **[Turing.jl](https://github.com/TuringLang/Turing.jl)** | Probabilistic programming, `@model` macro, sampling | PyMC | Phase 4 |
| **[Distributions.jl](https://github.com/JuliaStats/Distributions.jl)** | Probability distributions (Normal, Beta, Gamma, etc.) | PyMC distributions | Phase 2 |
| **[MCMCChains.jl](https://github.com/TuringLang/MCMCChains.jl)** | MCMC chain storage, summary, diagnostics display | ArviZ InferenceData | Phase 4 |
| **[MCMCDiagnosticTools.jl](https://github.com/TuringLang/MCMCDiagnosticTools.jl)** | R-hat, ESS, MCSE, Geweke | ArviZ diagnostics | Phase 6 |
| **[DataFrames.jl](https://github.com/JuliaData/DataFrames.jl)** | Tabular data handling for Phase 7 summary-table projections and later pipeline IO | Pandas | Phase 7 |
| **[CSV.jl](https://github.com/JuliaData/CSV.jl)** | CSV reading/writing for pipeline IO and exported artifacts | pandas.read_csv | Phase 9 |
| **[YAML.jl](https://github.com/JuliaData/YAML.jl)** | YAML config loading | PyYAML | Phase 3 |
| **[LinearAlgebra](https://docs.julialang.org/en/v1/stdlib/LinearAlgebra/)** | Linear algebra (stdlib) | NumPy linalg | Phase 1 |
| **[Statistics](https://docs.julialang.org/en/v1/stdlib/Statistics/)** | Mean, std, etc. (stdlib) | NumPy | Phase 1 |
| **[StatsFuns.jl](https://github.com/JuliaStats/StatsFuns.jl)** | logistic, logit, softmax, etc. | scipy.special | Phase 1 |
| **[StatsBase.jl](https://github.com/JuliaStats/StatsBase.jl)** | Statistical utilities, weights, sampling | NumPy/SciPy | Phase 4 |

## Inference Dependencies

| Package | Purpose | Abacus Equivalent | Required From |
|---|---|---|---|
| **[AdvancedHMC.jl](https://github.com/TuringLang/AdvancedHMC.jl)** | HMC/NUTS sampler (Turing backend) | PyMC NUTS / nutpie | Phase 4 |
| **[DynamicHMC.jl](https://github.com/tpapp/DynamicHMC.jl)** | Alternative NUTS implementation | nutpie / NumPyro | Phase 5 (optional) |
| **[AdvancedVI.jl](https://github.com/TuringLang/AdvancedVI.jl)** | Variational inference (ADVI) | pm.fit() / ADVI | Phase 6 |
| **[ForwardDiff.jl](https://github.com/JuliaDiff/ForwardDiff.jl)** | Forward-mode autodiff | PyTensor autodiff | Phase 4 |
| **[ReverseDiff.jl](https://github.com/JuliaDiff/ReverseDiff.jl)** | Reverse-mode autodiff | PyTensor autodiff | Phase 4 |

## Gaussian Processes

| Package | Purpose | Abacus Equivalent | Required From |
|---|---|---|---|
| **[AbstractGPs.jl](https://github.com/JuliaGaussianProcesses/AbstractGPs.jl)** | GP interface | pm.gp | Phase 5 |
| **[KernelFunctions.jl](https://github.com/JuliaGaussianProcesses/KernelFunctions.jl)** | GP kernels (Matern, RBF, Periodic) | PyMC covariance functions | Phase 5 |

> **Note:** HSGP (Hilbert Space GP) may need custom implementation. Evaluate if `AbstractGPs.jl` supports it or if manual port is needed.

## Optimization

| Package | Purpose | Abacus Equivalent | Required From |
|---|---|---|---|
| **[JuMP.jl](https://github.com/jump-dev/JuMP.jl)** | Mathematical optimization framework | scipy.optimize | Phase 8 |
| **[Ipopt.jl](https://github.com/jump-dev/Ipopt.jl)** | Interior-point nonlinear optimizer (JuMP solver) | SLSQP | Phase 8 |
| **[Optim.jl](https://github.com/JuliaNLSolvers/Optim.jl)** | Optional exploratory optimizer backend, not part of the bounded Phase 8 public contract | scipy.optimize.minimize | Stretch / optional |

## Plotting

| Package | Purpose | Abacus Equivalent | Required From |
|---|---|---|---|
| **[CairoMakie.jl](https://github.com/MakieOrg/Makie.jl)** | Canonical static plotting backend and `Figure` export path | Matplotlib | Phase 10 |
| **[AlgebraOfGraphics.jl](https://github.com/MakieOrg/AlgebraOfGraphics.jl)** | Optional internal helper for faceting / grammar-style plotting; not required for the bounded public contract | Seaborn | Phase 10 |

## IO & Serialization

| Package | Purpose | Abacus Equivalent | Required From |
|---|---|---|---|
| **[JLD2.jl](https://github.com/JuliaIO/JLD2.jl)** | Save/load Julia objects (models, chains) | pickle / NetCDF | Phase 4 |
| **[JSON3.jl](https://github.com/quinnj/JSON3.jl)** | JSON reading/writing | json | Phase 9 |
| **[Dates](https://docs.julialang.org/en/v1/stdlib/Dates/)** | Date/time handling (stdlib) | datetime / pandas | Phase 4 |

> **Phase 9 note:** the bounded pipeline contract does not require a dedicated
> CLI framework package. Prefer a thin stdlib-backed CLI entry point over
> adding `ArgParse.jl` or `Comonicon.jl` unless the Phase 9 implementation
> proves that a new dependency is necessary.

## Testing & Development

| Package | Purpose | Required From |
|---|---|---|
| **[Test](https://docs.julialang.org/en/v1/stdlib/Test/)** | Unit testing (stdlib) | Phase 1 |
| **[BenchmarkTools.jl](https://github.com/JuliaCI/BenchmarkTools.jl)** | Canonical Phase 11 benchmark runner dependency | Phase 11 |
| **[PkgBenchmark.jl](https://github.com/JuliaCI/PkgBenchmark.jl)** | Optional benchmark-result tracking helper if Phase 11 needs it | Phase 11 (optional) |
| **[Runic.jl](https://github.com/fredrikekre/Runic.jl)** | Code formatting | Phase 1 |
| **[Documenter.jl](https://github.com/JuliaDocs/Documenter.jl)** | Documentation generator | Phase 1 |
| **[Aqua.jl](https://github.com/JuliaTesting/Aqua.jl)** | Package quality checks | Phase 1 |
| **[JET.jl](https://github.com/aviatesk/JET.jl)** | Static analysis | Phase 1 |

## Optional / Stretch

| Package | Purpose | When |
|---|---|---|
| **[CUDA.jl](https://github.com/JuliaGPU/CUDA.jl)** | GPU acceleration | Stretch |
| **[Distributed](https://docs.julialang.org/en/v1/stdlib/Distributed/)** | Multi-process parallelism (stdlib) | Stretch |
| **[PythonCall.jl](https://github.com/JuliaPy/PythonCall.jl)** | Python interop (call Abacus from Julia or vice-versa) | Stretch |
| **[PackageCompiler.jl](https://github.com/JuliaLang/PackageCompiler.jl)** | Pre-compile to eliminate first-call latency | Production |
| **[Genie.jl](https://github.com/GenieFramework/Genie.jl)** | Web framework (scenario planner) | Stretch |

---

## Version Strategy

- Target **Julia 1.10 LTS** as minimum supported version
- Test on **Julia 1.11+** (latest stable)
- Pin major versions of Turing ecosystem packages together (they release in sync)
- Use `[compat]` section in `Project.toml` to enforce version bounds

```toml
[compat]
julia = "1.10"
Turing = "0.33"
Distributions = "0.25"
MCMCChains = "6"
DataFrames = "1"
```

---

## Dependency Graph

```
Epsilon.jl
├── Turing.jl
│   ├── Distributions.jl
│   ├── AdvancedHMC.jl
│   ├── AdvancedVI.jl
│   ├── MCMCChains.jl
│   ├── ForwardDiff.jl / ReverseDiff.jl
│   └── DynamicPPL.jl (internal)
├── DataFrames.jl + CSV.jl
├── YAML.jl + JSON3.jl
├── JuMP.jl + Ipopt.jl
├── AbstractGPs.jl + KernelFunctions.jl
├── CairoMakie.jl + AlgebraOfGraphics.jl
├── JLD2.jl
└── StatsFuns.jl + StatsBase.jl
```
