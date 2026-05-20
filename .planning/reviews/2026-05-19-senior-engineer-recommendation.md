# Epsilon.jl — Senior Engineer Critical Review and Recommendation

**Date**: 2026-05-19
**Reviewer**: Senior engineering advisor
**Scope**: Code quality, logic/correctness, architecture
**Audience**: Epsilon.jl maintainers planning the next stabilisation pass before v1.0
**Reference branch**: `a9ad7336` (epsilon), upstream `9a0bfe5d` (abacus, methodological reference only)

This document is **not** a general essay. It is an implementable recommendation. Each section ends with concrete actions, schemas, or warnings to add to the docs. Where prior reviews already cover an issue, this document defers to them and focuses on new structural recommendations.

Outstanding prior reviews already on file (do not duplicate work):

- `code-review-v4.md` — trend/holiday state-reconstruction bug, negative-spend validation, silent unknown-key YAML acceptance. **Status: must-fix, still open.**
- `2026-05-19-critical-review.md` — misnamed `logistic_saturation` (is in fact `tanh`-based), excessive export surface, panel-flattening doc gap.
- `stage-70-panel-optimization-design_v2.md` — panel optimisation contract.

This recommendation **assumes those fixes will land** and concentrates on structural problems that those reviews did not address.

---

## 1. Executive summary

Epsilon.jl is methodologically sound and statistically more coherent than its Abacus origin in several places — particularly the typed post-model artifact surface (`ContributionResults`, `DecompositionResults`, `ResponseCurveResults`, etc.), the explicit historical-scaling delta grid for panel response curves, and the bounded `PanelMMMData(time × panel)` / `(time × channel × panel)` layout. These are the design moves to **keep**.

The library is, however, structurally weighed down by three things:

1. **A 3,657-line `pipeline/stages.jl` file** that orchestrates everything imperatively, owns artifact persistence, and is the single largest source of accidental coupling in the repo. There is no `AbstractStage` abstraction; stages are free functions selected by string keys, and the panel branch literally exists as `_skip_panel_pipeline_stages!` that retroactively marks unsupported records as `:skipped`. This is fragile and not extensible.
2. **A `PipelineContext` god object** (`src/pipeline/context.jl`, 533 lines, ~24 mutable fields) carrying raw config, validated config, both `MMMData`/`PanelMMMData`, the model, results, and stage records together — coupling every stage to every other stage's lifetime.
3. **Substantial duplication between `TimeSeriesMMM` and `PanelMMM`**: `_turing_runtime` has two near-identical method bodies (`mmm/model.jl:314-404` and `mmm/model.jl:406-498`), `_panel_turing_runtime` likewise has two (`mmm/panel.jl:204-340` and `mmm/panel.jl:342-478`), and response/saturation/adstock curves split into separate time-series and panel context constructors that share most of their logic (`postmodel/response_curves.jl:1-69`).

Other notable issues:

- **158 `export` statements** in `src/Epsilon.jl` (effectively the entire internal surface). Many of these are implementation details (`expand_masked_values`, `regularized_local_scales`, `_string_*` helpers indirectly).
- **`nobs(data::PanelMMMData) = length(data.target)`** (`src/model/types.jl:305`) returns *total panel-cells* (time × panel), not time rows. This contradicts coordinate metadata, which records `"time"` rows. It is a correctness time-bomb.
- **The flat panel-dim name is asymmetric**: `_flat_panel_dim_name` (`src/model/builder.jl:92-95`) returns the *declared dimension name* for 1-D panels but the *literal string `"panel"`* for multi-D panels. Downstream serialisation and joins must therefore special-case both.
- **`PanelMMMData.panel_coordinates`** is a `Dict{String, Vector{String}}` (`src/model/types.jl:267`) — this loses the declared panel-dim *order*, which must then be carried separately in `ModelCoordinateMetadata.panel_dims::Tuple{Vararg{String}}`. The two data structures can disagree.
- **Module loading order** in `src/Epsilon.jl` includes `transforms/*.jl` **after** `mmm/*.jl`, `inference/*.jl`, `postmodel/*.jl`, `optimization/*.jl`, and `pipeline/*.jl` (lines 208–211 vs. 168–207). This works because Julia resolves at call time, but it is semantically backwards: every module that *uses* the transforms is loaded before them. New contributors will get burnt by this.
- **The panel branch deliberately skips `preflight` and `validation` stages** by post-hoc marking them `:skipped`. That is the wrong direction; the stage list should never have included them.
- **Holdout validation** is wired only for time-series and is brittle: predictions during validation recompute trend/holiday bases from the holdout window rather than from fitted state (see `code-review-v4.md`). For panels it does not exist at all.

