# Supported Local Workflows

This page is the canonical runbook for Epsilon's currently supported local
MCMC example paths. It covers the synthetic toy example, the fixed-schema CSV
quickstart, compact output inspection, trusted-local artifact roundtrips, and
the local smoke command.

These workflows are maintenance and teaching evidence for the supported
Turing/NUTS MCMC path. They are not benchmarks, release evidence, Abacus parity
claims, dashboard workflows, or a broader ingestion API.

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

## Local Smoke Command

For a fast local confidence check of both supported example paths:

```bash
make smoke
```

The smoke command runs the toy and CSV examples with small MCMC settings,
writes outputs into temporary directories, checks nonempty compact sidecars,
and verifies `status=fit` plus `backend=turing`. It removes its temporary
outputs when it exits.

`make smoke` is useful before or after small supported-path changes. It is not
a benchmark, not release evidence, not an Abacus parity gate, and not a
replacement for focused tests when code behavior changes.
