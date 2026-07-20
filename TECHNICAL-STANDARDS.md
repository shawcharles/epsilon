# Technical Standards

This document defines the public engineering baseline for `Epsilon.jl`. It is
kept at the repository root so contributors can see the package standards
before opening code, documentation, or release changes.

## Scope

Epsilon is a Julia-native Bayesian marketing mix modelling library. The package
focuses on local, config-driven MMM workflows, structured analysis artifacts,
and plain Julia APIs.

Epsilon does not ship a dashboard, hosted UI, AI advisor, or variational
inference path. The maintained fitting backend is Turing/NUTS MCMC.

## Style And Formatting

- Follow the Julia manual style guide and SciML style guide where they apply.
- Use `Runic.jl` for Julia source formatting.
- Prefer readable, type-stable Julia over clever compactness.
- Keep comments short and reserve them for non-obvious intent.

Run formatting checks locally:

```bash
make format-check
```

## Naming And API Design

- Modules, structs, and abstract types use `CamelCase`.
- Functions and variables use `snake_case`.
- Mutating functions end in `!`.
- Abstract types begin with `Abstract`.
- Internal APIs stay unexported until deliberately promoted.
- Avoid type piracy.
- Keep the public API small, documented, and stable enough for real users.

## Repository Layout

- `Project.toml` is the package manifest with tight `[compat]` bounds.
- `src/Epsilon.jl` is the package entry point.
- `test/` contains focused unit, integration, and workflow tests.
- `docs/` contains the Documenter.jl source.
- `data/demo/` contains maintained demo datasets and configs.
- `scripts/` contains local maintenance scripts.

Generated model outputs belong under a user-selected output directory, not in
package source.

## Dependencies

- Prefer Julia stdlib functionality before adding dependencies.
- Every non-trivial dependency must have a clear owner and purpose.
- Add or update `[compat]` bounds with dependency changes.
- Keep the core package lean; optional feature surfaces should use extensions
  where practical.

## Testing

- Every public feature needs behaviour-focused tests.
- Randomised tests must set explicit seeds.
- `test/runtests.jl` should stay thin and delegate to focused test files.
- `Aqua.jl` and `Documenter.doctest` are part of the local quality gate.
- Use scoped checks for routine work; reserve full-suite checks for broad
  release, namespace, or cross-subsystem changes.

Useful local commands:

```bash
make smoke
make test-file FILE=test/api_exports.jl
make test-model
make docs
```

## Numerics And Modelling

- Prefer generic array code unless profiling justifies narrower types.
- Keep hot-path functions type-stable.
- Validate finite inputs and domain constraints at public boundaries.
- Be careful with mutation in autodiff-sensitive code.
- Preserve methodological coherence over convenience when API and statistical
  design choices conflict.
- Benchmark before micro-optimising, and treat local timing results as
  environment-specific engineering evidence.

## Configuration And Artifacts

- YAML is the supported external configuration format.
- Config schemas should fail clearly on unsupported keys or invalid values.
- CSV demo data and holidays files should remain small, inspectable, and
  suitable for local smoke tests.
- Julia `.jls` artifacts are trusted-local serialisation outputs, not portable
  interchange files and not safe to load from untrusted sources.

## Release Checks

Before a public release candidate, run the relevant local gates:

```bash
make format-check
make smoke
make docs
```

Use the full test suite only for final release confirmation or changes with
plausible cross-file effects:

```bash
make test
```

## Short Version

When reviewing an Epsilon change, ask:

1. Is it idiomatic Julia?
2. Is the public API still small and intentional?
3. Is the behaviour documented and tested?
4. Is it autodiff-safe and numerically guarded?
5. Does it improve or preserve methodological coherence?

## References

- Julia Style Guide: <https://docs.julialang.org/en/v1/manual/style-guide/>
- SciML Style Guide: <https://docs.sciml.ai/SciMLStyle/dev/>
- Pkg package creation guidance: <https://pkgdocs.julialang.org/v1/creating-packages/>
- Documenter.jl: <https://documenter.juliadocs.org/stable/>
- Aqua.jl: <https://juliatesting.github.io/Aqua.jl/v0.8/>
