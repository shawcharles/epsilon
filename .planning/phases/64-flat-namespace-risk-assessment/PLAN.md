# Phase 64: Flat Namespace Risk Assessment

Status: Reviewed

## Objective

Review the remaining risk from Epsilon's single flat Julia module after the
Phase 55 through Phase 58 package-entry cleanup, and decide whether further
namespace decomposition should happen before the first usable release path.

This phase is planning-only. It must not change runtime source, public exports,
include order, docs inventory, parity claims, or tests.

## Current Evidence

Observed on 2026-07-19 after Phases 56, 57, and 58:

- `src/Epsilon.jl` is now a small package entry point with the single
  `module Epsilon` boundary, `include("exports.jl")`,
  `include("includes.jl")`, `epsilon_version`, `prior_predict`, and docstring
  anchors for `fit!` and `summary_table`.
- `src/Epsilon.jl` is 58 lines.
- `src/includes.jl` is 62 lines and contains 52 runtime include statements,
  grouped by current layer/load-order comments.
- `src/exports.jl` is 200 lines and contains 199 public `export` statements.
- The duplicated panel-coordinate result forwarders identified in Phase 55 were
  moved to `src/model/coordinate_forwarders.jl` in Phase 58.
- `test/api_exports.jl` remains the public export/docs/triage guard.

The original Phase 55 pressure point has therefore mostly been resolved. The
remaining concern is not package-entry bloat. The remaining concern is that all
included source files still evaluate into one Julia module, so internal helper
names, load-order assumptions, and export-list review still share one global
namespace.

## Scope

In scope:

- Reassess the remaining flat-module risk using the current source layout.
- Compare that risk against the disruption of introducing internal submodules
  before the first usable release path.
- Decide whether a bounded follow-up is worth doing now.
- Record exact out-of-scope boundaries and verification expectations.

Out of scope:

- Editing `src/`, `test/`, `docs/`, `Project.toml`, or `Manifest.toml`.
- Introducing internal submodules.
- Reordering includes.
- Adding, removing, renaming, or deprecating exports.
- Changing API docs inventory, API triage, changelog, ROADMAP, STATE, or parity
  ledger entries.
- Running Julia tests or the full suite.

## Assessment

Do not introduce internal submodules now.

The current single-module design still has real scaling costs:

- private helper names are not compiler-isolated by layer;
- include order remains a single manual sequence;
- `src/exports.jl` is easier to review than the old entry point, but the export
  declarations are still a long ungrouped public list; and
- a future API split would require careful method-extension and qualification
  work across MMM, inference, postmodel, optimisation, pipeline, and plotting
  surfaces.

Those costs are mostly maintainability costs, not current correctness defects.
A submodule split would be a high-risk internal refactor at exactly the wrong
time: it could alter method lookup, require broad qualification changes, create
new import cycles, and force many tests to prove behaviour that is currently
stable. It would also not make the library more usable for analysts in the
short term.

The release-path priority should remain small behavioural hardening,
documentation clarity, and toy-model usability evidence. Namespace
decomposition should wait until there is a concrete recurring collision,
extension-boundary problem, or public API lifecycle decision that makes the
benefit exceed the migration risk.

## Recommendation

Keep Epsilon as one Julia module for the first usable release path.

The only reasonable near-term namespace follow-up is a small structure-only
cleanup:

- group `src/exports.jl` by existing API domain comments;
- preserve the exact exported symbol set;
- do not reorder runtime includes;
- do not touch docs inventory or lifecycle triage unless a guard proves a
  mismatch; and
- verify with `test/api_exports.jl`, package-load smoke, formatter check, and
  diff/allowlist checks.

This follow-up is optional. It is useful for reviewability, not required for
correctness. If taken, it should be a narrow Phase 65 and must not become a
general API cleanup.

## Parked Future Work

A true namespace decomposition should require a separate RFC after the first
usable release path is stable. That RFC should answer:

- which internal layers would become submodules;
- whether public names stay re-exported from `Epsilon`;
- how method extension across model, result, optimisation, and plotting types
  will be qualified;
- how include cycles will be avoided;
- how docs inventory and API triage will distinguish public and internal
  names; and
- what migration support is required for downstream users.

Until those questions have concrete answers, submodules are architectural churn,
not release-enabling work.

## File Allowlist

This phase may touch only:

- `.planning/phases/64-flat-namespace-risk-assessment/PLAN.md`

Known unrelated local files must remain unstaged:

- `.gitignore`
- `.planning/CRITICAL-REVIEW-2026-07-19.md`

## Acceptance Criteria

- [ ] The current post-Phase-58 source layout is documented with concrete file
      counts and boundaries.
- [ ] The recommendation distinguishes entry-point bloat from true flat-module
      namespace risk.
- [ ] The phase explicitly rejects pre-release internal submodules unless a
      later RFC justifies them.
- [ ] Any near-term follow-up is bounded to export-list grouping only, with no
      export-set, include-order, docs-inventory, or API-lifecycle movement.
- [ ] An independent read-only review confirms or corrects the recommendation.
- [ ] No runtime source, tests, docs, roadmap/state, changelog, or parity ledger
      files are edited.

## Verification

Planning-only scoped verification:

```bash
git diff --check
git diff --cached --check
git diff --cached --name-only | sort
git status --short --branch
```

No Julia tests are required because this phase changes only a planning artifact
and makes no source, test, docs, dependency, fixture, or pipeline changes.

## Independent Review Result

The independent read-only review agreed with the recommendation:

- Do not introduce internal submodules now.
- Treat the residual namespace risk as real but bounded: private helper names
  still share one module scope, and include order is still manually maintained.
- Treat a submodule split as higher-risk pre-release churn because it would
  require qualification/import work, could affect method extension semantics,
  and could disrupt docs/API inventory and load-order behaviour.
- Keep the single-module architecture for the first usable release path.
- If a follow-up is taken, bound it to grouping `src/exports.jl` by domain
  comments while preserving the exact export set.

No corrections to the plan recommendation were required.
