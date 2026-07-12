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
  for now. Current explicit deferrals are variational inference v1 support, AI
  advisor, and Dash/dashboard parity.

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
| Package identity and public exports | `abacus/__init__.py`, `abacus/version.py` | `src/Epsilon.jl`, `docs/src/api.md`, `test/api_exports.jl`, `.planning/API-EXPORT-TRIAGE.md`, `.planning/API-EXPORT-CLEANUP-RFC.md` | scaffolded | Current exports are inventoried, documented, lifecycle-triaged, and backed by a small candidate-only cleanup RFC for selected validation helpers. Six validation-helper candidates now emit runtime deprecation warnings on direct public calls while constructors, loaders, and payload builders use warning-free helpers. Guard tests prevent silent inventory drift, require non-empty rendered docstrings plus exact Documenter `@docs` membership, keep lifecycle triage aligned with the inventory, and keep `deprecation-candidate` rows matched to RFC migration text. This is governance/runtime-warning hygiene only, not export removal and not Abacus behavioural evidence; export removals and stronger Abacus API compatibility claims remain future work. |
| YAML/public builder | `abacus/mmm/builders/*.py`, `abacus/pipeline/config.py` | `src/model/config.jl`, `src/model/builder.jl`, `src/pipeline/config.jl` | scaffolded | Build config-normalization fixtures from Abacus demo configs and compare the resolved typed spec. |
| Data validation and preprocessing | `abacus/mmm/preprocessing.py`, `abacus/mmm/validating.py`, `abacus/mmm/models/panel_data.py` | `src/model/types.jl`, `src/model/builder.jl`, `src/mmm/media.jl`, `src/mmm/panel.jl` | scaffolded | `PanelAxis`, `PanelCoordinate`, `panel_axis`, and `panel_coordinates` expose deterministic flat `panel_cell` reconstruction for one-dimensional and multidimensional panels, with declared coordinate columns kept in model order. `ntime`, `npanels`, and `npanel_observations` make panel observation semantics explicit while `nobs(::PanelMMMData)` remains the compatibility flat panel-cell count. Add remaining fixtures for date ordering, channel/control columns, missingness, panel keys, and holdout splits. |
| Scaling | `abacus/mmm/scaling.py`, `abacus/mmm/preprocessing.py` | `src/transforms/scaling.jl`, `src/mmm/controls.jl` | ported | Keep parity tests tied to Abacus fixture exports; extend to panel-scaled tensors. |
| Convolution | `abacus/mmm/transforms/convolution.py` | `src/transforms/convolution.jl` | ported | Keep as low-level fixture gate for all adstock work. |
| Adstock transforms | `abacus/mmm/components/adstock.py`, `abacus/mmm/transforms/adstock.py` | `src/transforms/adstock.jl` | ported | Verify no-adstock and panel tensor behavior against Abacus. |
| Saturation transforms | `abacus/mmm/components/saturation.py`, `abacus/mmm/transforms/saturation.py` | `src/transforms/saturation.jl` | scaffolded | `centered_logistic_saturation` is the explicit Epsilon name for the existing zero-baselined logistic-family curve; `logistic_saturation` remains a legacy alias. Continue auditing coverage for inverse-scaled logistic, baselined tanh, sigmoid hill, root, and no-saturation variants. |
| Prior schema and distribution mapping | `abacus/prior.py`, `abacus/model_config.py` | `src/distributions/priors.jl` | scaffolded | Compare parsed prior configs, defaults, dimensions, and parameter names from demo configs. |
| Special priors | `abacus/special_priors/*.py` | `src/distributions/special.jl`, `src/distributions/masked.jl`, `src/distributions/shrinkage.jl` | scaffolded | Prove log-density and coefficient-helper parity or document Julia-native replacements. |
| Fourier seasonality | `abacus/mmm/fourier.py` | `src/mmm/seasonality.jl` | scaffolded | Add basis-matrix fixtures with dates from demo data. |
| HSGP and time-varying parameters | `abacus/mmm/hsgp.py`, `abacus/mmm/tvp.py` | `src/mmm/hsgp.jl`; future `src/mmm/tvp.jl` | missing | Phase 36 adds only a bounded programmatic TimeSeriesMMM MCMC shared media multiplier. Abacus evidence is explicitly enabled PanelMMM boolean-path placement only; Epsilon separately covers its own runtime, likelihood, retained-grid replay, and trusted-local serialisation state. Generic HSGP, TVP, panels, YAML/pipeline, and HSGP postmodel calculations remain separate work. |
| Linear and changepoint trend | `abacus/mmm/linear_trend.py` | `src/mmm/trend.jl` | scaffolded | Compare trend design matrices and fitted prediction-state replay. |
| Events and holiday basis effects | `abacus/mmm/events.py`, `abacus/mmm/builders/holidays.py` | `src/mmm/events.jl`, `src/mmm/holidays.jl` | scaffolded/native | Separate Abacus-compatible event basis from Epsilon-native pooled holiday behavior. |
| Additive effects | `abacus/mmm/additive_effect.py`, `abacus/mmm/models/panel_build.py` | `src/mmm/model.jl`, `src/postmodel/replay.jl` | scaffolded | Lock contribution-term naming and additive replay state. |
| Target types and efficiency metrics | `abacus/mmm/target.py`, `abacus/metrics.py` | `src/postmodel/metrics.jl`, `src/optimization/summary.jl` | scaffolded | Port target-type normalization and ROAS/CPA label semantics. |
| Time-series MMM | `abacus/mmm/panel.py` with no panel dims | `src/mmm/model.jl`, `src/inference/mcmc.jl` | scaffolded | Make `timeseries` demo the first vertical acceptance target. |
| Panel MMM, one dimension | `abacus/mmm/panel.py`, `abacus/mmm/models/*.py` | `src/mmm/panel.jl` | ported | `geo_panel` config/model semantics and deterministic replay are covered by validation fixtures; continue extending downstream panel artifacts separately. |
| Multi-dimensional panel MMM | `abacus/mmm/panel.py`, `abacus/mmm/models/panel_types.py` | `src/mmm/panel.jl`, `src/model/types.jl`, `src/postmodel/replay.jl` | scaffolded | `geo_brand_panel` config/data, flattened panel ordering, model-spec metadata, runtime artifact schema, deterministic contribution/decomposition replay, and panel-cell response/metric summaries are covered by validation fixtures; Stage `70` historical-share optimization is implemented for `PanelMMM` and fixture-backed for both `geo_panel` and `geo_brand_panel`. |
| Hierarchical pooling through priors | `abacus/mmm/panel.py`, `abacus/prior.py` | `src/mmm/panel.jl`, `src/distributions/priors.jl` | scaffolded | Ensure pooling is encoded through priors, not implicit panel defaults. |
| Mundlak / correlated random effects | Abacus panel/model code and docs | none | missing | Port only after panel-indexed baseline is stable. |
| Calibration and lift tests | `abacus/mmm/lift_test.py`, `abacus/mmm/calibration/*.py`, `abacus/mmm/builders/calibration.py` | `src/mmm/calibration.jl` | scaffolded | Fixture-backed schema, alignment, monotonicity, scaling, and likelihood-term math (`CalibrationStepConfig`, `exact_row_indices`, `assert_monotonic_lift`, `scale_channel_lift_measurements`, `scale_target_for_lift_measurements`, `scale_lift_measurements`, `lift_test_likelihood_terms`, `cost_per_target_penalties`) are implemented and fixture-tested. Phase 15 has landed the bounded `TimeSeriesMMM` MCMC integration: typed calibration payloads thread through construction, fitting, artifact traceability, VI rejection, and serialization; `_time_series_mmm_model` adds optional independent `Turing.@addlogprob!` terms for centered-logistic lift-test calibration and cost-per-target soft penalties; and fixture-backed integration evidence verifies the accepted combined path against Abacus scaling/graph-helper semantics and a conditioned Turing logjoint. Phase 17 now parses bounded public dict/YAML `calibration` blocks into the existing `TimeSeriesCalibrationInput` payload under `ModelConfig.extras["calibration"]` and threads that parsed payload into `TimeSeriesMMM` construction and bounded time-series MCMC pipeline fitting. Both calibration terms are additive, optional, and scaled into model space. Status deliberately remains `scaffolded` because this ledger row covers more than the implemented bounded slice: `PanelMMM` calibration, VI calibration, broader lift-test saturation families, Dash/UI workflows, and AI-advisor behaviour remain unsupported or deferred until separate contracts exist. |


