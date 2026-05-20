# Phase 14: Abacus Parity Recovery

## Goal

Turn the broad Epsilon scaffold into a fixture-backed Julia port of the Abacus
statistical MMM core, starting with the `timeseries` demo-style path and then
expanding to `geo_panel` and `geo_brand_panel`.

This phase is governed by `.planning/ABACUS-PARITY-LEDGER.md`. A module or API
counts as release-ready only when the corresponding ledger row is `ported` or
explicitly documented as `native` or `deferred`.

## Non-Goals

- Do not chase AI advisor, Plotly Dash, hosted dashboard, or docs-site parity.
- Do not implement downstream scenario-planning UI while core model, replay,
  optimization, and artifact parity are still unsettled; scenario-planning
  methodology remains in scope after those foundations are stable.
- Do not add new Epsilon-only methodology while parity gaps remain unresolved.
- Do not rely on posterior draw equality between PyMC and Turing as a parity
  gate. Compare deterministic preprocessing, model specification, replay,
  artifact schemas, and posterior-derived summaries from controlled fixtures.

## Invariants

- Python can be used to export deterministic Abacus fixtures, but Julia tests
  must consume committed fixture files and must not call Python at runtime.
- Public release language must distinguish `ported`, `native`, `scaffolded`,
  `missing`, and `deferred`.
- Config and data compilation come before model feature expansion.
- Panel parity means panel-indexed parameters by default unless the prior
  explicitly encodes pooling.

## Plan 14-01: Timeseries Config/Data Fixture Spine

Status: completed 2026-05-10.

**Objective:** Make Abacus `timeseries` demo config/data compilation observable
and testable from Epsilon.

Tasks:

- Locate the Abacus `timeseries` demo config and dataset in
  `/home/user/Documents/GITHUB/tandpds/abacus/data/demo/`.
- Extend `scripts/export_abacus_fixtures.py` to export deterministic Julia
  literals for:
  - normalized config fields
  - channel, control, date, target, event, and holiday columns
  - design matrices
  - transformed media tensors before sampling
  - coordinate metadata and dimension names
  - expected pipeline stage names and manifest keys
- Commit fixtures under `test/fixtures/abacus/timeseries/`.
- Add Julia tests comparing Epsilon config/data compilation to those fixtures.

Exit criteria:

- `make test` includes a focused timeseries config/data parity test.
- Any mismatches are classified as implementation bugs, intentional
  Julia-native differences, or unsupported Abacus features.

## Plan 14-02: Timeseries Model And Replay Parity

Status: completed 2026-05-10 for the deterministic `timeseries` replay gate.

**Objective:** Make the Epsilon `timeseries` path produce stable model and
posterior replay artifacts from the compiled spec.

Tasks:

- Compare prior names, parameter dimensions, transform ownership, target scale,
  and likelihood structure against Abacus fixture metadata.
- Repair fitted prediction-state replay for train, holdout, and new-data paths.
- Add deterministic replay tests for posterior predictive means,
  contributions, decompositions, response curves, and metric tables using
  controlled posterior fixtures.
- Mark holiday behavior as Abacus-compatible or Epsilon-native explicitly.

Exit criteria:

- The `timeseries` path has ledger rows promoted from `scaffolded` to
  `ported` or `native` with test references.

## Plan 14-03: One-Dimensional Panel Parity

Status: completed 2026-05-18 for the deterministic `geo_panel` config/model
and replay gate. The config/data fixture gate and panel-indexed core semantics
landed 2026-05-10; panel Fourier seasonality and native pooled holiday design
support landed 2026-05-10; bounded panel contribution/decomposition replay
coverage landed 2026-05-18.

**Objective:** Bring `geo_panel` onto the same fixture-backed path after the
time-series spine is stable.

Tasks:

- [x] Export `geo_panel` Abacus fixtures for config/data compilation, panel keys,
  coordinate metadata, and transformed media tensors.
- [x] Align Epsilon panel data containers with Abacus panel-indexed parameter
  semantics.
- [x] Verify that hierarchical pooling is represented through priors rather than
  implicit defaults.
- [x] Add panel Fourier seasonality and native pooled automatic holiday support
  for the accepted one-dimensional `geo_panel` config/data gate.
- [x] Add panel posterior replay tests for prediction and contribution artifacts.

