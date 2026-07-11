# Toy MMM MCMC Smoke Demo

This directory contains a tiny synthetic `TimeSeriesMMM` example for checking
the supported Epsilon MCMC path without running the heavier demo pipeline.

```bash
julia --project=. examples/toy_mmm/run_toy_mmm.jl --draws 8 --tune 8 --output-dir "$(mktemp -d)"
```

The script fits one Turing/NUTS chain with `chains = 1`, `cores = 1`,
`progressbar = false`, an explicit seed, and convergence checks disabled. It
then builds grouped inference results, contribution summaries, and one `tv`
metric summary on the deterministic spend grid `[0.0, observed_total / 2,
observed_total]`.

Successful runs print `status=fit`, `backend=turing`, the sampler settings,
and compact row counts. When `--output-dir` is supplied, the script writes
`contribution_summary.csv`, `metric_summary.csv`, and `run_summary.txt` there.
`--help` prints usage without fitting a model, and malformed CLI values fail
with `ArgumentError` messages that name the rejected option.

This is a fast supported MCMC smoke demo only. It is not release evidence, not
a benchmark, not an Abacus parity claim, and not a broader support expansion.
