# Epsilon.jl

`Epsilon.jl` is a Julia-native framework for Bayesian marketing mix modeling.
It is now a bounded, ledger-governed Julia MMM library rather than an initial
package scaffold. It stands as an independent Julia MMM library with
comparison-backed validation where an external reference implementation has
matching statistical and methodological behavior. Parity is claimed only where
the committed evidence and `.planning/ABACUS-PARITY-LEDGER.md` support that
claim.

## Current Status

Epsilon is documented through Phase 43. The current supported fitting contract
is MCMC/Turing only; the former variational surface was permanently retired in
Phase 38. Phases 39 through 43 added local supported-path confidence evidence
and documentation for the toy MCMC and fixed-schema CSV quickstart workflows,
including compact sidecars, trusted-local artifact roundtrips, and the canonical
[Supported Local Workflows](supported_paths.md) runbook. Those workflows are
not benchmarks, release evidence, or reference-parity evidence.

The historical phase detail below remains useful context for the current
surface:

- package entry point
- test harness
- docs scaffold
- repository standards
- transform primitives completed
- prior and distribution layer completed
- model-core layer completed
- typed model/config scaffolding completed
- bounded `TimeSeriesMMM` and `PanelMMM` feature surface frozen at Phase 5 closeout
- Phase 6 `06-01` landed: the current MCMC fit path now records explicit
  execution-policy metadata and replaces stale successful fit state with an
  explicit error state when `fit!` fails
- Phase 6 `06-02` landed: canonical grouped `InferenceResults` artifacts now
  preserve posterior draws, optional prior draws, predictive draws, sampler
  statistics, observed data, and coordinate metadata without redefining the
  flatter `ModelResults` convenience surface
- Phase 6 is now closed historically: `fit!` is the canonical MCMC path and
  `InferenceResults` is the canonical grouped artifact surface. Its former
  variational implementation was permanently removed in Phase 38.
- Phase 7 is now closed: grouped time-series `InferenceResults` can now
  produce `contribution_results`, `decomposition_results`,
  `response_curve_results`, `metric_results`, and `summary_table` on the
  v1-supported MCMC row through deterministic replay of the frozen Phase 5
  additive model contract; the former variational artifacts were permanently
  retired in Phase 38. Response curves use
  total-spend grids in original units and preserve the observed temporal spend
  shape for the selected channel
- Phase 8 is now closed for time-series optimization, and Phase 14 adds a
  bounded panel extension: `optimize_budget(results; ...)` is the canonical
  fixed-budget optimization entry point on supported grouped `InferenceResults`,
  backed by posterior-mean response surfaces, `JuMP.jl + Ipopt.jl`, typed
  `BudgetOptimizationResult` / `PanelBudgetOptimizationResult` outputs,
  `budget_impact_table(result)`, and `budget_audit_table(result)`. Panel
  optimization allocates channel totals and preserves historical within-channel
  panel-cell spend shares; free channel-by-panel allocation remains deferred.
- Phase 9 is now closed: `run_pipeline(PipelineRunConfig(...))` and
  `pipeline_main(args = ARGS)` are the canonical bounded pipeline entry
  points, and the repo now ships a thin `bin/epsilon` wrapper for the same
  `epsilon run config.yml` path. The closed time-series pipeline surface is
  MCMC-only, runs the fixed Stage `00`-`70` sequence, preserves blocked
  holdout validation as a side branch off the full-sample fit path, writes
  stage-local `png` plots beside the corresponding stage artifacts, and rejects
  retired variational-shaped configuration keys. The pipeline also supports reference-style
  optional Stage `05` prior-sensitivity planning: it writes resolved scenario
  configs plus human and LLM-safe manifests, but does not refit every scenario
  automatically. Panel pipeline orchestration is currently bounded to metadata,
  optional prior-sensitivity planning, fit, assessment, decomposition,
  diagnostics, curves, and explicitly enabled historical-share optimization:
  `PanelMMM` configs can emit Stage `00` metadata/manifest
  artifacts, Stage `20` fit artifacts, Stage `30` assessment artifacts, Stage
  `40` decomposition artifacts, Stage `50` diagnostics artifacts, and Stage
  `60` response-curve artifacts plus Stage `70` optimization artifacts for
  channel-level historical-share panel allocation, while unsupported panel
  stages are skipped until their artifact semantics are fixture-backed. Stage
  `35` panel holdout validation is explicitly deferred for v1 rather than
  added for parity alone; time-series blocked holdout validation remains
  supported.
