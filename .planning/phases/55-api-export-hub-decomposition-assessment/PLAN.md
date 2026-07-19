# Phase 55: API Export Hub Decomposition Assessment

Status: Reviewed

## Objective

Design a safe, bounded way to reduce the scaling risk in `src/Epsilon.jl`
without changing the public API, include graph, runtime behaviour, or
Documenter/API inventory contract in this phase.

The current package entry point is doing three jobs at once:

- declaring the public export surface;
- establishing the source include/load order; and
- hosting small API forwarding methods, especially panel-coordinate metadata
  accessors.

That has worked during pre-v1 build-out, but it is now a maintainability risk:
the file currently has 199 `export` statements, 51 `include` statements, and 32
trivial panel-coordinate forwarder methods. Phase 55 is a planning and design
checkpoint only. It should decide the smallest implementation sequence that
can make the entry point easier to review while preserving the existing public
surface and test guards.

## Current Evidence

Observed on 2026-07-19:

- `src/Epsilon.jl` has 199 individual `export` statements.
- `src/Epsilon.jl` has 51 direct `include(...)` statements.
- `src/Epsilon.jl` has 32 trivial `panel_coordinates`, `panel_axes`,
  `panel_axis`, and `panel_coordinate` forwarding methods over result types.
- `docs/src/api.md` contains the guarded public API inventory table.
- `.planning/API-EXPORT-TRIAGE.md` records lifecycle disposition for current
  exports.
- `test/api_exports.jl` guards the loaded export surface, docs inventory,
  triage register, deprecation audit, v1 out-of-scope claims, current-docs
  claim boundaries, public identity language, and trusted-local artifact
  wording.

## Scope

In scope for Phase 55:

- Record the current export/include/forwarder pressure points.
- Define a future implementation sequence that starts with structure-only
  changes and no public API movement.
- Define the verification lanes needed for any later source-touching slice.
- Identify what must not be changed without a separate API decision.

Out of scope for Phase 55:

- Editing `src/Epsilon.jl` or any runtime source file.
- Moving exports, changing export names, adding exports, or removing exports.
- Reordering includes.
- Adding internal submodules.
- Changing `docs/src/api.md`, `.planning/API-EXPORT-TRIAGE.md`, or
  `.planning/API-EXPORT-CLEANUP-RFC.md`.
- Changing `test/api_exports.jl`.
- Updating `.planning/ROADMAP.md`, `.planning/STATE.md`, or
  `.planning/ABACUS-PARITY-LEDGER.md`.
- Running the full suite.

## Design Recommendation

Do not begin with a broad namespace refactor. The first implementation slice
should be a structure-preserving extraction, not an API cleanup.

Recommended sequence:

1. Create private package-entry metadata files that are included by
   `src/Epsilon.jl`, such as `src/exports.jl` and `src/includes.jl`, while
   preserving the exact export set and include order.
2. Add comments or grouped blocks to make the include dependency order explicit
   by layer: distributions, model/config, MMM feature primitives, model build
   and IO, inference, postmodel, optimization, scenario planner, pipeline,
   plotting, transforms.
3. Move the repeated panel-coordinate result forwarders into the most natural
   existing source owner only after the export/include extraction is guarded.
   The likely owner is a model/postmodel metadata layer, but the exact file
   should be decided after checking type definition order.
4. Only after those no-op structure changes are guarded should Epsilon consider
   true API lifecycle changes, such as retiring deprecated validation-helper
   exports. Those belong to a separate breaking/deprecation phase because the
   triage and docs guards intentionally say they are not ready to unexport.

## Future Implementation Slices

These are not Phase 55 implementation tasks. They are the reviewed sequence for
future phases if the user chooses to proceed.

### Future Slice 56-01: Freeze The Entry-Point Contract

Description: Add a future implementation guard that preserves the loaded export
set and smoke-tests package loading before any entry-point reorganisation is
committed.

Acceptance criteria:

- [ ] The loaded `names(Epsilon; all = false, imported = false)` set is
      unchanged before and after the reorganisation.
- [ ] Existing `test/api_exports.jl` remains the source of truth for public
      inventory and documentation coverage.
- [ ] Any include-list extraction is reviewed against the ordered include list
      before and after the change; `test/api_exports.jl` is not treated as
      proof of include-order equivalence.
- [ ] No lifecycle changes are made to exported symbols.

Verification:

- [ ] `make test-file FILE=test/api_exports.jl`
- [ ] `julia --project=. -e 'using Epsilon; println(length(names(Epsilon; all=false, imported=false)))'`

Dependencies: None.

Files likely touched in a future implementation:

- `src/Epsilon.jl`
- `src/exports.jl`
- possibly `test/api_exports.jl` only if a structure-preservation helper is
  needed

Estimated scope: Small.

### Future Slice 56-02: Extract Export Declarations Without API Movement

Description: Move the export declarations out of the package entry point into a
private included file while preserving the exact public symbol set and avoiding
any docs inventory churn.

Acceptance criteria:

