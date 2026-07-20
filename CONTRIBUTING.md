# Contributing

Epsilon is a Julia package for Bayesian marketing mix modelling. Contributions
should keep the package structure, tests, documentation, and public API clear
enough for statistical behaviour to remain inspectable and maintainable.

## Development Workflow

1. Read [`TECHNICAL-STANDARDS.md`](TECHNICAL-STANDARDS.md) before opening a PR.
2. Keep changes scoped to one concern: API, implementation, tests, or docs.
3. Add or update tests with every behavior change.
4. Update public documentation when user-facing behaviour or supported paths
   change.

## Local Commands

```bash
make instantiate
make format-check
make smoke
make test-file FILE=test/api_exports.jl
make docs
```

Use `make test` for release confirmation or changes that plausibly affect
multiple subsystems.

## Pull Request Expectations

- Formatting passes with Runic.
- Local tests and docs pass before review.
- Public APIs are documented.
- Statistical behaviour changes are explicit, documented, and covered by tests.

## Documentation Consistency

Epsilon enforces documentation consistency through its test suite (`test/api_exports.jl`). This guards the `api.md` inventory table against the code's export list, and heavily checks cross-document consistency of support claims (such as which features are or are not supported) across `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `TECHNICAL-STANDARDS.md`, and all `docs/src/*.md` pages.

If you edit wording related to feature support boundaries or rename an exported function, you might see local tests fail. This is intentional: update the claims in all affected files simultaneously so the repository speaks with one voice. 
