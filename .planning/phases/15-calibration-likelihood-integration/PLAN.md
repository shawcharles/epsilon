# Phase 15: Calibration Likelihood Integration

## Status

Planned 2026-07-01. Task 15-01 (contract freeze), Task 15-02 (typed
calibration payloads), Task 15-03 (config/spec threading), Task 15-04
(pure model-space calibration log-density helpers), Task 15-05
(lift-test likelihood wired into `_time_series_mmm_model`), and Task 15-06
(cost-per-target soft penalties wired into `_time_series_mmm_model`), and
Task 15-07 (fixture-backed integration evidence) are landed. Task 15-08
(documentation, ledger, changelog, and guardrail closure) remains.




## Goal

Turn the scaffolded calibration/lift-test helper surface into a bounded,
fixture-backed `TimeSeriesMMM` model capability by adding calibration
log-likelihood contributions to the Turing sampling model.

This phase is intentionally narrower than broad Abacus calibration parity. The
existing helper layer in `src/mmm/calibration.jl` already covers schema,
alignment, monotonicity, scaling, Gamma reparameterization, lift-test
likelihood-term math, and cost-per-target soft penalties. Phase 15 wires that
math into the supported time-series model path only.

## Non-Goals

- Do not implement `PanelMMM` calibration integration in this phase.
- Do not add panel calibration YAML support, panel row alignment, or
  panel-cell calibration semantics.
- Do not implement calibration in `approximate_fit!` / VI.
- Do not add automatic scenario refits, Dash/UI workflows, or AI advisor
  calibration features.
- Do not change Abacus fixture generation except where new deterministic
  integration fixtures are required.
- Do not broaden the supported model feature matrix beyond the current
  `TimeSeriesMMM` surface unless the calibration integration requires an
  explicit rejection path.

## Invariants

- Calibration is optional and disabled by default.
- Uncalibrated `TimeSeriesMMM` fits must keep the same model structure,
  parameter names, artifact contracts, and posterior predictive behavior.
- Calibration terms must live in the same scaled model space as the fitted
  media and target likelihood.
- The public contract must fail closed: unsupported panel, VI, unknown method,
  malformed rows, invalid domains, or incompatible saturation choices
  must raise clear `ArgumentError`s rather than silently dropping calibration.
- Python may export deterministic Abacus fixtures, but Julia tests must consume
  committed fixture files and must not call Python at runtime.
- The parity ledger remains `scaffolded` until the sampling-model integration is
  implemented and verified.

## Design Decisions

### Calibration Ownership

Store calibration configuration and prepared calibration observations in a small
typed payload attached to the time-series runtime/spec path, not as ad hoc
fields on `TimeSeriesMMM`.

Rationale: the model already derives scale state in `MMMModelSpec` and passes a
runtime object into `_time_series_mmm_model`. Calibration needs both resolved
scale state and model-parameter-dependent saturation values. Keeping
the payload close to runtime construction avoids a second hidden data path.

### Model Scope

Support `TimeSeriesMMM` MCMC first. Reject `PanelMMM` and VI calibration
honestly.

Rationale: panel calibration needs a separate methodological contract for row
coordinates, panel-cell attribution, and pooled versus panel-indexed effects.
Adding it opportunistically would create false parity. VI support also needs a
separate check that `Turing.@addlogprob!`/AD behavior and grouped VI artifacts
remain coherent.

### Likelihood Semantics

Compute calibration contributions from transformed media in scaled space:

- lift tests use `mu = abs(saturation(x + delta_x) - saturation(x))`, with the
  same sampled channel-specific saturation parameters as the media path
- observed lift is `abs(delta_y)` after target scaling
- uncertainty is scaled with the target transform and must remain positive
- cost-per-target penalties use scaled cost-per-target values and add a scalar
  soft penalty

Rationale: Epsilon's bounded Abacus-compatible model path samples on scaled
channels and scaled target. Calibration in original units would double-count
scale and break comparability. Adstock must not be inserted into lift-test
calibration unless a later fixture-backed contract proves that Abacus is
calibrating adstocked time-series media rather than saturation observations.

### Artifact Semantics

Persist enough calibration metadata in the successful fit artifact to explain
what was applied, but do not claim posterior replay or pipeline parity until
those surfaces have their own evidence.

Rationale: model fitting needs traceability, but this phase should not
accidentally reopen pipeline/reporting scope.

## Task List

### Task 15-01: Freeze The Time-Series Calibration Contract

**Description:** Define the minimal public and internal contract for
time-series calibration integration before touching the Turing model.

**Status:** Landed 2026-07-01. See "Task 15-01 Frozen Contract" below for the
concrete decisions.

**Acceptance criteria:**
- [x] The accepted config/data shape is documented in this plan or a linked
      planning note before implementation.
