# Review Feedback: Phase 26 Plan

## Reviewer

Lovelace subagent, plan review before implementation.

## Result

Approved after Must Fix clarification.

## Must Fix

1. Clarify that the guard checks the current export surface only after
   filtering to the six deprecated validation-helper symbols. The original
   wording could be read as requiring the six-row migration audit to match all
   loaded exports.

## Should Fix

1. Name the exact read-only evidence sources for the triage register and
   runtime-deprecation design.
2. Add parser robustness criteria: unique begin/end markers, exact table
   header, exactly six data rows, and no duplicate symbols.
3. Add a lightweight `src/` diff guard to the closure checks.

## Resolution

- `PLAN.md` and `ARCHITECT-BRIEF.md` now refer to the filtered deprecated-
  helper export subset, not all exports.
- `ARCHITECT-BRIEF.md` now names `.planning/API-EXPORT-TRIAGE.md` and
  `.planning/API-RUNTIME-DEPRECATION-DESIGN.md` as read-only evidence sources.
- Parser robustness and `git diff --name-only -- src/` checks are now explicit
  acceptance/verification criteria.

## Verification Position

The plan is bounded and does not justify a full-suite run. The default
verification remains `make test-file FILE=test/api_exports.jl`, Runic on the
touched Julia test file, `git diff --name-only -- src/`, and `git diff --check`.

---

# Review Feedback: Phase 26 Implementation

## Reviewer

Helmholtz subagent, implementation review before commit.

## Result

Cleared.

## Must Fix

None.

## Should Fix

None.

## Notes

- The Markdown parsers are deliberately strict for repo-controlled tables. They
  reject pipes inside table cells, but the guarded migration text has none.
- No `src/`, `Project.toml`, or docs inventory changes were present.
- The audit guard is correctly scoped to the six deprecated validation helpers
  rather than the full export surface.
- Migration text is guarded across the triage register, cleanup RFC, audit
  table, and runtime-deprecation design.
- RFC, roadmap, state, and changelog wording remains conservative: no
  stable-v1 readiness or Abacus parity overclaiming.

## Verification

Reviewer reran and passed:

```bash
make test-file FILE=test/api_exports.jl
julia --project=@runic -m Runic --check --diff test/api_exports.jl
git diff --name-only -- src/
git diff --check
```

`make test-file FILE=test/api_exports.jl` passed with 4355 tests.
