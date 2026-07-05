# Technical Standards

This document sets the engineering baseline for `Epsilon.jl`. The goal is a
codebase that feels like a serious Julia package for scientific computing.

## Decisions

### 1. Style Guide Baseline

Yes: we should adopt the official Julia style guide as the foundation and use the
SciML Style Guide as the operational default for day-to-day code review.

That gives us two useful properties:

- Julia-manual compatibility for broad ecosystem conventions.
- SciML-grade discipline for scientific and numerically sensitive code.

When the two are both silent, we optimize for readability, type stability, and
maintainability over cleverness.

### 2. Formatting

We will use `Runic.jl` as the enforced formatter.

Rationale:

- It is the formatter recommended by the current SciML Style Guide.
- Zero-configuration formatting reduces repository-level style drift.
- Local formatting checks avoid debating whitespace in reviews.

### 3. Naming and API Conventions

- Modules, structs, and abstract types use `CamelCase`.
- Functions and variables use `snake_case`.
- Mutating functions end in `!`.
- Abstract types begin with `Abstract`.
- Internal APIs stay unexported until intentionally promoted.
- Avoid type piracy.

### 4. Package Structure

The package follows the standard Julia library layout:

- `Project.toml` at the root with tight `[compat]` bounds.
- `src/Epsilon.jl` as the only package entry point.
- `test/` for unit, integration, and parity checks.
- `docs/` for `Documenter.jl`.
- `benchmark/` for performance tracking.
- `.planning/` for project-management artifacts, not user documentation.

We will not write package state into the repository or package directory at
runtime. Generated outputs belong in user-specified locations.

### 5. Dependency Policy

- Prefer stdlib before adding third-party packages.
- Every non-trivial dependency must have a clear architectural owner.
- Add tight `[compat]` bounds from the start.
- Keep the main package lean; optional features can become extensions later.

### 6. Testing Standard

- Every public feature gets tests.
- Statistical behavior gets comparison tests against Abacus fixtures where the
  semantics of the Epsilon surface and the Abacus reference genuinely match.
- `runtests.jl` stays thin and delegates to focused test files.
- `Aqua.jl` is part of the default quality gate.
- `Documenter.doctest` is part of the test suite for public examples.
- Randomized tests must set explicit seeds.

Once the test suite grows, group files by package layer:

- `test/transforms/`
- `test/distributions/`
- `test/model/`
- `test/mmm/`
- `test/inference/`
- `test/postmodel/`
- `test/optimization/`
- `test/pipeline/`

### 7. Documentation Standard

- Every exported symbol needs a docstring.
- Usage examples should be runnable `jldoctest` blocks where practical.
- Architecture decisions belong in `.planning/`, not scattered across PR threads.
- Any public behavior change must update docs in the same change.

### 8. Quality Gate Standard

Required local quality-gate checks:

- `make check` for routine scoped iteration: touched-file Runic formatting plus
  the current high-churn model-layer test lane.
- `make check-optimization`, `make check-validation`, or another focused test
  lane when the active slice touches those subsystems.
- `make check-full` before phase-closing checkpoint commits, shared namespace or
  export-surface changes, and final pre-merge confirmation. This runs
  touched-file Runic formatting, the full `Pkg.test()` suite, Aqua quality
  checks, doctests, and docs build.
- `make check-release` for the stricter release gate once repo-wide Runic drift
  has been cleared. This adds the repo-wide `make format-check` requirement to
  the full test/docs gate.

Deferred until the model core exists:

- JET static analysis
- benchmark regression tracking
- code coverage thresholds

### 9. Performance and Numerical Rules

- Prefer generic code over concrete `Array`-only APIs unless profiling proves
  otherwise.
- Keep hot-path functions type-stable.
- Avoid mutation in autodiff-sensitive transforms unless we have proof it is safe.
- Benchmark before micro-optimizing.
- Honest numerical comparison against Abacus is more important than aesthetic
  refactors, but methodological coherence wins if literal upstream fidelity
  would produce a weaker or less truthful bounded design.

### 10. Configuration and Reproducibility

- YAML remains the external configuration format for migration compatibility.
- Config schemas must be versioned once they become user-facing.
- Example configs and fixtures should be committed and used in tests.
- Minimum supported Julia version is `1.10`.

## Short Version

If a reviewer asks whether a change is "the Epsilon way", the default checks are:

1. Is it idiomatic Julia?
2. Does it follow SciML-style naming and structure?
3. Is it testable and autodiff-safe?
4. Does it preserve or improve methodological coherence, and is any Abacus
   comparison claim still honest?
5. Is the public API still small and intentional?

## References

- Julia Style Guide: <https://docs.julialang.org/en/v1/manual/style-guide/>
- SciML Style Guide: <https://docs.sciml.ai/SciMLStyle/dev/>
- Pkg package creation guidance: <https://pkgdocs.julialang.org/v1/creating-packages/>
- Documenter.jl: <https://documenter.juliadocs.org/stable/>
- Aqua.jl: <https://juliatesting.github.io/Aqua.jl/v0.8/>
- JET.jl: <https://aviatesk.github.io/JET.jl/stable/>
