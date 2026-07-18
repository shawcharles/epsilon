# CSV Time-Series MCMC Quickstart

This example loads the bundled `toy_timeseries.csv` into `MMMData` and fits a
small `TimeSeriesMMM` through Epsilon's supported Turing/NUTS MCMC path.

```bash
julia --project=. examples/csv_mmm/run_csv_mmm.jl --draws 8 --tune 8 --output-dir "$(mktemp -d)"
```

The CSV schema is exact and case-sensitive:

```text
date,sales,tv,search
2026-01-05,82,12,4
```

`date` must be an ISO date in `yyyy-mm-dd` format. `sales`, `tv`, and `search`
must be present finite numeric values; `tv` and `search` must also be
nonnegative. The loader rejects missing or unexpected columns, missing or
malformed dates, missing, malformed, non-finite, or negative media values, and
duplicate parsed dates. Rows are sorted by parsed date before the script
constructs `MMMData`.

Use `--data PATH` to load another file with this same four-column schema. It
defaults to the bundled CSV. A successful run prints `status=fit` and
`backend=turing`; with `--output-dir`, it writes `contribution_summary.csv`,
`metric_summary.csv`, and `run_summary.txt`.
The text summary uses stable `key=value` lines for status, backend, data path,
sampler settings, the evaluated channel, observed `tv` spend total, and output
row counts. The CSV sidecars use the same compact summary-table columns returned
by Epsilon: contribution rows contain `observation,date,component,mean,lower_5,
upper_95`, and metric rows contain `channel,spend,metric,mean,lower_5,upper_95`.

This is a fixed-schema teaching example, not a general CSV ingestion API,
pipeline feature, data-cleaning workflow, benchmark, release claim, or Abacus
parity evidence. `--help` shows the available options without fitting a model.

For the canonical supported local workflow, including compact-output
inspection, trusted-local fitted-model and grouped-results roundtrips, and
`make smoke`, see
[`docs/src/supported_paths.md`](../../docs/src/supported_paths.md).
