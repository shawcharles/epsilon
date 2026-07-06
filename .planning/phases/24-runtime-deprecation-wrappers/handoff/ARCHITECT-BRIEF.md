# Architect Brief: Phase 24 Runtime Deprecation Wrappers

## Step Name

Phase 24: Runtime Deprecation Wrappers.

## Objective

Implement the Phase 23 design for six validation-helper deprecation candidates:
public direct calls should warn, while constructors/builders/loaders should use
warning-free internal helpers and stay silent.

## Files In Scope

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
- `.planning/phases/24-runtime-deprecation-wrappers/handoff/*`

## Files Out Of Scope

- `src/Epsilon.jl`
- export inventory changes in `docs/src/api.md`
- broad docs restructuring
- unrelated tests
- benchmark files
- scenario planner, pipeline, inference, optimization, or panel validation
  implementation

## Constraints

- Do not remove, rename, reorder, or unexport any symbol.
- Preserve validation predicates, return values, exception types, and exact
  exception messages.
- Use warning-free `_validate_*` helpers for internal constructor/builder/loader
  paths.
- Use public wrappers with `Base.depwarn` for direct public validator calls.
- Keep warnings scoped to direct public calls.
- Tests must assert warnings explicitly; do not rely on visible stderr.
- Invalid direct public validator tests must assert exact `ArgumentError`
  message text.
- All six public wrappers need positive and invalid direct-call coverage.
- Keep verification targeted unless scope expands.

## Acceptance Criteria

- Six public validators warn on direct calls.
- Six public validators still return `nothing` for valid inputs.
- Invalid direct public calls preserve exact `ArgumentError` messages.
- Replacement workflows do not warn.
- API export/docstring guard still passes.
- Planning/changelog/ledger wording is conservative.

## Verification Commands

```bash
julia --depwarn=yes --project=. test/model/calibration.jl
julia --depwarn=yes --project=. test/model/types.jl
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["api_exports", "basic"])'
julia --project=@runic -m Runic --check --diff src/mmm/calibration.jl src/model/types.jl test/model/calibration.jl test/model/types.jl
git diff --check
```

Do not run the full suite unless implementation unexpectedly touches exports,
shared test namespace behaviour, or broader package infrastructure.
