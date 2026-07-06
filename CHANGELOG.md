# Changelog

All notable project changes are recorded here. Epsilon is still on the
`0.1.0-dev` line, so entries are grouped under `Unreleased`.

## Unreleased

### Added

- Added `centered_logistic_saturation(x, lam)` as the explicit public name for
  Epsilon's zero-baselined logistic-family saturation curve,
  `tanh(lam * x / 2)`.
- Added `PanelAxis`, `panel_axis`, `panel_axes`, `PanelCoordinate`,
  `panel_coordinates`, and `panel_coordinate` helpers for recovering ordered
  named `PanelMMM` coordinates from Epsilon's deterministic flat `panel_cell`
  axis.
- Added `ntime`, `npanels`, and `npanel_observations` helpers so panel code can
  distinguish shared time rows, flat panel cells, and flattened panel-cell
  observations explicitly.
- Added fixture-backed Abacus pipeline artifact-key parity for the bounded
  `timeseries` Stage `00` through Stage `70` surface.
- Added Abacus-compatible pipeline artifact keys for Stage `35` holdout
  validation, Stage `40` decomposition, Stage `50` diagnostics, Stage `60`
  response curves, and enabled Stage `70` optimization.
- Added Julia-native serialized artifact equivalents for Abacus PyMC/NetCDF
  outputs where the stage semantics match but file-format identity would be
  misleading.
- Added stricter pipeline tests that assert exported Abacus manifest
  artifact-key sets are present in Epsilon stage manifests and that all mapped
  artifacts exist.
- Added Phase 14 handoff state for resuming with `geo_panel` pipeline Stage
  `00` metadata/manifest parity.
- Added fixture-backed `geo_panel` pipeline Stage `00` metadata/manifest
  parity and Stage `20` fit artifact-key parity, including panel-aware
  dataset/model metadata, Julia-native fit artifacts, posterior summaries,
  trace plots, and explicit skipped unsupported panel pipeline stages.
- Added fixture-backed `geo_brand_panel` pipeline Stage `00` metadata/manifest
  parity and Stage `20` fit artifact-key parity for multidimensional panel
  configs, including flattened panel-cell metadata, coordinate round trips, and
  Julia-native fit artifacts under Abacus-compatible manifest keys.
- Added fixture-backed `geo_panel` and `geo_brand_panel` pipeline Stage `30`
  assessment artifact-key parity, including panel-aware observed/fitted,
  residual, posterior predictive summary, and assessment plot artifacts.
- Added fixture-backed `geo_panel` and `geo_brand_panel` pipeline Stage `40`
  decomposition artifact-key parity, including Julia-native contribution and
  decomposition result artifacts, panel-aware contribution/decomposition
  summaries, Abacus-compatible baseline/channel/mean contribution CSVs, and
  decomposition/media contribution plots.
- Added fixture-backed `geo_panel` and `geo_brand_panel` pipeline Stage `50`
  diagnostics artifact-key parity, including panel-aware design reports,
  chain/MCMC diagnostics, predictive diagnostics, residual diagnostics, VIF
  reports, and residual ACF plots.
- Added fixture-backed `geo_panel` and `geo_brand_panel` pipeline Stage `60`
  response-curve artifact-key parity, including panel-cell historical-scaling
  response, saturation, adstock, and metric artifacts under Abacus-compatible
  curve keys.
- Added bounded `PanelMMM` Stage `70` optimization support for channel-level
  budget allocation with fixed historical within-channel panel-cell shares,
  including `PanelBudgetOptimizationResult`, panel allocation/audit artifacts,
  explicit errors for deferred free channel-by-panel constraints, and
  fixture-backed `geo_panel` pipeline artifact-key coverage.
- Extended fixture-backed `geo_brand_panel` pipeline Stage `70` historical-share
  optimization coverage, asserting that the existing bounded
  `panel_allocation_mode = :historical_shares` policy preserves flattened
  multidimensional panel-cell axes and `geo`/`brand` coordinate metadata in the
  emitted `channel_panel_allocation.csv` and `channel_delta_audit.csv`
  artifacts.
- Added bounded Abacus-compatible Stage `05` prior-sensitivity planning to the
  pipeline. The stage parses runner-only `prior_sensitivity` YAML, writes
  resolved manual or `conservative_mmm` scenario configs, emits human and
  LLM-safe manifests, and validates narrow prior/selected model-structure
  override paths without fitting every scenario automatically.
- Added the first bounded non-UI scenario-planner surface: typed current,
  manual-allocation, and fixed-budget optimized scenario specs plus
  `scenario_plan(result)` comparison tables over solved time-series and panel
  budget optimization results. The surface mirrors Abacus's reusable business
  planning store shape without Dash UI, background jobs, automatic scenario
  refits, or free channel-by-panel allocation.
