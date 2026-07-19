# Phase 56: Export Declarations Extraction

Status: Implemented

## Objective

Extract the public export declarations from `src/Epsilon.jl` into a private
package-entry file without changing Epsilon's public API, source include order,
runtime behaviour, docs inventory, API lifecycle state, or parity claims.

Phase 55 reviewed the package-entry pressure in `src/Epsilon.jl` and approved
export extraction as the first safe implementation slice before any include
order work or panel-coordinate forwarder cleanup.

## Scope

In scope:

- Move the existing export declarations into `src/exports.jl`.
- Add `include("exports.jl")` immediately after `module Epsilon`.
- Preserve the existing source include order after the export block.
- Preserve the loaded public symbol set exactly.
- Keep `test/api_exports.jl` as the focused public-surface guard.

Out of scope:

- Adding, removing, renaming, grouping differently in docs, or deprecating
  exported symbols.
- Moving or reordering runtime source includes.
- Moving panel-coordinate forwarding methods.
- Editing `docs/src/api.md`, `.planning/API-EXPORT-TRIAGE.md`,
  `.planning/API-EXPORT-CLEANUP-RFC.md`, `.planning/ROADMAP.md`,
  `.planning/STATE.md`, or `.planning/ABACUS-PARITY-LEDGER.md`.
- Running the full suite.

## File Allowlist

Implementation may touch only:

- `src/Epsilon.jl`
- `src/exports.jl`
- `.planning/phases/56-export-declarations-extraction/PLAN.md` for status and
  verification-log updates only

The pre-existing untracked `.planning/CRITICAL-REVIEW-2026-07-19.md` remains
outside this phase and must not be staged.

## Acceptance Criteria

- [x] `src/Epsilon.jl` keeps the single `module Epsilon` boundary.
- [x] `src/Epsilon.jl` includes `exports.jl` before runtime source includes.
- [x] `src/exports.jl` contains the exact exported symbol declarations moved
      from `src/Epsilon.jl`.
- [x] The source include order for runtime files remains unchanged.
- [x] `docs/src/api.md`, `.planning/API-EXPORT-TRIAGE.md`, and related API
      lifecycle docs require no edits.
- [x] No public API lifecycle or parity claim changes.

## Verification

Use scoped checks only:

```bash
make test-file FILE=test/api_exports.jl
julia --project=. -e 'using Epsilon; println(length(names(Epsilon; all=false, imported=false)))'
make format-check-touched
git diff --check
git diff --cached --check
git diff --cached --name-only | sort
git status --short --branch
```

No full suite is required because this slice is a mechanical package-entry
reorganisation with no model/runtime logic, dependencies, shared test imports,
docs inventory rows, generated fixtures, pipeline stages, or planning-state
closure edits.

`test/api_exports.jl` proves the loaded public symbol set and docs/triage
consistency, not textual export-block identity or runtime include-list
equivalence. The moved export block and unchanged runtime include order must be
checked by direct diff review before commit.

## Independent Review Questions

Before implementation, an independent reviewer must check:

- whether the plan stays within the Phase 55 reviewed boundary;
- whether adding `include("exports.jl")` immediately after `module Epsilon`
  preserves the prior export-before-source-include execution shape;
- whether the focused API export test plus package-load smoke check are
  sufficient scoped verification;
- whether any docs inventory, API triage, ROADMAP, STATE, or parity-ledger edit
  is necessary; and
- whether the file allowlist is tight enough.

## Independent Review Result

The independent reviewer approved the plan with minor verification wording
changes:

- `include("exports.jl")` immediately after `module Epsilon` preserves the
  prior export-before-source-include execution shape because Julia evaluates the
  included file in the current module.
- `test/api_exports.jl` is sufficient for the loaded public symbol set and
  docs/triage consistency, but not for textual export-block identity or
  byte-for-byte runtime include-list ordering.
- `git diff --cached --name-only | sort` should be treated as an allowlist check
  only after staging the phase payload, with `git status --short --branch`
  confirming no unrelated file was pulled in.
- ROADMAP, STATE, docs inventory, API triage, and parity ledger should remain
  untouched.

## Landing Notes

- Moved the existing 199 export declarations into `src/exports.jl`.
- Added `include("exports.jl")` immediately after `module Epsilon`.
- Preserved the existing runtime source include order exactly after excluding
  the new `exports.jl` include.
- Left panel-coordinate forwarders, API docs inventory, API triage, ROADMAP,
  STATE, and parity ledger untouched.

Scoped verification:

```bash
diff -u /tmp/epsilon_phase56_exports_before_lines.txt /tmp/epsilon_phase56_exports_after_lines.txt
# no diff; moved export declarations are textually identical

diff -u /tmp/epsilon_phase56_includes_before_lines.txt /tmp/epsilon_phase56_includes_after_lines.txt
# no diff; runtime source include order is unchanged

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
# .planning/phases/56-export-declarations-extraction/PLAN.md
# src/Epsilon.jl
# src/exports.jl

git diff --cached | rg -i "password|secret|api_key|token"
# no matches
```