Overall grade: **B for methodology, C+ for engineering structure.** The methodology is in better shape than the structure.

---

## 2. Recommendations

The recommendations are grouped into four streams. Each stream is independent enough to land separately.

- **Stream A — Coordinate and panel-axis schema** (do first, everything else depends on it)
- **Stream B — Stage abstraction and artifact persistence**
- **Stream C — Post-model surface stabilisation**
- **Stream D — Public API curation and module loading**

Stream A is the only one that has *downstream* schema implications and should land before v1.0. The others are quality-of-life and maintainability improvements.

---

### Stream A — Coordinate and panel-axis schema (must-fix before v1.0)

#### A.1 Replace `Dict{String, Vector{String}}` with an ordered structure

**Problem.** `PanelMMMData.panel_coordinates` (`src/model/types.jl:267`) and `ModelCoordinateMetadata.coordinates` (`src/model/builder.jl:10`) both store coordinate values keyed by dimension name in a plain `Dict`. The declared dimension *order* is carried separately by `ModelCoordinateMetadata.panel_dims::Tuple{Vararg{String}}`. There is nothing preventing the dict and the tuple from disagreeing.

The deterministic flat panel axis is constructed by `_panel_coordinate_value_product` (`src/model/builder.jl:97-106`) as the lexicographic product over `metadata.panel_dims`, so any disagreement between `panel_dims` and the dict silently produces a *wrong* flat axis with no exception.

**Recommendation.** Introduce a small ordered container and centralise *all* construction of the flat axis through it.

```julia
"""
    PanelAxis

Deterministic, ordered description of the flat panel-cell axis used internally
by bounded panel MMM models.

Fields:
- `dims::Vector{Symbol}`           — declared panel dimensions in declared order
- `coordinates::Vector{Vector{String}}` — coordinate values per dimension, same order as `dims`
- `flat_names::Vector{String}`     — deterministic flat panel labels (cartesian product)
- `flat_to_coord::Vector{NTuple{N, String} where N}` — one tuple per flat index

Invariants enforced at construction:
- length(dims) == length(coordinates)
- length(flat_names) == prod(length.(coordinates))
- `flat_names[i]` is uniquely determined by `flat_to_coord[i]` via a canonical separator
- when length(dims) == 1, flat_names == coordinates[1]
"""
struct PanelAxis
    dims::Vector{Symbol}
    coordinates::Vector{Vector{String}}
    flat_names::Vector{String}
    flat_to_coord::Vector{Tuple}
end
```

- Construct it once from validated input. Never reconstruct it from `Dict` later.
- Replace `PanelMMMData.panel_coordinates::Dict{...}` with `panel_axis::PanelAxis`.
- Replace the `coordinates`/`panel_dims` fields of `ModelCoordinateMetadata` with a single `panel_axis::PanelAxis` plus the `observation_dim` and `named_dims` it already has.
- `_flat_panel_dim_name` (which returns either the declared dim or the literal `"panel"`) becomes redundant; callers should ask the axis directly.

**Migration**: a single deprecation cycle is enough since the panel surface is documented as bounded. Keep readers for the old serialised format for one release.

