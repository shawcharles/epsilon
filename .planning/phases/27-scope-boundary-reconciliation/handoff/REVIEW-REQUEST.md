# Review Request: Phase 27 Scope Boundary Reconciliation

## Scope For Review

Review the Phase 27 documentation/planning/test-guard changes only. This
Builder pass should not have changed source code, dependency files, runtime
warnings, exports, or API cleanup candidates.

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

## Review Focus

- Confirm release-facing supported inference, post-model, and optimisation rows
  are MCMC-only for v1.
- Confirm `.planning/PROJECT.md` has exactly one marked v1 out-of-scope table
  with the required header, separator, surface rows, and `out-of-scope-v1`
  status.
- Confirm `VariationalConfig` and `approximate_fit!` are preserved as existing
  scaffolded exports, not removed or runtime-deprecated.
- Confirm old planning-history language is framed as historical implementation
  superseded by Phase 27, not as current v1 VI support.
- Confirm the focused `test/api_exports.jl` guard is context-aware enough to
  allow unsupported/out-of-scope/historical/export-existence VI wording while
  rejecting active support phrases and legacy row IDs.
- Confirm the reviewer Must Fix is resolved: raw substring matching has been
  replaced with active-claim predicates, allowed-context handling, and explicit
  allowed/rejected examples.
- Confirm no `src/**`, `Project.toml`, or `Manifest.toml` changes are present.

## Verification Run

- `make test-file FILE=test/api_exports.jl` passed with
  `Pass 4373, Total 4373` after the reviewer Must Fix patch.
- `julia --project=@runic -m Runic --check --diff test/api_exports.jl` passed.
- `git diff --check` passed.
- `git diff --name-only -- src/ Project.toml Manifest.toml` passed and printed
  no files.
- Legacy phrase scan returned no matches across the guarded release/planning
  files.

## Known Gaps

- Full suite intentionally not run.
- No commit made.
- `docs/src/api.md` intentionally not edited.