| Fitting and sampler config | `abacus/modeling/base.py`, `abacus/pytensor/sampling.py` | `src/inference/mcmc.jl`, `src/model/config.jl` | scaffolded | Compare sampler config parsing and saved fit metadata; numerical posterior equality is not required. |
| Variational inference | Abacus/PyMC ADVI surfaces | `VariationalConfig`, `approximate_fit!` | deferred | Out of scope for v1 release support after Phase 27. Existing Julia exports remain scaffolded pre-v1 review implementation surfaces, not supported release backends and not Abacus parity evidence. |
| Posterior predictive | `abacus/mmm/base.py`, `abacus/mmm/models/panel_predict.py` | `src/model/results.jl`, `src/inference/results.jl` | scaffolded | Make prediction replay consume saved state for train, holdout, and new data. |
| Diagnostics | `abacus/mmm/diagnostics/*.py` | `src/model/diagnostics.jl`, `src/inference/diagnostics.jl`, `src/plotting/diagnostics.jl` | scaffolded | Port design, MCMC, and predictive summary schemas before plot polish. |
| Panel holdout validation | `abacus/pipeline/stages/validation.py` and panel prediction paths | none | deferred | Stage `35` panel validation is not a v1 MMM requirement. Epsilon keeps time-series blocked holdout validation, but defers panel holdout semantics until there is a concrete methodological requirement beyond parity theater. |
| Contribution and decomposition outputs | `abacus/mmm/base.py`, `abacus/mmm/summarization/*.py` | `src/postmodel/contributions.jl`, `src/postmodel/decomposition.jl` | ported | Time-series replay is covered by `test/validation/timeseries_model_replay.jl`; panel replay is covered by `test/validation/geo_panel_model_replay.jl` and `test/validation/geo_brand_panel_model_replay.jl`. Post-model summary derivation now validates the frozen contribution/decomposition axis contracts before emitting tables. |
| Response, saturation, and adstock curves | `abacus/mmm/panel.py`, `abacus/mmm/summarization/curves.py` | `src/postmodel/response_curves.jl` | ported | Time-series response, saturation-only, and adstock-only curves are covered by `test/validation/timeseries_model_replay.jl`; `geo_brand_panel` panel-cell historical-scaling curves are covered by `test/validation/geo_brand_panel_model_replay.jl`. Curve and metric artifacts now validate the `(draw, panel, spend_point)` / `(draw, panel, spend_point, metric)` panel contracts, including `(panel, spend_point)` spend grids and explicit `delta_grid` multipliers. |
| Budget optimization | `abacus/mmm/budget_optimizer.py`, `abacus/mmm/optimization/*.py`, `abacus/mmm/constraints.py` | `src/optimization/*.jl` | scaffolded | Time-series optimization is fixture-backed; `PanelMMM` now supports the bounded v1 historical-share policy: optimize channel totals, reuse panel response curves through shared channel deltas, and preserve within-channel panel-cell spend shares. Free channel-by-panel allocation and panel-total bounds remain deferred. |
| Pipeline runner and artifacts | `abacus/pipeline/*.py`, `abacus/pipeline/stages/*.py` | `src/pipeline/*.jl` | scaffolded | `timeseries` now exports the Abacus pipeline manifest/artifact contract and Epsilon validates Stage `00` through Stage `70` artifact-key parity, using Julia-native serialized artifacts where Abacus uses PyMC/NetCDF-specific files; `geo_panel` and `geo_brand_panel` now cover Stage `00` metadata/manifest parity, Stage `20` fit artifact-key parity, Stage `30` assessment artifact-key parity, Stage `40` decomposition artifact-key parity, Stage `50` diagnostics artifact-key parity, and Stage `60` response-curve artifact-key parity. Both `geo_panel` and `geo_brand_panel` now also cover explicitly enabled Stage `70` historical-share optimization artifacts, with multidimensional `geo`/`brand` coordinate columns preserved in `channel_panel_allocation.csv` for `geo_brand_panel`; other unsupported panel stages are skipped until semantics are fixture-backed. |
| Prior sensitivity | `abacus/prior_sensitivity/*.py`, `abacus/pipeline/stages/prior_sensitivity.py` | `src/pipeline/config.jl`, `src/pipeline/stages.jl` | ported | Bounded Stage `05` prior-sensitivity planning is implemented: manual and `conservative_mmm` scenario configs are resolved to YAML, human and LLM-safe manifests are emitted, and narrow prior plus explicitly gated structure override paths are validated. Automatic refitting/comparison of every scenario is out of this stage's scope. |
| Plotting | `abacus/mmm/plotting/*.py`, `abacus/plot.py` | `src/plotting/*.jl` | native/scaffolded | Keep Julia-native Makie plots; compare data inputs, not exact figure appearance. |
| Scenario planner | `abacus/scenario_planner/*.py` | `src/scenario_planner.jl` | scaffolded | Bounded non-UI planner semantics are started and Phase 18 is closed: typed current/manual/fixed-budget scenario specs, `scenario_plan(result)` tables from solved optimization results, time-series `evaluate_manual_scenario` response evaluation over existing fitted response surfaces, manual-evaluation projection into `ScenarioPlanResult` tables, combined current/manual/optimized projection with artifact mismatch rejection, and local Epsilon/Julia-version-bound `ScenarioStoreArtifact` persistence with CSV inspection sidecars plus compatibility guardrails. Automatic scenario refits, future spend-path simulation, hosted/background scenario stores, pipeline store emission, free channel-by-panel allocation, panel manual allocation, and Dash UI remain deferred. |
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
18. `src/mmm/calibration.jl` and `test/model/calibration.jl` cover a bounded,
    fixture-backed calibration/lift-test schema slice: `CalibrationStepConfig`
    mirrors the Abacus public YAML `calibration` step schema (including the
    `params.dist` YAML restriction); `exact_row_indices` and
    `assert_monotonic_lift` mirror Abacus
    `abacus.mmm.calibration.alignment.exact_row_indices`/`assert_monotonic`;
    `scale_channel_lift_measurements`, `scale_target_for_lift_measurements`,
    and `scale_lift_measurements` mirror
    `abacus.mmm.calibration.scaling`'s pivot/transform/unpivot rescaling
    behavior; and `lift_test_likelihood_terms`/`cost_per_target_penalties`
    reproduce the pure-math ingredients of Abacus
    `abacus.mmm.calibration.graph.add_saturation_observations` (a true Gamma
    observation likelihood, using the confirmed PyMC `mu`/`sigma` ->
    `shape`/`scale` reparameterization) and
    `add_cost_per_target_potentials` (a soft Gaussian penalty). Fixtures are
    exported from `scripts/export_abacus_fixtures.py` into
    `test/fixtures/abacus/calibration_*.jl`,
    `test/fixtures/abacus/lift_test_likelihood_cases.jl`, and
    `test/fixtures/abacus/cost_per_target_cases.jl`, including real
    PyMC-derived `Gamma` log-density values. PyMC/PyTensor-graph-specific
    indexing (`VariableIndexer`, dimension-based model-variable gathering) and
    wiring a calibration likelihood term into `TimeSeriesMMM`/`PanelMMM`
    sampling are an explicit follow-on sub-slice; panel calibration model
    integration is out of scope until that sub-slice lands.
