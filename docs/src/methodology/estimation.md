# Estimation, Diagnostics, And Validation

This page explains how Epsilon turns a model specification and a dataset into
posterior draws, how to judge whether those draws are trustworthy, and how the
validation machinery should, and should not, be interpreted. It assumes the
model equations in [Model Form](model.md) and the transform definitions in
[Media Transforms](media_transforms.md).

## The Bayesian Workflow

Epsilon's maintained fitting path is fully Bayesian. The model specifies a
joint distribution over parameters $\theta$ and data $y$:

```math
p(\theta, y) = p(y \mid \theta)\, p(\theta),
```

and inference characterises the posterior:

```math
p(\theta \mid y)
=
\frac{p(y \mid \theta)\, p(\theta)}
     {\int p(y \mid \theta')\, p(\theta')\, d\theta'} .
```

Three consequences matter in practice:

- **Priors are part of the model.** A HalfNormal media coefficient prior is
  not a technicality; it encodes the belief that media effects are nonnegative
  and usually modest. Where the data are weakly informative, such as short
  series, collinear channels, or little spend variation, the prior will do real work in
  the posterior. That is honest Bayesian behaviour, but it means prior choices
  deserve the same scrutiny as data choices.
- **The posterior is a distribution, not a point.** Epsilon keeps posterior
  draws and replays them through contributions, response curves, and decision
  summaries. Point summaries such as posterior means are conveniences; the
  spread of the draws is where the honesty lives.
- **Calibration terms are extra log-density.** Where lift-test or
  cost-per-target calibration is configured, those measurements enter as
  additional terms in the log joint, sharpening the posterior towards the
  external evidence. They do not change the observation model.

## The Sampler

Fitting uses NUTS, the No-U-Turn Sampler, a self-tuning variant of Hamiltonian
Monte Carlo, through Turing.jl. The sampler configuration has four numbers
worth understanding:

| Setting | Default | Meaning |
|---|---|---|
| `draws` | 1000 | post-warmup draws retained per chain |
| `tune` | 1000 | warmup iterations used to adapt step size and mass matrix |
| `chains` | 4 | independent chains, the basis of between-chain diagnostics |
| `target_accept` | 0.8 | target acceptance rate; raise towards 0.9 to 0.99 if divergences appear |

Warmup draws are discarded; only the retained draws feed posterior summaries.
Multiple independent chains are not a luxury: they are what makes it possible
to detect that the sampler has failed to explore the same distribution from
different starting points.

## Convergence Diagnostics

MCMC output is only useful if the chains have mixed well. Epsilon computes the
standard per-parameter diagnostics and flags problems against configurable
thresholds (`\\hat{R}` above 1.05 or effective sample size below 100 trigger
convergence warnings by default):

- **`\\hat{R}` (potential scale reduction factor).** Compares within-chain and
  between-chain variance. Values near 1.0 indicate that chains agree; values
  materially above 1 indicate the chains have not converged to the same
  distribution, and every downstream quantity, including contributions,
  curves, and allocations, inherits that failure.
- **Bulk and tail effective sample size (ESS).** The number of effectively
  independent draws the chain represents, for central and tail summaries
  respectively. Posterior means need adequate bulk ESS; credible intervals
  need adequate tail ESS. Autocorrelated MMM posteriors routinely deliver far
  fewer effective draws than raw draws.
- **Monte Carlo standard error.** The sampling error on the posterior mean
  itself. If the MCSE is large relative to the differences you care about
  (for example, between two channels' contributions), more draws are needed
  before the comparison means anything.

The practical responses to poor diagnostics are, in order of preference:
run longer (more `tune` for adaptation problems, more `draws` for low ESS),
raise `target_accept` if divergences are reported, simplify or reparameterise
the model (fewer collinear channels, stronger but honest priors), or narrow
the claims you make. Publishing decisions from an unconverged fit is the one
response that is never appropriate.

## Posterior Predictive Checking

Fitted-mean plots answer "does the model track the data?" Posterior predictive
checking answers the sharper question: "could data simulated from the fitted
model plausibly be the data we observed?" Epsilon generates replicated outcomes

```math
\tilde{y}_t^{(d)} \sim \operatorname{Normal}(\mu_t^{(d)}, \sigma^{(d)})
```

per posterior draw, so the replicated data include both parameter and
observation uncertainty. Comparing the observed series against the replicated
ensemble exposes systematic misfit, such as missed peaks, wrong seasonal
amplitude, or unmodelled trend breaks, that a good $R^2$ can hide.

A posterior predictive check is a model-criticism tool, not a pass/fail gate.
Localised misfit around promotions or holidays is often acceptable if those
periods are not decision-relevant; misfit in the level or seasonal structure
usually is not, because media decomposition rides on top of the baseline the
model attributes elsewhere.

## Holdout Validation And Its Limits

For time-series models, Epsilon supports blocked holdout validation: the
series is split into contiguous blocks, the model is refit without the holdout
block, and predictive accuracy on the held-out observations is summarised.
This roughly doubles the fitting cost because a second model is estimated.

Holdout validation measures **predictive** quality. That is valuable, because
a model that cannot predict withheld outcomes should not be trusted to
decompose them, but it has hard limits that analysts must keep in view:

- A model can predict the target well while attributing it wrongly. If two
  channels move together, many decompositions fit equally well; holdout error
  cannot distinguish between them.
- The holdout block comes from the same observational process as the training
  block. Validating on it says nothing about performance under interventions,
  which is precisely the setting budget decisions care about.
- With short series, the holdout block is small and its metrics are noisy; a
  single blocked split should not be over-read in either direction.

Treat holdout results as a necessary-but-not-sufficient check on the model's
predictive machinery, and look to calibration against experiments for evidence
about the decomposition itself.

## Identifiability

Several structural features of MMM limit what any estimation procedure can
recover, and Epsilon's design surfaces rather than hides them:

- **Scaling.** Priors live on the scaled model space (see
  [Scaling And Priors](scaling_and_priors.md)). A coefficient posterior must
  be read through the stored channel and target scales before it carries
  business meaning.
- **Collinearity.** Channels whose spend series move together are only weakly
  separately identified. The posterior will be wide or prior-dominated for
  those channels, and decomposition shares between them can swing under small
  prior changes. Pooling, aggregating channels, or bringing experimental
  evidence through calibration are the honest remedies.
- **Transform parameterisation.** Adstock and saturation parameters trade off
  against each other and against the media coefficient; a long carryover with
  a weak coefficient can mimic a short carryover with a strong one. Inspect
  joint posterior behaviour, not marginal summaries alone.
- **Sign constraints.** The default nonnegative media-coefficient prior rules
  out negative media effects by construction. That is usually the right
  inductive bias for spend data, but it means a "small but positive" posterior
  for a weak channel is partly the prior talking.

## What This Adds Up To

A defensible Epsilon workflow is: specify priors you can defend in business
terms; fit with multiple chains; confirm convergence before looking at any
substantive output; check posterior predictive behaviour against the observed
series; use holdout validation as a predictive sanity check; and use
calibration where credible experimental evidence exists. Skipping any of these
steps does not make the numbers wrong, but it removes the evidence that they
are right.
