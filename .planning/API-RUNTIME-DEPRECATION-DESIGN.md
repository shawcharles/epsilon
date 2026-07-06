# Public API Runtime Deprecation Design

Phase 23 recorded the implementation contract for runtime deprecation warnings
on the six validation-helper exports selected in
`.planning/API-EXPORT-CLEANUP-RFC.md`. Phase 24 has implemented that contract
as public `Base.depwarn` wrappers around warning-free internal helpers.

This document remains the design record. Phase 24 did not remove exports,
rename symbols, reorder the API inventory, change validation semantics, or
alter Abacus parity evidence.

## Phase 24 Implementation Status

- Landed: public direct calls to the six validators emit the warning text
  recorded below.
- Landed: `CalibrationStepConfig`,
  `build_lift_test_calibration_payload`,
  `build_cost_per_target_calibration_payload`, `SamplerConfig`,
  `ModelConfig`, `MMMData`, and the existing config-loader paths use
  warning-free helper validation through their constructors/builders.
- Landed: focused tests assert direct-call warnings, valid direct-call
  `nothing` returns, invalid direct-call `ArgumentError` messages, and silent
  replacement workflows where feasible.
- Not landed: export removal, API inventory row changes, support-band changes,
  or stable-v1 API claims.

## Source Candidate Set

The candidate set is fixed by the Phase 22 cleanup RFC:

| Symbol | Future Migration Target |
|---|---|
| `validate_calibration_step_config` | Use `CalibrationStepConfig` construction or `load_public_config` calibration parsing. |
| `validate_cost_per_target_calibration_payload` | Use `build_cost_per_target_calibration_payload`. |
| `validate_lift_test_calibration_payload` | Use `build_lift_test_calibration_payload`. |
| `validate_mmm_data` | Use `MMMData` construction before building `TimeSeriesMMM`. |
| `validate_model_config` | Use `ModelConfig` construction or `load_model_config`. |
| `validate_sampler_config` | Use `SamplerConfig` construction or `load_sampler_config`. |

These migration targets are existing public workflows for this cleanup slice.
They are not, by themselves, a stable v1 API freeze.

## Main Design Risk

The six public validation helpers were not isolated leaf APIs before Phase 24.
They were called from supported constructors and builders:

- `CalibrationStepConfig` called `validate_calibration_step_config`.
- `build_lift_test_calibration_payload` calls
  `validate_lift_test_calibration_payload`.
- `build_cost_per_target_calibration_payload` calls
  `validate_cost_per_target_calibration_payload`.
- typed config/data constructors called `validate_sampler_config`,
  `validate_model_config`, and `validate_mmm_data`.

Therefore Phase 24 did not add `Base.depwarn` directly to the old validator
bodies. That would have warned during ordinary constructor and builder use,
punishing the migration path we are telling users to adopt. Tiny change, large
footgun.

## Implemented Pattern

Use manual `Base.depwarn` wrappers rather than `@deprecate`. The public
functions keep their current names and signatures, emit one deprecation warning
when directly called, then delegate to warning-free internal helpers. This
preserves behaviour while giving tests and docs precise control over the
warning boundary.

Pattern:

```julia
function _validate_example(value::Example)
    # Current validation body, unchanged.
    return nothing
end

function validate_example(value::Example)
    Base.depwarn(
        "Epsilon.validate_example is deprecated as a public API; use Example construction instead. The function remains exported for this release and may be unexported before v1.",
        :validate_example,
    )
    return _validate_example(value)
end
```

Internal constructors, loaders, and builders must call `_validate_example`, not
`validate_example`.

## Candidate Contracts

### `validate_calibration_step_config`

Implemented warning text:

```text
Epsilon.validate_calibration_step_config is deprecated as a public API; use CalibrationStepConfig construction or load_public_config calibration parsing instead. The function remains exported for this release and may be unexported before v1.
```

Implemented source handling:

- Moved the validation body in `src/mmm/calibration.jl` to
  `_validate_calibration_step_config`.
- Updated `CalibrationStepConfig` construction to call
  `_validate_calibration_step_config`.
- Kept `validate_calibration_step_config` as the public warning wrapper.

Implemented tests:

- Direct public call warns and returns `nothing` for a valid config.
- Invalid direct public call warns and then throws the same `ArgumentError`
  type with the same message as today.
- `CalibrationStepConfig` construction does not warn.

Rollback note:

- If constructor behaviour or error text changes, revert the wrapper split and
  leave the symbol as a Phase 22 candidate only.

### `validate_lift_test_calibration_payload`

Implemented warning text:

```text
Epsilon.validate_lift_test_calibration_payload is deprecated as a public API; use build_lift_test_calibration_payload instead. The function remains exported for this release and may be unexported before v1.
```

Implemented source handling:

- Moved the validation body in `src/mmm/calibration.jl` to
  `_validate_lift_test_calibration_payload`.
- Updated `build_lift_test_calibration_payload` and any internal payload
  validation path to call `_validate_lift_test_calibration_payload`.
