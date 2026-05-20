# Phase 9 Plan - Pipeline

**Phase:** 9
**Phase Name:** Pipeline
**Status:** In Progress
**Last Reconciled:** 2026-04-23

## Objective

Turn the frozen Phases 6-8 public surfaces into one truthful, disk-backed,
YAML-driven workflow that takes a supported MMM config plus dataset and
produces a structured run directory.

Phase 9 is where Epsilon stops being only a library of bounded in-memory calls
and starts exposing one reproducible workflow contract for:

- loading a supported YAML config
- loading a combined CSV dataset
- fitting one supported MMM
- materializing grouped inference and downstream analyst outputs
- writing stage-owned artifacts into a predictable run directory

The key constraints are:

- Phase 9 must consume the frozen model, inference, post-model, and
  optimization surfaces rather than re-deriving those semantics inside the
  runner.
- Phase 9 must freeze the pipeline support matrix up front instead of leaving
  panel, VI, or artifact-format decisions to implementation time.
- Phase 9 must stay time-series first and MCMC-only unless a later phase opens
  broader workflow support explicitly.

## Entry Conditions

Phase 8 is closed and the following are already in place:

- public YAML/model loading through:
  - `load_public_config`
  - `load_model_config`
  - `load_sampler_config`
- supported model surfaces:
  - `TimeSeriesMMM`
  - bounded `PanelMMM`
- canonical grouped inference artifacts:
  - `InferenceResults`
- bounded post-model outputs:
  - `contribution_results`
  - `decomposition_results`
  - `response_curve_results`
  - `metric_results`
  - `summary_table`
- bounded optimization outputs:
  - `optimize_budget`
  - `BudgetOptimizationResult`
  - `budget_impact_table`
  - `budget_audit_table`
- typed model and grouped-artifact persistence:
  - `save_model`
  - `save_inference_results`

Phase 9 must orchestrate those contracts; it must not quietly replace them.

## Current Base To Extend

The current closed base is:

- public MMM config + sampler config loading
- typed `MMMData` / `PanelMMMData`
- `fit!` as the canonical MCMC path
- `inference_results` as the canonical grouped artifact
- deterministic replay and analyst outputs on supported grouped
  `TimeSeriesMMM` artifacts
- bounded fixed-budget optimization on supported grouped
  `TimeSeriesMMM` artifacts

Phase 9 adds one coherent runner layer on top of that base.

## Phase 9 Pipeline Contract

Phase 9 fixes the pipeline contract up front:

- The pipeline is time-series first.
- The pipeline is YAML-driven and CLI-accessible.
- The pipeline uses one combined CSV dataset input, not separate `X` / `y`
  files.
- The pipeline is MCMC-only in Phase 9:
  - it consumes YAML `fit`
  - it drives `fit!`
  - it does not expose `approximate_fit!` or VI selection through YAML or CLI
- The pipeline consumes Julia-native Epsilon artifacts and writes Julia-native
  serialized stage artifacts plus CSV / JSON sidecars for summaries and
  manifests.
- The pipeline does not introduce a second results object, a second diagnostics
  object, or a second optimization object.
- The pipeline does not reopen panel post-model or panel optimization
  semantics.
- There is no separate plotting/report-bundle phase hidden inside Phase 9.
  Stage summaries and the run manifest are part of the pipeline contract;
  dedicated visual/report presentation remains Phase 10.

## Public Contract

The canonical public entry points for Phase 9 are:

- `PipelineRunConfig`
- `PipelineStageRecord`
- `PipelineRunResult`
- `PipelineValidationResult`
- `run_pipeline(config::PipelineRunConfig)`
- `pipeline_main(args = ARGS)`

The canonical CLI surface is:

- `epsilon run path/to/config.yml`

The bounded API-level config surface is:

- `PipelineRunConfig(; config_path, output_dir="results", run_name=nothing, dataset_path=nothing, prior_samples=20, curve_points=100, draws=nothing, tune=nothing, chains=nothing, cores=nothing, random_seed=nothing)`

Phase 9 should keep the CLI thin and route through the same `run_pipeline`
implementation rather than owning a second orchestration path.

### `PipelineStageRecord`

The bounded stage-record surface is:

