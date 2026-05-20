# Phase 8 Plan - Budget Optimization

**Phase:** 8
**Phase Name:** Budget Optimization
**Status:** In Progress
**Last Reconciled:** 2026-04-22

## Objective

Turn the frozen Phase 7 response and metric surfaces into one truthful,
bounded optimization layer that can allocate fixed budget across supported
media channels without reopening model, inference, or post-model semantics.

Phase 8 is where Epsilon starts producing optimizer outputs from the canonical
Phase 7 post-model contract:

- optimized channel spend allocations
- optimized expected response
- current versus optimized efficiency comparisons
- constraint-audit outputs for bounded optimization runs

The key constraints are:

- Phase 8 must consume the frozen Phase 7 response and metric surfaces rather
  than optimize directly against raw posterior objects.
- Phase 8 must settle the fixed-budget optimization contract up front instead
  of leaving solver, objective, and constraint semantics to implementation-time
  decisions.
- Phase 8 remains time-series first and must not invent premature panel
  optimization semantics.

## Entry Conditions

Phase 7 is closed and the following are already in place:

- canonical grouped `InferenceResults`
- deterministic replay for supported time-series grouped artifacts
- typed `ContributionResults`, `DecompositionResults`, `ResponseCurveResults`,
  and `MetricResults`
- `response_curve_results(results; channel, grid)` on supported
  `TimeSeriesMMM` MCMC and VI grouped artifacts
- `metric_results(results; channel, grid)` derived from the same response
  surface
- explicit post-model support matrix with honest panel failure

Phase 8 must build on those contracts instead of redefining them.

## Current Base To Extend

The current bounded post-model base is:

- canonical grouped artifact:
  - `InferenceResults`
- canonical post-model typed surfaces:
  - `ResponseCurveResults`
  - `MetricResults`
- current supported post-model rows:
  - `TimeSeriesMMM` + Turing MCMC
  - `TimeSeriesMMM` + bounded VI
- current unsupported post-model rows:
  - `PanelMMM` post-model outputs

Phase 8 must add one coherent optimization layer on top of that base.

## Phase 8 Optimization Contract

Phase 8 fixes the optimization contract up front:

- Optimization is fixed-budget and time-series first.
- Optimization consumes canonical grouped `InferenceResults` through the frozen
  Phase 7 response and metric surfaces.
- Phase 8 does not optimize directly against raw posterior objects, raw
  `Chains`, ad hoc posterior summaries, or backend-specific inference objects.
- Phase 8 does not introduce new future-window or pacing semantics. The
  bounded optimizer works on the same observed horizon semantics already frozen
  by Phase 7 response curves:
  - total spend in original units over the current observed horizon
  - observed intra-horizon spend shape preserved within each selected channel
- Phase 8 does not introduce cross-channel interaction terms. Total modeled
  response for optimization is defined as:
  - fixed non-media baseline components from the current fitted artifact
  - plus the sum of channel-level response surfaces for the optimized channels
- Phase 8 optimizes posterior mean expected total response.
- Efficiency metrics such as ROAS and CPA are reported from the optimized
  allocation but are not separate optimization objectives in the bounded Phase
  8 surface.
- Multi-objective trade-offs, stochastic utility functions, and direct
  risk-aware optimization are deferred beyond Phase 8.

## Public Contract

The canonical public entry point for Phase 8 is:

- `optimize_budget(results::InferenceResults; total_budget, channels=nothing, budget_bounds=nothing, relative_bounds=nothing, objective=:total_response, grid=nothing)`

The canonical typed result surface is:

- `BudgetOptimizationResult`

Phase 8 should also expose bounded comparison and audit projections over that
typed result, but those projections are additive views rather than a second
canonical optimization artifact.

The typed result surface must preserve:

- optimized spend by channel
- current spend by channel
- optimized posterior response summaries
- current posterior response summaries
- optimized and current efficiency summaries using the default Phase 7 metric
  for the model target type
- solver status, objective value, and convergence metadata
- explicit constraint-audit information

## Public Keyword Shapes

The public entry point stays small, but the keyword contract is fixed now
rather than left to `08-01` implementation-time choices:

- `total_budget::Real`
  - required
  - interpreted in original total-horizon spend units
  - applies to the optimized channel set only
  - must be finite and non-negative
- `channels::Union{Nothing, AbstractVector{<:AbstractString}}`
  - `nothing` means optimize all modeled media channels in canonical model-spec
    order
  - when provided, it must be a unique subset of modeled channel names
  - duplicate or unknown names are contract errors