- [ ] `src/Epsilon.jl` still owns the single `module Epsilon` boundary.
- [ ] Export declarations are grouped by existing API domain.
- [ ] The exported symbol set is unchanged.
- [ ] `docs/src/api.md` and `.planning/API-EXPORT-TRIAGE.md` do not need table
      edits.

Verification:

- [ ] `make test-file FILE=test/api_exports.jl`
- [ ] `make format-check-touched`
- [ ] `git diff --check`

Dependencies: Future Slice 56-01.

Files likely touched in a future implementation:

- `src/Epsilon.jl`
- `src/exports.jl`

Estimated scope: Small.

### Future Slice 57-01: Document Include Order Without Reordering It

Description: Extract or annotate the include list so reviewers can see the
dependency order by layer without changing load order.

Acceptance criteria:

- [ ] Include order remains byte-for-byte equivalent in execution order.
- [ ] Layer comments explain why transforms are currently loaded after plotting
      even though transforms are lower-level concepts, if that order is
      preserved.
- [ ] No source file starts relying on accidental load-order changes.

Verification:

- [ ] `make test-file FILE=test/api_exports.jl`
- [ ] one focused source-loading smoke check:
      `julia --project=. -e 'using Epsilon; println(Epsilon.epsilon_version())'`
- [ ] `make format-check-touched`
- [ ] `git diff --check`

Dependencies: Future Slice 56-01.

Files likely touched in a future implementation:

- `src/Epsilon.jl`
- optionally `src/includes.jl`

Estimated scope: Small.

### Future Slice 58-01: Replace Panel-Coordinate Forwarder Duplication

Description: After the entry-point extraction is stable, replace the repeated
panel-coordinate forwarding methods with a small internal abstraction or move
them to the appropriate metadata owner.

Acceptance criteria:

- [ ] Public methods for `panel_coordinates`, `panel_axes`, `panel_axis`, and
      `panel_coordinate` continue to work for every currently supported result
      type.
- [ ] Forwarding remains explicit enough that method ownership is clear.
- [ ] No inference, postmodel, pipeline, or optimization result schema changes.

Verification:

- [ ] `make test-file FILE=test/model/results.jl` if it owns metadata coverage.
- [ ] `make test-file FILE=test/postmodel/*.jl` is not a valid selector; choose
      the exact focused files that currently exercise panel metadata.
- [ ] `make test-file FILE=test/optimization/objective.jl` only if
      `PanelBudgetOptimizationResult` forwarding is touched.
- [ ] `make test-file FILE=test/api_exports.jl`

Dependencies: Future Slices 56-01 and 56-02.

Files likely touched in a future implementation:

- `src/Epsilon.jl`
- one existing metadata/result owner file after type-order review
- focused tests for the exact owner surface

Estimated scope: Medium.

## Recommended Immediate Next Phase

After Phase 55 is reviewed and committed, the next implementation phase should
be narrow:

**Phase 56: Extract Export Declarations Without API Movement**

That phase should touch only `src/Epsilon.jl`, a new private `src/exports.jl`,
and at most this plan's status section. It should preserve the loaded export
set exactly, smoke-test package loading, and treat `test/api_exports.jl` as the
focused public-surface guard. It should not move includes, not touch
panel-coordinate forwarders, not update public API docs, and not change
`.planning/ROADMAP.md` or `.planning/STATE.md`.

## Verification Plan For Phase 55

Because Phase 55 is planning-only, use lightweight checks:

```bash
git diff --check
git diff --cached --check
```

No Julia tests are required for this phase because no runtime, docs, test,
export, include, dependency, fixture, or public API file changes.

Verification result:

```bash
git diff --check
# passed with no output
```

## Independent Review Questions

Before committing this plan, an independent reviewer must check:

- whether the plan correctly treats export extraction as structure-preserving
  rather than API cleanup;
- whether any proposed future task accidentally widens into API lifecycle,
  include-order, docs inventory, or parity-ledger work;
- whether `test/api_exports.jl` is the right focused verification lane for
  later export extraction;
- whether the panel-coordinate forwarder cleanup should be delayed until after
  export extraction; and
- whether `.planning/ROADMAP.md` / `.planning/STATE.md` should remain untouched
  in this planning-only commit.

## Independent Review Result

The independent reviewer approved the plan with minor wording fixes:

- Reworded Future Slice 56-01 so `test/api_exports.jl` guards export-surface
  preservation and docs/API inventory coherence, but is not presented as proof
  of include-order equivalence.
- Renamed the proposed source-touching work from Phase 55 task numbers to
  future implementation slices, keeping Phase 55 planning-only.
- Replaced "one-line panel-coordinate forwarder methods" with "trivial
  panel-coordinate forwarder methods" because some methods span two physical
  lines.

The reviewer confirmed that export extraction should happen before
panel-coordinate cleanup; `test/api_exports.jl` is the right focused lane for
the future export-extraction slice; and API lifecycle, docs inventory, parity,
`.planning/ROADMAP.md`, and `.planning/STATE.md` should remain untouched here.
