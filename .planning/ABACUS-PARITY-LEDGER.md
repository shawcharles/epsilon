# Abacus Parity Ledger

## Purpose

This ledger is the implementation control document for making Epsilon a
credible Julia port of the Abacus MMM core. It separates implemented Julia
surface area from demonstrated Abacus parity and keeps release claims tied to
fixtures, demo runs, and artifact contracts.

Epsilon should not claim broad Abacus parity until the relevant row below has a
deterministic fixture, an Epsilon implementation, and a passing comparison test
or a documented Julia-native divergence.

## Status Labels

- `ported`: implemented in Epsilon and parity-tested against Abacus semantics
- `native`: implemented intentionally differently in Julia with documented
  methodology
- `scaffolded`: API or module exists, but Abacus parity is not yet proven
- `missing`: Abacus behavior is not implemented in Epsilon, but remains in
  scope for the Julia port unless explicitly deferred
- `deferred`: intentionally out of the statistical/methodological port scope
  for now. Current explicit deferrals are AI advisor and Dash/dashboard parity.

## Acceptance Targets

The first parity milestone is not the full Abacus product. It is the Abacus
statistical MMM core on bundled demo-style runs:

1. `timeseries`
2. `geo_panel`
3. `geo_brand_panel`

Each target should pass these gates before it is counted as ported:

- config and data ingestion normalize to the expected typed model spec
- design matrices, transformed media tensors, and coordinate metadata match
  Abacus where semantics match
- prior and likelihood parameterization are documented and test-covered
- posterior predictive, contribution, curve, metric, and optimization artifacts
  are reproducible from saved fit state
- pipeline output has a stable manifest and stage-local artifact layout

## Core Ledger

