# Demo Data And Runner

This directory provides a bounded, release-honest demo surface for Epsilon.

## What Is Included

- `reference/abacus/`
  - canonical reference demo datasets copied into the Epsilon repo
  - one de-duplicated `holidays.csv` file shared by all copied reference configs
  - raw reference `config.yml` files for:
    - `timeseries`
    - `geo_panel`
    - `geo_brand_panel`
- `epsilon/timeseries/config.yml`
  - an Epsilon-native runnable config over the same reference time-series demo
    dataset
  - kept intentionally lighter than the full reference pipeline example:
    validation and optimization are off by default so the first runnable Epsilon
    demo stays fast and truthful to the shipped support matrix
- `run_demo.jl`
  - a thin orchestrator over Epsilon's shipped pipeline entry point

## Supported Demo Rows

- `timeseries`
  - runnable through `run_demo.jl`
  - uses the bounded Epsilon v1 time-series MCMC pipeline contract
- `geo_panel`
  - reference-only dataset and raw reference config
  - useful for cross-framework comparisons
  - not runnable through the Epsilon pipeline because the shipped pipeline is
    time-series-first
- `geo_brand_panel`
  - reference-only dataset and raw reference config
  - useful for cross-framework comparisons
  - not runnable through the Epsilon pipeline because the shipped pipeline is
    time-series-first and the bounded panel path supports one panel dimension

## Holiday File

The raw reference holiday CSV is included so comparisons with other MMM
frameworks can use the same reference inputs.

The shipped runnable Epsilon time-series demo uses this same copied holiday CSV
as a reference input through the native `holidays.mode = "auto"` path, which
builds one pooled automatic holiday component. This is the coherent Epsilon
native holiday design, not a claim of end-to-end reference parity on the
holiday-bearing row. The pipeline remains time-series-only, and broader holiday
feature expansion is still out of scope.

## Runner Commands

List available demo bundles:

```bash
julia --project=. examples/demo/run_demo.jl list
```

Show the canonical paths for one bundle:

```bash
julia --project=. examples/demo/run_demo.jl paths timeseries
```

Run the Epsilon time-series demo:

```bash
julia --project=. examples/demo/run_demo.jl run timeseries
```

The runner forwards the bounded pipeline CLI overrides, so quick local runs can
use smaller sampler settings:

```bash
julia --project=. examples/demo/run_demo.jl run timeseries \
  --draws 120 --tune 120 --chains 2 --cores 2 \
  --prior-samples 10 --curve-points 32
```

By default the runner writes results under `examples/demo/results/`.
Successful runs include stage-local `png` plots directly inside the
corresponding Stage `10`-`70` subdirectories, with `write_plot_bundle(run)`
remaining available as a separate curated export if needed.
