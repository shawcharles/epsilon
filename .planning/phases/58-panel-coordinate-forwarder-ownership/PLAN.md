# Phase 58: Panel Coordinate Forwarder Ownership

Status: Implemented

## Objective

Move panel-coordinate result forwarding methods out of `src/Epsilon.jl` and
replace the 32 duplicated methods with a small internal forwarding surface,
without changing public exports, result schemas, coordinate metadata semantics,
include order of existing files, docs inventory, API lifecycle state, or parity
claims.

Phases 56 and 57 extracted export declarations and runtime includes from the
package entry point. Phase 58 addresses the last remaining package-entry
pressure point identified in Phase 55: the duplicated
`panel_coordinates` / `panel_axes` / `panel_axis` / `panel_coordinate`
forwarders for result types.

## Current Boundary

Current public primitive methods are owned by `src/model/builder.jl`:

- `panel_coordinates(::ModelCoordinateMetadata)`
- `panel_axes(::ModelCoordinateMetadata)`
- `panel_axis(::ModelCoordinateMetadata)`
- `panel_coordinate(::ModelCoordinateMetadata, flat_index)`
- corresponding `MMMModelSpec` forwarding methods

The duplicated methods currently live in `src/Epsilon.jl` for:

- `InferenceResults`
- `ContributionResults`
- `DecompositionResults`
- `ResponseCurveResults`
- `SaturationCurveResults`
- `AdstockCurveResults`
- `MetricResults`
- `PanelBudgetOptimizationResult`

Those result types are all defined only after `src/model/builder.jl`, so the
new forwarding owner must be loaded after `src/inference/results.jl`,
`src/postmodel/types.jl`, and `src/optimization/types.jl`.

## Scope

In scope:

- Add one private source file, `src/model/coordinate_forwarders.jl`.
- Define an internal union alias for result types that carry
  `coordinate_metadata`.
- Replace the 32 duplicated result-forwarder methods with four methods over
  that internal union alias.
- Include the new file after `optimization/types.jl`, where all forwarded
  result types are defined.
- Leave the existing order of all pre-existing include statements unchanged.

Out of scope:

- Moving primitive coordinate metadata methods from `src/model/builder.jl`.
- Moving `MMMModelSpec` forwarding methods.
- Changing public exports, docs inventory, API triage, cleanup RFC, ROADMAP,
  STATE, or parity ledger.
- Changing result structs, schemas, serialization, pipeline artifacts,
  postmodel calculations, optimisation behaviour, or panel metadata semantics.
- Adding new abstract supertypes to public result structs.
- Running the full suite.

## File Allowlist

Implementation may touch only:

- `src/Epsilon.jl`
- `src/includes.jl`
- `src/model/coordinate_forwarders.jl`
- `test/model/panel.jl`
- `.planning/phases/58-panel-coordinate-forwarder-ownership/PLAN.md` for status
  and verification-log updates only

The pre-existing untracked `.planning/CRITICAL-REVIEW-2026-07-19.md` remains
outside this phase and must not be staged.

## Acceptance Criteria

- [x] `src/Epsilon.jl` no longer contains the duplicated result forwarders.
- [x] `src/model/coordinate_forwarders.jl` contains four forwarding methods:
      `panel_coordinates`, `panel_axes`, `panel_axis`, and `panel_coordinate`.
- [x] The forwarding methods cover the exact same eight result types listed in
      this plan.
- [x] `src/includes.jl` loads `src/model/coordinate_forwarders.jl` only after
      the forwarded result types are defined.
- [x] A narrow behavioural test calls all four forwarding functions on all
      eight intended result types.
- [x] Existing public `PanelCoordinate` and panel metadata APIs behave
      unchanged for grouped inference, postmodel, metric, and panel budget
      optimisation result surfaces.
- [x] No export, docs inventory, API lifecycle, roadmap/state, or parity-ledger
      changes.

## Verification

Use scoped checks only:

```bash
JULIA_PKG_SERVER_REGISTRY_PREFERENCE=eager make test-file FILE=test/api_exports.jl
JULIA_PKG_SERVER_REGISTRY_PREFERENCE=eager make test-file FILE=test/model/panel.jl
make format-check-touched
git diff --check
git diff --cached --check
git diff --cached --name-only | sort
git status --short --branch
```