| Abacus Area | Abacus Source | Epsilon Target | Status | Next Work |
|---|---|---|---|---|
| Package identity and public exports | `abacus/__init__.py`, `abacus/version.py` | `src/Epsilon.jl` | scaffolded | Audit exports against the supported core API and remove or document surfaces that are not parity-backed. |
| YAML/public builder | `abacus/mmm/builders/*.py`, `abacus/pipeline/config.py` | `src/model/config.jl`, `src/model/builder.jl`, `src/pipeline/config.jl` | scaffolded | Build config-normalization fixtures from Abacus demo configs and compare the resolved typed spec. |
| Data validation and preprocessing | `abacus/mmm/preprocessing.py`, `abacus/mmm/validating.py`, `abacus/mmm/models/panel_data.py` | `src/model/types.jl`, `src/model/builder.jl`, `src/mmm/media.jl`, `src/mmm/panel.jl` | scaffolded | `PanelAxis`, `PanelCoordinate`, `panel_axis`, and `panel_coordinates` expose deterministic flat `panel_cell` reconstruction for one-dimensional and multidimensional panels, with declared coordinate columns kept in model order. `ntime`, `npanels`, and `npanel_observations` make panel observation semantics explicit while `nobs(::PanelMMMData)` remains the compatibility flat panel-cell count. Add remaining fixtures for date ordering, channel/control columns, missingness, panel keys, and holdout splits. |
| Scaling | `abacus/mmm/scaling.py`, `abacus/mmm/preprocessing.py` | `src/transforms/scaling.jl`, `src/mmm/controls.jl` | ported | Keep parity tests tied to Abacus fixture exports; extend to panel-scaled tensors. |
| Convolution | `abacus/mmm/transforms/convolution.py` | `src/transforms/convolution.jl` | ported | Keep as low-level fixture gate for all adstock work. |
| Adstock transforms | `abacus/mmm/components/adstock.py`, `abacus/mmm/transforms/adstock.py` | `src/transforms/adstock.jl` | ported | Verify no-adstock and panel tensor behavior against Abacus. |
| Saturation transforms | `abacus/mmm/components/saturation.py`, `abacus/mmm/transforms/saturation.py` | `src/transforms/saturation.jl` | scaffolded | `centered_logistic_saturation` is the explicit Epsilon name for the existing zero-baselined logistic-family curve; `logistic_saturation` remains a legacy alias. Continue auditing coverage for inverse-scaled logistic, baselined tanh, sigmoid hill, root, and no-saturation variants. |
| Prior schema and distribution mapping | `abacus/prior.py`, `abacus/model_config.py` | `src/distributions/priors.jl` | scaffolded | Compare parsed prior configs, defaults, dimensions, and parameter names from demo configs. |
| Special priors | `abacus/special_priors/*.py` | `src/distributions/special.jl`, `src/distributions/masked.jl`, `src/distributions/shrinkage.jl` | scaffolded | Prove log-density and coefficient-helper parity or document Julia-native replacements. |
| Fourier seasonality | `abacus/mmm/fourier.py` | `src/mmm/seasonality.jl` | scaffolded | Add basis-matrix fixtures with dates from demo data. |
| HSGP and time-varying parameters | `abacus/mmm/hsgp.py`, `abacus/mmm/tvp.py` | future `src/mmm/hsgp.jl` / `src/mmm/tvp.jl` | missing | Port basis construction and time-varying parameter semantics after `geo_brand_panel` parity is stable. |
| Linear and changepoint trend | `abacus/mmm/linear_trend.py` | `src/mmm/trend.jl` | scaffolded | Compare trend design matrices and fitted prediction-state replay. |
| Events and holiday basis effects | `abacus/mmm/events.py`, `abacus/mmm/builders/holidays.py` | `src/mmm/events.jl`, `src/mmm/holidays.jl` | scaffolded/native | Separate Abacus-compatible event basis from Epsilon-native pooled holiday behavior. |
| Additive effects | `abacus/mmm/additive_effect.py`, `abacus/mmm/models/panel_build.py` | `src/mmm/model.jl`, `src/postmodel/replay.jl` | scaffolded | Lock contribution-term naming and additive replay state. |
| Target types and efficiency metrics | `abacus/mmm/target.py`, `abacus/metrics.py` | `src/postmodel/metrics.jl`, `src/optimization/summary.jl` | scaffolded | Port target-type normalization and ROAS/CPA label semantics. |
| Time-series MMM | `abacus/mmm/panel.py` with no panel dims | `src/mmm/model.jl`, `src/inference/mcmc.jl` | scaffolded | Make `timeseries` demo the first vertical acceptance target. |
| Panel MMM, one dimension | `abacus/mmm/panel.py`, `abacus/mmm/models/*.py` | `src/mmm/panel.jl` | ported | `geo_panel` config/model semantics and deterministic replay are covered by validation fixtures; continue extending downstream panel artifacts separately. |
| Multi-dimensional panel MMM | `abacus/mmm/panel.py`, `abacus/mmm/models/panel_types.py` | `src/mmm/panel.jl`, `src/model/types.jl`, `src/postmodel/replay.jl` | scaffolded | `geo_brand_panel` config/data, flattened panel ordering, model-spec metadata, runtime artifact schema, deterministic contribution/decomposition replay, and panel-cell response/metric summaries are covered by validation fixtures; Stage `70` historical-share optimization is implemented for `PanelMMM` and fixture-backed for both `geo_panel` and `geo_brand_panel`. |
| Hierarchical pooling through priors | `abacus/mmm/panel.py`, `abacus/prior.py` | `src/mmm/panel.jl`, `src/distributions/priors.jl` | scaffolded | Ensure pooling is encoded through priors, not implicit panel defaults. |
| Mundlak / correlated random effects | Abacus panel/model code and docs | none | missing | Port only after panel-indexed baseline is stable. |
| Calibration and lift tests | `abacus/mmm/lift_test.py`, `abacus/mmm/calibration/*.py`, `abacus/mmm/builders/calibration.py` | none | missing | Add likelihood-term fixtures and schema before model integration. |
| Fitting and sampler config | `abacus/modeling/base.py`, `abacus/pytensor/sampling.py` | `src/inference/mcmc.jl`, `src/model/config.jl` | scaffolded | Compare sampler config parsing and saved fit metadata; numerical posterior equality is not required. |
| Posterior predictive | `abacus/mmm/base.py`, `abacus/mmm/models/panel_predict.py` | `src/model/results.jl`, `src/inference/results.jl` | scaffolded | Make prediction replay consume saved state for train, holdout, and new data. |
| Diagnostics | `abacus/mmm/diagnostics/*.py` | `src/model/diagnostics.jl`, `src/inference/diagnostics.jl`, `src/plotting/diagnostics.jl` | scaffolded | Port design, MCMC, and predictive summary schemas before plot polish. |
| Panel holdout validation | `abacus/pipeline/stages/validation.py` and panel prediction paths | none | deferred | Stage `35` panel validation is not a v1 MMM requirement. Epsilon keeps time-series blocked holdout validation, but defers panel holdout semantics until there is a concrete methodological requirement beyond parity theater. |
| Contribution and decomposition outputs | `abacus/mmm/base.py`, `abacus/mmm/summarization/*.py` | `src/postmodel/contributions.jl`, `src/postmodel/decomposition.jl` | ported | Time-series replay is covered by `test/validation/timeseries_model_replay.jl`; panel replay is covered by `test/validation/geo_panel_model_replay.jl` and `test/validation/geo_brand_panel_model_replay.jl`. Post-model summary derivation now validates the frozen contribution/decomposition axis contracts before emitting tables. |
| Response, saturation, and adstock curves | `abacus/mmm/panel.py`, `abacus/mmm/summarization/curves.py` | `src/postmodel/response_curves.jl` | ported | Time-series response, saturation-only, and adstock-only curves are covered by `test/validation/timeseries_model_replay.jl`; `geo_brand_panel` panel-cell historical-scaling curves are covered by `test/validation/geo_brand_panel_model_replay.jl`. Curve and metric artifacts now validate the `(draw, panel, spend_point)` / `(draw, panel, spend_point, metric)` panel contracts, including `(panel, spend_point)` spend grids and explicit `delta_grid` multipliers. |
| Budget optimization | `abacus/mmm/budget_optimizer.py`, `abacus/mmm/optimization/*.py`, `abacus/mmm/constraints.py` | `src/optimization/*.jl` | scaffolded | Time-series optimization is fixture-backed; `PanelMMM` now supports the bounded v1 historical-share policy: optimize channel totals, reuse panel response curves through shared channel deltas, and preserve within-channel panel-cell spend shares. Free channel-by-panel allocation and panel-total bounds remain deferred. |
| Pipeline runner and artifacts | `abacus/pipeline/*.py`, `abacus/pipeline/stages/*.py` | `src/pipeline/*.jl` | scaffolded | `timeseries` now exports the Abacus pipeline manifest/artifact contract and Epsilon validates Stage `00` through Stage `70` artifact-key parity, using Julia-native serialized artifacts where Abacus uses PyMC/NetCDF-specific files; `geo_panel` and `geo_brand_panel` now cover Stage `00` metadata/manifest parity, Stage `20` fit artifact-key parity, Stage `30` assessment artifact-key parity, Stage `40` decomposition artifact-key parity, Stage `50` diagnostics artifact-key parity, and Stage `60` response-curve artifact-key parity. Both `geo_panel` and `geo_brand_panel` now also cover explicitly enabled Stage `70` historical-share optimization artifacts, with multidimensional `geo`/`brand` coordinate columns preserved in `channel_panel_allocation.csv` for `geo_brand_panel`; other unsupported panel stages are skipped until semantics are fixture-backed. |
| Prior sensitivity | `abacus/prior_sensitivity/*.py`, `abacus/pipeline/stages/prior_sensitivity.py` | `src/pipeline/config.jl`, `src/pipeline/stages.jl` | ported | Bounded Stage `05` prior-sensitivity planning is implemented: manual and `conservative_mmm` scenario configs are resolved to YAML, human and LLM-safe manifests are emitted, and narrow prior plus explicitly gated structure override paths are validated. Automatic refitting/comparison of every scenario is out of this stage's scope. |
| Plotting | `abacus/mmm/plotting/*.py`, `abacus/plot.py` | `src/plotting/*.jl` | native/scaffolded | Keep Julia-native Makie plots; compare data inputs, not exact figure appearance. |
| Scenario planner | `abacus/scenario_planner/*.py` | `src/scenario_planner.jl` | scaffolded | Bounded non-UI planner semantics are started: typed current/manual/fixed-budget scenario specs and `scenario_plan(result)` emit Abacus-like totals, channel, allocation, metadata, and panel allocation tables from solved optimization results. Automatic scenario refits, future spend-path simulation, background jobs, and Dash UI remain deferred. |
| AI advisor | `abacus/ai/*.py`, `abacus/pipeline/stages/ai_advisor.py` | none | deferred | Not central to the statistical or methodological port. |
| Dash/dashboard and product UX | Abacus Dash/dashboard/product layers, `docs-site/`, product assets | `docs/`, Julia-native plots/artifacts | deferred/native | Do not chase Dash or hosted dashboard parity; keep docs and static Julia-native artifacts honest. |

