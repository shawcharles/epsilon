# Review Feedback: Phase 23 Plan

## Reviewer

Dewey subagent, plan review before implementation.

## Result

Approved for implementation.

## Must Fix

None.

## Should Fix

1. Clarify phase-local handoff paths in the plan.
2. State explicitly that future runtime warnings must preserve existing
   validation exception types and messages after warning emission.

## Resolution

Both Should Fix items were incorporated before design-document implementation:

- Task verification paths now use the full
  `.planning/phases/23-runtime-deprecation-design/handoff/...` paths.
- The design constraints and future implementation contract now require exact
  validation exception type and message preservation.

## Verification Position

Skipping the full suite is acceptable if the final diff remains strictly
planning/changelog/handoff plus the new runtime deprecation design document and
`git diff --check` passes. If executable package files are touched, verification
must escalate to the relevant targeted lane or full suite depending on scope.

## Implementation Review

Reviewer: Huygens subagent, after implementation.

Result: approved.

Must Fix: none.

Should Fix: none.

Findings:

- The design matches the six Phase 22 candidates and migration targets.
- The design requires the wrapper/internal-helper split before any warnings.
- The design preserves `nothing` returns and exact validation exception
  type/message behaviour.
- Planning, roadmap, state, and changelog wording says runtime deprecation is
  designed, not landed.
- No `src/`, `test/`, or `docs/src` changes are present.

Verification note:

- Plain `git diff --check` does not inspect untracked files before staging.
  Run `git diff --cached --check` after staging to cover the new Phase 23
  markdown files.
