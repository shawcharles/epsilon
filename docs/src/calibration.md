# Calibration

Calibration support is intentionally bounded. Epsilon currently supports
calibration likelihood terms for `TimeSeriesMMM` fitted with MCMC through
`fit!`.

## Supported Surface

The supported calibration path is:

- `TimeSeriesMMM` with the Turing/NUTS MCMC backend.
- Programmatic construction and bounded public dict/YAML configuration,
  including the time-series MCMC pipeline fit path.
- Lift-test calibration for the `"logistic"` model path, which maps to
  [`centered_logistic_saturation`](@ref).
- Cost-per-target soft penalties.
- Optional, additive calibration terms: enabling both lift-test and
  cost-per-target calibration adds both scalar contributions to the model
  log-joint independently.

Lift-test calibration is computed in scaled model space as
`abs(saturation(x + delta_x) - saturation(x))`. It deliberately uses
saturation only. Adstock is not inserted into the lift-test calibration term.

Cost-per-target calibration uses caller-supplied gathered, target, and `sigma`
values, scaled with the model target scale, and adds a soft penalty to the
model log-joint. It does not infer calibration values from posterior
predictive, optimization, or pipeline artifacts.

## YAML Configuration

The public YAML/config surface accepts a top-level `calibration` block for
time-series MCMC models. The block is parsed into the same
`TimeSeriesCalibrationInput` object used by programmatic `TimeSeriesMMM`
construction, and the bounded pipeline path passes that payload through to the
fit stage.

```yaml
data:
  date_column: date
  # Required when the same YAML is used with run_pipeline.
  dataset_path: data.csv
target:
  column: sales
media:
  channels: [tv, search]
  saturation:
    type: logistic
fit:
  backend: mcmc
calibration:
  steps:
    - method: add_lift_test_measurements
    - method: add_cost_per_target_calibration
  lift_test:
    channel: [tv, search]
    x: [100.0, 80.0]
    delta_x: [10.0, 8.0]
    delta_y: [12.0, 7.5]
    sigma: [1.5, 1.2]
  cost_per_target:
    gathered_cpt: [4.2, 3.8]
    targets: [120.0, 95.0]
    sigma: [0.4, 0.35]
```

Only the listed step methods are supported. Step `params.dist` and custom row
fields are rejected rather than ignored.

## Unsupported Paths

The following remain outside the current supported surface:

- `PanelMMM` calibration.
- Variational inference, which is permanently retired from Epsilon.
- YAML `fit.backend` values outside the MCMC/Turing aliases when calibration is
  present.
- Saturation families other than the centered-logistic `"logistic"` path for
  lift-test calibration.
- Automatic generation of calibration rows from lift-test artifacts,
  posterior-predictive outputs, optimization outputs, or pipeline artifacts.
- Dashboard/UI workflows and AI-advisor behaviour.

Unsupported calibration paths fail closed with explicit errors rather than
silently dropping calibration.

## Validation Status

The supported calibration path is the bounded `TimeSeriesMMM` MCMC slice,
including combined lift-test plus cost-per-target model integration. This does
not imply support for panel models, variational inference, broader saturation
families, hosted/UI workflows, or AI-advisor behaviour.

Calibration docstrings are included in the [Public API](api.md) reference.
