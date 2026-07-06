# Phase 25: Focused Test File Harness

**Status:** Landed.

## Context

Phase 24 exposed a verification friction point: direct root-project execution of
`test/model/calibration.jl` cannot load test-only dependencies such as
`ForwardDiff` and `ReverseDiff`. The file passes when run inside a package test
environment, but the current harness only supports broad layer selectors such
as `model`, which can drift into slower unrelated model tests.

The goal is not to move test-only dependencies into runtime `[deps]`. The goal
is to make focused test-file execution use `Pkg.test`'s test environment.

## Objective

Add a focused package-test file selector so maintainers can run one test file
inside the proper test environment, including `[extras]`, without running the
full suite or the whole model layer.

## In Scope

- Extend `test/runtests.jl` to accept explicit test-file selectors via
  `Pkg.test(; test_args=[...])`.
- Preserve existing layer selectors such as `basic`, `api_exports`, `model`,
  `pipeline`, and `validation`.
- Add a Makefile helper for focused file execution.
- Document the preferred command in planning state and changelog.
- Add focused tests for the selector parser if the implementation makes that
  practical without bootstrapping the full suite.
- Phase-local Three Man Team handoff files.

## Out Of Scope

- Moving `ForwardDiff`, `ReverseDiff`, `Aqua`, or `Documenter` into runtime
  `[deps]`.
- Changing model, calibration, inference, pipeline, plotting, or optimisation
  semantics.
- Changing existing test files' assertions.
- Rewriting the whole test harness.
- Running the full suite unless the implementation touches shared namespace
  behaviour beyond selector routing.

## Proposed Interface

Keep current layer commands unchanged:

```julia
using Pkg
Pkg.test(; test_args = ["model"])
```

Add focused file commands:

```julia
using Pkg
Pkg.test(; test_args = ["test/model/calibration.jl"], julia_args = ["--depwarn=yes"])
Pkg.test(; test_args = ["model/calibration.jl"], julia_args = ["--depwarn=yes"])
Pkg.test(; test_args = ["model/calibration"], julia_args = ["--depwarn=yes"])
```

Add a Makefile helper:

```bash
make test-file FILE=test/model/calibration.jl
```

The Makefile helper should pass `--depwarn=yes` so Phase 24 deprecation tests
are meaningful. Direct `julia --project=. test/model/calibration.jl` should no
longer be the recommended command for files that import test-only dependencies.

Selector grammar:

- Layer selectors are exact existing layer names: `basic`, `api_exports`,
  `distributions`, `model`, `inference`, `postmodel`, `optimization`,
  `scenario_planner`, `pipeline`, `plotting`, `validation`, and `transforms`.
- File selectors must identify a single `.jl` file under `test/`.
- File selectors may include an optional leading `test/`.
- File selectors may omit the trailing `.jl`; the harness should add it before
  canonical validation.
- File selectors must canonicalise under the repository `test/` directory.
- File selectors must resolve to `isfile`.
- `test/runtests.jl` is explicitly rejected to avoid recursive harness calls.
- Directory selectors are rejected.
- Absolute paths outside `test/` and parent traversal such as
  `../Project.toml` are rejected.
- Mixed layer/file mode is rejected. For example,
  `Pkg.test(; test_args=["model", "test/model/calibration.jl"])` must fail
  clearly instead of silently narrowing to the file or widening to the layer.

## Design Constraints

1. File selectors must be bounded to files under `test/`.
2. File selectors must not include `test/runtests.jl` recursively.
3. Invalid file selectors must fail clearly before running unrelated tests.
4. File selectors and layer selectors must not be mixed.
5. If file selectors are present, only selected files run.
6. Existing no-argument `Pkg.test()` behaviour must remain full suite plus Aqua
   and doctest.
7. Existing layer-only `Pkg.test(; test_args=["model"])` behaviour must remain
   unchanged.

## Verification Plan

Targeted only:

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

Do not run the full suite for this harness cleanup unless the implementation
changes shared imports, export inventory, or package-wide test semantics.

## Tasks

### Task 25-01: Plan Review

Acceptance criteria:

- [x] This plan is reviewed by an independent subagent before implementation.
- [x] Must Fix review items are resolved before harness edits start.
- [x] The reviewed plan keeps Phase 25 bounded to test-harness ergonomics.

Verification:

- [x] `.planning/phases/25-focused-test-file-harness/handoff/ARCHITECT-BRIEF.md`
      matches the reviewed plan.
- [x] `.planning/phases/25-focused-test-file-harness/handoff/REVIEW-FEEDBACK.md`
      records the plan review result.

### Task 25-02: File Selector Harness

Acceptance criteria:

- [x] `test/runtests.jl` accepts file selectors under `test/`.
- [x] Existing layer selectors keep their current behaviour.
- [x] Invalid file selectors fail clearly.
- [x] Mixed layer/file selectors fail clearly.
- [x] No-argument full-suite semantics remain unchanged.

Verification:

```bash
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["test/model/calibration.jl"], julia_args=["--depwarn=yes"])'
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["model/types.jl"], julia_args=["--depwarn=yes"])'
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["missing/nope.jl"])' # must fail
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["test/model"])' # must fail
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["test/runtests.jl"])' # must fail
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["../Project.toml"])' # must fail
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["/tmp/outside.jl"])' # must fail
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["model", "test/model/calibration.jl"])' # must fail
```

### Task 25-03: Makefile Helper And Planning Closure

Acceptance criteria:

- [x] `make test-file FILE=test/model/calibration.jl` runs the selected file in
      the package test environment.
- [x] `CHANGELOG.md`, `.planning/ROADMAP.md`, and `.planning/STATE.md` record
      the harness cleanup conservatively.
- [x] No model/runtime source files are edited.

Verification:

```bash
make test-file FILE=test/model/calibration.jl
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["api_exports", "basic"])'
julia --project=@runic -m Runic --check --diff test/runtests.jl
git diff --check
```

### Task 25-04: Implementation Review And Commit

Acceptance criteria:

- [x] Builder writes
      `.planning/phases/25-focused-test-file-harness/handoff/BUILD-LOG.md`.
- [x] Builder writes
      `.planning/phases/25-focused-test-file-harness/handoff/REVIEW-REQUEST.md`.
- [x] Reviewer writes
      `.planning/phases/25-focused-test-file-harness/handoff/REVIEW-FEEDBACK.md`.
- [x] All Must Fix items are resolved before commit.
- [x] The commit includes only intended Phase 25 files.

Verification:

```bash
git status --short
git diff --stat
git diff --check
```