- `key::String`
- `directory::String`
- `status::Symbol`
- `started_at_utc::Union{Nothing, String}`
- `finished_at_utc::Union{Nothing, String}`
- `artifact_paths::Dict{String, String}`
- `warnings::Vector{String}`
- `error::Union{Nothing, Dict{String, Any}}`

`artifact_paths` maps stable logical names such as `model`, `inference_results`,
`posterior_summary`, or `budget_audit` to relative paths inside the run
directory.

### `PipelineRunResult`

The bounded run-result surface is:

- `run_name::String`
- `run_dir::String`
- `manifest_path::String`
- `status::Symbol`
- `config_path::String`
- `started_at_utc::String`
- `finished_at_utc::Union{Nothing, String}`
- `stage_records::Vector{PipelineStageRecord}`
- `warnings::Vector{String}`
- `error::Union{Nothing, Dict{String, Any}}`

`PipelineRunResult` is a typed Julia summary of the run. It mirrors the
machine-readable manifest and does not become a second richer reporting API.

### `PipelineValidationResult`

The bounded validation artifact surface is:

- `holdout_rows::Int`
- `train_date_start::String`
- `train_date_end::String`
- `holdout_date_start::String`
- `holdout_date_end::String`
- `observed::Vector{Float64}`
- `fitted_mean::Vector{Float64}`
- `residuals::Vector{Float64}`
- `metrics::Dict{String, Float64}`

The required metric keys are:

- `mae`
- `rmse`
- `bias`

This artifact is pipeline-owned and stage-scoped. It is not a replacement for
`InferenceResults` or `ModelResults`.

## Public Keyword Shapes

The bounded Phase 9 runtime config is fixed now rather than left to `09-01`
implementation-time choices:

- `config_path::AbstractString`
  - required
  - path to the YAML pipeline/model config
- `output_dir::AbstractString`
  - optional
  - defaults to `"results"`
  - root under which the timestamped run directory is created
- `run_name::Union{Nothing, AbstractString}`
  - optional
  - defaults to the YAML filename stem
- `dataset_path::Union{Nothing, AbstractString}`
  - optional
  - overrides `data.dataset_path` in YAML for CSV loading only
- `prior_samples::Integer`
  - optional
  - number of prior predictive draws written by Stage 10
  - must be positive
- `curve_points::Integer`
  - optional
  - number of spend-grid points used by Stage 60 response curves
  - must be at least `2`
- `draws`, `tune`, `chains`, `cores`, `random_seed`
  - optional runtime overrides
  - merge onto YAML `fit`
  - follow existing `SamplerConfig` semantics

The pipeline does not accept:

- backend selectors
- separate `x_path` / `y_path`
- holiday catalogue file overrides
- external inference-artifact injection
- partial stage selection or resume controls

Those remain out of scope for the bounded Phase 9 surface.

## CLI Contract

The bounded CLI entry point is:

```text
epsilon run <config_path>
```

The CLI flags are fixed to the `PipelineRunConfig` surface:

- `--output-dir`
- `--run-name`
- `--dataset-path`
- `--prior-samples`
- `--curve-points`
- `--draws`
- `--tune`
- `--chains`
- `--cores`
- `--random-seed`

The CLI does not expose flags for:

- backend selection
- validation or optimization enable/disable overrides
- partial stage selection
- resume / continue-after-failure behavior
- separate `X` / `y` file paths

The API and CLI must stay one-to-one on the bounded runtime override set above.

## YAML Contract

Phase 9 consumes one YAML file that combines:

- the existing public MMM model config surface
- a small set of runner-only pipeline keys

The bounded runner-only keys are:

- `data.dataset_path`
  - combined CSV dataset path for the run
- `validation`
  - optional blocked-holdout config
- `optimization`
  - optional bounded optimization config

### Runner-Only YAML Rules

- Runner-only keys must be parsed and validated by the pipeline layer before
  the remaining config is passed to `load_public_config`.
- The public model/config loader remains the canonical validator for the
  supported MMM YAML surface.
- The pipeline must strip runner-only keys before the model/config loader sees
  the public MMM config.
- `config.resolved.yaml` must preserve the full effective pipeline config,
  including runner-only keys and merged runtime overrides.
- `config.model.yaml` must preserve the exact public MMM config that is passed
  to `load_public_config` after runner-only stripping.

## Combined CSV Dataset Contract

Phase 9 supports exactly one combined CSV ingestion path.

### Required Columns

