# Component Mapping — PyMC/PyTensor → Turing.jl

> The Rosetta Stone for porting Abacus to Epsilon.
> Each section maps Python constructs to their Julia equivalents.

---

## 1. Model Specification

### Model Context

| Abacus (PyMC) | Epsilon (Turing.jl) | Notes |
|---|---|---|
| `with pm.Model() as model:` | `@model function mmm(X, y, ...)` | PyMC uses context manager; Turing uses `@model` macro |
| `pm.MutableData("x", data)` | Function argument `x` in `@model` | Turing models are functions — data is passed as args |
| `coords={"channel": [...]}` | Manual indexing or `filldist` | Turing has no built-in coord system; use named dims via MCMCChains |
| `model.set_data({"x": new_x})` | Call `model(new_x, new_y)` | Just re-instantiate the model with new data |

### Priors / Random Variables

| Abacus (PyMC) | Epsilon (Turing.jl) | Notes |
|---|---|---|
| `alpha = pm.Beta("alpha", 1, 3)` | `alpha ~ Beta(1, 3)` | Nearly identical syntax |
| `sigma = pm.HalfNormal("sigma", 1)` | `sigma ~ truncated(Normal(0, 1), 0, Inf)` | Turing uses `truncated()` for half-distributions |
| `pm.Normal("y_obs", mu, sigma, observed=y)` | `y ~ MvNormal(mu, sigma²)` or `for i in eachindex(y); y[i] ~ Normal(mu[i], sigma); end` | Observed data passed as argument, conditioned via `y[i] ~ ...` |
| `pm.Deterministic("contrib", x * beta)` | `contrib = x * beta` (tracked via `return` or `generated_quantities`) | Turing tracks sampled vars automatically; deterministics need `generated_quantities` |
| `pm.Potential("lift", logp)` | `Turing.@addlogprob!(logp)` | Direct equivalent |

### Plates / Vectorized Priors

| Abacus (PyMC) | Epsilon (Turing.jl) | Notes |
|---|---|---|
| `pm.Normal("beta", 0, 1, dims="channel")` | `beta ~ filldist(Normal(0, 1), n_channels)` | `filldist` creates independent priors |
| `pm.Normal("beta", mu_g, sigma_g, dims=("geo","channel"))` | `beta ~ filldist(Normal(mu_g, sigma_g), n_geo, n_channels)` | Multi-dim plates via `filldist` shape |
| `pm.MvNormal("beta", mu, cov)` | `beta ~ MvNormal(mu, cov)` | Direct equivalent |

---

## 2. Distributions

### Standard Distributions

| PyMC (`pm.`) | Distributions.jl | Notes |
|---|---|---|
| `pm.Normal(mu, sigma)` | `Normal(mu, sigma)` | ✅ Direct |
| `pm.HalfNormal(sigma)` | `truncated(Normal(0, sigma), 0, Inf)` | Or define `HalfNormal(σ) = truncated(Normal(0,σ), 0, Inf)` |
| `pm.TruncatedNormal(mu, sigma, lower, upper)` | `truncated(Normal(mu, sigma), lower, upper)` | ✅ Direct |
| `pm.Beta(alpha, beta)` | `Beta(alpha, beta)` | ✅ Direct |
| `pm.Gamma(alpha, beta)` | `Gamma(alpha, 1/beta)` | ⚠️ PyMC uses rate; Distributions.jl uses scale = 1/rate |
| `pm.HalfCauchy(beta)` | `truncated(Cauchy(0, beta), 0, Inf)` | No built-in HalfCauchy |
| `pm.Laplace(mu, b)` | `Laplace(mu, b)` | ✅ Direct |
| `pm.StudentT(nu, mu, sigma)` | `LocationScale(mu, sigma, TDist(nu))` | Or use `TDist` and shift manually |
| `pm.Exponential(lam)` | `Exponential(1/lam)` | ⚠️ PyMC uses rate; Distributions.jl uses scale |
| `pm.Uniform(lower, upper)` | `Uniform(lower, upper)` | ✅ Direct |
| `pm.Dirichlet(a)` | `Dirichlet(a)` | ✅ Direct |
| `pm.LogNormal(mu, sigma)` | `LogNormal(mu, sigma)` | ✅ Direct |
| `pm.InverseGamma(alpha, beta)` | `InverseGamma(alpha, beta)` | ✅ Direct |
| `pm.Weibull(alpha, beta)` | `Weibull(alpha, beta)` | ✅ Direct |
| `pm.Poisson(mu)` | `Poisson(mu)` | ✅ Direct |

