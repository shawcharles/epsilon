# Configuration

Epsilon's public runner is config driven. A normal run uses one YAML file and a
combined CSV dataset:

```bash
julia --project=. runme.jl path/to/config.yml
```

Relative paths in the config are resolved from the directory containing the
YAML file. The maintained demo bundles under `data/demo/` are the best starting
templates.

## Required Top-Level Blocks

A runnable model config needs:

| Block | Purpose |
|---|---|
| `data` | dataset path and date column |
| `target` | target column and target type |
| `media` | media channel columns plus adstock and saturation choices |
| `fit` | MCMC/Turing sampler settings |

The config parser rejects unknown top-level keys in the maintained pipeline
surface. That is deliberate: spelling mistakes should fail clearly rather than
quietly producing a different model.

## Minimal Time-Series Config

```yaml
data:
  dataset_path: dataset.csv
  date_column: date

target:
  column: revenue
  type: revenue

media:
  channels: [tv, search]
  adstock:
    type: geometric
    l_max: 4
  saturation:
    type: logistic

fit:
  backend: turing
  draws: 250
  tune: 250
  chains: 2
  cores: 2
  random_seed: 42
```

The dataset must contain the date column, target column, and every media
channel listed in the YAML.

## Minimal Panel Config

```yaml
data:
  dataset_path: dataset.csv
  date_column: date

target:
  column: revenue
  type: revenue

dimensions:
  panel: [geo]

media:
  channels: [tv, search]
  adstock:
    type: geometric
    l_max: 4
  saturation:
    type: logistic

fit:
  backend: turing
  draws: 250
  tune: 250
  chains: 2
  cores: 2
  random_seed: 42
```

The dataset must contain every declared panel column. For a geo-by-brand model,
use:

```yaml
dimensions:
  panel: [geo, brand]
```

Internally, Epsilon fits panel models on a flattened `panel_cell` axis and
keeps coordinate metadata for interpretation and replay.

## `data`

```yaml
data:
  dataset_path: dataset.csv
  date_column: date
```

`dataset_path` is required by `run_pipeline` and `runme.jl`. It points to one
combined CSV containing target, media, optional controls, optional events, and
optional panel columns. Separate `x_path` and `y_path` inputs are unsupported.

`date_column` names the date column used for time indexing, seasonality,
holidays, trend, and result artifacts.

## `target`

```yaml
target:
  column: revenue
  type: revenue
```

`column` names the target variable. `type` is currently:

- `revenue`
- `conversion`

The target type affects metric defaults: revenue targets default to ROAS;
conversion targets default to CPA.

## `media`

```yaml
media:
  channels: [tv, search]
  adstock:
    type: geometric
    l_max: 4
    normalize: false
  saturation:
    type: logistic
```

`channels` is the ordered list of media columns. Media values must be
nonnegative at model boundaries.

Supported adstock types:

- `none`
- `geometric`
- `delayed`
- `binomial`
- `weibull_pdf`
- `weibull_cdf`

Adstock accepts:

- `type`
- `l_max`
- `normalize`
- `priors`

Supported saturation types:

- `none`
- `logistic`
- `tanh`
- `michaelis_menten`
- `hill`

Saturation accepts:

- `type`
- `priors`

See [Media Transforms](methodology/media_transforms.md) for the mathematical
forms.

## Priors

Priors can be supplied in the top-level `priors` block or inside transform
blocks:

```yaml
priors:
  intercept:
    distribution: Normal
    mu: 0
    sigma: 2
  beta_media:
    distribution: HalfNormal
    sigma: 1
    dims: ["channel"]

media:
  adstock:
    type: geometric
    l_max: 4
    priors:
      alpha:
        distribution: Beta
        alpha: 1
        beta: 3
        dims: ["channel"]
```

Supported distribution names include `Normal`, `HalfNormal`, `Beta`, `Gamma`,
`Exponential`, `Laplace`, `LogNormal`, `Uniform`, `Weibull`, `Cauchy`,
`HalfCauchy`, `StudentT`, `SkewStudentT`, `Scaled`, and `TruncatedNormal`,
subject to the parameter requirements of the fitted path.

Use `dims` to declare parameter ownership. Common dimensions are:

- `channel`
- `date`
- `holiday`
- declared panel dimensions such as `geo` or `brand`