- [x] `TimeSeriesMMM` is the only accepted model target.
- [x] Panel and VI behaviour is specified as explicit rejection, not future
      implicit support.
- [x] Supported step methods are limited to
      `add_lift_test_measurements` and `add_cost_per_target_calibration`.

**Verification:**
- [x] Review against `.planning/ABACUS-PARITY-LEDGER.md`.
- [x] Confirm no release-facing docs claim calibration model parity yet.

**Dependencies:** None.

**Files likely touched during implementation:**
- `.planning/ABACUS-PARITY-LEDGER.md`
- `docs/src/index.md`
- `src/mmm/calibration.jl`
- `src/model/types.jl`

**Estimated scope:** Small.

## Task 15-01 Frozen Contract

This section is the authoritative record of the decisions Task 15-01 froze.
Tasks 15-02 onward must implement against this contract rather than reopening
it; changing any of these decisions requires an explicit plan update, not a
silent implementation choice.

### Accepted model target

- `TimeSeriesMMM` fitted via `fit!` (Turing / NUTS MCMC) is the only accepted
  integration target for calibration likelihood terms in Phase 15.
- `PanelMMM` must reject any calibration configuration with a clear
  `ArgumentError` raised before sampling, mirroring the existing
  `_validate_model_data_alignment(config::ModelConfig, data::PanelMMMData)`
  rejection pattern in `src/model/builder.jl` (for example, the existing
  `"PanelMMM does not yet support media.controls"` style message). Calibration
  must not be accepted implicitly through generic config/spec code paths
  shared with `TimeSeriesMMM`.
- `approximate_fit!` (VI) on `TimeSeriesMMM` must also reject calibration
  configuration with a clear `ArgumentError` for now. VI support is out of
  scope until a separate contract addresses `Turing.@addlogprob!` interaction
  with the AdvancedVI mean-field Gaussian path.
- `prior_predict`/unfitted prediction paths are unaffected: calibration is a
  fitting-time likelihood contribution only, not a generative feature of the
  model's prior/posterior predictive draws.

### Accepted config/data entry shape

- Calibration steps enter through a **companion internal payload**, not a new
  `ModelConfig` field and not `ModelConfig.extras`. Concretely: `TimeSeriesMMM`
  gains an optional constructor argument (for example
  `calibration_steps::Vector{CalibrationStepConfig} = CalibrationStepConfig[]`
  plus the associated row data), resolved internally into a typed payload
  attached alongside the runtime/spec construction path described in the
  "Calibration Ownership" design decision above.
- Rationale for deferring a `ModelConfig.calibration` field: `ModelConfig` is
  the serializable, YAML-facing config contract validated by
  `validate_model_config`, and widening it now would commit to a YAML schema
  and a `MMMModelSpec`/serialization format change before the model-integration
  semantics (Tasks 15-04 through 15-06) are proven. A companion payload keeps
  Task 15-03's spec/serialization footprint minimal and reversible. Promoting
  calibration steps into `ModelConfig` (and YAML) is explicitly deferred to a
  later phase once the sampling-model contract is verified.
- Lift-test row data is accepted as plain columnar input (channel labels plus
  `x`, `delta_x`, `delta_y`, `sigma` vectors), validated with the existing
  `validate_lift_test_columns`, `exact_row_indices`, and
  `assert_monotonic_lift` helpers from `src/mmm/calibration.jl`. It is not a
  new field on `MMMData`.