- Added bounded `TimeSeriesMMM` MCMC calibration likelihood support for
  centered-logistic lift-test measurements and cost-per-target soft penalties.
  The two calibration terms are optional and additive, resolve into scaled
  model space, and are fixture-backed against comparable Abacus preprocessing
  and log-density helpers. `PanelMMM` calibration, VI calibration, broader
  saturation-family calibration, Dash/UI workflows, and AI-advisor behaviour
  remain unsupported.
- Added bounded public dict/YAML parsing for top-level `calibration` blocks:
  valid lift-test and cost-per-target row payloads now resolve into the
  existing typed `TimeSeriesCalibrationInput` under
  `ModelConfig.extras["calibration"]` and are consumed by `TimeSeriesMMM`
  construction and the bounded time-series MCMC pipeline fit path. Panel
  calibration, VI calibration, non-logistic lift-test calibration, Dash/UI
  workflows, and AI-advisor behaviour remain unsupported.
- Added the first evaluated manual-allocation scenario-planner contract:
  `evaluate_manual_scenario(results, scenario)` and
  `ManualScenarioEvaluationResult` evaluate one `ManualAllocationScenarioSpec`
  against existing time-series response surfaces without refitting, solving a
  new optimization problem, adding Dash/UI workflow, or introducing panel
  manual-allocation semantics.
- Extended `scenario_plan` so one or more evaluated manual-allocation scenarios
  project into `ScenarioPlanResult` totals, channel, allocation, and metadata
  tables with explicit `manual_allocation` scenario rows while preserving the
  existing solved-optimization table contract.
- Extended `scenario_plan` again so compatible evaluated manual-allocation
  scenarios and one solved fixed-budget optimization result can be projected
  into one deterministic current/manual/optimized `ScenarioPlanResult`, with
  hard artifact and baseline mismatch rejection before table construction.
- Added local non-UI scenario-store artifacts for existing
  `ScenarioPlanResult` tables: `write_scenario_store` writes a typed
  `scenario_store.jls` payload plus CSV inspection sidecars,
  `load_scenario_store` restores a validated `ScenarioStoreArtifact`,
  `scenario_store_plan` projects copied tables, and
  `assert_scenario_store_compatible` rejects incompatible stores. This is a
  local Epsilon/Julia-version-bound artifact contract, not Dash/UI, hosted
  stores, background jobs, automatic refits, future spend simulation, pipeline
  emission, or panel manual allocation.
- Added a public API support-status inventory in the docs plus a focused
  `api_exports` test layer that compares the marked inventory table against
  the loaded `Epsilon` module export surface.
- Added a public API documentation guard to the focused `api_exports` test
  layer. The guard now requires every inventoried/exported symbol to have a
  non-empty rendered docstring and an exact `Epsilon.<symbol>` entry in a
  Documenter `@docs` block under `docs/src`, including bang-suffixed names.
- Added a guarded public API lifecycle triage register at
  `.planning/API-EXPORT-TRIAGE.md`, plus focused `api_exports` checks that keep
  every current export's triage row aligned with the documented inventory. This
  is pre-v1 governance hygiene only, not an export cleanup or Abacus API parity
  claim.
- Added a candidate-only public API cleanup RFC at
  `.planning/API-EXPORT-CLEANUP-RFC.md`, marking a small set of exported
  validation helpers as planning-level `deprecation-candidate` rows with
  concrete migration paths and focused RFC/register consistency checks. This
  does not remove exports, add runtime deprecation warnings, or change Abacus
  behavioural evidence.
- Added a marked migration-readiness audit for those six deprecated validation
  helpers, plus focused `api_exports` checks that keep the audit aligned with
  current exports, the triage register, the Phase 22 RFC, and the Phase 23/24
  runtime-deprecation design. The audit records runtime warnings and
  warning-free replacements as guarded while keeping every helper not ready to
  unexport.
- Added a design-only runtime deprecation plan at
  `.planning/API-RUNTIME-DEPRECATION-DESIGN.md` for those six validation-helper
  candidates. It records the future wrapper/internal-helper split, warning
  text, tests, and rollback criteria needed before any runtime warning can
  safely land; it does not change exports or runtime behaviour.
- Added focused package-test file selectors to `test/runtests.jl`, so commands
  such as `Pkg.test(; test_args=["test/model/calibration.jl"],
  julia_args=["--depwarn=yes"])` run one test file inside the package test
  environment with test-only dependencies available.
- Added `make test-file FILE=...` as the local helper for focused package-test
  file execution.
- Added `examples/toy_mmm/run_toy_mmm.jl`, a tiny synthetic `TimeSeriesMMM`
  Turing/NUTS MCMC smoke demo with a callable `run_toy_mmm` entry point,
  compact optional CSV/text summaries, and focused test coverage under
  `test/examples/toy_mcmc_smoke.jl`. This is a supported-path smoke demo only,
  not release evidence, not a benchmark, not an Abacus parity claim, and not a
  broader support expansion.
