# Media Transforms

Media enters Epsilon through a two-part transformation path: carryover
followed by diminishing returns. The transformed media is then multiplied by
the media coefficient and added to the model mean.

For channel `j`, the usual time-series path is:

```math
f_j(x_{1:T,j})_t =
S_j\left(A_j(x_{1:T,j})_t\right),
```

where `A_j` is the adstock transform and `S_j` is the saturation transform.
Panel models apply the same idea for each flattened panel cell.

## Adstock

Adstock converts current and previous media into a carryover signal:

```math
A_j(x)_t = \sum_{\ell=0}^{L-1} w_{j,\ell} x_{t-\ell,j},
```

where `L` is `l_max` and the boundary behaviour is controlled by the configured
convolution mode. With the usual trailing carryover mode, past spend can affect
the current observation, but future spend cannot.

Supported adstock families in the maintained model path are:

| Type | Lag weights |
|---|---|
| `none` | $A_j(x)_t = x_{t,j}$ |
| `geometric` | $w_{\ell} = \alpha^\ell$ |
| `delayed` | $w_{\ell} = \alpha^{(\ell - \theta)^2}$ |
| `binomial` | $w_{\ell} = (1 - \ell / (L + 1))^{1 / \alpha - 1}$ |
| `weibull_pdf` | Weibull-PDF-shaped finite-lag kernel |
| `weibull_cdf` | Weibull-survival-style finite-lag kernel with a leading self-retention term |

When `normalize=true`, Epsilon normalises the constructed lag weights by their
sum. Normalisation changes the scale of the carryover signal and therefore the
interpretation of the media coefficient.

### Weibull-PDF Weight Rescaling

For `weibull_pdf`, Epsilon first evaluates a finite Weibull-PDF-shaped lag
profile and then rescales that profile to the interval `[0, 1]` before the
optional `normalize=true` sum-normalisation step. In symbols, if
$u_\ell$ is the raw finite-lag Weibull PDF value, the default PDF-kernel weights
are:

```math
w_\ell =
\begin{cases}
(u_\ell - \min_m u_m) / (\max_m u_m - \min_m u_m), & \max_m u_m > \min_m u_m, \\
u_\ell, & \max_m u_m = \min_m u_m.
\end{cases}
```

This is a shape rescaling, not a probability-mass normalisation. It preserves a
bounded finite-lag profile for the model's adstock layer; use `normalize=true`
when you want the resulting finite kernel to sum to one before convolution.
Because this changes the scale of the adstocked signal, compare Weibull-PDF
results against other adstock families through fitted contributions and response
curves rather than raw lag weights alone.

## Saturation

Saturation maps the adstocked signal to a nonlinear response scale. It is where
diminishing marginal returns enter the model.

Supported saturation families in the maintained model path are:

| Type | Functional form |
|---|---|
| `none` | $S(x) = x$ |
| `logistic` | $S(x; \lambda) = \tanh(\lambda x / 2)$ |
| `tanh` | $S(x; b, c) = b \tanh(x / (bc))$ |
| `michaelis_menten` | $S(x; a, \lambda) = ax / (\lambda + x)$ |
| `hill` | $S(x; s, \kappa) = 1 - \kappa^s / (\kappa^s + x^s)$ |

Media spend must be nonnegative at public model boundaries. The low-level tanh
primitive can accept signed values, but the MMM media path treats negative
media as invalid input.

## Contribution

After transformation, each channel contributes:

```math
\mathrm{contribution}_{t,j}
= \beta_j S_j(A_j(x_j)_t).
```

The total media contribution is:

```math
m_t = \sum_{j=1}^{J} \mathrm{contribution}_{t,j}.
```

Panel models use the same expression with panel-cell-specific indexing:

```math
\mathrm{contribution}_{t,j,p}
= \beta_{j,p} S_{j,p}(A_{j,p}(x_{j,p})_t).
```

## Why A Response Curve Can Look Linear

A response curve can look almost linear even when the configured saturation
function is nonlinear. The visible curvature depends on the part of the curve
covered by the plotted spend range and posterior draws.

For the centered-logistic form:

```math
S(x; \lambda) = \tanh(\lambda x / 2).
```

Near zero, the first-order approximation is:

```math
S(x; \lambda) \approx \lambda x / 2.
```

So if the fitted posterior places observed spend in a low-saturation region,
the plotted response curve will be close to a straight line. Stronger curvature
appears when the observed or counterfactual spend range reaches the shoulder of
the saturation curve. This is a modelling result, not automatically a plotting
bug.

The practical checks are:

- inspect the posterior for the saturation parameter,
- compare observed spend with the grid range used by the response plot,
- check whether the channel was scaled to a range where $\lambda x$ remains
  small,
- compare marginal response curves, not just total response curves.

## Reading Adstock Curves

Adstock curves show carryover, not diminishing returns. A geometric or
normalised finite-lag adstock curve can be close to linear over a plotted total
spend range because adstock is a weighted sum. Curvature in MMM usually comes
from the saturation layer, not the carryover layer by itself.

When interpreting Epsilon's plotted artifacts, treat adstock, saturation,
response, contribution, and optimisation plots as different projections of the
same fitted model. They answer related but distinct questions.
