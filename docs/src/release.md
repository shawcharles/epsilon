# Release Gate

Phase 11 landed the bounded v1 release-gate infrastructure for Epsilon, and
Phase 12 has now closed the methodology-remediation pass on top of it. The
package should still avoid blanket “Abacus parity” claims: the guaranteed
Abacus-reference row is `VAL-TS-00-MCMC`, while the holiday-bearing automatic
holiday row remains an Epsilon-native/reference row unless a separate
compatibility mode is added. More importantly, Epsilon now treats Abacus as a
major reference and comparison baseline rather than a source of literal
implementation obligations: methodological coherence wins when strict upstream
fidelity would produce a weaker or less honest bounded design. Treat this page
as the canonical release-gate summary for the closed bounded v1 surface.

Phase 13 also closes the accepted contract-remediation issues from the external
review: time-series prediction and replay now use fitted trend and
automatic-holiday date-basis state from the model spec, unfitted prior
prediction resolves scale and date-derived feature state from `model.data`,
media/channel arrays must be finite and nonnegative, `hill_function` rejects
negative inputs with a clear `ArgumentError`, and pipeline YAML fails on
unsupported top-level keys.

## Quickstart

The canonical entry points for the closed v1 surface are:

- direct modeling and inference:
  - `fit!(model)` with sampler settings carried on the typed model
  - `predict(model)`, `prior_predict(model)`, and `inference_results(model)`
- post-model analysis:
  - `contribution_results(results)`
  - `decomposition_results(results)`
  - `response_curve_results(results; ...)`
  - `metric_results(results; ...)`
- optimization:
  - `optimize_budget(results; ...)`
- scenario planning:
  - `scenario_plan(result)` over solved budget optimization results
  - `evaluate_manual_scenario(results, scenario)` for bounded time-series
    manual allocation evaluation over existing response surfaces
  - `scenario_plan(result, evaluations)` for compatible
    current/manual/optimized comparison without re-solving
  - `write_scenario_store(path, plan; ...)` and `load_scenario_store(path)` for
    local Epsilon/Julia-version-bound scenario-store artifacts over existing
    `ScenarioPlanResult` tables
- pipeline:
  - `run_pipeline(PipelineRunConfig(...))`
  - `bin/epsilon run path/to/config.yml`
- plotting:
  - direct Makie `Figure` APIs such as `trace_plot`, `contribution_plot`, and
    `budget_optimization_plot`
  - stage-local pipeline plot artifacts written automatically during Stage
    `10`-`70` execution
  - `write_plot_bundle(run)` for the bounded deterministic post-hoc pipeline
    plot bundle

## Supported v1 Surface

| Surface | Supported Rows | Notes |
|---|---|---|
| MMM feature bundles | `TS-00` through `TS-05`, `P-00` | Frozen at Phase 5 closeout |
| Inference | `INF-TS-MCMC`, `INF-P-MCMC` | V1 inference support is MCMC-only; `approximate_fit!` and `VariationalConfig` remain scaffolded pre-v1 review exports |
| Post-model | `POST-TS-MCMC`, `POST-P-MCMC` | Deterministic replay from grouped MCMC `InferenceResults`; post-model result arrays have validated axis-order contracts, and panel response/metric curves are panel-cell/channel artifacts with explicit `delta_grid` historical-scaling semantics |
| Optimization | `OPT-TS-MCMC`, `OPT-P-MCMC` | Fixed-budget `:total_response` only; panel optimization allocates channel totals and preserves historical within-channel panel-cell spend shares |
| Scenario planner | solved time-series and bounded panel optimization results; evaluated time-series manual allocations; local scenario-store artifacts | Non-UI comparison tables over existing optimizer outputs and existing time-series response surfaces; typed current, manual-allocation, and fixed-budget optimized scenario specs are supported. Compatible evaluated manual scenarios can be compared with one solved optimization result, and existing `ScenarioPlanResult` tables can be written to a local typed `scenario_store.jls` payload with CSV inspection sidecars. The store artifact is Epsilon/Julia-version-bound and should not be treated as a portable or untrusted interchange format. Panel manual allocation, automatic scenario refits, future-path simulation, pipeline scenario-store emission, hosted/background stores, and Dash workflows remain deferred |
| Pipeline | bounded time-series MCMC Stage `00`-`70` path, including optional Stage `05` prior-sensitivity planning; panel Stage `00` metadata, optional Stage `05` prior-sensitivity planning, Stage `20` fit, Stage `30` assessment, Stage `40` decomposition, Stage `50` diagnostics, Stage `60` response-curve path, and explicitly enabled Stage `70` historical-share optimization | `run_pipeline(config)` and `epsilon run config.yml`, with stage-local plot artifacts; Phase 14 validates Abacus-compatible Stage `00` through Stage `70` artifact keys against an exported Abacus `timeseries` pipeline contract, and validates `geo_panel` / `geo_brand_panel` Stage `00`-`60` keys plus `geo_panel` and `geo_brand_panel` Stage `70` historical-share optimization artifacts against exported Abacus panel contracts where semantics match. Stage `05` writes resolved prior-sensitivity scenario configs and human/LLM-safe manifests; it does not refit every scenario automatically. Julia-native serialized artifacts are used where Abacus uses PyMC/NetCDF-specific files |
| Plotting | grouped diagnostics, time-series post-model, channel-level time-series and panel optimization, deterministic plot bundle | Direct plots return Makie `Figure` objects; `write_plot_bundle(run)` is the optional curated export |

