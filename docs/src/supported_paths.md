# Supported Local Workflows

This page is the canonical runbook for Epsilon's maintained local demo
workflow. The public path is config driven:

```text
config.yml
dataset.csv
holidays.csv
```

The bundled demo configs live under `data/demo/` and are the only maintained
example surface.

## Demo Bundles

Available bundles:

- `data/demo/timeseries/`
- `data/demo/geo_panel/`
- `data/demo/geo_brand_panel/`

Each bundle contains:

```text
README.md
config.yml
dataset.csv
holidays.csv
```

The time-series bundle is runnable end to end through the repo-local runner.
The panel bundles are maintained config/data examples for the bounded
`PanelMMM` surface and are checked by the local smoke harness without running
panel MCMC.

## Config-Driven Runner

Run the canonical time-series demo from the repository root:

```bash
julia --project=. runme.jl data/demo/timeseries/config.yml
```

For a small local run without editing the YAML, add `--quick`:

```bash
julia --project=. runme.jl data/demo/timeseries/config.yml --quick
```

With no arguments, the runner uses `data/demo/timeseries/config.yml` and quick
local settings:

```bash
julia --project=. runme.jl
```

The runner prints the Epsilon header, a config/output context block, one-line
stage progress bars, plotting status, and a structured final success or failure
summary. It loads CairoMakie by default and writes stage-local PNG plot
artifacts when active; pass `--no-plots` to suppress plot artifact generation.

Skipped stages write a small `SKIPPED.json` marker in their stage directory and
register it as `skipped_marker` in `run_manifest.json`. For example,
`optimization.enabled: false` leaves `70_optimisation/` present but records why
no optimisation artifacts were produced.

For programmatic use, call `run_pipeline(PipelineRunConfig(...))` directly. The
runner is only a convenience control plane over the same pipeline path.

## Trusted-Local Artifacts

Pipeline runs write structured stage directories under `results/` or the
configured output root. Julia `.jls` files are trusted-local serialization
artifacts. Treat them as bound to the Julia, Epsilon, and dependency versions
that wrote them. They are not portable interchange files and must not be loaded
from untrusted input.

## Local Smoke Command

For a fast local confidence check of the maintained demo surface:

```bash
make smoke
```

`make smoke` is an alias for the demo-config smoke harness:

```bash
make smoke-demo-configs
```

The harness runs `data/demo/timeseries/config.yml` through a tiny headless
pipeline with runtime sampler overrides. It preserves the config's default
validation stage, so the smoke run performs the main fit and the validation
holdout fit with deliberately small chains. It checks required non-plot Stage
`00`, `10`, `20`, `30`, `35`, `40`, `50`, and `60` artifacts and verifies that
headless plot omissions are explicit rather than recorded as missing PNG paths.

The same command checks `data/demo/geo_panel/config.yml` and
`data/demo/geo_brand_panel/config.yml` through config loading, CSV loading,
`PanelMMM` construction, model-spec construction, and coordinate-metadata
checks. It does not run panel MCMC sampling.

`make smoke-demo-configs` writes only to temporary directories by default. Set
`KEEP_SMOKE_OUTPUTS=1` when inspecting the generated run directory manually.
This command is local workflow evidence only; it is not a benchmark, release
gate, dashboard workflow, or substitute for focused tests.
