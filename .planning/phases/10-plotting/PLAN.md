# Phase 10 Plan - Plotting

**Phase:** 10
**Phase Name:** Plotting
**Status:** In Progress
**Last Reconciled:** 2026-04-23

## Objective

Turn the closed Phases 6-9 artifact surfaces into one truthful Julia-native
visualization layer for diagnostics, analyst interpretation, optimization
review, and report-ready static exports.

Phase 10 is where Epsilon stops at tables, typed results, and pipeline sidecars
and starts exposing a bounded plotting contract for:

- inspecting grouped inference visually
- rendering time-series contribution and decomposition outputs
- reviewing response curves and optimization recommendations
- exporting a deterministic static plot bundle from a successful pipeline run

The key constraint is that Phase 10 must stay intentionally smaller than the
Abacus Dash surface. It should consume the frozen artifact contracts from
Phases 6-9, not reopen pipeline orchestration, report generation, or dashboard
scope.

## Entry Conditions

Phase 9 is closed and the following are already in place:

- grouped inference artifacts:
  - `InferenceResults`
- post-model outputs:
  - `ContributionResults`
  - `DecompositionResults`
  - `ResponseCurveResults`
  - `MetricResults`
  - `summary_table`
- optimization outputs:
  - `BudgetOptimizationResult`
  - `budget_impact_table`
  - `budget_audit_table`
- pipeline outputs:
  - `PipelineRunResult`
  - `PipelineStageRecord`
  - `run_manifest.json`
  - closed Stage `00`-`70` artifact schema

Phase 10 must visualize those contracts; it must not create parallel result
types for the same underlying semantics.

## Current Base To Extend

The current closed base is:

- `fit!` and `approximate_fit!` for the supported inference rows
- grouped `InferenceResults` as the canonical artifact for downstream work
- deterministic replay through:
  - `contribution_results`
  - `decomposition_results`
  - `response_curve_results`
  - `metric_results`
- fixed-budget optimization through:
  - `optimize_budget`
  - `BudgetOptimizationResult`
- disk-backed pipeline runs through:
  - `run_pipeline`
  - `pipeline_main`
  - `PipelineRunResult`

Phase 10 adds one coherent plotting layer on top of that base.

## Phase 10 Plotting Contract

Phase 10 freezes the plotting contract up front:

- The canonical backend is `CairoMakie.jl`.
- Plot functions return Makie `Figure` objects.
- Direct static export of returned figures uses Makie's `save(...)` path and is
  bounded to `png`, `svg`, and `pdf`.
- Phase 10 is time-series first for post-model and optimization visuals because
  the underlying typed surfaces are already time-series first.
- Diagnostic plots may consume the bounded grouped inference rows that already
  exist, but they must stay honest about which artifact groups and backend
  semantics they require.
- The plotting layer does not become a second pipeline stage graph.
- The plotting layer does not introduce a Dash-equivalent interactive app, web
  server, widget surface, or report PDF generator.
- A report-ready plot bundle is allowed only as a post-hoc export helper over a
  successful `PipelineRunResult`; it must not mutate the closed Phase 9 run
  directory contract, and its bounded Phase 10 bundle format is `png` only.

## Canonical Public Surface

The bounded public plotting surface is:

- `epsilon_theme() -> Makie.Theme`
- `trace_plot(results::InferenceResults; parameters=nothing, max_parameters=8)`
- `posterior_density_plot(results::InferenceResults; parameters=nothing, max_parameters=8)`
- `prior_posterior_plot(results::InferenceResults; parameter)`
- `observed_fitted_plot(results::InferenceResults)`
- `residual_diagnostics_plot(results::InferenceResults)`
- `contribution_plot(results::ContributionResults; channels=nothing)`
- `contribution_area_plot(results::ContributionResults; channels=nothing)`
- `decomposition_plot(results::DecompositionResults)`
- `response_curve_plot(results::ResponseCurveResults)`
- `budget_optimization_plot(result::BudgetOptimizationResult)`
- `write_plot_bundle(run::PipelineRunResult; output_dir=nothing)`

`epsilon_theme()` is a pure theme helper:

- it returns a Makie `Theme`
- it does not mutate Makie's global active theme
- public plotting functions should apply it locally rather than changing global
  process state

Phase 10 should not add a second family of generic catch-all plotting wrappers
such as `plot(result)` or `autoplot(result)`. The public surface should stay
type-explicit.

## Per-Function Input Contract

### Diagnostics Foundation

