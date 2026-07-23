# Epsilon.jl Architecture

This document is a contributor map for Epsilon's main execution path. It
describes how a user-facing configuration becomes a fitted Bayesian MMM result,
where the major modules live, and which extension points are deliberately
bounded in the current beta line.

Epsilon is a compact Julia package, not a service or dashboard application. The
core design favours typed model objects, local reproducibility, explicit
artifact boundaries, and conservative capability gating.

## Layer Map

The package is organised around a one-way modelling flow:

```text
distributions
  -> model config/data/spec
  -> MMM feature builders
  -> inference
  -> post-model replay
  -> optimisation and scenario summaries
  -> pipeline and optional plotting
```

Key paths:

| Layer | Main paths | Responsibility |
| --- | --- | --- |
| Priors and distributions | `src/distributions/` | Julia-native prior specifications and instantiated distributions |
| Model data and config | `src/model/types.jl`, `src/model/config.jl` | Public config/data containers, validation, YAML-facing normalisation |
| Model building | `src/model/builder.jl` | Compile validated config/data into `MMMModelSpec` and coordinate metadata |
| MMM likelihood | `src/mmm/` | Media transforms, controls, holidays, events, seasonality, trend, calibration, Turing model definitions |
| Inference | `src/inference/` | MCMC execution plans, diagnostics, grouped inference artifacts |
| Post-model quantities | `src/postmodel/` | Posterior replay, contributions, decomposition, response curves, metrics |
| Optimisation | `src/optimization/` | Bounded fixed-budget optimisation, allocation evaluation, decision summaries |
| Scenario planning | `src/scenario_planner.jl` | Typed scenario specs and comparison surfaces |
| Pipeline | `src/pipeline/` | Config-driven local runner, stage directories, manifests, skipped-stage markers |
| Plotting | `src/plotting/`, `ext/EpsilonCairoMakieExt.jl` | Core plotting stubs and optional CairoMakie-backed methods |
| Transforms | `src/transforms/` | Public adstock, saturation, convolution, and scaling primitives |

`src/Epsilon.jl` is intentionally small. It includes `src/exports.jl` and
`src/includes.jl`, then defines the few public forwarding entry points that
need methods loaded from several layers.

## Config To Runtime Path

The main time-series path is:

```text
YAML / programmatic config
  -> ModelConfig
  -> MMMData
  -> TimeSeriesMMM
  -> MMMModelSpec
  -> Turing runtime NamedTuple
  -> Turing @model
  -> ModelFitState artifact
```

`ModelConfig` is the public configuration authority. It validates columns,
model blocks, priors, sampler settings, and unsupported keys early. External
YAML remains dictionary-shaped at the boundary, but model construction
normalises it before fitting.

`MMMData` owns the observed target, media channel matrix, optional controls,
optional events, and row dates. Constructor validation checks sizes, finite
values, channel names, and nonnegative media values before model fitting.

`MMMModelSpec` is the compiled model contract. It stores resolved model
settings, channel/target scaling, prior specifications, coordinate metadata,
and feature-state needed for fitted prediction. Post-fit replay should prefer
the fitted artifact's spec over mutable model config, so predictions remain
stable even if a user edits the model object after fitting.

The private Turing runtime converts the spec into concrete objects used inside
the `@model`: instantiated prior distributions, feature matrices, transform
settings, dimensions, and calibration payloads.

## Fitting Lifecycle

The fitted model lifecycle is explicit:

1. `build_model(model)` validates and compiles a spec without sampling.
2. `fit!(model)` compiles the spec, builds the Turing model, samples with
   NUTS, and stores a `ModelFitState`.
3. Successful fits store a Turing-backed artifact with chain, runtime, spec,
   metadata, execution plan, and optional diagnostics.
4. Failed fits replace stale successful state with an error state. Downstream
   prediction and post-model APIs fail closed if the last fit failed.

The maintained inference backend is Turing/NUTS MCMC. Variational inference is
not part of Epsilon's supported surface.

## Result And Artifact Flow

Low-level fit artifacts are converted into user-facing result envelopes:

| Entry point | Output |
| --- | --- |
| `model_results(model)` | Flat fitted result container |
| `inference_results(model)` | Grouped posterior, predictive, prior, and sample-stat artifact |
| `contribution_results(model)` | Posterior media contribution summaries |
| `decomposition_results(model)` | Additive component decomposition |
| `response_curve_results(model)` | Channel response curves |
| `metric_results(model)` | ROAS/CPA-style summary metrics |
| `optimize_budget(...)` | Bounded fixed-budget optimisation result |
| `evaluate_budget_allocation(...)` | Posterior replay for a supplied allocation |

Pipeline runs write these surfaces into structured stage directories under a
run folder. Optional or unsupported stages still write explicit skipped-stage
markers so absence of an artifact is not ambiguous.

Julia `.jls` artifacts are trusted-local serialisation outputs. They are not
portable interchange files and must not be loaded from untrusted sources.

## Time-Series And Panel Boundaries

Time-series MMM is the most complete path. Panel MMM is deliberately bounded.

| Capability | Time-series | Panel |
| --- | --- | --- |
| Turing/NUTS fit | Supported | Supported |
| Adstock and saturation | Supported | Supported |
| Controls | Supported | Deferred |
| Events | Supported | Deferred |
| Holidays | Supported | Supported |
| Fourier seasonality | Supported | Supported |
| Trend | Supported | Deferred |
| Calibration | Bounded logistic lift-test and cost-per-target paths | Deferred |
| Holdout validation | Supported | Deferred |
| Budget optimisation | Channel-level fixed budget | Historical-share allocation only |
| Free channel-by-panel optimisation | Deferred | Deferred |

When adding features, avoid making panel behaviour appear broader than it is.
Unsupported panel blocks should fail clearly or write explicit skipped-stage
artifacts, depending on whether the failure is a config problem or an optional
pipeline stage.

## Adding A Transform

A new adstock or saturation path normally needs updates in several places:

1. Add the low-level transform under `src/transforms/`.
2. Add validation and runtime dispatch in `src/mmm/media.jl` and the panel
   media path if panel support is intended.
3. Add config/spec handling in `src/model/builder.jl`.
4. Add prior defaults and coordinate metadata for any new sampled parameters.
5. Add deterministic unit tests for the transform, including invalid inputs.
6. Add at least one model smoke test proving the Turing parameter is present
   and the fitted path runs.
7. Update methodology docs if the transform is public.

Do not add a config value unless the fitted path, post-model replay path, and
documentation all agree about the semantics.

## Optimisation Boundary

The maintained optimiser solves bounded fixed-budget allocation over supported
channel-level response surfaces. It does not refit the MMM and it does not
perform free channel-by-panel allocation.

Decision helpers such as `budget_utility_value` score posterior response draws
after allocation evaluation. They are pure decision diagnostics unless and
until a future solver objective explicitly opts into a utility.

## Verification Expectations

Use scoped checks during development:

```bash
make format-check-touched
make test-file FILE=test/inference/recovery.jl
make test-file FILE=test/inference/runtests.jl
make docs
```

Use the full local release gate only for release-facing changes:

```bash
make check-release
```

The test suite uses file selectors through `Pkg.test`, so prefer Make targets
over direct `include(...)` calls.