- `budget_bounds`
  - channel-keyed mapping of `channel_name => (lower=?, upper=?)`
  - values are absolute spend bounds in original total-horizon units
  - omitted `lower` / `upper` sides are treated as unbounded within this bound
    family
- `relative_bounds`
  - channel-keyed mapping of `channel_name => (lower=?, upper=?)`
  - values are multiplicative guardrails against observed channel totals over
    the frozen Phase 7 horizon
  - for example, `lower=0.8, upper=1.2` means 80%-120% of observed spend
  - omitted `lower` / `upper` sides are treated as unbounded within this bound
    family
- `grid`
  - `nothing` means use the canonical deterministic grid builder defined below
  - when provided, it must be a channel-keyed mapping of
    `channel_name => spend_grid::AbstractVector{<:Real}`
  - spend grids are expressed in original total-horizon spend units
  - spend grids must be finite, non-negative, strictly increasing, and cover
    the full feasible domain for that channel after bound normalization
- `objective`
  - only `:total_response` is supported in Phase 8

Phase 8 does not accept public optimization inputs in normalized shares,
date-level spend units, percentages on a 0-100 scale, or backend-specific
constraint objects.

## Objective And Constraint Semantics

Phase 8 freezes the bounded objective and constraint set:

### Objective

- supported objective:
  - `:total_response`
- objective meaning:
  - maximize posterior mean total modeled response under a fixed total budget
- unsupported in Phase 8:
  - direct ROAS-maximization objective
  - direct CPA-minimization objective
  - weighted multi-objective trade-offs
  - stochastic utility families over posterior draws

### Objective Evaluation Contract

The canonical optimization objective is evaluated from the frozen Phase 7
response surface using one deterministic contract:

- for each optimized channel, Phase 8 first materializes a channel-level
  posterior-mean response curve over a spend grid in original total-horizon
  units
- when `grid=nothing`, the canonical grid builder must:
  - start at `0`
  - end at `max(current_channel_spend, total_budget, finite_effective_upper)`
  - include the current observed spend and any effective lower/upper bound
    endpoints exactly
  - produce one deterministic strictly increasing grid per optimized channel
- when `grid` is supplied, Phase 8 must use that channel-level spend grid
  exactly and reject grids that do not cover the full feasible domain
- the supported continuous objective representation is one-dimensional monotone
  cubic interpolation of posterior-mean response against total spend for each
  optimized channel
- total modeled response for optimization is:
  - fixed non-media baseline from the frozen fitted artifact
  - plus the sum of optimized-channel interpolated responses
  - plus fixed observed contributions from any unoptimized channels
- the supported Phase 8 objective must be continuously evaluable across the
  feasible interior; discrete lookup tables or stepwise objective semantics are
  not part of the supported `JuMP.jl + Ipopt.jl` contract
- Phase 8 parity compares the final optimization outputs produced from this
  canonical interpolated objective contract; it does not compare ad hoc
  alternative surrogates built from the same raw curve knots

### Constraints

Supported Phase 8 constraints are:

- required total-budget equality across optimized channels
- optional per-channel absolute lower and upper spend bounds in original units
- optional reference-relative lower and upper spend guardrails against the
  observed baseline channel totals over the frozen Phase 7 horizon
- optional channel subset selection, with unselected channels held fixed at
  their observed spend

Unsupported in Phase 8 are:

- pairwise channel-ratio constraints
- date-level pacing constraints
- panel / geo budget-cell constraints
- scenario-planner style draft overrides
- optimization over controls, events, seasonality, or trend terms directly

### Constraint Normalization Contract

Phase 8 combines bound families in one deterministic way before solver
orchestration:

- absolute bounds are interpreted directly in original total-horizon spend
  units
- relative bounds are converted to absolute spend units by multiplying the
  observed channel total over the frozen Phase 7 horizon
- for each optimized channel:
  - effective lower bound = `max(all provided lower bounds, 0)`
  - effective upper bound = `min(all provided upper bounds)`
- if both bound families are absent for a channel, that channel remains
  unbounded within the supported Phase 8 contract except for non-negativity and
  the total-budget equality
- if an effective lower bound exceeds an effective upper bound, Phase 8 must
  fail before solver construction
- if the requested `total_budget` is less than the sum of effective lower
  bounds, Phase 8 must fail as infeasible before solver construction
- if every optimized channel has a finite effective upper bound and the
  requested `total_budget` exceeds the sum of those upper bounds, Phase 8 must
  fail as infeasible before solver construction