- `trace_plot`
  - requires MCMC-backed `InferenceResults`
  - consumes posterior draws only
  - unsupported for VI-backed grouped artifacts
- `posterior_density_plot`
  - requires posterior draws
  - supported wherever grouped posterior draws exist
- `prior_posterior_plot`
  - requires both posterior and prior draws for the selected parameter
  - must fail explicitly if prior draws are absent
- `observed_fitted_plot`
  - requires observed data plus posterior predictive draws
  - bounded to time-series grouped artifacts for Phase 10
- `residual_diagnostics_plot`
  - requires the same observed plus posterior predictive inputs as
    `observed_fitted_plot`
  - bounded to time-series grouped artifacts for Phase 10

### Post-Model Plots

- `contribution_plot`
  - consumes `ContributionResults`
  - renders channel contribution time series with central tendency and HDI bands
- `contribution_area_plot`
  - consumes `ContributionResults`
  - renders stacked additive contribution breakdown through time
- `decomposition_plot`
  - consumes `DecompositionResults`
  - renders waterfall-style decomposition in target units
- `response_curve_plot`
  - consumes `ResponseCurveResults`
  - renders response and optional marginal-response views on the frozen spend
    grid

### Optimization Plot

- `budget_optimization_plot`
  - consumes `BudgetOptimizationResult`
  - compares current versus optimized spend and response through one bounded
    static visual

### Plot Bundle Export

- `write_plot_bundle`
  - consumes a successful `PipelineRunResult`
  - reads existing typed artifacts and sidecars from the closed Phase 9 run
    directory
  - writes a separate plot directory
  - is `png` only in the bounded Phase 10 contract
  - never mutates pipeline stage artifacts or the manifest
  - does not expose parameter-selection keywords in Phase 10; bundle contents
    are determined by the fixed policy below

Bundle parameter-selection policy is fixed now:

- `trace_plot` and `posterior_density_plot` bundle outputs use the first
  `min(8, n)` scalar posterior parameter names in deterministic sorted-name
  order
- `trace.png` and `posterior_density.png` are single multi-panel figures over
  that fixed selected parameter set, not one file per parameter
- `prior_posterior_plot` bundle outputs are emitted for that same selected
  parameter set, but only for parameters that have both prior and posterior
  draws available
- missing prior draws do not fail the bundle; they skip the corresponding
  `prior_posterior_*` files honestly
- the bundle does not attempt user-driven parameter customization in Phase 10

## Theme And Export Contract

Phase 10 fixes one visual baseline:

- backend: `CairoMakie`
- theme owner: `epsilon_theme()`
- output intent: readable static plots for docs, notebooks, and exported files
- direct figure export formats:
  - `png`
  - `svg`
  - `pdf`
- report-bundle export format:
  - `png`

The theme contract should define:

- one stable categorical palette for channels and components
- one diverging treatment for positive versus negative decomposition bars
- consistent font sizes, line widths, grid styling, and legend placement
- deterministic sizing defaults for:
  - standard notebook/docs figures
  - report-ready wide figures

Phase 10 does not need exact pixel parity with Abacus. The parity target is
information content and honest rendering of the frozen typed surfaces, not a
Matplotlib lookalike.

## Report-Ready Bundle Contract

`write_plot_bundle(run; ...)` is the bounded report-ready helper.

The canonical output tree is:

- `diagnostics/`
  - `trace.png`
  - `posterior_density.png`
  - `observed_fitted.png`
  - `residual_diagnostics.png`
  - `prior_posterior_<parameter_slug>.png` for the fixed selected parameter set
    when both prior and posterior draws exist
- `postmodel/`
  - `contributions.png`
  - `contributions_area.png`
  - `decomposition.png`
  - `response_curve_<channel>.png`
- `optimization/`
  - `budget_optimization.png` when optimization artifacts exist

The bundle helper must:

- skip optimization plots honestly when the pipeline run has no optimization
  stage artifacts
- fail explicitly when required upstream artifacts are missing or incompatible
- leave the Phase 9 run directory untouched
- use the deterministic parameter-selection policy defined above rather than an
  implementation-time heuristic

Phase 10 does not add:

- HTML dashboards
- slide decks
- PDF report assembly
- plot bundle generation as an automatic pipeline side effect

Those remain outside the bounded Phase 10 contract.

## Explicitly Unsupported In Phase 10

The following remain unsupported:

- Plotly Dash parity
- browser-based interactive dashboards
- panel post-model plots
- panel optimization plots
- VI trace plots
- pipeline-stage mutation that writes plots back into the closed Phase 9 run
  directory
