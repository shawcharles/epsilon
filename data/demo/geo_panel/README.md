# Geo Panel Demo

This bundle demonstrates Epsilon's bounded panel config shape with one panel
axis: `geo`.

Files:

- `config.yml`: `PanelMMM` configuration with `dimensions.panel = ["geo"]`.
- `dataset.csv`: demo panel data with date, geo, revenue, and media channels.
- `holidays.csv`: bundle-local holiday calendar used by the config.

The maintained smoke harness checks this bundle through config loading, CSV
loading, `PanelMMM` construction, model-spec construction, and coordinate
metadata checks:

```bash
make smoke
```

The smoke harness does not run panel MCMC sampling. Panel holdout validation,
panel calibration, and free channel-by-panel optimisation are outside the
current supported surface.
