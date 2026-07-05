# Phase 20: Public API Docstring Guard

## Status

Landed. The plan was reviewed before implementation, the implementation was
reviewed after the Builder pass, and the phase-closing local gate passed.

## Background

Phase 19 created a machine-checkable public API inventory in `docs/src/api.md`
and a focused `api_exports` test layer that keeps the inventory aligned with
the loaded `Epsilon` export surface.

`TECHNICAL-STANDARDS.md` also requires every exported symbol to have a
docstring, and the documentation policy says public APIs should appear in
canonical `@docs` or `@autodocs` blocks. A live probe after Phase 19 found the
current state is already good:

- 200 loaded exports.
- 0 missing docstring entries under the pre-plan `Base.Docs.doc` probe.
- 0 missing `Epsilon.<symbol>` entries inside Documenter `@docs` blocks.

The remaining gap is enforcement. `test/basic.jl` still has a curated
docstring smoke list for selected symbols, so future exported names could
regress documentation coverage unless someone remembers to update the broader
docs manually.

## Objective

Make the Phase 19 API inventory the source list for public API documentation
coverage and guard the repo standard that every export has both a docstring and
canonical docs membership.

## In Scope

- Extend the focused API guard test to assert every current exported symbol:
  - appears exactly once in the Phase 19 inventory;
  - has a deterministic, non-empty `Base.Docs.doc` entry;
  - appears in at least one Documenter `@docs` block as `Epsilon.<symbol>`.
- Remove or simplify the old curated docstring smoke list in `test/basic.jl`
  so there is one authoritative public API documentation guard.
- Keep `test/runtests.jl` thin. Reuse the existing `:api_exports` lane rather
  than creating a broad new test layer.