Exit criteria:

- `geo_panel` compiles, fits, replays, and emits stable artifact schemas through
  Epsilon without unsupported hidden feature flags.

## Plan 14-04: Multi-Dimensional Panel Parity

Status: completed 2026-05-18 for the `geo_brand_panel` config/data,
dimension-order, model-spec, runtime artifact-schema, and deterministic
contribution/decomposition replay gates. Response, optimization, plotting, and
pipeline artifacts remain separate slices. The first response slice has since
landed panel-cell historical-scaling response/saturation/adstock curves and
marketing metrics for `geo_brand_panel`.

**Objective:** Extend the stable panel core to the `geo_brand_panel` demo-style
path.

Tasks:

- [x] Export `geo_brand_panel` fixtures for dimensions, coordinates, media tensors,
  and model-spec metadata.
- [x] Generalize panel internals where current code assumes exactly one panel
  dimension.
- [x] Add tests for stable dimension ordering and artifact schemas.
- [x] Add deterministic multidimensional contribution/decomposition replay with
  flat panel-cell and coordinate-column summary semantics.

Exit criteria:

- `geo_brand_panel` passes config/data, artifact-schema, and replay gates.
- Any unsupported multi-dimensional modeling features are explicit ledger rows.

## Plan 14-05: Pipeline Manifest And Artifact Parity

Status: completed 2026-05-19.

**Objective:** Rebuild release readiness around demo acceptance rather than
historical phase completion.

Tasks:

- [x] Decide panel response/metric semantics: panel diagnostics are
  panel-cell/channel surfaces, aggregate budget semantics require an explicit
  allocation policy, and `PanelMMM` curve replay uses an explicit
  `delta_grid` historical-scaling contract.
- [x] Export the latest local Abacus `timeseries` pipeline contract, including
  manifest keys, stage record keys, stage artifact keys, and stage-local
  filenames.
- [x] Compare Abacus and Epsilon stage directories for the supported bounded
  pipeline stages, while keeping AI advisor stages deferred.
- [x] Add the first fixture-backed `timeseries` pipeline parity test for Stage
  `00` metadata artifacts and manifest artifact keys.
- [x] Expand `timeseries` artifact-key parity through Stage `20` fit and Stage
  `30` assessment, preserving Julia-native artifact formats for PyMC/NetCDF
  equivalents.
- [x] Expand `timeseries` artifact parity through validation, decomposition,
  diagnostics, curves, and optimization.
- [x] Add `geo_panel` pipeline Stage `00` metadata/manifest tests and Stage
  `20` fit artifact-key tests with explicit skipped unsupported panel stages.
- [x] Move the metadata/fit contract to `geo_brand_panel` with
  multidimensional panel-cell metadata and fit artifact-key tests.
- [x] Add panel Stage `30` assessment artifact-key tests and panel-aware
  observed/fitted, residual, posterior predictive, and plot artifacts for
  `geo_panel` and `geo_brand_panel`.
- [x] Expand panel pipeline parity to Stage `40` decomposition artifacts for
  `geo_panel` and `geo_brand_panel`.
- [x] Expand panel pipeline parity to Stage `50` diagnostics artifacts for
  `geo_panel` and `geo_brand_panel`.
- [x] Expand panel pipeline parity to Stage `60` response-curve artifacts for
  `geo_panel` and `geo_brand_panel`.
- [x] Document Stage `35` panel holdout validation as deferred for v1 unless a
  concrete methodological requirement and fixture-backed contract are added.
- [x] Extend Stage `70` historical-share optimization coverage from
  `geo_panel` to `geo_brand_panel`.
- [x] Implement bounded Stage `05` prior-sensitivity planning with manual and
  `conservative_mmm` scenario config emission plus human/LLM-safe manifests.
- [x] Update docs so users can see which rows are `ported`, `native`,
  `scaffolded`, `missing`, or `deferred`.

Exit criteria:

- Release docs point at ledger-backed acceptance tests.
- The pipeline can emit stable artifacts for every accepted demo-style path.

## Verification

Run after each plan:

```bash
make test
make docs
make format-check
```

When fixture exporters change, also run:

```bash
PYTHONNOUSERSITE=1 python scripts/export_abacus_fixtures.py
```