19. Phase 15 Task 15-01 has frozen the time-series calibration model
    integration contract at
    `.planning/phases/15-calibration-likelihood-integration/PLAN.md`
    ("Task 15-01 Frozen Contract"): `TimeSeriesMMM` fit via `fit!` is the only
    accepted integration target; `PanelMMM` and `approximate_fit!` (VI) must
    reject calibration configuration with a clear `ArgumentError`; calibration
    steps and row data enter through a companion internal payload rather than
    a new `ModelConfig` field or `ModelConfig.extras`; only
    `add_lift_test_measurements` and `add_cost_per_target_calibration` remain
    supported; and the first integration slice supports centered logistic
    saturation only, with other saturation types rejected when calibration is
    enabled until they have their own fixture-backed evidence.
20. Phase 15 Task 15-02 has landed typed calibration payloads
    (`LiftTestCalibrationPayload`, `CostPerTargetCalibrationPayload`) in
    `src/mmm/calibration.jl`, reusing the existing `assert_monotonic_lift`,
    `scale_lift_measurements`, and `scale_target_for_lift_measurements`
    helpers rather than duplicating alignment/scaling logic. Both payload
    types validate row-aligned, scaled, positive-`sigma` observations and are
    exported from `src/Epsilon.jl`, with fixture-independent unit tests in
    `test/model/calibration.jl` covering valid construction and malformed
    rejection. Neither payload type is wired into `TimeSeriesMMM`,
    `ModelConfig`, or the Turing sampling model yet; that remains Task 15-03
    onward.
