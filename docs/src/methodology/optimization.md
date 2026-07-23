# Budget Optimisation

Budget optimisation is a post-model decision aid. It takes one fitted
`InferenceResults` artifact, replays its response curves, and searches for a
channel allocation that maximises total model-implied response under a fixed
budget and user-supplied constraints. It never refits the model, and it never
introduces information that was not already in the fitted posterior.

This page describes exactly what is solved, what the constraints mean, how the
solver works, and, just as importantly, what an allocation result does not tell
you.

## What `optimize_budget` Solves

For time-series results, the maintained objective is total response. Let $a_j$
denote the total spend assigned to channel $j$ over the same aggregation
window as the historical data, and let $R_j(a_j)$ be the channel response
surface described below. The problem is:

```math
\max_{a_1, \ldots, a_J}
\;\;
R_0 + \sum_{j \in \mathcal{O}} R_j(a_j)
\quad
\text{subject to}
\quad
\sum_{j \in \mathcal{O}} a_j + \sum_{j \in \mathcal{F}} \bar{x}_j = B,
\qquad
\ell_j \le a_j \le u_j .
```

Here $\mathcal{O}$ is the optimised channel set, $\mathcal{F}$ is the set of
channels held fixed at their observed spend $\bar{x}_j$, $B$ is the supplied
`total_budget`, $R_0$ collects the baseline and fixed-channel response, and
$\ell_j, u_j$ are the effective per-channel bounds. The budget constraint is
an *equality*: the optimiser reallocates the budget, it does not decide
whether the budget should be spent at all.

Only `objective = :total_response` is currently supported. The utility
functions described in
[Post-Model Quantities](post_model_quantities.md) score evaluated allocations;
they do not change the solved objective.

## How Response Surfaces Feed The Solve

Each optimised channel contributes a one-dimensional response surface built
from the fitted model's response curve machinery:

1. A spend grid is constructed for the channel, covering zero, the observed
   spend, the effective bounds, and enough intermediate points (64 by default)
   to make interpolation stable. Grid points are in original spend units.
2. `response_curve_results` is evaluated on that grid, giving a matrix of
   responses indexed by posterior draw and grid point.
3. The **posterior mean** across draws is taken, yielding a single
   deterministic response value per grid point.
4. A smooth interpolant through those points, together with its first and
   second derivatives, is registered with the solver as a nonlinear operator.

Two consequences follow. First, the surfaces inherit the response-curve
semantics exactly: a grid point asks "what total contribution would the fitted
model assign to this channel if its historical spend path were rescaled to
this total?", with the historical spend *shape* preserved. Second, because the
objective uses posterior-mean curves, the solve itself does not propagate
posterior uncertainty into the allocation. Uncertainty enters afterwards,
through evaluation and decision summaries, not through the optimiser.

## Constraints And Bounds

The supported constraint surface is deliberately small:

- **Total-budget equality.** The sum of optimised and fixed-channel spend must
  equal `total_budget`. All quantities, including the budget, observed spend,
  explicit bounds, and response grids, must be in the same original input units
  as the channel columns supplied to the model. Epsilon does not convert
  currencies or rescale thousands/millions at the optimiser boundary.
- **Channel subset.** Passing `channels` restricts optimisation to those
  channels; every other fitted channel is held at its observed spend. This is
  how you answer "reallocate within TV and search, hold everything else".
- **Absolute bounds (`budget_bounds`).** A channel-keyed mapping with optional
  `lower` and `upper` spend limits in original units.
- **Relative bounds (`relative_bounds`).** Guardrails expressed relative to
  each channel's observed spend; for example, "no more than 50 per cent above
  or below what was historically spent". Relative bounds exist because response
  curves are only credible near the observed spend range; they stop the solver
  from extrapolating deep into untested regions of the curve.
- **Effective bounds.** Where absolute and relative bounds are both present,
  the effective bound is the intersection. Infeasible combinations (for
  example, a budget that cannot be reached within the bounds) fail with an
  explicit error rather than a silently relaxed constraint.

After the nonlinear solve, Epsilon performs a small bound-projection pass to
snap near-bound solver drift back onto the exact bounds and to restore the
budget equality. This is post-solve hygiene, not a second optimisation; if the
residual cannot be absorbed within valid bound slack, the call fails closed.

## The Solver

