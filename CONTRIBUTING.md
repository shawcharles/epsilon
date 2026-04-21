# Contributing

Epsilon is being built as a Julia package first, and an MMM framework second.
That ordering matters: if the package structure, tests, docs, and API hygiene are
weak, the statistical work will become difficult to maintain.

## Development Workflow

1. Read [`TECHNICAL-STANDARDS.md`](TECHNICAL-STANDARDS.md) before opening a PR.
2. Keep changes scoped to one concern: API, implementation, tests, or docs.
3. Add or update tests with every behavior change.
4. Update planning docs in [`.planning/`](.planning/README.md) when architecture
   or milestone assumptions change.

## Local Commands

```bash
make instantiate
make format
make test
make docs
```

## Pull Request Expectations

- Formatting passes with Runic.
- Tests pass on supported Julia versions.
- Public APIs are documented.
- Any deviation from Abacus behavior is explicit and justified.
