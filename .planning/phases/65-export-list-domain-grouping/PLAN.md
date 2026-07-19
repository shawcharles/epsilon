# Phase 65: Export List Domain Grouping

Status: Implemented

## Objective

Improve reviewability of Epsilon's public export declarations by grouping
`src/exports.jl` under domain comments, without changing the exported symbol
set, public API lifecycle state, runtime include order, docs inventory, or
behaviour.

Phase 64 concluded that a true internal submodule split should not happen
before the first usable release path. This phase takes only the low-risk
follow-up from that assessment: make the existing flat export list easier to
audit.

## Scope

In scope:

- Add domain comments to `src/exports.jl`.
- Reorder export declarations only within `src/exports.jl` for reviewability.
- Preserve the exact loaded export set.
- Preserve `src/Epsilon.jl` and `src/includes.jl` unchanged.
- Keep `test/api_exports.jl` as the public-surface guard.

Out of scope:

- Adding, removing, renaming, deprecating, or unexporting any symbol.
- Introducing internal submodules.
- Reordering runtime includes.
- Editing docs inventory, API triage, cleanup RFC, changelog, ROADMAP, STATE,
  or parity ledger files.
- Changing model, transform, inference, postmodel, optimisation, pipeline, or
  plotting behaviour.
- Running the full suite.

## Export Groups

Use domain comments that match the existing package layers closely enough for
review:

- Package/version and shared public entry points.
- Prior and distribution specifications.
- Core model types, config, data, metadata, and validation.
- Transforms and preprocessing.
- Calibration and lift-test helpers.
- Inference results and diagnostics.
- MMM model fitting and prediction.
- Post-model result surfaces and summaries.
- Optimisation and scenario planning.
- Pipeline runtime.
- Plotting.

The groups are a review aid only. They do not create lifecycle commitments,
submodules, or new public namespaces.

## File Allowlist

Implementation may touch only:

- `src/exports.jl`
- `.planning/phases/65-export-list-domain-grouping/PLAN.md`

Known unrelated local files must remain unstaged:

- `.gitignore`
- `.planning/CRITICAL-REVIEW-2026-07-19.md`

## Acceptance Criteria

- [x] `src/exports.jl` is grouped by domain comments.
- [x] The loaded public export set remains exactly unchanged at 199 symbols.
- [x] `src/Epsilon.jl` and `src/includes.jl` remain unchanged.
- [x] API docs inventory, API triage, cleanup RFC, changelog, ROADMAP, STATE,
      and parity ledger remain untouched.
- [x] An independent review confirms the plan and grouping boundary before
      implementation.
- [x] Staged files match the allowlist exactly.

## Verification

Use scoped checks only:

```bash
git show HEAD:src/exports.jl | rg '^export ' | sed 's/^export //' | sort > /tmp/epsilon_phase65_exports_before.txt
rg '^export ' src/exports.jl | sed 's/^export //' | sort > /tmp/epsilon_phase65_exports_after.txt
diff -u /tmp/epsilon_phase65_exports_before.txt /tmp/epsilon_phase65_exports_after.txt
git diff --exit-code -- src/Epsilon.jl src/includes.jl
JULIA_PKG_SERVER_REGISTRY_PREFERENCE=eager make test-file FILE=test/api_exports.jl
julia --project=. -e 'using Epsilon; exports = Set(Symbol.(names(Epsilon; all=false, imported=false))); delete!(exports, :Epsilon); @assert length(exports) == 199; println(length(exports))'
make format-check-touched
git diff --check
git diff --cached --check
git diff --cached --name-only | sort
git status --short --branch
```

No full suite is required because this slice changes only export declaration
organisation. It does not change executable methods, dependencies, generated
fixtures, docs inventory rows, pipeline stages, or shared test imports.

## Independent Review Result

The independent read-only review approved the scope with one correction:

- Keep the phase bounded to structure-only grouping in `src/exports.jl`.
- Keep one `export SymbolName` declaration per line.
- Preserve the exact export set; do not add, remove, rename, deprecate, or
  unexport symbols.
- Do not touch `src/Epsilon.jl`, `src/includes.jl`, docs inventory, API triage,
  cleanup RFC, changelog, ROADMAP, STATE, or parity ledger files.
- Add a hard verification command proving the protected runtime hub files are
  untouched:
  `git diff --exit-code -- src/Epsilon.jl src/includes.jl`.
- No full suite is justified for this slice.

## Landing Notes

- Grouped the 199 one-line export declarations in `src/exports.jl` under
  domain comments covering package entry points, priors/distributions, core
  model types, serialization, transforms, calibration, inference, MMM model
  surfaces, postmodel outputs, optimisation/scenarios, pipeline runtime, and
  plotting.
- Preserved one `export SymbolName` declaration per line.
- Preserved the exact sorted export-symbol set against `HEAD`.
- Left `src/Epsilon.jl`, `src/includes.jl`, docs inventory, API triage,
  cleanup RFC, changelog, ROADMAP, STATE, and parity ledger untouched.

Scoped verification:

```bash
git show HEAD:src/exports.jl | rg '^export ' | sed 's/^export //' | sort > /tmp/epsilon_phase65_exports_before.txt
rg '^export ' src/exports.jl | sed 's/^export //' | sort > /tmp/epsilon_phase65_exports_after.txt
wc -l /tmp/epsilon_phase65_exports_after.txt
# 199 /tmp/epsilon_phase65_exports_after.txt

diff -u /tmp/epsilon_phase65_exports_before.txt /tmp/epsilon_phase65_exports_after.txt
# no diff

git diff --exit-code -- src/Epsilon.jl src/includes.jl
# no diff

JULIA_PKG_SERVER_REGISTRY_PREFERENCE=eager make test-file FILE=test/api_exports.jl
# Epsilon.jl: 5589 passed / 5589 total, 7.5s

julia --project=. -e 'using Epsilon; exports = Set(Symbol.(names(Epsilon; all=false, imported=false))); delete!(exports, :Epsilon); @assert length(exports) == 199; println(length(exports))'
# 199

make format-check-touched
# passed with no output

git diff --check
# passed with no output
```
