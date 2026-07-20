# Support Boundaries

This page defines the current public support boundaries for Epsilon. The
`0.1.0-beta.1` support surface is intentionally narrower than the full public
export list.

## Supported

| Area | Current Support |
|---|---|
| Fitting | Turing/NUTS MCMC for supported `TimeSeriesMMM` and bounded `PanelMMM` models |
| Data | Config-driven CSV workflows with explicit date, target, media, holiday, control, and panel columns |
| Pipeline | Stage-based local runs through `run_pipeline`, `pipeline_main`, and `runme.jl` |
| Time-series validation | Blocked holdout validation through Stage `35` |
| Panel modelling | One or more declared panel dimensions on a deterministic flattened panel-cell axis |
| Post-model analysis | Contributions, decomposition, response curves, saturation curves, adstock curves, and marketing metrics from grouped MCMC results |
| Optimisation | Fixed-budget total-response optimisation; panel optimisation uses historical within-channel panel shares |
| Plotting | Static CairoMakie-backed plots and stage-local PNG artifacts |
| Scenario planning | Non-UI comparison tables over current, manual time-series, and solved optimisation scenarios |
| Calibration | Time-series MCMC lift-test and cost-per-target calibration on the bounded centered-logistic path |

## Explicitly Unsupported Or Deferred

- Variational inference. Epsilon supports MCMC/Turing fitting only.
- Dashboard, hosted UI, AI advisor, or background scenario-store workflows.
- Panel holdout validation.
- Panel calibration.
- Free channel-by-panel optimisation.
- Panel seasonality, trend, events, and richer controls beyond the currently
  supported panel surface.
- Automatic refitting of every prior-sensitivity scenario.
- Arbitrary future spend-path simulation.
- No portable binary interchange for Julia `.jls` artifacts.
- Loading serialized artifacts from untrusted sources.

Unsupported paths should fail explicitly rather than silently approximating a
different model.

## Pipeline Stages

Pipeline runs use fixed stage directories:

| Stage | Directory | Notes |
|---|---|---|
| `00` | `00_run_metadata/` | Source config, resolved config, data and model metadata |
| `05` | `05_prior_sensitivity/` | Optional scenario planning, not automatic refitting |
| `10` | `10_pre_diagnostics/` | Prior predictive artifacts where supported |
| `20` | `20_model_fit/` | Fitted model and grouped inference artifacts |
| `30` | `30_model_assessment/` | Observed/fitted, posterior predictive, residual summaries, plots |
| `35` | `35_holdout_validation/` | Time-series holdout validation only |
| `40` | `40_decomposition/` | Contributions and decomposition artifacts |
| `50` | `50_diagnostics/` | Sampler, convergence, predictive, residual, and design diagnostics |
| `60` | `60_response_curves/` | Response, saturation, adstock, and metric artifacts |
| `70` | `70_optimisation/` | Optional budget optimisation |

When a stage is skipped, Epsilon writes `SKIPPED.json` in that stage directory
and records the marker in `run_manifest.json`.

## Config Guidelines

- Use `fit.backend: mcmc` or omit the backend for the maintained MCMC path.
- Keep media spend nonnegative.
- Use explicit panel dimensions under `dimensions.panel` for panel configs.
- Keep demo optimisation disabled unless a deliberate budget block is supplied.
- Prefer `runme.jl ... --quick` for local demo checks and increase sampler
  settings only when inspecting modelling behaviour.

## Local Checks

Use focused checks for routine development:

```bash
make format-check
make smoke
make smoke-demo-configs
```

Use the full suite only when a broad local gate is needed:

```bash
make test
```

Build the documentation after public documentation changes:

```bash
make docs
```