### Custom / Special Distributions (Need Implementation)

| Abacus Special Prior | Julia Strategy |
|---|---|
| `Scaled(dist, scale)` | Custom struct wrapping `dist`, override `rand` and `logpdf` |
| `SkewStudentT(nu, mu, sigma, alpha)` | Implement as custom `Distribution` subtype |
| Michaelis-Menten | Already covered by the saturation layer; no separate custom distribution is planned |
| `MaskedPrior(dist, mask)` | Julia function that applies prior to masked indices |
| `Horseshoe` | Available in Turing ecosystem or implement manually |
| `FinnishHorseshoe` | Implement using `Horseshoe` + slab regularization |
| `R2D2` | Implement: Dirichlet concentration → variance allocation |

---

## 3. Tensor Operations

### PyTensor → Julia Native Arrays

| PyTensor (`pt.`) | Julia | Notes |
|---|---|---|
| `pt.tensor` / `pt.as_tensor` | Native `Array` / `Vector` / `Matrix` | Julia arrays ARE tensors |
| `pt.sum(x, axis=0)` | `sum(x, dims=1)` | ⚠️ Julia is 1-indexed |
| `pt.exp(x)` | `exp.(x)` | Broadcast with `.` |
| `pt.log(x)` | `log.(x)` | Broadcast |
| `pt.power(x, n)` | `x .^ n` | Broadcast |
| `pt.dot(a, b)` | `a' * b` or `dot(a, b)` | `LinearAlgebra.dot` |
| `pt.switch(cond, a, b)` | `ifelse.(cond, a, b)` | Broadcast `ifelse` |
| `pt.clip(x, lo, hi)` | `clamp.(x, lo, hi)` | ✅ Direct |
| `pt.cumsum(x, axis=0)` | `cumsum(x, dims=1)` | ✅ Direct |
| `pt.cumprod(x, axis=0)` | `cumprod(x, dims=1)` | ✅ Direct |
| `pt.concatenate([a, b], axis=0)` | `cat(a, b, dims=1)` or `vcat(a, b)` | ✅ |
| `pt.stack([a, b], axis=0)` | `stack([a, b])` | Julia 1.9+ |
| `pt.zeros(shape)` | `zeros(shape...)` | ✅ |
| `pt.ones(shape)` | `ones(shape...)` | ✅ |
| `pt.arange(start, stop)` | `start:stop-1` or `collect(start:stop-1)` | ⚠️ 0-indexed → 1-indexed |
| `pt.set_subtensor(x[idx], val)` | `x[idx] = val` (mutating) or use `setindex` | PyTensor is immutable; Julia arrays are mutable |
| `pt.sigmoid(x)` | `logistic.(x)` from `StatsFuns.jl` or `1 ./ (1 .+ exp.(-x))` | |
| `pt.softmax(x, axis)` | `softmax(x)` from `NNlib.jl` or manual | |
| `pt.max(x, axis)` | `maximum(x, dims=axis)` | |
| `pt.min(x, axis)` | `minimum(x, dims=axis)` | |
| `pt.abs(x)` | `abs.(x)` | Broadcast |
| `pt.sqrt(x)` | `sqrt.(x)` | Broadcast |
| `pt.reshape(x, shape)` | `reshape(x, shape...)` | ✅ |
| `pt.flatten(x)` | `vec(x)` | ✅ |
| `pt.specify_shape(x, shape)` | Not needed — Julia arrays have known shapes | |