## Explicit Unsupported Rows

The release gate keeps the unsupported surface explicit:

- `seasonality.type = "hsgp"`
- panel seasonality, trend, events, and richer controls
- `PanelMMM` + `approximate_fit!`
- `approximate_fit!` / `VariationalConfig` as a v1 release-supported inference
  backend
- YAML-driven VI
- VI-backed `model_results`, sampler diagnostics, convergence reports, and
  convergence warnings
- panel Stage `35` holdout validation; time-series blocked holdout validation
  remains supported, but panel holdout semantics are deferred unless a concrete
  methodological requirement is added
- free channel-by-panel allocation, panel-total optimization bounds, and
  fairness/weighted panel optimization objectives
- automatic fitting/comparison of every prior-sensitivity scenario; Stage `05`
  deliberately writes scenario plans for deliberate follow-on runs
- panel manual-allocation evaluation
- scenario planner simulation over arbitrary future spend paths, background
  execution, hosted scenario stores, pipeline scenario-store emission, and
  interactive scenario-planner UI workflows
- panel post-model plotting beyond contribution/decomposition summary artifacts
- unsupported panel pipeline stages beyond Stage `00` through Stage `60` and
  explicitly enabled Stage `70` historical-share optimization
- VI trace plots
- NetCDF / ArviZ-native grouped export
- Dash parity, AI advisor, or interactive dashboard/reporting surfaces

## Validation Contract

Phase 12 does not widen the Abacus-reference row set. The guaranteed
Abacus-reference row remains:

- `VAL-TS-00-MCMC`

`VAL-TS-04-MCMC` now runs on Epsilon’s coherent native automatic holiday path.
Unless Epsilon later ships a separate compatibility mode with matching Prophet
semantics, this row should remain a bounded Epsilon-native/reference row rather
than an Abacus-reference row.

All other rows remain bounded Epsilon-only validation rows unless Phase 12
changes that explicitly in docs and tests.

Phase 11 uses one explicit release gate with two kinds of checks.

### Abacus-Reference Rows

These rows are validated against compact committed Abacus-derived fixtures:

- `VAL-TS-00-MCMC`

The final harness checks:

- exact dataset and config metadata identity
- posterior parameter identity
- posterior-predictive summary parity on the observed design
- bounded schema / budget-consistency checks for the compact post-model and
  optimization summaries

Detailed numeric comparison for the transform layer and the retained Phase 7 / 8
post-model and optimization surfaces stays on the committed phase-local fixture
gates. These checks justify parity claims only where the semantics of the
underlying Epsilon surface still genuinely match the Abacus reference.

### Bounded Epsilon-Only Rows

These rows are validated through explicit contract-regression checks rather
than false Abacus parity claims:

- `VAL-TS-04-MCMC`
- `VAL-P-00-MCMC`
- `VAL-PIPE-TS-00-MCMC`
- bounded plotting support

The release-gate harness exercises `VAL-TS-04-MCMC` through the repaired
automatic-holiday grouped inference / post-model / optimization contract,
and the bounded plotting row through `write_plot_bundle(run)` on a successful
pipeline run. Historical VI harness work remains scaffolded implementation
evidence only and is not part of the v1 release gate after Phase 27.

### Maintainer Commands

