# Phase 22: Public API Export Cleanup RFC

**Status:** Landed.

## Context

Phase 21 created `.planning/API-EXPORT-TRIAGE.md`, a guarded lifecycle register
for the current 200 loaded `Epsilon` exports. It deliberately classified all
118 `scaffolded` exports as `review-before-v1` because no concrete migration
paths had been reviewed.

The next useful release-prep slice is not to remove exports. It is to turn a
small part of the `review-before-v1` pile into an explicit cleanup RFC:
identify high-confidence deprecation candidates, name concrete migration paths,
and guard the relationship between the RFC and the lifecycle register.

## Objective

Create a bounded public API cleanup RFC that reviews the `review-before-v1`
surface, identifies a small high-confidence set of deprecation candidates with
concrete migration paths, and keeps any resulting triage-register changes
machine-checkable. Runtime behaviour and exports must remain unchanged.

## In Scope

- Add `.planning/API-EXPORT-CLEANUP-RFC.md`.
- Review the current `review-before-v1` rows in
  `.planning/API-EXPORT-TRIAGE.md`.
- Identify a small, high-confidence candidate set, expected range 3-8 symbols.
- Candidate rows must have:
  - an existing exported replacement or existing public constructor/workflow;
  - a concrete migration note;
  - a short rationale;
  - a risk level;
  - an explicit "not yet removed" decision.
- Update `.planning/API-EXPORT-TRIAGE.md` only for candidates that meet that
  standard, changing lifecycle from `review-before-v1` to
  `deprecation-candidate` and replacing `n/a` migration notes with concrete
  migration text.
- Extend `test/api_exports.jl` so every `deprecation-candidate` row in the
  triage register appears exactly once in the RFC candidate table with matching
  migration text.
- Update `CHANGELOG.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, and
  `.planning/ABACUS-PARITY-LEDGER.md` conservatively.
- Refresh ignored Three Man Team handoff files.

## Out Of Scope

- Removing, renaming, or reordering exports in `src/Epsilon.jl`.
- Adding `Base.depwarn`, `@deprecate`, or runtime warning behaviour.
- Changing model, inference, transform, optimization, pipeline, plotting,
  calibration, or scenario-planner semantics.
- Changing user docs to announce actual deprecation warnings. This phase only
  records an RFC and planning-level lifecycle candidates.
- Broadly reclassifying the public API surface.
- Claiming stronger Abacus package/API parity.
- Benchmarking or release certification.

## Candidate Standard

Do not mark an export as `deprecation-candidate` merely because it looks
internal. A candidate must satisfy all of these:

1. The symbol is currently `review-before-v1` in the triage register.
2. The symbol has a concrete replacement using an already exported symbol,
   constructor, or documented public workflow.
   Prefer migration targets whose lifecycle is `keep-public`, `keep-bounded`,
   or `compatibility`, or a documented workflow the RFC explicitly commits to
   preserving. If a target is still `review-before-v1`, the RFC must explain
   why that is stable enough for this candidate.
3. Removing the export later would not remove the underlying method or type
   from the package; users could still qualify it as `Epsilon.symbol` until a
   later breaking cleanup if the implementation remains loaded.
4. The rationale is about API surface coherence, not hiding unfinished
   methodology.
5. The risk is low or medium and is explicitly named.

If the migration path depends on future API work, leave the lifecycle as
`review-before-v1` and mention it in the RFC's non-candidate notes instead.

## RFC Format

The RFC should contain a marked candidate table:

```markdown
<!-- BEGIN PUBLIC API CLEANUP CANDIDATES -->
| Symbol | Current Lifecycle | Proposed Lifecycle | Migration | Rationale | Risk | Decision |
|---|---|---|---|---|---|---|
| `validate_model_config` | review-before-v1 | deprecation-candidate | Use `ModelConfig` construction or `load_model_config`. | Public validation helper duplicates constructor/config loader validation paths. | low | Candidate only; no runtime change in Phase 22. |
<!-- END PUBLIC API CLEANUP CANDIDATES -->
```

Rules:

- `Symbol` must remain backtick-wrapped.
- Table cells must not contain raw `|` characters.
- `Current Lifecycle` must be the lifecycle before the Phase 22 proposal.
- `Proposed Lifecycle` must be `deprecation-candidate`.
- `Migration` must be non-empty and not `n/a`.
- `Decision` must exactly include:
  `Candidate only; no runtime or export change in Phase 22.`
- The table should stay small enough to review manually.

The RFC should also include a non-candidate notes section summarising common
classes left as `review-before-v1`, especially where migration paths are not
yet concrete.

## Test Extension

Extend `test/api_exports.jl`, keeping it the single public API governance test
entrypoint.

The new checks should:

1. parse `.planning/API-EXPORT-CLEANUP-RFC.md` between the candidate markers;
2. assert the candidate table header exactly matches the planned seven-column
   schema;
3. assert every RFC candidate is a current loaded export and appears in the
   triage register;
4. assert every RFC candidate has `Proposed Lifecycle ==
   "deprecation-candidate"`;
5. assert every RFC candidate has `Current Lifecycle == "review-before-v1"`;
6. assert every RFC candidate has non-empty, non-`n/a` migration text;
7. assert every RFC candidate decision contains the exact accepted phrase
   `Candidate only; no runtime or export change in Phase 22.`;
8. assert every triage-register `deprecation-candidate` appears exactly once in
   the RFC candidate table;
9. assert migration text matches between the triage register and RFC for each
   candidate;
10. aggregate missing, stale, duplicate, lifecycle-mismatched,
    decision-invalid, and migration-mismatched failures into sorted lists where
    practical.

The existing Phase 19, Phase 20, and Phase 21 checks must remain intact.

## Tasks

### Task 22-01: Plan Review

Acceptance criteria:

- [x] This plan is reviewed by an independent subagent before implementation.
- [x] Must Fix review items are resolved before Builder work starts.
- [x] The reviewed plan keeps the phase bounded to RFC, triage, guard, and
      planning hygiene.

Verification:

- [x] `handoff/ARCHITECT-BRIEF.md` matches the reviewed plan.
- [x] `handoff/REVIEW-FEEDBACK.md` records the plan review result.

**Status:** Landed. Independent plan review found no Must Fix items. Three
Should Fix items were incorporated before implementation: stricter migration
target wording, guard checks for current lifecycle and no-runtime/export
decision text, and triage glossary wording clarifying candidate-only status.

### Task 22-02: Cleanup RFC And Triage Updates

Acceptance criteria:

- [x] `.planning/API-EXPORT-CLEANUP-RFC.md` exists.
- [x] The RFC candidate table contains a small high-confidence candidate set.
- [x] Every candidate has concrete migration text to existing public API.
- [x] `.planning/API-EXPORT-TRIAGE.md` marks only those RFC-backed rows as
      `deprecation-candidate`.
- [x] No export removal or runtime deprecation behaviour is introduced.

Verification:

- [x] RFC/triage consistency checks pass through the focused `api_exports`
      lane.

**Status:** Landed. `.planning/API-EXPORT-CLEANUP-RFC.md` records six
candidate-only validation-helper rows. `.planning/API-EXPORT-TRIAGE.md` marks
only those six RFC-backed rows as `deprecation-candidate`, with exact matching
migration text and no runtime/export changes.

### Task 22-03: Focused Guard Extension

Acceptance criteria:

- [x] `test/api_exports.jl` parses the cleanup RFC candidate table.
- [x] The guard rejects triage `deprecation-candidate` rows missing from the
      RFC.
- [x] The guard rejects RFC candidates missing from the triage register or not
      marked as `deprecation-candidate`.
- [x] The guard rejects weak or mismatched migration notes.
- [x] The guard rejects candidates whose current lifecycle is not
      `review-before-v1`.
- [x] The guard rejects candidate decisions that do not state that Phase 22
      makes no runtime or export change.
- [x] Existing API inventory, docstring, `@docs`, and lifecycle-triage checks
      remain intact.

Verification:

```bash
JULIA_PKG_SERVER_REGISTRY_PREFERENCE=eager julia --project=. -e 'using Pkg; Pkg.test(; test_args=["api_exports", "basic"])'
```

**Status:** Landed. Focused `api_exports` plus `basic` verification passed with
`Pass 3689, Total 3689`.

### Task 22-04: Docs And Planning Closure

Acceptance criteria:

- [x] `CHANGELOG.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, and
      `.planning/ABACUS-PARITY-LEDGER.md` describe the phase conservatively.
