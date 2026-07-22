# Post-Model Quantities

Epsilon separates fitting from post-model replay. The sampler estimates
posterior draws for model parameters; post-model functions replay those draws
through the stored model specification, scales, and coordinate metadata to
produce interpretable artifacts.

This page defines the main quantities used in result folders and plotting
outputs.

## Fitted Mean

The fitted mean is the posterior draw of the model expectation:

```math
\mu_t^{(d)}
```

for draw `d`. For panel models, the indexed form is:

```math
\mu_{t,p}^{(d)}.
```

The fitted mean is a conditional expectation under the fitted model. It is not
the same object as an observed outcome draw.

## Posterior Predictive

Posterior predictive draws include observation noise:

```math
\tilde{y}_t^{(d)} \sim
\operatorname{Normal}(\mu_t^{(d)}, \sigma^{(d)}).
```

This is why an observed-versus-fitted plot and a posterior-predictive plot can
look similar but are not conceptually identical. One summarises the fitted
mean; the other summarises replicated outcomes from the full observation model.
For low-noise fits or visually compressed y-axes, the two plots can be very
close.

## Residuals

Residual diagnostics use:

```math
e_t = y_t - \mathbb{E}[\tilde{y}_t \mid \mathrm{posterior}],
```

or the corresponding panel-cell version where supported. Residual plots are
diagnostics for fit quality and remaining structure. They are not causal
validation.

## Contributions

Contribution replay decomposes the additive mean into named components. For a
time-series model, Epsilon stores draw-level contribution arrays with axes:

```text
draw, observation, component
```

For panel models, the axes are:

```text
draw, time, panel_cell, component
```

Media contribution for channel `j` is:

```math
\mathrm{media}_{t,j}^{(d)}
= b \, \beta_j^{(d)} f_j^{(d)}(x_j^{*})_t,
```

where `b` is the target scale. Panel replay uses the panel-cell target scale
`b_p`.

Intercept, control, event, holiday, seasonality, and trend components are also
reported in original target units when they are present in the fitted model.

## Decomposition

Decomposition aggregates contribution draws over time:

```math
T_k^{(d)} = \sum_t \mathrm{component}_{t,k}^{(d)}.
```

Shares are computed from component totals:

```math
S_k^{(d)} =
\frac{T_k^{(d)}}{\sum_{r} T_r^{(d)}}.
```

Panel decomposition aggregates over both time and flattened panel cells before
component totals and shares are computed.

## Response Curves

A response curve for channel `j` asks: what total contribution would the fitted
model assign to this channel if the historical spend path were rescaled to a
given spend point?

For time-series models, the grid is in original total-spend units. Let `g` be a
grid point and $G_j = \sum_t x_{t,j}$ be observed total spend. Epsilon rescales
the historical path by:

```math
\delta(g) = g / G_j,
\qquad
x_{t,j}^{\mathrm{scenario}} = \delta(g) x_{t,j}.
```

It then scales the scenario path to model space, replays adstock and
saturation, applies the media coefficient, sums over time, and maps to original
target units.

For panel models, curves use a `delta_grid`: each delta rescales the observed
historical spend path within every panel cell. This preserves panel-cell spend
shape and avoids pretending that a single aggregate spend grid identifies a
free channel-by-panel allocation.

## Saturation Curves

Saturation curves bypass adstock and show the saturation-only contribution
surface for the selected channel. They help answer whether fitted diminishing
returns are visible over the plotted spend range.

If a saturation curve is almost linear, the fitted posterior may be placing the
observed range in the near-linear part of the saturation function. That is a
substantive diagnostic: check the saturation parameter, observed spend range,
and prior strength before assuming the plot is wrong.

## Adstock Curves

Adstock curves bypass saturation and downstream target coefficienting. Returned
values are in original channel-spend-equivalent units. They describe carryover,
not diminishing returns.

This distinction matters: adstock is a weighted-sum memory mechanism, so an
adstock-only curve can look linear. Curvature normally appears in the
saturation or full response curve.

