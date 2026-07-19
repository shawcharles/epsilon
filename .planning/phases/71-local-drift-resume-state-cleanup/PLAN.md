# Phase 71: Local Drift And Resume-State Cleanup

## Status

Implemented.

## Objective

Remove recurring local status noise by making an explicit tracked/local decision
for the two remaining drift items:

```text
.gitignore
.planning/CRITICAL-REVIEW-2026-07-19.md
```

This is repository hygiene only. It does not change model semantics, pipeline
behaviour, demo configs, docs claims, tests, dependencies, benchmarks, release
readiness, or parity status.

## Current Evidence

Observed on `main` after Phase 70:

- `git status --short --branch` reports:
  - `M .gitignore`
  - `?? .planning/CRITICAL-REVIEW-2026-07-19.md`
- `.gitignore` has one narrow local addition:
  - `graphify-out/`
- `.planning/CRITICAL-REVIEW-2026-07-19.md` is a 302-line saved critical
  engineering review. Later phase plans already reference it as the source for
  several completed remediation slices.
- The review report is useful historical evidence, but some findings are no
  longer current after Phases 49 through 70. If tracked, it needs a clear
  historical-snapshot note so future readers use `.planning/STATE.md` and
  `.planning/ROADMAP.md` for current status.
- The new `?? .planning/phases/71-local-drift-resume-state-cleanup/` entry is
  created by this phase and is covered by the plan allowlist; it is not
  pre-existing drift.

## Decision

Track both drift items deliberately:

1. Commit the `graphify-out/` ignore rule. It is a generated local tool output
   directory and should not appear in normal status checks.
2. Commit `.planning/CRITICAL-REVIEW-2026-07-19.md` as historical review
   evidence, after adding a short note that the report is a point-in-time
   review and that later phases have addressed many findings.
3. Update planning state so the resume point is clean and future agents do not
   keep treating these files as unrelated drift.

## In Scope

- Add a historical-snapshot note to
  `.planning/CRITICAL-REVIEW-2026-07-19.md`.
- Commit `.planning/CRITICAL-REVIEW-2026-07-19.md`.
- Commit the existing `.gitignore` `graphify-out/` rule.
- Update `.planning/ROADMAP.md`, `.planning/STATE.md`, and this plan.
- Run status/whitespace checks only.

## Out of Scope

- Editing the body findings of the critical review.
- Re-auditing the codebase.
- Opening new remediation phases from the review.
- Changing model/runtime/docs behaviour.
- Changing `data/demo`, `examples/demo`, pipeline stages, plotting, or tests.
- Benchmark or release-readiness work.
- Full-suite execution.
- Moving or renaming internal reference/provenance surfaces.
- Modifying `.planning/ABACUS-PARITY-LEDGER.md`.

## File Allowlist

Expected implementation files:

- `.gitignore`
- `.planning/CRITICAL-REVIEW-2026-07-19.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/71-local-drift-resume-state-cleanup/PLAN.md`

Do not stage unrelated files.

## Tasks

### 71-01: Preserve The Critical Review As Historical Evidence

- [x] Add a short note near the top of
      `.planning/CRITICAL-REVIEW-2026-07-19.md` saying it is a point-in-time
      review and that later phases supersede current-status claims.
- [x] Do not edit or relitigate the body findings.
- [x] Acceptance: the report is useful as historical evidence without becoming
      the current source of truth.

### 71-02: Track The Local Ignore Rule

- [x] Commit the existing `graphify-out/` ignore rule.
- [x] Acceptance: generated Graphify output no longer appears in ordinary git
      status, and no broader ignore rule is added.

### 71-03: Update Resume State

- [x] Add Phase 71 to `.planning/ROADMAP.md`.
- [x] Update `.planning/STATE.md` to show Phase 71 complete after
      implementation.
- [x] Mark this plan implemented after review and checks pass.
- [ ] Acceptance: `git status --short --branch` is clean after commit.

### 71-04: Verification And Commit

- [ ] Run scoped checks only:
      - `git diff --check`;
      - `git diff --cached --check` after staging;
      - `{ git diff --name-only; git diff --cached --name-only; git ls-files --others --exclude-standard; } | sort`;
      - `git status --short --branch`.
- [ ] Commit and push after independent implementation review clears.

## Implementation Notes

Landed scope:

- `.planning/CRITICAL-REVIEW-2026-07-19.md` now has a historical-snapshot note
  before the original review scope. The body findings were not edited.
- One pre-existing trailing whitespace marker inside the previously untracked
  review report was removed so `git diff --cached --check` passes; no wording or
  finding changed.
- `.gitignore` retains only the narrow `graphify-out/` generated-output rule.
- `.planning/ROADMAP.md` and `.planning/STATE.md` now record Phase 71 as the
  current completed phase.

No Julia tests are required because this phase changes only planning/history
metadata and `.gitignore`.

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Stale review findings get read as current defects | Medium | Add a historical-snapshot note and point readers to current planning state. |
| `.gitignore` grows broad local-machine clutter | Low | Commit only the narrow `graphify-out/` rule already present. |
| Hygiene phase turns into new remediation work | Medium | Do not edit review findings or open code changes in this phase. |
| Unnecessary tests waste time | Low | Run whitespace/status checks only; no runtime changed. |

## Independent Review

Completed before implementation by a read-only subagent.

Accepted corrections:

- Add staged-file verification via `git diff --cached --check` and include
  `git diff --cached --name-only` in the file-inventory command.
- Clarify that the new Phase 71 plan directory is phase-created allowlisted
  work, not pre-existing drift.

The reviewer cleared the decision to track the critical review as historical
evidence and to commit the narrow `graphify-out/` ignore rule.