- Phase 10 is now closed and Phase 68 makes plotting an optional extension: load
  `using Epsilon, CairoMakie` before calling bounded plot functions such as
  `trace_plot`, `contribution_plot`, `response_curve_plot`, and
  `budget_optimization_plot`, or before expecting stage-local pipeline PNGs and
  `write_plot_bundle(run)` exports. Without the backend, direct plot calls fail
  clearly and pipeline non-plot artifacts remain available while plot paths are
  omitted with stage warnings. The plotting support matrix remains intentionally
  narrower than Dash parity: it is time-series-first for post-model visuals,
  supports channel-level budget optimization plots for time-series and bounded
  panel optimization results, has no variational plotting path, and bounds the
  report bundle to deterministic `png` export over successful pipeline runs
- Phase 10 `10-01` is now landed: `epsilon_theme()` plus the bounded
  diagnostic plotting surface now ship on top of grouped `InferenceResults`.
  `trace_plot(results)` is the MCMC-only posterior trace view. `posterior_density_plot`,
  `prior_posterior_plot`, `observed_fitted_plot`, and
  `residual_diagnostics_plot` now return Makie `Figure` objects and save
  through direct `png`, `svg`, or `pdf` exports. Time-series observed/fitted
  and residual plots consume the frozen grouped posterior-predictive surface;
  panel diagnostic plotting remains explicitly unsupported in the current
  bounded Phase 10 slice
- Phase 10 `10-02` is now landed: post-model plotting now renders directly from
  `ContributionResults`, `DecompositionResults`, and `ResponseCurveResults`
  through `contribution_plot`, `contribution_area_plot`, `decomposition_plot`,
  and `response_curve_plot`. The current bounded row remains time-series first,
  and those figures work on the v1-supported MCMC post-model artifacts where
  the underlying typed Phase 7 surface exists. The former variational plotting
  path was permanently removed. Panel
  post-model plotting remains explicitly unsupported
- Phase 10 `10-03` is now landed and closes Phase 10: optimization plotting
  now renders directly from `BudgetOptimizationResult` through
  `budget_optimization_plot`, and `write_plot_bundle(run)` now exports the
  bounded deterministic `png` bundle over successful Phase 9 pipeline runs.
  The pipeline itself writes stage-local plots during Stage `10`-`70`
  execution; the bundle helper is the separate curated export over those same
  saved artifacts. It keeps optimization plots optional when the optimization
  stage is skipped and uses the fixed parameter-selection policy for
  diagnostic figures and per-parameter prior-versus-posterior files
- Phase 11 landed the release-gate infrastructure: compact final validation
  fixtures, a maintainer-facing release harness, a frozen benchmark runner,
  and published reference-machine results for the bounded v1 workload matrix.
- Phase 12 is now closed: the final validation harness has been rerun on the
  repaired methodology, the guaranteed reference-backed row remains
  `VAL-TS-00-MCMC`, and the holiday-bearing automatic-holiday row is now
  documented honestly as an Epsilon-native/reference row unless a separate
  compatibility mode is added.
