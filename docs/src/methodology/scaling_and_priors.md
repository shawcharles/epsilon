# Scaling And Priors

Epsilon fits the maintained MCMC models on a transformed numerical scale. This
keeps the sampler away from raw business-unit magnitudes and makes default
priors more reusable across small demo datasets and larger user datasets.

The important practical rule is simple: priors live on the model scale unless a
page or artifact explicitly says otherwise.

## Target Scaling

For a time-series target, Epsilon uses max-absolute scaling:

```math
b = \max_t |y_t|,
\qquad
y_t^{*} =
\begin{cases}
y_t / b, & b > 0, \\
y_t, & b = 0.
\end{cases}
```

The fitted likelihood is attached to `y_t^{*}`. Post-model quantities such as
contributions and decomposition totals are mapped back by multiplying scaled
contributions by `b`.

For panel models, the target scale is panel-cell specific:

```math
b_p = \max_t |y_{t,p}|,
\qquad
y_{t,p}^{*} = y_{t,p} / b_p.
```

If a target scale would be zero, Epsilon stores scale `1.0` so replay remains
well defined.

## Media Scaling

For a time-series media channel `j`, Epsilon stores:

```math
a_j = \max_t |x_{t,j}|,
\qquad
x_{t,j}^{*} = x_{t,j} / a_j.
```

For panel models, channel scales are channel-by-panel-cell:

```math
a_{j,p} = \max_t |x_{t,j,p}|,
\qquad
x_{t,j,p}^{*} = x_{t,j,p} / a_{j,p}.
```

The model applies adstock and saturation to the scaled media series. Response
and contribution artifacts then replay the fitted transform path and report
quantities in original target units where appropriate.

## Controls

Controls can be standardised in the time-series path:

```math
z_{t,k}^{*} = \frac{z_{t,k} - \bar{z}_k}{s_k}.
```

The scale uses the population standard deviation over the fitted data. A
constant control column receives scale `1.0`, which avoids division by zero and
leaves the centred column at zero.

Panel controls are not part of the current maintained panel surface.

## Default Prior Locations

The default priors are deliberately weak and model-scale oriented. The exact
config surface can override them, but the defaults in the maintained path are:

| Parameter | Meaning | Default prior |
|---|---|---|
| `intercept` | baseline mean level on scaled target scale | `Normal(0, 2)` |
| `sigma` | residual scale on scaled target scale | `HalfNormal(1)` |
| `beta_media` | media coefficient | `HalfNormal(1)` |
| `beta_controls` | control coefficient | `Normal(0, 1)` |
| `beta_events` | event-window coefficient | `Normal(0, 1)` |
| `beta_holidays` | holiday coefficient | `Normal(0, 1)` |
| `beta_seasonality` | Fourier-seasonality coefficient | `Laplace(0, 1)` |
| `beta_trend` | linear-trend coefficient | `Normal(0, 1)` |
| `delta_trend` | changepoint-trend increment | `Laplace(0, 0.25)` |

Adstock and saturation parameters have family-specific priors. For example,
geometric and binomial adstock use an `alpha` prior on `[0, 1]`, while the
centered-logistic saturation path uses a positive `lam` prior.

## Prior Dimensions

Priors can be scalar, channel-specific, panel-specific, or channel-by-panel
depending on their configured dimensions and the model type.

For time-series models, channel-level media parameters have one value per
configured media channel:

```math
\beta = (\beta_1, \ldots, \beta_J).
```

For panel models, the flattened panel-cell axis allows:

```math
\beta_j,
\qquad
\beta_p,
\qquad
\beta_{j,p}.
```

Epsilon rejects partial panel-dimensional priors in the maintained panel path:
a prior must either include all declared panel dimensions or none. This avoids
ambiguous indexing when a model has more than one panel dimension, such as
geo-by-brand.

## Reading Priors In Business Terms

Because priors are applied on scaled variables, a coefficient prior is not a
direct prior over pounds, dollars, impressions, sales, or conversions. A rough
business-scale interpretation requires the fitted scales:

```math
\Delta y
\approx
b \, \beta_j \, \Delta f_j(x^{*}).
```

For panel cells:

```math
\Delta y_{p}
\approx
b_p \, \beta_{j,p} \, \Delta f_{j,p}(x^{*}_{j,p}).
```

This is why the stored model spec includes channel and target scales. Prediction
and post-model replay use those scales to keep fitted artifacts consistent with
the original data.

## What To Check When Priors Dominate

Signs that priors are doing too much work include:

- posterior response curves that stay close to the prior shape despite clear
  media variation,
- very wide posterior predictive intervals,
- weak movement in media coefficients from prior to posterior,
- implausible response curves outside the observed spend range,
- sensitivity of conclusions to small prior changes.

Those are modelling diagnostics, not package failures. The remedy is usually a
clearer design, better calibration evidence, narrower prior assumptions, or a
more honest support boundary for the decision being made.

