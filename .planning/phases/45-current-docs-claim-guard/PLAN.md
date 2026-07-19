# Phase 45: Current Docs Claim Guard

## Status

Landed. The current-facing docs claim guard is implemented and verified.

## Objective

Add a focused regression guard that keeps the Phase 44 current-facing docs
truthful after future edits. The guard should reject stale current-status
phrases and support-boundary drift without rerunning release gates, benchmarks,
smoke workflows, or the full test suite.

## Reference Boundary

Phase 44 reconciled the current docs after Phase 43:

- `docs/src/index.md` describes the project through Phase 43 rather than stale
  Phase 12 framing.
- `docs/src/release.md` preserves Phase 13 release-gate revalidation while
  making clear that later support-boundary and local-workflow phases did not
  rerun the release gate or refresh benchmark artifacts.
- `.planning/PROJECT.md` points to `docs/src/supported_paths.md` and keeps
  toy/CSV/local smoke evidence separate from release, benchmark, portable
  interchange, and Abacus parity evidence.
- Phase 38 remains binding: variational inference is permanently retired, and
  MCMC/Turing is the only fitting path.

## In Scope

- Add a narrow docs-claim guard to the existing `test/api_exports.jl` public
  surface governance lane.
- Guard current-facing files only:
  - `docs/src/index.md`
  - `docs/src/release.md`
  - `docs/src/supported_paths.md`
  - `.planning/PROJECT.md`
- Reject known stale current-status wording such as `Phases 1-12` and
  `after Phase 40`.
- Require the current docs to preserve:
  - Phase 43 as the documented current support-workflow state.
  - Phase 13 as the last release-gate revalidation.
  - permanent VI retirement and MCMC/Turing-only fitting.
  - supported local workflow evidence as local confidence/teaching evidence,
    not benchmark, release, or Abacus parity evidence.
  - `.jls` artifacts as trusted-local Julia serialization, not portable or
    untrusted interchange.
- Record the user's future strategic direction: Epsilon should eventually scrub
  or reframe public Abacus mentions and stand as an independent MMM library,
  but that work needs its own reviewed plan because the current parity ledger
  and fixtures remain active validation infrastructure.
- Update `.planning/ROADMAP.md` and `.planning/STATE.md` for Phase 45.

## Out of Scope

- Runtime, model, inference, optimization, plotting, pipeline, or example
  changes.
- Any benchmark run, smoke run, release-gate run, or full test-suite run.
- Rewriting public documentation copy unless the guard exposes a real
  contradiction.
- Scrubbing Abacus mentions in this phase.
- Changing `.planning/ABACUS-PARITY-LEDGER.md`, fixture names, fixture paths,
  or parity status rows.
- Reopening release preparation, HSGP/TVP support, panel validation,
  calibration expansion, dashboard/UI, AI advisor, or VI.

## Tasks

### 45-01: Plan And Review

- [x] Create this plan with an exact scope boundary.
- [x] Run an independent review pass before implementation.
- [x] Resolve any blocker raised by the reviewer.

### 45-02: Current Docs Claim Guard

- [x] Add focused assertions to `test/api_exports.jl`.
- [x] Reuse existing file-reading and VI-claim guard style where practical.
- [x] Keep failures specific enough to identify the offending claim class.
- [x] Do not add a new test dependency or broaden the test runner.

### 45-03: State Closure

- [x] Mark Phase 45 complete in this plan.
- [x] Update `.planning/ROADMAP.md` and `.planning/STATE.md`.
- [x] Preserve the future Abacus-reference decoupling note as pending work, not
      as completed cleanup.

## Acceptance Criteria

- `test/api_exports.jl` fails if current-facing docs revert to stale Phase
  12/40 current-state wording.
- `test/api_exports.jl` fails if required positive current anchors disappear:
  Phase 43 as the documented supported-workflow state, Phase 13 as the last
  release-gate revalidation, permanent VI retirement, local-workflow evidence
  limits, and trusted-local `.jls` caveats.
- `test/api_exports.jl` fails if current-facing docs imply VI is supported.
- `test/api_exports.jl` fails if supported local workflows are recast as
  benchmarks, release evidence, or Abacus parity evidence.
- `test/api_exports.jl` fails if trusted-local `.jls` artifacts are recast as
  portable or safe for untrusted input.
- The phase records that future Abacus-reference scrubbing requires a separate
  reviewed identity/validation plan.
- The changed-file set is limited to:
  - `.planning/ROADMAP.md`
  - `.planning/STATE.md`
  - `.planning/phases/45-current-docs-claim-guard/PLAN.md`
  - `test/api_exports.jl`

## Verification

Use scoped local checks only:

```bash
make test-file FILE=test/api_exports.jl
make format-check-touched
git diff --check
git diff --cached --check
git status --short
```

No full suite, `make smoke`, `make docs`, benchmark, or release gate is
required for this guard-only phase.

Actual verification:

- [x] `make test-file FILE=test/api_exports.jl` passed: `5583 / 5583`.
- [x] `make format-check-touched`
- [x] `git diff --check`
- [x] `git diff --cached --check`
- [x] `git status --short`

## Risks

- **Over-specific text guards:** exact sentence matching can turn useful docs
  edits into brittle failures. Mitigation: assert short semantic phrases and
  use whitespace-normalized text where line wrapping is likely.
- **False independence claims:** removing or suppressing every Abacus mention
  prematurely would hide the current validation provenance. Mitigation: record
  Abacus public-identity decoupling as future work with an explicit replacement
  plan, while leaving the current parity infrastructure truthful.
- **Test-lane creep:** docs-claim guards can become a general prose linter.
  Mitigation: guard only current support, release, VI, local-workflow, and
  trusted-local artifact claims.

## Review Notes

Independent review completed before implementation. Findings:

- No Must Fix blockers.
- Add an explicit changed-file allowlist verification, including untracked
  files.
- Keep the new docs-claim guard on its own tight path set rather than reusing
  the broader VI-scope scan paths.
- Require positive current anchors as well as rejecting stale or widened
  wording.
- The future Abacus-reference scrub note is safe because actual scrubbing and
  parity-ledger or fixture changes are out of scope.
