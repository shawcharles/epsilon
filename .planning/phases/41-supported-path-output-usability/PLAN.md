# Phase 41: Supported-Path Output Usability Audit

**Status:** Landed.
**Created:** 2026-07-18
**Owner:** Epsilon maintainers

## Objective

Audit and lightly harden the outputs produced by the two supported local MCMC
example paths:

- `examples/toy_mmm/run_toy_mmm.jl`
- `examples/csv_mmm/run_csv_mmm.jl`

Phase 39 proved both paths run through the supported Turing/NUTS MCMC backend.
Phase 41 checks the next practical question: when a user supplies
`--output-dir`, are the resulting `run_summary.txt`, `contribution_summary.csv`,
and `metric_summary.csv` clear, stable, and tested enough to be useful without
reading source code?

This phase must improve supported-path usability without widening Epsilon's
model, inference, ingestion, pipeline, benchmark, release, dashboard/UI,
Abacus-parity, HSGP/TVP, or panel support surface.

## Reference Boundary

Primary files:

- `examples/toy_mmm/run_toy_mmm.jl`
- `examples/toy_mmm/README.md`
- `examples/csv_mmm/run_csv_mmm.jl`
- `examples/csv_mmm/README.md`
- `test/examples/toy_mcmc_smoke.jl`
- `test/examples/csv_mmm_quickstart.jl`
- `scripts/smoke_supported_paths.sh`

Root `README.md` and release documentation are out of scope unless a direct
current-facing contradiction is discovered during the audit.

Planning/state files:

- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- this plan

## In Scope

- Run each existing example with tiny settings and an isolated temporary output
  directory.
- Inspect the generated text and CSV sidecars manually.
- Add focused tests for the example output contract where current tests only
  assert "file exists and is non-empty".
- Improve example output labels or README wording if the audit finds unclear
  or misleading fields.
- Keep both examples small, local, deterministic by seed, and suitable for the
  existing `make smoke` command.
- Update planning state when the phase closes.

## Out of Scope

- No full test suite, `make check-full`, benchmark run, benchmark-result update,
  release branch, release tag, package registration, or release-readiness claim.
- No source changes under `src/`.
- No dependency or manifest changes.
- No new data ingestion API, pipeline stage, scenario-store path, dashboard/UI,
  report generator, or plotting surface.
- No model, prior, sampler, posterior, contribution, metric, optimization,
  calibration, HSGP/TVP, or panel semantics changes.
- No Abacus parity status promotion.

## Tasks

### 41-01: Reviewed Output-Usability Contract

- [x] Write this phase plan before implementation.
- [x] Add only minimal roadmap/state hooks needed to identify Phase 41 as the
      active planning slice.
- [x] Send the plan to an independent review agent.
- [x] Resolve every Must Fix from review before implementation begins.

### 41-02: Inspect Current Example Outputs

- [x] Run the toy example with tiny settings and a temporary output directory.
- [x] Run the CSV example with tiny settings and a temporary output directory.
- [x] Inspect `run_summary.txt`, `contribution_summary.csv`, and
      `metric_summary.csv` for both examples.
- [x] Record any unclear, unstable, misleading, or untested output fields in this
      plan before changing files.

### 41-03: Harden The Output Contract

- [x] Add focused assertions for the stable `run_summary.txt` keys produced by
      both examples.
- [x] Add focused assertions for expected CSV column presence and row counts for
      both examples' `contribution_summary.csv` and `metric_summary.csv`.
- [x] If needed, make small example-output or README wording improvements that
      clarify existing outputs without changing the modelling path.
- [x] Keep output filenames unchanged.

### 41-04: Closure And State Update

- [x] Run only the two focused example test files and lightweight formatting /
      manifest checks.
- [x] Update this plan with landed status, audit notes, and verification
      evidence.
- [x] Update `.planning/ROADMAP.md` and `.planning/STATE.md` to record Phase 41
      closure.
- [x] Commit and push the bounded slice.

## Acceptance Criteria

- The toy and CSV examples still run with tiny settings and write the same three
  output filenames when `--output-dir` is supplied.