21. Phase 15 Task 15-03 has landed config/spec threading for calibration.
    `TimeSeriesMMM` gained a `calibration` field, populated via new
    `calibration_steps`/`lift_test_data`/`cost_per_target_data` constructor
    keyword arguments, holding a raw (unscaled) `TimeSeriesCalibrationInput`.
    `_fit_time_series_mmm!` resolves that raw input into a scaled
    `MMMCalibrationSpec` via `_resolve_calibration_spec` and attaches it to
    the successful fit artifact; `MMMModelSpec` itself is deliberately
    unchanged. `PanelMMM` rejects calibration keyword arguments with a
    `MethodError` (no such constructor parameters exist on `PanelMMM`), and
    `approximate_fit!` (VI) on a calibrated `TimeSeriesMMM` raises a clear
    `ArgumentError` before sampling. `save_model`/`load_model` round-trip the
    calibration field and default it to `nothing` for old-format payloads
    with no schema version bump required. New tests cover calibrated
    construction, a real Turing NUTS `fit!` smoke test that asserts the
    resolved calibration spec on the artifact, `PanelMMM` rejection,
    save/load round-trip and backward compatibility, and VI rejection; the
    full 3909-test suite passes with these additions and no regressions. The
    resolved calibration spec still has zero effect on posterior inference
    until Task 15-05 wires it into the Turing model's log-density via
    `Turing.@addlogprob!`.
22. Phase 15 Task 15-04 has landed pure, Turing-independent, AD-compatible
    lift-test log-density helpers in `src/mmm/calibration.jl`:
    `lift_test_estimated_lift_ad`, `lift_test_log_density`, and
    `lift_test_payload_log_density`. These operate on already-scaled
    model-space `x`/`delta_x`/`delta_y`/`sigma` values and a caller-supplied
    `saturation_fn`/per-channel sampled parameter vector, reuse the existing
    `lift_test_gamma_distribution` Gamma reparameterization, and preserve the
    saturation-only lift-test calibration contract (no adstock).
    `lift_test_estimated_lift_ad` deliberately avoids the `Float64`-forcing
    behavior of the pre-existing `lift_test_estimated_lift`, so
    `ForwardDiff.Dual`/`ReverseDiff.TrackedReal` values survive through
    `saturation_fn`. `lift_test_payload_log_density` validates
    `LiftTestCalibrationPayload.channel_index` against the supplied
    per-channel parameter vector and raises a clear `ArgumentError` on
    out-of-bounds channel index instead of an opaque `BoundsError`.
    Cost-per-target's helper acceptance criterion was already satisfied by
    the pre-existing `cost_per_target_penalties`/`cost_per_target_total_penalty`
    helpers from Task 15-02, unchanged in this task. New deterministic tests
    in `test/model/calibration.jl` compare helper outputs against the
    existing `ABACUS_LIFT_TEST_LIKELIHOOD_CASES` fixture, cover zero
    estimated lift, non-positive sigma, non-finite inputs, and channel-index
    mismatch, and add a `ForwardDiff`/`ReverseDiff` gradient-agreement smoke
    test. None of these helpers are called from `_time_series_mmm_model` or
    any other Turing model code; calibration still has zero effect on
    posterior inference until Task 15-05 wires a contribution into the
    Turing model via `Turing.@addlogprob!`.
23. Phase 15 Task 15-05 has landed lift-test likelihood integration into
    `_time_series_mmm_model` in `src/mmm/model.jl`. The model now accepts an
    optional `lift_test_payload` keyword; when present, it rejects any
    non-`logistic` `runtime.saturation_type` with a clear `ArgumentError`
    (matching the Task 15-01 frozen contract), then calls the Task 15-04
    pure helper `lift_test_payload_log_density` with
    `centered_logistic_saturation` and the same sampled `lam` vector used by
    the media saturation path, and adds the result via
    `Turing.@addlogprob!`. The helper call is wrapped in a `try`/`catch`
    that converts a domain-rejection `ArgumentError` (raised when NUTS's
    `AutoForwardDiff` gradient probes legitimately visit degenerate
    parameter points during warmup/leapfrog) into a `-Inf` log-density
    contribution rather than aborting sampling. `_fit_time_series_mmm!`
    passes the Task 15-03 resolved `calibration.lift_test` straight through;
    uncalibrated models pass `nothing` and take the exact same code path as
    before this task, preserving byte-for-byte uncalibrated behaviour. An
    earlier draft that added an `isfinite(...) && return` short-circuit
    after `Turing.@addlogprob!` was found to break Turing/DynamicPPL's
    invariant that every model evaluation must execute the same set of `~`
    statements (it caused a `FieldError` when the early-return path skipped
    `beta_controls ~ ...`); the landed implementation always executes every
    subsequent `~` statement regardless of whether the lift-test term is
    finite. New tests in `test/model/builder.jl` add a deterministic
    log-density comparison (via `Turing.DynamicPPL.condition`/`evaluate!!`/
    `getlogjoint`) proving calibrated and uncalibrated model logjoint differ
    by exactly the fixture-backed `lift_test_payload_log_density(...)` term,
    a negative test proving `tanh`-saturation calibration raises
    `ArgumentError` on `fit!`, and a tiny end-to-end MCMC smoke test that
    fits a calibrated `TimeSeriesMMM`. The full test suite passes with these
    additions and no regressions. `PanelMMM` calibration, VI calibration,
    pipeline integration, and cost-per-target `Turing.@addlogprob!` wiring
    remain untouched and out of scope; Task 15-06 covers cost-per-target
    integration next.