- a generic `plot(::Any)` front door
- pixel-for-pixel visual parity as a release gate

## Module Ownership

Phase 10 should land under:

- `src/plotting/`
  - `theme.jl`
  - `diagnostics.jl`
  - `postmodel.jl`
  - `optimization.jl`
  - `bundle.jl`
- `test/plotting/`

The plotting layer must consume existing typed surfaces from:

- `src/inference/`
- `src/postmodel/`
- `src/optimization/`
- `src/pipeline/`

It must not take ownership of those contracts.

## Plan Breakdown

### 10-01 Theme And Diagnostic Foundation

**Goal:** Land the backend, theme, and first diagnostic plot family on top of
the closed inference contracts.

**Deliverables:**

- `src/plotting/theme.jl`
- `src/plotting/diagnostics.jl`
- public exports:
  - `epsilon_theme`
  - `trace_plot`
  - `posterior_density_plot`
  - `prior_posterior_plot`
  - `observed_fitted_plot`
  - `residual_diagnostics_plot`
- `test/plotting/diagnostics.jl`
- docs for the plotting entry points

**Acceptance:**

- theme is centralized rather than duplicated across plot functions
- `epsilon_theme()` returns a `Makie.Theme` and does not mutate global theme
  state
- `trace_plot` fails honestly on VI-backed artifacts
- `prior_posterior_plot` fails honestly when grouped prior draws are absent
- all diagnostic functions return Makie `Figure` objects and save successfully
  through direct `png`, `svg`, and `pdf` exports
- tests assert information-content correctness:
  - expected axes/labels/series
  - file export smoke
  - no exact pixel snapshot requirement

**Status:** Complete

### 10-02 Post-Model Plotting

**Goal:** Render the closed Phase 7 post-model outputs directly from their
typed result surfaces.

**Deliverables:**

- `src/plotting/postmodel.jl`
- public exports:
  - `contribution_plot`
  - `contribution_area_plot`
  - `decomposition_plot`
  - `response_curve_plot`
- `test/plotting/postmodel.jl`
- docs/examples for supported time-series MCMC and VI rows

**Acceptance:**

- contribution plots render HDI-aware time-series outputs from
  `ContributionResults`
- area plots preserve the additive contribution interpretation instead of
  inventing a second replay contract
- decomposition plots stay in observed target units
- response-curve plots stay anchored to the frozen Phase 7 spend-grid contract
- panel post-model plotting remains explicitly unsupported

**Status:** Complete

### 10-03 Optimization And Report-Ready Exports

**Goal:** Close Phase 10 with optimization visuals and one bounded static plot
bundle on top of the closed Phase 9 run schema.

**Deliverables:**

- `src/plotting/optimization.jl`
- `src/plotting/bundle.jl`
- public exports:
  - `budget_optimization_plot`
  - `write_plot_bundle`
- `test/plotting/optimization.jl`
- `test/plotting/bundle.jl`
- docs for direct artifact plotting and bundle export

**Acceptance:**

- optimization plots render truthful current-versus-optimized comparisons from
  `BudgetOptimizationResult`
- bundle export consumes successful `PipelineRunResult` values and writes the
  fixed `png` output tree with the deterministic parameter-selection policy
- optional optimization stage absence is handled honestly
- the Phase 10 support matrix is documented explicitly before Phase 11 begins

**Status:** Complete

## Verification Strategy

Phase 10 verification is data-level and artifact-level, not pixel-snapshot
driven.

Required checks:

- plot functions return `Figure`
- saved files exist and are non-empty
- plotted labels/legends/series correspond to the source typed results
- unsupported inputs fail with explicit `ArgumentError` or `ErrorException`
- direct plotting examples appear in docs
- bundle tests assert the deterministic diagnostic-parameter file set rather
  than leaving bundle composition implicit

Phase 10 should avoid fragile pixel-perfect golden-image tests unless one
specific rendering regression justifies them later.

## Phase Exit Criteria

Phase 10 is complete when:

- the bounded public plotting surface above exists and is documented
- the diagnostic, post-model, and optimization plot families all render from
  the closed typed artifact surfaces
- `write_plot_bundle` exists as the bounded report-ready export helper over
  successful pipeline runs
- the support matrix is explicit, including the continued lack of Dash parity
- Phase 11 can consume Phase 10 as a closed visualization layer rather than
  reopening backend or report-bundle decisions