- Documented the bounded calibration YAML/pipeline surface with the supported
  top-level `calibration` shape and explicit unsupported paths for panel
  calibration, VI calibration, non-logistic lift-test calibration, Dash/UI
  workflows, and AI-advisor behaviour.

### Changed

- Reconciled the v1 release boundary after Phase 27: release-facing docs and
  planning state now make MCMC/Turing the only v1-supported inference path,
  with variational inference, dashboard/UI parity, and AI advisor behaviour
  explicitly out of scope for v1. `VariationalConfig` and `approximate_fit!`
  remain scaffolded pre-v1 review exports; this change does not remove exports,
  add runtime warnings, or change model semantics.
- Deprecated the six exported validation-helper candidates at runtime while
  preserving exports and validation semantics. Direct public calls to
  `validate_calibration_step_config`,
  `validate_lift_test_calibration_payload`,
  `validate_cost_per_target_calibration_payload`, `validate_sampler_config`,
  `validate_model_config`, and `validate_mmm_data` now emit `Base.depwarn`;
  supported constructors, loaders, and payload builders use warning-free
  internal helpers.
- Fixed Phase 13 remediation issues: fitted time-series trend and automatic
  holiday date-basis state is now serialized in model specs and reused for
  prediction/replay, unfitted time-series prior prediction resolves scale and
  date-derived feature state from the model's training data, media/channel
  inputs are rejected when negative, `hill_function` now raises a clear
  `ArgumentError` for negative `x`, and pipeline YAML now rejects unknown
  top-level keys instead of silently ignoring typoed run blocks.
- Routed the existing `media.saturation.type = "logistic"` model path through
  `centered_logistic_saturation` while keeping `logistic_saturation` as a
  documented legacy compatibility alias. This preserves fitted-model numerical
  behavior while avoiding a misleading primary API name.
- Clarified that `nobs(::PanelMMMData)` remains the compatibility flattened
  panel-cell observation count for existing model-spec and pipeline artifact
  contracts; use `ntime` and `npanels` for separate panel axes.
- Updated panel contribution, curve, metric, and budget-allocation summaries to
  carry an explicit `panel_cell` column plus declared panel-coordinate columns;
  the legacy multidimensional `panel` column is retained as a compatibility
  alias.
- Locked post-model result axis contracts for contribution, decomposition,
  response, saturation, adstock, and metric artifacts. `summary_table` and
  `metric_results(::ResponseCurveResults)` now validate expected draw, panel,
  spend-point, component, and metric axes before deriving tidy tables or
  downstream metrics.
- Consolidated the shared response, saturation, and adstock curve construction
  path so time-series and panel curve entrypoints use one internal
  `InferenceResults`-to-result builder while preserving the existing replay
  math and public API.
- Updated Phase 14 documentation and planning state to treat `timeseries`
  pipeline Stage `00` through Stage `70` artifact-key parity as covered.
- Clarified that panel pipeline parity is currently bounded to Stage `00`
  metadata, Stage `20` fit, Stage `30` assessment, and Stage `40`
  decomposition, Stage `50` diagnostics, and Stage `60` response-curve
  semantics on both `geo_panel` and `geo_brand_panel` before broader panel
  pipeline orchestration.
- Updated the bounded pipeline contract so `PanelMMM` configs can run the
  metadata, fit, assessment, decomposition, diagnostics, and curve stages
  truthfully and can run optimization only when an Epsilon-supported
  `optimization.total_budget` contract is explicitly provided; Abacus panel
  relative-budget blocks are not parsed as time-series pipeline options.
- Documented Stage `35` panel holdout validation as deferred for v1: Epsilon
  keeps time-series blocked holdout validation, but does not add panel holdout
  semantics without a concrete methodological requirement.
- Closed Plan `14-05` with a parity audit: `timeseries` Stage `00` through
  Stage `70` is covered; `geo_panel` and `geo_brand_panel` cover accepted panel
  pipeline stages through explicitly enabled Stage `70` historical-share
  optimization; panel Stage `35` validation, AI advisor, and Dash remain
  outside the closed surface as documented.

### Notes

- Saved the 2026-05-20 handoff after Phase 13 remediation closeout: planning
  state now points future work at release-prep choices after the completed
  Phase 14 evidence spine.
- AI advisor and Plotly Dash/dashboard parity remain deferred.
- Panel Stage `35` validation remains deferred; adding it for parity alone is
  intentionally avoided.
- Scenario planner execution remains bounded to existing optimizer outputs and
  time-series manual-allocation evaluations over existing response surfaces;
  richer scenario simulation, automatic refits, background stores/jobs, panel
  manual allocation, and UI workflows are still outside the current surface.
- Repo-wide `make format-check` still reports pre-existing Runic drift outside
  the Phase 13 remediation slice; targeted Runic checks on the touched Julia
  files passed.
