# Demo Bundles

This directory contains Epsilon's canonical config-driven demo bundles.

Each bundle is self-contained:

```text
config.yml
dataset.csv
holidays.csv
```

Available bundles:

- `timeseries/`: runnable end-to-end through `runme.jl`.
- `geo_panel/`: bounded `PanelMMM` config/data example with one panel axis.
- `geo_brand_panel/`: bounded `PanelMMM` config/data example with two panel
  axes.

Run the default time-series demo from the repository root:

```bash
julia --project=. runme.jl
```

Run it explicitly:

```bash
julia --project=. runme.jl data/demo/timeseries/config.yml --quick
```

Check all demo configs locally:

```bash
make smoke
```

The smoke command runs the time-series bundle through a tiny pipeline and
checks the panel bundles through config/data/model-spec construction without
panel MCMC sampling.