- Phase 13 remediation is now closed for the accepted contract fixes: fitted
  time-series trend and automatic-holiday date-basis state is carried in model
  specs and reused for prediction/replay, unfitted prior prediction resolves
  scale and date-derived feature state from `model.data`, media/channel arrays
  must be finite and nonnegative, spend-domain saturation primitives reject
  negative `x` with `ArgumentError`, and pipeline YAML rejects unsupported
  top-level keys. `tanh_saturation` remains a signed low-level transform
  primitive, but public MMM media/spend surfaces reject negative values before
  replay. Specifically, `centered_logistic_saturation`,
  `logistic_saturation`, `michaelis_menten`, and `hill_function` require
  nonnegative `x`. Public model config parsing now also rejects unsupported
  top-level keys instead of silently storing typo-like entries in
  `ModelConfig.extras`; the retained `validation` extra is a narrow
  compatibility allowance, not a general YAML extension escape hatch. Opaque
  local state should be supplied programmatically through
  `ModelConfig(extras = ...)`.
- Epsilon now explicitly prioritizes the most methodologically coherent bounded
  Julia design over literal upstream fidelity when those goals conflict.
- current backend coverage: geometric, delayed, binomial, or Weibull adstock with centered logistic, tanh, Michaelis-Menten, or hill saturation, plus Fourier seasonality, bounded `linear` and `changepoint` trend paths, manual `events.columns` and generated `events.windows` event matrices, and a bounded `controls.transform = "standardize"` path on `TimeSeriesMMM`; plus a bounded `PanelMMM` path that can represent one or more declared panel dimensions through a deterministic flat panel-cell axis, shared media coefficients, hierarchical panel intercept offsets, contribution/decomposition replay, panel-cell response/metric surfaces with explicit `delta_grid` historical scaling, pipeline Stage `00` metadata artifacts, Stage `20` fit artifacts, Stage `30` assessment artifacts, Stage `40` decomposition artifacts, Stage `50` diagnostics artifacts, Stage `60` response-curve artifacts, and explicitly enabled Stage `70` historical-share optimization. The public config value `media.saturation.type = "logistic"` maps to Epsilon's centered logistic curve for compatibility. Panel seasonality, trend, events, richer controls, and free panel allocation are not yet exposed on that panel path; Stage `35` panel holdout validation is deliberately deferred for v1.
- the time-series pipeline now validates reference-compatible Stage `00`
  through Stage `70` artifact keys against an exported local reference
  `timeseries` manifest contract; backend-specific NetCDF/PyMC artifacts are mapped
  to Epsilon's typed Julia-native serialized artifacts rather than treated as
  byte-for-byte file-format parity. Optional Stage `05` prior-sensitivity
  planning is supported as a scenario-config and manifest stage, not as an
  automatic multi-fit comparison loop.
- the `geo_panel` and `geo_brand_panel` pipelines now validate Stage `00`
  metadata/manifest keys, Stage `20` fit artifact keys, Stage `30` assessment
  artifact keys, Stage `40` decomposition artifact keys, Stage `50`
  diagnostics artifact keys, and Stage `60` response-curve artifact keys
  against exported local reference manifest contracts, and both also validate
  Stage `70` historical-share optimization artifacts (including the
  multidimensional `geo`/`brand` coordinate columns in the
  `channel_panel_allocation` table for `geo_brand_panel`) against exported
  local reference panel manifest contracts, with unsupported panel stages
  explicitly skipped
- the bounded non-UI scenario planner surface now provides typed current,
  manual-allocation, and fixed-budget optimized scenario specs plus
  `scenario_plan(result)` tables over solved budget optimization results. It
  also evaluates time-series manual allocations against existing fitted
  response surfaces and projects evaluated manual scenarios into
  `ScenarioPlanResult` tables without refitting or re-optimizing. Compatible
  evaluated manual scenarios and one solved fixed-budget optimization result
  can also be compared in a single deterministic plan. The surface
  mirrors reusable business-planning store semantics without Dash UI,
  background jobs, automatic scenario refits, or free panel allocation
- the bounded calibration surface now supports `TimeSeriesMMM` MCMC
  calibration likelihood terms for centered-logistic lift-test measurements and
  cost-per-target soft penalties. Calibration terms are optional, additive,
  scaled into model space, and fixture-backed against comparable reference helper
  semantics. Public dict/YAML configs and the bounded time-series MCMC pipeline
  path can now carry those calibration terms into model construction.
  `PanelMMM` calibration, non-logistic lift-test saturation
  families, Dash/UI workflows, and AI-advisor behaviour remain unsupported.
