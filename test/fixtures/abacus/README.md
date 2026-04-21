# Abacus Fixtures

This directory stores parity fixtures exported from the local Abacus checkout at
`/home/user/Documents/GITHUB/tandpds/abacus`.

Regenerate the transform fixtures with:

```bash
python scripts/export_abacus_fixtures.py
```

The exporter writes Julia fixture files so the Epsilon test suite can consume
them directly without adding extra parsing dependencies.
