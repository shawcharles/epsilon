# Architect Brief: Phase 25 Focused Test File Harness

## Step Name

Phase 25: Focused Test File Harness.

## Objective

Make focused test-file runs use the package test environment so files with
test-only imports, especially `test/model/calibration.jl`, can run without a
temporary manual environment or broad model-layer run.

## Files In Scope

- `test/runtests.jl`
- `Makefile`
- `CHANGELOG.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/25-focused-test-file-harness/PLAN.md`
- `.planning/phases/25-focused-test-file-harness/handoff/*`

## Files Out Of Scope

- `src/`
- `Project.toml` runtime dependency changes
- `docs/src/api.md`
- model, calibration, inference, optimisation, plotting, pipeline, or
  validation implementation files
- existing test assertion changes unless required to verify the harness itself

## Constraints

- Preserve existing layer selectors.
- Preserve no-argument full-suite behaviour.
- Run selected test files only when explicit file selectors are passed.
- Keep file selectors bounded to the repository `test/` tree.
- Reject invalid selectors clearly.
- Reject mixed layer/file selectors clearly.
- Selector normalisation must support optional leading `test/` and optional
  trailing `.jl`, then canonicalise under `test/`.
- File selectors must resolve to files; directories, missing files,
  `test/runtests.jl`, absolute outside paths, and parent traversal are invalid.
- Do not make test-only dependencies runtime dependencies.
- Do not run the full suite unless scope expands.

## Acceptance Criteria

- `Pkg.test(; test_args=["test/model/calibration.jl"], julia_args=["--depwarn=yes"])`
  runs only `test/model/calibration.jl` in the package test environment.
- `Pkg.test(; test_args=["model/types.jl"], julia_args=["--depwarn=yes"])`
  runs only `test/model/types.jl` in the package test environment.
- `Pkg.test(; test_args=["api_exports", "basic"])` still works.
- `make test-file FILE=test/model/calibration.jl` works.
- No runtime/model source files are edited.

## Verification Commands

```bash
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["test/model/calibration.jl"], julia_args=["--depwarn=yes"])'
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["model/types.jl"], julia_args=["--depwarn=yes"])'
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["api_exports", "basic"])'
make test-file FILE=test/model/calibration.jl
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["missing/nope.jl"])' # must fail
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["test/model"])' # must fail
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["test/runtests.jl"])' # must fail
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["../Project.toml"])' # must fail
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["/tmp/outside.jl"])' # must fail
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["model", "test/model/calibration.jl"])' # must fail
julia --project=@runic -m Runic --check --diff test/runtests.jl
git diff --check
```
