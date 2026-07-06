# Build Log: Phase 25 Focused Test File Harness

## Scope

Implemented the focused package-test file harness described in
`PLAN.md` without changing runtime/model source files.

## Files Changed

- `test/runtests.jl`
- `Makefile`
- `CHANGELOG.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/25-focused-test-file-harness/PLAN.md`
- `.planning/phases/25-focused-test-file-harness/handoff/*`

## Implementation Notes

- Added bounded file-selector support to `test/runtests.jl`.
- Preserved existing exact layer selectors and no-argument full-suite
  semantics.
- File selectors may use optional leading `test/` and optional trailing `.jl`.
- File selectors are canonicalised under `test/` and must resolve to existing
  files.
- Existing files are also checked by real path, so symlinks under `test/` that
  point outside the test tree, or back to `test/runtests.jl`, are rejected.
- Invalid selectors fail before unrelated tests run:
  - missing file
  - directory selector
  - `test/runtests.jl`
  - parent traversal
  - absolute outside path
  - mixed layer/file mode
- Added `make test-file FILE=...`, passing `--depwarn=yes` through
  `Pkg.test`.

## Verification

Passed:

```bash
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["test/model/calibration.jl"], julia_args=["--depwarn=yes"])'
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["model/types.jl"], julia_args=["--depwarn=yes"])'
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["api_exports", "basic"], julia_args=["--depwarn=yes"])'
make test-file FILE=test/model/calibration.jl
julia --project=@runic -m Runic --check --diff test/runtests.jl
git diff --check
```

The combined negative selector check also passed, confirming expected failure
for:

```text
missing/nope.jl
test/model
test/runtests.jl
../Project.toml
/tmp/outside.jl
model + test/model/calibration.jl
test/__phase25_outside_link.jl
test/__phase25_runtests_link.jl
```

The full suite was intentionally not run. This phase changes selector routing
and local verification ergonomics only; the targeted positive and negative
selector checks exercise the changed dispatch path directly without spending a
full-suite run on unrelated model behaviour.