For panel configs, priors must either include all declared panel dimensions or
none. Partial panel-dimensional priors are rejected to avoid ambiguous
coordinate ownership.

See [Scaling And Priors](methodology/scaling_and_priors.md) before interpreting
prior magnitudes in business units.

## Seasonality

The maintained seasonality path is Fourier seasonality:

```yaml
seasonality:
  type: fourier
  n_order: 2
```

Panel models currently support only Fourier seasonality.

## Holidays

Automatic holiday features use a holiday CSV and one or more countries:

```yaml
holidays:
  mode: auto
  path: holidays.csv
  countries: UK
  priors:
    beta:
      distribution: Normal
      mu: 0
      sigma: 1
      dims: ["holiday"]
```

`countries` may be a string or a list of strings. Panel models support only the
current automatic pooled-holiday path.

## Controls

Time-series controls are declared through `media.controls` and can have a
`controls` block for transformation and priors:

```yaml
media:
  channels: [tv, search]
  controls: [price_index]

controls:
  transform: standardize
  priors:
    beta:
      distribution: Normal
      mu: 0
      sigma: 1
```

Panel controls are not part of the maintained panel surface.

## Trend And Events

Time-series configs may include supported trend and event blocks. These are
additive effects in the model mean.

```yaml
trend:
  type: linear

events:
  columns: [promotion_flag]
```

Panel trend and panel events are not currently supported.

## Calibration

Calibration YAML is supported only for time-series MCMC configs. It is not
supported for panel configs.

```yaml
calibration:
  steps:
    - method: lift_test
      params:
        dist: gamma
  lift_test:
    channel: [tv]
    x: [10000.0]
    delta_x: [2000.0]
    delta_y: [450.0]
    sigma: [120.0]
```

Lift-test calibration is currently supported on the centered-logistic
time-series path. Cost-per-target calibration uses:

```yaml
calibration:
  steps:
    - method: cost_per_target
  cost_per_target:
    gathered_cpt: [20.0]
    targets: [100.0]
    sigma: [5.0]
```

## Validation

Time-series blocked holdout validation is a runner-stage setting:

```yaml
validation:
  enabled: true
  holdout_rows: 8
```

When enabled, `holdout_rows` must be a positive integer. Panel holdout
validation is outside the maintained support surface.

## Prior Sensitivity

Prior sensitivity is a bounded planning stage. It writes scenario metadata; it
does not automatically refit every scenario.

```yaml
prior_sensitivity:
  enabled: true
  reference: reference
  scenario_policy: manual
  scenarios:
    tighter_media:
      description: Narrower media coefficient prior
      overrides:
        priors.beta_media.sigma: 0.5
```

Supported policies are `manual` and `conservative_mmm`. Scenario names must be
lowercase slugs using letters, numbers, and underscores.

## Optimisation

Optimisation is optional. Disable it explicitly when you do not want Stage `70`
artifacts:

```yaml
optimization:
  enabled: false
```

Skipped stages still create their directory and write `SKIPPED.json`.

When enabled, a total budget is required:

```yaml
optimization:
  enabled: true
  total_budget: 250000
  channels: [tv, search]
  objective: total_response
```

The maintained objective is `total_response`. Panel optimisation uses
historical within-channel panel shares; it is not free channel-by-panel
optimisation.

## Fitting

```yaml
fit:
  backend: turing
  draws: 1000
  tune: 1000
  chains: 4
  cores: 4
  target_accept: 0.8
  random_seed: 42
  progressbar: true
  compute_convergence_checks: true
```

Supported backend values are:

- `turing`
- `mcmc`
- `nuts`

Variational inference keys such as `vi`, `variational`, and
`approximate_fit` are permanently unsupported.

## Plot Output

Plotting is controlled by the runner and plotting backend, not by a maintained
YAML `plots` block. `runme.jl` loads CairoMakie by default and writes PNG plot
artifacts when plotting is available.

Use:

```bash
julia --project=. runme.jl path/to/config.yml --no-plots
```

to suppress plot artifact generation in headless runs.

## Use The Demo Bundles

The maintained examples are:

- `data/demo/timeseries/config.yml`
- `data/demo/geo_panel/config.yml`
- `data/demo/geo_brand_panel/config.yml`

Copy one of those bundles, then adjust column names, priors, sampler settings,
validation, calibration, and optimisation for your data.
