# Changelog

All notable project changes are recorded here. Epsilon is still on the
`0.1.0-dev` line, so entries are grouped under `Unreleased` until the first
tagged package release.

## Unreleased

### Added

- Added the repo-root `runme.jl` runner for config-driven local MMM workflows.
  It loads a `{config.yml, dataset.csv, holidays.csv}` bundle, prints a
  structured terminal summary, shows stage progress, and writes results under
  `results/`.
- Added Epsilon-native demo bundles under `data/demo/` for `timeseries`,
  `geo_panel`, and `geo_brand_panel` examples.
- Added CairoMakie-backed static plot artifacts for pipeline runs when plotting
  support is available, plus a `--no-plots` runner flag for headless execution.
- Added skipped-stage marker artifacts: skipped optional stages now write
  `SKIPPED.json` and record the marker in `run_manifest.json`.
- Added local smoke commands for the maintained toy, CSV, and config-driven
  demo workflows.
- Added bounded time-series calibration support for centered-logistic lift-test
  terms and cost-per-target soft penalties on the MCMC path.
- Added bounded scenario-planning helpers for current, manual-allocation, and
  solved optimisation scenarios, including local scenario-store artifacts.

### Changed

- Rewrote the public README and documentation to describe Epsilon as a
  standalone Julia MMM library with its own supported workflow and boundaries.
- Deduplicated pipeline artifact generation so compatibility manifest keys can
  point to canonical physical files instead of writing byte-identical outputs.
- Reconciled the public demo surface around `data/demo/` and `runme.jl`.
- Clarified support boundaries for MCMC fitting, panel workflows, calibration,
  plotting, optimisation, trusted-local `.jls` artifacts, and unsupported UI or
  hosted workflows.
- Moved plotting implementation behind the lazy CairoMakie package extension
  while keeping runner plot generation available by default.
- Hardened model/config validation around nonnegative media, unsupported
  top-level YAML keys, trusted-local artifact metadata, and invalid calibration
  payloads.
- Migrated the bounded budget optimiser to current JuMP nonlinear operator
  construction without changing result schemas.

### Fixed

- Fixed Stage `30` assessment plot generation so `observed_fitted.png`,
  `fit_timeseries.png`, and `posterior_predictive.png` are distinct diagnostic
  plots instead of three copies of the same observed/fitted figure.
- Fixed skipped optional stages so empty stage directories now explain
  themselves through marker artifacts.
- Fixed duplicate pipeline outputs in validation, decomposition, diagnostics,
  and response-curve stages.
- Fixed fitted time-series replay state for trend and automatic-holiday
  features so prediction and replay reuse fitted state rather than drifting to
  a fresh date basis.

### Removed

- Removed the pre-release variational-inference API and runtime path. Epsilon
  supports MCMC/Turing fitting only.
- Removed the obsolete legacy demo helper tree and tracked generated demo
  outputs. The maintained config-driven examples now live under `data/demo/`.
