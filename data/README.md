# Epsilon Demo Data

This directory contains the canonical Epsilon-native config-driven demo
bundles:

- `demo/timeseries/`
- `demo/geo_panel/`
- `demo/geo_brand_panel/`

Each bundle is self-contained:

```text
config.yml
dataset.csv
holidays.csv
```

Run the canonical time-series bundle through the Epsilon runner from the
repository root:

```bash
julia --project=. runme.jl data/demo/timeseries/config.yml
```

For quick local checks, use the runner's small local overrides instead of
editing the config:

```bash
julia --project=. runme.jl data/demo/timeseries/config.yml --quick
```

The no-argument form is a shorthand for the same bundled time-series demo with
quick local settings:

```bash
julia --project=. runme.jl
```

The runner prints the Epsilon header, the resolved run context, stage progress
bars, and a structured final summary. It is intended as the minimum-code
terminal workflow for the `{config, dataset, holidays}` triplet.

For programmatic use, call `run_pipeline(PipelineRunConfig(...))` directly.
The runner delegates to that same pipeline path.

To check all bundled demo configs through the maintained local smoke harness,
run:

```bash
make smoke-demo-configs
```

That command runs the time-series demo through a tiny full pipeline, including
the default validation stage, and checks the panel demo configs through
config/data/model-spec construction without MCMC sampling. It writes outputs to
temporary directories and removes them when it exits. It is local smoke
evidence only, not a benchmark, release gate, or parity claim.

The panel bundles use the bounded `PanelMMM` surface:

- `geo_panel` maps to `dimensions.panel = ["geo"]`.
- `geo_brand_panel` maps to `dimensions.panel = ["geo", "brand"]` and uses a
  deterministic flattened panel-cell axis internally.

Current boundaries:

- Variational inference is unsupported.
- Dashboard/UI and AI advisor workflows are unsupported.
- Panel holdout validation is deferred.
- Panel calibration is unsupported.
- Free channel-by-panel optimisation is unsupported.
- Demo optimisation is disabled by default; add an Epsilon-native
  `optimization.total_budget` block explicitly when needed.

`data/holidays.csv` is retained as a shared reference copy. The runnable demo
configs use their bundle-local `holidays.csv` files.
