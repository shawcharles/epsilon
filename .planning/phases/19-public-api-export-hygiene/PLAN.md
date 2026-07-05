# Phase 19: Public API Export Hygiene

## Status

Landed. The plan was reviewed before implementation, the implementation was
reviewed after the Builder pass, and the phase-closing local gate passed.

## Background

The first row of `.planning/ABACUS-PARITY-LEDGER.md` remains `scaffolded`:
package identity and public exports need to be audited against the supported
core API. Recent phases added real capability surfaces for calibration,
scenario planning, and scenario stores, but the package entry point still
exports a broad flat surface from `src/Epsilon.jl`.

This phase is a bounded hygiene pass. It does not try to make the public API
small by breaking users immediately. It records what is currently exported,
classifies support status, and adds a local guard so future exports cannot be
added silently without documentation/status wording.

## Objective

Make the exported Epsilon public surface auditable without changing modelling
semantics or removing user-facing symbols.

## In Scope

- Add a user-facing public API support inventory covering every current
  exported symbol from the loaded `Epsilon` module surface.
- Classify each exported symbol under conservative support bands, such as:
  - `core`: stable supported Epsilon surface.
  - `bounded`: supported only for the documented bounded slice.
  - `compatibility`: retained for migration or legacy naming.
  - `scaffolded`: public because the implementation exists, but not yet broad
    Abacus parity evidence.
- Add a focused test that compares `names(Epsilon)` / exported symbols against
  the inventory so new exports require explicit classification.
- Keep the existing curated docstring smoke test, but extend coverage only if it
  can be done without turning the phase into a broad docstring remediation.