## Implementation Sequence

### 1. Contract Reset

- Keep README and planning docs explicit that Epsilon is a partial Abacus port.
- Treat the old phase-completion text as internal history, not parity evidence.
- Add `ported`, `native`, `scaffolded`, `missing`, and `deferred` labels to
  user-facing release notes.

### 2. Fixture Spine

- Extend `scripts/export_abacus_fixtures.py` to export demo config resolution,
  design matrices, transformed media tensors, coordinates, and core artifact
  schemas.
- Commit generated Julia fixture literals under `test/fixtures/abacus/`.
- Keep Python out of the Julia test runtime.

### 3. Config And Data Parity

- Make Abacus demo configs compile into a stable `MMMModelSpec`.
- Compare normalized columns, dates, panel dimensions, target type, priors,
  transforms, events, holidays, and fit config.
- Do this before adding more model features.

### 4. Model Core Parity

- Make `timeseries` pass the full design and replay gates.
- Make `geo_panel` pass one-dimensional panel gates with panel-indexed
  parameters by default.
- Add `geo_brand_panel` only after the panel core supports multiple dimensions
  without special cases.

### 5. Methodology Gap Closure

- Add missing HSGP/time-varying parameter behavior after the multidimensional
  panel contract is stable.
- Add Mundlak/correlated random effects only after panel parity is stable.
- Add calibration and lift-test likelihood terms as a separate, fixture-backed
  slice.