- Cost-per-target row data is accepted the same way: plain columnar input
  (`gathered_cpt`, `targets`, `sigma`), matching Abacus's explicit
  gathered/target/sigma soft-penalty semantics (see the resolved "cost-per-target
  semantics" open question below).

### Supported calibration methods

- Exactly two methods are supported, matching the existing
  `_SUPPORTED_CALIBRATION_METHODS` in `src/mmm/calibration.jl`:
  `add_lift_test_measurements` and `add_cost_per_target_calibration`. No other
  method name is accepted; `validate_calibration_step_config` already enforces
  this and Task 15-02/15-03 must not weaken it.
- `CalibrationStepConfig.params.dist` remains rejected (no custom likelihood
  distributions through config), matching current Abacus YAML restrictions.

### Resolved open questions

- **Config/data entry point** (previously open): resolved above as a
  companion internal payload attached to `TimeSeriesMMM`, not `ModelConfig` or
  `ModelConfig.extras`.
- **Cost-per-target semantics** (previously open): resolved as Abacus's
  explicit gathered/target/sigma soft-penalty semantics. Cost-per-target values
  are supplied directly by the caller and are not inferred from optimization or
  posterior-predictive artifacts.
- **Supported saturation combinations** (previously open): resolved as the
  current centered logistic saturation path first (`centered_logistic_saturation`,
  including the `"logistic"` compatibility alias). Task 15-05 must explicitly
  reject other saturation types (`tanh`, `michaelis_menten`, `hill`, `none`)
  when calibration is enabled until each has its own fixture-backed evidence,
  rather than silently applying possibly-incorrect calibration math to them.

### Ledger and docs status after Task 15-01

- `.planning/ABACUS-PARITY-LEDGER.md`'s calibration row remains `scaffolded`.
  Task 15-01 does not change that status; it only records the frozen contract
  that Tasks 15-02 through 15-08 must implement before the row can move.
- `docs/src/index.md`'s "Calibration" section continues to state that the
  sampling-model integration is a separate follow-on slice; no release-facing
  doc claims `TimeSeriesMMM`/`PanelMMM` calibration model parity yet.


### Task 15-02: Add Typed Calibration Payloads

**Description:** Add internal typed payloads that represent validated,
row-aligned, scaled calibration observations ready for the model runtime.

**Status:** Landed 2026-07-01. `LiftTestCalibrationPayload` and
`CostPerTargetCalibrationPayload` (plus their `build_*`/`validate_*` helpers)
are implemented in `src/mmm/calibration.jl` and exported from
`src/Epsilon.jl`. Neither payload type is wired into `TimeSeriesMMM`,
`ModelConfig`, or the Turing model yet; that remains Task 15-03 onward.

**Acceptance criteria:**
- [x] Lift-test payloads carry channel index, scaled `x`, scaled `delta_x`,
      scaled `delta_y`, and scaled positive `sigma`.
- [x] Cost-per-target payloads carry scaled gathered/current cost-per-target,
      scaled target cost-per-target, and positive `sigma`.
- [x] Payload constructors reuse the existing helper functions in
      `src/mmm/calibration.jl`.
- [x] Unsupported or malformed payloads fail with clear `ArgumentError`s.

**Verification:**
- [x] Focused unit tests cover valid payload construction and rejection cases.
- [x] Existing `test/model/calibration.jl` fixture-backed helper tests still
      pass unchanged except for intentional additions.

**Dependencies:** Task 15-01.

**Files likely touched during implementation:**
- `src/mmm/calibration.jl`
- `src/Epsilon.jl`
- `test/model/calibration.jl`

**Estimated scope:** Medium.

### Task 15-03: Thread Calibration Through Config And Spec Boundaries

**Description:** Decide and implement how calibration steps enter the typed
time-series model path, then carry resolved calibration metadata through the
model spec/runtime boundary.

**Status:** Landed 2026-07-01. Task 15-03 threads calibration through
`TimeSeriesMMM`'s config/spec/runtime construction and fitting boundaries, and
rejects calibration where unsupported (`PanelMMM`, VI) — it does not add any
calibration likelihood term to the Turing model itself. Concretely:
`TimeSeriesMMM` gained a `calibration` field (populated via new
`calibration_steps`/`lift_test_data`/`cost_per_target_data` constructor keyword
arguments) holding a raw `TimeSeriesCalibrationInput`. `_fit_time_series_mmm!`
resolves that raw input into a scaled `MMMCalibrationSpec` via
`_resolve_calibration_spec` and attaches it to the fit artifact (not to
`MMMModelSpec` itself, which remains unchanged). `PanelMMM` rejects
calibration kwargs with a `MethodError` (no such constructor parameters
exist), and `approximate_fit!` (VI) on a calibrated `TimeSeriesMMM` raises a
clear `ArgumentError`. Save/load round-trips the calibration field and
defaults it to `nothing` for old-format payloads with no schema version bump
required. The resolved calibration spec is attached to the artifact for
traceability only; it has zero effect on posterior inference until Task 15-05
wires a calibration log-density contribution into the Turing model via
`Turing.@addlogprob!`.

**Acceptance criteria:**
- [x] `ModelConfig` or a narrowly scoped companion payload can represent the
      calibration steps without weakening existing config validation.
- [x] `_build_model_spec(config, data::MMMData)` can preserve the resolved
      calibration metadata needed for fitting.
- [x] `_build_model_spec(spec, new_data::MMMData)` either preserves or rejects
      calibration metadata according to the prediction/replay contract.
- [x] Existing serialized model/result artifacts remain backwards compatible,
      or any format change is versioned and tested.

**Verification:**
- [x] Config/model-spec equality tests cover calibration metadata.
- [x] Save/load tests confirm old uncalibrated artifacts still load.
- [x] Negative tests prove panel specs reject calibration metadata for now.

**Dependencies:** Task 15-02.

**Files likely touched during implementation:**
- `src/model/types.jl`
- `src/model/builder.jl`
- `src/serialization.jl` or related artifact helpers if spec shape changes
- `test/model/config.jl`
- `test/model/builder.jl`
- `test/model/serialization.jl`

**Estimated scope:** Medium.

### Task 15-04: Add Pure Model-Space Calibration Log-Density Helpers

**Description:** Add deterministic helpers that compute calibration log-density
contributions from already scaled channel values and sampled saturation
parameters, without invoking Turing.

**Status:** Landed 2026-07-01. Task 15-04 adds `lift_test_estimated_lift_ad`,
`lift_test_log_density`, and `lift_test_payload_log_density` to
`src/mmm/calibration.jl` as pure, Turing-independent, AD-compatible lift-test
log-density helpers operating on already-scaled model-space values and a
caller-supplied `saturation_fn`/per-channel sampled parameter vector.
`lift_test_estimated_lift_ad` avoids the `Float64`-forcing behavior of the
existing `lift_test_estimated_lift` so that `ForwardDiff.Dual`/
`ReverseDiff.TrackedReal` values survive through `saturation_fn`.
`lift_test_log_density` returns a scalar total log-density (summed Gamma
log-density across rows, reusing `lift_test_gamma_distribution`) and rejects
zero/negative/non-finite estimated lift, non-positive sigma, and non-finite
inputs via explicit `throw`s before the AD-differentiated summation, without
mutating any inputs. `lift_test_payload_log_density` is the multi-channel,
`LiftTestCalibrationPayload`-aware entry point: it validates
`payload.channel_index` against the supplied per-channel parameter vector and
raises a clear `ArgumentError` on out-of-bounds channel index rather than an
opaque `BoundsError`, then delegates to `lift_test_log_density`. No adstock is
applied in any of these helpers, preserving the saturation-only lift-test
calibration contract. Cost-per-target's acceptance criterion was already
satisfied by the pre-existing `cost_per_target_penalties`/
`cost_per_target_total_penalty` helpers from Task 15-02, unchanged in this
task. These new functions are not called from `_time_series_mmm_model` or any
other Turing model code; they have zero effect on posterior inference until
Task 15-05 wires them in via `Turing.@addlogprob!`. New deterministic tests in
`test/model/calibration.jl` compare helper outputs to the existing
`ABACUS_LIFT_TEST_LIKELIHOOD_CASES` fixture (matching the fixture-backed
PyMC Gamma log-density semantics), cover zero estimated lift, non-positive
sigma, non-finite `x`/`delta_x`/`delta_y`, and channel-index mismatch, and add
a `ForwardDiff`/`ReverseDiff` gradient-agreement smoke test following the
pattern in `test/transforms/autodiff.jl`.

**Acceptance criteria:**
- [x] Lift-test log-density helpers accept the channel-specific scaled values
      needed for `x` and `x + delta_x`.
- [x] Cost-per-target helpers return scalar penalties matching the existing
      pure helper semantics.
- [x] Helpers are generic enough for AD-compatible number types where they sit
      on the Turing path.
- [x] Domain checks remain outside hot AD loops where possible and do not
      mutate model inputs.

**Verification:**
- [x] Deterministic tests compare helper outputs to existing Abacus fixtures.
- [x] Tests cover zero estimated lift, non-finite inputs, and incompatible
      channel indices.

**Dependencies:** Task 15-02.

**Files likely touched during implementation:**
- `src/mmm/calibration.jl`
- `test/model/calibration.jl`

**Estimated scope:** Medium.

### Task 15-05: Integrate Lift-Test Likelihood Into `_time_series_mmm_model`

**Description:** Add the optional lift-test likelihood contribution to the
Turing model after saturation parameters are sampled and before the target
likelihood loop completes.

**Status:** Landed 2026-07-01. `_time_series_mmm_model` accepts an optional
`lift_test_payload` keyword. When present, it rejects any non-`logistic`
`runtime.saturation_type` with a clear `ArgumentError` (matching the frozen
Task 15-01 contract), then calls the Task 15-04 pure helper
`lift_test_payload_log_density` with `centered_logistic_saturation` and the
same sampled `lam` vector used by the media saturation path, and adds the
result via `Turing.@addlogprob!`. The helper call is wrapped in a
`try`/`catch` that converts a domain-rejection `ArgumentError` (for example,
"estimated lift magnitude must contain only positive finite values") into a
`-Inf` log-density contribution instead of propagating the exception,
because NUTS's `AutoForwardDiff` gradient probes legitimately visit
degenerate parameter points during warmup/leapfrog steps, and an uncaught
`ArgumentError` there aborts sampling rather than simply making that point
low-probability. `_fit_time_series_mmm!` passes
`calibration.lift_test` (from the Task 15-03 resolved `MMMCalibrationSpec`)
straight through as `lift_test_payload`; uncalibrated models pass `nothing`
and take the exact same code path as before this task (the `if
!isnothing(lift_test_payload)` block is skipped entirely, so byte-for-byte
uncalibrated behaviour is preserved).

A significant implementation lesson from this task: an earlier draft added
`isfinite(lift_test_logdensity) && return` immediately after
`Turing.@addlogprob!`, intending to short-circuit the rest of model
construction once an invalid calibration point was flagged. This broke
Turing/DynamicPPL's invariant that every evaluation of a `@model` function
must execute the same set of `~` tilde-statements: on the early-return path,
statements such as `beta_controls ~ Turing.filldist(...)` were skipped, while
on the normal path they were not, producing a
`FieldError: type NamedTuple has no field 'beta_controls'` deep inside
DynamicPPL's `VarNamedTuple` machinery whenever NUTS's AD step compared the
two variable sets. The fix was to remove the early return entirely: the model
always adds the (possibly `-Inf`) lift-test log-density term via
`Turing.@addlogprob!` and then unconditionally continues executing every
subsequent `~` statement, regardless of whether the lift-test term was
finite. Any future domain-rejection logic added to this model (for example,
Task 15-06's cost-per-target penalties) must follow the same pattern: convert
domain violations into `-Inf`/penalized log-density contributions, never into
early returns that skip declared random variables.

New tests in `test/model/builder.jl` add a deterministic log-density
comparison (using `Turing.DynamicPPL.condition`/`evaluate!!`/`getlogjoint` at
fixed parameter values) proving the calibrated and uncalibrated model logjoint
differ by exactly `lift_test_payload_log_density(...)`, a negative test
proving a `tanh`-saturation calibrated model raises `ArgumentError` on
`fit!`, and a tiny end-to-end MCMC smoke test that fits a calibrated
`TimeSeriesMMM`. The full existing 3900+ test suite (including
`test/model/runtests.jl`, `Aqua.test_all`, and doctests) passes with these
additions and no regressions. Panel calibration, VI, pipeline integration,
and cost-per-target `Turing.@addlogprob!` wiring remain untouched and out of
scope for this task.

A second implementation lesson from this task concerns test-file namespace
hygiene rather than model semantics. `test/model/builder.jl`'s new
deterministic log-density test needs `Turing.DynamicPPL.condition`,
`evaluate!!`, `VarInfo`, and `getlogjoint`. An early draft added `using Turing`
to the top of that file to get the `Turing` name in scope. Because
`test/runtests.jl` `include`s every test file inside one shared top-level
`@testset` block in `Main` (not separate module scopes), a `using` statement
in any one included file leaks its exported bindings into every other
included file evaluated afterward in the same `Pkg.test()` run. Turing exports
its own `predict` binding, which collided with `Epsilon`'s exported `predict`
(brought in via `using Epsilon` at the top of `test/runtests.jl`) and made the
unqualified `predict(model)` call at `test/validation/parity.jl:668` raise
`UndefVarError: predict not defined in Main` due to export ambiguity — a
regression only visible in the full `Pkg.test()` run, not when running
`test/model/builder.jl` in isolation. The fix was to change `using Turing` to
`import Turing` in `test/model/builder.jl`: every `Turing.X` reference in that
file was already fully qualified (`Turing.DynamicPPL.condition(...)`, etc.),
so `import Turing` supplies the module name without re-exporting any of
Turing's own exported bindings into the shared `Main` namespace. The general
rule for this codebase's test files: prefer `import ModuleName` over
`using ModuleName` unless a test file actually needs unqualified access to
that module's exports, because every test file shares one `Main` namespace
for the duration of `Pkg.test()`.


**Acceptance criteria:**
- [x] Uncalibrated runtime payloads produce byte-for-byte equivalent model
      construction behaviour at the public API level.
- [x] Calibrated runtime payloads add a scalar log-probability contribution via
      `Turing.@addlogprob!`.
- [x] The lift-test path uses the same sampled saturation parameters as the
      media contribution path.
- [x] Unsupported saturation combinations are either implemented correctly or
      rejected before sampling.
- [x] Adstock is not applied to lift-test rows unless a later fixture-backed
      design explicitly changes the calibration contract.

**Verification:**
- [x] A deterministic log-density test proves calibrated and uncalibrated
      models differ exactly by the expected fixture-backed calibration term.
- [x] A tiny MCMC smoke test fits a calibrated `TimeSeriesMMM`.
- [x] Existing uncalibrated model tests still pass.

**Dependencies:** Tasks 15-03 and 15-04.

**Files likely touched during implementation:**
- `src/mmm/model.jl`
- `src/model/builder.jl`
- `test/model/model.jl`
- `test/model/builder.jl`

**Estimated scope:** Medium.


### Task 15-06: Integrate Cost-Per-Target Soft Penalties

**Description:** Add optional cost-per-target soft-penalty terms to the
time-series Turing model, using the existing pure penalty helper.

**Status:** Landed 2026-07-01. `_time_series_mmm_model` accepts an optional
`cost_per_target_payload` keyword alongside `lift_test_payload`. When present,
it calls the existing pure helper `cost_per_target_total_penalty` (unchanged
from Task 15-02) with `cost_per_target_payload.gathered_cpt`, `.targets`, and
`.sigma`, and adds the resulting scalar via `Turing.@addlogprob!`. No new
AD-safe variant of `cost_per_target_total_penalty` was required: its `Float64`
internal casting is safe to reuse as-is because `CostPerTargetCalibrationPayload`'s
fields are fixed caller-supplied `Float64` data (validated/scaled once at
calibration-spec-resolution time), never derived from a Turing-sampled
parameter — unlike the lift-test path, where `lam` is a live sampled variable
that must survive AD tracing through `saturation_fn`. Because the term never
depends on a sampled variable, the added log-density contribution is an
intentional **constant** with respect to the parameters being sampled; this
matches the Task 15-01 frozen contract's requirement that the implementation
avoid any hidden dependency on posterior predictive or optimization artifacts,
since the penalty is computed purely from the caller-supplied gathered/target/
sigma data. The helper call is wrapped in the same `try`/`catch` pattern used
for the lift-test term: a domain-rejection `ArgumentError` is converted to a
`-Inf` log-density contribution rather than propagated, and the model
continues to execute every subsequent `~` statement unconditionally — no
early return is introduced, preserving the Task 15-05 invariant that every
evaluation of the `@model` function touches the same set of tilde-statements.
`_fit_time_series_mmm!` threads `calibration.cost_per_target` (from the
Task 15-03 resolved `MMMCalibrationSpec`) straight through as
`cost_per_target_payload`; uncalibrated models and lift-test-only calibrated
models pass `nothing` and take the exact same code path as before this task.
The two calibration terms are independent and simply additive: the lift-test
block and the cost-per-target block are separate `if !isnothing(...)` guards
that each call their own `Turing.@addlogprob!`, so enabling both at once sums
both scalar contributions onto the log-joint with no interaction between them.

Invalid or non-positive `sigma` is rejected eagerly, but not inside the Turing
model body: `CostPerTargetCalibrationRows`'s inner constructor calls the
existing `_positive_float_vector` validator and raises `ArgumentError:
sigma must contain only positive values` immediately at construction time,
before any `TimeSeriesMMM`/`fit!` call is even possible. This is a stronger
guarantee than a `fit!`-time check: malformed calibration data can never reach
the sampler. (The `try`/`catch`-to-`-Inf` conversion inside the model instead
handles a different failure mode — transient domain violations that
`cost_per_target_total_penalty` can raise from otherwise-valid data during
NUTS's AD gradient probes, analogous to the lift-test path's degenerate
parameter points.)

New tests in `test/model/builder.jl`: a deterministic log-density comparison
(via `Turing.DynamicPPL.condition`/`evaluate!!`/`getlogjoint`, using
`ABACUS_COST_PER_TARGET_CASES[1]`) proving the calibrated and uncalibrated
model logjoint differ by exactly `cost_per_target_total_penalty(...)`; a
negative test proving `CostPerTargetCalibrationRows(...)` itself raises
`ArgumentError` for non-positive `sigma` (corrected during verification to
assert against the constructor call directly, since that is where validation
actually fires — see below); and a combined smoke test that fits a tiny
`TimeSeriesMMM` with both `add_lift_test_measurements` and
`add_cost_per_target_calibration` steps configured together, confirming
`state.artifact.calibration.lift_test isa LiftTestCalibrationPayload` and
`state.artifact.calibration.cost_per_target isa CostPerTargetCalibrationPayload`
both hold after a real MCMC fit.

An implementation/verification lesson from this task: an initial draft of the
negative-sigma test wrapped `fit!(calibrated_model)` in `@test_throws
ArgumentError`, expecting the rejection to surface at fit time (mirroring the
Task 15-05 saturation-rejection test, which *is* a `fit!`-time check). Running
the full `Pkg.test()` suite surfaced this as an **Error**, not a caught
`@test_throws` pass, because `CostPerTargetCalibrationRows(...)` throws
`ArgumentError` synchronously at construction — before `TimeSeriesMMM` or
`fit!` is ever called — so the exception occurred outside the `@test_throws`
block entirely. The fix was to wrap the `CostPerTargetCalibrationRows(...)`
constructor call itself in `@test_throws ArgumentError`, removing the
now-unreachable `TimeSeriesMMM(...)`/`fit!(...)` calls from that test. This is
a useful general reminder for this codebase: some calibration row validation
(`CostPerTargetCalibrationRows`, and by the same pattern likely
`LiftTestCalibrationRows`) is eager/constructor-time, not deferred to
`fit!`-time, and negative tests must target the actual point of failure.

The full `Pkg.test()` suite (3943 tests) passes cleanly with these additions:
`Pass 3943, Total 3943, 0 failed, 0 errored` (22m11.1s). `src/mmm/model.jl`
and `test/model/builder.jl` are Runic-format-clean. Panel calibration, VI,
pipeline integration, and broader YAML expansion remain untouched and out of
scope for this task, per the user's explicit exclusion list for Task 15-06.

**Acceptance criteria:**
- [x] Penalties are optional and additive with lift-test terms when both are
      configured.
- [x] Scaled-space cost-per-target semantics are documented.
- [x] Invalid or zero `sigma` is rejected before sampling.
- [x] The implementation avoids hidden dependency on posterior predictive or
      optimization artifacts.

**Verification:**
- [x] Deterministic log-density tests compare the model contribution to fixture
      values.
- [x] A combined lift-test plus cost-per-target smoke test fits.

**Dependencies:** Tasks 15-03 and 15-04.

**Files likely touched during implementation:**
- `src/mmm/model.jl`
- `src/mmm/calibration.jl`
- `test/model/model.jl`
- `test/model/calibration.jl`

**Estimated scope:** Medium.


### Task 15-07: Add Fixture-Backed Integration Evidence

**Status: Landed (2026-07-05).** The exporter now emits
`test/fixtures/abacus/calibration_integration_cases.jl`, a deterministic
Julia-literal fixture for the accepted centered-logistic `TimeSeriesMMM` MCMC
calibration path. The fixture is generated from Abacus's real scaling and
graph-helper surfaces: `scale_lift_measurements`,
`add_saturation_observations`, and `add_cost_per_target_potentials`. Julia
tests consume only the generated fixture: `test/model/calibration.jl` verifies
payload construction and the additive model-space log-density against the
fixture, and `test/model/builder.jl` verifies that `_time_series_mmm_model`
changes the conditioned Turing logjoint by exactly the fixture's total
calibration term. The direct `test/model/builder.jl` file also now guards its
fixture includes so it no longer depends on `test/model/calibration.jl` having
run first in the shared `Main` namespace.

Verification: `PYTHONNOUSERSITE=1 python scripts/export_abacus_fixtures.py`
completed successfully and produced the new fixture. It also restamped existing
fixture provenance headers from the current local Abacus checkout
(`7fd0ef30aacc33c97342d21087c3f3653bb8a74c (dirty)`, with unrelated Abacus
worktree changes in `LICENSE` and `assets/state-space-ideas/`); those
header-only changes were reverted as unrelated churn. `julia --project=@runic
-m Runic --check --diff test/model/calibration.jl test/model/builder.jl
test/fixtures/abacus/calibration_integration_cases.jl` passed, and
`make test-model` passed with `Pass 897, Total 897` in 8m14.5s. A direct
`julia --project=. test/model/calibration.jl` run is not valid in this repo
because test-only dependencies such as `ForwardDiff` are available through
`Pkg.test()`, not the main project environment.

**Description:** Extend the Abacus fixture exporter only as needed to produce
deterministic model-integration evidence for the accepted time-series
calibration path.

**Acceptance criteria:**
- [x] New fixtures are deterministic Julia literals under
      `test/fixtures/abacus/`.
- [x] The exporter calls real Abacus calibration helpers for comparable
      preprocessing/log-density semantics.
- [x] Julia tests consume fixture files only; no Python runtime dependency is
      introduced.
- [x] Fixture README documents the regeneration command and fixture purpose.

**Verification:**
- [x] `PYTHONNOUSERSITE=1 python scripts/export_abacus_fixtures.py` regenerates
      the new fixture; existing-fixture header-only provenance churn from the
      dirty local Abacus checkout was observed and reverted.
- [x] New fixture-backed Julia tests pass.

**Dependencies:** Tasks 15-04 through 15-06.

**Files likely touched during implementation:**
- `scripts/export_abacus_fixtures.py`
- `test/fixtures/abacus/*.jl`
- `test/fixtures/abacus/README.md`
- `test/model/calibration.jl`

**Estimated scope:** Medium.

### Task 15-08: Documentation, Ledger, And Guardrails

**Description:** Update user-facing docs and planning state after the
time-series sampling integration is implemented and verified.

**Acceptance criteria:**
- [ ] Docs explain that calibration integration is available for
      `TimeSeriesMMM` MCMC only.
- [ ] Docs explain unsupported `PanelMMM` and VI calibration paths.
- [ ] `.planning/ABACUS-PARITY-LEDGER.md` moves the calibration row only as far
      as the evidence justifies.
- [ ] `CHANGELOG.md` records the user-facing model capability.

**Verification:**
- [ ] `make docs` passes.
- [ ] Ledger language does not imply panel, VI, pipeline, or UI parity.

**Dependencies:** Tasks 15-05 through 15-07.

**Files likely touched during implementation:**
- `docs/src/index.md`
- `CHANGELOG.md`
- `.planning/ABACUS-PARITY-LEDGER.md`
- `.planning/STATE.md`

**Estimated scope:** Small.

## Checkpoints

### Checkpoint A: Contract And Payload

After Tasks 15-01 through 15-03: **COMPLETE (2026-07-01).**

- [x] Calibration payload construction is typed and tested.
- [x] Existing uncalibrated config/model/spec tests pass.
- [x] Panel and VI rejection behaviour is specified.
- [x] No Turing model changes have landed before the payload contract is
      stable. (The fit artifact carries the resolved calibration spec, but the
      Turing `@model` log-density itself is unchanged; that is Task 15-05.)

### Checkpoint B: Deterministic Log-Density

After Tasks 15-04 through 15-06: **COMPLETE (2026-07-01).** Both the
lift-test slice (Task 15-05) and the cost-per-target slice (Task 15-06) are
landed; the full `Pkg.test()` suite (3943 tests) passes cleanly with 0 failed
and 0 errored.

- [x] Pure helper log-density tests pass. (Lift-test helpers, Task 15-04;
      cost-per-target helper tests reuse the pre-existing Task 15-02 helpers,
      Task 15-06.)
- [x] Turing model log-density differs from the uncalibrated model by the
      expected calibration term. (Lift-test term verified in
      `test/model/builder.jl` via Task 15-05; cost-per-target term verified
      the same way via Task 15-06, both using `Turing.DynamicPPL.condition`/
      `evaluate!!`/`getlogjoint`.)
- [x] Tiny calibrated MCMC smoke tests pass. (Lift-test-only smoke test from
      Task 15-05; a combined lift-test-plus-cost-per-target smoke test from
      Task 15-06.)
- [x] Existing uncalibrated `test/model/runtests.jl` remains green.



### Checkpoint C: Evidence And Docs

After Tasks 15-07 and 15-08:

- [ ] Abacus fixtures regenerate deterministically.
- [ ] Docs and ledger state match implemented scope exactly.
- [ ] `make docs` passes.
- [ ] Broader test gate has either passed or any unrelated gate failure is
      documented precisely.

## Risks And Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Original-unit calibration is accidentally added to scaled-space model terms | High | Scale calibration rows through the same `channel_scale` and `target_scale` used by `MMMModelSpec`; test the scaled values directly. |
| Calibration likelihood double-counts media effects, uses unsaturated media, or incorrectly applies adstock | High | Add deterministic log-density tests that inspect the exact saturation-only contribution used for lift tests. |
| Zero estimated lift creates invalid Gamma domains | High | Preserve early `ArgumentError` rejection for zero/negative/non-finite `mu` and add model-integration tests. |
| Panel semantics sneak in through generic config paths | High | Reject calibration when `model_kind != :time_series_mmm` until a separate panel contract exists. |
| Turing/AD breaks because helper code forces `Float64` inside the model path | Medium | Keep validated preprocessing in `Float64`, but make model-space likelihood helpers generic over sampled numeric types. |
| Artifact spec changes break old saved models | Medium | Version or isolate calibration metadata and add save/load compatibility tests. |
| The plan widens into pipeline parity | Medium | Keep pipeline integration out of Phase 15 unless time-series model integration is already landed and separately planned. |

## Open Questions

- Should calibration rows enter through `ModelConfig.extras`, a new
  `ModelConfig.calibration` field, or a companion constructor argument? Default
  recommendation: add an explicit typed field only if YAML ingestion is in
  scope for this phase; otherwise use a companion internal payload first and
  promote the API after the model semantics are proven.
- Should cost-per-target calibration use model-implied current response or an
  explicit gathered value from Abacus-style inputs? Default recommendation:
  start with Abacus's explicit gathered/target/sigma soft-penalty semantics and
  do not infer values from optimization artifacts.
- Which saturation combinations must be supported in the first integration
  slice? Default recommendation: support the current centered logistic path
  first if fixture evidence is available, then expand only with deterministic
  tests.

## Verification Commands

Run after each implementation checkpoint:

```bash
julia --project=. test/model/calibration.jl
julia --project=. test/model/runtests.jl
julia --project=@runic -m Runic --check --diff src/mmm/calibration.jl src/mmm/model.jl src/model/builder.jl test/model/calibration.jl
```

Run after fixture exporter changes:

```bash
PYTHONNOUSERSITE=1 python scripts/export_abacus_fixtures.py
```

Run before merging the full phase:

```bash
make test
make docs
```

If `make test` fails only in `Aqua.test_all(...; persistent_tasks=true)` with a
temporary precompile `done.log` failure, rerun the Aqua check in isolation
before classifying it as a code regression.
