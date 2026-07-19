# Phase 47: Public Identity Rewrite

Status: Landed

## Objective

Make Epsilon's public-facing documentation read as an independent Julia MMM
library, not as an Abacus clone or "Julia port", while preserving the honest
validation history that Abacus-derived fixtures and the parity ledger provide.

This phase is a documentation and guardrail slice. It does not change model
behaviour, fixture generation, runtime APIs, benchmarks, release gates, or
statistical scope.

## Background

The project used Abacus as a production-tested reference implementation during
the build-out of comparable MMM semantics. That remains useful validation
provenance, but it should no longer be the first public identity of Epsilon.
Epsilon should now present itself as a Julia-native MMM library with
comparison-backed evidence where semantics match.

Phase 46 planned the broader reference decoupling work. Phase 47 executes the
first bounded public-doc rewrite and adds a regression guard so future edits do
not reintroduce dependent-product phrasing.

## In Scope

- Rewrite current public-facing identity language in root docs and docs pages
  from "Abacus Julia port" or product-parity framing to Epsilon-first language.
- Preserve concrete validation provenance where it is technically material:
  committed fixtures, parity/status ledger, and scoped comparison evidence.
- Reframe user-facing caveats from "Abacus parity" to narrower
  "reference-parity" or "validation evidence" language where possible.
- Update examples that describe toy/demo workflows so they are not presented as
  Abacus parity claims.
- Add or update a focused test guard in `test/api_exports.jl` that rejects
  public dependent-product phrasing such as "Abacus Julia port".
- Correct the Phase 46 planning inventory inconsistency that counted ignored
  built docs even though the tracked-file inventory explicitly excluded them.
- Update roadmap/state documentation for Phase 47.

## Out Of Scope

- Renaming `test/fixtures/abacus/`, `scripts/export_abacus_fixtures.py`, or the
  parity ledger file itself.
- Scrubbing historical planning records or deleting validation provenance.
- Changing source/runtime behaviour.
- Changing benchmark evidence, running benchmark jobs, or making release
  certification claims.
- Reopening VI, dashboards, panel validation, free channel-by-panel
  optimisation, or other deferred modelling surfaces.
- Running the full test suite for this docs-only slice.

## File Allowlist

Implementation may touch only these tracked files:

- `README.md`
- `CONTRIBUTING.md`
- `TECHNICAL-STANDARDS.md`
- `docs/src/index.md`
- `docs/src/release.md`
- `docs/src/api.md`
- `docs/src/calibration.md`
- `docs/src/benchmarks.md`
- `docs/src/supported_paths.md`
- `examples/toy_mmm/README.md`
- `examples/csv_mmm/README.md`
- `examples/demo/README.md`
- `test/api_exports.jl`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/46-abacus-reference-decoupling/PLAN.md`
- `.planning/phases/47-public-identity-rewrite/PLAN.md`

The pre-existing untracked file
`.planning/CRITICAL-REVIEW-2026-07-19.md` must remain untracked and must not be
included in the commit.

## Tasks

### Task 47-01: Rewrite Public Identity Copy

- Replace first-viewport and root-document "Abacus Julia port" framing with
  Epsilon-first language.
- Keep references to the validation ledger and fixture-backed comparisons where
  they substantiate claims.
- Avoid implying broad parity with any upstream product or API surface.

Acceptance criteria:

- [x] `README.md` introduces Epsilon as an independent Julia-native MMM
      library.
- [x] `README.md` no longer presents the project as an "Abacus Julia port".
- [x] Public docs distinguish current supported Epsilon capabilities from
      historical reference-comparison evidence.

### Task 47-02: Reframe Examples And Caveats

- Update toy/demo example READMEs so they describe local Epsilon workflows,
  not release evidence or upstream parity.
- Reframe public "Abacus parity" caveats as reference-parity or validation
  caveats when the underlying point is still needed.

Acceptance criteria:

- [x] Example docs remain honest about toy/demo limitations.
- [x] Public caveats are still conservative but do not centre Abacus as the
      product identity.

### Task 47-03: Add Public Identity Regression Guard

- Update `test/api_exports.jl` with focused checks for banned public identity
  phrases.
- Keep existing release-evidence guardrails, adjusted only where wording moves
  from Abacus-specific to reference-parity language.

Acceptance criteria:

- [x] Guard rejects "Abacus Julia port" style public copy.
- [x] Guard bans only active public dependent-product phrasing, not all Abacus
      or provenance references.
- [x] Guard continues to reject accidental use of docs/examples as parity,
      benchmark, or release evidence.
- [x] Release-gate docs still preserve `VAL-TS-00-MCMC`, committed fixture
      provenance, and the Epsilon-native/reference-row distinction.
- [x] `make test-file FILE=test/api_exports.jl` passes.

### Task 47-04: Planning Closure

- Correct the Phase 46 tracked-file inventory note about ignored `docs/build`.
- Mark Phase 47 complete in roadmap/state once verification passes.

Acceptance criteria:

- [x] `.planning/phases/46-abacus-reference-decoupling/PLAN.md` no longer
      counts ignored built docs as tracked inventory.
- [x] `.planning/ROADMAP.md` and `.planning/STATE.md` name Phase 47 and its
      status accurately.

## Verification

Run only scoped checks for this docs-and-guardrail phase:

```bash
make test-file FILE=test/api_exports.jl
make docs
make format-check-touched
git diff --check
git diff --cached --check
```

Before commit, verify the changed-file allowlist exactly and confirm
`.planning/CRITICAL-REVIEW-2026-07-19.md` remains untracked and unstaged.

No full test suite is required for this phase because source/runtime behaviour
is unchanged and the focused guard test covers the only executable change.

## Review Notes

An independent review pass must check this plan before implementation begins,
with particular attention to:

- whether the allowlist is narrow enough,
- whether validation provenance is preserved,
- whether the new guard is too broad and might ban legitimate historical
  planning evidence,
- whether the Phase 46 inventory correction belongs in this slice, and
- whether scoped verification is sufficient.

Review completed before implementation. The review required two constraints:
preserve release-gate provenance explicitly, and ban only active
dependent-product identity phrases rather than all Abacus/provenance
references. Both constraints were added to Task 47-03 before implementation.

Landing note: Phase 47 rewrote current public identity wording in root docs,
selected user docs, and example READMEs; added a targeted
`test/api_exports.jl` guard against active dependent-product phrases; preserved
`VAL-TS-00-MCMC` and Abacus-derived fixture provenance in release docs; updated
roadmap/state; and corrected the Phase 46 ignored `docs/build/` inventory row.
No runtime source, dependencies, benchmark artifacts, smoke harness, full-suite
gate, or parity-status files changed.
