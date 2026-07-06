# Build Log: Phase 27 Scope Boundary Reconciliation

## Builder Summary

Implemented the Phase 27 scope-boundary correction as a documentation,
planning, and focused-guard change only. V1 release-facing docs now make
MCMC/Turing the supported inference backend and treat variational inference as
out of scope for v1 support. Existing `VariationalConfig` and
`approximate_fit!` exports remain untouched and described as scaffolded
pre-v1 review surfaces.

## Changed Files

- `README.md`
- `docs/src/index.md`
- `docs/src/release.md`
- `.planning/PROJECT.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/ABACUS-PARITY-LEDGER.md`
- `.planning/phases/27-scope-boundary-reconciliation/PLAN.md`
- `.planning/phases/27-scope-boundary-reconciliation/handoff/BUILD-LOG.md`
- `.planning/phases/27-scope-boundary-reconciliation/handoff/REVIEW-REQUEST.md`
- `CHANGELOG.md`
- `test/api_exports.jl`

## Implementation Notes

- Added the exact marked v1 out-of-scope table in `.planning/PROJECT.md` with
  `variational_inference`, `dashboard_ui`, and `ai_advisor`, each marked
  `out-of-scope-v1`.
- Removed legacy VI support row IDs from release-facing supported matrices.
- Reworded older Phase 6/7/8 planning language as historical implementation
  facts superseded by Phase 27 rather than current v1 support.
- Added an explicit `deferred` variational-inference ledger row.
- Extended `test/api_exports.jl` to:
  - validate the marked v1 out-of-scope table shape and exact rows;
  - scan `README.md`, `docs/src/index.md`, `docs/src/release.md`,
    `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, and
    `.planning/ABACUS-PARITY-LEDGER.md`;
  - reject the legacy row IDs `INF-TS-VI`, `POST-TS-VI`, `OPT-TS-VI` and
    active support claims from the Architect brief;
  - preserve allowed unsupported, out-of-scope, scaffolded, historical, and
    superseded VI wording through explicit guard examples.

## Reviewer Must Fix Resolution

- The first review found that the VI claim guard used raw substring matching,
  which was too broad for valid wording such as `unsupported VI` and too
  narrow for active variants such as `VI is supported for v1`.
- The guard now uses `_api_exports_has_active_vi_release_claim` with:
  - unconditional rejection of legacy supported row IDs;
  - explicit allowed-context regexes for unsupported/out-of-scope/scaffolded/
    historical/superseded/export-existence wording;
  - active-claim regexes for legacy phrases and variants such as
    `VI is supported for v1`, `VI is release-supported`, and
    `ADVI is a supported backend`;
  - positive and negative examples inside the focused testset.

## Verification

- `make test-file FILE=test/api_exports.jl`
  - Passed.
  - Reported `Pass 4373, Total 4373` after the reviewer Must Fix patch.
- `julia --project=@runic -m Runic --check --diff test/api_exports.jl`
  - Passed with no diff.
- `git diff --check`
  - Passed.
- `git diff --name-only -- src/ Project.toml Manifest.toml`
  - Passed; printed no files.
- Additional scan:
  - `rg -n "INF-TS-VI|POST-TS-VI|OPT-TS-VI|supported VI|supported MCMC and VI|supported MCMC and supported VI|bounded explicit VI path|bounded VI support" README.md docs/src/index.md docs/src/release.md .planning/PROJECT.md .planning/ROADMAP.md .planning/STATE.md .planning/ABACUS-PARITY-LEDGER.md`
  - No matches.

## Known Gaps

- Three Man Team reviewer pass has not been run in this Builder turn.
- Commit is intentionally not made by the Builder.
- Full suite was not run, per Phase 27 boundary.
- `docs/src/api.md` was not touched; `VariationalConfig` and
  `approximate_fit!` remain scaffolded inventory rows.
