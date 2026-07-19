# Supported Local Workflows

This page is the canonical runbook for Epsilon's currently supported local
MCMC example and demo-config paths. It covers the synthetic toy example, the
fixed-schema CSV quickstart, compact output inspection, trusted-local artifact
roundtrips, the local supported-path smoke command, and the local demo-config
smoke command.

These workflows are maintenance and teaching evidence for the supported
Turing/NUTS MCMC path. They are not benchmarks, release evidence, dashboard
workflows, or a broader ingestion API.

## Toy MCMC Example

Run the synthetic toy model from the repository root:

```bash
julia --project=. examples/toy_mmm/run_toy_mmm.jl --draws 8 --tune 8 --output-dir "$(mktemp -d)"
```

The script fits one tiny `TimeSeriesMMM` through the supported Turing/NUTS MCMC
path with one chain, one core, a deterministic default seed, `progressbar =
false`, and convergence checks disabled for the smoke workload. Successful runs
print `status=fit`, `backend=turing`, sampler settings, and compact row counts.

When `--output-dir` is supplied, the toy example writes:

- `contribution_summary.csv`
- `metric_summary.csv`
- `run_summary.txt`

The contribution CSV uses:

```text
observation,date,component,mean,lower_5,upper_95
```

The metric CSV uses:

```text
channel,spend,metric,mean,lower_5,upper_95
```

The summary text uses stable `key=value` lines for status, backend, sampler
settings, the evaluated channel, observed `tv` spend total, and output row
counts. The sampled numeric values are intentionally not a stable contract for
tiny chains.

## CSV Quickstart

Run the bundled fixed-schema CSV quickstart from the repository root:

```bash
julia --project=. examples/csv_mmm/run_csv_mmm.jl --draws 8 --tune 8 --output-dir "$(mktemp -d)"
```

The required CSV schema is exact and case-sensitive:

```text
date,sales,tv,search
2026-01-05,82,12,4
```

`date` must parse as an ISO `yyyy-mm-dd` date. `sales`, `tv`, and `search` must
be present finite numeric values, and media columns must be nonnegative. Rows
are sorted by parsed date before model construction.

Use `--data PATH` only for another file with the same four-column schema:

```bash
julia --project=. examples/csv_mmm/run_csv_mmm.jl --data path/to/file.csv --draws 8 --tune 8 --output-dir "$(mktemp -d)"
```

With `--output-dir`, the CSV quickstart writes the same compact sidecars as the
toy example: `contribution_summary.csv`, `metric_summary.csv`, and
`run_summary.txt`.

This quickstart is not a general CSV ingestion API or data-cleaning workflow.

## Trusted-Local Artifact Roundtrips

The CLI examples write compact CSV/text sidecars only. To save and reload the
returned fitted model or grouped inference results, call the example function
from Julia and use the existing Epsilon persistence APIs.

Toy example:

```julia
using Epsilon

include("examples/toy_mmm/run_toy_mmm.jl")
result = run_toy_mmm(; draws = 8, tune = 8, output_dir = nothing, verbose = false)

mktempdir() do dir
    model_path = joinpath(dir, "model.jls")
    grouped_path = joinpath(dir, "grouped_inference_results.jls")

    save_model(model_path, result.model)
    save_inference_results(grouped_path, result.grouped)

    loaded_model = load_model(model_path)
    loaded_grouped = load_inference_results(grouped_path)

    @assert loaded_model.fit_state.status == :fit
    @assert loaded_model.fit_state.backend == :turing
    @assert size(loaded_grouped.posterior, 1) == 8
end
```

CSV quickstart:

```julia
using Epsilon

include("examples/csv_mmm/run_csv_mmm.jl")
result = run_csv_mmm(; draws = 8, tune = 8, output_dir = nothing, verbose = false)

mktempdir() do dir
    model_path = joinpath(dir, "model.jls")
    grouped_path = joinpath(dir, "grouped_inference_results.jls")

    save_model(model_path, result.model)
    save_inference_results(grouped_path, result.grouped)

    loaded_model = load_model(model_path)
    loaded_grouped = load_inference_results(grouped_path)

    @assert loaded_model.fit_state.status == :fit
    @assert loaded_model.fit_state.backend == :turing
    @assert size(loaded_grouped.posterior, 1) == 8
end
```

The `.jls` files are trusted-local Julia serialization artifacts. Treat them as
bound to the local Julia, Epsilon, and dependency versions that wrote them. They
are not portable interchange files and must not be loaded from untrusted input.

## Config-Driven Demo Runner

The repo-root runner is the shortest path for running an Epsilon-native
config/data/holidays bundle:

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

The runner is intentionally more visual than the programmatic API: it prints
the Epsilon header, a config/output context block, one-line stage progress
bars, plotting status, and a structured final success or failure summary. The
runner loads CairoMakie by default and writes stage-local PNG plot artifacts
when active; pass `--no-plots` to suppress plot artifact generation. The
progress display counts all manifest stage records, including skipped optional
stages in the final status summary.

Skipped stages write a small `SKIPPED.json` marker in their stage directory and
register it as `skipped_marker` in `run_manifest.json`. For example,
`optimization.enabled: false` leaves `70_optimisation/` present but records why
no optimisation artifacts were produced.

The bundled config owns its local `dataset.csv` and `holidays.csv` paths. The
runner delegates to `pipeline_main`, so normal pipeline flags such as
`--output-dir`, `--run-name`, `--dataset-path`, `--draws`, `--tune`,
`--chains`, `--cores`, `--prior-samples`, `--curve-points`, and
`--random-seed` use the same validation as `run_pipeline(PipelineRunConfig(...))`.

For programmatic use, call `run_pipeline(PipelineRunConfig(...))` directly. The
runner is only a convenience control plane.

## Local Smoke Commands

For a fast local confidence check of both supported example paths:

```bash
make smoke
```

The smoke command runs the toy and CSV examples with small MCMC settings,
writes outputs into temporary directories, checks nonempty compact sidecars,
and verifies `status=fit` plus `backend=turing`. It removes its temporary
outputs when it exits.

`make smoke` is useful before or after small supported-path changes. It is not
a benchmark, not release evidence, and not a replacement for focused tests when
code behaviour changes.

For a local check of the canonical Epsilon-native config-driven demo bundles
under `data/demo/`:

```bash
make smoke-demo-configs
```

That command runs `data/demo/timeseries/config.yml` through a tiny headless
pipeline with runtime sampler overrides. It preserves the config's default
validation stage, so the smoke run performs the main fit and the validation
holdout fit with deliberately small chains. It checks required non-plot Stage
`00`, `10`, `20`, `30`, `35`, `40`, `50`, and `60` artifacts and verifies that
headless plot omissions are explicit rather than recorded as missing PNG
paths.

The same command checks `data/demo/geo_panel/config.yml` and
`data/demo/geo_brand_panel/config.yml` through config loading, CSV loading,
`PanelMMM` construction, model-spec construction, and coordinate-metadata
checks. It does not run panel MCMC sampling.

`make smoke-demo-configs` writes only to temporary directories by default. Set
`KEEP_SMOKE_OUTPUTS=1` when inspecting the generated run directory manually.
This command is local workflow evidence only; it is not a benchmark, release
gate, dashboard workflow, or substitute for focused tests.
