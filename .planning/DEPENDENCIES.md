# Dependencies — Epsilon MMM

> Julia package dependencies, version strategy, and rationale.

---

## Core Dependencies

These are required for the main `Epsilon.jl` package:

| Package | Purpose | Abacus Equivalent | Required From |
|---|---|---|---|
| **[Turing.jl](https://github.com/TuringLang/Turing.jl)** | Probabilistic programming, `@model` macro, sampling | PyMC | Phase 3 |
| **[Distributions.jl](https://github.com/JuliaStats/Distributions.jl)** | Probability distributions (Normal, Beta, Gamma, etc.) | PyMC distributions | Phase 2 |
| **[MCMCChains.jl](https://github.com/TuringLang/MCMCChains.jl)** | MCMC chain storage, summary, diagnostics display | ArviZ InferenceData | Phase 5 |
| **[MCMCDiagnosticTools.jl](https://github.com/TuringLang/MCMCDiagnosticTools.jl)** | R-hat, ESS, MCSE, Geweke | ArviZ diagnostics | Phase 5 |
| **[DataFrames.jl](https://github.com/JuliaData/DataFrames.jl)** | Tabular data handling | Pandas | Phase 0 |
| **[CSV.jl](https://github.com/JuliaData/CSV.jl)** | CSV reading/writing | pandas.read_csv | Phase 0 |
| **[YAML.jl](https://github.com/JuliaData/YAML.jl)** | YAML config loading | PyYAML | Phase 3 |
| **[LinearAlgebra](https://docs.julialang.org/en/v1/stdlib/LinearAlgebra/)** | Linear algebra (stdlib) | NumPy linalg | Phase 1 |
| **[Statistics](https://docs.julialang.org/en/v1/stdlib/Statistics/)** | Mean, std, etc. (stdlib) | NumPy | Phase 1 |
| **[StatsFuns.jl](https://github.com/JuliaStats/StatsFuns.jl)** | logistic, logit, softmax, etc. | scipy.special | Phase 1 |
| **[StatsBase.jl](https://github.com/JuliaStats/StatsBase.jl)** | Statistical utilities, weights, sampling | NumPy/SciPy | Phase 1 |

## Inference Dependencies

| Package | Purpose | Abacus Equivalent | Required From |
|---|---|---|---|
| **[AdvancedHMC.jl](https://github.com/TuringLang/AdvancedHMC.jl)** | HMC/NUTS sampler (Turing backend) | PyMC NUTS / nutpie | Phase 5 |
| **[DynamicHMC.jl](https://github.com/tpapp/DynamicHMC.jl)** | Alternative NUTS implementation | nutpie / NumPyro | Phase 5 (optional) |
| **[AdvancedVI.jl](https://github.com/TuringLang/AdvancedVI.jl)** | Variational inference (ADVI) | pm.fit() / ADVI | Phase 5 |
| **[ForwardDiff.jl](https://github.com/JuliaDiff/ForwardDiff.jl)** | Forward-mode autodiff | PyTensor autodiff | Phase 3 |
| **[ReverseDiff.jl](https://github.com/JuliaDiff/ReverseDiff.jl)** | Reverse-mode autodiff | PyTensor autodiff | Phase 3 |

## Gaussian Processes

| Package | Purpose | Abacus Equivalent | Required From |
|---|---|---|---|
| **[AbstractGPs.jl](https://github.com/JuliaGaussianProcesses/AbstractGPs.jl)** | GP interface | pm.gp | Phase 4 |
| **[KernelFunctions.jl](https://github.com/JuliaGaussianProcesses/KernelFunctions.jl)** | GP kernels (Matern, RBF, Periodic) | PyMC covariance functions | Phase 4 |

> **Note:** HSGP (Hilbert Space GP) may need custom implementation. Evaluate if `AbstractGPs.jl` supports it or if manual port is needed.

## Optimization

| Package | Purpose | Abacus Equivalent | Required From |
|---|---|---|---|
| **[JuMP.jl](https://github.com/jump-dev/JuMP.jl)** | Mathematical optimization framework | scipy.optimize | Phase 7 |
| **[Ipopt.jl](https://github.com/jump-dev/Ipopt.jl)** | Interior-point nonlinear optimizer (JuMP solver) | SLSQP | Phase 7 |
| **[Optim.jl](https://github.com/JuliaNLSolvers/Optim.jl)** | Unconstrained/simple optimization | scipy.optimize.minimize | Phase 7 |

## Plotting

| Package | Purpose | Abacus Equivalent | Required From |
|---|---|---|---|
| **[CairoMakie.jl](https://github.com/MakieOrg/Makie.jl)** | Publication-quality static plots | Matplotlib | Phase 9 |
| **[AlgebraOfGraphics.jl](https://github.com/MakieOrg/AlgebraOfGraphics.jl)** | Grammar-of-graphics layer for Makie | Seaborn | Phase 9 |

> **Alternative:** `Plots.jl` + `GR` backend for initial prototyping (simpler API).

## IO & Serialization

| Package | Purpose | Abacus Equivalent | Required From |
|---|---|---|---|
| **[JLD2.jl](https://github.com/JuliaIO/JLD2.jl)** | Save/load Julia objects (models, chains) | pickle / NetCDF | Phase 3 |
| **[JSON3.jl](https://github.com/quinnj/JSON3.jl)** | JSON reading/writing | json | Phase 3 |
| **[Dates](https://docs.julialang.org/en/v1/stdlib/Dates/)** | Date/time handling (stdlib) | datetime / pandas | Phase 0 |

## Testing & Development

| Package | Purpose | Required From |
|---|---|---|
| **[Test](https://docs.julialang.org/en/v1/stdlib/Test/)** | Unit testing (stdlib) | Phase 0 |
| **[BenchmarkTools.jl](https://github.com/JuliaCI/BenchmarkTools.jl)** | Micro-benchmarks | Phase 10 |
| **[PkgBenchmark.jl](https://github.com/JuliaCI/PkgBenchmark.jl)** | CI benchmark tracking | Phase 10 |
| **[Runic.jl](https://github.com/fredrikekre/Runic.jl)** | Code formatting | Phase 0 |
| **[Documenter.jl](https://github.com/JuliaDocs/Documenter.jl)** | Documentation generator | Phase 0 |
| **[Aqua.jl](https://github.com/JuliaTesting/Aqua.jl)** | Package quality checks | Phase 0 |
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