- a bounded, programmatic-only `TimeSeriesMMM` MCMC shared-media HSGP
  multiplier is available with retained date/cadence replay state and
  trusted-local Julia serialisation validation. On the exact retained training
  grid, grouped posterior `contribution_results` and `decomposition_results`
  report posterior-conditional HSGP-adjusted model allocations; they are not
  causal effects, realised-target decompositions, or forecast attribution.
  Existing summary and contribution/decomposition plots consume those result
  objects. YAML/pipeline configuration, panels, calibration,
  Michaelis-Menten, channel-specific/intercept/multidimensional/periodic HSGP,
  TVP, curves, saturation/adstock diagnostics, and metrics remain unsupported.

## Release Gate

The canonical release-gate summary lives in [Release Gate](release.md). It
defines the Phase 11 infrastructure and the now-closed Phase 12 reconciliation:

- the supported v1 surface
- explicit unsupported rows
- the Phase 11 validation split between reference-backed rows and Epsilon-only
  contract-validation
- the `v1.0.0-rc1` readiness checklist

Benchmark methodology and published reference-machine results live in
[Benchmarks](benchmarks.md).

## Toy MCMC Smoke Demo

The fastest supported-path smoke check is the synthetic toy model:

```bash
julia --project=. examples/toy_mmm/run_toy_mmm.jl --draws 8 --tune 8 --output-dir "$(mktemp -d)"
```

This fits a tiny `TimeSeriesMMM` through the supported Turing/NUTS MCMC path,
extracts grouped inference results without prior or predictive groups, and
writes compact contribution and metric summaries when an output directory is
provided. It is not release evidence, not a benchmark, not a reference-parity
claim, and not a broader support expansion.

The canonical local runbook for the toy example, the fixed-schema CSV
quickstart, compact sidecars, trusted-local artifact roundtrips, and
`make smoke` is [Supported Local Workflows](supported_paths.md).

## Demo Data

The canonical Epsilon-native config-driven demo bundles live under
`data/demo/`. Run the canonical time-series bundle with:

```bash
julia --project=. runme.jl data/demo/timeseries/config.yml --quick
```

The runner delegates to `pipeline_main`; bundle-local `dataset.csv` and
`holidays.csv` paths stay owned by the YAML config. As a human-facing command,
`runme.jl` prints the Epsilon header, a compact run context, stage progress
bars, and a structured final summary. Maintainers can check all bundled demo
configs locally with:

```bash
make smoke-demo-configs
```

That command runs the time-series demo config through a tiny headless pipeline,
including validation, and checks the panel configs through
config/data/model-spec construction without panel MCMC sampling. It is local
workflow evidence only, not a benchmark, release gate, or reference-parity
claim.

The older comparison surface under `examples/demo/` is retained for
historical/reference comparison material:

- copied reference datasets for `timeseries`, `geo_panel`, and
  `geo_brand_panel`
- one shared copied `holidays.csv` file for cross-framework comparisons
- a legacy Epsilon-native runnable time-series config over the same reference
  data
- `julia --project=. examples/demo/run_demo.jl run timeseries`

This does not reopen the support matrix. The legacy helper is time-series-only,
while the panel bundles are included as reference data/configs for comparison
work. The copied time-series demo remains a useful reference baseline. The
helper uses the coherent native automatic holiday path, so it should be treated
as a bounded Epsilon comparison workflow rather than as proof of end-to-end
reference parity on the holiday-bearing row.

## Phase 7 Post-Model Matrix

### Supported rows

| ID | Model | Backend | Contributions / Decomposition | Response / Metrics | `summary_table` | Notes |
|---|---|---|---|---|---|---|
| `POST-TS-MCMC` | `TimeSeriesMMM` | Turing / NUTS | Supported | Supported | Supported | Consumes canonical grouped `InferenceResults` through deterministic replay |
| `POST-P-MCMC` | `PanelMMM` | Turing / NUTS | Supported | Supported with explicit `delta_grid` | Supported | Bounded panel replay covered by `geo_panel` and `geo_brand_panel` validation gates; panels use a fixed flat `panel_cell` axis plus declared coordinate columns in contribution, curve, and metric summaries |

