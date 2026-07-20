# Model Form

This page describes the statistical model estimated by Epsilon's maintained
MCMC path. The equations are written on the model scale: media channels and the
target are scaled before the Turing model is built, and post-model summaries
map fitted quantities back to original business units where appropriate.

## Time-Series Mean Function

For observations indexed by time `t = 1, ..., T`, the maintained time-series
path uses a Gaussian observation model:

```math
y_t^{*} \sim \operatorname{Normal}(\mu_t, \sigma),
```

where `y_t^{*}` is the scaled target. The linear predictor is additive:

```math
\mu_t =
  \alpha
  + m_t
  + c_t
  + e_t
  + h_t
  + s_t
  + r_t.
```

The terms are:

- Intercept ($\alpha$).
- `m_t`: total media contribution after adstock, saturation, optional media
  multiplier, and media coefficients.
- `c_t`: optional control contribution.
- `e_t`: optional event-window contribution.
- `h_t`: optional holiday contribution.
- `s_t`: optional Fourier seasonality contribution.
- `r_t`: optional trend contribution.

The media term is a sum over configured channels:

```math
m_t = \sum_{j=1}^{J} \beta_j f_j(x_{1:T,j})_t,
```

where `x_{1:T,j}` is the scaled spend or exposure series for channel `j`,
`f_j` is the configured adstock-and-saturation transform, and $\beta_j$ is the
media coefficient. In the default nonnegative media-coefficient path,
$\beta_j$ has a positive prior.

Optional controls enter linearly:

```math
c_t = \sum_{k=1}^{K} z_{t,k}\gamma_k.
```

Holiday, event, seasonality, and trend effects use the same additive structure:
a design matrix multiplied by coefficient draws. If a component is absent from
the config, its contribution is zero.

## Panel Mean Function

For panel models, Epsilon uses a shared time axis and a deterministic flattened
panel-cell axis. Let `p = 1, ..., P` index the flattened panel cells. The
maintained panel path estimates:

```math
y_{t,p}^{*} \sim \operatorname{Normal}(\mu_{t,p}, \sigma_p),
```

with

```math
\mu_{t,p} =
  \alpha_p
  + m_{t,p}
  + h_{t,p}
  + s_{t,p}.
```

The panel media term is:

```math
m_{t,p} = \sum_{j=1}^{J} \beta_{j,p} f_{j,p}(x_{1:T,j,p})_t.
```

Depending on the prior dimensions, panel parameters may be shared across panel
cells, vary by channel, vary by panel cell, or vary by channel and panel cell.
For multi-dimensional panels such as geo-by-brand, Epsilon stores the fitted
model on one flattened panel-cell axis and keeps named coordinate metadata for
interpretation and replay.

The current panel path is intentionally narrower than the time-series path:
panel controls, panel trend, panel events, panel calibration, and panel holdout
validation are not part of the maintained support surface.

## Scaling

Epsilon scales media and target values before fitting:

```math
x_{t,j}^{*} = x_{t,j} / a_j,
\qquad
y_t^{*} = y_t / b.
```

For time-series models, `a_j` is the channel scale for channel `j` and `b` is
the target scale. For panel models, channel scales are channel-by-panel-cell
and target scales are panel-cell specific.

This means priors are interpreted on the model scale, not directly in pounds,
dollars, impressions, or conversions. Response curves and decomposition
artifacts are reported through Epsilon's post-model layer so analysts can
inspect business-scale quantities without changing the fitted model.

## Calibration Terms

Calibration does not replace the observation model. On the supported
time-series path, Epsilon adds calibration information to the posterior as
additional log-density terms:

```math
\log p(\theta \mid y, q)
\propto
\log p(y \mid \theta)
+ \log p(\theta)
+ \log p(q_{\mathrm{lift}} \mid \theta)
+ \ell_{\mathrm{cost}}(\theta).
```

The lift-test term is available for the centered-logistic time-series MCMC
path. The cost-per-target term is a soft penalty. Both are additive and
independent of the Gaussian observation likelihood.

## What The Fitted Mean Is Not

The fitted mean is not a causal identification guarantee. It is the posterior
mean function implied by the supplied data, transform choices, priors, and
calibration terms. Causal interpretation still depends on the data-generating
setting, omitted-variable risk, media planning process, and whether calibration
measurements are credible for the estimand being reported.