The combined CSV must contain:

- the date column declared by `data.date_column`
- the target column declared by `target.column`
- every media channel listed in `media.channels`
- every control column listed in `media.controls`, when present
- every manual event column listed in `events.columns`, when present

The pipeline rejects:

- missing required columns
- duplicate column names after CSV parsing
- `dimensions.panel` / panel dimension columns in the bounded Phase 9 surface

Extra columns are allowed but ignored unless they are referenced by the
supported YAML contract above.

### Date Parsing And Ordering

The date column must parse as one uniform temporal type:

- all `Date`
- or all `DateTime`

Mixed parsed date types are rejected. The pipeline sorts rows by parsed date in
ascending chronological order before building `MMMData`. Holdout splitting uses
that sorted chronological order, not raw file order.

The pipeline rejects:

- unparseable date values
- duplicate parsed date values
- fewer than `holdout_rows + 1` rows when validation is enabled

### Numeric Data Rules

The following columns must be finite numeric data with no missing values:

- target column
- media channel columns
- control columns used by the supported YAML contract
- manual event columns used by the supported YAML contract

Channel, control, and event columns are loaded in the canonical order already
fixed by the public YAML/model contract:

- channel order follows `media.channels`
- control order follows `media.controls`
- manual event order follows `events.columns`

The pipeline must not infer a new column ordering from CSV position.

### `validation` Block

The bounded Phase 9 `validation` block is:

- `enabled::Bool`
  - optional
  - defaults to `true` when the block is present
- `holdout_rows::Integer`
  - required when validation is enabled
  - must be positive
  - defines a blocked holdout on the trailing observed rows of the current
    time-series horizon

Phase 9 validation does not include:

- rolling-origin cross-validation
- multiple holdout folds
- panel holdout routing

### Validation Branching Contract

Stage `35_holdout_validation` is a side branch off the full run, not a
replacement fit:

- it consumes the Stage `00_run_metadata` resolved config plus the fully loaded
  sorted dataset
- it constructs a train-window dataset by dropping the final `holdout_rows`
  observations
- it fits a separate train-window `TimeSeriesMMM`
- it evaluates posterior predictive summaries on the held-out trailing window
- it writes a stage-owned `PipelineValidationResult`
- it does not mutate or overwrite the full-sample Stage `20_model_fit`
  artifacts in the main pipeline context
- later mainline stages (`40`, `50`, `60`, `70`) continue to consume the
  full-sample Stage `20_model_fit` artifacts only

### `optimization` Block

The bounded Phase 9 `optimization` block is a YAML projection of the already
closed Phase 8 optimization contract:

- `enabled::Bool`
  - optional
  - defaults to `true` when the block is present
- `total_budget`
  - required when optimization is enabled
- `channels`
  - optional
- `budget_bounds`
  - optional
- `relative_bounds`
  - optional
- `objective`
  - optional but bounded to `:total_response`
- `grid`
  - optional

Phase 9 must not redefine or widen those semantics.

## Manifest And Result Schema Contract

The root `run_manifest.json` is the machine-readable index for the whole run
and must serialize the same bounded information surface returned by
`PipelineRunResult`.

### Top-Level Manifest Keys

The required top-level keys are:

- `schema_version`
- `run_name`
- `status`
- `config_path`
- `run_dir`
- `output_dir`
- `started_at_utc`
- `finished_at_utc`
- `model_type`
- `data`
- `stages`
- `warnings`
- `error`

`stages` is a mapping keyed by stage key (`metadata`, `preflight`, ...,
`optimisation`) rather than an unkeyed list.

### `data` Object Schema

The required `data` object keys are:

- `n_rows`
- `date_column`
- `date_type`
- `date_min`
- `date_max`
- `target_column`
- `channel_columns`
- `control_columns`
- `event_columns`

### Error Payload Schema

Top-level and per-stage `error` payloads must use the same keys:

- `type`
- `message`
- `stage`

`stage` is `nothing` only for pre-stage failures before stage execution begins.

### Stage Record Schema

Each stage record under `stages` must contain:

- `key`
- `directory`
- `status`
- `started_at_utc`
- `finished_at_utc`
- `artifact_paths`
- `warnings`
- `error`

The typed `PipelineStageRecord` and the serialized stage-record objects must be
schema-equivalent.

## Support Matrix