### Post-Model Axis Contracts

Post-model artifacts are draw-level arrays with fixed axis orders. Summary
tables validate these contracts before materializing tidy tables:

| Result type | Time-series axes | Panel axes | Panel grid / metadata contract |
|---|---|---|---|
| `ContributionResults.values` | `(draw, observation, component)` | `(draw, time, panel, component)` | Panel summaries include `panel_cell` plus declared coordinate columns |
| `DecompositionResults.totals`, `shares` | `(draw, component)` | `(draw, component)` | Panel contributions are aggregated over time and panel cells before decomposition |
| `ResponseCurveResults.values` | `(draw, spend_point)` | `(draw, panel, spend_point)` | Panel `spend_grid` is `(panel, spend_point)` and `spend_share_grid` is the shared `delta_grid` |
| `SaturationCurveResults.values` | `(draw, spend_point)` | `(draw, panel, spend_point)` | Same panel grid contract as response curves |
| `AdstockCurveResults.values` | `(draw, spend_point)` | `(draw, panel, spend_point)` | Same panel grid contract as response curves |
| `MetricResults.values` | `(draw, spend_point, metric)` | `(draw, panel, spend_point, metric)` | Panel metrics inherit the response-curve `(panel, spend_point)` spend grid |

For panel curves, `delta_grid` values are historical spend multipliers. They
are not absolute spend values and they do not authorize arbitrary free
channel-by-panel allocation.

### Explicitly unsupported in Phase 7

| ID | Combination | Status | Reason |
|---|---|---|---|
| `POST-U2` | Flat `ModelResults` as the canonical post-model input | Unsupported | Phase 7 consumes grouped `InferenceResults` directly |
| `POST-U3` | Post-model outputs without grouped posterior/spec/observed-data state | Unsupported | Deterministic replay requires the frozen grouped artifact contract |
| `POST-U4` | Retired-backend post-model outputs | Retired | Retired backend artifacts are rejected before post-model use |

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
| `OPT-U3` | Constraint families beyond total-budget equality, absolute bounds, and reference-relative guardrails | Unsupported | Pairwise ratios, pacing, and multi-objective trade-offs are deferred |
| `OPT-U4` | Free channel-by-panel allocation or panel-total bounds | Unsupported | Panel response curves are valid for shared within-channel historical deltas; arbitrary panel allocation needs a separate validity contract |
| `OPT-U5` | Retired-backend optimisation | Retired | Retired backend artifacts are rejected before optimisation |

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
| `TS-U1` | `TimeSeriesMMM` | `seasonality.type = "hsgp"` | Unsupported | HSGP is deferred from the Phase 5 surface |
| `P-U1` | `PanelMMM` | any panel seasonality | Unsupported | Fourier/HSGP seasonality is not yet exposed on the panel path |
| `P-U2` | `PanelMMM` | any panel trend | Unsupported | Linear/changepoint trend is not yet exposed on the panel path |
| `P-U3` | `PanelMMM` | any panel events | Unsupported | `events.columns` / `events.windows` are not yet exposed on the panel path |
| `P-U4` | `PanelMMM` | any panel richer controls | Unsupported | `controls.transform` is not yet exposed on the panel path |

Current key-level contract:

- `seasonality.type = "fourier"` requires `seasonality.n_order`
- `trend.type = "linear"` or `trend.type = "changepoint"`; changepoints require `trend.n_changepoints`
- `events` supports either `events.columns` or `events.windows`
- `controls.transform = "standardize"` is layered on top of `media.controls`
- `PanelMMM` accepts one or more `dimensions.panel` entries by using a deterministic flat panel-cell axis; prediction expects the fitted `panel_names` in the same order

### Panel Coordinate Mapping

