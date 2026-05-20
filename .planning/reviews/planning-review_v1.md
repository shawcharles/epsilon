# External Planning Review

This review covers the Phase 8 planning set for `Epsilon.jl`, centered on
`.planning/phases/08-budget-optimization/PLAN.md` and checked against the
adjacent planning documents plus the current codebase shape where relevant.
The overall direction is strong: the planning set is now mostly honest about
current implementation status, the Phase 8 scope is bounded appropriately, and
the execution order (`08-01` contract -> `08-02` orchestration -> `08-03`
parity/closeout) is technically sensible. The remaining issues are mostly about
implementation precision and cross-document consistency rather than the chosen
scope.

## Findings

### 1. High — The objective-evaluation contract is not specified tightly enough for the locked `JuMP.jl + Ipopt.jl` path

The Phase 8 plan correctly insists that optimization must consume the frozen
Phase 7 response surface instead of reopening posterior semantics, and it also
locks the solver path to `JuMP.jl + Ipopt.jl`. However, the plan never defines
how a continuous optimizer is supposed to evaluate that objective from the
Phase 7 surface.

Evidence:

- `.planning/phases/08-budget-optimization/PLAN.md` says the optimizer must
  consume the frozen Phase 7 response surface, exposes
  `optimize_budget(...; ... , grid=nothing)`, and says `08-01` / `08-02` must
  define and evaluate the objective on top of response curves.
- `.planning/phases/07-post-modeling/PLAN.md` defines the canonical response
  API as `response_curve_results(results::InferenceResults; channel, grid)`,
  i.e. a grid-based surface projection.

What is missing:

- the default grid-generation contract when `grid=nothing`
- whether optimization uses discrete lookup, interpolation, spline fitting, or
  another surrogate over the Phase 7 curve points
- whether the chosen objective representation is smooth/differentiable enough
  for `Ipopt`
- how parity should compare the optimizer objective when the underlying Phase 7
  surface is grid-based

Why this matters:

- Two implementers could build materially different optimizers and both claim
  compliance with the plan.
- If the objective is still effectively discrete, `Ipopt` is the wrong solver
  contract.
- If a surrogate is introduced, that surrogate becomes part of the public Phase
  8 semantics and should be frozen in planning before implementation.

Recommended fix:

- Add a short “Objective Evaluation Contract” subsection to the Phase 8 plan
  before `08-01` starts. It should define the canonical spend-grid builder,
  the continuous approximation/interpolation rule (or explicitly choose a
  discrete optimization contract instead), any differentiability assumptions,
  and the exact object that parity tests compare.

### 2. High — The public input and constraint contract is still too ambiguous to make `08-01` reviewable

The plan names the right constraint families, but the public API is still only
partially specified. The current prose is not precise enough to guarantee one
reviewable implementation.

Evidence:

- `.planning/phases/08-budget-optimization/PLAN.md` fixes the public entry
  point as
  `optimize_budget(results::InferenceResults; total_budget, channels=nothing, budget_bounds=nothing, relative_bounds=nothing, objective=:total_response, grid=nothing)`.
- The same document says Phase 8 supports absolute bounds,
  reference-relative guardrails, and optional channel subset selection with
  unselected channels held fixed.

What is missing:

- the exact Julia shapes/types for `channels`, `budget_bounds`,
  `relative_bounds`, and `grid`
- whether `total_budget` applies to all channels or only the optimized subset
  when some channels are held fixed
- how absolute bounds and reference-relative bounds combine when both are
  provided
- the validation and precedence rules for conflicting or infeasible bounds
- the keyed-channel contract (for example, duplicate names, unknown names,
  ordering guarantees, omitted channels)
- whether bound values are total-horizon spend units only, and whether any
  rescaling or normalization is allowed

Why this matters:

- `08-01` claims it will freeze the typed optimization contract, but the plan
  still allows multiple incompatible APIs.
- Reviewers cannot tell whether later tests are validating the intended public
  contract or just one arbitrary implementation choice.
- Subset optimization is especially ambiguous: without an explicit budget
  accounting rule, different implementations can produce different totals while
  all appearing plausible.

Recommended fix:

- Specify one typed contract now, either directly in the plan or by naming a
  dedicated Phase 8 constraint/config type. Also add explicit negative
  acceptance cases for unknown channels, conflicting bounds, infeasible budgets,
  and subset-budget ambiguity.

### 3. Medium — Phase 8 parity closeout is not yet falsifiable

The plan repeatedly says Phase 8 will match Abacus on “agreed optimization
fixtures” within “defined tolerances,” but neither the fixture matrix nor the
tolerances are actually defined in the planning set.

Evidence:

- `.planning/phases/08-budget-optimization/PLAN.md` `08-03` requires parity on
  agreed optimization fixtures within defined tolerances.
