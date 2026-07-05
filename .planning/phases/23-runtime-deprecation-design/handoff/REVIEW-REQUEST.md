# Review Request: Phase 23 Runtime Deprecation Design

## Scope Implemented

Phase 23 is a design-only closure phase for future runtime deprecation of the
six Phase 22 validation-helper candidates.

Changed files:

- `.planning/API-RUNTIME-DEPRECATION-DESIGN.md`
- `.planning/phases/23-runtime-deprecation-design/PLAN.md`
- `.planning/phases/23-runtime-deprecation-design/handoff/ARCHITECT-BRIEF.md`
- `.planning/phases/23-runtime-deprecation-design/handoff/REVIEW-FEEDBACK.md`
- `.planning/phases/23-runtime-deprecation-design/handoff/REVIEW-REQUEST.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `CHANGELOG.md`

## Intended Non-Changes

No `src/`, `test/`, or `docs/src` files should be changed. No exports,
runtime warnings, validation semantics, model behaviour, user-facing docs, or
Abacus parity evidence should change.

## Review Questions

1. Does `.planning/API-RUNTIME-DEPRECATION-DESIGN.md` match the six candidates
   and migrations from `.planning/API-EXPORT-CLEANUP-RFC.md`?
2. Does it correctly prevent the main failure mode: adding warnings directly to
   validators that constructors and builders call internally?
3. Does the design preserve current validation return values and exact
   exception type/message behaviour after future warning emission?
4. Are planning/changelog updates conservative and free of overclaiming?
5. Is scoped verification with `git diff --check` sufficient for this
   markdown-only phase?