### Key Difference: Lazy vs Eager

PyTensor builds a **computation graph** (lazy) that is compiled and optimized before execution. Julia operates **eagerly** — computations run immediately. This means:

- No equivalent of `pytensor.function([inputs], [outputs])` — just write a Julia function
- No graph compilation step — Julia's JIT compiler handles optimization
- No `pt.shared()` — just use regular variables
- Autodiff via `ForwardDiff.jl` or `ReverseDiff.jl` works on native Julia code

---

## 4. Sampling & Inference

| Abacus (PyMC) | Epsilon (Turing.jl) | Notes |
|---|---|---|
| `pm.sample(draws=2000, chains=4, target_accept=0.9)` | `sample(model, NUTS(0.9), MCMCThreads(), 2000, 4)` | `0.9` = target acceptance rate |
| `pm.sample(nuts_sampler="nutpie")` | Not needed — Turing's NUTS is already fast | Julia NUTS is compiled |
| `pm.sample(nuts_sampler="numpyro")` | Not needed | |
| `pm.fit(method=pm.ADVI())` | `vi(model, ADVI())` via AdvancedVI.jl | |
| `pm.sample_prior_predictive()` | `sample(model, Prior(), N)` | |
| `pm.sample_posterior_predictive(trace)` | `predict(model, chain)` | |
| `pm.compute_deterministics(trace)` | `generated_quantities(model, chain)` | Key pattern for deterministics |
| `az.InferenceData` | `MCMCChains.Chains` | Similar but different API |
| `az.summary(idata)` | `describe(chain)` or `summarystats(chain)` | |
| `az.hdi(idata, hdi_prob=0.94)` | `hpd(chain, alpha=0.06)` | |
| `az.r_hat(idata)` | `rhat(chain)` from MCMCDiagnosticTools | |
| `az.ess(idata)` | `ess(chain)` from MCMCDiagnosticTools | |

---

## 5. Adstock Transform Mapping

| Abacus Function | Julia Implementation | Key Operations |
|---|---|---|
| `geometric_adstock(x, alpha, l_max)` | `geometric_adstock(x, α, l_max)` | `w[t] = α^t`, then `batched_conv(x, w)` |
| `delayed_adstock(x, alpha, theta, l_max)` | `delayed_adstock(x, α, θ, l_max)` | `w[t] = α^((t-θ)²)`, then conv |
| `binomial_adstock(x, alpha, l_max, L)` | `binomial_adstock(x, α, l_max, L)` | `w[t] = (1-t/(L+1))^(1/α-1)` |
| `weibull_adstock(x, k, lam, l_max, type)` | `weibull_adstock(x, k, λ, l_max, type)` | PDF or CDF Weibull kernel |
| `batched_convolution(x, w, axis, mode)` | `batched_convolution(x, w; dims, mode)` | Core convolution engine |

### Batched Convolution Detail

```python
# Abacus (PyTensor)
pt.sum(pt.stack([pt.roll(x, -i) * w[i] for i in range(l_max)]) * mask, axis=0)
```

```julia
# Epsilon (Julia)
# Option 1: Loop-based (autodiff-friendly)
function batched_convolution(x::AbstractVector, w::AbstractVector; mode=:after)
    T = length(x)
    L = length(w)
    y = similar(x, T)
    for t in 1:T
        y[t] = sum(w[i] * x[max(1, t - i + 1)] for i in 1:min(L, t))
    end
    return y
end

# Option 2: DSP.conv based (faster, may need custom adjoint for autodiff)
```

---

## 6. Saturation Transform Mapping

