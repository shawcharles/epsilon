# Epsilon MMM

**Bayesian Marketing Mix Modeling in Julia**

Epsilon.jl is a Julia-native Bayesian Marketing Mix Modeling library built on
[Turing.jl](https://turing.ml/) and the Julia scientific computing ecosystem.
[Abacus](https://github.com/tandpds/abacus) is the major reference and
comparison baseline for the statistical MMM core, but Epsilon prioritizes
methodologically coherent Julia APIs over literal upstream fidelity.

> *A Julia-native MMM library informed by [Abacus](https://github.com/tandpds/abacus) - comparable statistical rigour where semantics match, with methodological coherence taking priority over literal upstream fidelity.*

## Status

**Abacus Julia port in progress** - Epsilon has substantial Julia
implementation work and fixture-backed parity in key layers, but broad Abacus
parity is not yet certified. Release preparation is paused until parity is
demonstrated against concrete Abacus demo-style runs rather than inferred from
module coverage.

The current implementation should be read with these labels:

- `ported`: implemented and parity-tested against Abacus semantics
- `native`: implemented intentionally differently in Julia
- `scaffolded`: API or module exists, but Abacus parity is not proven
- `missing`: Abacus behavior is not implemented yet, but remains in scope
  unless explicitly deferred
- `deferred`: intentionally not part of the current statistical/methodological
  port scope. Current explicit deferrals are variational inference, AI advisor,
  and Dash/dashboard parity for v1.

The active implementation plan is tracked in
[`ABACUS-PARITY-LEDGER.md`](.planning/ABACUS-PARITY-LEDGER.md). The first
release-quality target is not full Abacus product parity; it is the statistical
MMM core on the bundled `timeseries`, `geo_panel`, and `geo_brand_panel`
demo-style paths. Beyond explicitly deferred surfaces, Abacus statistical and
methodological functionality should be treated as in scope for the Julia port.

Current high-confidence parity is strongest in the lowest layers: convolution,
scaling, and selected adstock/transform behavior remain `ported` against
Abacus fixtures. Phase 14 has additionally closed ledger-backed fixture and
demo-replay parity for the `timeseries`, `geo_panel`, and `geo_brand_panel`
acceptance targets: config/data ingestion, model-spec metadata, deterministic
posterior replay, contribution/decomposition outputs, response/saturation/
adstock curves, marketing metrics, and pipeline Stage `00` through Stage `70`
artifact-key parity (where each stage is enabled) all pass the fixture/demo
gates recorded in
[`ABACUS-PARITY-LEDGER.md`](.planning/ABACUS-PARITY-LEDGER.md). This is not
full Abacus product parity: HSGP/time-varying parameters, Mundlak/correlated
random effects, calibration/lift tests, variational inference release support,
panel holdout validation, and free channel-by-panel optimization remain
`missing`, `scaffolded`, or `deferred` and are not implied by the above. Any
surface not listed in the ledger as `ported` or covered by a closed Phase 14
gate should still be treated as `scaffolded` until it has its own fixture or
demo acceptance test.

Historical phase notes below describe implemented Epsilon surfaces and past
methodology work. They are not, by themselves, Abacus parity claims.

The historical config value `media.saturation.type = "logistic"` currently
maps to Epsilon's centered logistic saturation curve,
`centered_logistic_saturation(x, lam) = tanh(lam * x / 2)`. The older
`logistic_saturation` function remains as a compatibility alias, but new code
should use the explicit centered name.

For panel models, Epsilon represents one or more declared panel dimensions on a
deterministic flat `panel_cell` axis with declared coordinate columns such as
`geo` and `brand`. Use `panel_axis(spec_or_result)`,
`panel_coordinates(spec_or_result)`, or
`panel_coordinate(spec_or_result, flat_index)` to recover named coordinates
such as `(geo = "UK", brand = "Alpha")` from that flat axis.
Use `ntime(data)`, `npanels(data)`, and `npanel_observations(data)` when panel
code needs to distinguish shared time rows from flattened panel-cell
observations; `nobs(::PanelMMMData)` remains the compatibility panel-cell count.

Phase 7 is now closed for the time-series surface: grouped time-series
`InferenceResults` from the v1-supported MCMC row can produce
`contribution_results`, `decomposition_results`, `response_curve_results`,
`saturation_curve_results`, `adstock_curve_results`, `metric_results`, and
`summary_table` through deterministic replay of the frozen additive model
terms. Earlier phase work also left scaffolded VI artefact consumers in the
codebase, but Phase 27 supersedes that as a v1 release-support claim. Stage 60
keeps three bounded curve families on the time-series path: forward-pass
response curves in target units, saturation-only curves in target units, and
adstock-only carryover curves in original channel-spend-equivalent units. Phase
14 has additionally landed bounded panel contribution/decomposition replay for
the `geo_panel` and `geo_brand_panel` gates, with `geo_brand_panel` preserving
Abacus `("geo", "brand")` dimension ordering on a deterministic flattened
panel-cell axis. Panel response,
saturation, adstock, and marketing-metric surfaces are now available as
panel-cell/channel artifacts: panel curves require an explicit `delta_grid`
and use Abacus-style historical-scaling semantics rather than an implicit
aggregate allocation rule. Panel optimization is supported on the bounded
historical-share policy: optimize channel totals while preserving each
channel's historical within-panel-cell spend shares. Free channel-by-panel
allocation remains deferred.

Phase 8 is now closed: `optimize_budget(results; ...)` is the canonical
fixed-budget optimization entry point on supported grouped time-series
`InferenceResults`, backed by the frozen posterior-mean response surface,
`JuMP.jl + Ipopt.jl`, typed `BudgetOptimizationResult` outputs,
`budget_impact_table(result)`, and `budget_audit_table(result)`. The
v1-supported optimization rows are MCMC-backed: `TimeSeriesMMM` + MCMC and the
bounded `PanelMMM` historical-share policy for `geo_panel` and
`geo_brand_panel`. Earlier VI optimisation wiring remains scaffolded
implementation history, not a v1 release-support row.

The bounded non-UI scenario planner now supports typed current, manual
allocation, and fixed-budget optimized scenario specs. `evaluate_manual_scenario`
evaluates `TimeSeriesMMM` manual channel allocations against existing response
surfaces without refitting or solving, and `scenario_plan` can project current,
manual-allocation, and solved optimization rows into deterministic comparison
tables when the supplied artifacts match. Panel manual allocation, arbitrary
future spend-path simulation, hosted/background scenario stores, automatic
scenario refits, and Dash/UI workflows remain outside this surface.

Phase 9 is now closed: `run_pipeline(PipelineRunConfig(...))` and
`pipeline_main(args = ARGS)` are the canonical bounded pipeline entry points,
and the repo now ships a thin `bin/epsilon` wrapper for the same `epsilon run
config.yml` path. The closed pipeline surface is time-series-first and
MCMC-only, runs the full fixed Stage `00`-`70` sequence, preserves blocked
holdout validation as a side branch off the full-sample fit path, writes
stage-local `png` plots alongside the corresponding stage artifacts, and keeps
YAML-driven VI explicitly unsupported. Panel pipeline orchestration is
currently bounded to metadata, fit, assessment, decomposition, diagnostics, and
curves, plus explicitly enabled historical-share optimization: `PanelMMM`
configs can emit Stage `00` metadata/manifest artifacts, Stage `20` fit
artifacts, Stage `30` assessment artifacts, Stage `40` decomposition artifacts,
Stage `50` diagnostics artifacts, Stage `60` response-curve artifacts, and
Stage `70` historical-share optimization artifacts, while unsupported panel
stages are explicitly skipped until their artifact semantics are fixture-backed.
Phase 14 has begun
fixture-backed Abacus pipeline parity on the `timeseries`, `geo_panel`, and
`geo_brand_panel` paths: Epsilon now
exports Abacus-compatible Stage `00` metadata files, records the Abacus `idata`
fit artifact key as a Julia-native grouped `InferenceResults` artifact, and
writes Stage `30` through Stage `70` artifacts under Abacus-compatible names
for assessment, holdout validation, decomposition, diagnostics, response
curves, and optimization. PyMC/NetCDF-specific Abacus artifacts map to
Julia-native serialized artifacts where direct file identity would be
misleading. These time-series pipeline keys and the `geo_panel` /
`geo_brand_panel` Stage `00` metadata, Stage `20` fit, Stage `30` assessment,
Stage `40` decomposition, Stage `50` diagnostics, and Stage `60` response-curve
keys plus explicitly enabled Stage `70` historical-share optimization keys are
validated against exported Abacus pipeline manifest contracts.

Phase 10 is now closed: the bounded `CairoMakie` plotting surface is in the
package through `epsilon_theme()`, `trace_plot`,
`posterior_density_plot`, `prior_posterior_plot`, `observed_fitted_plot`,
`residual_diagnostics_plot`, `contribution_plot`, `contribution_area_plot`,
`decomposition_plot`, `response_curve_plot`, `saturation_curve_plot`,
`adstock_curve_plot`, `budget_optimization_plot`, and `write_plot_bundle(run)`.
Those direct plotting APIs return Makie `Figure` objects and save through
direct `png`, `svg`, or `pdf` exports; the bounded bundle helper is a
deterministic `png`-only export over successful pipeline runs after the
pipeline has already written stage-local plots into the Stage `10`-`70`
directories. The frozen plotting support matrix remains intentionally narrower than
Dash/dashboard parity: diagnostics consume grouped `InferenceResults`, post-model
visuals consume the closed Phase 7 typed result surfaces, optimization visuals
consume `BudgetOptimizationResult`, VI trace plots stay unsupported, and panel
post-model/optimization plotting is not yet supported on the current bounded
slice.

Phase 11 landed the release-gate infrastructure: the harness distinguishes
Abacus-reference time-series MCMC rows from bounded Epsilon-only panel,
pipeline, and plotting rows. Historical VI validation scaffolding is superseded
by Phase 27's v1 boundary. The compact final validation fixtures provide one
explicit maintainer-facing harness over the closed surface, the retained
Phase 7/8 comparison fixtures remain the hard numeric gate for detailed
post-model and optimization cross-checks where semantics actually match, and
the frozen benchmark suite now publishes its methodology plus the committed
`benchmark/results/reference_machine.*` snapshot without making a blanket
faster-than-Abacus claim. Phase 12 has now closed the methodology gap on the
bounded release story and narrowed the parity claim where semantics still
diverge.

Release docs:

- supported surface, unsupported rows, validation method, and
  `v1.0.0-rc1` readiness checklist:
  [`docs/src/release.md`](docs/src/release.md)
- benchmark methodology and published reference-machine results:
  [`docs/src/benchmarks.md`](docs/src/benchmarks.md)

## Demo Data And Runner

The repo now ships a bounded demo/comparison surface under
[`examples/demo/`](examples/demo/README.md):

- copied Abacus reference datasets for `timeseries`, `geo_panel`, and
  `geo_brand_panel`
- a shared copied `holidays.csv` reference file for cross-framework
  comparisons
- an Epsilon-native runnable time-series config on the same reference data
- a thin Julia runner:
  `julia --project=. examples/demo/run_demo.jl run timeseries`

This stays truthful to the closed v1 support matrix. The copied panel bundles
are included as reference datasets/configs for comparison work, but the shipped
demo runner is time-series-only because the public pipeline remains
time-series-first. Successful demo runs write stage-local plots directly into
the run directory. The copied Abacus time-series demo remains a useful
reference baseline. The shipped Epsilon demo now uses the coherent native
automatic holiday path (`holidays.mode = "auto"` with one pooled holiday
component), but that native design should not be described as Abacus parity
unless a separate compatibility mode with matching semantics is introduced.

## Supported Phase 5 Matrix

### Supported bundles

| ID | Model | Seasonality | Trend | Events | Controls | Status | Notes |
|---|---|---|---|---|---|---|---|
| `TS-00` | `TimeSeriesMMM` | `none` | `none` | `none` | `none` | Supported | Base time-series media path |
| `TS-01` | `TimeSeriesMMM` | `fourier` | `none` | `none` | `none` | Supported | Requires `seasonality.n_order` |
| `TS-02` | `TimeSeriesMMM` | `fourier` | `linear` | `none` | `none` | Supported | `trend.priors.beta` optional |
| `TS-03` | `TimeSeriesMMM` | `fourier` | `linear` | `events.columns` | `none` | Supported | Manual event matrix via `MMMData.events` |
| `TS-04` | `TimeSeriesMMM` | `fourier` | `changepoint` | `events.windows` | `none` | Supported | Requires `trend.n_changepoints` |
| `TS-05` | `TimeSeriesMMM` | `fourier` | `none` | `none` | `controls.transform = "standardize"` | Supported | Requires `media.controls` |
| `P-00` | `PanelMMM` | `none` | `none` | `none` | `none` | Supported | Flat panel-cell axis, shared media betas, hierarchical panel intercept offsets |

### Explicitly unsupported in Phase 5

| ID | Model | Combination | Status | Reason |
|---|---|---|---|---|
| `TS-U1` | `TimeSeriesMMM` | `seasonality.type = "hsgp"` | Unsupported | HSGP is not yet implemented on the Phase 5 surface |
| `P-U1` | `PanelMMM` | any panel seasonality | Unsupported | Fourier/HSGP seasonality is not yet fully exposed on the panel path |
| `P-U2` | `PanelMMM` | any panel trend | Unsupported | Linear/changepoint trend is not yet exposed on the panel path |
| `P-U3` | `PanelMMM` | any panel events | Unsupported | `events.columns` / `events.windows` are not yet exposed on the panel path |
| `P-U4` | `PanelMMM` | any panel richer controls | Unsupported | `controls.transform` is not yet exposed on the panel path |

Current key-level contract:

- `seasonality.type = "fourier"` requires `seasonality.n_order`
- `trend.type = "linear"` or `trend.type = "changepoint"`; changepoints require `trend.n_changepoints`
- `events` supports either `events.columns` or `events.windows`
- `controls.transform = "standardize"` is layered on top of `media.controls`
- `PanelMMM` accepts one or more `dimensions.panel` entries by using a deterministic flat panel-cell axis; prediction expects the fitted `panel_names` in the same order

## Phase 6 Inference Matrix

### Supported rows

| ID | Model | Backend | Entry Point | `predict` | `prior_predict` | `model_results` | `inference_results` | Diagnostics | Notes |
|---|---|---|---|---|---|---|---|---|---|
| `INF-TS-MCMC` | `TimeSeriesMMM` | Turing / NUTS | `fit!` | Supported | Supported | Supported | Supported | Supported | Canonical MCMC path; YAML `fit` remains mapped here |
| `INF-P-MCMC` | `PanelMMM` | Turing / NUTS | `fit!` | Supported | Supported | Supported | Supported | Supported | Bounded panel slice only; seasonality/trend/events/richer controls still excluded |

### Explicitly unsupported in Phase 6

| ID | Combination | Status | Reason |
|---|---|---|---|
| `INF-U1` | `PanelMMM` + `approximate_fit!` | Unsupported | Panel VI is not implemented in the bounded Phase 6 surface |
| `INF-U2` | YAML-driven VI or mixed-backend `fit!` semantics | Unsupported | YAML `fit` and `SamplerConfig` remain MCMC-only |
| `INF-U3` | VI-backed `model_results`, `model_diagnostics`, `sampler_diagnostics`, `convergence_report`, `convergence_warnings` | Unsupported | These remain MCMC/Turing-only surfaces |
| `INF-U5` | `approximate_fit!` / `VariationalConfig` as a v1 release-supported backend | Unsupported | The exports remain scaffolded pre-v1 review surfaces, but Phase 27 keeps v1 inference support MCMC-only |
| `INF-U4` | NetCDF / ArviZ-native grouped export | Unsupported | Deferred from Phase 6; `InferenceResults` is the canonical grouped artifact |

## Phase 7 Post-Model Matrix

### Supported rows

| ID | Model | Backend | Contributions / Decomposition | Response / Metrics | `summary_table` | Notes |
|---|---|---|---|---|---|---|
| `POST-TS-MCMC` | `TimeSeriesMMM` | Turing / NUTS | Supported | Supported | Supported | Consumes canonical grouped `InferenceResults` through deterministic replay |
| `POST-P-MCMC` | `PanelMMM` | Turing / NUTS | Supported | Supported with explicit `delta_grid` | Supported | Bounded panel replay covered by `geo_panel` and `geo_brand_panel` validation gates; panels use a fixed flat `panel_cell` axis plus declared coordinate columns in contribution, curve, and metric summaries |

### Explicitly unsupported in Phase 7

| ID | Combination | Status | Reason |
|---|---|---|---|
| `POST-U2` | Flat `ModelResults` as the canonical post-model input | Unsupported | Phase 7 consumes grouped `InferenceResults` directly |
| `POST-U3` | Post-model outputs without grouped posterior/spec/observed-data state | Unsupported | Deterministic replay requires the frozen grouped artifact contract |
| `POST-U4` | VI-backed post-model outputs as v1 release-supported rows | Unsupported | Historical implementation artefacts remain scaffolded; v1 post-model support is MCMC-only |

## Phase 8 Optimization Matrix

### Supported rows

| ID | Model | Backend | Entry Point | Comparison / Audit Outputs | Notes |
|---|---|---|---|---|---|
| `OPT-TS-MCMC` | `TimeSeriesMMM` | Turing / NUTS | `optimize_budget(results; ...)` | Supported | Fixed-budget equality plus absolute and reference-relative bounds on grouped MCMC `InferenceResults` |
| `OPT-P-MCMC` | `PanelMMM` | Turing / NUTS | `optimize_budget(results; panel_allocation_mode = :historical_shares, ...)` | Supported | Optimizes channel totals, reuses panel response curves through shared channel deltas, and preserves historical within-channel panel-cell spend shares |

### Explicitly unsupported in Phase 8

| ID | Combination | Status | Reason |
|---|---|---|---|
| `OPT-U2` | Objectives other than `:total_response` | Unsupported | Phase 8 freezes one posterior-mean total-response objective |
| `OPT-U3` | Constraint families beyond total-budget equality, absolute bounds, and reference-relative guardrails | Unsupported | Pairwise ratios, pacing, and multi-objective trade-offs are not yet implemented |
| `OPT-U4` | VI-backed optimisation as a v1 release-supported row | Unsupported | Historical implementation artefacts remain scaffolded; v1 optimisation support is MCMC-only |

## Why Julia?

| | Python (Abacus) | Julia (Epsilon) |
|---|---|---|
| Probabilistic Programming | PyMC / PyTensor | Turing.jl |
| MCMC Sampling | NUTS (via PyMC/nutpie/NumPyro) | DynamicHMC.jl / AdvancedHMC.jl |
| Autodiff | PyTensor graph-mode | Native (ForwardDiff.jl / ReverseDiff.jl) |
| Tensor Operations | PyTensor / NumPy | Native arrays + LinearAlgebra stdlib |
| Performance | Interpreted + JIT (JAX path) | JIT-compiled (LLVM) |
| Variational Inference | PyMC ADVI | AdvancedVI.jl scaffold exists; out of scope for v1 support |
| Gaussian Processes | PyMC GP / HSGP | AbstractGPs.jl / KernelFunctions.jl |
| Diagnostics | ArviZ | MCMCChains.jl / MCMCDiagnosticTools.jl |
| Optimization | scipy.optimize | Optim.jl / JuMP.jl |
| Plotting | Matplotlib / Seaborn | Makie.jl |
| Data Handling | Pandas / xarray | DataFrames.jl |

## Project Planning

See [`.planning/`](.planning/README.md) for the full GSD board, architecture plan,
and component mapping.

## Technical Standards

Project standards live in
[`TECHNICAL-STANDARDS.md`](TECHNICAL-STANDARDS.md).
The short version:

- follow the official Julia style guide
- use the SciML Style Guide as the package-level default
- enforce formatting with `Runic.jl`
- keep docs, tests, and compat bounds in lockstep with code changes

## License

Apache License 2.0