- Update `CHANGELOG.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, and
  `.planning/ABACUS-PARITY-LEDGER.md` conservatively.
- Refresh ignored Three Man Team handoff files for this phase.

## Out Of Scope

- Editing public API implementation modules for behavioural changes.
- Removing, renaming, or deprecating exports.
- Rewriting all docstrings for style.
- Forcing private/internal documented names out of existing `@docs` blocks.
  The guard should require every export to be documented; it should not fail
  merely because an internal helper is also documented.
- Claiming broad Abacus API parity.
- Adding GitHub Actions or hosted CI.

## Design

### Source List

Use the Phase 19 inventory as the source list, with the loaded module export
surface as the behavioural check. Do not regex `src/Epsilon.jl`.

The test should continue to derive exports with:

```julia
Set(Symbol.(names(Epsilon; all = false, imported = false)))
```

and delete `:Epsilon` if present.

### Docstring Check

For every symbol in the inventory/export set:

```julia
doc = _api_exports_doc_for(symbol)
```

The helper should:

1. call `getfield(Epsilon, symbol)`;
2. call `Base.Docs.doc(object)`;
3. catch lookup failures and treat them as missing documentation;
4. treat `nothing` as missing documentation;
5. render the returned doc object with `sprint(show, "text/plain", doc)` or an
   equivalent deterministic text rendering; and
6. reject empty rendered documentation after `strip`.

The test should collect and report a sorted list of symbols with missing or
empty docs rather than fail one symbol at a time. It should not assert on prose
length beyond non-empty rendering, wording, examples, or support-band status in
this phase.

### `@docs` Membership Check

Parse Markdown files under `docs/src/` for fenced `@docs` blocks and collect
entries matching exact stripped lines of the form `Epsilon.<symbol>`, where
`<symbol>` is `String(symbol)` from the inventory/export set. This exact-line
matching is intentional so Julia names ending in `!`, such as `fit!`,
`approximate_fit!`, and `fit_transform!`, are handled without a fragile
identifier regex.

The test should assert every exported symbol appears at least once in those
blocks and should report a sorted missing-symbol list.

Do not require exactly once. Existing docs intentionally split API references
across the home page, calibration page, and other sections. Duplicates are a
documentation polish issue, not a correctness issue for this guard.

Do not reject non-exported names inside `@docs` blocks. Existing docs may
intentionally include internal helpers where they explain an advanced or
bounded implementation detail.

This phase accepts scanning all Markdown files under `docs/src/` as the
canonical docs-membership surface and relies on `make docs` to catch build-level
reachability or Documenter errors. It does not parse `docs/make.jl` navigation.

### Existing `basic` Test

Replace the curated public-API docstring smoke list in `test/basic.jl` with a
short pointer-style test or remove that testset entirely if `api_exports` fully
covers it. Keep the version smoke test.

## Tasks

### Task 20-01: Plan Review Gate

**Acceptance criteria**

- [x] `PLAN.md` exists for Phase 20.
- [x] `handoff/ARCHITECT-BRIEF.md` describes scope, constraints, verification,
      and acceptance criteria.
- [x] A subagent reviewer has reviewed the plan before implementation.
- [x] Must Fix items from plan review are resolved or explicitly escalated.

**Status:** Landed. The first plan review found Must Fix items around
doc-lookup failure semantics and bang-suffixed `@docs` matching. The plan and
brief were patched, then re-reviewed with no remaining Must Fix items before
implementation.

### Task 20-02: Docstring And `@docs` Guard

**Acceptance criteria**

- [x] `test/api_exports.jl` checks every current inventory/export symbol has a
      deterministic non-empty `Base.Docs.doc` entry, treating lookup failures,
      `nothing`, and empty rendered docs as missing.
- [x] `test/api_exports.jl` checks every current inventory/export symbol
      appears as an exact stripped `Epsilon.<symbol>` line in at least one
      `docs/src` Documenter `@docs` block, including bang-suffixed names.
- [x] The guard continues to parse only the marked Phase 19 inventory table for
      inventory membership.
- [x] The guard does not reject documented internal helpers that are not
      exported.
- [x] Missing docstring and missing `@docs` failures are aggregated into sorted
      symbol lists.

**Status:** Landed. `test/api_exports.jl` now keeps the Phase 19
inventory/export exact-match checks and adds deterministic docstring plus
Documenter `@docs` membership guards for every inventoried/exported symbol.

### Task 20-03: Remove Curated Smoke Duplication

**Acceptance criteria**

- [x] `test/basic.jl` no longer maintains a hand-picked public API docstring
      list.
- [x] The version smoke test remains.
- [x] `test/runtests.jl` remains a thin dispatcher.

**Status:** Landed. `test/basic.jl` now contains only the version smoke test;
the public API documentation guard is centralised in `test/api_exports.jl`.

### Task 20-04: Planning And Release Notes Closure

**Acceptance criteria**

- [x] `CHANGELOG.md` records the documentation guard addition.
- [x] `.planning/ROADMAP.md` records Phase 20 as closed once implemented.
- [x] `.planning/STATE.md` points future work to the next bounded slice.
- [x] `.planning/ABACUS-PARITY-LEDGER.md` updates the package identity/public
      exports evidence as public API documentation hygiene only, without
      changing the row status from `scaffolded` or adding Abacus behavioural
      evidence claims.
- [x] Handoff files are refreshed.

**Status:** Landed. The package identity/public exports ledger row remains
`scaffolded`; this phase is recorded as public API documentation hygiene, not
Abacus behavioural evidence.

## Verification

Routine scoped verification:

```bash
JULIA_PKG_SERVER_REGISTRY_PREFERENCE=eager julia --project=. -e 'using Pkg; Pkg.test(; test_args=["api_exports", "basic"])'
julia --project=@runic -m Runic --check --diff test/api_exports.jl test/basic.jl
make docs
git diff --check
```

If implementation touches additional Julia files, include them in the Runic
command.

Closure verification before marking Phase 20 landed and committing the phase
closure:

```bash
make check-full
```

This closure gate is required because the phase updates `.planning/` state and
the parity ledger. If it is intentionally skipped, record that as an explicit
escalation.

**Verification result:** Passed. `make check-full` ran touched-file Runic,
full `Pkg.test()` with `Pass 5862, Total 5862` in 20m30.2s, and `make docs`.
The docs build completed with the known non-fatal large `index.html` warning
and skipped deployment outside CI.

## Risks And Mitigations

| Risk | Mitigation |
|---|---|
| Guard duplicates Documenter internals poorly | Parse only fenced `@docs` blocks and only require exported names to appear at least once. |
| Bang-suffixed Julia names are missed | Match exact stripped `Epsilon.<symbol>` lines from `String(symbol)` instead of using a `\w+`-style regex. |
| Doc lookup errors create noisy failures | Catch lookup/rendering failures and aggregate them as missing docs. |
| Phase becomes a docstring rewrite | Treat current docstrings as sufficient unless a test exposes a missing entry. |
| Private helper docs break the guard | Do not reject non-exported `@docs` entries in this phase. |
| Full suite is run unnecessarily during iteration | Use the focused `api_exports` and `basic` lanes during iteration; reserve `make check-full` for phase closure. |
| API documentation guard is mistaken for Abacus parity | Keep the ledger row `scaffolded` and describe this as documentation hygiene only. |

## Definition Of Done

- The plan is reviewed before implementation.
- Every current export is guarded for inventory membership, docstring presence,
  and canonical `@docs` membership.
- The curated smoke list in `test/basic.jl` is removed or reduced so it cannot
  drift separately from the inventory.
- Planning and release notes are updated without widening parity claims.
- Targeted iteration verification passes.
- The phase-closing `make check-full` gate passes, or any deliberate skip is
  recorded as an explicit escalation.
- Implementation is reviewed under the Three Man Team gate before commit.