- when `channels=nothing`, `total_budget` applies to all modeled media
  channels
- when `channels` is a strict subset, `total_budget` applies only to that
  optimized subset and all unselected channels remain fixed at observed spend
- omitted channels in `budget_bounds` or `relative_bounds` are treated as
  having no bounds from that bound family
- bound normalization must be independent of caller ordering; canonical
  channel/result ordering follows model-spec channel order rather than input
  vector order

## Solver Contract

Phase 8 resolves the solver question explicitly:

- `JuMP.jl + Ipopt.jl` is the canonical constrained solver path.
- `Optim.jl` is not part of the bounded Phase 8 public contract.
- Internal experimentation may use `Optim.jl`, but successful Phase 8 delivery
  must not depend on supporting two solver stacks.

This keeps Phase 8 honest about constrained optimization ownership and matches
the current constraint-heavy bounded scope.

## Starting Support Matrix

Phase 8 starts from the following explicit baseline:

| Surface | `TimeSeriesMMM` + MCMC | `TimeSeriesMMM` + VI | `PanelMMM` + MCMC | Notes |
|---|---|---|---|---|
| `InferenceResults` | Supported | Supported | Supported | Phase 6 baseline |
| Phase 7 response / metric surfaces | Supported | Supported | Unsupported | Phase 7 baseline |
| optimization outputs | Not Yet Supported | Not Yet Supported | Not Yet Supported | Phase 8 scope |

Phase 8 closes with the following intended support matrix:

| Surface | `TimeSeriesMMM` + MCMC | `TimeSeriesMMM` + VI | `PanelMMM` + MCMC | Notes |
|---|---|---|---|---|
| fixed-budget optimization | Supported | Supported | Unsupported | Consumes the frozen Phase 7 response / metric surface |
| optimization comparison outputs | Supported | Supported | Unsupported | Typed result plus bounded projections |
| optimization constraint audit | Supported | Supported | Unsupported | Same bounded contract |

Panel optimization stays explicitly unsupported unless a later phase reopens it
truthfully.

## In Scope

- `src/optimization/` and `test/optimization/` as the canonical ownership
  layer for optimizer work
- one fixed-budget optimization path on supported time-series grouped artifacts
- one canonical solver stack through `JuMP.jl + Ipopt.jl`
- typed optimization result surfaces and bounded comparison outputs
- objective evaluation on top of the frozen Phase 7 response surface
- total-budget equality, absolute bounds, and reference-relative guardrails
- parity coverage for the supported optimization surface

## Not In Scope

The following remain outside Phase 8:

- panel optimization
- pipeline YAML optimization config
- date-level pacing or time-distribution factors
- pairwise ratio constraints between channels
- multi-objective or direct efficiency objective families
- scenario-planner UI semantics
- report/plot presentation layers

Those belong to Phases 9-10 or later bounded follow-up work.

## Execution Order

### 08-01: Objective Surface And Constraint Primitives ✅

**Goal:** freeze the bounded optimization problem definition before solver
orchestration begins.

**Scope:**

- create the `src/optimization/` ownership layer
- add typed optimization result and constraint/config surfaces
- define the fixed-budget objective on top of frozen Phase 7 response curves
- implement constraint normalization for:
  - total-budget equality
  - absolute bounds
  - reference-relative lower and upper guardrails
- lock the solver contract to `JuMP.jl + Ipopt.jl`
- freeze the deterministic grid builder and interpolation rule used by the
  bounded objective surface

**Acceptance:**

- the public optimizer entry point and typed result surface are explicit
- the public keyword shapes for `channels`, `budget_bounds`,
  `relative_bounds`, and `grid` are fixed and documented honestly
- the supported objective, interpolation rule, and supported constraint
  primitives are documented honestly
- the bounded time-series-only support matrix is explicit before orchestration
  work starts
- unsupported optimization semantics fail cleanly at the contract layer
- negative contract coverage exists for:
  - unknown channels
  - duplicate channels
  - conflicting absolute and relative bounds
  - infeasible total-budget requests
  - unsupported objective or constraint families
  - subset-budget ambiguity
  - malformed or domain-incomplete spend grids

### 08-02: Optimizer Orchestration And Result Surface ✅

**Goal:** execute the bounded optimization problem reproducibly on supported
time-series grouped artifacts.

**Scope:**