- `.planning/phases/07-post-modeling/PLAN.md` is materially tighter: it names
  the supported rows explicitly and sets a concrete `1e-6` tolerance for the
  frozen Phase 7 parity surface.

What is missing:

- the required optimization fixture families
- the minimum support matrix that parity must cover across MCMC and bounded VI
- the expected negative fixtures (for example infeasible constraints,
  unsupported panel artifacts, unsupported constraint families)
- the numeric tolerances for allocations, objective values, and comparison
  outputs
- the export/update ownership for optimization fixtures if Abacus parity data
  changes

Why this matters:

- `08-03` can be declared complete without a stable review target.
- Optimization parity is more sensitive than Phase 7 summary projections, so a
  looser and undefined acceptance contract is especially risky here.

Recommended fix:

- Add a small parity matrix to the Phase 8 plan now: fixture families, covered
  rows, expected outputs, tolerances, and the fixture source/update path.

## Cross-Document Gaps

### 1. `.planning/COMPONENT-MAPPING.md` still leaves unsupported solver and constraint semantics alive

The dedicated Phase 8 plan closes the solver question to `JuMP.jl + Ipopt.jl`
and explicitly excludes pairwise ratio constraints. But
`.planning/COMPONENT-MAPPING.md` still says budget optimization maps to
`Optim.optimize(... )` or `JuMP`, and it still lists ratio constraints as part
of the mapping surface.

Why this matters:

- It reopens decisions that the Phase 8 plan says are already frozen.
- It creates an avoidable implementation and review fork right before `08-01`.

Recommended change:

- Update the budget-optimization mapping section so it reflects the closed Phase
  8 contract: `JuMP.jl + Ipopt.jl` only for the supported path, with ratio
  constraints marked explicitly out of scope.

### 2. `.planning/ARCHITECTURE.md` contains a stale concrete `PanelMMM` example that no longer matches code

The architecture document still shows a `PanelMMM` example with fields
`data::MMMData` and `chain::Union{Nothing, Chains}`. The current code in
`src/model/builder.jl` defines `mutable struct PanelMMM <: AbstractMMMModel`
with `data::PanelMMMData`, `built_model::Union{Nothing, MMMModelSpec}`, and
`fit_state::Union{Nothing, ModelFitState}`.

Why this matters:

- This is no longer just a conceptual simplification; it is a contradictory
  concrete example in an architecture document that implementers may copy from.
- It weakens the “aligned with the current codebase” requirement for the
  planning set.

Recommended change:

- Update the architecture example so it matches the current code shape, or mark
  it explicitly as historical pseudocode if it is meant to be illustrative only.

### 3. Plotting dependency sequencing is out of sync between `.planning/DEPENDENCIES.md` and `.planning/ROADMAP.md`

`.planning/ROADMAP.md` still places plotting in Phase 10, but
`.planning/DEPENDENCIES.md` says `CairoMakie.jl` and `AlgebraOfGraphics.jl` are
required from Phase 9.

Why this matters:

- It introduces a stale dependency assumption for downstream planning.
- It makes Phase 9 look heavier than the roadmap currently defines.

Recommended change:

- Reconcile the dependency table with the roadmap. If plotting remains a Phase
  10 deliverable, the plotting dependencies should move to Phase 10 as well.

## Recommended Planning Changes

1. Add an explicit Phase 8 objective-evaluation contract covering default grid
   construction, interpolation/surrogate behavior, solver compatibility, and
   parity comparison semantics.
2. Freeze one typed public input contract for `channels`, `budget_bounds`,
   `relative_bounds`, and `grid`, including subset-budget semantics and
   validation/failure rules.
3. Expand `08-01` acceptance criteria to include negative contract tests for
   unknown channels, infeasible bounds, conflicting bound families, unsupported
   constraint types, and subset-budget ambiguity.
4. Expand `08-03` with a concrete optimization parity matrix: fixture families,
   supported rows, exact outputs under comparison, and numeric tolerances.
5. Reconcile the stale optimization guidance in
   `.planning/COMPONENT-MAPPING.md` before implementation work starts.
6. Reconcile `.planning/ARCHITECTURE.md` and `.planning/DEPENDENCIES.md` with
   the current codebase and roadmap so adjacent documents stop reintroducing
   stale assumptions during Phase 8 work.

## Conclusion

The Phase 8 planning set is substantially better than an aspirational roadmap:
it is bounded, mostly honest about current implementation status, and sequenced
in a sensible order. In particular, the repository still has no `src/optimization/`
layer, which matches the planning claim that Phase 8 is planned rather than
partially landed.

That said, I would not yet call the Phase 8 plan fully implementation-ready.
The core blocker is not missing ambition; it is missing precision. The
objective-evaluation contract, public input schema, and parity closeout rules
still need to be frozen more explicitly, and a few adjacent planning documents
still advertise stale or conflicting assumptions. Once those items are cleaned
up, the Phase 8 plan should be in a strong state for `08-01` execution.