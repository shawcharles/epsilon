# Phase 43: Supported-Path User Workflow Runbook

**Status:** Landed.
**Created:** 2026-07-18
**Owner:** Epsilon maintainers

## Objective

Create one canonical, docs-backed runbook for the currently supported local
MCMC example workflow:

- run the synthetic toy example
- run the fixed-schema CSV quickstart
- inspect their compact output sidecars
- save and reload returned fitted models and grouped inference results through
  existing trusted-local APIs
- use `make smoke` as fast local confidence evidence

Phases 39 through 42 proved these paths run, emit compact outputs, and roundtrip
fitted artifacts. Phase 43 closes the documentation gap: a user or maintainer
should not have to infer the supported workflow from tests, planning files, or
release-gate wording.

This is documentation and runbook hygiene only. It must not introduce new
runtime behavior, public APIs, CLI flags, artifact formats, benchmarks, release
claims, or Abacus parity promotions.

## Reference Boundary

Primary docs:

- `examples/toy_mmm/README.md`
- `examples/csv_mmm/README.md`
- `docs/src/index.md`
- `docs/make.jl`
- new `docs/src/supported_paths.md`, if accepted by review

Existing behavior references:

- `examples/toy_mmm/run_toy_mmm.jl`
- `examples/csv_mmm/run_csv_mmm.jl`
- `scripts/smoke_supported_paths.sh`
- `test/examples/toy_mcmc_smoke.jl`
- `test/examples/csv_mmm_quickstart.jl`

Planning/state files:

- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- this plan

## In Scope

- Add a canonical docs page for the supported-path local workflow.
- Explain the exact commands for toy, CSV, and `make smoke`.
- Explain the compact output sidecars and their stable columns/summary keys at
  a high level.
- Explain the trusted-local save/load workflow for returned `TimeSeriesMMM` and
  grouped `InferenceResults` objects using existing APIs.
- Cross-link the two example READMEs to the canonical docs page instead of
  duplicating a long runbook in both directories.
- Update docs navigation and planning state when the phase closes.

## Out of Scope

- No `src/` changes.
- No new public API, CLI flag, artifact format, serialization backend, output
  filename, script behavior, or example return contract.
- No new examples, demo data, pipeline behavior, ingestion API, scenario
  planner behavior, plots, reports, dashboard/UI, AI advisor, VI, calibration,
  HSGP/TVP, panel, optimization, or Abacus parity changes.
- No full test suite, `make check-full`, benchmark run, benchmark-output
  update, release branch, release tag, package registration, or release-ready
  claim.
- No parity ledger update unless a direct current-facing contradiction is found.
- No claim that `.jls` files are portable interchange artifacts or safe for
  untrusted input.

## Tasks

### 43-01: Reviewed Runbook Contract

- [x] Write this phase plan before implementation.
- [x] Add only minimal roadmap/state hooks needed to identify Phase 43 as the
      active planning slice.
- [x] Send the plan to an independent review agent.
- [x] Resolve every Must Fix from review before implementation begins.

### 43-02: Canonical Supported-Path Page

- [x] Add a docs page that gives the supported toy, CSV, and `make smoke`
      commands.
- [x] Include a compact-output inspection section that names the stable sidecar
      files and columns without promising sampled numeric stability.
- [x] Include a trusted-local artifact roundtrip section using existing
      `save_model`, `load_model`, `save_inference_results`, and
      `load_inference_results` APIs.
- [x] State clearly that the `.jls` artifacts are local Julia/Epsilon-version
      bound serialization, not portable interchange and not for untrusted
      inputs.

### 43-03: Minimal Cross-Links

- [x] Add docs navigation for the canonical page.
- [x] Add short links from the toy and CSV example READMEs to the canonical
      runbook.
- [x] Avoid duplicating long code snippets in both example READMEs.

### 43-04: Closure And State Update

- [x] Run docs-focused and lightweight verification only.
- [x] Update this plan with landed status, review notes, and verification
      evidence.
