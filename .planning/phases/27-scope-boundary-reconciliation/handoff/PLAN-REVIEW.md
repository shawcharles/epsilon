# Plan Review: Phase 27 Scope Boundary Reconciliation

## Must Fix

1. Tighten the guard acceptance beyond row IDs.

   The plan correctly targets `INF-TS-VI`, `POST-TS-VI`, and `OPT-TS-VI`, but the current docs also make prose claims such as "supported MCMC and VI rows", "supported MCMC and supported VI", "bounded explicit VI path", and "bounded VI support". Those claims appear in release-facing narrative, not only table row IDs, so the proposed acceptance check in `ARCHITECT-BRIEF.md` is too narrow. Add explicit acceptance criteria and guard fixtures for prose claims in `README.md`, `docs/src/index.md`, and `docs/src/release.md`, while allowing VI to appear only in unsupported/out-of-scope wording and API-inventory/export-existence contexts.

2. Include planning-history contradictions in the acceptance gate.

   The phase says the documented v1 boundary must be internally consistent, but the brief's `rg` acceptance command only scans `README.md`, `docs/src`, and `.planning/ABACUS-PARITY-LEDGER.md`. `.planning/ROADMAP.md` still says Phase 6 successfully delivered a supported bounded VI path, and `.planning/STATE.md` still records "Keep VI as an explicit Julia-only API" as an unqualified decision. The builder needs explicit instructions to rewrite these as historical implementation facts superseded by Phase 27's release boundary, not current v1 support.

3. Specify the API-inventory edit shape to avoid breaking existing guards.

   `docs/src/api.md` is in scope, and the brief says to keep `VariationalConfig` and `approximate_fit!` visible "with wording that they are not release-supported". That must not mean changing the marked inventory table schema or casually changing support cells unless the triage table is updated consistently. The safer instruction is: keep both rows as `scaffolded` in the marked inventory, and add any release-support clarification outside the machine-checked table or in existing support-band prose.

4. Extend the no-source/dependency verification to `Manifest.toml`.

   The plan says no dependency files are changed and the brief marks `Manifest.toml` out of scope, but the verification command only checks `src/` and `Project.toml`. Use `git diff --name-only -- src/ Project.toml Manifest.toml` so the acceptance criterion matches the stated boundary.

## Should Fix

1. Define the `.planning/PROJECT.md` out-of-scope table contract before implementation.

   The plan says to add a marked table, but it does not define the marker names, header, or exact row IDs beyond the brief's three identifiers. The guard test will be less brittle if the plan specifies one marked table with exact rows for `variational_inference`, `dashboard_ui`, and `ai_advisor`, and exact status wording such as `out-of-scope-v1` or `deferred`.

2. Clarify that the guard should be context-aware, not a blind ban on "VI".

   VI must remain mentionable for unsupported rows, historical notes, API inventory, and export-existence language. A blunt substring ban will either fail valid docs or push the builder into euphemisms. The test should reject supported-release contexts, not the term itself.

3. Add `README.md` and planning files to the explicit guard source list.

   `test/api_exports.jl` already walks `docs/src`, but this phase needs coverage for `README.md`, `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, and `.planning/ABACUS-PARITY-LEDGER.md` because the contradictions are spread across all of them.

## Cleared

- The plan honours the maintainer boundary against dashboard/UI work, AI-advisor work, source/runtime changes, export removal, runtime VI deprecation warnings, and full-suite verification.
- Keeping `VariationalConfig` and `approximate_fit!` exported as scaffolded pre-v1-review surfaces is coherent, provided the docs stop presenting them as supported v1 inference.
- Targeted verification through `make test-file FILE=test/api_exports.jl`, Runic on that file, and `git diff --check` is appropriate for this bounded docs/governance slice.
