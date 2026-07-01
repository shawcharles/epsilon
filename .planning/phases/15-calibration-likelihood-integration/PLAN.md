# Phase 15: Calibration Likelihood Integration

## Status

Planned 2026-07-01. Implementation has not started.

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

**Acceptance criteria:**
- [ ] The accepted config/data shape is documented in this plan or a linked
      planning note before implementation.
- [ ] `TimeSeriesMMM` is the only accepted model target.
- [ ] Panel and VI behaviour is specified as explicit rejection, not future
      implicit support.
- [ ] Supported step methods are limited to
      `add_lift_test_measurements` and `add_cost_per_target_calibration`.

**Verification:**
- [ ] Review against `.planning/ABACUS-PARITY-LEDGER.md`.
- [ ] Confirm no release-facing docs claim calibration model parity yet.

**Dependencies:** None.

**Files likely touched during implementation:**
- `.planning/ABACUS-PARITY-LEDGER.md`
- `docs/src/index.md`
- `src/mmm/calibration.jl`
- `src/model/types.jl`

**Estimated scope:** Small.

### Task 15-02: Add Typed Calibration Payloads

**Description:** Add internal typed payloads that represent validated,
row-aligned, scaled calibration observations ready for the model runtime.

**Acceptance criteria:**
- [ ] Lift-test payloads carry channel index, scaled `x`, scaled `delta_x`,
      scaled `delta_y`, and scaled positive `sigma`.
- [ ] Cost-per-target payloads carry scaled gathered/current cost-per-target,
      scaled target cost-per-target, and positive `sigma`.
- [ ] Payload constructors reuse the existing helper functions in
      `src/mmm/calibration.jl`.
- [ ] Unsupported or malformed payloads fail with clear `ArgumentError`s.

**Verification:**
- [ ] Focused unit tests cover valid payload construction and rejection cases.
- [ ] Existing `test/model/calibration.jl` fixture-backed helper tests still
      pass unchanged except for intentional additions.

**Dependencies:** Task 15-01.

**Files likely touched during implementation:**
- `src/mmm/calibration.jl`
- `test/model/calibration.jl`

**Estimated scope:** Medium.

### Task 15-03: Thread Calibration Through Config And Spec Boundaries

**Description:** Decide and implement how calibration steps enter the typed
time-series model path, then carry resolved calibration metadata through the
model spec/runtime boundary.

**Acceptance criteria:**
- [ ] `ModelConfig` or a narrowly scoped companion payload can represent the
      calibration steps without weakening existing config validation.
- [ ] `_build_model_spec(config, data::MMMData)` can preserve the resolved
      calibration metadata needed for fitting.
- [ ] `_build_model_spec(spec, new_data::MMMData)` either preserves or rejects
      calibration metadata according to the prediction/replay contract.
- [ ] Existing serialized model/result artifacts remain backwards compatible,
      or any format change is versioned and tested.

**Verification:**
- [ ] Config/model-spec equality tests cover calibration metadata.
- [ ] Save/load tests confirm old uncalibrated artifacts still load.
- [ ] Negative tests prove panel specs reject calibration metadata for now.

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

**Acceptance criteria:**
- [ ] Lift-test log-density helpers accept the channel-specific scaled values
      needed for `x` and `x + delta_x`.
- [ ] Cost-per-target helpers return scalar penalties matching the existing
      pure helper semantics.
- [ ] Helpers are generic enough for AD-compatible number types where they sit
      on the Turing path.
- [ ] Domain checks remain outside hot AD loops where possible and do not
      mutate model inputs.

**Verification:**
- [ ] Deterministic tests compare helper outputs to existing Abacus fixtures.
- [ ] Tests cover zero estimated lift, non-finite inputs, and incompatible
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

**Acceptance criteria:**
- [ ] Uncalibrated runtime payloads produce byte-for-byte equivalent model
      construction behaviour at the public API level.
- [ ] Calibrated runtime payloads add a scalar log-probability contribution via
      `Turing.@addlogprob!`.
- [ ] The lift-test path uses the same sampled saturation parameters as the
      media contribution path.
- [ ] Unsupported saturation combinations are either implemented correctly or
      rejected before sampling.
- [ ] Adstock is not applied to lift-test rows unless a later fixture-backed
      design explicitly changes the calibration contract.

**Verification:**
- [ ] A deterministic log-density test proves calibrated and uncalibrated
      models differ exactly by the expected fixture-backed calibration term.
- [ ] A tiny MCMC smoke test fits a calibrated `TimeSeriesMMM`.
- [ ] Existing uncalibrated model tests still pass.

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

**Acceptance criteria:**
- [ ] Penalties are optional and additive with lift-test terms when both are
      configured.
- [ ] Scaled-space cost-per-target semantics are documented.
- [ ] Invalid or zero `sigma` is rejected before sampling.
- [ ] The implementation avoids hidden dependency on posterior predictive or
      optimization artifacts.

**Verification:**
- [ ] Deterministic log-density tests compare the model contribution to fixture
      values.
- [ ] A combined lift-test plus cost-per-target smoke test fits.

**Dependencies:** Tasks 15-03 and 15-04.

**Files likely touched during implementation:**
- `src/mmm/model.jl`
- `src/mmm/calibration.jl`
- `test/model/model.jl`
- `test/model/calibration.jl`

**Estimated scope:** Medium.

### Task 15-07: Add Fixture-Backed Integration Evidence

**Description:** Extend the Abacus fixture exporter only as needed to produce
deterministic model-integration evidence for the accepted time-series
calibration path.

**Acceptance criteria:**
- [ ] New fixtures are deterministic Julia literals under
      `test/fixtures/abacus/`.
- [ ] The exporter calls real Abacus calibration helpers for comparable
      preprocessing/log-density semantics.
- [ ] Julia tests consume fixture files only; no Python runtime dependency is
      introduced.
- [ ] Fixture README documents the regeneration command and fixture purpose.

**Verification:**
- [ ] `PYTHONNOUSERSITE=1 python scripts/export_abacus_fixtures.py` regenerates
      fixtures without unrelated churn.
- [ ] New fixture-backed Julia tests pass.

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

After Tasks 15-01 through 15-03:

- [ ] Calibration payload construction is typed and tested.
- [ ] Existing uncalibrated config/model/spec tests pass.
- [ ] Panel and VI rejection behaviour is specified.
- [ ] No Turing model changes have landed before the payload contract is stable.

### Checkpoint B: Deterministic Log-Density

After Tasks 15-04 through 15-06:

- [ ] Pure helper log-density tests pass.
- [ ] Turing model log-density differs from the uncalibrated model by the
      expected calibration term.
- [ ] Tiny calibrated MCMC smoke tests pass.
- [ ] Existing uncalibrated `test/model/runtests.jl` remains green.

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
