# Review Request: Phase 24 Runtime Deprecation Wrappers

## Request

Review the Phase 24 implementation against
`.planning/phases/24-runtime-deprecation-wrappers/handoff/ARCHITECT-BRIEF.md`
and the Phase 24 plan.

## Focus Areas

- Confirm the six public validators warn only on direct public calls:
  `validate_calibration_step_config`,
  `validate_lift_test_calibration_payload`,
  `validate_cost_per_target_calibration_payload`, `validate_sampler_config`,
  `validate_model_config`, and `validate_mmm_data`.
- Confirm constructors, loaders, and payload builders use warning-free
  `_validate_*` helpers.
- Confirm validation predicates, return values, exception types, and exact
  invalid-message semantics were preserved.
- Confirm tests assert warnings explicitly and compare invalid
  `ArgumentError.msg` strings.
- Confirm no export, API inventory, docs inventory row, modelling, inference,
  or Abacus parity scope was widened.

## Verification Run By Builder

- `julia --depwarn=yes --project=. test/model/types.jl` passed.
- Narrow calibration wrapper smoke under root project passed with
  `julia --depwarn=yes --project=. -e ...`, covering valid direct public calls
  for the three calibration validators plus silent builder construction.
- `julia --project=. -e 'using Pkg; Pkg.test(; test_args=["api_exports", "basic"])'` passed.
- Runic check on touched source/test files passed.
- `git diff --check` passed.
- `julia --depwarn=yes --project=. test/model/calibration.jl` failed before
  executing tests because `ForwardDiff` is unavailable to root-project direct
  script execution.
- A broader `Pkg.test(; test_args=["model"])` substitute was interrupted after
  reaching unrelated sampler-heavy builder tests; before interruption it had
  exercised the changed `types.jl` and `calibration.jl` testsets and exposed a
  helper-name overwrite warning, which was fixed.

## Known Gaps For Reviewer

- Decide whether to accept the documented direct-calibration-command dependency
  gap or request an alternate targeted calibration verification through the test
  harness.