- [x] The package identity/public exports ledger row remains `scaffolded`.
- [x] Three Man Team handoff files are refreshed.

Verification:

```bash
julia --project=@runic -m Runic --check --diff test/api_exports.jl
git diff --check
```

`make docs` is optional for this phase unless user-facing docs are edited.

**Status:** Landed. Runic on `test/api_exports.jl` and `git diff --check`
passed. User-facing docs were not edited, so standalone `make docs` was not run
during iteration; the phase-closing `make check-full` docs build passed.

### Task 22-05: Implementation Review And Commit

Acceptance criteria:

- [x] Builder writes `handoff/REVIEW-REQUEST.md`.
- [x] Reviewer writes `handoff/REVIEW-FEEDBACK.md`.
- [x] All Must Fix items are resolved before commit.
- [x] The commit includes only the intended Phase 22 files.

Closure gate:

Because this phase touches export-surface tests, `.planning/` state, and the
parity ledger, run the phase-closing gate after implementation review and
before committing:

```bash
make check-full
```

Do not run the full suite during normal iteration.

**Status:** Landed. Implementation review found no Must Fix items. The
phase-closing `make check-full` gate passed: full `Pkg.test()` reported
`Pass 7724, Total 7724` in 19m53.1s, followed by a successful docs build with
the known non-fatal `index.html` warning and deployment skipped outside CI.

## Risks

| Risk | Mitigation |
|---|---|
| RFC is mistaken for immediate deprecation | Candidate decisions must say no runtime/export change in Phase 22. |
| Candidate set becomes speculative | Require existing migration path; otherwise keep `review-before-v1`. |
| Hidden behavioural change sneaks in | Keep `src/` implementation files and `src/Epsilon.jl` out of scope. |
| Guard overfits prose | Check only the marked RFC candidate table and exact migration text. |
| Full suite is run too often | Use focused `api_exports`/`basic` and Runic during iteration; reserve `make check-full` for closure only. |

## Exit Criteria

- A reviewed cleanup RFC exists.
- Any `deprecation-candidate` lifecycle rows are backed by exact RFC candidate
  entries and concrete migration notes.
- No exports or runtime semantics change.
- The next phase can choose between implementing actual staged deprecation
  warnings or leaving candidates pending for maintainer review.