24. Phase 15 Task 15-06 has landed cost-per-target soft-penalty integration
    into `_time_series_mmm_model` in `src/mmm/model.jl`, alongside the
    Task 15-05 lift-test term. The model now also accepts an optional
    `cost_per_target_payload` keyword; when present, it calls the existing
    pure helper `cost_per_target_total_penalty` (unchanged from Task 15-02)
    with the payload's `gathered_cpt`, `targets`, and `sigma`, and adds the
    resulting scalar via a second, independent `Turing.@addlogprob!` call. No
    new AD-safe variant of the helper was needed:
    `CostPerTargetCalibrationPayload`'s fields are fixed caller-supplied
    `Float64` data (validated/scaled once at calibration-spec-resolution
    time), never derived from a Turing-sampled parameter, so the helper's
    internal `Float64` casting is safe to reuse directly. Because the term
    never depends on a sampled variable, the added log-density contribution
    is an intentional constant with respect to the parameters being sampled,
    matching the Task 15-01 frozen contract's requirement to avoid any hidden
    dependency on posterior predictive or optimization artifacts. The helper
    call is wrapped in the same `try`/`catch`-to-`-Inf` pattern used for the
    lift-test term, and the model continues to execute every subsequent `~`
    statement unconditionally, with no early return, preserving the Task
    15-05 Turing/DynamicPPL invariant. The lift-test and cost-per-target
    terms are independent and simply additive: enabling both at once sums
    both scalar contributions onto the log-joint with no interaction between
    them. Invalid or non-positive `sigma` is rejected eagerly at
    `CostPerTargetCalibrationRows` construction time (via the existing
    `_positive_float_vector` validator), before any `TimeSeriesMMM`/`fit!`
    call is possible, distinct from the `try`/`catch`-to-`-Inf` pattern that
    instead handles transient domain violations `cost_per_target_total_penalty`
    can raise from otherwise-valid data during NUTS's AD gradient probes. New
    tests in `test/model/builder.jl` add a deterministic log-density
    comparison (using `Turing.DynamicPPL.condition`/`evaluate!!`/
    `getlogjoint` against `ABACUS_COST_PER_TARGET_CASES[1]`) proving the
    calibrated and uncalibrated model logjoint differ by exactly
    `cost_per_target_total_penalty(...)`, a negative test proving
    `CostPerTargetCalibrationRows(...)` itself raises `ArgumentError` for
    non-positive `sigma` at construction time (not `fit!`-time), and a
    combined smoke test that fits a tiny `TimeSeriesMMM` with both
    `add_lift_test_measurements` and `add_cost_per_target_calibration` steps
    configured together, confirming both payload types are present on the
    fit artifact's calibration spec after a real MCMC fit. The full
    `Pkg.test()` suite (3943 tests) passes cleanly with these additions:
    `Pass 3943, Total 3943, 0 failed, 0 errored` (22m11.1s), and
    `src/mmm/model.jl`/`test/model/builder.jl` are Runic-format-clean.
    `PanelMMM` calibration, VI calibration, pipeline integration, and broader
    YAML expansion remain untouched and out of scope.
25. Phase 15 Task 15-07 has landed fixture-backed model-integration evidence
    for the accepted `TimeSeriesMMM` MCMC calibration path. The main exporter
    now writes `test/fixtures/abacus/calibration_integration_cases.jl`, a
    deterministic Julia-literal fixture for a combined centered-logistic
    lift-test plus cost-per-target case. The fixture generator calls real
    Abacus helper surfaces for the comparable semantics:
    `scale_lift_measurements` for original-unit-to-model-space lift data,
    `add_saturation_observations` for the PyMC Gamma lift-test graph
    log-density, and `add_cost_per_target_potentials` for the cost-per-target
    `pm.Potential` contribution. Julia tests consume only the committed
    fixture, with no Python runtime dependency: `test/model/calibration.jl`
    checks the resolved `LiftTestCalibrationPayload`/
    `CostPerTargetCalibrationPayload` values and additive scalar log-density,
    and `test/model/builder.jl` checks that a conditioned
    `_time_series_mmm_model` logjoint differs from the uncalibrated model by
    exactly the fixture's combined term. `test/model/builder.jl` also now
    guards its fixture includes so the file no longer depends on
    `test/model/calibration.jl` running first in the shared `Main` namespace.
    Verification: `PYTHONNOUSERSITE=1 python scripts/export_abacus_fixtures.py`
    completed successfully; existing fixture body outputs were unchanged, but
    the local Abacus checkout is currently at
    `7fd0ef30aacc33c97342d21087c3f3653bb8a74c (dirty)` with unrelated dirty
    files, so the exporter restamped old fixture provenance headers. Those
    header-only changes were reverted as unrelated churn. Touched Julia files
    are Runic-clean, and `make test-model` passed with `Pass 897, Total 897`
    in 8m14.5s. This is evidence for the bounded time-series MCMC path only;
    it does not add panel calibration, VI calibration, pipeline integration,
    broader YAML expansion, Dash/UI parity, or AI-advisor behavior.
26. Phase 15 Task 15-08 closed the documentation and ledger guardrails for the
    bounded calibration slice at the Phase 15 boundary. The calibration docs
    described the supported
    surface as `TimeSeriesMMM` MCMC only, with centered-logistic lift-test
    calibration and cost-per-target soft penalties as optional additive
    scaled-space terms. They also explicitly documented unsupported paths:
    `PanelMMM` calibration, VI calibration, pipeline/YAML ingestion,
    non-logistic lift-test saturation families, Dash/UI workflows, and
    AI-advisor behaviour. `CHANGELOG.md` records the new user-facing
    capability without implying broader Abacus calibration parity. The ledger
    row deliberately remains `scaffolded`: the bounded time-series MCMC slice
    is implemented and fixture-backed, but the row names a wider Abacus surface
    whose panel, VI, pipeline/YAML, and UI behaviours are not yet implemented.
    Phase-closing verification passed with `make check-full`: `Pkg.test()`
    reported `Pass 3969, Total 3969` in 23m42.2s, followed by a successful docs
    build.
27. Phase 16 Task 16-01 started bounded scenario-planner manual-allocation
    evaluation. `evaluate_manual_scenario(results, scenario)` and
    `ManualScenarioEvaluationResult` evaluate one `ManualAllocationScenarioSpec`
    against existing time-series response surfaces by reusing the Phase 8
    response-surface interpolation path. Omitted channels are held at observed
    spend. The slice does not refit a model, solve a new optimization problem,
    simulate future spend paths, add saved/background scenario stores, add
    Dash/UI behaviour, or implement panel manual-allocation semantics. Evidence
    is deterministic and synthetic-surface based in `test/scenario_planner.jl`;
    scoped verification passed with
    `julia --project=. -e 'using Pkg; Pkg.test(; test_args=["scenario_planner"])'`
    reporting `Pass 43, Total 43`.