| Abacus Function | Julia Formula | Notes |
|---|---|---|
| `logistic_saturation(x, lam)` | `lam .* logistic.(mu .* x) .- lam .* logistic(0)` | `logistic(z) = 1/(1+exp(-z))` |
| `tanh_saturation(x, b, c)` | `b .* tanh.(x ./ (b .* c))` | Direct translation |
| `michaelis_menten_saturation(x, a, Km)` | `a .* x ./ (x .+ Km)` | Direct translation |
| `hill_saturation(x, sigma, beta, lam)` | Hill equation with half-saturation point | See Abacus implementation |

---

## 7. Seasonality Mapping

### Fourier Seasonality

```python
# Abacus
for i in range(n_order):
    X[:, 2*i] = np.sin(2 * np.pi * (i+1) * t / period)
    X[:, 2*i+1] = np.cos(2 * np.pi * (i+1) * t / period)
```

```julia
# Epsilon
function fourier_features(t::AbstractVector, period::Real, n_order::Int)
    X = zeros(length(t), 2 * n_order)
    for i in 1:n_order
        X[:, 2i-1] = sin.(2π * i * t / period)
        X[:, 2i]   = cos.(2π * i * t / period)
    end
    return X
end
```

### HSGP (Hilbert Space Gaussian Process)

| Abacus (PyMC) | Epsilon (Julia) | Notes |
|---|---|---|
| `pm.gp.HSGP(m, L, cov_func)` | Custom implementation or `AbstractGPs.jl` + HSGP approx | No direct HSGP in Julia ecosystem — likely need custom port |
| `gp.prior_linearized(X)` | Compute basis functions + spectral density | Port the HSGP math directly |

**HSGP is a key technical risk — may need to be ported manually from Abacus's PyMC implementation.**

---

## 8. Panel / Hierarchical Model Mapping

```python
# Abacus — Hierarchical prior (PyMC)
with pm.Model(coords={"geo": geos, "channel": channels}):
    mu_global = pm.Normal("mu_global", 0, 1)
    sigma_global = pm.HalfNormal("sigma_global", 1)
    beta_geo = pm.Normal("beta_geo", mu_global, sigma_global, dims=("geo", "channel"))
```

```julia
# Epsilon — Hierarchical prior (Turing)
@model function panel_mmm(X, y, n_geo, n_channels)
    mu_global ~ Normal(0, 1)
    sigma_global ~ truncated(Normal(0, 1), 0, Inf)
    beta_geo ~ filldist(Normal(mu_global, sigma_global), n_geo, n_channels)
    # ... rest of model
end
```

---

## 9. Budget Optimization Mapping

| Abacus (scipy) | Epsilon (Julia) | Notes |
|---|---|---|
| `scipy.optimize.minimize(method='SLSQP')` | `JuMP.jl + Ipopt.jl` | Closed Phase 8 solver contract for the supported path |
| Equality constraint: `sum(x) == budget` | `JuMP: @constraint(m, sum(x) == budget)` | Total-budget equality is part of the bounded Phase 8 contract |
| Bounds: `lower <= x[i] <= upper` | `JuMP: @variable(m, lo <= x[i] <= hi)` | Absolute and reference-relative bounds are normalized before model construction |
| Ratio constraints | Deferred / out of scope | Not part of the closed Phase 8 public surface |

**Recommendation:** Use `JuMP.jl` + `Ipopt.jl` only for the supported Phase 8 budget optimizer. `Optim.jl` may still be useful for exploratory experiments, but it is not part of the bounded public contract.

---

## 10. IO & Serialization Mapping

| Abacus | Epsilon | Notes |
|---|---|---|
| `az.InferenceData` (NetCDF) | `MCMCChains.Chains` + metadata `Dict` | |
| `az.to_netcdf(idata, path)` | `JLD2.save(path, chain)` or custom NetCDF | |
| `pickle` (model save) | `Serialization.serialize` or `JLD2.save` | |
| `json` (config) | `JSON3.jl` | |
| `yaml` (pipeline config) | `YAML.jl` | |
| `pandas.DataFrame` | `DataFrames.DataFrame` | Near-identical API |
| `xarray.DataArray` | `AxisArrays.jl` or `DimensionalData.jl` | For labeled multi-dim arrays |