#### A.2 Make the flat panel-axis name *always* explicit

**Problem.** `_flat_panel_dim_name` (`src/model/builder.jl:92-95`):

```julia
return length(metadata.panel_dims) == 1 ? only(metadata.panel_dims) : "panel"
```

For one-dim panels this returns `"geo"`; for multi-dim panels it returns `"panel"`. Every downstream serialiser (results CSVs, summary tables, the optimizer summary, plots) must branch on this.

**Recommendation.** Always export *both*:

- a fixed internal axis name, `:panel_cell` (or simply `:panel`)
- the per-row declared coordinate columns (`geo`, `brand`, ...)

Summaries should *always* contain the internal flat axis column **and** each declared coordinate column. This eliminates the special case.

```
panel_cell | geo | brand | …
1          | UK  | Alpha | …
2          | UK  | Beta  | …
```

For 1-D panels, `panel_cell` is redundant with `geo` but carrying it harmlessly keeps the schema stable.

#### A.3 Fix `nobs(PanelMMMData)`

**Problem.** `nobs(data::PanelMMMData) = length(data.target)` (`src/model/types.jl:305`) returns `time × panel`, not `time`. The doc string for `nobs` says "number of observations". For a panel that means rows of the panel-cell × time matrix, *not* the product. `MMMModelSpec.nobs` stores this same conflated value (`src/model/builder.jl:135`).

This is acceptable today only because no panel diagnostic, summary, or predictive table generically consumes `spec.nobs`. As soon as one does, computed metrics (AIC-like, df, residual variance estimators) will be silently wrong.

**Recommendation.**

- Define and use two unambiguous accessors:
  - `ntime(data)` — number of time rows
  - `npanels(data)` — number of flat panel cells
  - `nobs(data::PanelMMMData) = ntime(data) * npanels(data)` may stay only if **renamed** and documented as "panel-cell observations". I would simply remove the method.
- Store `ntime` and `npanels` separately in `MMMModelSpec`; remove the conflated `nobs` field from spec.

#### A.4 Documentation warnings to add

Add to `docs/src/index.md` (or a new `docs/src/panel.md`) — and reference from the docstrings of `PanelMMMData`, `panel_coordinates`, and `panel_coordinate`:

> **Warning — flat panel-cell axis.** Epsilon represents multi-dimensional panel models (e.g. `geo × brand`) on a deterministic *flat* panel-cell axis. The flat axis is the cartesian product of declared `panel_dims` in declared order; the ordering is part of Epsilon's data contract and not user-configurable post hoc. Coordinate columns (`geo`, `brand`, ...) are preserved in all post-model summaries; users **should join on the declared coordinate columns**, never on the internal `panel_cell` index, when comparing across runs.

> **Warning — `nobs` semantics changed.** Until version vX.Y, `nobs(::PanelMMMData)` returned `time × panel`. From vX.Y onwards, panel datasets expose `ntime` and `npanels` separately; the old `nobs` is removed.

---

### Stream B — Stage abstraction and artifact persistence

#### B.1 Introduce an `AbstractPipelineStage` trait

**Problem.** `pipeline/stages.jl` is 3,657 lines. Composition is two hand-written `if`/`else` blocks in `_run_all_pipeline_stages!` (`src/pipeline/stages.jl:9-39`). The panel branch concludes with `_skip_panel_pipeline_stages!` (lines 41–59) which iterates the stage records and rewrites the status of any panel-unsupported stage to `:skipped`. That is *deletion via post-processing* — it tells you the abstraction is wrong.

**Recommendation.** Replace string keys + free functions with a small typed stage registry. The stage is the unit of composition.

