# Phase 18: Scenario Store Artifacts

## Status

Phase 18 is complete. The initial plan was reviewed by a Three Man Team
subagent before implementation, reviewer Must Fix feedback was incorporated,
and the implementation was reviewed before commit.

## Goal

Persist the already-supported non-UI scenario-planner outputs as durable,
reloadable artifacts without adding Dash/UI behaviour, hosted/background
scenario stores, automatic scenario refits, future spend-path simulation,
pipeline orchestration, or panel manual-allocation semantics.

## Boundary

In scope:

- A small typed scenario-store payload for `ScenarioPlanResult`.
- Deterministic write/load helpers for local filesystem artifacts.
- Hard validation on load for schema version, table shape, model/spec identity,
  channel order, coordinate metadata, objective, and baseline compatibility.
- Focused scenario-planner tests and public docs for the file contract.
- Changelog, roadmap, state, and parity-ledger guardrails.

Out of scope:

- Dash/UI, hosted workspaces, background jobs, or multi-user scenario stores.
- Automatic scenario refits or optimization solves.
- Future spend-path simulation.
- Panel manual allocation evaluation.
- Pipeline stage emission of scenario-store artifacts.
- Broad Abacus scenario-planner product parity.

## Architecture Decisions

- The store is a local artifact contract, not an application state service.
- `ScenarioPlanResult` remains the canonical in-memory result type.
- Store write/load uses stdlib `Serialization` for the typed local payload and
  CSV sidecar tables for human inspection. This is a local Epsilon/Julia
  artifact, not a cross-version portable interchange archive.
- The typed payload carries `ModelArtifactMetadata`, `MMMModelSpec`,
  `ModelCoordinateMetadata`, `objective`, `channel_columns`, and baseline
  summary fields so incompatible artifacts can be rejected before use.
- CSV sidecars are read-only convenience outputs; `load_scenario_store` returns
  a typed `ScenarioStoreArtifact`, and `scenario_store_plan(store)` explicitly
  projects its copied `ScenarioPlanResult`.
- `metadata`, `spec`, and `coordinate_metadata` are trusted constructor inputs,
  not values inferred from tables. Tables must still cross-check against those
  trusted inputs before a store artifact can be constructed.
- Writers replace known sidecar files deterministically and remove stale
  `channel_panel_allocations.csv` when the current plan has no panel-allocation
  table.
- The scenario planner ledger row remains `scaffolded`.

## Task 18-01: Store Contract And Validation

**Description:** Add a typed `ScenarioStoreArtifact` payload plus helpers that
extract and validate contract metadata from a `ScenarioPlanResult`.

**Acceptance criteria:**

- [x] Store artifacts carry schema version, metadata, spec, coordinate
      metadata, objective, channel order, baseline scenario id, and the five
      `ScenarioPlanResult` tables.
- [x] Construction rejects missing or repeated current baseline rows,
      inconsistent objective values across totals/metadata, inconsistent
      channel order versus `spec.channel_columns`, malformed variant-specific
      table columns, and allocation rows whose baseline ids do not match the
      current baseline.
- [x] Store construction copies DataFrames so mutating the input plan after
      writing cannot mutate the stored artifact.
- [x] No model fitting, optimization solving, manual evaluation, or pipeline
      execution is introduced.

**Verification:**

- [x] Focused scenario-planner tests.
- [x] Targeted Runic check on touched Julia/test files.

**Status:** Landed. `ScenarioStoreArtifact` validates the store contract over
existing `ScenarioPlanResult` tables and rejects malformed current baselines,
objective drift, channel-order drift, missing/duplicate allocation channels,
unknown scenario ids, and baseline-id mismatches. Store construction and
projection copy DataFrames.

## Task 18-02: Local Write/Load API

**Description:** Add deterministic local artifact APIs:
`write_scenario_store(path, plan; metadata, spec, coordinate_metadata)`,
`load_scenario_store(path)`, and `scenario_store_plan(store)`.

**Acceptance criteria:**

- [x] `write_scenario_store` creates or reuses a directory containing a typed
      `scenario_store.jls` payload plus deterministic CSV sidecars for totals,
      channels, allocations, metadata, and channel-panel allocations when
      present; known stale sidecars are replaced or removed.
- [x] `load_scenario_store` restores and validates the typed artifact.
- [x] `scenario_store_plan(store)` reconstructs a copied `ScenarioPlanResult`
      from a loaded or newly constructed store.
- [x] Existing `scenario_plan(...)` behavior is unchanged.
- [x] Invalid paths, missing payloads, corrupt payloads, and unsupported schema
      versions fail closed with explicit `ArgumentError`s where Julia
      deserialization permits wrapping.

**Verification:**

- [x] Focused scenario-planner write/load tests.
- [x] `git diff --check`.

**Status:** Landed. `write_scenario_store`, `load_scenario_store`, and
`scenario_store_plan` provide the local typed payload plus CSV sidecar contract.
Tests cover write/load, stale optional sidecar removal, non-empty panel sidecar
emission, manual-only plans, combined manual/optimised plans, corrupt payloads,
and unsupported schema versions.

## Task 18-03: Compatibility Guardrails

**Description:** Add explicit comparison helpers so users can assert whether two
loaded scenario stores may be compared or reused together.

**Acceptance criteria:**

- [x] `assert_scenario_store_compatible(a, b)` rejects mismatched model
      metadata, model spec, coordinate metadata, channel order, objective, and
      current baseline fields.
- [x] Mismatches are reported as clear `ArgumentError`s, not downstream table
      failures.
- [x] Compatible stores pass without modifying either artifact.

**Verification:**

- [x] Focused mismatch tests for each guarded field.

**Status:** Landed. Compatibility checks reject model metadata, spec,
coordinate metadata, channel order, objective, and current-baseline mismatches
before stores are compared.

## Task 18-04: Docs, Changelog, And Ledger Closure

**Description:** Document the local non-UI store contract and close Phase 18
planning state without overclaiming Abacus scenario-planner parity.

**Acceptance criteria:**

- [x] Docs describe the supported local artifact layout, the
      Epsilon/Julia-version-bound serialization limit, and unsupported paths.
- [x] Changelog records the capability without implying Dash/UI, hosted store,
      background-job, refit, future-path, or panel-manual-allocation support.
- [x] Roadmap, state, handoff, and parity ledger reflect Phase 18 closure while
      keeping the scenario-planner row `scaffolded`.

**Verification:**

- [x] `make docs`
- [x] Focused scenario-planner tests from Tasks 18-01 through 18-03.

**Status:** Landed. Public docs, changelog, roadmap, state, and ledger wording
record the bounded local scenario-store artifact surface while preserving
unsupported Dash/UI, hosted/background-store, automatic-refit, future-path,
pipeline-emission, and panel-manual-allocation guardrails. The scenario-planner
ledger row remains `scaffolded`.

## Risks And Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Store artifacts become an implied app platform | High | Keep the API local-file-only and explicitly exclude hosted/background stores. |
| CSV sidecars become the source of truth | Medium | Load only from the typed payload; treat CSV as inspection output. |
| Incompatible scenarios are compared silently | High | Store and validate metadata/spec/coordinate/objective/baseline fields. |
| Stale sidecar files mislead users | Medium | Replace known sidecars and remove absent optional sidecars on each write. |
| Broad Abacus scenario-planner parity is overclaimed | Medium | Keep the ledger row `scaffolded` and document unsupported surfaces. |
