# Modelling Judgement, Runtime, And Limitations

Epsilon provides the statistical machinery for Bayesian marketing mix
modelling; it cannot provide the judgement that makes an MMM worth believing.
This page collects the practical guidance that applies across the whole
workflow: how to approach a modelling exercise, what runtime to expect, and
what the method fundamentally cannot deliver.

## Observational MMM Is Not Automatic Causal Identification

An MMM regresses the target on media spend, controls, and baseline structure.
Media spend is not randomly assigned: it is set by planners who already know
something about expected demand. Budgets rise before seasonal peaks, shift
towards channels that appear to perform, and respond to the same market
conditions that move the target. A regression fitted to such data recovers
associations, and whether those associations approximate causal effects
depends on things outside the model: the richness of the controls, the
plausibility of the seasonal and trend structure, and the absence of important
omitted drivers.

Epsilon's defaults encode sensible inductive biases, including nonnegative
media coefficients, diminishing returns, and regularising priors, but these are
biases, not identification. The strongest upgrades to causal credibility
available to an analyst are:

- credible experimental evidence (geo lift tests, conversion lift studies)
  brought in through [calibration](calibration.md);
- honest sensitivity analysis over priors and transform choices;
- triangulation against other measurement approaches rather than reliance on
  any single model.

A well-converged, well-validated Epsilon fit is a disciplined summary of what
the data and priors imply. It is not proof that the implied media effects
caused the outcomes.

## Data And Specification Judgement

The single largest determinant of MMM quality is the data, not the sampler.

- **Variation is information.** A channel whose spend barely moves cannot be
  identified from the data and will be prior-dominated. Prefer fewer channels
  with real variation over an exhaustive channel list.
- **Aggregate aggressively rather than hopefully.** If two channels are
  planned together and move together, model them together. Splitting them adds
  parameters without adding information.
- **Match granularity to the decision.** Weekly national series are the
  natural scale for most MMM questions. Daily data adds noise faster than it
  adds signal unless carryover is genuinely sub-weekly.
- **Controls must be real controls.** Include the demand drivers you believe
  move the target, such as price, distribution, promotions, seasonality, or
  trend, or the media coefficients will absorb them. But avoid conditioning on
  variables that media itself influences, which biases effects downwards.
- **Two to three years is a healthy horizon.** Long enough to estimate
  seasonality, short enough that the market structure is roughly stable.

## Runtime Expectations

Fitting cost is dominated by MCMC. A useful mental model: time scales roughly
linearly with total leapfrog steps, which grow with `draws + tune`, with the
number of observations, and with the number of parameters. In practice:

- A quick configuration check with `runme.jl ... --quick` (tens of draws, one
  chain) completes in minutes and exists only to verify that the config,
  data, and pipeline wiring are correct. Its posterior draws are meaningless.
- A serious time-series fit with the defaults (1000 tuning steps, 1000 draws,
  4 chains) on two to three years of weekly data and a handful of channels is
  typically an order-of-minutes to order-of-an-hour job on a local machine,
  depending on model complexity and hardware.
- Blocked holdout validation refits the model, so expect roughly double the
  fitting time when validation is enabled.
- Panel models scale with the number of panel cells; cost grows accordingly.
- Post-model stages, including decomposition, response curves, and diagnostics,
  are cheap relative to fitting. Budget optimisation is a small nonlinear solve
  and is effectively instant next to MCMC.

Budget sampler settings deliberately: small settings for iteration on the
specification, full settings only when the specification is frozen and the
posterior itself is the object of interest.

## Interpreting Outputs Conservatively

- Report intervals, not points. A channel contribution of "GBP 1.2m" means
  little; "GBP 1.2m, 90 per cent interval GBP 0.4m to GBP 2.1m" is the honest
  version.
- Compare channels on marginal, not just average, response when the question
  is where the next pound should go, and remember both come from the same
  fitted curves.
- Treat decomposition shares between correlated channels as jointly uncertain,
  not as independent precise numbers.
- Read any optimised allocation together with its
  [uncertainty summaries](methodology/optimization.md), and treat
  bound-pinned channels as constraint statements rather than model findings.

## Stated Limitations

The following limits are current and deliberate; they are stated here and in
[Current Scope And Limitations](scope.md) so analysts can plan around them:

- Variational inference is retired; MCMC is the only maintained fitting path.
- Panel support is narrower than the time-series path: no panel calibration,
  no panel holdout validation, and no free channel-by-panel optimisation.
- Calibration is limited to lift-test and cost-per-target terms on the
  centered-logistic time-series path; Epsilon does not generate calibration
  rows from external artifacts automatically.
- There is no future spend-path simulation: response curves and optimisation
  replay the historical spend shape under rescaling.
- Julia `.jls` artifacts are trusted-local serialisation, not a portable
  interchange format.

Where a required capability is on this list, the correct response is to treat
the question as out of scope for the current release rather than to
approximate the missing feature with post-hoc manipulation of outputs.
