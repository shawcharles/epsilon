# Review Feedback: Phase 27 Scope Boundary Reconciliation

## Must Fix

None. The previous Must Fix is resolved.

## Should Fix

None.

## Escalate

None. No source, dependency, runtime-warning, export-removal, or API-cleanup question needs an architect decision from this re-review.

## Cleared

- The `test/api_exports.jl` guard no longer relies on raw substring matching. It now routes VI claims through `_api_exports_has_active_vi_release_claim`, rejects legacy supported row IDs unconditionally, checks explicit active-claim regexes, and allows unsupported/out-of-scope/scaffolded/pre-v1/historical/superseded contexts (`test/api_exports.jl:49`, `test/api_exports.jl:62`, `test/api_exports.jl:478`).
- The prior false-positive/false-negative risk is covered by explicit examples: allowed lines include `unsupported VI`, scaffolded pre-v1 wording, and historical/superseded wording; rejected lines include `supported MCMC and VI`, `bounded VI support`, `VI is supported for v1`, `VI is release-supported`, `ADVI is a supported backend`, and `Variational inference is supported for v1` (`test/api_exports.jl:758`, `test/api_exports.jl:764`).
- The scan still covers the required release/planning files and keeps `legacy_vi_claims == String[]` (`test/api_exports.jl:15`, `test/api_exports.jl:484`, `test/api_exports.jl:779`).
- `BUILD-LOG.md` documents the reviewer Must Fix resolution and the new `Pass 4373, Total 4373` result (`.planning/phases/27-scope-boundary-reconciliation/handoff/BUILD-LOG.md:38`, `.planning/phases/27-scope-boundary-reconciliation/handoff/BUILD-LOG.md:57`).
- `REVIEW-REQUEST.md` documents the same fix scope and new test count (`.planning/phases/27-scope-boundary-reconciliation/handoff/REVIEW-REQUEST.md:31`, `.planning/phases/27-scope-boundary-reconciliation/handoff/REVIEW-REQUEST.md:39`).
- I reran the focused verification only: `make test-file FILE=test/api_exports.jl` passed with `Pass 4373, Total 4373`; Runic check on `test/api_exports.jl` passed; `git diff --check` passed; and `git diff --name-only -- src/ Project.toml Manifest.toml` printed no files. No full suite was run.
