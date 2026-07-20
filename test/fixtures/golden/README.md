# Golden Fixtures

This directory contains deterministic fixture data used by the test suite.
The fixtures are retained as compact Julia literals, YAML files, CSV files, and
small JSON/CSV summaries so tests can run without external services, Python
runtime dependencies, or large draw dumps.

## Purpose

Golden fixtures lock expected numerical behaviour for:

- transform primitives,
- config and data loading,
- calibration payloads,
- HSGP helper semantics,
- post-model summaries,
- optimisation summaries,
- pipeline artifact contracts, and
- compact validation workflows.

The fixture values should be treated as regression evidence for Epsilon's
current semantics. They are not public API, release claims, or a benchmark
suite.

## Maintenance

- Keep fixture files deterministic and reviewable.
- Prefer Julia literals where practical.
- Avoid absolute machine-local paths in committed fixture files.
- Do not introduce external runtime dependencies into Julia tests.
- If a fixture must be regenerated, document the current Epsilon-native command
  or script in the same change.