```julia
abstract type AbstractPipelineStage end

"""
    PipelineStage{kind}

A pipeline stage is identified by a `Symbol` kind, knows the model kinds it
applies to, and exposes `run!`, `inputs`, and `outputs` contracts.

Required interface:
- `kind(stage)::Symbol`
- `applies_to(stage)::NTuple{N, Symbol}`     # e.g. (:time_series, :panel)
- `directory(stage)::String`                  # e.g. "20_model_fit"
- `inputs(stage)::Vector{Symbol}`             # stage kinds this stage reads
- `outputs(stage)::Vector{Symbol}`            # artifact-key names this stage writes
- `run!(stage, context)::StageResult`
"""
struct PipelineStage{K} <: AbstractPipelineStage
    applies_to::NTuple{<:Any, Symbol}
    directory::String
    inputs::Vector{Symbol}
    outputs::Vector{Symbol}
    runner::Function
end

struct StageResult
    status::Symbol                            # :completed | :skipped | :failed
    artifact_paths::Dict{String, String}
    warnings::Vector{String}
    duration_seconds::Float64
end
```

Then:

- Each existing `_run_<name>_stage!` becomes a `PipelineStage` value in a registry: `const PIPELINE_STAGES = Dict{Symbol, PipelineStage}(...)`.
- The orchestrator becomes:
  ```julia
  for kind in stages_for(model_kind)
      stage = PIPELINE_STAGES[kind]
      _run_stage!(context, stage)
  end
  ```
- The panel branch lists exactly the stages it supports. **Delete `_skip_panel_pipeline_stages!` entirely.** A stage that is not in the panel list is simply not in the manifest. (See B.4 for the doc warning.)

This will not on its own reduce `stages.jl` by 3,657 lines, but it does isolate orchestration (a few hundred lines) from the per-stage I/O and computation (the bulk of the file) which can then be split per stage into `src/pipeline/stages/fit.jl`, `src/pipeline/stages/decomposition.jl`, etc.

#### B.2 Make `PipelineContext` immutable per stage, with a typed `StageInputs`

**Problem.** `PipelineContext` (`src/pipeline/context.jl:212-239`) has ~24 mutable fields. Every stage mutates it. Stage *N* implicitly depends on stage *N−1*'s writes; if you reorder or skip, you can get a `Nothing` field at runtime.

**Recommendation.** Keep one orchestration object, but make each stage's input typed and minimal:

```julia
struct StageInputs
    config::ResolvedConfig
    data::Union{MMMData, PanelMMMData}
    model::Union{Nothing, AbstractMMMModel}
    inference::Union{Nothing, InferenceResults}
    artifacts::Dict{Symbol, Any}              # produced by earlier stages
    stage_dir::String
    run_dir::String
end
```

A stage receives `StageInputs` and returns a `StageResult`. The orchestrator is the only thing that touches the mutable big context. This is a thin, mechanical change — no algorithmic rewrite — and it tames the god object.

#### B.3 Codify the artifact directory schema

Right now the numbered directory contract (`00_run_metadata`, `10_pre_diagnostics`, `20_model_fit`, `30_model_assessment`, `35_holdout_validation`, `40_decomposition`, `50_diagnostics`, `60_response_curves`, `70_optimisation`) is hard-coded throughout `stages.jl`. Make it the responsibility of each `PipelineStage` value:

| Stage kind          | Directory               | Applies to               | Outputs (suggested keys)                                  |
| ------------------- | ----------------------- | ------------------------ | --------------------------------------------------------- |
| `metadata`          | `00_run_metadata`       | time_series, panel       | `manifest.json`, `resolved_config.yml`                    |
| `prior_sensitivity` | `05_prior_sensitivity`  | time_series, panel       | one subdirectory per scenario                             |
| `preflight`         | `10_pre_diagnostics`    | time_series              | `data_summary.csv`, `data_quality_report.json`            |
| `fit`               | `20_model_fit`          | time_series, panel       | `model.jls`, `inference_results.jls`, `fit_summary.csv`   |
| `assessment`        | `30_model_assessment`   | time_series, panel       | `assessment_metrics.csv`, `posterior_predictive.jls`      |
| `validation`        | `35_holdout_validation` | **time_series only**     | `holdout_*` family (see §B.4 for the panel decision)      |
| `decomposition`     | `40_decomposition`      | time_series, panel       | `decomposition.csv`, `contributions.jls`                  |
| `diagnostics`       | `50_diagnostics`        | time_series, panel       | `parameter_diagnostics.csv`, `convergence_report.json`    |
| `curves`            | `60_response_curves`    | time_series, panel       | `response_curves.csv`, `saturation_curves.csv`, `adstock_curves.csv`, `metrics.csv` |
| `optimisation`      | `70_optimisation`       | time_series, panel       | `budget_audit.csv`, `budget_impact.csv`, `scenarios/`     |

