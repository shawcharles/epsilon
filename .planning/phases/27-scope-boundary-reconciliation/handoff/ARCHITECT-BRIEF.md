# Architect Brief: Phase 27 Scope Boundary Reconciliation

## Step Name

Phase 27: Scope Boundary Reconciliation

## Objective

Reconcile Epsilon's v1 documentation, planning, and guard tests with the
maintainer decision that variational inference is not part of the supported v1
library surface. Preserve the existing VI exports for now as scaffolded
pre-v1-review implementation, but stop claiming them as release-supported.

## Files In Scope

- `README.md`
- `docs/src/index.md`
- `docs/src/release.md`
- `docs/src/api.md`
- `.planning/PROJECT.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/ABACUS-PARITY-LEDGER.md`
- `.planning/phases/27-scope-boundary-reconciliation/PLAN.md`
- `.planning/phases/27-scope-boundary-reconciliation/handoff/*`
- `CHANGELOG.md`
- `test/api_exports.jl`

## Files Out Of Scope

- `src/**`
- `Project.toml`
- `Manifest.toml`
- Any runtime deprecation implementation for `VariationalConfig` or
  `approximate_fit!`
- Any dashboard/UI, hosted workflow, or AI-advisor implementation
- Any full-suite verification output or benchmark output

## Constraints

- Use British English.
- Keep this as a scope-contract correction, not a modelling change.
- Do not remove exports.
- Do not change inference semantics.
- Do not expand `.planning/API-EXPORT-CLEANUP-RFC.md` to include VI unless a
  separate API cleanup phase is approved.
- Preserve the distinction between an implemented/scaffolded export and a
  supported v1 release surface.
- Do not change the machine-checked public API inventory table schema in
  `docs/src/api.md`. Keep `VariationalConfig` and `approximate_fit!` as
  `scaffolded` inventory rows unless a separate API cleanup phase is approved.
  Add release-support clarification outside the marked inventory if needed.
- Run targeted verification only.

## Required Implementation Shape

1. Add a marked v1 out-of-scope table in `.planning/PROJECT.md` covering
   `variational_inference`, `dashboard_ui`, and `ai_advisor`.
   Required markers/header:
   - `<!-- BEGIN V1 OUT OF SCOPE -->`
   - `| Surface | Status | Rationale |`
   - `|---|---|---|`
   - exact surface rows: `variational_inference`, `dashboard_ui`,
     `ai_advisor`
   - exact status: `out-of-scope-v1`
   - `<!-- END V1 OUT OF SCOPE -->`
2. Update docs and release matrices so supported inference/post-model/
   optimization rows are MCMC-only for v1.
3. Keep `VariationalConfig` and `approximate_fit!` visible in the API inventory
   as scaffolded exports, with wording that they are not release-supported.
4. Add a focused guard to `test/api_exports.jl` that checks the marked
   out-of-scope table and rejects old supported-VI row IDs/phrases in
   release-facing and planning docs. The guard must be context-aware: allow VI
   in unsupported/out-of-scope wording, historical-superseded notes, and API
   export-existence contexts; reject active supported-release claims.
5. Update roadmap/state/changelog/ledger to record Phase 27.

## Acceptance Criteria

- The focused guard scans at least `README.md`, `docs/src/index.md`,
  `docs/src/release.md`, `.planning/PROJECT.md`, `.planning/ROADMAP.md`,
  `.planning/STATE.md`, and `.planning/ABACUS-PARITY-LEDGER.md` for active
  supported-release VI claims.
- `rg -n "INF-TS-VI|POST-TS-VI|OPT-TS-VI|supported VI|supported MCMC and VI|supported MCMC and supported VI|bounded explicit VI path|bounded VI support" README.md docs/src .planning/PROJECT.md .planning/ROADMAP.md .planning/STATE.md .planning/ABACUS-PARITY-LEDGER.md`
  returns no active supported-release claims.
- `make test-file FILE=test/api_exports.jl` passes.
- Runic check passes for `test/api_exports.jl`.
- `git diff --name-only -- src/ Project.toml Manifest.toml` prints nothing.
- Review feedback has no unresolved Must Fix items before commit.

## Verification Commands

```bash
make test-file FILE=test/api_exports.jl
julia --project=@runic -m Runic --check --diff test/api_exports.jl
git diff --check
git diff --name-only -- src/ Project.toml Manifest.toml
```
