# Changelog

All notable public changes to Epsilon are recorded here.

## 0.1.0-beta.1 - 2026-07-20

First public beta release of `Epsilon.jl`.

### Included

- Julia-native Bayesian MMM modelling with Turing/NUTS MCMC.
- Config-driven local runner via `runme.jl`.
- Maintained demo bundles under `data/demo/` for `timeseries`, `geo_panel`,
  and `geo_brand_panel` workflows.
- Structured pipeline output stages under user-selected result directories.
- Stage-local JSON/CSV artifacts, trusted-local `.jls` artifacts, and static
  CairoMakie plot outputs where plotting support is available.
- Time-series fitting, posterior assessment, contribution decomposition,
  diagnostics, response curves, calibration terms, and fixed-budget
  optimisation on supported paths.
- Bounded panel and geo-brand-panel workflows with declared panel dimensions and
  deterministic panel-cell metadata.
- Scenario planning helpers for current, manual-allocation, and solved
  optimisation scenarios.
- Local maintenance commands for formatting, smoke checks, tests, and docs.

### Not Included

- Variational inference.
- Dashboard or hosted UI.
- AI advisor features.
- Panel calibration.
- Panel holdout validation.
- Free channel-by-panel optimisation.
- Portable binary interchange for `.jls` artifacts.