`PanelMMM` stores model tensors on one flat panel-cell axis. The analyst-facing
flat axis is always named `panel_cell`; declared panel dimensions such as `geo`
or `brand` are coordinate columns attached to that axis. For multidimensional
panels, Epsilon also keeps the legacy internal `panel` coordinate in metadata
for compatibility with existing tensor names.

Use `panel_axis(metadata_or_result)` or `panel_axes(metadata_or_result)` to
inspect the ordered `PanelAxis` contract, and `panel_coordinates` to recover the
one-based flat index, flat panel label, and named coordinates for each panel
cell. The ordering is the declared panel-dimension order, with earlier
dimensions varying more slowly. For example, `("geo", "brand")` with geos
`UK, FR` and brands `Alpha, Beta` maps to `UK|Alpha`, `UK|Beta`, `FR|Alpha`,
`FR|Beta`.

!!! warning "Panel Observation Counts"
    `nobs(::PanelMMMData)` currently returns flattened panel-cell observations,
    `ntime(data) * npanels(data)`, to preserve existing model-spec and pipeline
    artifact contracts. Use `ntime(data)`, `npanels(data)`, and
    `npanel_observations(data)` when code needs explicit panel axis semantics.

## Phase 6 Inference Matrix

### Supported rows

| ID | Model | Backend | Entry Point | `predict` | `prior_predict` | `model_results` | `inference_results` | Diagnostics | Notes |
|---|---|---|---|---|---|---|---|---|---|
| `INF-TS-MCMC` | `TimeSeriesMMM` | Turing / NUTS | `fit!` | Supported | Supported | Supported | Supported | Supported | Canonical MCMC path; YAML `fit` remains mapped here |
| `INF-P-MCMC` | `PanelMMM` | Turing / NUTS | `fit!` | Supported | Supported | Supported | Supported | Supported | Bounded panel slice only; seasonality/trend/events/richer controls still excluded |

### Explicitly unsupported in Phase 6

| ID | Combination | Status | Reason |
|---|---|---|---|
| `INF-U1` | Variational fitting | Retired | Epsilon permanently supports only MCMC/Turing fitting |
| `INF-U2` | Retired inference-shaped configuration or mixed-backend `fit!` semantics | Retired | Parsers reject variational-shaped keys and non-MCMC backends |
| `INF-U3` | Retired-backend artifacts | Retired | Loaders reject non-Turing backend metadata before consumer use |
| `INF-U4` | NetCDF / ArviZ-native grouped export | Unsupported | Deferred from Phase 6; `InferenceResults` is the canonical grouped artifact |
| `INF-U5` | Variational inference backend | Retired | Permanently removed before release; no compatibility API is retained |

## Working Principles

- Preserve statistical correctness and stable model behavior.
- Prefer Julia-native APIs, multiple dispatch, and explicit types.
- Keep the public API small until each layer is stable.
- Treat autodiff compatibility and numerical tests as first-class constraints.

## Planning

Project planning documents live under `.planning/` in the repository root.

## Standards

Repository standards are defined in `TECHNICAL-STANDARDS.md`.

## Internal Optimization Contract

Phase 8 keeps the solver-agnostic optimization contract explicit underneath the
public `optimize_budget(results; ...)` surface.

```@docs
Epsilon.BudgetChannelConstraint
Epsilon.BudgetConstraintAudit
Epsilon.BudgetChannelSurface
Epsilon.BudgetOptimizationProblem
Epsilon._build_budget_optimization_problem
Epsilon._evaluate_budget_objective
```

## Pipeline Contract

Phase 9 is now closed. The bounded pipeline contract is frozen through the
fixed Stage `00`-`70` surface, with stage-local plot artifacts emitted into
the corresponding run directories. Phase 14 now also exports the reference
`timeseries` pipeline manifest contract as a Julia fixture and checks the
supported Stage `00` through Stage `70` artifact keys against reference names,
with Julia-native artifact formats retained where the reference implementation uses
PyMC/NetCDF-specific files.

