```text
███████╗██████╗ ███████╗██╗██╗      ██████╗ ███╗   ██╗
██╔════╝██╔══██╗██╔════╝██║██║     ██╔═══██╗████╗  ██║
█████╗  ██████╔╝███████╗██║██║     ██║   ██║██╔██╗ ██║
██╔══╝  ██╔═══╝ ╚════██║██║██║     ██║   ██║██║╚██╗██║
███████╗██║     ███████║██║███████╗╚██████╔╝██║ ╚████║
╚══════╝╚═╝     ╚══════╝╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═══╝
```

# Epsilon.jl

`Epsilon.jl` is a Julia-native Bayesian marketing mix modelling library. It
focuses on a practical MMM workflow: define a model in YAML, provide a dataset
and holiday file, run MCMC inference, then inspect structured results, plots,
decomposition, response curves, diagnostics, validation, and optional budget
optimisation artifacts.

Epsilon is pre-release software. The supported surface is intentionally
bounded, but the maintained paths are usable for demo-scale MMM runs.

## What It Supports

- Time-series MMM with Turing/NUTS MCMC.
- Panel MMM over one or more panel dimensions, represented internally on a
  deterministic flattened panel-cell axis.
- Config-driven runs using a `{config.yml, dataset.csv, holidays.csv}` bundle.
- Stage-based result folders with manifests, model fit artifacts, diagnostics,
  decomposition, response curves, plots, and skipped-stage markers.
- Blocked holdout validation for time-series models.
- Historical-share budget optimisation for supported time-series and panel
  result surfaces.
- Julia-native plotting through CairoMakie-backed stage artifacts and direct
  plot functions.

> [!NOTE]
> Variational inference is not supported and is not planned for this library.
> Dashboard/UI workflows, AI advisor workflows, panel holdout validation, panel
> calibration, and free channel-by-panel optimisation are outside the current
> scope.

## Requirements

- Julia `1.10` or newer.
- A local checkout of this repository.
- The project environment instantiated with Julia's package manager.

```bash
git clone https://github.com/shawcharles/epsilon.git
cd epsilon
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

## Quick Start

Run the default bundled time-series demo with small local settings:

```bash
julia --project=. runme.jl
```

Or run the same demo explicitly:

```bash
julia --project=. runme.jl data/demo/timeseries/config.yml --quick
```

The runner prints a terminal header, the resolved run context, stage progress
bars, plotting status, and a final summary. Outputs are written under
`results/<run_name>_<timestamp>/`.

For a fast maintained smoke check over the bundled demo configs:

```bash
make smoke
```

The explicit target is equivalent:

```bash
make smoke-demo-configs
```

## Config-Driven Workflow

Each runnable demo bundle is self-contained:

```text
data/demo/timeseries/
  config.yml
  dataset.csv
  holidays.csv

data/demo/geo_panel/
  config.yml
  dataset.csv
  holidays.csv

data/demo/geo_brand_panel/
  config.yml
  dataset.csv
  holidays.csv
```

The normal workflow is:

1. Copy one of the demo bundles.
2. Edit `config.yml` for your columns, priors, sampler settings, validation,
   and optional optimisation block.
3. Replace `dataset.csv` and `holidays.csv` with your data.
4. Run:

```bash
julia --project=. runme.jl path/to/config.yml
```

Disable plotting when running headless:

```bash
julia --project=. runme.jl path/to/config.yml --no-plots
```

Optional stages can be turned off in YAML. For example:

```yaml
optimization:
  enabled: false
```

Skipped stages still create a stage directory and write `SKIPPED.json`, with
the marker also registered in `run_manifest.json`.

## Programmatic Use

The public pipeline entry point is `run_pipeline`:

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

Lower-level model construction, fitting, post-model analysis, and plotting APIs
are available for Julia users who want to work directly with typed model
objects. See `docs/src/api.md` and the demo bundles under `data/demo/`.

## Result Layout

A completed pipeline run writes a structured directory similar to:

```text
results/config_YYYYMMDD_HHMMSS/
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

The manifest records stage status, artifact paths, warnings, and failures.
Julia `.jls` files are trusted-local serialisation artifacts, not portable
interchange files.

## Plotting

The config runner loads plotting support by default and writes stage-local PNG
artifacts when CairoMakie is available. Direct plotting APIs are also available
after loading:

```julia
using Epsilon, CairoMakie
```

Core non-plot artifacts remain available without plotting.

## Demo Bundles

`data/demo/` contains the canonical config-driven demo bundles. Each bundle has
its own `README.md`, `config.yml`, `dataset.csv`, and `holidays.csv`.

Useful commands from the repository root:

```bash
julia --project=. runme.jl data/demo/timeseries/config.yml --quick
julia --project=. runme.jl
```

## Local Checks

Use focused checks during development:

```bash
make format-check
make smoke
make smoke-demo-configs
```

Run the full test suite only when you need a complete local gate:

```bash
make test
```

## Current Boundaries

Epsilon is designed as a compact statistical library, not a dashboard product.
The current priority is a clear, reproducible MMM modelling path in Julia:
configuration, MCMC fitting, structured artifacts, diagnostics, decomposition,
curves, validation where supported, and optimisation where the contract is
well-defined.

Unsupported or deferred areas are rejected or marked explicitly rather than
silently approximated.

## Authorship And Licence

Epsilon is authored by Charles Shaw <charles@charlesshaw.net>.

Copyright 2026 Charles Shaw. Licensed under the Apache License, Version 2.0;
see `LICENSE` and `NOTICE`.
