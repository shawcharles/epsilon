# Phase 57: Include Order Documentation

Status: Implemented

## Objective

Extract and document Epsilon's runtime source include list without changing the
runtime include order, public export set, package module boundary, API docs
inventory, lifecycle state, or parity claims.

Phase 56 moved export declarations into `src/exports.jl`. Phase 57 performs
the next small package-entry cleanup: move the remaining runtime includes into
`src/includes.jl` with layer comments, then include that file from
`src/Epsilon.jl` after `exports.jl`.

## Scope

In scope:

- Move the existing runtime `include(...)` statements from `src/Epsilon.jl` into
  `src/includes.jl`.
- Preserve the exact runtime source include order.
- Add comments in `src/includes.jl` that explain the current load-order groups.
- Keep `include("exports.jl")` before runtime includes.
- Keep `src/Epsilon.jl` as the single `module Epsilon` boundary.

Out of scope:

- Reordering runtime includes.
- Moving export declarations or editing `src/exports.jl`.
- Moving panel-coordinate forwarding methods.
- Adding internal submodules.
- Editing API docs inventory, API triage, API cleanup RFC, ROADMAP, STATE, or
  parity ledger.
- Changing model/runtime behaviour, dependencies, fixtures, examples, pipeline
  stages, or tests.
- Running the full suite.

## File Allowlist

Implementation may touch only:

- `src/Epsilon.jl`
- `src/includes.jl`
- `.planning/phases/57-include-order-documentation/PLAN.md` for status and
  verification-log updates only

The pre-existing untracked `.planning/CRITICAL-REVIEW-2026-07-19.md` remains
outside this phase and must not be staged.

## Acceptance Criteria

- [x] `src/Epsilon.jl` keeps `module Epsilon`, `include("exports.jl")`, and
      `include("includes.jl")` in that order.
- [x] `src/includes.jl` contains the exact runtime include list moved from
      `src/Epsilon.jl`.
- [x] Runtime source include order is unchanged by direct before/after diff.
- [x] `src/includes.jl` comments make the current dependency/load-order groups
      easier to inspect without pretending the order is ideal or reordered.
- [x] No export, docs inventory, API lifecycle, roadmap/state, or parity-ledger
      changes.

## Verification

Use scoped checks only:

```bash
rg '^include\(' src/Epsilon.jl | grep -v 'include("exports.jl")' > /tmp/epsilon_phase57_runtime_includes_before.txt
rg '^include\(' src/includes.jl > /tmp/epsilon_phase57_runtime_includes_after.txt
diff -u /tmp/epsilon_phase57_runtime_includes_before.txt /tmp/epsilon_phase57_runtime_includes_after.txt
JULIA_PKG_SERVER_REGISTRY_PREFERENCE=eager make test-file FILE=test/api_exports.jl
julia --project=. -e 'using Epsilon; @assert Epsilon.epsilon_version() !== nothing; println(Epsilon.epsilon_version())'
make format-check-touched
git diff --check
git diff --cached --check
git diff --cached --name-only | sort
git status --short --branch
```

`test/api_exports.jl` validates package loading, the public export surface, and
docs/triage consistency. It does not prove include-list identity; the include
order must be checked by direct diff review. The before list must come from
`src/Epsilon.jl` before implementation, excluding `exports.jl`; the after list
must come from `src/includes.jl`, excluding neither `exports.jl` nor
`includes.jl` because neither belongs there.

No full suite is required because this is a mechanical package-entry
reorganisation with no model/runtime logic changes, no dependency changes, no
shared test imports, no docs inventory rows, no generated fixtures, no pipeline
stage changes, and no planning-state closure edit.

## Independent Review Questions

Before implementation, an independent reviewer must check:

- whether the plan stays within the Phase 55 and Phase 56 reviewed boundary;
- whether moving runtime includes into `src/includes.jl` preserves path
  resolution and module evaluation semantics;
- whether the proposed comments document current load order without implying
  an unreviewed dependency reordering;
- whether focused API/load verification plus direct include-list diff is enough;
- whether ROADMAP, STATE, docs inventory, API triage, and parity ledger should
  remain untouched; and
- whether the file allowlist is tight enough.

## Independent Review Result

The independent reviewer approved implementation with verification wording
tightened:

- The include-list diff must compare the pre-implementation runtime includes
  from `src/Epsilon.jl` against post-implementation includes from
  `src/includes.jl`.
- `src/includes.jl` comments must state that transforms remain after plotting
  because current order is being preserved, not because that is the ideal
  architectural dependency order.
- The staged-file allowlist is a hard landing gate: exactly `src/Epsilon.jl`,
  `src/includes.jl`, and this Phase 57 plan.
- ROADMAP, STATE, docs inventory, API triage, parity ledger, exports, and API
  lifecycle state should remain untouched.

## Landing Notes

- Moved the 51 runtime include statements from `src/Epsilon.jl` into
  `src/includes.jl`.
- Added `include("includes.jl")` immediately after `include("exports.jl")`.
- Added layer comments in `src/includes.jl`, including the explicit warning
  that transforms remain after plotting only because this phase preserves
  existing load order.
- Left exports, panel-coordinate forwarders, docs inventory, API triage,
  ROADMAP, STATE, and parity ledger untouched.

Scoped verification:

```bash
rg '^include\(' src/Epsilon.jl | grep -v 'include("exports.jl")' > /tmp/epsilon_phase57_runtime_includes_before.txt
# before-state captured 51 runtime include statements

rg '^include\(' src/includes.jl > /tmp/epsilon_phase57_runtime_includes_after.txt
diff -u /tmp/epsilon_phase57_runtime_includes_before.txt /tmp/epsilon_phase57_runtime_includes_after.txt
# no diff; runtime include order is unchanged

JULIA_PKG_SERVER_REGISTRY_PREFERENCE=eager make test-file FILE=test/api_exports.jl
# Epsilon.jl: 5589 passed / 5589 total, 7.5s

julia --project=. -e 'using Epsilon; @assert Epsilon.epsilon_version() !== nothing; println(Epsilon.epsilon_version())'
# 0.1.0-dev

make format-check-touched
git diff --check
# both passed with no output

git diff --cached --check
# passed with no output

git diff --cached --name-only | sort
# .planning/phases/57-include-order-documentation/PLAN.md
# src/Epsilon.jl
# src/includes.jl

git diff --cached | rg -i "password|secret|api_key|token"
# no matches
```