```@docs
Epsilon.PipelineRunConfig
Epsilon.PipelineStageRecord
Epsilon.PipelineRunResult
Epsilon.PipelineValidationResult
Epsilon.pipeline_main
Epsilon.run_pipeline
```

## Plotting Foundation

Phase 10 has landed the bounded diagnostic plotting foundation on grouped
`InferenceResults`. Phase 68 moves the CairoMakie-backed implementation behind
an optional extension; load `using Epsilon, CairoMakie` before calling these
functions.

```@docs
Epsilon.epsilon_theme
Epsilon.trace_plot
Epsilon.posterior_density_plot
Epsilon.prior_posterior_plot
Epsilon.observed_fitted_plot
Epsilon.residual_diagnostics_plot
```

## Post-Model Plotting

Phase 10 now also includes the first bounded plotting layer over the closed
Phase 7 post-model result surfaces. These functions require the optional
CairoMakie extension to be loaded.

```@docs
Epsilon.contribution_plot
Epsilon.contribution_area_plot
Epsilon.decomposition_plot
Epsilon.response_curve_plot
Epsilon.saturation_curve_plot
Epsilon.adstock_curve_plot
```

## Optimization And Bundle Plotting

Phase 10 is now closed with optimization plotting plus deterministic static
bundle export over successful pipeline runs. These helpers require loading the
optional CairoMakie extension.

```@docs
Epsilon.budget_optimization_plot
Epsilon.write_plot_bundle
```

## Scenario Planner

Phase 16 extends the bounded non-UI scenario-planner surface with time-series
manual-allocation evaluation, table projection over existing response surfaces,
and combined current/manual/optimized comparison against already solved
fixed-budget optimization results. Phase 18 adds local scenario-store artifacts
for those existing `ScenarioPlanResult` tables. These stores are
Epsilon/Julia-version-bound typed artifacts with CSV inspection sidecars; they
are not a portable interchange format and should not be loaded from untrusted
sources. The local artifact layout is `scenario_store.jls`, `totals.csv`,
`channels.csv`, `allocations.csv`, `metadata.csv`, and optional
`channel_panel_allocations.csv`. Dash/UI workflows, hosted/background stores,
automatic refits, future spend paths, pipeline emission, and panel
manual-allocation evaluation remain unsupported.

```@docs
Epsilon.ScenarioDataArraySpec
Epsilon.AbstractScenarioSpec
Epsilon.CurrentScenarioSpec
Epsilon.ManualAllocationScenarioSpec
Epsilon.ManualScenarioEvaluationResult
Epsilon.evaluate_manual_scenario
Epsilon.FixedBudgetOptimizedScenarioSpec
Epsilon.ScenarioPlanResult
Epsilon.ScenarioStoreArtifact
Epsilon.scenario_plan
Epsilon.write_scenario_store
Epsilon.load_scenario_store
Epsilon.scenario_store_plan
Epsilon.assert_scenario_store_compatible
```

## Calibration

The calibration/lift-test surface covers fixture-backed schema, pure helper
semantics, and bounded `TimeSeriesMMM` MCMC likelihood integration for
centered-logistic lift-test calibration plus cost-per-target soft penalties.
See [Calibration](calibration.md) for the API reference and current exclusions.

## API

