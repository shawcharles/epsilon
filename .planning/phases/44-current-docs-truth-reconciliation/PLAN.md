# Phase 44: Current Docs Truth Reconciliation

**Status:** Landed.
**Created:** 2026-07-19
**Owner:** Epsilon maintainers

## Objective

Reconcile current-facing documentation with the actual project state after
Phase 43. The docs home page and release-facing project docs still contain
historical framing such as "Phases 1-12" or "last updated after Phase 40",
which is now stale and can mislead future maintainers into release-prep,
benchmark, or parity-claim drift.

This phase updates only current-facing wording so the docs say the same thing
as `.planning/STATE.md`:

- MCMC/Turing is the sole fitting path; VI is permanently retired.
- Supported local toy/CSV workflows exist and are documented in
  `docs/src/supported_paths.md`.
- Local smoke and supported-path docs are not benchmarks, release evidence, or
  Abacus parity evidence.
- `.jls` artifacts are trusted-local Julia/Epsilon-version-bound
  serialization, not portable interchange and not safe for untrusted input.
- Abacus parity claims remain governed by `.planning/ABACUS-PARITY-LEDGER.md`.

This is documentation and planning hygiene only. It must not introduce runtime
behavior, tests, new docs pages, public APIs, CLI flags, artifact formats,
benchmarks, release actions, or parity promotions.

## Reference Boundary

Primary current-facing docs:

- `docs/src/index.md`
- `docs/src/release.md`
- `.planning/PROJECT.md`

Planning/state files:

- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- this plan

Reference-only docs:

- `docs/src/supported_paths.md`
- `.planning/ABACUS-PARITY-LEDGER.md`

## In Scope

- Replace stale "Phases 1-12" style current-status wording on the docs home
  page with a concise current-state summary through Phase 43.
- Update release-facing introductory wording so the page remains truthful after
  Phases 38 through 43 without implying a new release gate has run.
- Refresh `.planning/PROJECT.md` current-status / last-updated wording if it is
  stale.
- Update roadmap/state when the phase closes.

## Out of Scope

- No `src/`, `test/`, examples, scripts, Makefile, dependency, manifest,
  benchmark, release artifact, or parity-ledger changes.
- No new docs pages, page renames, navigation changes, or generated docs
  commits.
- No feature work, model semantics, pipeline behavior, scenario behavior,
  calibration, HSGP/TVP, panel, plotting, dashboard/UI, AI advisor, or VI work.
- No benchmark run, benchmark-result update, release branch, release tag,
  package registration, `make check-full`, `make test`, or release check.
- No claim that supported-path smoke or runbook evidence is release evidence,
  benchmark evidence, or Abacus parity evidence.

## Tasks

### 44-01: Reviewed Docs-Truth Contract

- [x] Write this phase plan before implementation.
- [x] Add only minimal roadmap/state hooks needed to identify Phase 44 as the
      active planning slice.
- [x] Send the plan to an independent review agent.
- [x] Resolve every Must Fix from review before implementation begins.

### 44-02: Reconcile Current-Facing Docs

- [x] Update `docs/src/index.md` current-status wording so it no longer claims
      the current state is only through Phase 12.
- [x] Update `docs/src/release.md` introductory wording so it distinguishes the
      historical Phase 11/12 release-gate infrastructure from later Phase 38-43
      support-boundary and workflow hardening.
- [x] Update `.planning/PROJECT.md` stale current-status / last-updated wording
      if needed.
- [x] Keep unsupported and evidence-boundary wording conservative.

### 44-03: Closure And State Update

- [x] Run docs-focused and lightweight verification only.
- [x] Update this plan with landed status, review notes, and verification
      evidence.
- [x] Update `.planning/ROADMAP.md` and `.planning/STATE.md` to record Phase 44
      closure.
- [x] Prepare the bounded slice for commit and push.

## Acceptance Criteria

- Current-facing docs no longer imply the project status stopped at Phase 12 or
  Phase 40.
- Release-facing docs do not imply that Phases 38-43 reran release gates,
  benchmarks, or broad Abacus parity certification.
- MCMC-only, VI-retired, trusted-local artifact, supported-path runbook, and
  no-release/no-benchmark/no-parity-evidence boundaries are preserved.
- Verification includes content checks proving stale current-facing phrases are
  removed from the targeted docs.
- No runtime code, tests, examples, scripts, Makefile, dependencies, manifests,
  benchmark files, release artifacts, generated docs, or parity ledger rows
  change.

## Verification

Use scoped checks only:

