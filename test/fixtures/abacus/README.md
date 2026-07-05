# Abacus Fixtures

This directory stores parity fixtures exported from the local Abacus checkout at
`/home/user/Documents/GITHUB/tandpds/abacus`.

Regenerate the transform fixtures with:

```bash
PYTHONNOUSERSITE=1 python scripts/export_abacus_fixtures.py
```

`PYTHONNOUSERSITE=1` avoids mixing the Abacus/PyTensor environment with
user-site NumPy packages.

Regenerate the Phase 7 post-model summary fixtures with:

```bash
python scripts/export_abacus_postmodel_fixtures.py
```

Regenerate the Phase 8 optimization fixtures with:

```bash
python scripts/export_abacus_optimization_fixtures.py
```

Regenerate the Phase 11 compact validation fixtures with:

```bash
python scripts/export_abacus_validation_fixtures.py
```

The Phase 11 exporter assumes a local Abacus checkout at:

- `/home/user/Documents/GITHUB/tandpds/abacus`

It retains compact validation fixtures rooted in the local Abacus checkout for:

- `VAL-TS-00-MCMC`
- `VAL-TS-04-MCMC`

under:

- `test/fixtures/abacus/validation/`

`VAL-TS-00-MCMC` remains fully Abacus-derived and is part of the current
Abacus-reference release gate. `VAL-TS-04-MCMC` is retained as a compact
cross-framework reference case, but its current config is now locally adapted
to Epsilon’s native automatic holiday path, so the active validation harness
treats it as a bounded Epsilon-native/reference row rather than as literal
Abacus parity.

The other bounded rows (`VAL-P-00-MCMC`, `VAL-PIPE-TS-00-MCMC`) are not
exported from Abacus and remain regression fixtures / integration checks on the
Epsilon side.

The exporters write compact Julia or summary-sized fixture artifacts so the
Epsilon test suite can consume them directly without adding extra parsing
dependencies or giant draw dumps to the repo.

Each generated Julia fixture should record its exporter, local Abacus root, and
Abacus git revision in the file header. A `(dirty)` suffix means the local
Abacus checkout had uncommitted changes when that fixture was exported. Treat
that header as the per-file provenance source of truth when reviewing fixture
freshness; this README records the workflow, not a single global Abacus
revision.

Phase 14 parity recovery adds a stricter fixture spine for the bundled Abacus
demo-style paths:

- `timeseries`
- `geo_panel`
- `geo_brand_panel`

Those fixtures should cover config/data normalization, design matrices,
transformed media tensors, coordinate metadata, and pipeline manifest schemas
before model, post-model, and optimization rows are promoted from `scaffolded`
to `ported`.

Current Phase 14 generated demo fixtures:

- `timeseries/config_data.jl`: accepted config/data plus controlled replay
  fixture for the bounded time-series row. It also records the latest local
  Abacus `timeseries_*` pipeline contract: manifest top-level keys, stage
  record keys, stage artifact keys, and stage-local artifact filenames.
- `geo_panel/config_data.jl`: accepted config/data and transform fixture for
  the one-dimensional panel row, including panel-wise scaling and
  panel-indexed alpha, beta-media, intercept, sigma, Fourier seasonality, and
  pooled automatic holiday semantics. Abacus `prophet_component` holiday config
  is normalized to Epsilon's native pooled automatic holiday design before
  replay parity is attempted. It also records the latest local Abacus
  `geo_panel_*` pipeline contract for Stage `00` metadata/manifest parity and
  Stage `20` fit artifact-key parity, Stage `30` assessment artifact-key
  parity, Stage `40` decomposition artifact-key parity, and Stage `50`
  diagnostics artifact-key parity, and Stage `60` response-curve artifact-key
  parity.
- `geo_brand_panel/config_data.jl`: accepted config/data and transform fixture
  for the multidimensional panel row. Epsilon stores the panel grid on a
  deterministic flattened panel-cell axis while retaining the Abacus
  `("geo", "brand")` dimension order and coordinate values in model metadata;
  controlled contribution/decomposition replay is covered in
  `test/validation/geo_brand_panel_model_replay.jl`. It also records the
  latest local Abacus `geo_brand_panel_*` pipeline contract for Stage `00`
  metadata/manifest parity, Stage `20` fit artifact-key parity, Stage `30`
  assessment artifact-key parity, Stage `40` decomposition artifact-key
  parity, Stage `50` diagnostics artifact-key parity, and Stage `60`
  response-curve artifact-key parity.