```bash
julia --project=. test/validation/runtests.jl
make test
make docs
```

Fixture regeneration commands remain documented in
`test/fixtures/abacus/README.md`.

## Benchmarks

The benchmark methodology and published reference-machine results live in the
[Benchmarks](benchmarks.md) page and in the committed `benchmark/results/`
artifacts.

Phase 11 does not require a universal faster-than-Abacus claim. The benchmark
gate is honest publication of:

- workload identities
- run protocol
- machine / environment metadata
- measured results for the frozen v1 workload matrix

The current committed benchmark snapshot records `git_dirty = true` and a
row-specific pipeline exception: `B-W4-PIPELINE` inherits `target_accept = 0.8`
from the frozen pipeline fixture YAML while the direct workflow rows use the
explicit `0.85` benchmark override. Maintainers should rerun the frozen suite
from a clean tagged worktree for the final release artifact.

## Phase 11 Infrastructure Checklist

- [x] The frozen Phase 5 feature matrix is documented with supported and
  unsupported rows.
- [x] The Phase 6 inference matrix is documented; Phase 27 supersedes the
  earlier VI row as release support and keeps v1 inference MCMC-only with
  explicit unsupported rows.
- [x] The Phase 7 post-model contract is closed on grouped `InferenceResults`.
- [x] The Phase 8 fixed-budget optimization surface is documented with explicit
  unsupported constraint/objective families.
- [x] The Phase 9 pipeline contract is closed on the bounded time-series MCMC
  Stage `00`-`70` path, including stage-local plot artifacts.
- [x] The Phase 10 plotting surface is documented as a bounded CairoMakie layer
  with deterministic static bundle export.
- [x] The Phase 11 release-gate harness passes locally.
- [x] `make test` passes on the current repo state.
- [x] `make docs` passes on the current repo state.
- [x] The frozen benchmark workload matrix is documented and the committed
  reference-machine snapshot is published.
- [x] Known unsupported rows and residual limitations are explicit in release
  docs.

## Phase 12 Closeout Status

The checklist above records what Phase 11 infrastructure landed. The additional
Phase 12 closeout work has now rerun the final validation harness and
reconciled the release-facing methodology claim.

Closed Phase 12 items:

- [x] The guaranteed Abacus-reference row `VAL-TS-00-MCMC` fits in the same
  scaling/model space as Abacus.
- [x] Original-scale predictive and contribution outputs are reconstructed on
  top of that repaired scaled-space contract.
- [x] Stage 60 exposes the repaired comparable curve families:
  forward-pass, saturation-only, and adstock.
- [x] Stage 70 optimization is revalidated against the repaired comparable
  curve/model-space contract.
- [x] The shipped time-series demo and holiday/trend/seasonality design are
  reconciled with the final bounded methodology decision.
- [x] Release-facing docs can truthfully distinguish repaired Abacus-reference
  rows from Epsilon-native rows.

Release preparation may resume from this narrowed claim set. Maintainers should
still rerun the frozen benchmark suite from a clean worktree before publishing
an actual release artifact because the current committed benchmark snapshot
still records `git_dirty = true`.

## Known Residual Limitations

Even after Phase 12, the bounded v1 surface remains intentionally smaller than
full Abacus scope:

- HSGP is not yet implemented on the bounded v1 surface.
- The panel path can represent one or more declared panel dimensions through a
  deterministic flat panel-cell axis, with hierarchical intercept offsets.
- Panel contribution/decomposition replay is covered for the `geo_panel` and
  `geo_brand_panel` gates. Multidimensional panel contribution summaries use a
  deterministic flat `panel` key plus declared coordinate columns. Panel
  response, saturation, adstock, and marketing metrics use the same flat
  panel-cell axis and require an explicit `delta_grid`. Panel optimization is
  implemented only as channel-total allocation with fixed historical
  within-channel panel shares; arbitrary channel-by-panel allocation is not
  implied. Panel Stage `35` holdout validation is deferred for v1 rather than
  added for parity theater.
- VI exports remain scaffolded, Julia-only pre-v1 review surfaces and are not
  part of v1 release support.
- The pipeline remains time-series-first and MCMC-only.
- Plotting is static and Makie-based rather than a replicated Dash product
  layer; Dash/dashboard parity remains explicitly deferred.

These are documented release boundaries, not hidden follow-up tasks inside the
closed v1 gate.
