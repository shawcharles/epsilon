# Phase 39: Supported-Path Smoke Certification

## Status

Landed. The implementation plan passed independent review before code changes.
The slice stayed deliberately small: it certifies the documented toy and
fixed-schema CSV MCMC paths after Phase 38 retired VI, without adding a
benchmark, release claim, new ingestion API, or wider model support. Scoped
verification passed with `bash -n scripts/smoke_supported_paths.sh`,
`make smoke`, `make test-file FILE=test/examples/toy_mcmc_smoke.jl`
(`92 / 92`), and
`make test-file FILE=test/examples/csv_mmm_quickstart.jl` (`114 / 114`).

## Objective

Give maintainers one local, fast, user-facing smoke command that checks the
currently supported front door still works: the synthetic toy `TimeSeriesMMM`
MCMC example and the fixed-schema CSV quickstart both fit through the supported
Turing/NUTS path and write the compact summaries documented in the README.

This is a usability and support-boundary certification phase. It is not Abacus
parity evidence, not benchmark evidence, not release preparation, and not a
new statistical feature.

## In Scope

- Add a local smoke harness for the already-supported toy and CSV quickstart
  scripts.
- Add a Makefile target that runs that harness with tiny draw/tune settings and
  temporary output directories.
- Check that both documented commands complete, produce non-empty compact
  summary artifacts, and report `status=fit` plus `backend=turing`.
- Update README/docs/planning/changelog wording so the smoke command is visible
  as a supported-path check, while preserving the non-benchmark/non-parity
  boundary.
- Run only scoped verification appropriate to this slice.

## Explicit Exclusions

- No runtime modelling changes.
- No public API additions or exports.
- No dependency changes.
- No benchmarks or timing claims.
- No release-readiness claim.
- No Abacus parity claim.
- No general CSV ingestion API.
- No pipeline integration.
- No panel, HSGP/TVP, calibration, optimisation, scenario-planner, dashboard,
  AI-advisor, or VI work.
- No full test suite unless an implementation change unexpectedly touches
  shared Julia runtime/test namespace behaviour.

## Architecture

1. **Smoke harness.** Add a shell harness under `scripts/` that runs:
   `examples/toy_mmm/run_toy_mmm.jl` and
   `examples/csv_mmm/run_csv_mmm.jl` with small draw/tune counts and isolated
   `mktemp -d` output directories. The harness should fail closed on command
   errors or missing/non-empty output checks.
2. **Make target.** Add a `make smoke` target that delegates to the harness.
   Keep knobs simple and local: respect `JULIA`, and allow optional `DRAWS`,
   `TUNE`, and `SEED` overrides only if they do not complicate the contract.
3. **Documentation.** Update README and planning state to identify `make smoke`
   as the fastest supported-path check. Keep the language precise: smoke
   certification, not benchmark or parity certification.
4. **Verification.** Verify the harness itself and keep existing focused Julia
   example tests as the behavioural coverage for the two scripts.

## Tasks

### Task 39-01: Reviewed Smoke Contract

**Description:** Freeze the supported-path smoke boundary before
implementation.

**Acceptance Criteria:**

- [x] Plan states that Phase 39 is smoke certification only.
- [x] Plan explicitly excludes benchmarks, release claims, parity claims, and
      new modelling/API surface.
- [x] Independent plan review approves the contract before implementation.

**Verification:**

- [x] Plan review returns `APPROVE` or all Must Fix findings are resolved.

### Task 39-02: Local Smoke Harness

**Description:** Add a local script plus Makefile target for the two supported
example paths.

**Acceptance Criteria:**

- [x] `make smoke` runs the toy MCMC script and the CSV quickstart script.
- [x] Each run writes into a temporary directory and leaves no repo-local result
      artifacts.
- [x] The harness checks non-empty `contribution_summary.csv`,
      `metric_summary.csv`, and `run_summary.txt` for both paths.
- [x] The harness checks `run_summary.txt` contains `status=fit` and
      `backend=turing`.

**Verification:**

- [x] `bash -n scripts/smoke_supported_paths.sh`
- [x] `make smoke`

### Task 39-03: Supported-Path Documentation

**Description:** Make the smoke command visible without overclaiming.

**Acceptance Criteria:**

- [x] README points users to `make smoke` as the fastest combined supported-path
      check.
- [x] Changelog records the local smoke harness.
- [x] `.planning/STATE.md` and `.planning/ROADMAP.md` describe Phase 39 without
      changing parity-ledger statuses.

**Verification:**

- [x] `rg -n "smoke|benchmark|parity|release" README.md .planning/STATE.md .planning/ROADMAP.md CHANGELOG.md`
      shows no new overclaiming language.

### Task 39-04: Scoped Closure

**Description:** Close the phase with scoped checks only.

**Acceptance Criteria:**

- [x] Existing focused toy and CSV example tests still pass.
- [x] Formatting/diff hygiene passes.
- [x] No dependency manifests changed.
- [x] No full suite is run because the implementation did not touch shared Julia
      runtime/test namespace behaviour.

**Verification:**

- [x] `make test-file FILE=test/examples/toy_mcmc_smoke.jl`
- [x] `make test-file FILE=test/examples/csv_mmm_quickstart.jl`
- [x] `make format-check-touched`
- [x] `git diff --check`
- [x] `test -z "$(git diff --name-only -- Project.toml Manifest.toml docs/Manifest.toml)"`

## Risks And Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Smoke harness becomes a benchmark by accident | Misleading maturity signal | Do not print or record timing; describe it only as a supported-path smoke check |
| Harness writes generated outputs into the repo | Dirty worktree and confusing artifacts | Always use temporary directories and verify no repo-local output contract |
| Documentation overclaims release or parity evidence | Recreates earlier claim-hygiene problem | Use explicit "not benchmark, not release evidence, not Abacus parity" wording |
| Full-suite habit creeps back into a small slice | Slow iteration for little signal | Use focused example tests and script checks only unless shared Julia code changes |