```bash
make docs
make format-check-touched
git diff --check
git diff --cached --check
test -z "$({ git diff --name-only; git diff --cached --name-only; } | sort -u | grep -E '^(src/|test/|examples/|scripts/|Makefile$|Project.toml$|Manifest.toml$|docs/Project.toml$|docs/Manifest.toml$|benchmark/|\\.planning/ABACUS-PARITY-LEDGER\\.md$|docs/build/)')"
! rg -n "Phases 1-12|after Phase 40" docs/src/index.md docs/src/release.md .planning/PROJECT.md
! rg -n "(Phases 38-43|Phases 38 through 43).*(reran|release gates?|benchmarks?|Abacus parity|certification)|(reran|release gates?|benchmarks?|Abacus parity|certification).*(Phases 38-43|Phases 38 through 43)" docs/src/index.md docs/src/release.md .planning/PROJECT.md
diff -u <({ git diff --name-only; git diff --cached --name-only; git ls-files --others --exclude-standard; } | sort -u) <(printf '%s\n' \
  .planning/PROJECT.md \
  .planning/ROADMAP.md \
  .planning/STATE.md \
  .planning/phases/44-current-docs-truth-reconciliation/PLAN.md \
  docs/src/index.md \
  docs/src/release.md | sort)
git status --short
```

Do not run `make test`, `Pkg.test()` without a focused file selector,
`make smoke`, `make check-full`, release checks, or benchmark commands.

## Risks

- **Release overclaim:** Updating release docs can accidentally suggest a new
  release gate has run. Keep Phase 11/12 as historical infrastructure and name
  later phases as support-boundary/documentation hardening.
- **Benchmark drift:** Do not touch benchmark files or imply a refreshed
  benchmark snapshot exists.
- **Parity overclaim:** The parity ledger remains the controlling source for
  Abacus claims.
- **Docs churn:** Keep edits surgical. Do not rewrite matrices or old
  historical sections unless they contradict current-facing status.

## Review Notes

- Independent plan review found one Must Fix: the original verification guard
  missed staged changes. It also recommended content checks for stale phrases
  and adding `docs/Project.toml` to the dependency guard. Review re-check found
  no Must Fix and suggested broadening the overclaim grep to cover both
  `Phases 38-43` and `Phases 38 through 43`. All points are resolved before
  implementation.

## Implementation Notes

- Updated `docs/src/index.md` so the current status is documented through Phase
  43, with MCMC/Turing as the sole fitting path and supported local workflows
  explicitly separated from benchmark, release, and Abacus parity evidence.
- Updated `docs/src/release.md` so the Phase 11/12 release-gate infrastructure
  is framed historically and later support-boundary/workflow hardening is not
  presented as a rerun release gate or refreshed benchmark.
- Updated `.planning/PROJECT.md` to mention the canonical supported local
  workflow runbook, trusted-local artifact boundary, and current Phase 44
  last-updated marker.
- Left runtime source, tests, examples, scripts, Makefile, manifests,
  benchmarks, generated docs, release artifacts, and the parity ledger
  untouched.

## Verification Evidence

Scoped verification only:

```bash
make docs
make format-check-touched
git diff --check
git diff --cached --check
test -z "$({ git diff --name-only; git diff --cached --name-only; } | sort -u | grep -E '^(src/|test/|examples/|scripts/|Makefile$|Project.toml$|Manifest.toml$|docs/Project.toml$|docs/Manifest.toml$|benchmark/|\\.planning/ABACUS-PARITY-LEDGER\\.md$|docs/build/)')"
! rg -n "Phases 1-12|after Phase 40" docs/src/index.md docs/src/release.md .planning/PROJECT.md
! rg -n "(Phases 38-43|Phases 38 through 43).*(reran|release gates?|benchmarks?|Abacus parity|certification)|(reran|release gates?|benchmarks?|Abacus parity|certification).*(Phases 38-43|Phases 38 through 43)" docs/src/index.md docs/src/release.md .planning/PROJECT.md
diff -u <({ git diff --name-only; git diff --cached --name-only; git ls-files --others --exclude-standard; } | sort -u) <(printf '%s\n' \
  .planning/PROJECT.md \
  .planning/ROADMAP.md \
  .planning/STATE.md \
  .planning/phases/44-current-docs-truth-reconciliation/PLAN.md \
  docs/src/index.md \
  docs/src/release.md | sort)
```

`make docs` completed successfully. Documenter emitted non-fatal existing-style
warnings about edit-link detection, skipped deployment outside CI, and the large
`index.md` generated HTML size. `make format-check-touched` reported no touched
Julia files.

The full suite, smoke command, benchmarks, release checks, and release-prep
commands were not run for this docs-only slice.