### 6. Artifact And Pipeline Parity

- Freeze saved fit, inference, contribution, curve, metric, optimization, and
  pipeline manifest schemas.
- Rebuild the pipeline around the three demo acceptance targets.
- Make release readiness depend on demo-level acceptance, not on broad module
  presence.

## Evidence Update

As of 2026-05-10:

1. `test/validation/timeseries_config_data.jl` covers the Abacus
   `timeseries` demo config/data fixture, including media scaling,
   geometric adstock, centered logistic saturation, seasonality coordinates, and the
   Epsilon-native pooled holiday mapping.
2. `test/validation/timeseries_model_replay.jl` covers a controlled
   `timeseries` posterior replay fixture for parameter names, additive
   contributions, posterior mean reconstruction, decomposition totals/shares,
   response curves, saturation curves, adstock curves, and ROAS/CPA metric
   tables.
3. Holiday behavior for the `timeseries` row is explicitly
   `native`: Abacus `prophet_component` config is ingested and normalized to
   Epsilon's pooled automatic holiday component.
4. `test/validation/geo_panel_config_data.jl` covers the Abacus `geo_panel`
   demo config/data fixture, including panel keys, panel-wise scaling tensors,
   panel-indexed adstock alpha, beta-media, intercept, and sigma prior
   dimensions, geometric adstock, centered logistic saturation, panel Fourier
   seasonality, and native pooled panel holiday design. Abacus
   `prophet_component` config is ingested as Epsilon's `native` pooled automatic
   holiday component, matching the current time-series holiday contract.
5. `test/validation/geo_panel_model_replay.jl` covers a controlled
   one-dimensional panel replay fixture for parameter names, panel-indexed media
   transforms, original-scale contribution artifacts, posterior mean
   reconstruction, decomposition totals/shares, and panel contribution summary
   table schema.
