# Epsilon Demo Data

This directory contains Epsilon-native config-driven demo bundles:

- `demo/timeseries/`
- `demo/geo_panel/`
- `demo/geo_brand_panel/`

Each bundle is self-contained:

```text
config.yml
dataset.csv
holidays.csv
```

Run a bundle through the Epsilon pipeline from the repository root:

```bash
julia --project=. -e 'using Epsilon; run_pipeline(PipelineRunConfig(config_path = "data/demo/timeseries/config.yml", output_dir = "results"))'
```

For quick local checks, override sampler size at runtime instead of editing the
config:

```bash
julia --project=. -e 'using Epsilon; run_pipeline(PipelineRunConfig(config_path = "data/demo/timeseries/config.yml", output_dir = "results", draws = 20, tune = 20, chains = 1, cores = 1, prior_samples = 5, curve_points = 12))'
```

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
