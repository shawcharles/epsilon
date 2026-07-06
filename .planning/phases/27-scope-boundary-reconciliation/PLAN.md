# Phase 27: Scope Boundary Reconciliation

## Status

Landed pending commit. Three Man Team plan review, Builder implementation, and
Reviewer clearance are complete. This phase reconciles the release-scope
contract after the maintainer clarified that Epsilon does not need dashboard/UI
parity and will not implement variational inference as a supported v1 surface.

## Objective

Make the documented v1 boundary internally consistent:

- MCMC/Turing is the supported v1 inference path.
- Dashboard/UI, AI advisor, and variational inference are out of scope for v1.
- Existing `VariationalConfig` and `approximate_fit!` implementation exports
  are not removed in this phase; they remain pre-v1 review surfaces until a
  separate API cleanup/deprecation contract is approved.

## Rationale

The repository already keeps Dash/UI and AI-advisor parity deferred, and recent
calibration phases explicitly rejected VI calibration. Older release docs still
present a bounded VI row as supported, which now contradicts the maintainer's
scope decision. That contradiction should be fixed before more release-facing
work, otherwise future planning, docs, and tests will keep pulling the library
toward an inference backend that is no longer wanted.

## In Scope

1. Update release-facing documentation and support matrices so they no longer
   claim supported VI rows.
2. Add a small guarded v1 out-of-scope table covering:
   - variational inference;
   - dashboard/UI and Dash parity;
   - AI advisor functionality.
3. Add focused guard coverage in `test/api_exports.jl` to prevent unsupported
   VI release claims from reappearing.
4. Update `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`,
   `.planning/ABACUS-PARITY-LEDGER.md`, and `CHANGELOG.md` to reflect the
   scope correction.
   Existing historical planning entries that say VI was implemented should be
   rewritten as historical implementation facts superseded by the Phase 27 v1
   release boundary, not left as current support claims.
5. Preserve the API inventory distinction between "export exists" and
   "release-supported surface".

## Out Of Scope

- Removing `VariationalConfig` or `approximate_fit!`.
- Adding runtime deprecation warnings for VI exports.
- Editing inference source files or model semantics.
- Reworking the public API cleanup RFC/triage lifecycle for VI.
- Running the full test suite.
- Adding dashboard/UI, hosted workflow, or AI-advisor functionality.

## Implementation Tasks

### 27-01: Plan And Review

- [x] Write this phase plan.
- [x] Write the Three Man Team architect brief.
- [x] Get a review pass on the plan/brief before implementation.

### 27-02: Documentation And Ledger Scope Correction

- [x] Replace supported VI row claims in `README.md`,
      `docs/src/index.md`, and `docs/src/release.md` with explicit
      out-of-scope wording.
- [x] Update `.planning/PROJECT.md` so VI is listed with the other deferred
      product/library boundaries.
- [x] Update `.planning/ROADMAP.md` and `.planning/STATE.md` so Phase 27 is
      the current closed scope-correction phase after landing.
- [x] Rewrite old planning-history VI support language as historical
      implementation detail superseded by Phase 27's release boundary.
- [x] Update `.planning/ABACUS-PARITY-LEDGER.md` so VI appears as an explicit
      deferred surface and no release-support wording remains.
- [x] Update `CHANGELOG.md` under `Unreleased`.

### 27-03: Focused Scope Guard

- [x] Extend `test/api_exports.jl` with a focused docs/scope guard.
- [x] Guard the marked v1 out-of-scope table.
- [x] Guard against legacy phrases or row IDs that would reintroduce supported
      VI release claims across release-facing and planning docs.

### 27-04: Review, Verification, Commit

- [x] Write the build log and review request.
- [x] Run the Three Man Team reviewer pass.
- [x] Resolve all Must Fix findings.
- [x] Run targeted verification only:
  - `make test-file FILE=test/api_exports.jl`
  - `julia --project=@runic -m Runic --check --diff test/api_exports.jl`
  - `git diff --check`
  - `git diff --name-only -- src/ Project.toml Manifest.toml`
- [x] Commit the reviewed scope correction.

## Acceptance Criteria

- No release-facing documentation claims VI is a supported v1 row.
- `VariationalConfig` and `approximate_fit!` remain documented as existing
  scaffolded exports, not as supported release surfaces.
- Dashboard/UI, AI advisor, and VI are all explicitly out of scope for v1.
- Focused guard tests fail if the old supported VI row IDs or support phrases
  are reintroduced in release-facing or planning docs.
- The guard is context-aware: it allows VI in unsupported/out-of-scope wording,
  historical-superseded notes, and API export-existence contexts, but rejects
  active supported-release claims such as "supported VI", "supported MCMC and
  VI", "supported MCMC and supported VI", "bounded explicit VI path", "bounded
  VI support", and the old row IDs `INF-TS-VI`, `POST-TS-VI`, and
  `OPT-TS-VI`.
- `.planning/PROJECT.md` contains one machine-checked table between
  `<!-- BEGIN V1 OUT OF SCOPE -->` and `<!-- END V1 OUT OF SCOPE -->` with
  header `| Surface | Status | Rationale |` and exact surface rows
  `variational_inference`, `dashboard_ui`, and `ai_advisor`, each with status
  `out-of-scope-v1`.
- No `src/` files or dependency files are changed.
- No full-suite run is performed for this bounded documentation/governance
  phase.

## Verification

Targeted commands only:

```bash
make test-file FILE=test/api_exports.jl
julia --project=@runic -m Runic --check --diff test/api_exports.jl
git diff --check
git diff --name-only -- src/ Project.toml Manifest.toml
```
