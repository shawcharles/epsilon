# Epsilon.jl

`Epsilon.jl` is a Julia-native Bayesian marketing mix modelling library. It
supports a bounded, practical MMM workflow: configure a model in YAML, provide
data and holidays, run MCMC inference, and inspect structured result folders
with model fit artifacts, diagnostics, decomposition, response curves,
validation where supported, plots, and optional optimisation outputs.

Epsilon is pre-release software. The maintained paths are intended for toy,
demo, and local analysis workflows while the public API continues to settle.

## Quick Start

From the repository root:

```bash
julia --project=. runme.jl
```

That command runs the bundled time-series demo with small local settings. To
run the same config explicitly:

```bash
julia --project=. runme.jl data/demo/timeseries/config.yml --quick
```

Outputs are written under `results/<run_name>_<timestamp>/`. The runner prints
the Epsilon header, resolved run context, stage progress bars, plotting status,
and a final summary.

For smoke checks:

```bash
make smoke
make smoke-demo-configs
```

## Supported Workflow

The primary workflow is config driven:

```text
config.yml
dataset.csv
holidays.csv
```

Runnable demo bundles are available under:

- `data/demo/timeseries/`
- `data/demo/geo_panel/`
- `data/demo/geo_brand_panel/`

See [Supported Local Workflows](supported_paths.md) for the full runbook,
compact output inspection, trusted-local artifact roundtrips, and smoke
commands.

For the fitted regression structure and media-response equations, see
[Model Form](methodology/model.md) and
[Media Transforms](methodology/media_transforms.md).

## Programmatic Entry Point

```julia
using Epsilon

result = run_pipeline(
    PipelineRunConfig(
        config_path = "data/demo/timeseries/config.yml",
        output_dir = "results",
        run_name = "demo",
        draws = 20,
        tune = 20,
        chains = 1,
        cores = 1,
        random_seed = 123,
    ),
)

println(result.status)
println(result.run_dir)
```

Lower-level model construction, fitting, post-model analysis, optimisation,
scenario-planning, and plotting APIs are available for Julia users who want to
work directly with typed model objects. See [Public API](api.md).

## Result Folders

A successful pipeline run writes a manifest and stage directories:

```text
run_manifest.json
00_run_metadata/
05_prior_sensitivity/
10_pre_diagnostics/
20_model_fit/
30_model_assessment/
35_holdout_validation/
40_decomposition/
50_diagnostics/
60_response_curves/
70_optimisation/
```

Skipped optional stages still create a directory and write `SKIPPED.json`, with
the marker also recorded in `run_manifest.json`.

Julia `.jls` files are trusted-local serialisation artifacts. They are bound to
the Julia, Epsilon, and dependency versions that wrote them and should not be
loaded from untrusted sources.

## Supported Surface

Currently supported:

- time-series MMM with Turing/NUTS MCMC,
- bounded panel MMM over one or more declared panel dimensions,
- grouped inference results and deterministic post-model replay,
- contribution, decomposition, response, saturation, adstock, and metric
  summaries,
- time-series blocked holdout validation,
- historical-share budget optimisation for supported result surfaces,
- config-driven pipeline runs,
- CairoMakie-backed plots when `CairoMakie` is loaded.

See [Support Boundaries](release.md) for explicit unsupported and deferred
areas.

## Plotting

The config runner loads plotting support by default. Direct plotting APIs are
available after:

```julia
using Epsilon, CairoMakie
```

Without the plotting backend, core fitting and non-plot pipeline artifacts
remain available.

## Calibration

Calibration support is intentionally bounded. The currently supported slice is
time-series MCMC calibration through centered-logistic lift-test terms and
cost-per-target soft penalties. See [Calibration](calibration.md).

## Methodology

The statistical model is documented in [Model Form](methodology/model.md).
The adstock, saturation, contribution, and response-curve mechanics are
documented in [Media Transforms](methodology/media_transforms.md).

## API Reference

The complete exported-symbol inventory and docstring reference live in
[Public API](api.md).