```@docs
Epsilon.ConvMode
Epsilon.After
Epsilon.Before
Epsilon.Overlap
Epsilon.ConvergenceIssue
Epsilon.ConvergenceReport
Epsilon.ConvergenceWarning
Epsilon.ConvergenceWarnings
Epsilon.EpsilonPrior
Epsilon.LaplacePrior
Epsilon.LogNormalPrior
Epsilon.MaskedPrior
Epsilon.ModelConfigError
Epsilon.AbstractModel
Epsilon.AbstractRegressionModel
Epsilon.AbstractMMMModel
Epsilon.MMMData
Epsilon.PanelMMMData
Epsilon.InferenceSampleStats
Epsilon.InferenceResults
Epsilon.ModelArtifactMetadata
Epsilon.ModelCoordinateMetadata
Epsilon.PanelAxis
Epsilon.PanelCoordinate
Epsilon.ModelDiagnostics
Epsilon.MMMModelSpec
Epsilon.ModelConfig
Epsilon.ModelFitState
Epsilon.ModelResults
Epsilon.ParameterDiagnostics
Epsilon.SamplerDiagnostics
Epsilon.SamplerWarning
Epsilon.SamplerWarnings
Epsilon.SamplerConfig
Epsilon.PanelMMM
Epsilon.TimeSeriesMMM
Epsilon.WeibullType
Epsilon.active_count
Epsilon.batched_convolution
Epsilon.binomial_adstock
Epsilon.build_model
Epsilon.convergence_report
Epsilon.convergence_warnings
Epsilon._compute_scales
Epsilon.deserialize_model_config
Epsilon.deserialize_prior
Epsilon.delayed_adstock
Epsilon.geometric_adstock
Epsilon.epsilon_version
Epsilon.fourier_features
Epsilon.expand_masked_values
Epsilon.inference_results
Epsilon.load_inference_results
Epsilon.load_model_config
Epsilon.load_model
Epsilon.load_public_config
Epsilon.load_results
Epsilon.load_sampler_config
Epsilon.centered_logistic_saturation
Epsilon.hill_function
Epsilon.has_convergence_issues
Epsilon.has_convergence_warnings
Epsilon.has_numerical_errors
Epsilon.has_sampler_warnings
Epsilon.instantiate_distribution
Epsilon.logistic_saturation
Epsilon.MaxAbsScaler
Epsilon.MaxAbsScaleTarget
Epsilon.MaxAbsScaleChannels
Epsilon.michaelis_menten
Epsilon.FinnishHorseshoePrior
Epsilon.finnish_horseshoe_coefficients
Epsilon.HorseshoePrior
Epsilon.horseshoe_coefficients
Epsilon.max_abs_scale_target_data
Epsilon.max_abs_scale_channel_data
Epsilon.model_config_from_dict
Epsilon.model_diagnostics
Epsilon.model_results
Epsilon.predict
Epsilon.ContributionResults
Epsilon.DecompositionResults
Epsilon.ResponseCurveResults
Epsilon.SaturationCurveResults
Epsilon.AdstockCurveResults
Epsilon.MetricResults
Epsilon.BudgetOptimizationResult
Epsilon.PanelBudgetOptimizationResult
Epsilon.budget_audit_table
Epsilon.budget_impact_table
Epsilon.panel_budget_allocation_table
Epsilon.panel_axis
Epsilon.panel_axes
Epsilon.panel_coordinate
Epsilon.panel_coordinates
Epsilon.contribution_results
Epsilon.decomposition_results
Epsilon.response_curve_results
Epsilon.saturation_curve_results
Epsilon.adstock_curve_results
Epsilon.metric_results
Epsilon.optimize_budget
Epsilon.summary_table
Epsilon.sampler_diagnostics
Epsilon.sampler_warnings
Epsilon.normalize_channel_columns
Epsilon.nobs
Epsilon.ntime
Epsilon.npanels
Epsilon.npanel_observations
Epsilon.prior_predict
Epsilon.r2d2_coefficients
Epsilon.r2d2_variance_weights
Epsilon.R2D2Prior
Epsilon.regularized_local_scales
Epsilon.Scaled
Epsilon.sampler_config_from_dict
Epsilon.save_inference_results
Epsilon.save_model
Epsilon.save_results
Epsilon.SkewStudentT
Epsilon.StandardScaler
Epsilon.StandardizeControls
Epsilon.standardize_control_data
Epsilon.tanh_saturation
Epsilon.validate_column_indices
Epsilon.validate_channel_values
Epsilon.validate_model_config
Epsilon.validate_mmm_data
Epsilon.validate_panel_mmm_data
Epsilon.validate_sampler_config
Epsilon.validate_target_data
Epsilon.weibull_adstock
Epsilon.fit!
Epsilon.fit_transform!
Epsilon.inverse_transform
Epsilon.transform
```