Phase 9 starts from the following explicit baseline:

| Surface | `TimeSeriesMMM` + MCMC | `TimeSeriesMMM` + VI | `PanelMMM` + MCMC | Notes |
|---|---|---|---|---|
| in-memory public APIs | Supported | Partially supported | Partially supported | Closed by Phases 6-8 |
| YAML-driven pipeline | Not Yet Supported | Not Yet Supported | Not Yet Supported | Phase 9 scope |

Phase 9 closes with the following intended support matrix:

| Surface | `TimeSeriesMMM` + MCMC | `TimeSeriesMMM` + VI | `PanelMMM` + MCMC | Notes |
|---|---|---|---|---|
| `run_pipeline` | Supported | Unsupported | Unsupported | YAML `fit` remains MCMC-only; panel pipeline is deferred |
| optional blocked holdout validation | Supported | Unsupported | Unsupported | Uses one trailing blocked holdout over the supported time-series path |
| optional optimization stage | Supported | Unsupported | Unsupported | Consumes the closed Phase 8 optimization contract |

Explicitly unsupported in Phase 9:

- YAML-driven VI
- panel pipeline orchestration
- panel post-model pipeline outputs
- panel optimization pipeline outputs
- separate `X` / `y` CSV ingestion
- artifact formats that bypass the current Julia-native save/load surfaces

## Stage Order And Semantics

Phase 9 uses one fixed stage sequence. There is no stage reordering API in the
bounded Phase 9 surface.

| Stage key | Directory | Purpose | Optional |
|---|---|---|---|
| `metadata` | `00_run_metadata` | Resolve config, load CSV data, build the typed model, initialize the manifest | No |
| `preflight` | `10_pre_diagnostics` | Prior predictive draws and compact prior summaries | No |
| `fit` | `20_model_fit` | Run `fit!`, persist model + grouped inference artifacts, write posterior summaries | No |
| `assessment` | `30_model_assessment` | In-sample posterior predictive summaries, fitted series, and residual outputs | No |
| `validation` | `35_holdout_validation` | Trailing blocked holdout refit and held-out predictive summaries | Yes |
| `decomposition` | `40_decomposition` | Contributions, decomposition artifacts, and summary tables | No |
| `diagnostics` | `50_diagnostics` | Diagnostics, warnings, and convergence/sampler summaries | No |
| `curves` | `60_response_curves` | Response-curve and metric artifacts | No |
| `optimisation` | `70_optimisation` | Bounded budget optimization artifacts | Yes |

There is no separate reporting stage in Phase 9. Run-level reporting is:

- `run_manifest.json`
- stage summary CSV / JSON sidecars
- the predictable directory schema itself

Plot bundles and richer presentation remain Phase 10 work.

## Output Directory Contract

Each run creates:

```text
<output_dir>/<run_name>_<YYYYMMDD_HHMMSS>/
```

The timestamp is generated in UTC. All stage directories are created up front.

The bounded run tree is:

```text
results/
  demo_run_20260423_120000/
    run_manifest.json
    00_run_metadata/
    10_pre_diagnostics/
    20_model_fit/
    30_model_assessment/
    35_holdout_validation/
    40_decomposition/
    50_diagnostics/
    60_response_curves/
    70_optimisation/
```

### Artifact Format Contract

Phase 9 writes:

- Julia-native serialized artifacts:
  - `.jls` payloads for typed model, grouped inference, post-model, and
    optimization surfaces
- analyst/report sidecars:
  - `.csv`
  - `.json`
  - copied / resolved `.yaml`

Phase 9 does not introduce:

- NetCDF / ArviZ-native pipeline artifacts
- pipeline-owned xarray-style outputs
- plotting bundles beyond compact summary sidecars

## Core Sidecar Schema Contract

Phase 9 fixes the minimum schema of the cross-stage sidecars rather than only
their filenames.

### Metadata Stage Sidecars

- `dataset_metadata.json`
  - uses the exact `data` object schema defined for `run_manifest.json`
- `model_metadata.json`
  - required keys:
    - `model_type`
    - `backend`
    - `objective`
    - `nobs`
    - `nchannels`
- `config.original.yaml`
  - verbatim copy of the source YAML
- `config.resolved.yaml`
  - full effective pipeline config including runner-only keys and applied
    runtime overrides