28. Phase 16 Task 16-02 projected evaluated manual-allocation scenarios into
    scenario-planner tables. `scenario_plan` now accepts one
    `ManualScenarioEvaluationResult` or a vector of them and returns
    `ScenarioPlanResult` totals, channel, allocation, and metadata tables with
    explicit `manual_allocation` rows. The existing solved-optimization
    `scenario_plan(::BudgetOptimizationResult)` output remains backward
    compatible. Combined current/manual/optimized projection, saved scenario
    stores, background jobs, Dash/UI behaviour, automatic refits, and panel
    manual-allocation semantics remain outside this task. Scoped verification
    passed with
    `julia --project=. -e 'using Pkg; Pkg.test(; test_args=["scenario_planner"])'`
    reporting `Pass 67, Total 67`.
29. Phase 16 Task 16-03 added combined current/manual/optimized scenario-plan
    projection. `scenario_plan(result, evaluation)` and
    `scenario_plan(result, evaluations)` accept one solved budget optimization
    result plus compatible already evaluated manual-allocation scenarios and
    return one deterministic `ScenarioPlanResult`. The combined path rejects
    mismatched artifact metadata, model spec, coordinate metadata, objective,
    current spend, current response, and current default efficiency before
    table construction. It reuses existing manual-only and optimizer-only table
    builders and does not fit, reevaluate manual scenarios, or solve a new
    optimization problem. Saved scenario stores, background jobs, Dash/UI
    behaviour, automatic refits, and panel manual-allocation semantics remain
    outside this task. Scoped verification passed with
    `JULIA_PKG_SERVER_REGISTRY_PREFERENCE=eager julia --project=. -e 'using Pkg; Pkg.test(; test_args=["scenario_planner"])'`
    reporting `Pass 88, Total 88`; touched-file Runic and `git diff --check`
    also passed.
30. Phase 16 Task 16-04 closed documentation, changelog, and ledger guardrails
    for the bounded scenario-planner manual-allocation surface. Release docs,
    README status wording, changelog notes, roadmap state, and this ledger now
    describe the supported surface as non-UI time-series manual allocation over
    existing response surfaces, manual table projection, and combined
    current/manual/optimized comparison when compatible artifacts are supplied.
    The same artifacts explicitly keep Dash/UI, hosted/background scenario
    stores, automatic refits, future spend-path simulation, panel manual
    allocation, and free channel-by-panel allocation outside the supported
    surface. The scenario planner row remains `scaffolded` because broader
    Abacus scenario-planner product parity is not implemented. Scoped
    verification passed with targeted scenario-planner tests reporting
    `Pass 88, Total 88`; `make docs` passed with the known non-fatal
    `index.html` size warning; and `git diff --check` passed. The full suite
    was intentionally not run for this documentation closure.
31. Phase 17 Task 17-01 started bounded calibration YAML/pipeline integration
    by parsing public dict/YAML `calibration` blocks into the existing typed
    `TimeSeriesCalibrationInput` payload stored at
    `ModelConfig.extras["calibration"]`. Valid lift-test and cost-per-target
    row blocks construct the same row objects as programmatic callers, while
    unsupported top-level calibration keys, unsupported row keys,
    `params.dist`, repeated methods, missing matching rows, malformed row
    vectors, panel configs, and VI-like fit backends fail closed through
    `ModelConfigError`. The slice deliberately does not yet wire parsed
    calibration into pipeline model construction or fitting; `PanelMMM`
    calibration, VI calibration, non-logistic lift-test calibration, Dash/UI,
    and AI-advisor paths remain unsupported. Scoped verification passed:
    `julia --project=. test/model/config.jl`, targeted Runic on touched Julia
    files, and
    `JULIA_PKG_SERVER_REGISTRY_PREFERENCE=eager julia --project=. -e 'using Pkg; Pkg.test(; test_args=["model"])'`
    reporting `Pass 913, Total 913`.
32. Phase 17 Task 17-02 threaded parsed calibration into time-series
    construction. `TimeSeriesMMM(config, sampler, data)` now consumes
    `ModelConfig.extras["calibration"]` unchanged when constructor calibration
    keywords are absent, rejects ambiguous parsed-plus-keyword calibration with
    `ArgumentError`, and preserves the existing programmatic
    `calibration_steps`/`lift_test_data`/`cost_per_target_data` constructor
    path. `PanelMMM` rejects parsed calibration explicitly. This task still
    does not wire pipeline model construction or fitting. Scoped verification
    passed with `julia --project=. test/model/builder.jl`,
    `julia --project=. test/model/panel.jl`, targeted Runic on touched Julia
    files, and `git diff --check`.
33. Phase 17 Task 17-03 landed bounded pipeline calibration acceptance for the
    time-series MCMC path. Pipeline YAML now accepts a top-level `calibration`
    block and validates `fit.backend` as MCMC/Turing-only. The loader carries
    parsed calibration through `ModelConfig`, and the metadata/fit stages build
    a calibrated `TimeSeriesMMM` through the same constructor path as
    programmatic usage. Panel calibration and VI-like pipeline calibration are
    rejected before fit. The new focused smoke in `test/pipeline/calibration.jl`
    exercises pipeline loading, context scaffolding, metadata construction, and
    the fit stage, then asserts the fitted/saved model artifact carries a
    resolved `MMMCalibrationSpec` with lift-test and cost-per-target payloads.
    Scoped verification passed with `julia --project=. test/pipeline/config.jl`,
    `julia --project=. test/pipeline/calibration.jl`, targeted Runic on touched
    pipeline files, and `git diff --check`.