`test/api_exports.jl` guards the public export/docs/triage surface.
`test/model/panel.jl` guards primitive metadata/spec coordinate behaviour and
must include one synthetic result-forwarder test covering the exact eight
existing forwarded result types. Avoid full-suite execution.

No full suite is required because this slice changes internal method ownership
only, does not add or remove exports, does not alter shared test imports, does
not touch dependencies, generated fixtures, pipeline stage execution, docs
inventory rows, or planning-state closure docs.

## Independent Review Questions

Before implementation, an independent reviewer must check:

- whether a private union alias plus four forwarding methods is preferable to a
  new public/shared abstract supertype for this pre-v1 cleanup;
- whether `src/model/coordinate_forwarders.jl` after `optimization/types.jl` is
  a sound ownership/load-order point;
- whether any forwarded type is missing or accidentally added;
- whether focused tests listed above are sufficient;
- whether ROADMAP, STATE, docs inventory, API triage, and parity ledger should
  remain untouched; and
- whether the file allowlist is tight enough.

## Independent Review Result

The independent reviewer approved the implementation design with one coverage
caveat:

- Add one narrow behavioural test that calls all four public forwarders on all
  eight intended result types, because existing validation coverage directly
  exercises only `InferenceResults` and `ContributionResults`.
- Do not add `BudgetOptimizationResult`, `BudgetOptimizationProblem`,
  `ManualScenarioEvaluationResult`, or `ScenarioStoreArtifact` to the alias in
  this phase, even though some also carry `coordinate_metadata`; doing so would
  widen behaviour beyond the existing duplicated method surface.
- The private union alias is preferable to a new public abstract supertype for
  this pre-v1 cleanup because it removes duplication without changing result
  type hierarchy or creating a new public lifecycle commitment.
- The load-order point after `optimization/types.jl` is sound because all eight
  target structs are defined by then, and method ambiguity risk is low because
  the alias is disjoint from `ModelCoordinateMetadata` and `MMMModelSpec`.
- ROADMAP, STATE, docs inventory, API triage, changelog, and parity ledger
  should remain untouched.

## Landing Notes

- Removed the 32 duplicated result-forwarder methods from `src/Epsilon.jl`.
- Added `src/model/coordinate_forwarders.jl` with private
  `_PanelCoordinateResult` union alias covering exactly `InferenceResults`,
  `ContributionResults`, `DecompositionResults`, `ResponseCurveResults`,
  `SaturationCurveResults`, `AdstockCurveResults`, `MetricResults`, and
  `PanelBudgetOptimizationResult`.
- Added four forwarding methods over that alias.
- Loaded the new owner after `optimization/types.jl`, once all eight target
  structs are defined.
- Added a synthetic `test/model/panel.jl` behavioural test that calls
  `panel_coordinates`, `panel_axes`, `panel_axis`, and `panel_coordinate` on
  all eight result shells.
- Left exports, docs inventory, API triage, changelog, ROADMAP, STATE, and
  parity ledger untouched.

Scoped verification:

```bash
JULIA_PKG_SERVER_REGISTRY_PREFERENCE=eager make test-file FILE=test/model/panel.jl
# Epsilon.jl: 123 passed / 123 total, 1m26.3s

JULIA_PKG_SERVER_REGISTRY_PREFERENCE=eager make test-file FILE=test/api_exports.jl
# Epsilon.jl: 5589 passed / 5589 total, 7.7s

julia --project=. -e 'using Epsilon; exports = Set(Symbol.(names(Epsilon; all=false, imported=false))); delete!(exports, :Epsilon); @assert length(exports) == 199; println(length(exports))'
# 199

make format-check-touched
git diff --check
# both passed with no output

git diff --cached --check
# passed with no output

git diff --cached --name-only | sort
# .planning/phases/58-panel-coordinate-forwarder-ownership/PLAN.md
# src/Epsilon.jl
# src/includes.jl
# src/model/coordinate_forwarders.jl
# test/model/panel.jl

git diff --cached | rg -i "password|secret|api_key|token"
# no matches
```
