# Review Feedback: Phase 24 Plan

## Reviewer

Herschel subagent, plan review before implementation.

## Result

Approved for implementation.

## Must Fix

None.

## Should Fix

1. Make warning tests explicit with `@test_deprecated`, `@test_logs`,
   `@test_warn`, or equivalent rather than relying on visible stderr.
2. Preserve exact validation error messages with message-level assertions for
   invalid direct public validator calls.
3. Ensure all six public wrappers get both positive and invalid direct-call
   coverage, including `validate_calibration_step_config`.

## Resolution

The plan and Builder brief now require explicit warning assertions, exact
invalid-message assertions, and direct public-call coverage for all six
wrappers. The targeted warning test commands use `julia --depwarn=yes` because
plain direct Julia execution suppresses `Base.depwarn` in this environment.

## Verification Position

The targeted-test plan is appropriate. The full suite is not required unless
implementation touches `src/Epsilon.jl`, shared test imports, `test/runtests.jl`,
or broader package infrastructure.

## Implementation Review

Reviewer: Dirac subagent, after implementation.

Result: approved after Must Fix resolution.

Must Fix:

1. `.planning/API-RUNTIME-DEPRECATION-DESIGN.md` still described the original
   risk in present tense, saying constructors/builders call public
   `validate_*` wrappers. After Phase 24 they call `_validate_*` helpers.
2. The per-symbol design sections still used "Future warning/source/tests"
   headings even though Phase 24 had landed the implementation.

Resolution:

- The main design-risk section now describes the old public-validator call
  pattern as the pre-Phase-24 risk.
- Per-symbol headings now use implemented/landed wording for warning text,
  source handling, and tests.

Source/test review:

- Reviewer confirmed exactly six public wrappers call `Base.depwarn` and
  delegate to warning-free helpers.
- Reviewer confirmed constructors, loaders, and payload builders use helpers
  and remain warning-free for valid replacement workflows.
- Reviewer found no source/test Must Fix items.
- Reviewer confirmed no `src/Epsilon.jl` or `docs/src/api.md` diff, and no
  modelling, inference, or parity widening.
