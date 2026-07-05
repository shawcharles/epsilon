# Phase 17: Calibration YAML And Pipeline Integration

## Status

Tasks 17-01 and 17-02 are landed. Tasks 17-03 and 17-04 remain.

## Goal

Expose the already-landed bounded `TimeSeriesMMM` MCMC calibration likelihood
surface through public YAML/config and pipeline boundaries without changing the
calibration maths, adding panel support, adding VI support, or widening into
Dash/UI workflows.

## Boundary

In scope:

- Public dict/YAML parsing for calibration steps and row data.
- `TimeSeriesMMM` MCMC construction from parsed calibration payloads.
- Pipeline acceptance of bounded calibration YAML for time-series MCMC runs.
- Explicit rejection of unsupported calibration combinations.
- Documentation, changelog, and ledger guardrails.

Out of scope:

- New calibration likelihood maths.
- `PanelMMM` calibration.
- VI calibration.
- Non-logistic lift-test calibration.
- Dash/UI, AI advisor, or hosted calibration workflows.
- Automatic generation of calibration rows from lift-test artifacts.

## Architecture Decisions

- YAML calibration parsing must produce the same `TimeSeriesCalibrationInput`
  object used by the programmatic `TimeSeriesMMM` constructor.
- Parsed calibration should remain companion model-construction payload, not a
  new field on `MMMModelSpec`.
- Pipeline integration must consume existing parsed payloads and pass them to
  `TimeSeriesMMM`; it must not infer calibration from optimisation,
  posterior-predictive, or pipeline artifacts.
- Unsupported combinations should fail before sampling starts.

## Task 17-01: Parse Calibration Blocks Into Typed Payloads

**Description:** Add bounded public config parsing for a top-level
`calibration` YAML/dict block and store the typed `TimeSeriesCalibrationInput`
in `ModelConfig.extras["calibration"]`. This task does not wire pipeline model
construction yet.

**Acceptance criteria:**

- [x] `model_config_from_dict` and `load_public_config` parse valid lift-test
      and cost-per-target calibration blocks into `TimeSeriesCalibrationInput`.
- [x] Parsed row data is identical to the existing programmatic row
      constructors.
- [x] `params.dist`, malformed rows, repeated/missing steps, panel configs, and
      VI-like fit backends fail closed.
- [x] Existing uncalibrated configs remain unchanged.

**Verification:**

- [x] `JULIA_PKG_SERVER_REGISTRY_PREFERENCE=eager julia --project=. -e 'using Pkg; Pkg.test(; test_args=["model"])'`
- [x] Targeted Runic check on touched Julia files.

**Dependencies:** Phase 15 calibration payloads.

**Status:** Landed. Public dict/YAML parsing now accepts a bounded top-level
`calibration` block and stores the typed `TimeSeriesCalibrationInput` in
`ModelConfig.extras["calibration"]`. The parser validates step shape, rejects
unsupported step params and repeated methods, rejects panel and VI-like
calibration configs, coerces YAML row vectors to the same concrete row types
used by programmatic constructors, and leaves uncalibrated configs unchanged.
This task intentionally does not wire parsed calibration into pipeline fitting.

## Task 17-02: Thread Parsed Calibration Into Time-Series Model Construction

**Description:** Add a narrow construction helper so callers that build a
`TimeSeriesMMM` from `ModelConfig` can pass the parsed calibration input without
duplicating row extraction logic.

**Acceptance criteria:**

- [x] Parsed calibration reaches `TimeSeriesMMM.calibration` unchanged.
- [x] Panel construction rejects parsed calibration explicitly.
- [x] Existing programmatic calibration constructor arguments remain
      compatible.

**Verification:**

- [x] Targeted model builder tests.
- [x] Targeted Runic check on touched Julia files.

**Dependencies:** Task 17-01.

**Status:** Landed. `TimeSeriesMMM` now consumes a parsed
`TimeSeriesCalibrationInput` from `ModelConfig.extras["calibration"]` when
constructor calibration keywords are absent. Supplying both parsed calibration
and constructor calibration keywords raises an explicit `ArgumentError` instead
of silently choosing one source. `PanelMMM` rejects parsed calibration from
`ModelConfig.extras` explicitly. Programmatic time-series constructor
calibration arguments remain supported.

## Task 17-03: Pipeline Acceptance And Fit Smoke

**Description:** Allow bounded time-series MCMC pipeline YAML to include the
parsed calibration block and pass it into model construction. Keep pipeline
validation strict for unsupported calibration shapes.

**Acceptance criteria:**

- [ ] Pipeline top-level allowlist accepts `calibration`.
- [ ] Time-series MCMC pipeline model construction receives parsed calibration.
- [ ] Pipeline rejects panel calibration and VI-like calibration before fit.
- [ ] A tiny calibrated pipeline smoke test proves the artifact contains a
      resolved `MMMCalibrationSpec`.

**Verification:**

- [ ] Targeted pipeline config/run tests.
- [ ] Targeted model calibration tests as needed.

**Dependencies:** Tasks 17-01 and 17-02.

## Task 17-04: Docs, Changelog, And Ledger Guardrails

**Description:** Update user-facing docs, changelog, and the parity ledger to
record the bounded YAML/pipeline calibration surface without moving the broad
calibration row beyond `scaffolded`.

**Acceptance criteria:**

- [ ] Docs show the supported YAML shape and unsupported paths.
- [ ] Changelog records the capability without implying panel/VI/UI support.
- [ ] Ledger remains conservative and explicitly names remaining unsupported
      calibration surfaces.

**Verification:**

- [ ] `make docs`
- [ ] Targeted model/pipeline tests from the closed slice.

**Dependencies:** Tasks 17-01 through 17-03.

## Risks And Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| YAML path diverges from programmatic path | High | Parse directly into existing `TimeSeriesCalibrationInput`. |
| Pipeline silently drops calibration | High | Add explicit pipeline tests that inspect fit artifacts. |
| Panel/VI calibration sneaks in | Medium | Reject unsupported combinations before sampling. |
| Broad Abacus calibration parity is overclaimed | Medium | Keep ledger status `scaffolded` until panel, VI, YAML breadth, and UI paths have separate evidence. |
