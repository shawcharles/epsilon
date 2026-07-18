# Phase 40: Planning Truth Reconciliation

**Status:** Landed.
**Created:** 2026-07-18
**Owner:** Epsilon maintainers

## Objective

Reconcile the project control documents after Phase 39 so the repository's
planning surface tells one truthful story about the current state of Epsilon:
Phase 13 contract remediation is closed, Plan 14-05 is closed, Phase 38 has
permanently retired variational inference, Phase 39 has landed local
supported-path smoke certification, and release/benchmark work remains a
separate explicit decision rather than the automatic next step.

This phase is documentation and planning-state hygiene only. It must not change
runtime code, tests, examples, benchmark results, release artefacts, manifests,
dependencies, model semantics, or Abacus parity status rows without direct
evidence.

## Reference Boundary

Primary source-of-truth documents:

- `.planning/STATE.md`
- `.planning/ROADMAP.md`
- `.planning/PROJECT.md`
- `.planning/ABACUS-PARITY-LEDGER.md`
- `README.md`
- `CHANGELOG.md`
- `.planning/phases/38-permanent-vi-surface-retirement/PLAN.md`
- `.planning/phases/39-supported-path-smoke-certification/PLAN.md`

Initial contradiction scan found:

- `.planning/PROJECT.md` still marks the Phase 13 remediation and parity-ledger
  distinction requirements unchecked, despite later state/roadmap evidence that
  both were closed.
- `.planning/PROJECT.md` still marks the demo-style `timeseries`, `geo_panel`,
  and `geo_brand_panel` acceptance target unchecked, despite Phase 14 / Plan
  `14-05` closure evidence.
- `.planning/PROJECT.md` still says it was last updated after Phase 27.
- `.planning/ROADMAP.md` says Plan `14-05` is closed near the top, but the
  Phase 14 detail list still has `14-05` unchecked.
- `.planning/ROADMAP.md` progress prose still says phases execute through
  Phase 29 and omits Phases 31-39 from the lower progress table.
- `.planning/STATE.md` correctly records Phase 39 at the top, but lower
  progress, recent-trend, pending-todo, blocker, and session handoff sections
  still reflect older Phase 26 / Phase 14 release-prep state.

## In Scope

- Add Phase 40 to the roadmap as a bounded planning/docs reconciliation phase.
- Refresh `.planning/STATE.md` so current phase, current plan, recent trend,
  pending todos, blockers, and session handoff reflect Phase 40 and the landed
  Phase 38/39 reality.
- Refresh `.planning/ROADMAP.md` so Phase 14 details agree with the Phase 14
  summary, the execution-order/progress sections include Phases 31-40, and
  stale "next release prep" implications are either removed or bounded.
- Refresh `.planning/PROJECT.md` so completed active requirements and key
  decision outcomes match the evidence from Phases 13, 14, 38, and 39.
- Touch `.planning/ABACUS-PARITY-LEDGER.md`, `README.md`, or `CHANGELOG.md`
  only if a direct contradiction is found during the implementation scan.

## Out of Scope

- Any change under `src/`, `test/`, `examples/`, `docs/src/`, `benchmark/`,
  `scripts/`, or dependency/manifest files.
- Any benchmark run or benchmark result refresh.
- Any release branch, release tag, package registration, or release-readiness
  claim.
- Any Abacus parity status promotion or demotion unless a contradictory planning
  sentence needs correction.
- Any inference, calibration, HSGP/TVP, panel validation, optimiser, plotting,
  dashboard/UI, or AI-advisor behaviour change.
- Any full Julia test-suite run.

## Tasks

### 40-01: Reviewed Reconciliation Contract

- [x] Write this phase plan before implementation.
- [x] Add only minimal roadmap/state hooks needed to identify Phase 40 as the
      active planning slice.
- [x] Send the plan to an independent review agent.
- [x] Resolve every Must Fix from review before implementation begins.

### 40-02: Roadmap Truth Reconciliation

- [x] Mark Plan `14-05` complete in the Phase 14 detail list and align its text
      with the accepted Stage `00` through Stage `70` summary.
- [x] Add Phase 40 to the main phase list and lower progress table.
- [x] Bring the lower progress table current through Phases 31-40 without
      rewriting unrelated historical detail.
- [x] Replace stale execution-order or recent-progress wording that implies the
      roadmap ends at Phase 29 or that Plan `14-05` remains open.

### 40-03: Project And State Truth Reconciliation

- [x] Update `.planning/PROJECT.md` validated/active requirements so closed
      Phase 13, Phase 14 demo-acceptance, and parity-ledger work are no longer
      presented as open.
- [x] Update key-decision outcomes in `.planning/PROJECT.md` where the outcome
      has moved from pending to landed/closed.