This is what the table belongs to: a unit test that consumes the registry and asserts directory schema parity, *not* a wiki page that drifts.

#### B.4 Holdout validation — recommendation

Given the user's stated context that panel holdout validation is likely deferred and is not central to MMM, and given the *existing* time-series holdout validation already has a state-reconstruction bug (`code-review-v4.md`):

**Recommendation.**

1. **Time-series holdout validation**: keep, but block it behind the trend/holiday state-persistence fix from `code-review-v4.md`. Until then, mark it as **experimental** in the docs.
2. **Panel holdout validation**: do **not** stub it. Remove it from the panel stage list cleanly (Stream B.1 makes that one-line). Drop the `35_holdout_validation` directory from panel runs entirely. **Delete `_skip_panel_pipeline_stages!`.** The panel manifest should simply not contain a `validation` entry.

Documentation warning to add:

> **Warning — panel holdout validation.** Out-of-time holdout validation is currently supported for `TimeSeriesMMM` only. Panel MMM holdout validation is intentionally not implemented in this release because (a) panel cells share global parameters and a leave-future-out scheme is methodologically less informative than for a single time series, and (b) panel-aware predictive recomputation is not implemented for trend/holiday bases. Use posterior predictive checks at the panel-cell level for fit assessment.

3. **Time-series holdout validation** must also call out the trend/holiday-window risk in the docs until fixed:

> **Warning — holdout predictions and date-derived features.** Trend and holiday features in the current model path are computed relative to the *first date of the supplied data*. Out-of-time predictions on a small or single-row window therefore re-anchor the trend origin and may infer a different holiday observation period from the fitted model. Until this is fixed, treat holdout metrics as upper bounds on out-of-sample performance, and validate visually against the fitted residual ACF (`50_diagnostics/residuals_acf.png`).

---

### Stream C — Post-model surface stabilisation

The typed post-model surface (`ContributionResults`, `DecompositionResults`, `ResponseCurveResults`, `SaturationCurveResults`, `AdstockCurveResults`, `MetricResults` — defined in `src/postmodel/types.jl`) is the **best-designed** part of Epsilon. The shape contracts are clear and panel-aware. The work here is to *lock in* the schemas and clean up shared internals.

#### C.1 Stabilised schemas

| Type                       | Time-series shape of `values`            | Panel shape of `values`                          | Axis order (must be documented) |
| -------------------------- | ---------------------------------------- | ------------------------------------------------ | ------------------------------- |
| `ContributionResults`      | `(draw, observation, component)`         | `(draw, time, panel_cell, component)`            | (draw, time, …, component)      |
| `DecompositionResults`     | `(draw, component)`                      | `(draw, panel_cell, component)`                  | (draw, …, component)            |
| `ResponseCurveResults`     | `(draw, spend_point)`                    | `(draw, panel_cell, spend_point)`                | (draw, panel_cell, spend_point) |
| `SaturationCurveResults`   | `(draw, spend_point)`                    | `(draw, panel_cell, spend_point)`                | identical to response           |
| `AdstockCurveResults`      | `(draw, spend_point)`                    | `(draw, panel_cell, spend_point)`                | identical to response           |
| `MetricResults`            | `(draw, spend_point, metric)`            | `(draw, panel_cell, spend_point, metric)`        | (…, metric is always last)      |