- implement solver orchestration in `src/optimization/optimizer.jl`
- translate supported constraint primitives into one canonical JuMP model
- evaluate the optimization objective from the frozen Phase 7 response surface
- add typed `BudgetOptimizationResult`
- add current-versus-optimized response and default-efficiency summaries
- add constraint-audit output on top of the same result surface

**Acceptance:**

- supported time-series grouped artifacts from both MCMC and bounded VI rows
  can produce fixed-budget optimized allocations
- unselected channels remain fixed at observed spend when a subset is
  optimized
- optimized results carry solver status and constraint-audit information
- panel artifacts and unsupported constraint families fail explicitly

### 08-03: Parity, Reporting Outputs, And Closeout

**Goal:** make the bounded optimization surface testable, documented, and ready
for pipeline/report consumers.

**Scope:**

- add Abacus parity coverage for agreed optimization fixtures
- add bounded comparison outputs over `BudgetOptimizationResult`
- freeze the truthful Phase 8 support matrix
- document the Phase 8 to Phase 9 handoff explicitly:
  - Phase 9 must consume the frozen optimization result surface rather than
    re-derive optimizer semantics from raw response curves

**Parity Matrix:**

| Fixture family | `TimeSeriesMMM` + MCMC | `TimeSeriesMMM` + VI | `PanelMMM` + MCMC | Outputs under comparison |
|---|---|---|---|---|
| all-channel fixed-budget allocation | Required | Required | Unsupported | optimized spend vector, optimized total response, current-versus-optimized efficiency summaries |
| absolute-bound constrained allocation | Required | Required | Unsupported | optimized spend vector, objective value, constraint audit |
| reference-relative guardrail allocation | Required | Required | Unsupported | optimized spend vector, objective value, constraint audit |
| mixed bound families with subset optimization | Required | Required | Unsupported | optimized spend vector for optimized subset, fixed spend for held channels, objective value |

Negative fixture coverage is also required for:

- unsupported `PanelMMM` artifacts
- unsupported objective or constraint families
- infeasible bound or budget combinations
- malformed channel selections or spend grids

Optimization fixture ownership is frozen as:

- fixture source:
  - local Abacus checkout under `/home/user/Documents/GITHUB/tandpds/abacus`
- export path:
  - `scripts/export_abacus_optimization_fixtures.py`
- stored fixtures:
  - `test/fixtures/abacus/optimization/`
- update documentation:
  - `test/fixtures/abacus/README.md`

**Acceptance:**

- supported Phase 8 optimization outputs match Abacus on agreed fixtures
  within the following tolerances:
  - optimized/current spend allocations: `atol=1e-5`, `rtol=1e-5`
  - optimized/current objective summaries: `atol=1e-5`, `rtol=1e-5`
  - derived default efficiency summaries: `atol=1e-5`, `rtol=1e-5`
- closeout coverage spans the supported time-series MCMC and VI rows
- docs state clearly that optimization remains time-series first and that panel
  optimization is not part of the closed Phase 8 surface
- the optimization support matrix is explicit before Phase 9 begins

## Dependencies And Handoff

Phase 8 depends on the frozen Phase 7 contracts:

- `ResponseCurveResults`
- `MetricResults`
- `response_curve_results`
- `metric_results`
- fixed total-spend / observed-shape semantics

Phase 9 must depend on Phase 8 rather than bypass it:

- pipeline optimization must consume the frozen `BudgetOptimizationResult`
  surface
- pipeline configuration must not reopen objective, solver, or constraint
  semantics already settled in Phase 8

## Deliverables

At minimum, Phase 8 should leave the repo with:

- `src/optimization/types.jl`
- `src/optimization/objective.jl`
- `src/optimization/constraints.jl`
- `src/optimization/optimizer.jl`
- `test/optimization/`
- docs for the supported optimization surface
- parity and negative coverage for the truthful Phase 8 surface

## Exit Criteria

Phase 8 is complete only when all of the following are true:

- analysts can optimize supported time-series grouped artifacts under one
  bounded fixed-budget contract
- optimization consumes the frozen Phase 7 response and metric surfaces rather
  than re-deriving business outputs from raw posterior artifacts
- the supported objective and supported constraint primitives are documented
  honestly
- the canonical solver path is fixed to `JuMP.jl + Ipopt.jl`
- optimization parity coverage exists for the supported surface
- the frozen support matrix is explicit across `TimeSeriesMMM` MCMC,
  `TimeSeriesMMM` VI, and unsupported `PanelMMM` rows
- panel optimization remains explicitly unsupported unless separately planned
  and delivered