34. Phase 17 Task 17-04 closed docs, changelog, and ledger guardrails for the
    bounded calibration YAML/pipeline surface. `docs/src/calibration.md` now
    shows the accepted top-level `calibration` YAML shape for time-series MCMC
    configs, states that public dict/YAML parsing resolves into the existing
    `TimeSeriesCalibrationInput` payload, and names the remaining unsupported
    surfaces: `PanelMMM` calibration, VI calibration, non-logistic lift-test
    calibration, automatic row generation from artifacts, Dash/UI workflows,
    and AI-advisor behaviour. `docs/src/index.md` and `CHANGELOG.md` were
    updated to avoid the stale claim that pipeline/YAML ingestion is wholly
    unsupported. The broad calibration ledger row remains `scaffolded` because
    this phase only exposes the already-implemented bounded `TimeSeriesMMM`
    MCMC slice through config and pipeline boundaries. Verification reused the
    targeted model/pipeline tests from Tasks 17-01 through 17-03 and closed the
    docs-only task with `make docs` and `git diff --check`.
35. Phase 18 landed local scenario-store artifacts for the existing bounded
    non-UI scenario-planner surface. `ScenarioStoreArtifact` validates
    `ScenarioPlanResult` tables against trusted `ModelArtifactMetadata`,
    `MMMModelSpec`, and `ModelCoordinateMetadata` inputs; `write_scenario_store`
    writes a typed `scenario_store.jls` payload plus deterministic CSV
    inspection sidecars; `load_scenario_store` restores a validated typed
    artifact; `scenario_store_plan` projects copied tables; and
    `assert_scenario_store_compatible` rejects metadata, spec, coordinate,
    channel-order, objective, and current-baseline mismatches. The store
    contract is local and Epsilon/Julia-version-bound, not a portable or
    untrusted interchange format. Scoped verification passed with targeted
    Runic on `src/scenario_planner.jl`, `src/Epsilon.jl`, and
    `test/scenario_planner.jl`; focused scenario-planner tests reported
    `Pass 129, Total 129`; `make docs` passed with the known non-fatal
    `index.html` size warning and deployment skipped outside CI; and
    `git diff --check` passed. The scenario planner row remains `scaffolded`
    because hosted/background stores, pipeline store emission, automatic
    refits, future spend paths, panel manual allocation, free channel-by-panel
    allocation, and Dash UI remain unsupported.
36. Phase 19 landed public API export hygiene for the package identity/public
    exports row. `docs/src/api.md` defines support bands and inventories the
    200 current loaded exports from `names(Epsilon; all = false, imported =
    false)` with `:Epsilon` removed. `test/api_exports.jl` parses only the
    marked inventory table and rejects missing, duplicate, empty/malformed, or
    stale rows, so future exports require explicit support-status wording.
    `docs/make.jl` now includes the Public API page. The ledger row remains
    `scaffolded`: this is an audit and guardrail, not broad Abacus package/API
    parity, and breaking export cleanup remains future work. Verification
    passed with focused `api_exports` tests
    (`Pass 610, Total 610`), Runic on touched Julia files, `make docs`,
    `git diff --check`, and the phase-closing `make check-full` gate with
    full `Pkg.test()` reporting `Pass 4720, Total 4720` in 21m02.6s followed
    by a successful docs build.
37. Phase 20 landed public API documentation hygiene for the same
    package-identity/public-exports row without changing row status. The
    focused `api_exports` guard keeps the Phase 19 inventory/export exact-match
    checks and now also treats doc lookup failures, `nothing`, and empty
    rendered docs as missing documentation, aggregating failures into sorted
    symbol lists. It scans fenced Documenter `@docs` blocks under `docs/src`
    and requires each current inventoried/exported symbol to appear as an exact
    stripped `Epsilon.<symbol>` line using `String(symbol)`, so names ending in
    `!` are covered. `test/basic.jl` no longer carries a curated public API
    docstring smoke list. This is not Abacus behavioural evidence and does not
    support broader package/API parity claims. Verification passed with
    focused `api_exports` plus `basic` tests (`Pass 1827, Total 1827`),
    Runic on touched Julia files, `make docs`, `git diff --check`, and the
    phase-closing `make check-full` gate with full `Pkg.test()` reporting
    `Pass 5862, Total 5862` in 20m30.2s followed by a successful docs build.
38. Phase 21 landed public API governance hygiene for the same
    package-identity/public-exports row without changing row status. The
    lifecycle triage register at `.planning/API-EXPORT-TRIAGE.md` records one
    row for each of the 200 current loaded exports, copying `Domain` and
    `Support` from `docs/src/api.md` and classifying conservatively as
    `keep-public`, `keep-bounded`, `compatibility`, or `review-before-v1`.
    There are no `deprecation-candidate` rows because no concrete reviewed
    migration path is known. The focused `api_exports` guard now validates the
    triage markers, exact six-column header, duplicate/missing/stale symbols,
    inventory membership, Domain/Support alignment, controlled lifecycle
    values, non-empty rationales, and concrete migration notes for any future
    `deprecation-candidate` rows. This is not Abacus behavioural evidence and
    does not support broader package/API parity claims. Verification passed
    with focused `api_exports` plus `basic` tests (`Pass 3048, Total 3048`),
    Runic on `test/api_exports.jl`, `make docs`, `git diff --check`, and the
    phase-closing `make check-full` gate with full `Pkg.test()` reporting
    `Pass 7083, Total 7083` in 20m56.1s followed by a successful docs build.
39. Phase 22 landed a candidate-only cleanup RFC for the same
    package-identity/public-exports row without changing row status.
    `.planning/API-EXPORT-CLEANUP-RFC.md` marks six exported validation helpers
    as planning-level `deprecation-candidate` rows with concrete migration
    paths to existing constructors, loaders, or payload builders. The focused
    `api_exports` guard now validates the RFC markers, exact seven-column
    header, current/proposed lifecycle cells, no-runtime/export decision text,
    current export and triage membership, one-to-one `deprecation-candidate`
    coverage, and exact migration-text matches against
    `.planning/API-EXPORT-TRIAGE.md`. This is governance/RFC hygiene only; it
    is not runtime deprecation, export removal, or Abacus behavioural evidence.
    Verification passed with focused `api_exports` plus `basic` tests
    (`Pass 3689, Total 3689`), Runic on `test/api_exports.jl`,
    `git diff --check`, and the phase-closing `make check-full` gate with full
    `Pkg.test()` reporting `Pass 7724, Total 7724` in 19m53.1s followed by a
    successful docs build.
