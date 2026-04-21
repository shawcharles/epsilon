# Epsilon.jl

`Epsilon.jl` is a Julia-native framework for Bayesian marketing mix modeling.
The initial package scaffold follows standard Julia package conventions so the
package can grow in layers without fighting the toolchain.

## Current Status

Epsilon is in Phase 4:

- package entry point
- test harness
- docs scaffold
- repository standards
- transform primitives completed
- prior and distribution layer completed
- typed model/config scaffolding completed
- builder and orchestration interfaces in progress

## Working Principles

- Preserve statistical correctness and stable model behavior.
- Prefer Julia-native APIs, multiple dispatch, and explicit types.
- Keep the public API small until each layer is stable.
- Treat autodiff compatibility and numerical tests as first-class constraints.

## Planning

Project planning documents live under `.planning/` in the repository root.

## Standards

Repository standards are defined in `TECHNICAL-STANDARDS.md`.

## API

```@docs
Epsilon.ConvMode
Epsilon.EpsilonPrior
Epsilon.LaplacePrior
Epsilon.LogNormalPrior
Epsilon.MaskedPrior
Epsilon.ModelConfigError
Epsilon.AbstractModel
Epsilon.AbstractRegressionModel
Epsilon.AbstractMMMModel
Epsilon.MMMData
Epsilon.MMMModelSpec
Epsilon.ModelConfig
Epsilon.ModelFitState
Epsilon.SamplerConfig
Epsilon.TimeSeriesMMM
Epsilon.WeibullType
Epsilon.active_count
Epsilon.batched_convolution
Epsilon.binomial_adstock
Epsilon.build_model
Epsilon.deserialize_model_config
Epsilon.deserialize_prior
Epsilon.delayed_adstock
Epsilon.geometric_adstock
Epsilon.epsilon_version
Epsilon.expand_masked_values
Epsilon.load_model_config
Epsilon.load_public_config
Epsilon.load_sampler_config
Epsilon.hill_function
Epsilon.instantiate_distribution
Epsilon.logistic_saturation
Epsilon.MaxAbsScaler
Epsilon.MaxAbsScaleTarget
Epsilon.MaxAbsScaleChannels
Epsilon.michaelis_menten
Epsilon.FinnishHorseshoePrior
Epsilon.finnish_horseshoe_coefficients
Epsilon.HorseshoePrior
Epsilon.horseshoe_coefficients
Epsilon.max_abs_scale_target_data
Epsilon.max_abs_scale_channel_data
Epsilon.model_config_from_dict
Epsilon.normalize_channel_columns
Epsilon.nobs
Epsilon.r2d2_coefficients
Epsilon.r2d2_variance_weights
Epsilon.R2D2Prior
Epsilon.regularized_local_scales
Epsilon.Scaled
Epsilon.sampler_config_from_dict
Epsilon.SkewStudentT
Epsilon.StandardScaler
Epsilon.StandardizeControls
Epsilon.standardize_control_data
Epsilon.tanh_saturation
Epsilon.validate_column_indices
Epsilon.validate_channel_values
Epsilon.validate_model_config
Epsilon.validate_mmm_data
Epsilon.validate_sampler_config
Epsilon.validate_target_data
Epsilon.weibull_adstock
Epsilon.fit!
Epsilon.fit_transform!
Epsilon.inverse_transform
Epsilon.predict
Epsilon.transform
```