6. `test/validation/geo_brand_panel_config_data.jl` covers the Abacus
   `geo_brand_panel` demo config/data fixture, including `("geo", "brand")`
   panel dimension order, deterministic flattened panel-cell ordering,
   panel-wise scaling tensors, multidimensional panel-indexed alpha,
   beta-media, intercept, sigma, Fourier seasonality, and native pooled panel
   holiday design.
7. `test/validation/geo_brand_panel_model_replay.jl` covers controlled
   multidimensional panel replay for `geo_brand_panel`, including flat
   panel-cell parameter ordering, original-scale contributions,
   decomposition totals/shares, posterior mean reconstruction, and contribution
   summary tables with `panel`, `geo`, and `brand` columns.
8. `test/validation/geo_brand_panel_model_replay.jl` now also covers
   panel-cell response, saturation, adstock, and marketing-metric summaries for
   `geo_brand_panel`. Panel curves require an explicit `delta_grid` and use
   Abacus-style historical scaling of each observed panel-cell/channel spend
   path instead of an implicit aggregate allocation rule.
9. `scripts/export_abacus_fixtures.py` now exports the latest local Abacus
   `timeseries` pipeline contract into `test/fixtures/abacus/timeseries/config_data.jl`,
   including manifest keys, stage record keys, stage artifact keys, and
   stage-local filenames. `test/pipeline/run.jl` verifies that Epsilon's
   supported stage directories match Abacus and that Stage `00` metadata
   artifacts use the Abacus-compatible names and manifest keys.
10. `test/pipeline/run.jl` now also verifies Abacus Stage `20` fit and Stage
    `30` assessment artifact keys for the bounded `timeseries` pipeline. The
    Abacus `idata` key maps to Epsilon's Julia-native grouped
    `InferenceResults` artifact rather than a fake NetCDF file; Stage `30`
    emits posterior predictive summaries and fit/residual diagnostic plots
    under Abacus-compatible names.
11. `test/pipeline/run.jl` now verifies Abacus Stage `35` holdout validation,
    Stage `40` decomposition, Stage `50` diagnostics, Stage `60` response
    curves, and enabled Stage `70` optimization artifact keys for the bounded
    `timeseries` pipeline. Abacus NetCDF/PyMC-specific artifacts are mapped to
    Epsilon's Julia-native serialized artifacts where the stage semantics
    match, with CSV/JSON/text/PNG reports emitted under Abacus-compatible
    manifest keys.
12. `test/pipeline/run.jl` now verifies the exported Abacus `geo_panel`
    pipeline contract against Epsilon's panel-aware Stage `00` metadata
    artifacts, Stage `20` fit artifacts, Stage `30` assessment artifacts, and
    Stage `40` decomposition artifacts, Stage `50` diagnostics artifacts, plus
    Stage `60` response-curve artifacts.
    The Abacus `idata` key maps to Epsilon's Julia-native grouped
    `InferenceResults` artifact, with a saved `PanelMMM`, posterior summary
    CSV, trace plot, panel-aware observed/fitted/residual tables, posterior
    predictive summaries, and assessment plots emitted under Abacus-compatible
    keys. The Stage `40` Abacus contribution keys map to typed Julia-native
    `ContributionResults` and `DecompositionResults` artifacts, panel-aware
    contribution/decomposition summaries, baseline/channel contribution CSVs,
    and decomposition/media contribution plots. The Stage `50` diagnostics keys
    map to panel-aware design reports, chain/MCMC diagnostics, predictive and
    residual diagnostics, VIF reports, and residual ACF plots. Stage `60`
    response, saturation, adstock, and metric artifacts use the accepted
    panel-cell `delta_grid` historical-scaling semantics; unsupported later
    panel stages are skipped rather than silently treated as time-series stages.
