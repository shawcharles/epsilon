# Phase 67: Epsilon-Native Demo Configs

Status: Implemented

## Objective

Adapt the newly copied `data/demo/*/config.yml` files so they are
Epsilon-native config-driven demo inputs for the current pipeline surface:

```text
config.yml + dataset.csv + holidays.csv -> run_pipeline / epsilon run -> results/<run>/
```

This phase should make the copied demo bundles usable for Epsilon's own
workflow without pretending to preserve every Abacus-only config feature.

## Current Evidence

Observed on 2026-07-19:

- `data/` is currently untracked and contains:
  - `data/demo/timeseries/{config.yml,dataset.csv,holidays.csv}`
  - `data/demo/geo_panel/{config.yml,dataset.csv,holidays.csv}`
  - `data/demo/geo_brand_panel/{config.yml,dataset.csv,holidays.csv}`
  - `data/holidays.csv`
- `data/demo/timeseries/config.yml` fails Epsilon pipeline config loading
  because its copied validation block uses Abacus-style
  `holdout_observations`, `include_last_observations`, `coverage_levels`, and
  nested `sampler` keys.
- `data/demo/geo_panel/config.yml` and
  `data/demo/geo_brand_panel/config.yml` currently load as `PanelMMM`
  configs, but only because Epsilon normalises/strips or ignores several
  copied Abacus-style surfaces. They are not honest Epsilon-native configs yet.
- Epsilon supports all three data shapes through:
  - `TimeSeriesMMM` for `timeseries`;
  - `PanelMMM` with `dimensions.panel = ["geo"]` for `geo_panel`; and
  - `PanelMMM` with `dimensions.panel = ["geo", "brand"]` for
    `geo_brand_panel`.

## Scope

In scope:

- Adapt the three copied `data/demo/*/config.yml` files to Epsilon-native YAML.
- Keep each config self-contained with local `dataset.csv` and `holidays.csv`
  paths.
- Replace copied Abacus `effects` seasonality declarations with explicit
  Epsilon `seasonality` blocks.
- Replace copied `holidays.mode: prophet_component` with Epsilon's supported
  `holidays.mode: auto`.
- Move copied `media.saturation.priors.beta` into Epsilon's native
  `priors.beta_media` position.
- Remove unsupported or intentionally retired copied workflow blocks:
  `ai_advisor`, `original_scale_vars`, Abacus-style validation subkeys, and
  relative-budget optimisation blocks.
- Keep optimisation disabled by default in demo configs unless a native
  `total_budget` contract is explicitly added later.
- Add a small `data/README.md` describing which configs are runnable and the
  key support limits.
- Commit the copied demo CSVs/holiday files together with their adapted
  configs so the configs are reproducible.
- Keep `data/holidays.csv` as a shared reference copy only; the runnable demo
  configs should depend on their bundle-local `holidays.csv` files.

Out of scope:

- Runtime source changes.
- New config parser compatibility shims.
- New modelling features.
- Panel holdout validation.
- Panel calibration.
- Free channel-by-panel optimisation.
- AI advisor, dashboard/UI, or VI surfaces.
- Benchmark or release-evidence claims.
- Full-suite execution.
- Editing existing `examples/demo/` behaviour in this phase.
- Parity ledger status changes.

## File Allowlist

Implementation may touch only:

- `data/README.md`
- `data/holidays.csv`
- `data/demo/timeseries/config.yml`
- `data/demo/timeseries/dataset.csv`
- `data/demo/timeseries/holidays.csv`
- `data/demo/geo_panel/config.yml`
- `data/demo/geo_panel/dataset.csv`
- `data/demo/geo_panel/holidays.csv`
- `data/demo/geo_brand_panel/config.yml`
- `data/demo/geo_brand_panel/dataset.csv`
- `data/demo/geo_brand_panel/holidays.csv`
- `.planning/phases/67-epsilon-native-demo-configs/PLAN.md`

Known unrelated local files must remain unstaged:

- `.gitignore`
- `.planning/CRITICAL-REVIEW-2026-07-19.md`

## Acceptance Criteria

- [x] All three `data/demo/*/config.yml` files are Epsilon-native and no longer
      contain copied Abacus-only workflow blocks.
- [x] All three configs load through `PipelineRunConfig` /
      `_load_pipeline_configuration`.
- [x] All three configs load their CSV datasets and build a corresponding
      `TimeSeriesMMM` or `PanelMMM` model spec without running MCMC.
- [x] The panel configs remain honest about unsupported panel holdout
      validation and free channel-by-panel optimisation by omitting those
      workflow blocks.
- [x] `data/README.md` explains the runnable config-driven shape and the
      bounded support limits.
- [x] An independent read-only review approves or corrects the plan before
      implementation.
- [x] Staged files match the allowlist exactly.

## Verification

Use scoped checks only:

```bash
julia --project=. -e 'using Epsilon; mktempdir() do dir; for cfg in ARGS; c=PipelineRunConfig(config_path=cfg, output_dir=dir, draws=1, tune=0, chains=1, cores=1, prior_samples=2, curve_points=4); loaded=Epsilon._load_pipeline_configuration(c); ctx=Epsilon._pipeline_context(c, loaded); data=isempty(loaded.model_config.dims) ? Epsilon._load_pipeline_dataset(ctx) : Epsilon._load_pipeline_panel_dataset(ctx); model=isempty(loaded.model_config.dims) ? TimeSeriesMMM(loaded.model_config, loaded.sampler_config, data) : PanelMMM(loaded.model_config, loaded.sampler_config, data); spec=build_model(model); println(cfg, " => ", typeof(model), " nobs=", spec.nobs, " nchannels=", spec.nchannels); end; end' data/demo/timeseries/config.yml data/demo/geo_panel/config.yml data/demo/geo_brand_panel/config.yml
rg -n "prophet_component|holdout_observations|include_last_observations|coverage_levels|ai_advisor|original_scale_vars|mode: relative|openrouter|llm_enabled|^effects:" data/demo
julia --project=. -e 'import YAML; for cfg in ARGS; raw=YAML.load_file(cfg); priors=get(get(get(raw, "media", Dict()), "saturation", Dict()), "priors", Dict()); haskey(priors, "beta") && error("media.saturation.priors.beta remains in $cfg"); end' data/demo/timeseries/config.yml data/demo/geo_panel/config.yml data/demo/geo_brand_panel/config.yml
git diff --check
git diff --cached --check
git diff --cached --name-only | sort
git status --short --branch
```

No MCMC run and no full suite are required because this phase adapts demo
configuration and data assets only. The model-spec construction check verifies
that the configs, data paths, holiday paths, panel coordinates, and model
surface all resolve without paying sampler cost.

## Independent Review Result

The independent read-only review approved the slice with two required
corrections:

- Use bundle-local holiday paths (`path: holidays.csv`) in each runnable demo
  config, keeping `data/holidays.csv` only as a shared reference copy.
- Run verification inside `mktempdir()` because `_pipeline_context` creates a
  run directory even though the check does not run MCMC.

The reviewer also recommended strengthening the grep guard for lingering
Abacus-style `effects:` blocks and adding a structural YAML check that
`media.saturation.priors.beta` is no longer present.

## Landing Notes

- Adapted `data/demo/timeseries/config.yml`,
  `data/demo/geo_panel/config.yml`, and
  `data/demo/geo_brand_panel/config.yml` to Epsilon-native config surfaces.
- Replaced copied `effects` blocks with explicit `seasonality` blocks.
- Replaced copied `holidays.mode: prophet_component` with
  `holidays.mode: auto` and local `path: holidays.csv` in each bundle.
- Moved copied media amplitude priors from
  `media.saturation.priors.beta` into native `priors.beta_media`.
- Removed copied Abacus-only workflow blocks:
  `ai_advisor`, `original_scale_vars`, relative-budget optimisation, and
  Abacus-style validation subkeys.
- Kept time-series holdout validation on the native `holdout_rows` key.
- Omitted panel validation blocks because panel Stage 35 remains deferred.
- Kept optimisation disabled by default in all three demo configs.
- Added `data/README.md` documenting the config-driven workflow and current
  support limits.
- Committed the copied demo datasets and holiday CSV files alongside the
  adapted configs so each config is runnable from the repository checkout.

Scoped verification:

```bash
! rg -n "prophet_component|holdout_observations|include_last_observations|coverage_levels|ai_advisor|original_scale_vars|mode: relative|openrouter|llm_enabled|^effects:" data/demo
# no matches

julia --project=. -e 'import YAML; for cfg in ARGS; raw=YAML.load_file(cfg); priors=get(get(get(raw, "media", Dict()), "saturation", Dict()), "priors", Dict()); haskey(priors, "beta") && error("media.saturation.priors.beta remains in $cfg"); println("native-priors-ok ", cfg); end' data/demo/timeseries/config.yml data/demo/geo_panel/config.yml data/demo/geo_brand_panel/config.yml
# native-priors-ok for all three configs

julia --project=. -e 'using Epsilon; mktempdir() do dir; for cfg in ARGS; c=PipelineRunConfig(config_path=cfg, output_dir=dir, draws=1, tune=0, chains=1, cores=1, prior_samples=2, curve_points=4); loaded=Epsilon._load_pipeline_configuration(c); ctx=Epsilon._pipeline_context(c, loaded); data=isempty(loaded.model_config.dims) ? Epsilon._load_pipeline_dataset(ctx) : Epsilon._load_pipeline_panel_dataset(ctx); model=isempty(loaded.model_config.dims) ? TimeSeriesMMM(loaded.model_config, loaded.sampler_config, data) : PanelMMM(loaded.model_config, loaded.sampler_config, data); spec=build_model(model); println(cfg, " => ", typeof(model), " nobs=", spec.nobs, " nchannels=", spec.nchannels, " dims=", spec.dims); end; end' data/demo/timeseries/config.yml data/demo/geo_panel/config.yml data/demo/geo_brand_panel/config.yml
# data/demo/timeseries/config.yml => TimeSeriesMMM nobs=104 nchannels=6 dims=()
# data/demo/geo_panel/config.yml => PanelMMM nobs=312 nchannels=6 dims=("geo",)
# data/demo/geo_brand_panel/config.yml => PanelMMM nobs=936 nchannels=6 dims=("geo", "brand")

git diff --check
# passed with no output
```

No MCMC run and no full suite were run because this phase changes only
configuration/data demo assets and verifies config/data/model-spec resolution.