- `config.model.yaml`
  - exact public MMM config passed to `load_public_config`

### Fit And Predictive Summary Sidecars

- `posterior_summary.csv`
  - required columns:
    - `parameter`
    - `mean`
    - `sd`
    - `median`
    - `q05`
    - `q95`
    - `rhat`
    - `ess_bulk`
    - `ess_tail`
- `predictive_summary.csv`
  - required columns:
    - `metric`
    - `value`
- `holdout_summary.csv`
  - required columns:
    - `metric`
    - `value`

### Typed-Surface Projection Sidecars

The following files must be direct projections of already-frozen typed
surfaces rather than new ad hoc summary shapes:

- `contribution_summary.csv`
  - `summary_table(::ContributionResults)`
- `decomposition_summary.csv`
  - `summary_table(::DecompositionResults)`
- `response_curve_summary.csv`
  - `summary_table(::ResponseCurveResults)`
- `metric_summary.csv`
  - `summary_table(::MetricResults)`
- `budget_impact.csv`
  - `budget_impact_table(::BudgetOptimizationResult)`
- `budget_bounds_audit.csv`
  - `budget_audit_table(::BudgetOptimizationResult)`

### Warning Summary Sidecars

- `warnings_summary.json`
  - required keys:
    - `sampler_warnings`
    - `convergence_warnings`
    - `summary`

### Stage-Owned Artifacts

The minimum stage outputs are:

- `00_run_metadata`
  - `config.original.yaml`
  - `config.resolved.yaml`
  - `config.model.yaml`
  - `dataset_metadata.json`
  - `model_metadata.json`
  - `spec_summary.csv`
- `10_pre_diagnostics`
  - `prior_predictive.jls`
  - `prior_predictive_summary.csv`
- `20_model_fit`
  - `model.jls`
  - `inference_results.jls`
  - `posterior_summary.csv`
- `30_model_assessment`
  - `model_results.jls`
  - `observed.csv`
  - `fitted.csv`
  - `residuals.csv`
  - `predictive_summary.csv`
- `35_holdout_validation`
  - `validation_metadata.json`
  - `validation_results.jls`
  - `holdout_summary.csv`
- `40_decomposition`
  - `contribution_results.jls`
  - `decomposition_results.jls`
  - `contribution_summary.csv`
  - `decomposition_summary.csv`
- `50_diagnostics`
  - `model_diagnostics.jls`
  - `sampler_diagnostics.jls`
  - `convergence_report.json`
  - `warnings_summary.json`
- `60_response_curves`
  - `response_curve_results.jls`
  - `metric_results.jls`
  - `response_curve_summary.csv`
  - `metric_summary.csv`
- `70_optimisation`
  - `budget_optimization_result.jls`
  - `budget_impact.csv`
  - `budget_bounds_audit.csv`

Exact filenames may grow, but Phase 9 should not ship with a looser artifact
contract than the above minimum surface.

## Manifest, Failure, And Skip Semantics

The root `run_manifest.json` is the machine-readable index for the whole run.

It must record:

- effective run name
- config path
- output directory
- overall status
- model class
- dataset metadata summary
- per-stage status
- warnings
- top-level failure payload when the run aborts

Stage statuses are fixed to:

- `pending`
- `running`
- `completed`
- `skipped`
- `failed`
- `not_reached`

Failure behavior is fixed:

- the pipeline stops at the first stage failure
- the failed stage is marked `failed`
- later pending stages are marked `not_reached`
- the exception is re-raised after the manifest is updated

Skip behavior is fixed:

- `validation` is skipped when the YAML block is absent or disabled
- `optimisation` is skipped when the YAML block is absent or disabled

## Stage Context Contract

The pipeline context is bounded and stage-owned. Each stage has a fixed input /
output contract:

| Stage | Consumes | Produces | Later Consumers |
|---|---|---|---|
| `metadata` | `PipelineRunConfig`, source YAML, combined CSV | resolved config files, stripped model config, sorted dataset metadata, typed `TimeSeriesMMM`, initialized manifest | all later stages |
| `preflight` | typed model from `metadata`, `prior_samples` | prior predictive stage artifacts only | none |
| `fit` | typed model + sorted dataset from `metadata` | fitted model, `InferenceResults`, posterior summary sidecars | `assessment`, `decomposition`, `diagnostics`, `curves`, `optimisation` |
| `assessment` | Stage `fit` model + `InferenceResults` | `ModelResults`, fitted/residual sidecars, predictive summary | none |
| `validation` | Stage `metadata` config + sorted dataset | side-branch train-window fit, `PipelineValidationResult`, holdout summary | none |
| `decomposition` | Stage `fit` `InferenceResults` | `ContributionResults`, `DecompositionResults`, summary CSVs | none |
| `diagnostics` | Stage `fit` model + `InferenceResults` | diagnostics artifacts and warning summaries | none |
| `curves` | Stage `fit` `InferenceResults`, `curve_points` | `ResponseCurveResults`, `MetricResults`, summary CSVs | none |
| `optimisation` | Stage `fit` `InferenceResults`, YAML `optimization` block | `BudgetOptimizationResult`, budget impact/audit sidecars | none |

In particular:

- Stage `optimisation` consumes Stage `fit` `InferenceResults` directly and
  does not depend on Stage `curves` sidecars.
- Stage `diagnostics` consumes the full-sample fitted model and grouped
  artifacts, not the validation side branch.
- Stage `assessment` and Stage `validation` are distinct:
  - `assessment` is full-sample / in-sample
  - `validation` is blocked holdout / out-of-sample

## In Scope

- `src/pipeline/` and `test/pipeline/` as the ownership layer for the runner
- one YAML-driven time-series MCMC pipeline
- one combined-CSV ingestion path
- one structured run directory and machine-readable manifest
- one blocked holdout validation path
- one optimization stage that consumes the closed Phase 8 contract
- end-to-end integration coverage for the supported pipeline matrix

## Not In Scope

The following remain outside Phase 9:

- panel pipeline support
- YAML-driven VI or backend selection
- separate `X` / `y` CSV ingestion
- holiday catalogue CSV routing beyond existing public event/window features
- partial-stage selection, resume, or continue-after-failure semantics
- plot bundles or rich HTML/PDF reporting
- NetCDF / ArviZ-native run artifacts

Those belong to later pipeline follow-ups or Phase 10 plotting/report work.

## Execution Order

### 09-01: Pipeline Config, Context, And Orchestration Skeleton

**Goal:** freeze the pipeline support matrix, runtime config surface, stage
order, manifest contract, and output schema before stage logic lands.

**Scope:**

- create the `src/pipeline/` ownership layer
- add `PipelineRunConfig`, `PipelineRunResult`, and `PipelineContext`
- implement runner-only YAML parsing and stripping
- create the fixed stage registry and manifest/status model
- create the run-directory scaffolding and artifact-writer helpers
- document the bounded support matrix and output schema

**Acceptance:**

- the pipeline public entry points are explicit
- the bounded runtime keyword shapes are explicit
- runner-only YAML keys are explicit
- the fixed stage order is explicit
- the output directory and manifest contract are explicit
- unsupported panel / VI / split-CSV semantics fail at the contract layer

**Completed:** 2026-04-23

`09-01` landed the initial truthful scaffold in `src/pipeline/` and
`test/pipeline/`: it validated the bounded Phase 9 contract, wrote the run
directory and manifest skeleton, and returned a pending `PipelineRunResult`
without pretending Stage `00`-`70` execution had already landed.

### 09-02: Metadata, Preflight, Fit, And Assessment Stages

**Goal:** land the core disk-backed MMM workflow on the supported time-series
MCMC path.

**Scope:**

- implement Stage 00 metadata/model-build behavior
- implement Stage 10 prior predictive outputs
- implement Stage 20 fit + grouped artifact persistence
- implement Stage 30 in-sample assessment outputs
- write compact CSV / JSON summaries alongside Julia-native artifacts

**Acceptance:**

- a supported YAML config plus CSV dataset can build a typed `TimeSeriesMMM`
- the pipeline can run through fit and in-sample assessment successfully
- persisted stage artifacts are reloadable and use the closed Phases 6-8
  surfaces rather than ad hoc structs
- run metadata and stage status updates remain truthful through Stage 30

**Completed:** 2026-04-23

`09-02` landed the first executable runner slice in `src/pipeline/` and
`test/pipeline/`: at that point the bounded runner executed Stage
`00_run_metadata`, `10_pre_diagnostics`, `20_model_fit`, and
`30_model_assessment` on the supported time-series MCMC path, writing
reloadable Julia-native artifacts plus schema-fixed CSV / JSON / YAML
sidecars. The top-level `PipelineRunResult` remained truthfully `:pending`
until `09-03` landed the remaining Stage `35`-`70` surface.

