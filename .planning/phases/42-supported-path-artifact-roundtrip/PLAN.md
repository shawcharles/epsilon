# Phase 42: Supported-Path Artifact Roundtrip Audit

**Status:** Landed.
**Created:** 2026-07-18
**Owner:** Epsilon maintainers

## Objective

Prove that the two supported local MCMC example paths can be persisted and
reloaded with Epsilon's existing trusted-local artifact APIs:

- `examples/toy_mmm/run_toy_mmm.jl`
- `examples/csv_mmm/run_csv_mmm.jl`

Phase 39 proved both examples run. Phase 41 made their compact sidecar outputs
inspectable and structurally guarded. Phase 42 checks the next bounded maturity
question: after a tiny supported-path fit, can a caller save and reload the
returned fitted model and grouped inference results without losing the status,
backend, fitted spec, observed-data equality/dimensions, posterior draw count,
or ability to derive the same compact summary-table structure?

This phase uses existing `save_model`, `load_model`, `save_inference_results`,
and `load_inference_results` APIs. It must not introduce new persistence APIs,
new CLI flags, new artifact formats, release evidence, benchmark evidence, or
Abacus parity promotions.

## Reference Boundary

Primary files:

- `examples/toy_mmm/run_toy_mmm.jl`
- `examples/toy_mmm/README.md`
- `examples/csv_mmm/run_csv_mmm.jl`
- `examples/csv_mmm/README.md`
- `test/examples/toy_mcmc_smoke.jl`
- `test/examples/csv_mmm_quickstart.jl`

Existing API references:

- `src/model/io.jl`
- `src/inference/results.jl`
- `test/model/io.jl`
- `test/inference/results.jl`

Planning/state files:

- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- this plan

## In Scope

- Run each existing example with tiny settings.
- In the focused example tests, save and reload the returned fitted
  `TimeSeriesMMM` with `save_model` / `load_model`.
- In the focused example tests, save and reload the returned grouped
  `InferenceResults` with `save_inference_results` / `load_inference_results`.
- Assert stable, structure-level roundtrip properties:
  - loaded model type, fit status, backend, sampler settings, and channel names
  - loaded model ability to rebuild grouped inference results without prior or
    predictive groups
  - loaded grouped-results metadata, fitted spec, observed-data dimensions, and
    posterior draw count
  - contribution and metric summary table headers, row counts, components, and
    metric labels derived from loaded grouped results
- Update the example READMEs only to explain the existing trusted-local
  persistence workflow, if needed.
- Update planning state when the phase closes.

## Out of Scope

- No full test suite, `make check-full`, benchmark run, benchmark-result update,
  release branch, release tag, package registration, or release-readiness claim.
- No new CLI flags such as `--artifact-dir`.
- No new public API, artifact format, serialization backend, manifest format, or
  portability promise.
- No source changes under `src/`.
- No dependency or manifest changes.
- No model, prior, sampler, posterior, contribution, metric, optimization,
  calibration, HSGP/TVP, panel, pipeline, plotting, scenario, ingestion,
  dashboard/UI, or AI-advisor semantics changes.
- No root README, release docs, parity ledger, or Abacus parity status changes
  unless a direct current-facing contradiction is found.

## Tasks

### 42-01: Reviewed Roundtrip Contract

- [x] Write this phase plan before implementation.
- [x] Add only minimal roadmap/state hooks needed to identify Phase 42 as the
      active planning slice.
- [x] Send the plan to an independent review agent.
- [x] Resolve every Must Fix from review before implementation begins.

### 42-02: Inspect Existing Persistence Fit

- [x] Confirm the toy example return contract includes a fitted model and grouped
      inference results usable by existing persistence APIs.
- [x] Confirm the CSV example return contract includes a fitted model and grouped
      inference results usable by existing persistence APIs.
- [x] Confirm existing save/load APIs are trusted-local Julia serialization and
      should not be documented as portable interchange.
- [x] Record any implementation caveats in this plan before changing tests.

### 42-03: Add Focused Roundtrip Assertions

- [x] Add toy-example focused assertions for model roundtrip and grouped-results
      roundtrip.
- [x] Add CSV-example focused assertions for model roundtrip and grouped-results
      roundtrip.
- [x] Assert stable structure and dimensions only; do not assert exact posterior
      numeric values from tiny chains.
- [x] Assert loaded observed data equality, dimensions, and names where needed;
      do not assert object identity (`===`) across serialization boundaries.
- [x] Keep existing output filenames and CLI behavior unchanged.