- Kept `validate_lift_test_calibration_payload` as the public warning wrapper.

Implemented tests:

- Direct public call warns and returns `nothing` for a valid payload.
- Invalid direct public call warns and then throws the same `ArgumentError`
  type with the same message as today.
- `build_lift_test_calibration_payload` does not warn when valid inputs are
  supplied.

Rollback note:

- If the builder emits warnings, the implementation is wrong. Revert and keep
  the public validator candidate-only.

### `validate_cost_per_target_calibration_payload`

Implemented warning text:

```text
Epsilon.validate_cost_per_target_calibration_payload is deprecated as a public API; use build_cost_per_target_calibration_payload instead. The function remains exported for this release and may be unexported before v1.
```

Implemented source handling:

- Moved the validation body in `src/mmm/calibration.jl` to
  `_validate_cost_per_target_calibration_payload`.
- Updated `build_cost_per_target_calibration_payload` and any internal payload
  validation path to call `_validate_cost_per_target_calibration_payload`.
- Kept `validate_cost_per_target_calibration_payload` as the public warning
  wrapper.

Implemented tests:

- Direct public call warns and returns `nothing` for a valid payload.
- Invalid direct public call warns and then throws the same `ArgumentError`
  type with the same message as today.
- `build_cost_per_target_calibration_payload` does not warn when valid inputs
  are supplied.

Rollback note:

- If the builder emits warnings, revert the wrapper split and keep the current
  no-warning public function until a better migration surface exists.

### `validate_mmm_data`

Implemented warning text:

```text
Epsilon.validate_mmm_data is deprecated as a public API; use MMMData construction before building TimeSeriesMMM instead. The function remains exported for this release and may be unexported before v1.
```

Implemented source handling:

- Moved the validation body in `src/model/types.jl` to
  `_validate_mmm_data`.
- Updated `MMMData` construction to call `_validate_mmm_data`.
- Kept `validate_mmm_data` as the public warning wrapper.

Implemented tests:

- Direct public call warns and returns `nothing` for valid data.
- Invalid direct public call warns and then throws the same `ArgumentError`
  type with the same message as today.
- `MMMData` construction does not warn.

Rollback note:

- If common model construction starts warning, revert. A deprecation that
  attacks the replacement path is worse than no deprecation.

### `validate_model_config`

Implemented warning text:

```text
Epsilon.validate_model_config is deprecated as a public API; use ModelConfig construction or load_model_config instead. The function remains exported for this release and may be unexported before v1.
```

Implemented source handling:

- Moved the validation body in `src/model/types.jl` to
  `_validate_model_config`.
- Updated `ModelConfig` construction and loader paths to call
  `_validate_model_config`.
- Kept `validate_model_config` as the public warning wrapper.

Implemented tests:

- Direct public call warns and returns `nothing` for a valid model config.
- Invalid direct public call warns and then throws the same `ArgumentError`
  type with the same message as today.
- `ModelConfig` construction and `load_model_config` do not warn.

Rollback note:

- If YAML/config loading warns for valid supported configs, revert the runtime
  warning and leave the lifecycle as planning-only.

### `validate_sampler_config`

Implemented warning text:

```text
Epsilon.validate_sampler_config is deprecated as a public API; use SamplerConfig construction or load_sampler_config instead. The function remains exported for this release and may be unexported before v1.
```

Implemented source handling:

- Moved the validation body in `src/model/types.jl` to
  `_validate_sampler_config`.
- Updated `SamplerConfig` construction and loader paths to call
  `_validate_sampler_config`.
- Kept `validate_sampler_config` as the public warning wrapper.

Implemented tests:

- Direct public call warns and returns `nothing` for a valid sampler config.
- Invalid direct public call warns and then throws the same `ArgumentError`
  type with the same message as today.
- `SamplerConfig` construction and `load_sampler_config` do not warn.

Rollback note:

- If sampler config construction or loading warns, revert and keep the public
  validator candidate-only.

## Test Lane

The runtime implementation phase uses targeted tests, not the full suite by
default. Expected lanes:

- focused API/export checks if export inventory or lifecycle docs are touched;
- `test/model/calibration.jl` for calibration payload validators;
- the focused model/config test file covering `ModelConfig`, `SamplerConfig`,
  and `MMMData` constructors;
- `git diff --check`;
- Runic on any edited Julia test/source files.

The full suite is only justified if the future phase changes exports,
shared test namespace imports, or other cross-file package behaviour.

## Documentation Timing

Runtime deprecation is now announced in the affected public docstrings and
changelog because runtime warnings have landed. Continue to:

- keep the Phase 22 RFC as historical governance context;
- update `CHANGELOG.md` under `Changed`;
- update API docs for each affected symbol or remove them only in the later
  unexport/removal phase;
- keep the triage register lifecycle as `deprecation-candidate` until a
  separate approved phase changes the export surface.

## Non-Goals

- No export removal in the warning phase.
- No broad public API cleanup beyond the six Phase 22 candidates.
- No change to Abacus parity status.
- No claim that Epsilon has reached stable v1 API readiness.