- Add a docs navigation entry for the public API/status inventory.
- Update `CHANGELOG.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, and
  `.planning/ABACUS-PARITY-LEDGER.md` conservatively.
- Refresh ignored Three Man Team handoff files for this phase.

## Out Of Scope

- Removing, renaming, or deprecating exports.
- Reorganising the `src/Epsilon.jl` export list as a broad refactor.
- Changing model, inference, transform, optimization, pipeline, plotting, or
  scenario-planner semantics.
- Claiming full Abacus package/API parity.
- Adding CI or GitHub Actions. Verification remains local-script driven.
- Running the full test suite during routine iteration. Full-suite verification
  is reserved for the phase-closing checkpoint because this phase updates
  `.planning/` state and the parity ledger. Routine iteration should use the
  focused `:api_exports` lane.

## Design

### Inventory Location

Use `docs/src/api.md` as the primary human-readable inventory. This keeps the
support contract in user-facing documentation rather than hidden in planning
state.

The page must contain a machine-checkable inventory table between explicit
markers:

```markdown
<!-- BEGIN PUBLIC API INVENTORY -->
| Symbol | Domain | Support |
|---|---|---|
| `fit!` | Model fitting | core |
<!-- END PUBLIC API INVENTORY -->
```

Only this marked table is parsed by the guard test. Narrative prose outside the
marked table can mention non-exported internals or future work without becoming
part of the current public API inventory.

The inventory should be checked from the actual loaded package export surface,
not manually trusted.

### Guard Test

Add a focused `:api_exports` test layer. The test should:

1. derive the actual public exported names with
   `Set(Symbol.(names(Epsilon; all = false, imported = false)))`;
2. remove `:Epsilon` if Julia exposes it in that set;
3. read only the marked inventory table in `docs/src/api.md`;
4. parse exactly one table row per inventory entry, with a backticked `Symbol`
   cell and non-empty `Domain` / `Support` cells;
5. assert every exported symbol appears exactly once in the table;
6. assert every table symbol is currently exported.

Do not derive expected exports by regexing `src/Epsilon.jl`; the loaded module
is the behavioural surface users get from `using Epsilon`.

This test is intentionally cheap and deterministic. It should be runnable with:

```bash
JULIA_PKG_SERVER_REGISTRY_PREFERENCE=eager julia --project=. -e 'using Pkg; Pkg.test(; test_args=["api_exports"])'
```

### Documentation Shape

The docs page should be concise but complete:

- define support bands;
- group exports by domain;
- explicitly state that classification is not a full Abacus parity claim;
- link or refer to the parity ledger for methodological evidence;
- include the marked `Symbol` / `Domain` / `Support` table as the inventory
  source of truth;
- retain `@docs` coverage in existing docs without forcing every export into a
  large `@docs` block in this phase.

This phase does not close the broader documentation-standard gap that every
exported symbol should eventually have a docstring. It creates the public API
status inventory and guardrail first; a future docstring-completeness pass can
use the inventory as its input list.

### Ledger Wording

The package identity/public exports row should remain `scaffolded` unless the
phase also proves a tighter API compatibility contract against Abacus. The
expected landing wording is: current exports are inventoried and support
classified; breaking cleanup/deprecation remains future work.

## Tasks

### Task 19-01: Plan Review Gate

**Acceptance criteria**

- [x] `PLAN.md` exists for Phase 19.
- [x] `handoff/ARCHITECT-BRIEF.md` describes scope, constraints, verification,
      and acceptance criteria.
- [x] A subagent reviewer has reviewed the plan before implementation.
- [x] Must Fix items from plan review are resolved or explicitly escalated.

**Status:** Landed. The initial plan review identified closure-verification,
inventory-parser, and loaded-export discovery Must Fix items; the plan was
patched and re-reviewed with no remaining Must Fix items before the Builder
implementation began.

### Task 19-02: Public API Inventory

**Acceptance criteria**

- [x] `docs/src/api.md` lists every current export from the loaded `Epsilon`
      module export surface.
- [x] Each export appears under a support band and domain group.
- [x] The page includes exactly one machine-checkable row per current exported
      symbol between `BEGIN PUBLIC API INVENTORY` and
      `END PUBLIC API INVENTORY` markers.
- [x] The page states that support classification is not equivalent to broad
      Abacus parity.
- [x] `docs/make.jl` includes the page in navigation.

**Status:** Landed. `docs/src/api.md` defines the support bands and carries a
200-row marked inventory table matching the current loaded module export
surface.

### Task 19-03: Export Guardrail Test

**Acceptance criteria**

- [x] A focused API export test layer is added to `test/runtests.jl`.
- [x] The test fails if an exported symbol is missing from the inventory.
- [x] The test fails if the inventory carries stale symbols that are no longer
      exported.
- [x] The test derives current exports from
      `names(Epsilon; all = false, imported = false)` rather than regexing
      source.
- [x] Existing `basic` smoke coverage remains intact.

**Status:** Landed. `test/api_exports.jl` parses only the marked inventory
table, rejects malformed/empty/duplicate/stale/missing rows, and compares
against `Set(Symbol.(names(Epsilon; all = false, imported = false)))` with
`:Epsilon` removed if present.

### Task 19-04: Planning And Release Notes Closure

**Acceptance criteria**

- [x] `CHANGELOG.md` records the API inventory/guardrail addition.
- [x] `.planning/ROADMAP.md` records Phase 19 as closed once implemented.
- [x] `.planning/STATE.md` points future work to the next bounded slice.
- [x] `.planning/ABACUS-PARITY-LEDGER.md` updates the public exports row and
      evidence wording without overstating parity.
- [x] `handoff/BUILD-LOG.md`, `handoff/REVIEW-REQUEST.md`,
      `handoff/REVIEW-FEEDBACK.md`, and `handoff/SESSION-CHECKPOINT.md` are
      refreshed.

**Status:** Landed. The package identity/public exports ledger row remains
`scaffolded`; this phase documents and guards the current surface but does not
remove exports or claim broad Abacus API parity.

## Verification

Routine scoped verification:

```bash
JULIA_PKG_SERVER_REGISTRY_PREFERENCE=eager julia --project=. -e 'using Pkg; Pkg.test(; test_args=["api_exports"])'
julia --project=@runic -m Runic --check --diff test/runtests.jl test/api_exports.jl docs/make.jl
make docs
git diff --check
```

If implementation touches additional Julia files, include those files in the
Runic command. Keep `test/runtests.jl` as a thin dispatcher; inventory parsing
belongs in `test/api_exports.jl`.

Closure verification before marking Phase 19 landed and committing the phase
closure:

```bash
make check-full
```

This closure gate is required because the phase updates `.planning/` state and
the parity ledger. If it is intentionally skipped, that must be recorded as an
explicit escalation rather than treated as the default.

**Verification result:** Passed. `make check-full` ran touched-file Runic,
full `Pkg.test()` with `Pass 4720, Total 4720` in 21m02.6s, and `make docs`.
The docs build completed with the known non-fatal large `index.html` warning
and skipped deployment outside CI.

## Risks And Mitigations

| Risk | Mitigation |
|---|---|
| Inventory becomes a false parity claim | Use support bands and explicitly defer broad Abacus package/API parity. |
| Phase balloons into breaking API cleanup | Forbid removals, renames, and deprecations in this phase. |
| Guard test becomes brittle to prose edits | Require simple backticked symbol tokens and keep parsing minimal. |
| Full suite is run unnecessarily during iteration | Use targeted `:api_exports`, docs, Runic, and whitespace checks for routine iteration; reserve `make check-full` for phase closure because `.planning/` state and the parity ledger are updated. |
| Export status choices are contentious | Use conservative labels; mark uncertain surfaces `scaffolded` rather than pretending stability. |

## Definition Of Done

- The plan is reviewed before implementation.
- Every current export has visible support-status wording in user docs.
- A focused local guard catches undocumented future exports.
- Planning and release notes are updated without widening the parity claim.
- Targeted iteration verification passes.
- The phase-closing `make check-full` gate passes, or any deliberate skip is
  recorded as an explicit escalation.
- Implementation is reviewed under the Three Man Team gate before commit.