Locking these means:

- A regression test per type asserting `size(values)` axis order on both a time-series and a panel fixture.
- `summary_table` output schema documented per type (column names, dtypes, sort order).
- Backwards-incompatible changes to these shapes are a major-version-bump event.

#### C.2 Document the historical-scaling delta grid contract

The panel response/saturation/adstock curves do **not** use an aggregate spend grid (as the time-series curves do). They use a **shared multiplicative delta grid** over the per-cell observed historical spend path:

```
spend_grid[panel_cell, point] = observed_spend[panel_cell] * delta_grid[point]
```

(see `src/postmodel/response_curves.jl:33-69`, especially line 59:
`spend_grid = observed_spend * transpose(delta_values)`).

This is **the methodologically correct choice for panels** because aggregating spend across heterogeneous cells and re-allocating it produces curves that depend on the allocation rule, not on the model. Epsilon should make this an explicit, *named*, and *required* contract.

**Recommendation:**

- Rename the `delta_grid` keyword argument on `response_curve_results`/`saturation_curve_results`/`adstock_curve_results` to `historical_scaling_delta_grid` (or expose both names; deprecate the short one in a future release). The current short name is too generic.
- Validate that `delta_grid` is strictly positive and that `1.0 ∈ delta_grid` (so the observed-spend point is always on the curve). Today this is not enforced.
- Add to `ResponseCurveResults`'s docstring:

```
For bounded panel replay, `spend_grid` is a `(panel_cell, spend_point)` matrix
formed as `observed_spend ⊗ delta_grid`. The delta grid is *not* an aggregate
spend grid: it is a multiplicative rescaling of each panel cell's observed
historical spend path. This ensures that:

1. Each cell's saturation parameters are evaluated on its own data scale.
2. Curves are comparable across cells in *relative* (per-cell) terms.
3. The point `delta = 1.0` always lies on the curve and reproduces the
   observed-spend contribution.

A documented consequence: panel curves are NOT directly comparable to
time-series curves at equal absolute spend.
```

Add a documentation warning:

> **Warning — panel response curves are relative.** Panel response, saturation, and adstock curves are evaluated on a per-cell historical-scaling delta grid. Two panel cells at `delta = 2.0` do **not** in general receive the same absolute incremental spend. To compare absolute incremental spend across cells, post-process: `spend_grid[i, j] = observed_spend[i] * delta[j]`.

#### C.3 Consolidate the curve context constructors

`_curve_surface_context` (`src/postmodel/response_curves.jl:1-31`) and `_panel_curve_surface_context` (lines 33–69) are 80 % the same code. They differ in two things: time-series uses a 1-D channel vector, panel uses a 2-D `(time, panel)` per-channel slice and a delta grid. The duplication is solvable with a small `CurveContext` struct parameterised by a `CurveBackend{:time_series}` / `CurveBackend{:panel}` trait. Same applies to the `_channel_*_path_for_draw` and `_panel_channel_*_path_for_draw` families (see `src/postmodel/replay.jl`, ~959 lines; this file is the next refactor target after `pipeline/stages.jl`).

#### C.4 Saturation function naming — final form

Endorse the rename already recommended in `2026-05-19-critical-review.md`:

- The current `logistic_saturation(x, λ)` (`src/transforms/saturation.jl:33`) implements a `tanh`-based curve. Rename to `tanh_saturation` (or `centered_logistic_saturation` is already correct — keep that). Introduce a proper `logistic_saturation(x, k) = 1 / (1 + exp(-k*x))`. Add a one-release deprecation cycle.

Documentation warning to add to the saturation page until the rename ships:

> **Warning — `logistic_saturation` is `tanh`-based.** In this release `logistic_saturation(x, λ)` returns `tanh(λ * x / 2)`, not the standard logistic `1 / (1 + exp(-λx))`. This is being renamed to `tanh_saturation` in the next minor release. If you rely on the standard logistic, do not use this function; compute it directly.