13. `test/pipeline/run.jl` now verifies the exported Abacus
    `geo_brand_panel` pipeline contract against Epsilon's multidimensional
    panel Stage `00` metadata artifacts, Stage `20` fit artifacts, and Stage
    `30` assessment artifacts, Stage `40` decomposition artifacts, and Stage
    `50` diagnostics artifacts, plus Stage `60` response-curve artifacts,
    including `("geo", "brand")` panel coordinate metadata round trips,
    Julia-native grouped `InferenceResults` artifacts, panel-aware assessment
    CSV/plot artifacts, and multidimensional panel contribution summaries under
    Abacus-compatible keys, diagnostics design summaries that preserve declared
    panel dimensions, and response-curve summaries that retain flat panel names
    plus `geo`/`brand` coordinate columns.
14. `test/pipeline/run.jl` now verifies `geo_panel` Stage `70`
    historical-share optimization artifacts. The optimizer emits a typed
    `PanelBudgetOptimizationResult`, channel-level Abacus-compatible budget
    artifacts, and panel-specific coordinate, channel-panel allocation, panel
    response, and channel-delta audit tables. The policy deliberately preserves
    historical within-channel panel-cell shares; free panel allocation and
    panel-total constraints fail explicitly.
15. `test/pipeline/run.jl` also now verifies `geo_brand_panel` Stage `70`
    historical-share optimization artifacts. The same bounded policy applies to
    multidimensional panel-cell axes: the loaded
    `PanelBudgetOptimizationResult` reports
    `panel_allocation_mode = :historical_shares`, and the emitted
    `channel_panel_allocation.csv` and `channel_delta_audit.csv` retain the
    flat panel names plus `geo`/`brand` coordinate columns; optimized
    channel-panel spend sums back to the optimized channel total.
16. Stage `35` panel holdout validation is explicitly deferred for v1. The
    project keeps the existing time-series blocked holdout validation path, but
    does not add panel holdout validation without a concrete methodological
    requirement and a separate fixture-backed contract.
17. The optional Stage `05` prior-sensitivity planning surface is implemented
    for pipeline configs. Epsilon mirrors Abacus's bounded planning behavior:
    `prior_sensitivity` is runner-only YAML, `manual` and `conservative_mmm`
    policies resolve to scenario `config.resolved.yaml` files, and the stage
    writes `scenario_manifest.yaml` plus `llm_safe_scenario_manifest.yaml`
    without fitting every scenario automatically.

## Plan 14-05 Parity Audit

Plan `14-05` is closed on the bounded Abacus parity-recovery surface.

- `timeseries`: Stage `00` through Stage `70` artifact-key parity is covered,
  including Stage `35` blocked holdout validation and enabled Stage `70`
  optimization, with Julia-native serialized artifacts used where Abacus emits
  PyMC/NetCDF-specific files.
- `geo_panel`: Stage `00`, Stage `20`, Stage `30`, Stage `40`, Stage `50`,
  Stage `60`, and explicitly enabled Stage `70` historical-share optimization
  artifact parity are covered. Stage `35` panel holdout validation is
  explicitly deferred for v1.
- `geo_brand_panel`: Stage `00`, Stage `20`, Stage `30`, Stage `40`, Stage
  `50`, Stage `60`, and explicitly enabled Stage `70` historical-share
  optimization artifact parity are covered, including flattened
  multidimensional panel-cell axes and `geo`/`brand` coordinate metadata in
  panel optimization artifacts. Stage `35` panel holdout validation is
  explicitly deferred for v1.
- AI advisor and Plotly Dash/dashboard parity remain deferred.
- Stage `05` prior-sensitivity planning is now covered; automatic
  multi-scenario fitting and comparison remain outside that bounded stage.
- Free channel-by-panel optimization, panel-total bounds, fairness constraints,
  weighted objectives, and aggregate panel budget semantics remain deferred
  until there is a separate validity contract.

## Immediate Next Slice

Now that Plan `14-05` is closed:

1. Expand scenario planner semantics only where the next slice has a concrete
   non-UI planning contract, such as manual-allocation response evaluation or
   saved scenario-store artifacts. Automatic prior-sensitivity scenario
   fitting/comparison remains outside the bounded Stage `05` planning
   contract.
2. Keep free channel-by-panel allocation, aggregate panel budget allocation,
   panel-total bounds, and fairness/weighted objectives out of the pipeline
   until those semantics have explicit validity contracts.
3. Keep AI advisor plus dashboard/Dash parity deferred.
