# Phase 70: Demo Surface Reconciliation

## Status

Implemented.

## Objective

Reconcile Epsilon's two demo surfaces so users see one clear path for
Epsilon-native config-driven modelling and one clearly secondary path for
historical/reference comparison material:

```text
Primary Epsilon demo workflow: data/demo/*
Historical/reference comparison surface: examples/demo/*
```

This is a usability and claim-hygiene phase. It does not change model
semantics, sampling, pipeline stages, panel support, plotting, optimisation,
benchmarks, release readiness, or reference-parity status.

## Current Evidence

Observed after Phase 69:

- `data/demo/{timeseries,geo_panel,geo_brand_panel}` contains Epsilon-native
  configs plus bundle-local `dataset.csv` and `holidays.csv` files.
- `make smoke-demo-configs` verifies the `data/demo` workflow locally:
  - time-series full pipeline smoke, including the default validation stage;
  - `geo_panel` and `geo_brand_panel` config/data/model-spec checks without
    panel MCMC sampling.
- `examples/demo/` still presents a separate demo surface:
  - `reference/abacus/*` contains copied reference datasets/configs;
  - `epsilon/timeseries/config.yml` is a separate time-series-only runnable
    config;
  - `run_demo.jl` is a thin runner over that older time-series-only path.
- Current public docs mention both surfaces. The wording is truthful, but the
  split can still make a new user wonder which demo path is canonical.

## In Scope

1. Make `data/demo/*` the documented canonical Epsilon-native config-driven
   demo surface.
2. Reword `examples/demo/README.md` so it is explicitly secondary:
   historical/reference comparison material plus a legacy time-series runner,
   not the primary Epsilon demo path.
3. Reword `examples/demo/run_demo.jl` list/path/help text if needed so CLI
   output does not imply that `examples/demo` is the preferred current demo
   workflow.
4. Update root and Documenter docs to route users consistently:
   - quick local examples: `make smoke`;
   - config-driven demos: `make smoke-demo-configs` and `data/demo/*`;
   - historical comparison material: `examples/demo/*`.
5. Add or update focused tests only where text/runner behaviour changes.
6. Add a narrow docs guard if needed to prevent the old primary-demo framing
   from returning.
7. Update changelog and planning state.

## Out of Scope

- Moving, deleting, or renaming fixture/reference files.
- Renaming `examples/demo/reference/abacus` in this phase.
- Renaming `.planning/ABACUS-PARITY-LEDGER.md` or changing ledger statuses.
- Changing `data/demo/*` configs or datasets.
- Changing model construction, sampler settings, pipeline stages, artifact
  schemas, plotting behaviour, optimisation, scenario planning, calibration,
  HSGP/TVP, or panel modelling support.
- Running panel MCMC demos.
- Dashboard/UI work.
- Variational inference.
- Benchmark snapshotting or release-readiness claims.
- Full-suite execution during routine iteration.

## Design Contract

### Canonical User Story

Public docs should point to this order:

1. `make smoke` for the fastest toy/CSV confidence check.
2. `make smoke-demo-configs` for the shipped config-driven demo bundles.
3. Manual `run_pipeline(PipelineRunConfig(config_path = "data/demo/..."))`
   when the user wants to inspect or customise config-driven demo runs.
4. `examples/demo/*` only when the user needs historical/reference comparison
   context.

### Examples Demo Boundary

`examples/demo` may remain in the repository because it still has value for
comparison work and historical provenance. It must not be framed as the main
Epsilon demo path.

Allowed wording:

- "historical/reference comparison surface"
- "legacy comparison runner"
- "time-series-only helper"
- "use `data/demo/*` for current Epsilon-native config-driven demos"

Avoid wording:

- "the demo runner" without qualification
- "canonical demo" for `examples/demo`
- "reference parity" for the native automatic-holiday time-series row
- any suggestion that `geo_panel` or `geo_brand_panel` are runnable through
  `examples/demo/run_demo.jl`

### Tests

If `examples/demo/run_demo.jl` output changes, update
`test/pipeline/demo.jl` only for the changed strings. Do not widen it into a
second smoke harness; Phase 69 already owns the `data/demo` smoke command.