- [x] Refresh `.planning/PROJECT.md` last-updated metadata.
- [x] Update `.planning/STATE.md` current phase/status, phase progress,
      recent-trend, pending-todo, blocker, and session handoff sections so they
      point to Phase 40 and the current post-Phase-39 state.

### 40-04: Guardrail Scan And Closure

- [x] Scan for stale `14-05`, Phase 26 handoff, Phase 29 execution-order,
      `scaffolded pre-v1` VI, and automatic release-prep/benchmark implications.
- [x] Update this plan with a landed status note and verification evidence.
- [x] Keep the touched-file manifest planning-only.
- [x] Commit the reconciliation once independently reviewed and locally checked.

## Acceptance Criteria

- `.planning/PROJECT.md`, `.planning/ROADMAP.md`, and `.planning/STATE.md` agree
  on the current completed state through Phase 39 and the active Phase 40
  reconciliation slice.
- Plan `14-05` is not simultaneously described as closed and unchecked/open.
- Phase 13 remediation and the parity-ledger source-of-truth requirement are
  not simultaneously described as closed and pending.
- The demo-style `timeseries`, `geo_panel`, and `geo_brand_panel` acceptance
  target is not simultaneously described as closed and pending.
- VI is described only as permanently retired or historical/superseded, never as
  a supported v1 backend or future implementation target.
- Benchmark/release work is not presented as the automatic next action; any such
  work remains an explicit later decision.
- No runtime, test, example, benchmark, dependency, manifest, or release files
  change.

## Verification

Run only lightweight documentation/state checks:

```bash
rg -n "14-05|Phase 26|Phase 29|scaffolded pre-v1|release preparation resumes|release prep|clean benchmark snapshot|automatic next|next recommended slice" .planning/PROJECT.md .planning/ROADMAP.md .planning/STATE.md .planning/ABACUS-PARITY-LEDGER.md README.md CHANGELOG.md
rg -n "Current Phase|Current Phase Name|Total Phases|Current Plan|Phase 40" .planning/STATE.md .planning/ROADMAP.md
git diff --check
test -z "$(git diff --name-only -- src test examples docs/src benchmark scripts Project.toml Manifest.toml docs/Manifest.toml)"
git status --short
```

Do not run `make test`, `Pkg.test()`, `make check-full`, or example MCMC smoke
commands for this phase; they do not validate planning-doc consistency and would
violate the scoped-test default.

## Risks

- **Over-editing historical context:** Some old statements are valid historical
  records. Correct contradictions and current-state guidance, but do not flatten
  useful history.
- **Accidental release claim:** Avoid wording that implies the package is release
  ready merely because planning docs agree.
- **Ledger overpromotion:** The Abacus parity ledger should remain the parity
  status authority; Phase 40 may clarify wording but should not upgrade rows.
- **Verification creep:** Full test runs would waste time and validate the wrong
  surface for a docs-only phase.

## Review Notes

- Independent plan review found one Must Fix: explicitly cover the unchecked
  `.planning/PROJECT.md` demo-style acceptance target. It also recommended
  tightening the stale benchmark scan to avoid legitimate historical benchmark
  hits. Both points are resolved in this plan before implementation.
- Implementation reconciled only `.planning/PROJECT.md`, `.planning/ROADMAP.md`,
  `.planning/STATE.md`, and this plan. No source, tests, examples, docs source,
  benchmark, script, dependency, manifest, release artifact, or parity-status
  files were edited.
- Independent implementation review found stale current-state wording at the
  top of `.planning/ROADMAP.md`, a pending verification note in this plan, and
  two readability/overclaiming refinements. These were resolved before commit.

## Verification Evidence

- Lightweight stale-phrase scan was run:
  `rg -n "14-05|Phase 26|Phase 29|scaffolded pre-v1|release preparation resumes|release prep|clean benchmark snapshot|automatic next|next recommended slice" ...`.
  Remaining hits were historical or explicitly bounded, and the review-requested
  stale current-state roadmap hits were fixed.
- Current-phase scan was run:
  `rg -n "Current Phase|Current Phase Name|Total Phases|Current Plan|Phase 40" .planning/STATE.md .planning/ROADMAP.md`.
  It confirms Phase 40 is current and complete.
- `git diff --check` passed.
- Planning-only touched-file guard passed:
  no files under `src`, `test`, `examples`, `docs/src`, `benchmark`, `scripts`,
  `Project.toml`, `Manifest.toml`, or `docs/Manifest.toml` changed.
- `git status --short` showed only `.planning/PROJECT.md`,
  `.planning/ROADMAP.md`, `.planning/STATE.md`, and this new phase plan before
  staging.
