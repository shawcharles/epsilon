# Calibration

Calibration support is intentionally bounded. Epsilon currently supports
calibration likelihood terms for `TimeSeriesMMM` fitted with MCMC through
`fit!`; the implementation is fixture-backed against comparable Abacus
preprocessing and log-density semantics.

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
values, scaled with the model target scale, and adds the Abacus-style soft
penalty. It does not infer calibration values from posterior predictive,
optimization, or pipeline artifacts.

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
- Dash/UI workflows and AI-advisor behaviour.

Unsupported calibration paths fail closed with explicit errors rather than
silently dropping calibration.

## Parity Status

The calibration/lift-test ledger row remains `scaffolded`, not `ported`.
Epsilon has fixture-backed evidence for the bounded `TimeSeriesMMM` MCMC slice,
including combined lift-test plus cost-per-target model integration. That does
not imply broad Abacus calibration parity across panel models, VI, broader
saturation families, hosted/UI workflows, or AI-advisor behaviour.

```@docs
Epsilon.CalibrationStepConfig
Epsilon.validate_calibration_step_config
Epsilon.LiftTestCalibrationRows
Epsilon.CostPerTargetCalibrationRows
Epsilon.TimeSeriesCalibrationInput
Epsilon.MMMCalibrationSpec
Epsilon.UnalignedValuesError
Epsilon.NonMonotonicError
Epsilon.exact_row_indices
Epsilon.validate_lift_test_columns
Epsilon.assert_monotonic_lift
Epsilon.scale_channel_lift_measurements
Epsilon.scale_target_for_lift_measurements
Epsilon.scale_lift_measurements
Epsilon.gamma_shape_scale
Epsilon.lift_test_gamma_distribution
Epsilon.lift_test_estimated_lift
Epsilon.lift_test_estimated_lift_ad
Epsilon.lift_test_likelihood_terms
Epsilon.lift_test_log_density
Epsilon.lift_test_payload_log_density
Epsilon.LiftTestCalibrationPayload
Epsilon.validate_lift_test_calibration_payload
Epsilon.build_lift_test_calibration_payload
Epsilon.CostPerTargetCalibrationPayload
Epsilon.validate_cost_per_target_calibration_payload
Epsilon.build_cost_per_target_calibration_payload
Epsilon.cost_per_target_penalties
Epsilon.cost_per_target_total_penalty
Epsilon._validate_calibration_steps_and_rows
Epsilon._build_calibration_input
Epsilon._resolve_calibration_spec
```
