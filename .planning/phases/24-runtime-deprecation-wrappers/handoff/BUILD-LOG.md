# Build Log: Phase 24 Runtime Deprecation Wrappers

## Builder

Codex Builder.

## Scope Implemented

- Split the three calibration public validators into warning-free `_validate_*`
  helpers plus public `Base.depwarn` wrappers.
- Split the three model/data public validators into warning-free `_validate_*`
  helpers plus public `Base.depwarn` wrappers.
- Routed `CalibrationStepConfig`, calibration payload builders,
  `SamplerConfig`, `ModelConfig`, `MMMData`, and config-loader construction
  paths through warning-free helper validation.
- Updated public docstrings for the six public validators to state that they
  are deprecated wrappers and name the migration target.
- Added direct-call warning assertions, valid `nothing` return assertions, exact
  invalid `ArgumentError.msg` assertions, and silent replacement-workflow
  assertions where feasible.
- Updated changelog, roadmap, state, runtime deprecation design, parity ledger,
  and the Phase 24 plan conservatively.

## Changed Files

- `src/mmm/calibration.jl`
- `src/model/types.jl`
- `test/model/calibration.jl`
- `test/model/types.jl`
- `CHANGELOG.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/API-RUNTIME-DEPRECATION-DESIGN.md`
- `.planning/ABACUS-PARITY-LEDGER.md`
- `.planning/phases/24-runtime-deprecation-wrappers/PLAN.md`
- `.planning/phases/24-runtime-deprecation-wrappers/handoff/BUILD-LOG.md`
- `.planning/phases/24-runtime-deprecation-wrappers/handoff/REVIEW-REQUEST.md`

## Verification

- `julia --depwarn=yes --project=. test/model/types.jl` passed.
- Narrow calibration wrapper smoke under root project passed with
  `julia --depwarn=yes --project=. -e ...`, covering valid direct public calls
  for the three calibration validators plus silent builder construction.
- Targeted full calibration-file verification passed through a temporary test
  environment with direct test imports installed:
  `julia --depwarn=yes --project=. -e 'using Pkg; Pkg.activate(; temp=true); Pkg.develop(path=pwd()); Pkg.add(["ForwardDiff", "ReverseDiff", "Distributions"]); include("test/model/calibration.jl")'`.
- `julia --project=. -e 'using Pkg; Pkg.test(; test_args=["api_exports", "basic"])'` passed.
- `julia --project=@runic -m Runic --check --diff src/mmm/calibration.jl src/model/types.jl test/model/calibration.jl test/model/types.jl` passed.
- `git diff --check` passed.
- `julia --depwarn=yes --project=. test/model/calibration.jl` did not reach tests because direct root-project execution cannot load `ForwardDiff`; `ForwardDiff` and `ReverseDiff` are test-target dependencies available through `Pkg.test`, not root-project direct script dependencies.
- A substitute `Pkg.test(; test_args=["model"])` run exercised the changed `types.jl` and `calibration.jl` tests, found and prompted fixing one shared-namespace helper-name warning, then was intentionally interrupted once it reached unrelated sampler-heavy builder tests.

## Known Gaps

- The direct calibration command from the original plan remains blocked by the
  existing root-project dependency surface, not by Phase 24 code. The targeted
  temp-env command above covers the same file without running the full suite.
- Full-suite verification was not run; implementation review agreed it is not
  required for this bounded wrapper slice.