---

### Stream D — Public API curation and module loading

#### D.1 Curate exports

158 export statements is a kitchen-sink interface. It guarantees that *any* internal rename is a breaking change. Apply a two-tier approach:

- **Tier 1 (exported)**: the symbols a user typing `using Epsilon` needs. Roughly:
  - Top-level entry: `run_pipeline`, `pipeline_main`, `epsilon_version`
  - Model construction: `ModelConfig`, `model_config_from_dict`, `load_model_config`, `MMMModelSpec`, `MMMData`, `PanelMMMData`, `build_model`, `TimeSeriesMMM`, `PanelMMM`
  - Inference: `fit!`, `approximate_fit!`, `predict`, `prior_predict`, `inference_results`, `model_results`, `SamplerConfig`, `VariationalConfig`
  - Post-model: `contribution_results`, `decomposition_results`, `response_curve_results`, `saturation_curve_results`, `adstock_curve_results`, `metric_results`, `summary_table`
  - Plotting: the `*_plot` family
  - Optimisation: `optimize_budget`, `scenario_plan`, the scenario specs
  - Diagnostics: `model_diagnostics`, `convergence_report`, `sampler_diagnostics`
- **Tier 2 (qualified)**: everything else, accessible via `Epsilon.Transforms.batched_convolution`, `Epsilon.Priors.HorseshoePrior`, etc. Move the implementation into submodules of `Epsilon` so this qualification is natural.

This is roughly a **3-to-1 reduction** of exports (target ~50). A single release with `@deprecate_export` shims is enough to keep current scripts working.

#### D.2 Reorder includes in `src/Epsilon.jl`

Move `transforms/*.jl` includes (currently lines 208–211) to the top of the include block, before `distributions/*`, `model/*`, and `mmm/*`. Today it works only because the `@model` macro expansion defers symbol lookup, but it is the wrong dependency direction and will trip people up. While there, also load `inference/results.jl` *before* `mmm/model.jl` — `InferenceResults` is referenced by mmm code.

#### D.3 De-duplicate the two `_turing_runtime` methods (mmm/model.jl and mmm/panel.jl)

The pattern is the same in both files:

- `mmm/model.jl:314-404` (`_turing_runtime(config::ModelConfig, ...)`) and `mmm/model.jl:406-498` (`_turing_runtime(spec::MMMModelSpec, ...)`) share ~90 lines of identical body.
- `mmm/panel.jl:204-340` and `mmm/panel.jl:342-478` show the same pattern.

**Recommendation.** A small interface trait:

```julia
abstract type AbstractRuntimeSource end
struct ConfigSource <: AbstractRuntimeSource; config::ModelConfig; end
struct SpecSource   <: AbstractRuntimeSource; spec::MMMModelSpec; end

# field accessors with one method per source
_target_column(s::ConfigSource) = s.config.target_column
_target_column(s::SpecSource)   = s.spec.target_column
# … etc …

_turing_runtime(source::AbstractRuntimeSource, data) = …  # single body
```

Then `_turing_runtime(config::ModelConfig, data)` and `_turing_runtime(spec::MMMModelSpec, data)` become one-liner adapters that wrap in `ConfigSource` / `SpecSource`. Same shape for `_panel_turing_runtime`.

This removes ~180 lines and a real maintenance hazard.

#### D.4 Scaler design — make immutable + value-returning

`MaxAbsScaler` / `StandardScaler` (`src/transforms/scaling.jl:6-28`) are mutable structs with a `fitted::Bool` flag. Julia idiom is an *immutable* configuration struct plus a separate fitted-state struct:

```julia
struct MaxAbsScaler end
struct FittedMaxAbsScaler{T<:Real}
    scale::T
end
fit(::MaxAbsScaler, x) = FittedMaxAbsScaler(maximum(abs, x))
transform(s::FittedMaxAbsScaler, x) = x ./ s.scale
inverse_transform(s::FittedMaxAbsScaler, x) = x .* s.scale
```