If a docs guard is added, keep it string-level and focused. It should prevent
the confusing "examples/demo is primary" framing from returning, not police all
historical reference wording.

## File Allowlist

Expected implementation files:

- `examples/demo/README.md`
- `examples/demo/run_demo.jl`
- `test/pipeline/demo.jl`
- `README.md`
- `data/README.md`
- `docs/src/index.md`
- `docs/src/supported_paths.md`
- `docs/src/release.md`
- `CHANGELOG.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/70-demo-surface-reconciliation/PLAN.md`

Optional if a focused guard is useful:

- `test/docs_claims.jl` or the existing narrow docs-claim guard file, if one
  already owns this style of check.

Do not stage unrelated local drift:

- `.gitignore`
- `.planning/CRITICAL-REVIEW-2026-07-19.md`

## Tasks

### 70-01: Freeze Demo Surface Contract

- [x] Inventory current public references to `data/demo`, `examples/demo`,
      `run_demo.jl`, and demo-smoke commands.
- [x] Identify exact wording that makes `examples/demo` look primary.
- [x] Acceptance: the implementation diff has a narrow text/runner contract
      before edits begin.

### 70-02: Reword User-Facing Demo Routing

- [x] Update root, data, and Documenter docs so `data/demo/*` is the primary
      config-driven demo route.
- [x] Update `examples/demo/README.md` so its role is historical/reference
      comparison material plus a time-series-only legacy helper.
- [x] Acceptance: a new user can tell which command to run for current
      Epsilon-native config-driven demos.

### 70-03: Align Runner Output And Focused Tests

- [x] Update `examples/demo/run_demo.jl` help/list/path descriptions only if
      they currently imply primary-demo status.
- [x] Update `test/pipeline/demo.jl` for any intentionally changed output.
- [x] Add a focused string guard only if needed.
- [x] Acceptance: existing demo runner behaviour stays time-series-only, but
      its text no longer competes with `data/demo` as the canonical route.

### 70-04: Planning, Verification, And Commit

- [x] Mark this plan implemented.
- [x] Update `.planning/ROADMAP.md` and `.planning/STATE.md`.
- [x] Run scoped verification only:
      - `make test-file FILE=test/pipeline/demo.jl` if runner strings change;
      - any focused docs-claim guard if added;
      - `make format-check-touched` if Julia files change;
      - `git diff --check`.
- [x] Audit changed files against the Phase 70 allowlist before staging:
      `{ git diff --name-only; git ls-files --others --exclude-standard; } | sort`.
- [x] Commit reviewed changes.

Scoped verification completed:

```bash
make test-file FILE=test/pipeline/demo.jl
# passed: 18 / 18

make format-check-touched
# passed

git diff --check
# passed

{ git diff --name-only; git ls-files --others --exclude-standard; } | sort
# showed only Phase 70 allowlist files plus known unrelated local drift:
# .gitignore
# .planning/CRITICAL-REVIEW-2026-07-19.md
```

Independent implementation review cleared the change with no Must Fix or
Should Fix items. The reviewer confirmed that `data/demo/*` is canonical,
`examples/demo/*` is secondary/historical, `run_demo.jl` remains
time-series-only, and the updated non-plot artifact assertions match the
optional plotting boundary.

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Over-correcting by deleting useful reference material | Medium | Reword and route; do not move/delete/rename files in Phase 70. |
| Making docs imply panel MCMC demo support | High | State explicitly that panel demo smoke is config/data/model-spec only. |
| Reopening broad Abacus-name scrubbing | Medium | Keep internal reference/provenance names out of scope; Phase 48 already parked rename strategy. |
| Creating another smoke harness | Medium | Reuse Phase 69 command; do not add sampler-bearing checks. |
| Running unnecessary broad tests | Low | Use focused runner/docs tests only; no full suite. |

## Independent Review

Completed before implementation by a read-only subagent.

Review result:

- No Must Fix items.
- Accepted one Should Fix: add an explicit changed-file allowlist audit to the
  verification checklist because this workspace currently contains unrelated
  local drift in `.gitignore` and `.planning/CRITICAL-REVIEW-2026-07-19.md`.
- Cleared the plan's scope, demo-surface diagnosis, safe handling of future
  reference-name scrubbing, and scoped-test strategy.
