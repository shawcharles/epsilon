# Phase 16: Scenario Planner Manual Allocation Evaluation

## Status

Task 16-01 is landed. Tasks 16-02 through 16-04 remain.

## Goal

Extend the bounded non-UI scenario planner so analysts can evaluate manually
specified channel allocations against existing fitted time-series MMM response
surfaces, without fitting another model, solving another optimization problem,
or introducing Dash/background-job scenario-store behaviour.

## Boundary

In scope:

- `TimeSeriesMMM`/`InferenceResults` manual channel-allocation evaluation.
- Existing `ManualAllocationScenarioSpec` inputs.
- Existing response-curve and bounded optimization interpolation semantics.
- Deterministic comparison tables against current spend and, later, solved
  fixed-budget optimization results.

Out of scope:

- Automatic scenario refits.
- Future spend-path simulation.
- Dash/UI workflows.
- Background jobs or hosted scenario stores.
- Free channel-by-panel allocation.
- Panel manual-allocation evaluation until a separate historical-share contract
  is written and tested.

## Architecture Decisions

- Manual allocation evaluation should reuse the Phase 8 response-surface
  machinery rather than inventing a second response approximation path.
- A manual scenario may allocate a subset of channels; unallocated channels are
  held at observed spend, matching the existing subset-optimization contract.
- First support is time-series only. Panel support must be designed separately
  because panel response curves use shared historical-scaling deltas, not
  direct channel-by-panel spend cells.
- The existing `ManualAllocationScenarioSpec` remains an intent object. Task
  16-01 adds an evaluated result object; later tasks project that result into
  `ScenarioPlanResult` tables.

## Task 16-01: Manual Scenario Evaluation Contract

**Status: Landed (2026-07-05).** Added
`ManualScenarioEvaluationResult` and `evaluate_manual_scenario(results,
scenario)` for bounded time-series manual allocation evaluation. The evaluator
reuses the Phase 8 response-surface interpolation path, holds omitted channels
at observed spend, rejects invalid manual evaluation contracts, and does not
refit, optimize, simulate future paths, or add panel manual-allocation
semantics. Synthetic response-surface tests passed in the scoped scenario
planner lane.

**Description:** Add a typed manual-scenario evaluation result and a
time-series evaluator that consumes grouped `InferenceResults` plus one
`ManualAllocationScenarioSpec`. The evaluator should compute current versus
manual total spend, expected response, response delta, spend delta, and default
efficiency using the existing response-surface interpolation path.

**Acceptance criteria:**

- [x] Public docstrings describe that evaluation is time-series only and does
      not refit or optimize.
- [x] Manual allocations reject unknown channels, empty/zero-total evaluated
      budgets, and values outside the response-surface interpolation domain
      with explicit `ArgumentError`s.
- [x] Unallocated channels are held at observed spend.
- [x] Deterministic tests cover total response, spend maps, efficiency, subset
      allocation, and failure modes using synthetic response surfaces.

**Verification:**

- [x] `julia --project=. -e 'using Pkg; Pkg.test(; test_args=["scenario_planner"])'`
- [x] `julia --project=@runic -m Runic --check --diff src/scenario_planner.jl test/scenario_planner.jl`

**Dependencies:** Existing Phase 8 response-surface helpers and existing
`ManualAllocationScenarioSpec`.

**Files likely touched:**

- `src/scenario_planner.jl`
- `src/Epsilon.jl`
- `test/scenario_planner.jl`
- `docs/src/index.md`

**Estimated scope:** Medium.

## Task 16-02: Scenario Plan Table Projection

**Description:** Project one or more `ManualScenarioEvaluationResult` values
into `ScenarioPlanResult` tables alongside the current scenario. This task
should preserve the existing current-versus-optimized `scenario_plan(result)`
method and add a clearly separate manual-evaluation path.

**Acceptance criteria:**

- [ ] Manual rows appear in totals, channel, allocation, and metadata tables.
- [ ] Existing `scenario_plan(::BudgetOptimizationResult)` output remains
      backward compatible.
- [ ] Table columns distinguish `manual_allocation` from
      `fixed_budget_optimized`.

**Verification:**

- [ ] `julia --project=. -e 'using Pkg; Pkg.test(; test_args=["scenario_planner"])'`
- [ ] Targeted Runic check on touched Julia files.

**Dependencies:** Task 16-01.

**Estimated scope:** Medium.

## Task 16-03: Optimized Plus Manual Comparison

**Description:** Allow a scenario plan to combine current, manual, and solved
fixed-budget optimized scenarios when the caller supplies both the original
grouped `InferenceResults` and the solved optimization result. This is the
analyst-facing comparison surface: current plan, proposed manual mix, and
optimizer recommendation.

**Acceptance criteria:**

- [ ] Manual and optimized scenarios can be compared in one deterministic
      result.
- [ ] The function refuses mismatched model specs or coordinate metadata
      between grouped results and optimization results.
- [ ] No additional optimization solve or model fit is triggered.

**Verification:**

- [ ] Scenario planner tests.
- [ ] Optimisation summary tests if shared table helpers change.

**Dependencies:** Tasks 16-01 and 16-02.

**Estimated scope:** Medium.

## Task 16-04: Documentation, Changelog, And Ledger Guardrails

**Description:** Update user-facing docs, changelog, and the Abacus parity
ledger to record the bounded manual-allocation evaluation surface without
claiming Dash or scenario-store parity.

**Acceptance criteria:**

- [ ] Docs describe supported manual allocation semantics and exclusions.
- [ ] Changelog records the new user-facing planner capability.
- [ ] Ledger row remains no stronger than the evidence supports.

**Verification:**

- [ ] `make docs`
- [ ] Targeted scenario planner tests.

**Dependencies:** Tasks 16-01 through 16-03.

**Estimated scope:** Small.

## Checkpoint A: Evaluator Contract

After Task 16-01: **COMPLETE (2026-07-05).**

- [x] Manual evaluation semantics are deterministic and tested.
- [x] No public docs imply panel, refit, UI, or scenario-store support.
- [x] Verification remains scoped to scenario planner and formatting.

## Checkpoint B: Planner Projection

After Tasks 16-02 and 16-03:

- [ ] Manual scenarios appear in comparison tables.
- [ ] Existing optimized scenario tables are backward compatible.
- [ ] Combined current/manual/optimized comparison refuses mismatched artifacts.

## Checkpoint C: Closure

After Task 16-04:

- [ ] Docs, changelog, and ledger match the implemented surface exactly.
- [ ] Any broader verification is either run deliberately or deferred with a
      precise reason.

## Risks And Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Manual evaluation duplicates optimisation response math | High | Reuse Phase 8 response-surface helpers and interpolation. |
| Manual allocation silently changes fixed channels | Medium | Treat omitted channels as fixed at observed spend and test it. |
| Panel semantics are widened accidentally | Medium | Reject panel grouped results until a separate historical-share contract exists. |
| Scenario planner becomes Dash parity by stealth | Medium | Keep Phase 16 non-UI and artifact/table oriented only. |
| Full-suite runs slow routine iteration | Low | Use scenario-planner tests and targeted Runic checks unless exports/shared namespace changes require broadening. |

## Open Questions

- Should Task 16-03 accept multiple manual scenarios in one call, or should that
  wait for saved scenario-store artifacts?
- Should manual scenario evaluation expose uncertainty intervals from draw-level
  response curves, or keep the first surface on posterior-mean response for
  parity with Phase 8 optimization?