40. Phase 24 adds runtime deprecation wrappers for the same
    package-identity/public-exports row without changing row status. Direct
    public calls to the six Phase 22 validation-helper candidates now emit
    `Base.depwarn`, while the supported constructors, loaders, and calibration
    payload builders call warning-free `_validate_*` helpers. This is runtime
    warning hygiene only: `src/Epsilon.jl`, export inventory rows, validation
    predicates, modelling semantics, and Abacus parity evidence are unchanged.
41. Phase 31 adds only the deterministic date-index foundation used before
    Abacus constructs a time-varying HSGP multiplier. The internal
    `_infer_hsgp_time_index` helper is fixture-backed against Abacus
    `infer_time_index` for daily/weekly, forward/backward, leap-boundary, and
    off-cadence cases, while Epsilon deliberately hardens empty training dates
    with `ArgumentError`. It is not exported; HSGP configuration remains
    rejected, and no basis, prior, Turing, prediction, replay, or TVP behaviour
    is implemented. The HSGP/time-varying ledger row therefore remains
    `missing`. Final verification passed with `make test`: `8,488 / 8,488`
    tests in `20m44.6s`.
42. Phase 32 implements the private deterministic one-dimensional HSGP
    geometry foundation: retained Laplacian frequencies, training-range-centred
    fixed bases, ExpQuad/Matern-3/2/Matern-5/2 square-root PSD weights, and
    Abacus-compatible `m`/`c` plus `m`/`L` recommendation heuristics. The
    fixture exporter calls real Abacus helpers and PyMC `prior_linearized`; the
    one-mode/drop-first empty case applies PyMC's equivalent post-construction
    slice because the local PyMC version cannot compile its zero-column graph.
    Extreme finite domains are hardened with explicit `ArgumentError`s and
    focused tests pass `86 / 86`. The helpers remain private, HSGP config stays
    rejected, and no graph, Turing, TVP, prediction, replay, or panel behaviour
    is implemented; the ledger row remains `missing`. Final verification passed
    with `make test`: `8,574 / 8,574` tests in `20m59.8s`.
43. Phase 33 adds only the deterministic numerical composition used by
    Abacus `SoftPlusHSGP` after its coefficients are supplied: latent
    projection `phi * (sqrt_psd .* z)`, the local PyTensor thresholded
    softplus branches, and time-axis mean-one positive normalisation. It is
    fixture-backed against PyMC HSGP geometry and PyTensor softplus for vector
    and matrix coefficients, including exact zero-retained-mode ones and
    explicit all/partial Float64-underflow rejection before division. The
    helpers remain private; HSGP configuration stays rejected, and no prior,
    graph, Turing, TVP, prediction, replay, or panel behaviour is implemented.
    The HSGP/time-varying ledger row therefore remains `missing`. Focused
    verification passed `46 / 46`; the phase-closing `make test` checkpoint
    passed `8,620 / 8,620` in `20m24.2s`.
44. Phase 34 adds only private fitted-state replay for one concrete HSGP
    positive-multiplier coefficient draw. It snapshots weighted coefficients,
    training basis centre, optional training basis de-meaning offset, and the
    training raw-softplus mean immutably, then reuses those values for finite
    prediction coordinates rather than prediction-local recentering or
    renormalisation. Fixtures exercise Abacus SoftPlusHSGP's mutable-data,
    saved-mean replay path; Epsilon additionally rejects mutable/malformed
    state and prediction-only softplus underflow. There is still no HSGP prior,
    graph, Turing, configuration, public API, serialization, model prediction,
    panel, or TVP support, so the HSGP/time-varying row remains `missing`.
    Focused verification passed `58 / 58`; the phase-closing `make test`
    checkpoint passed `8,678 / 8,678` in `20m57.0s`.
45. Phase 35 records the independently reviewed methodological contract for a
    future TimeSeriesMMM-only shared HSGP media multiplier. It fixes multiplier
    placement, cadence units, scalar positive-prior rules, non-centred Turing
    variable identity, immutable training date/index state, prediction replay,
    schema-v2 migration, and explicit rejections for panels, intercepts,
    Michaelis-Menten, calibration, and YAML. It is planning only: no runtime
    behaviour or parity status changed, and the HSGP/time-varying row remains
    `missing` until Phase 36 implementation evidence lands.
46. Phase 36 implements the bounded programmatic TimeSeriesMMM MCMC shared
    media multiplier only. Its immutable scalar-prior and retained
    date/cadence/geometry state is sampled and replayed in Epsilon's own
    runtime, likelihood, and prediction paths; model envelopes now use a
    discriminator-only v2 validation layer after trusted-local Julia
    deserialisation, while shared result/inference schemas remain v1. The
    explicit Abacus evidence is limited to enabled PanelMMM boolean-path
    placement, not an aggregate joint or generic product-parity claim. YAML,
    pipeline, panels, VI, calibration, Michaelis-Menten,
    channel-specific/intercept/multidimensional/periodic HSGP, TVP, and HSGP
    postmodel calculation routes remain unsupported, so the combined HSGP/TVP
    ledger row remains `missing`.


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

1. Treat the Phase 16 scenario-planner manual-allocation surface as closed.
   Any further scenario-planner expansion, including saved scenario-store
   artifacts, background jobs, future-path simulation, or automatic refits,
   needs a separate non-UI planning contract first. Automatic
   prior-sensitivity scenario fitting/comparison remains outside the bounded
   Stage `05` planning contract.
2. Keep free channel-by-panel allocation, aggregate panel budget allocation,
   panel-total bounds, and fairness/weighted objectives out of the pipeline
   until those semantics have explicit validity contracts.
3. Keep AI advisor plus dashboard/Dash parity deferred.