- [x] Update `.planning/ROADMAP.md` and `.planning/STATE.md` to record Phase 43
      closure.
- [x] Prepare the bounded slice for commit and push.

## Acceptance Criteria

- A user can find one canonical docs page that explains the supported local toy
  and CSV workflow end to end.
- The canonical page is present in Documenter navigation, and both example
  READMEs link to it with short cross-references.
- The page documents the existing artifact roundtrip path without adding a new
  artifact-writing feature to the CLI examples.
- All artifact wording is precise: trusted-local Julia serialization only, not
  portable interchange, not untrusted input, not release evidence.
- Example READMEs remain concise and point to the canonical page.
- No runtime code, dependencies, manifests, benchmarks, parity ledger rows,
  release docs, or full-suite verification are changed.

## Verification

Use scoped checks only:

```bash
make docs
make format-check-touched
git diff --check
test -z "$(git diff --name-only -- src Project.toml Manifest.toml docs/Manifest.toml benchmark .planning/ABACUS-PARITY-LEDGER.md scripts/smoke_supported_paths.sh)"
diff -u <({ git diff --name-only; git ls-files --others --exclude-standard; } | sort) <(printf '%s\n' \
  .planning/ROADMAP.md \
  .planning/STATE.md \
  .planning/phases/43-supported-path-user-workflow-runbook/PLAN.md \
  docs/make.jl \
  docs/src/index.md \
  docs/src/supported_paths.md \
  examples/csv_mmm/README.md \
  examples/toy_mmm/README.md | sort)
git status --short
```

Do not run `make test`, `Pkg.test()` without a focused file selector,
`make check-full`, release checks, or benchmark commands.

## Risks

- **Documentation overclaim:** The runbook must not turn smoke/example evidence
  into release readiness, benchmark, or Abacus parity evidence.
- **Artifact portability overclaim:** Existing `.jls` serialization is
  trusted-local and Julia/Epsilon-version-bound. Keep that caveat near the
  save/load example.
- **Surface creep:** Adding CLI artifact flags would change behavior. This
  phase documents the returned objects and existing APIs only.
- **Docs drift:** Avoid copying too much duplicated workflow text into both
  example READMEs. Keep the canonical page authoritative.

## Review Notes

- Independent plan review found one Must Fix: the original negative
  no-widening guard did not fully enforce a docs/planning-only file boundary.
  It also recommended aligning the roadmap hook with the no-parity-change
  boundary and requiring Documenter navigation plus both example README links
  in acceptance criteria. All points are resolved before implementation.
- Independent review re-check found no Must Fix or Should Fix items after the
  allowlist and wording updates.

## Implementation Notes

- Added `docs/src/supported_paths.md` as the canonical supported local workflow
  runbook.
- Added the page to Documenter navigation through `docs/make.jl`.
- Added a short link from `docs/src/index.md` to the canonical page.
- Added short cross-links from both example READMEs without duplicating the full
  runbook.
- Left scripts, runtime source, tests, manifests, release docs, benchmark files,
  and parity ledgers untouched.

## Verification Evidence

Scoped verification only:

```bash
make docs
make format-check-touched
git diff --check
test -z "$(git diff --name-only -- src Project.toml Manifest.toml docs/Manifest.toml benchmark .planning/ABACUS-PARITY-LEDGER.md scripts/smoke_supported_paths.sh)"
diff -u <({ git diff --name-only; git ls-files --others --exclude-standard; } | sort) <(printf '%s\n' \
  .planning/ROADMAP.md \
  .planning/STATE.md \
  .planning/phases/43-supported-path-user-workflow-runbook/PLAN.md \
  docs/make.jl \
  docs/src/index.md \
  docs/src/supported_paths.md \
  examples/csv_mmm/README.md \
  examples/toy_mmm/README.md | sort)
```

`make docs` completed successfully. Documenter emitted non-fatal existing-style
warnings about edit-link detection, skipped deployment outside CI, and the large
`index.md` generated HTML size.

The full suite, benchmarks, release checks, and smoke command were not run for
this docs-only slice.