## Efficiency Metrics

Metrics are derived from response curves, not from a separate model:

```math
\operatorname{ROAS}(g)
=
\frac{\operatorname{response}(g)}{g},
```

```math
\operatorname{CPA}(g)
=
\frac{g}{\operatorname{response}(g)}.
```

Marginal metrics use finite differences over the response grid:

```math
\operatorname{mROAS}(g_i)
\approx
\frac{\operatorname{response}(g_{i+1}) - \operatorname{response}(g_{i-1})}
     {g_{i+1} - g_{i-1}},
```

with one-sided differences at the edges. Marginal CPA is the reciprocal of the
marginal response where the denominator is numerically nonzero.

The default headline metric follows the target type: revenue targets default
to ROAS; conversion targets default to CPA.

## Optimisation Inputs

Budget optimisation uses response-curve surfaces, observed spend, and explicit
constraints. It does not refit the model. The current maintained optimisation
path optimises over supported channel-level surfaces and holds unsupported or
unselected channels fixed according to the optimisation contract.

Optimisation diagnostics report marginal response at the observed/current spend
and at the solved optimised spend for channels in the optimised set. For revenue
targets this marginal response is reported as a marginal ROAS-style quantity.
For conversion targets Epsilon also reports marginal CPA where the reciprocal is
numerically defined. Channels solved at an active lower or upper bound should be
read as constrained recommendations; their marginal values are diagnostics, not
unconstrained first-order optimality conditions.

`evaluate_budget_allocation` scores a supplied channel allocation without
solving an optimisation problem. It replays posterior response curves at the
specified channel spends and returns total-response draws, so manual, current,
and solved optimised allocations can be compared on the same posterior scale.
The allocation must use the fitted model's channel set and original input
units. Panel evaluation is limited to the same historical-share semantics used
by bounded panel optimisation.

`budget_allocation_decision_summary` and
`budget_allocation_decision_table` compare evaluated allocations against a
reference allocation, usually the current allocation. For candidate response
draws $y^{(s)}_a$ and reference response draws $y^{(s)}_0$, Epsilon reports
paired uplift draws:

```math
\Delta^{(s)}_a = y^{(s)}_a - y^{(s)}_0,
```

draw-wise percentage uplift where the reference draw is numerically nonzero:

```math
r^{(s)}_a = \frac{\Delta^{(s)}_a}{y^{(s)}_0},
```

and the posterior probability of improvement:

```math
\Pr(y_a > y_0) \approx \frac{1}{S}\sum_{s=1}^{S}
\mathbb{1}\left[y^{(s)}_a > y^{(s)}_0\right].
```

These summaries are posterior decision diagnostics for model-conditioned
allocations. They are not realised business outcomes and they do not introduce
a refit, future baseline simulation, or a new optimiser objective.

`budget_utility_value` scores posterior response draws with a small set of
documented utility functions. The default preserves the current mean-response
decision criterion:

```math
U_{\mathrm{mean}}(a) = \frac{1}{S}\sum_{s=1}^{S} y^{(s)}_a.
```

The lower-interval utility uses the lower tail of the posterior response
distribution. For interval probability $p$ and $\alpha = 1 - p$:

```math
U_{\mathrm{lower}}(a) = Q_{\alpha / 2}(y_a).
```

The probability-of-improvement utility is the paired posterior probability
shown above, so it requires reference draws from a compatible allocation. The
risk-adjusted utility subtracts a standard-deviation penalty:

```math
U_{\mathrm{risk}}(a) =
\bar{y}_a - \lambda\,\operatorname{sd}(y_a),
\qquad \lambda \ge 0.
```

These utility functions are pure scoring helpers for evaluated allocations.
They do not yet change the maintained optimiser objective.

For panel results, optimisation uses historical within-channel panel shares.
That is a bounded allocation rule, not free channel-by-panel optimisation.