### 09-03: Validation, Decomposition, Diagnostics, Curves, And Optimisation

**Goal:** complete the remaining bounded stage surface without reopening later
phase work.

**Scope:**

- implement Stage 35 blocked holdout validation
- implement Stage 40 decomposition outputs
- implement Stage 50 diagnostics outputs
- implement Stage 60 response-curve + metric outputs
- implement Stage 70 optional optimization outputs
- finalize skip semantics for optional validation and optimization

**Acceptance:**

- the blocked holdout stage works on the supported time-series path
- decomposition, diagnostics, curves, and optimization all consume the closed
  Phases 6-8 typed surfaces
- omitted optional stages are marked `skipped` rather than failing or silently
  disappearing
- no separate report/plot stage is smuggled into Phase 9

**Completed:** 2026-04-23

`09-03` is now landed in `src/pipeline/` and `test/pipeline/`. The bounded
runner now executes Stage `35_holdout_validation`, `40_decomposition`,
`50_diagnostics`, `60_response_curves`, and optional `70_optimisation` on top
of the earlier `00`-`30` foundation, writing reloadable Julia-native artifacts
plus schema-fixed CSV / JSON / YAML sidecars. Validation remains a side branch
off the full-sample fit path, optimization skips honestly when disabled, and
the top-level `PipelineRunResult` now becomes truthfully `:completed` when all
enabled stages succeed.

### 09-04: CLI Entry Point And End-To-End Integration Coverage

**Goal:** expose the bounded runner through one thin CLI and prove the full
supported workflow end to end.

**Scope:**

- implement `pipeline_main(args = ARGS)` and the thin `epsilon run` path
- add integration tests for:
  - successful full run without optimization
  - successful full run with optimization enabled
  - skipped optional stages
  - contract errors for unsupported panel / VI / split-CSV inputs
  - manifest failure semantics on stage exceptions
- reconcile docs and planning with the final Phase 9 support matrix

**Acceptance:**

- `epsilon run config.yml` produces a structured run directory on the
  supported time-series MCMC path
- the CLI and API route through the same runner implementation
- end-to-end coverage exists for the truthful supported matrix

**Completed:** 2026-04-23

`09-04` is now landed in `src/pipeline/`, `bin/`, and `test/pipeline/`. The
bounded pipeline surface now includes `pipeline_main(args = ARGS)` plus a thin
`bin/epsilon` wrapper for the canonical `epsilon run config.yml` path, both
routing through the same `run_pipeline(config)` implementation. End-to-end
coverage now exists for successful full runs with and without optimization,
optional-stage skip semantics, explicit panel / YAML-driven VI / split-CSV
contract failures, and truthful manifest failure semantics on stage
exceptions.

## Dependencies And Handoff

Phase 9 depends on the frozen Phase 6-8 contracts:

- public YAML/model loading
- `fit!`
- `InferenceResults`
- post-model replay outputs
- `BudgetOptimizationResult`

Phase 10 must depend on Phase 9 rather than bypass it:

- plotting should consume the structured pipeline outputs and frozen stage
  artifact names
- Phase 10 must not invent a second runner or output-directory schema

## Deliverables

At minimum, Phase 9 should leave the repo with:

- `src/pipeline/config.jl`
- `src/pipeline/context.jl`
- `src/pipeline/stages/`
- `src/pipeline/run.jl`
- `src/pipeline/cli.jl`
- `test/pipeline/`
- docs for the bounded pipeline config and output schema
- end-to-end integration coverage for the truthful Phase 9 surface

## Exit Criteria

Phase 9 is complete only when all of the following are true:

- users can run one end-to-end YAML-driven pipeline on the supported
  time-series MCMC path
- the run directory and manifest schema are explicit and test-covered
- the pipeline consumes the frozen Phases 6-8 public surfaces rather than
  re-deriving model, inference, post-model, or optimization semantics
- optional validation and optimization stages are honest and test-covered
- panel and YAML-driven VI remain explicitly unsupported unless later phases
  reopen them
- there is no hidden plotting/report layer bundled into the Phase 9 contract