This is a small, mechanical, type-stability and clarity win. Not blocking for v1.0.

---

## 3. Issues we are explicitly *not* recommending changing

For the avoidance of doubt:

- **The flat panel-cell axis itself.** This is the right internal design. Stream A only formalises and orders it.
- **The typed post-model surface.** Keep all six types in `postmodel/types.jl`. They are coherent.
- **The historical-scaling delta grid for panel curves.** This is more statistically coherent than an aggregate spend grid would be. Stream C only renames the keyword and adds validation.
- **Turing + Distributions + AdvancedVI as the inference backend.** Don't reopen this.
- **The numbered artifact directory convention (`00_`, `10_`, ... `70_`).** Stream B only codifies it.
- **Variational inference being mean-field-only and time-series-only.** Document the restriction; do not extend it now.
- **Per-channel adstock / saturation forms (`geometric_adstock`, `delayed_adstock`, `weibull_adstock`, `hill_function`, `michaelis_menten`, `tanh_saturation`, `centered_logistic_saturation`).** These are well-tested against Abacus fixtures.

---

## 4. Suggested ordering and effort

| Stream | Estimated effort | Risk | Blocking for v1.0 |
| ------ | ---------------- | ---- | ----------------- |
| A — coordinate / panel-axis schema | M (1–2 weeks) | Medium (touches serialisation) | **Yes** |
| B.1–B.3 — stage abstraction & schema | M (2–3 weeks) | Low (mechanical refactor) | No |
| B.4 — holdout validation decision | S (1–2 days) | Low | **Yes** (decision must land in docs) |
| C.1 — schema lock-in tests | S | Low | **Yes** |
| C.2 — delta-grid contract & rename | S | Low | **Yes** |
| C.3 — curve context consolidation | M | Low | No |
| C.4 — `logistic_saturation` rename | S | Low (one-release deprecation) | **Yes** (rename ships in v1.0 with deprecation) |
| D.1 — export curation | M | Medium (any consumer scripts) | Recommended |
| D.2 — include order | XS | Low | No |
| D.3 — `_turing_runtime` de-dup | M | Low (purely structural) | No |
| D.4 — immutable scalers | S | Low | No |

Plus, from prior reviews:

- **`code-review-v4.md`**: trend/holiday persistence bug, negative-spend validation, silent unknown-key YAML rejection — **all blocking for v1.0**.

---

## 5. Documentation warnings to add (consolidated)

These should land verbatim in `docs/src/`:

1. **Panel flat axis & coordinate joining** (Stream A.4)
2. **`nobs` semantics changed** (Stream A.4)
3. **Panel holdout validation not supported** (Stream B.4)
4. **Time-series holdout date-feature limitation** (Stream B.4)
5. **Panel response curves are relative** (Stream C.2)
6. **`logistic_saturation` is `tanh`-based pending rename** (Stream C.4)

These are the user-visible behaviours that are presently surprising and must be either fixed or documented before v1.0.

---

## 6. Closing assessment

Epsilon.jl is closer to a coherent v1.0 than the code volume suggests. The methodological core (transforms, priors, inference shape, typed post-model surface, panel delta-grid contract) is in good shape and several decisions are *better* than the Abacus original. The remaining gap to v1.0 is **structural discipline**, not statistics:

- An ordered, single-source-of-truth panel axis (Stream A).
- A stage abstraction so that `pipeline/stages.jl` stops being a 3.6k-line god file (Stream B).
- Locked-in artifact schemas with regression tests (Stream C.1).
- A curated public API (Stream D.1).

If those four land — plus the open `code-review-v4.md` items — Epsilon is ready for v1.0 with a credible, narrow, panel-aware MMM contract, and the AI advisor / dashboard parity scope can stay safely deferred without leaving load-bearing hooks in the core library.