The problem is solved with Ipopt through JuMP. The channel response surfaces
are registered as nonlinear operators with analytic first and second
derivatives taken from the interpolants, and the solve starts from a feasible
allocation constructed from the effective bounds and observed spend.

Ipopt is a local nonlinear solver. Epsilon accepts locally feasible optima;
the response surfaces are smooth interpolations of posterior-mean grids, not
proven globally concave functions. For well-behaved saturation families the
surfaces are typically concave over the credible spend range, but analysts
should treat the returned allocation as a strong local candidate, not a
certified global optimum. Solver metadata, including termination status,
primal and dual status, and solve time, is retained in the result's convergence
metadata. A solve that does not reach a feasible solution raises an error
rather than returning a dubious allocation.

## What Panel Optimisation Does And Does Not Do

For panel results, `optimize_budget` allocates **channel totals** and then
distributes each channel's total across panel cells in proportion to the
historical within-channel spend shares:

```math
a_{j,p} = a_j \cdot \frac{\bar{x}_{j,p}}{\sum_{p'} \bar{x}_{j,p'}} .
```

This is a bounded allocation rule, chosen because panel response curves are
defined by a shared historical spend delta within each channel. They do not
identify the effect of moving spend between panel cells independently. Free
channel-by-panel allocation, panel-total bounds, and channel-panel bounds are
intentionally unsupported and are rejected rather than approximated.

In practical terms: panel optimisation answers "how should the channel split
of the budget change, holding each channel's geographic or brand mix at its
historical shape?" It cannot answer "which geo should get more TV spend?"

## Marginal Response Diagnostics

The result reports marginal response, the derivative of the channel response
surface, at the observed spend and at the solved spend for each optimised
channel. At an unconstrained interior solution, marginal responses should be
approximately equal across channels: that is the economic content of the
optimality condition, since a budget unit should flow to wherever it buys the
most response.

Where a channel sits at an active bound, its marginal response is a
diagnostic, not a first-order condition. A channel pinned at its upper bound
with a high marginal response is telling you the constraint, not the model, is
doing the deciding; treat that as a prompt to question the bound, not as a
finding about the channel.

## Uncertainty Summaries And Utility Scoring

Because the solve uses posterior-mean surfaces, Epsilon provides a separate
evaluation layer for uncertainty-aware comparison:

- `evaluate_budget_allocation` replays full posterior response draws at a
  supplied allocation (current, solved, or manual), giving a posterior
  distribution of total response for each candidate.
- `budget_allocation_decision_summary` compares a candidate against a
  reference allocation with paired draws, reporting the uplift distribution
  $\Delta^{(s)} = y^{(s)}_a - y^{(s)}_0$, the draw-wise percentage uplift, and
  the posterior probability of improvement
  $\Pr(y_a > y_0)$.
- `budget_utility_value` scores allocations under documented utilities: mean
  response, a lower-interval quantile for downside-averse decisions, the
  probability of improvement, and a risk-adjusted mean-minus-penalty form
  $\bar{y}_a - \lambda\,\mathrm{sd}(y_a)$.

These summaries are the honest way to compare allocations. Two allocations can
have nearly identical posterior-mean response but very different downside
risk; the mean-surface solve cannot see that distinction, the evaluation layer
can.

## What Not To Infer From An Allocation Result

An allocation produced by `optimize_budget` is **conditional on the fitted
model**. It is a rearrangement of the model's own response estimates under
your constraints. Specifically:

- It is not causal proof. If the fitted response curves are confounded, the
  optimal allocation inherits that confounding. Optimisation sharpens whatever
  the model believes; it does not test whether the model is right.
- It is not a forecast. Response surfaces replay the historical spend shape
  under rescaling; they do not simulate a future baseline, future seasonality,
  competitor reactions, or saturation drift.
- It is not robust to extrapolation. Spend points far outside the observed
  range rest on the weakest part of the response curve; relative bounds exist
  to keep the solver honest here, and loosening them should be a deliberate
  modelling decision.
- It is not uncertainty-aware at the solve step. The probability-of-improvement
  and utility summaries can be close to ambiguous even when the point
  allocation looks decisive. Report both.
- It is not a global guarantee. Local solver, interpolated surfaces, and an
  equality budget constraint mean small changes in inputs can move the
  allocation, especially where response curves are flat.

Used within these limits, budget optimisation is a disciplined way to explore
the implications of a fitted model. Used outside them, it manufactures
precision the data never supplied.