---

## 11. Plotting Mapping

| Abacus (Matplotlib/Seaborn) | Epsilon (Makie.jl) | Notes |
|---|---|---|
| `plt.figure()` / `plt.subplots()` | `fig = Figure()` / `ax = Axis(fig[1,1])` | Makie uses layout grid |
| `ax.plot(x, y)` | `lines!(ax, x, y)` | |
| `ax.fill_between(x, lo, hi)` | `band!(ax, x, lo, hi)` | HDI bands |
| `ax.bar(x, heights)` | `barplot!(ax, x, heights)` | |
| `sns.heatmap(data)` | `heatmap!(ax, data)` | |
| `plt.savefig("plot.png")` | `save("plot.png", fig)` | |

**Phase 10 decision:** `CairoMakie.jl` is the canonical static backend.
`AlgebraOfGraphics.jl` may help internally, but `Plots.jl` is outside the
bounded public plotting contract.

---

## 12. Pipeline Mapping

| Abacus | Epsilon | Notes |
|---|---|---|
| `PipelineRunConfig` | `PipelineRunConfig` | Same role, but bounded Phase 9 runtime keys stay time-series-first and MCMC-only |
| `run_pipeline(...)` | `run_pipeline(...)` | Canonical disk-backed runner entry point |
| `PipelineRunResult` | `PipelineRunResult` | Run-directory + manifest ownership |
| blocked holdout validation outputs | `PipelineValidationResult` | Stage-owned side-branch artifact; does not replace the main fit path |
| `run_manifest.json` | `run_manifest.json` | Same machine-readable run index concept |
| combined model dataset CSV | combined model dataset CSV | Closed Phase 9 path with fixed date parsing, sort order, duplicate-date rejection, and YAML-declared column mapping |
| NetCDF-heavy stage artifacts | Julia-native `.jls` artifacts + CSV / JSON sidecars | Closed Phase 9 contract; NetCDF remains out of scope |
| panel-first pipeline workflow | time-series-first pipeline workflow | Panel runner support is deferred beyond bounded Phase 9 |

**Recommendation:** Keep the first Epsilon runner thin and contract-driven.
Do not reopen panel, YAML-driven VI, or report-bundle semantics inside the
initial Phase 9 pipeline.

---

## Summary: Effort Estimation by Component

| Component | Complexity | Risk | Est. Effort |
|---|---|---|---|
| Adstock transforms | Low | Low | 1-2 days |
| Saturation transforms | Low | Low | 1 day |
| Batched convolution | Medium | Low | 1-2 days |
| Prior system | Medium | Medium | 3-5 days |
| Special priors | High | Medium | 5-7 days |
| Model builder / @model | High | High | 7-10 days |
| Config system (YAML) | Low | Low | 2-3 days |
| Fourier seasonality | Low | Low | 1 day |
| HSGP | High | **High** | 5-10 days |
| TVP (time-varying params) | Medium | Medium | 3-5 days |
| Panel / hierarchical | High | High | 5-7 days |
| MCMC sampling wrapper | Low | Low | 1-2 days |
| Variational inference | Medium | Medium | 3-5 days |
| Contribution decomposition | Medium | Low | 3-5 days |
| Response curves / metrics | Medium | Low | 2-3 days |
| Budget optimizer | Medium | Medium | 5-7 days |
| Pipeline (9 stages) | High | Medium | 10-15 days |
| Plotting (all charts) | Medium | Low | 7-10 days |
| IO / serialization | Low | Low | 2-3 days |
| **Total estimate** | | | **~70-100 days** |