### 42-04: Closure And State Update

- [x] Run only the two focused example test files and lightweight formatting /
      manifest checks.
- [x] Update this plan with landed status, audit notes, and verification
      evidence.
- [x] Update `.planning/ROADMAP.md` and `.planning/STATE.md` to record Phase 42
      closure.
- [x] Prepare the bounded slice for commit and push.

## Acceptance Criteria

- Both example functions still return their existing tuple shape and still write
  the Phase 41 sidecars when `--output-dir` is supplied.
- Focused tests prove that `save_model` / `load_model` preserves the supported
  fitted `TimeSeriesMMM` lifecycle for the toy and CSV examples.
- Focused tests prove that `save_inference_results` / `load_inference_results`
  preserves the grouped posterior/spec/observed-data structure for the toy and
  CSV examples.
- Tests assert stable metadata, dimensions, keys, headers, row counts, component
  labels, and metric labels only; no exact tiny-chain posterior values.
- Any README wording describes artifacts as trusted-local Julia serialization,
  not as portable release artifacts or interchange formats.
- No runtime package source, dependencies, manifests, benchmark outputs, release
  artefacts, parity-status rows, broad docs, or full suite changes.

## Verification

Use scoped checks only:

```bash
make test-file FILE=test/examples/toy_mcmc_smoke.jl
make test-file FILE=test/examples/csv_mmm_quickstart.jl
make format-check-touched
git diff --check
test -z "$(git diff --name-only -- src Project.toml Manifest.toml docs/Manifest.toml benchmark README.md docs/src/release.md .planning/ABACUS-PARITY-LEDGER.md scripts/smoke_supported_paths.sh)"
git status --short
```

Do not run `make test`, `Pkg.test()` without a focused file selector,
`make check-full`, or benchmark commands.

## Risks

- **Persistence overclaim:** Existing serialization is trusted-local Julia
  serialization, not a portable interchange format. Keep wording precise.
- **CLI surface creep:** Adding artifact-writing flags would turn examples into
  a new persistence feature. This phase only tests the existing returned objects
  with existing APIs.
- **MCMC variance:** Tests should assert structure and metadata, not sampled
  posterior values.
- **Duplicate low-level tests:** Existing model/results IO tests already cover
  API internals. Phase 42 should only add supported-path integration evidence.

## Review Notes

- Independent plan review found one Must Fix: `.planning/ROADMAP.md` listed
  Phase 42 in the main phase list and `.planning/STATE.md` marked 42 total
  phases, but the roadmap progress section still said phases execute through
  Phase 41 and lacked a Phase 42 row. It also recommended explicitly forbidding
  object-identity assertions after load. Both points are resolved before
  implementation.

## Implementation Audit Notes

- The landed test changes extend only `test/examples/toy_mcmc_smoke.jl` and
  `test/examples/csv_mmm_quickstart.jl`.
- The example functions still use their existing return contracts and optional
  compact sidecar output paths. No CLI flags, filenames, artifact formats, or
  package source files changed.
- Both focused tests now save and reload the fitted `TimeSeriesMMM`, then
  rebuild grouped inference results from the loaded model without prior or
  predictive groups.
- Both focused tests also save and reload the returned grouped
  `InferenceResults` object, then derive the same compact contribution and
  metric table structures from the loaded object.
- Assertions cover type, fit status, backend, sampler settings, channel names,
  fitted spec equality, observed-data equality/dimensions, posterior draw count,
  table headers, row counts, component labels, and metric labels. They avoid
  exact posterior numeric values and do not assert object identity across
  serialization boundaries.
- The existing persistence APIs remain trusted-local Julia serialization only;
  Phase 42 does not make a portable interchange, release, benchmark, or Abacus
  parity claim.

## Verification Evidence

Scoped verification only:

```bash
make test-file FILE=test/examples/toy_mcmc_smoke.jl
# Test Summary: Epsilon.jl | 144 pass / 144 total | 1m31.3s

make test-file FILE=test/examples/csv_mmm_quickstart.jl
# Test Summary: Epsilon.jl | 167 pass / 167 total | 1m15.3s

make format-check-touched
git diff --check
test -z "$(git diff --name-only -- src Project.toml Manifest.toml docs/Manifest.toml benchmark README.md docs/src/release.md .planning/ABACUS-PARITY-LEDGER.md scripts/smoke_supported_paths.sh)"
git status --short
```

The full suite, benchmarks, release checks, and release-prep commands were not
run for this bounded slice.
