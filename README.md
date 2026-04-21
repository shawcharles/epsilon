# ε Epsilon MMM

**Bayesian Marketing Mix Modeling in Julia**

Epsilon.jl is a high-performance framework for Bayesian Marketing Mix Modeling, built on [Turing.jl](https://turing.ml/) and the Julia scientific computing ecosystem.

> *A Julia port of [Abacus](https://github.com/tandpds/abacus) — same statistical rigour, native compiled performance.*

## Status

🚧 **Pre-alpha / Planning Phase** — Architecture and component mapping in progress.

## Why Julia?

| | Python (Abacus) | Julia (Epsilon) |
|---|---|---|
| Probabilistic Programming | PyMC / PyTensor | Turing.jl |
| MCMC Sampling | NUTS (via PyMC/nutpie/NumPyro) | DynamicHMC.jl / AdvancedHMC.jl |
| Autodiff | PyTensor graph-mode | Native (ForwardDiff.jl / ReverseDiff.jl) |
| Tensor Operations | PyTensor / NumPy | Native arrays + LinearAlgebra stdlib |
| Performance | Interpreted + JIT (JAX path) | JIT-compiled (LLVM) |
| Variational Inference | PyMC ADVI | AdvancedVI.jl |
| Gaussian Processes | PyMC GP / HSGP | AbstractGPs.jl / KernelFunctions.jl |
| Diagnostics | ArviZ | MCMCChains.jl / MCMCDiagnosticTools.jl |
| Optimization | scipy.optimize | Optim.jl / JuMP.jl |
| Plotting | Matplotlib / Seaborn | Makie.jl |
| Data Handling | Pandas / xarray | DataFrames.jl |

## Project Planning

See [`docs/planning/`](docs/planning/) for the full GSD board, architecture plan, and component mapping.

## License

MIT
