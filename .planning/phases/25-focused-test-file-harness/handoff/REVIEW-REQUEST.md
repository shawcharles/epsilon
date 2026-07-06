# Review Request: Phase 25 Focused Test File Harness

## Review Focus

Please review the focused test-file harness implementation from a senior Julia
library and test-infrastructure perspective.

## Intended Behaviour

- Existing layer selectors remain exact and unchanged.
- No-argument `Pkg.test()` remains the full suite plus Aqua/doctest path.
- Explicit file selectors run only selected files under `test/`.
- File selectors support optional leading `test/` and optional trailing `.jl`.
- Invalid selectors fail clearly before unrelated tests run.
- Mixed layer/file mode is rejected.
- `make test-file FILE=...` runs the selected file through `Pkg.test` with
  `--depwarn=yes`.

## Must Check

- Selector canonicalisation cannot escape `test/`.
- `test/runtests.jl` cannot recursively select itself.
- Directory selectors and missing files fail clearly.
- Parent traversal is rejected explicitly.
- Absolute paths outside `test/` are rejected.
- Mixed layer/file selectors cannot silently widen or narrow test scope.
- No runtime/model source files were edited.
- Planning and changelog wording does not imply model/runtime behaviour or
  Abacus parity changes.

## Verification Already Run

```bash
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["test/model/calibration.jl"], julia_args=["--depwarn=yes"])'
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["model/types.jl"], julia_args=["--depwarn=yes"])'
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["api_exports", "basic"], julia_args=["--depwarn=yes"])'
make test-file FILE=test/model/calibration.jl
julia --project=@runic -m Runic --check --diff test/runtests.jl
git diff --check
```

Negative selector checks passed for missing file, directory selector,
recursive `test/runtests.jl`, parent traversal, absolute outside path, and
mixed layer/file mode.