- Tests verify the content contract, not merely that output files are non-empty.
- `examples/toy_mmm/README.md` and `examples/csv_mmm/README.md` accurately
  explain the stable output sidecars and keep the examples framed as local
  supported-path examples only.
- Tests assert stable structure, keys, columns, row counts, and settings only;
  they do not assert exact posterior numeric values from tiny chains.
- No runtime package source, dependencies, manifests, benchmark outputs, release
  artefacts, parity-status rows, or broad docs are changed unless a direct
  wording contradiction is found.
- No full suite is run for this phase.

## Verification

Use scoped checks only:

```bash
TOY_OUT=$(mktemp -d)
CSV_OUT=$(mktemp -d)
julia --project=. examples/toy_mmm/run_toy_mmm.jl --draws 8 --tune 8 --output-dir "$TOY_OUT"
julia --project=. examples/csv_mmm/run_csv_mmm.jl --draws 8 --tune 8 --output-dir "$CSV_OUT"
make test-file FILE=test/examples/toy_mcmc_smoke.jl
make test-file FILE=test/examples/csv_mmm_quickstart.jl
make format-check-touched
git diff --check
test -z "$(git diff --name-only -- src Project.toml Manifest.toml docs/Manifest.toml benchmark)"
git status --short
```

If the package-test focused harness is unavailable for some reason, direct
commands may be used as a fallback:

```bash
julia --project=. test/examples/toy_mcmc_smoke.jl
julia --project=. test/examples/csv_mmm_quickstart.jl
```

Do not run `make test`, `Pkg.test()`, `make check-full`, or benchmark commands.

## Risks

- **Output overreach:** Adding rich reports would turn a smoke/quickstart path
  into a reporting feature. Keep the contract compact.
- **False release signal:** These outputs can be useful without becoming release
  evidence, benchmark evidence, or Abacus parity evidence.
- **MCMC variance:** Tests should assert stable structure and settings, not
  exact posterior values from tiny chains.
- **Scope creep into ingestion:** The CSV quickstart remains exact-schema only;
  do not generalise it into a data-loading API.

## Review Notes

- Independent plan review found three Must Fix items: remove broad root/release
  docs from the primary file set, specify example READMEs in the acceptance
  criteria, and fix the temporary-directory verification snippet. It also
  recommended preferring `make test-file` and explicitly forbidding exact tiny
  posterior numeric assertions. All points are resolved before implementation.
- Independent implementation review found one Must Fix: the final closure
  checkbox was still unchecked while the plan and state had been marked landed.
  It also recommended exact summary-key assertions and a clearer split between
  Phase 41 and Phase 40 status text. All points are resolved before commit.

## Audit Notes

- Current example outputs are already compact and usable: both examples write
  `run_summary.txt`, `contribution_summary.csv`, and `metric_summary.csv` when
  `--output-dir` is supplied.
- The audit found no need to change model output values, filenames, or example
  CLI behavior.
- The actual gap was test coverage: existing focused tests asserted only that
  sidecar files existed and were non-empty. Phase 41 now asserts stable summary
  keys/settings, CSV headers, row counts, contribution components, and metric
  labels without asserting exact posterior numeric values.
- Example READMEs now document the stable `key=value` summary lines and compact
  CSV columns.

## Verification Evidence

- Manual tiny example inspection:
  `julia --project=. examples/toy_mmm/run_toy_mmm.jl --draws 8 --tune 8 --output-dir "$TOY_OUT"`.
- Manual tiny example inspection:
  `julia --project=. examples/csv_mmm/run_csv_mmm.jl --draws 8 --tune 8 --output-dir "$CSV_OUT"`.
- `make test-file FILE=test/examples/toy_mcmc_smoke.jl` passed:
  `109 / 109` assertions in `1m32.4s`.
- `make test-file FILE=test/examples/csv_mmm_quickstart.jl` passed:
  `132 / 132` assertions in `1m15.2s`.
- `make format-check-touched` passed.
- `git diff --check` passed.
- Planning/source-boundary guard passed:
  no changes under `src`, `Project.toml`, `Manifest.toml`,
  `docs/Manifest.toml`, or `benchmark`.
