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

This is a fixed-schema teaching example, not a general CSV ingestion API,
pipeline feature, data-cleaning workflow, benchmark, release claim, or Abacus
parity evidence. `--help` shows the available options without fitting a model.
