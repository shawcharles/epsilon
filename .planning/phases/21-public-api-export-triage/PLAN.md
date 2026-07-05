# Phase 21: Public API Export Triage

**Status:** Landed.

## Context

Phase 19 made the current `Epsilon` export surface visible in
`docs/src/api.md`. Phase 20 made that inventory harder to accidentally rot by
requiring every inventoried/exported symbol to have a rendered docstring and a
Documenter `@docs` entry.

That still leaves the harder release-prep question unresolved: which of the
current 200 exports should be treated as durable public API, which are bounded
or compatibility surfaces, and which should be candidates for staged
deprecation or unexporting before a first stable release.

This phase is a triage and guardrail phase. It does not remove exports, rename
symbols, add runtime deprecation warnings, or change model behaviour. It creates
a durable decision register and a focused test so future API cleanup is
explicit, reviewed, and traceable.

## Objective

Create a machine-checkable public API triage register covering every current
loaded `Epsilon` export, classify each export under an explicit lifecycle
action, and document the bounded next steps for later deprecation or export
cleanup work without changing the package runtime surface.

## In Scope

- Add a durable API triage register, expected at
  `.planning/API-EXPORT-TRIAGE.md`, with one checked row per current export.
- Classify each export with a lifecycle action from a small controlled
  vocabulary:
  - `keep-public`: intended v1 public API candidate; not a stability guarantee
    until a stable release is cut.
  - `keep-bounded`: supported public API for a documented bounded slice.
  - `compatibility`: retained for migration, legacy naming, or Julia package
    convention.
  - `review-before-v1`: public today, but needs an explicit keep/deprecate
    decision before a stable release.
  - `deprecation-candidate`: likely should be unexported, renamed, or moved
    behind a narrower surface in a later breaking/deprecation phase.
- Require a short rationale for every row.
- Require a concrete replacement or migration note for every
  `deprecation-candidate` row.
- Extend the focused `test/api_exports.jl` lane to parse and validate the
  triage register against the loaded export surface.
- Update `docs/src/api.md` with a short pointer explaining that support status
  and lifecycle triage are related but different:
  support status describes the current documented scope; lifecycle action
  describes intended public API disposition.
- Update `CHANGELOG.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, and the
  parity ledger conservatively.
- Refresh ignored Three Man Team handoff files.

## Out Of Scope

- Removing, renaming, or reordering exports in `src/Epsilon.jl`.
- Adding `Base.depwarn`, `@deprecate`, or runtime warning behaviour.
- Changing docs `@docs` membership except for the short triage pointer.
- Changing model, inference, transform, optimization, pipeline, plotting,
  calibration, or scenario-planner semantics.
- Claiming stronger Abacus package/API parity.
- Benchmarking or full release certification.

## Design

### Register Format

The triage register should contain one machine-checkable table between explicit
markers:

```markdown
<!-- BEGIN PUBLIC API TRIAGE -->
| Symbol | Domain | Support | Lifecycle | Replacement / Migration | Rationale |
|---|---|---|---|---|---|
| `fit!` | Model lifecycle | scaffolded | review-before-v1 | n/a | Central public verb, but final lifecycle depends on first stable model API. |
<!-- END PUBLIC API TRIAGE -->
```

Rules:

- `Symbol`, `Domain`, and `Support` must match the Phase 19 inventory exactly
  for the same symbol.
- `Symbol` must remain backtick-wrapped.
- Table cells must not contain raw `|` characters.
- `Lifecycle` must be one of the controlled lifecycle values listed above.
- `Replacement / Migration` may be `n/a` except for
  `deprecation-candidate`, where it must name a concrete replacement, migration
  path, or staged removal mechanism. If no concrete migration exists yet, use
  `review-before-v1` instead.
- `Rationale` must be non-empty and should be short enough to keep the register
  reviewable.
- The register may group rows by ordinary Markdown headings outside the marked
  table, but the parser should only trust the marked table.

### Classification Bias

This phase should classify conservatively:

- Existing `core` support rows usually become `keep-public`.
- Existing `bounded` rows usually become `keep-bounded`.
- Existing `compatibility` rows usually become `compatibility`.
- Existing `scaffolded` rows usually become `review-before-v1` unless there is
  an obvious reason to mark them `keep-public`, `keep-bounded`, or
  `deprecation-candidate`.
- Mark `deprecation-candidate` only when the rationale is concrete and the
  migration note is concrete. A small high-confidence candidate set is better
  than a broad speculative burn list.

### Test Extension

Extend `test/api_exports.jl` rather than adding a second API guard file. The
existing focused lane should remain the single public API guard entrypoint.

The new testset should:

1. parse `.planning/API-EXPORT-TRIAGE.md` between the triage markers;
2. assert the table header exactly matches the planned six-column schema;
3. assert every loaded export appears exactly once;
4. assert every triage symbol also appears in the Phase 19 inventory;
5. assert `Domain` and `Support` match the inventory row for the same symbol;
6. assert every lifecycle value is in the controlled vocabulary;
7. assert every rationale is non-empty;
8. assert every `deprecation-candidate` has a non-empty, non-`n/a`
   replacement or migration note;
9. aggregate failures into sorted symbol lists where practical.

For the 200-export table, missing, duplicate, stale, domain-mismatched,
support-mismatched, lifecycle-invalid, empty-rationale, and weak
deprecation-migration failures should all be reported as aggregated sorted
lists where practical instead of stopping at the first bad row.

Do not derive expected exports by regexing `src/Epsilon.jl`; keep using the
loaded module export surface already used by the existing tests.

### Ledger Wording

The package identity/public exports row should remain `scaffolded`. Phase 21 is
API governance hygiene only. It is not Abacus behavioural evidence, not a
breaking cleanup, and not a v1 public API freeze.

Expected landing wording:

> Current exports are inventoried, documented, and now lifecycle-triaged in a
> guarded planning register. Export removals/deprecations and stronger Abacus
> API compatibility claims remain future work.

## Tasks

### Task 21-01: Plan Review

Acceptance criteria:

- [x] This plan is reviewed by an independent subagent before implementation.
- [x] Must Fix review items are resolved in the plan and handoff brief before
      Builder work starts.
- [x] The reviewed plan keeps implementation bounded to triage/register/test
      hygiene.

Verification:

- [x] `handoff/ARCHITECT-BRIEF.md` matches the reviewed plan.
- [x] `handoff/REVIEW-FEEDBACK.md` records the plan review result.

**Status:** Landed. Independent plan review found no Must Fix items. Four
Should Fix items were incorporated before implementation: non-freezing
`keep-public` wording, explicit Markdown table-cell grammar, concrete
deprecation-candidate migration notes, and aggregated failure output.

### Task 21-02: Triage Register

Acceptance criteria:

- [x] `.planning/API-EXPORT-TRIAGE.md` exists.
- [x] The marked table contains exactly one row for every current loaded
      export.
- [x] The register uses the six-column schema and controlled lifecycle
      vocabulary.
- [x] `Domain` and `Support` are copied from the guarded public API inventory.
- [x] `deprecation-candidate` rows, if any, include concrete migration notes.

Verification:

- [x] Register parser checks pass through the focused `api_exports` test lane.

**Status:** Landed. `.planning/API-EXPORT-TRIAGE.md` records 200 current loaded
exports with conservative lifecycle mapping: 34 `keep-public`, 45
`keep-bounded`, 3 `compatibility`, and 118 `review-before-v1`. No
`deprecation-candidate` rows were invented without a concrete migration path.

### Task 21-03: Focused Guard

Acceptance criteria:

- [x] `test/api_exports.jl` parses the triage register.
- [x] The focused API guard rejects missing, duplicate, stale, or mismatched
      triage rows.
- [x] The focused API guard rejects unknown lifecycle values.
- [x] The focused API guard rejects empty rationales and weak
      `deprecation-candidate` migration notes.
- [x] Existing inventory, docstring, and Documenter `@docs` checks remain
      intact.

Verification:

```bash
JULIA_PKG_SERVER_REGISTRY_PREFERENCE=eager julia --project=. -e 'using Pkg; Pkg.test(; test_args=["api_exports", "basic"])'
```

**Status:** Landed. The focused `api_exports` plus `basic` lane passed with
`Pass 3048, Total 3048`.

### Task 21-04: Docs And Planning Closure

Acceptance criteria:

- [x] `docs/src/api.md` points readers to the lifecycle triage register and
      distinguishes support status from lifecycle action.
- [x] `CHANGELOG.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, and
      `.planning/ABACUS-PARITY-LEDGER.md` describe the phase conservatively.
- [x] The package identity/public exports ledger row remains `scaffolded`.
- [x] Three Man Team handoff files are refreshed.

Verification:

```bash
julia --project=@runic -m Runic --check --diff test/api_exports.jl
make docs
git diff --check
```

**Status:** Landed. Runic on `test/api_exports.jl`, docs build, and
`git diff --check` passed. `make docs` emitted only the known non-fatal
`index.html` size warning and skipped deployment outside CI.

### Task 21-05: Implementation Review And Commit

Acceptance criteria:

- [x] Builder writes `handoff/REVIEW-REQUEST.md`.
- [x] Reviewer writes `handoff/REVIEW-FEEDBACK.md`.
- [x] All Must Fix items are resolved before commit.
- [x] The commit includes only the intended Phase 21 files.

Closure gate:

Because this phase touches export-surface tests, docs, `.planning/` state, and
the parity ledger, run the phase-closing gate after implementation review and
before committing:

```bash
make check-full
```

Do not run the full suite during normal iteration.

**Status:** Landed. Implementation review found no Must Fix items. The
phase-closing `make check-full` gate passed: full `Pkg.test()` reported
`Pass 7083, Total 7083` in 20m56.1s, followed by a successful docs build with
the known non-fatal `index.html` warning and deployment skipped outside CI.

## Risks

| Risk | Mitigation |
|---|---|
| Triage is mistaken for a v1 API freeze | State repeatedly that this is lifecycle triage, not a freeze or breaking cleanup. |
| Candidate list becomes speculative | Prefer `review-before-v1` unless a deprecation rationale and migration note are concrete. |
| Register drifts from inventory | Focused `api_exports` guard checks symbol, domain, and support against `docs/src/api.md`. |
| Full suite is run too often | Use focused `api_exports`/`basic`, Runic, docs, and diff checks during iteration; reserve `make check-full` for closure only. |
| Abacus parity is overclaimed | Keep ledger row `scaffolded` and call this governance hygiene only. |

## Exit Criteria

- Every current export has a guarded lifecycle triage row.
- Future export additions require both support-status documentation and
  lifecycle-disposition wording.
- No package runtime behaviour changes.
- The next API cleanup phase has a concrete register to work from instead of a
  fresh subjective audit.
