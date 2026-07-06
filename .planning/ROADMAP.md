# Roadmap: Epsilon MMM

## Overview

Epsilon has moved through thirteen historical implementation phases, but those
phases should no longer be treated as evidence of broad Abacus parity. The
active roadmap is now governed by `.planning/ABACUS-PARITY-LEDGER.md`: each
surface is classified as `ported`, `native`, `scaffolded`, `missing`, or
`deferred`, and release readiness depends on demo-backed acceptance rather than
module presence.

The next milestone is the Abacus statistical and methodological parity recovery
program: first `timeseries`, then `geo_panel`, then `geo_brand_panel`. Each
target must pass config/data, model, posterior replay, post-model,
optimization, and pipeline artifact gates before it can support a release
claim.

## Repository Review Snapshot

Current repository state on 2026-05-18:

- `make test` and `make docs` have passed in prior phase work, but passing the
  existing suite is not sufficient to claim Abacus parity
- the Abacus fixture export/import path is established through
  `scripts/export_abacus_fixtures.py`
- the transform layer has the strongest fixture-backed parity evidence
- prior/distribution, model, inference, post-model, optimization, plotting, and
  pipeline modules exist but need ledger-backed revalidation before broad
  parity claims
- `.planning/ABACUS-PARITY-LEDGER.md` is now the controlling document for the
  next implementation sequence
- Phase 4 is complete:
  - typed model/config/data structs are in place
  - deterministic config merging is in place
  - a runnable Turing-backed `TimeSeriesMMM` exists
  - prior and posterior predictive paths exist
  - model save/load and typed results save/load exist
  - typed diagnostics, convergence reports/warnings, and sampler
    diagnostics/warnings exist
  - richer grouped results export is explicitly deferred to Phase 6
- per-phase execution docs are now in place through
  `.planning/phases/11-validation-and-benchmarks/PLAN.md`
- `.planning/phases/05-mmm-features/PLAN.md` defines the executable Phase 5
  boundary and sequencing
- `.planning/phases/06-inference/PLAN.md` now defines the executable Phase 6
  inference boundary and sequencing
- `.planning/phases/07-post-modeling/PLAN.md` now defines the executable Phase 7
  post-model boundary and sequencing
- `.planning/phases/08-budget-optimization/PLAN.md` now defines the executable
  Phase 8 optimization boundary and sequencing
- `.planning/phases/09-pipeline/PLAN.md` now defines the executable Phase 9
  pipeline boundary and sequencing
- `.planning/phases/10-plotting/PLAN.md` now defines the executable Phase 10
  plotting boundary and sequencing
- `.planning/phases/11-validation-and-benchmarks/PLAN.md` now defines the
  executable Phase 11 validation / benchmark boundary and sequencing
- `.planning/phases/12-parity-remediation/PLAN.md` now defines the executable
  Phase 12 methodology-remediation boundary and sequencing
- `.planning/phases/13-prediction-state-and-contract-remediation/PLAN.md` now
  records completed Phase 13 remediation for fitted trend/holiday prediction
  state, media-domain validation, and pipeline YAML contract hardening
- the Phase 5 seasonality baseline has landed: `TimeSeriesMMM` now supports a
  Fourier seasonality path, and HSGP is not yet implemented on the supported
  Phase 5 surface
- the Phase 5 feature matrix is now frozen with dedicated integration coverage,
  including the first bounded `PanelMMM` path
- Phase 12 `12-01` and `12-02` are landed:
  - the bounded comparable time-series fit path now uses explicit max scaling
  - `channel_scale` / `target_scale` now flow through the typed
    spec/artifact path
  - predictive and replayed public outputs are reconstructed in original units
  - Stage 60 now exposes explicit forward-pass, saturation-only, and adstock
    curve families with per-channel pipeline artifacts and plotting consumers
- the targeted methodology audit is now closed on the bounded v1 surface:
  - Stage 70 optimization semantics are reverified on the repaired
    original-scale contract
  - the holiday/trend/seasonality contract is frozen around the coherent
    native pooled automatic holiday design
  - the final validation harness now distinguishes the guaranteed
    Abacus-reference row from the bounded holiday-bearing Epsilon-native row
  - release-facing docs are reconciled to the narrowed reference claim
- Abacus remains the main external reference and comparison baseline for the
  validated MMM statistical and methodological core, but Epsilon should claim
  parity only where a ledger row is backed by fixtures, demo acceptance, or
  explicit native-design documentation
- AI advisor and Plotly Dash/dashboard parity remain explicitly deferred; other
  Abacus statistical and methodological functionality remains in scope unless
  the parity ledger says otherwise
- Phase 14 has rebuilt the demo-backed evidence spine:
  - `timeseries` config/data and deterministic replay gates are accepted
  - `geo_panel` config/model/replay gates are accepted for deterministic replay
  - `geo_brand_panel` multidimensional config/model/contribution/decomposition
    replay and panel-cell response/metric semantics are accepted
  - `timeseries` pipeline Stage `00` through Stage `70` artifact-key parity is
    validated against the exported Abacus manifest contract, with Julia-native
    serialized artifacts used where Abacus emits PyMC/NetCDF-specific files
  - `geo_panel` pipeline Stage `00` metadata/manifest parity, Stage `20` fit
    artifact-key parity, Stage `30` assessment artifact-key parity, and Stage
    `40` decomposition artifact-key parity, and Stage `50` diagnostics
    artifact-key parity, and Stage `60` response-curve artifact-key parity are
    accepted with unsupported panel stages explicitly skipped; Stage `70`
    historical-share optimization is now implemented for `geo_panel` as a
    channel-total allocation surface that preserves within-channel panel-cell
    spend shares, with Stage `35` panel validation deferred
  - `geo_brand_panel` pipeline Stage `00` metadata/manifest parity, Stage `20`
    fit artifact-key parity, Stage `30` assessment artifact-key parity, and
    Stage `40` decomposition artifact-key parity, and Stage `50` diagnostics
    artifact-key parity, Stage `60` response-curve artifact-key parity, and
    explicitly enabled Stage `70` historical-share optimization are accepted
    with Stage `35` panel validation deferred
- Plan `14-05` is closed with a parity audit: `timeseries` Stage `00` through
  Stage `70` is covered; `geo_panel` and `geo_brand_panel` cover Stage `00`,
  Stage `20`, Stage `30`, Stage `40`, Stage `50`, Stage `60`, and explicitly
  enabled Stage `70` historical-share optimization; panel Stage `35` holdout
  validation is deferred for v1; AI advisor and Dash remain deferred
- optional Stage `05` prior-sensitivity planning is now implemented as a
  bounded scenario-config and manifest stage, matching Abacus's planning
  semantics without automatically fitting every scenario
- Phase 16 is now closed: the bounded non-UI scenario planner supports typed
  current/manual/fixed-budget specs, solved-optimization comparison tables,
  time-series manual-allocation response evaluation over existing fitted
  response surfaces, manual table projection, and combined
  current/manual/optimized comparison with artifact mismatch rejection. Saved
  scenario stores, automatic scenario refits, future spend-path simulation,
  panel manual allocation, and Dash workflows remain outside the current
  surface
- `centered_logistic_saturation` is the explicit public name for Epsilon's
  zero-baselined logistic-family curve; the older `logistic_saturation` export
  remains a compatibility alias, and `media.saturation.type = "logistic"`
  continues to map to the same fitted-model numerics
- `PanelCoordinate`, `panel_coordinates`, and `panel_coordinate` now make the
  deterministic flat panel-cell axis explicit for one-dimensional and
  multidimensional `PanelMMM` result surfaces without changing model numerics
- Phase 15 is now closed: the fixture-backed calibration/lift-test helper
  surface is wired into `TimeSeriesMMM` MCMC sampling for the bounded
  centered-logistic lift-test and cost-per-target slice, with docs, changelog,
  and ledger guardrails keeping panel calibration, VI calibration, pipeline/YAML
  ingestion, broader saturation-family calibration, Dash/UI workflows, and
  AI-advisor behaviour out of scope until separate contracts exist
- Phase 16 is now closed with documentation, changelog, and ledger guardrails
  matching the bounded non-UI manual-allocation surface
- Phase 17 is now closed: Task 17-01 parses bounded public `calibration`
  YAML/dict blocks into the existing typed `TimeSeriesCalibrationInput` under
  `ModelConfig.extras["calibration"]`; Task 17-02 threads that parsed payload
  into time-series construction with explicit panel rejection; Task 17-03
  threads the parsed payload through bounded time-series MCMC pipeline fitting;
  and Task 17-04 closes docs, changelog, and ledger guardrails while keeping
  panel calibration, VI calibration, non-logistic lift-test calibration,
  Dash/UI, and AI-advisor paths out of scope
- Phase 18 is now closed: existing non-UI `ScenarioPlanResult` tables can be
  persisted as local Epsilon/Julia-version-bound `ScenarioStoreArtifact`
  payloads with CSV inspection sidecars and compatibility guardrails, while
  Dash/UI, hosted/background stores, automatic refits, future spend paths,
  pipeline store emission, and panel manual allocation remain out of scope
- Phase 19 is closed: the current loaded-module public export surface is
  inventoried in `docs/src/api.md` with support bands, and a focused
  `api_exports` guard test prevents silent undocumented exports. The package
  identity/public exports ledger row remains `scaffolded`; breaking export
  cleanup and stronger Abacus API compatibility claims remain future work
- Phase 20 is closed: the focused `api_exports` guard now enforces that every
  inventoried/exported public symbol has a non-empty rendered docstring and an
  exact `Epsilon.<symbol>` entry in a fenced Documenter `@docs` block under
  `docs/src`. This is documentation hygiene only; the package identity/public
  exports ledger row remains `scaffolded`
- Phase 21 is closed: `.planning/API-EXPORT-TRIAGE.md` now records a guarded
  lifecycle action for every current loaded export, and the focused
  `api_exports` lane validates the triage table against the public API
  inventory. This is governance hygiene only; no exports, runtime warnings, or
  Abacus API parity claims changed
- Phase 22 is closed: `.planning/API-EXPORT-CLEANUP-RFC.md`
  records a small candidate-only cleanup RFC for exported validation helpers,
  and the focused `api_exports` lane guards the RFC/register relationship. This
  is governance hygiene only; no exports, runtime warnings, behaviour, or
  Abacus API parity claims change
- Phase 23 is closed: `.planning/API-RUNTIME-DEPRECATION-DESIGN.md` records
  the future runtime-deprecation implementation contract for the six Phase 22
  validation-helper candidates, including the required public-wrapper/internal-
  helper split. This is design hygiene only; no exports, runtime warnings,
  behaviour, tests, user-facing docs, or Abacus parity claims change
- Phase 24 is closed: the six Phase 22 validation-helper candidates now warn
  on direct public calls through `Base.depwarn` wrappers, while constructors,
  loaders, and calibration payload builders call warning-free `_validate_*`
  helpers. Exports and API inventory rows remain unchanged, and this does not
  change Abacus parity claims or v1 API stability.
- Phase 25 is closed: focused package-test file selectors now allow a single
  file under `test/` to run through `Pkg.test` with test-only dependencies
  available, and `make test-file FILE=...` provides the local helper. This is
  verification ergonomics only; no model/runtime semantics or Abacus parity
  claims change.
- Phase 26 is closed:
  `.planning/API-EXPORT-CLEANUP-RFC.md` now records a marked
  migration-readiness audit for the six deprecated validation-helper exports,
  and the focused `api_exports` lane guards that audit against current filtered
  exports, the triage register, the Phase 22 RFC, and the Phase 23/24
  runtime-deprecation design. This is governance consistency only; the helpers
  remain exported and not ready to unexport.
- Phase 27 is closed:
  release-facing docs, planning state, and the focused `api_exports` lane now
  make MCMC/Turing the only v1-supported inference backend. `VariationalConfig`
  and `approximate_fit!` remain scaffolded pre-v1 review exports, but
  variational inference, dashboard/UI parity, and AI advisor behaviour are
  explicitly out of scope for v1.
- Phase 28 is closed: a tiny synthetic
  `TimeSeriesMMM` toy MCMC smoke demo now lives under `examples/toy_mmm/`,
  exposes `run_toy_mmm`, writes compact summaries only when an output directory
  is supplied, and is covered by `test/examples/toy_mcmc_smoke.jl`. This is a
  supported-path smoke demo, not release evidence, not a benchmark, not an
  Abacus parity claim, and not a broader support expansion.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions added later if needed

- [x] **Phase 1: Foundation** - Establish the package, tooling, quality gate,
      and repository conventions.
- [x] **Phase 2: Primitives** - Port the mathematical transform layer with
      parity fixtures.
- [x] **Phase 3: Priors and Distributions** - Build the prior specification and
      custom distribution system.
- [x] **Phase 4: Model Core** - Implement typed config, model builders, and a
      basic runnable MMM.
- [x] **Phase 5: MMM Features** - Add seasonality, trend, events, controls,
      panel structure, and other model features.
- [x] **Phase 6: Inference** - Harden sampling, predictive workflows, and
      diagnostics.
- [x] **Phase 7: Post-Modeling** - Produce contributions, decomposition,
      response curves, and business metrics.
- [x] **Phase 8: Budget Optimization** - Implement constrained optimization on
      top of modeled response.
- [x] **Phase 9: Pipeline** - Deliver the end-to-end YAML-driven CLI workflow.
- [x] **Phase 10: Plotting** - Build the visualization layer for diagnostics and
      MMM outputs.
- [x] **Phase 11: Validation and Benchmarks** - Build the release-gate
      harness, benchmark runner, and readiness docs on top of the landed v1
      surface.
- [x] **Phase 12: Parity Remediation** - Repair the methodology gaps revealed
      by the audit before any release preparation resumes, using Abacus as a
      reference baseline rather than a source of mandatory literal behavior.
- [x] **Phase 13: Prediction-State and Contract Remediation** - Repair fitted
      trend/holiday prediction-state behavior and harden invalid input/config
      contracts before release preparation resumes.
- [x] **Phase 14: Abacus Parity Recovery** - Revalidate the Abacus statistical
      core through the `timeseries`, `geo_panel`, and `geo_brand_panel`
      demo-style acceptance targets tracked in
      `.planning/ABACUS-PARITY-LEDGER.md`.
- [x] **Phase 15: Calibration Likelihood Integration** - Wire the scaffolded
      calibration/lift-test helper layer into `TimeSeriesMMM` MCMC sampling
      with fixture-backed log-density evidence and explicit guardrails keeping
      panel, VI, pipeline/YAML, broader saturation-family, Dash/UI, and
      AI-advisor calibration out of scope.
- [x] **Phase 16: Scenario Planner Manual Allocation Evaluation** - Evaluate
      manually specified channel allocations against existing fitted
      time-series response surfaces, keeping scenario planning non-UI,
      no-refit, and bounded away from free panel allocation.
- [x] **Phase 17: Calibration YAML And Pipeline Integration** - Expose the
      bounded `TimeSeriesMMM` MCMC calibration likelihood through public
      YAML/config and pipeline construction without widening the unsupported
      panel, VI, non-logistic, Dash/UI, or AI-advisor calibration surfaces.
- [x] **Phase 18: Scenario Store Artifacts** - Persist existing non-UI
      `ScenarioPlanResult` tables as local typed artifacts with CSV inspection
      sidecars and compatibility guardrails, without adding hosted stores,
      background jobs, automatic refits, future spend paths, pipeline emission,
      Dash/UI, or panel manual allocation.
- [x] **Phase 19: Public API Export Hygiene** - Inventory the current exported
      public surface in user docs and guard it with a focused test, without
      changing exports or model semantics.
- [x] **Phase 20: Public API Docstring Guard** - Enforce docstring and
      Documenter `@docs` coverage for every current inventoried/exported public
      symbol, without changing exports, model semantics, or Abacus parity
      claims.
- [x] **Phase 21: Public API Export Triage** - Add a guarded lifecycle triage
      register for every current loaded export, without changing exports,
      runtime behaviour, or Abacus parity claims.
- [x] **Phase 22: Public API Export Cleanup RFC** - Record a small
      candidate-only cleanup RFC for exported validation helpers and guard the
      RFC/register relationship, without changing exports, runtime behaviour,
      or Abacus parity claims.
- [x] **Phase 23: Runtime Deprecation Design** - Record the future
      runtime-deprecation implementation contract for the six Phase 22
      validation-helper candidates, without changing exports, runtime
      behaviour, tests, user-facing docs, or Abacus parity claims.
- [x] **Phase 24: Runtime Deprecation Wrappers** - Implement runtime
      deprecation wrappers for the six Phase 22 validation-helper candidates,
      keeping constructors, loaders, and payload builders warning-free and
      leaving exports, inventory rows, and Abacus parity claims unchanged.
- [x] **Phase 25: Focused Test File Harness** - Add bounded `Pkg.test`
      file selectors and a `make test-file FILE=...` helper so routine
      verification can run one focused test file with test-only dependencies
      available, without widening to a full-suite run.
- [x] **Phase 26: Deprecated Validation Helper Migration Audit** - Record and
      guard the current migration-readiness state for the six deprecated
      validation-helper exports without removing exports, changing runtime
      behaviour, or making Abacus parity or stable-v1 API claims.
- [x] **Phase 27: Scope Boundary Reconciliation** - Keep v1 inference support
      MCMC-only while retaining VI exports as scaffolded pre-v1 review
      surfaces and documenting dashboard/UI and AI advisor behaviour as out of
      scope for v1.
- [x] **Phase 28: Toy MCMC Smoke Demo** - Add a tiny synthetic `TimeSeriesMMM`
      MCMC smoke demo plus focused test coverage, without treating it as
      release evidence, benchmark work, Abacus parity, or broader support
      expansion.

## Phase Details

### Phase 1: Foundation
**Goal:** Create a reliable Julia package foundation that supports fast, reproducible iteration on the rest of the roadmap.
**Depends on:** Nothing (first phase)
**Requirements:** [FOUND-01, FOUND-02]
**Success Criteria** (what must be TRUE):
  1. Contributors can run tests, formatting, and docs locally with a standard
     project workflow.
  2. The local package workflow enforces the baseline quality gate.
  3. The repository structure matches the agreed technical standards and is
     ready for layer-by-layer implementation.
**Plans:** 3 plans

Plans:
- [x] 01-01: Finalize the canonical contributor surface: standards path,
      contributor references, and repository-facing documentation.
- [x] 01-02: Make the default quality gate pass locally (`make test`,
      `make docs`, and Runic format checks).
- [x] 01-03: Establish the layer-oriented module/test skeleton and a concrete
      fixture acquisition path for Abacus parity work.

### Phase 2: Primitives
**Goal:** Port the mathematical transform layer and lock down parity at the lowest reusable layer.
**Depends on:** Phase 1
**Requirements:** [TRANS-01]
**Success Criteria** (what must be TRUE):
  1. Users can call convolution, adstock, saturation, and scaling utilities from
     Julia code.
  2. Transform outputs match Abacus fixtures within defined tolerances.
  3. The transform layer is documented and safe to use from higher model layers.
**Plans:** 4 plans

Plans:
- [x] 02-01: Implement convolution primitives and fixture-based tests.
- [x] 02-02: Implement adstock variants with normalization behavior and tests.
- [x] 02-03: Implement saturation variants and parity tests.
- [x] 02-04: Implement scaling, validation helpers, and transform integration
      coverage.

### Phase 3: Priors and Distributions
**Goal:** Create the config-driven prior system and the custom distributions required by the port.
**Depends on:** Phase 2
**Requirements:** [PRIOR-01]
**Success Criteria** (what must be TRUE):
  1. Users can describe priors in config and obtain consistent Julia objects.
  2. Custom and shrinkage priors behave correctly for sampling and log density
     evaluation.
  3. Distribution naming and parameterization differences from PyMC are handled
     in one well-tested layer.
**Plans:** 3 plans

Plans:
- [x] 03-01: Implement prior schema, distribution-name mapping, and config deserialization.
- [x] 03-02: Implement special distributions and their numerical tests.
- [x] 03-03: Implement shrinkage and masked priors with compatibility coverage.

### Phase 4: Model Core
**Goal:** Build the typed core abstractions, runnable MMM path, and the basic
lifecycle surfaces needed to extend the package safely.
**Depends on:** Phase 3
**Requirements:** [MODEL-01, MODEL-02]
**Success Criteria** (what must be TRUE):
  1. Users can load config and data into typed model objects.
  2. Users can build, fit, predict with, and save a basic time-series MMM.
  3. Users can inspect typed fit/results/diagnostic artifacts for that minimal
     model path.
  4. The model core exposes a stable interface that higher MMM features and
     later inference work can extend without major redesign.
**Plans:** 5 plans

Plans:
- [x] 04-01: Implement model types, config loading, and validation.
- [x] 04-02: Implement builder interfaces and model orchestration entry points.
- [x] 04-03: Implement the base MMM `@model`, minimal media-channel path, and posterior predictive smoke coverage.
- [x] 04-04: Implement the basic model lifecycle surface: prior/posterior
      predictive support, serialization, typed results, typed diagnostics, and
      multi-chain runtime coverage.
- [x] 04-05: Reconcile the Phase 4 boundary against the implemented code,
      define truthful exit criteria, decide that richer grouped results export
      belongs to Phase 6, and hand off remaining feature and inference work to
      Phases 5 and 6.

### Phase 5: MMM Features
**Goal:** Extend the base MMM with the major features needed for practical marketing-mix work without reopening Phase 4 model-core scope.
**Depends on:** Phase 4
**Requirements:** [MODEL-03]
**Success Criteria** (what must be TRUE):
  1. Users can configure supported Phase 5 features through one explicit,
     documented config contract rather than inferred feature flags.
  2. The feature layer composes with the Phase 4 model interfaces cleanly
     without reopening model-core scope.
  3. HSGP is forced through an explicit decision gate before downstream feature
     work depends on it; if not implemented in Phase 5, no public Phase 5 HSGP
     contract remains.
  4. The first panel / hierarchical path is implemented through `PanelMMM`
     rather than by overloading `TimeSeriesMMM`.
  5. Supported feature combinations are integration-tested and documented
     honestly before Phase 6 inference work begins.
**Plans:** 4 plans

Plans:
- [x] 05-01: Implement the seasonality baseline and force the early HSGP
      strategy decision.
- [x] 05-02: Implement trend, events, and richer control-variable components.
- [x] 05-03: Implement panel and hierarchical MMM support.
- [x] 05-04: Freeze the supported Phase 5 feature contract, land the accepted
      HSGP path or bounded unsupported decision, and close the phase honestly.

### Phase 6: Inference
**Goal:** Harden the current fitting workflow into a truthful inference layer
with a canonical grouped artifact contract. Phase 6 also landed an explicit VI
implementation, but Phase 27 reclassifies that surface as scaffolded pre-v1
review rather than v1 release support.
**Depends on:** Phase 5
**Requirements:** [INFER-01, INFER-02, INFER-03]
**Success Criteria** (what must be TRUE):
  1. Users can run truthful MCMC workflows on the supported Phase 5 surface
     with reproducible settings and explicit warning/failure behavior.
  2. Users can inspect and persist grouped inference artifacts through one
     canonical Julia-native `InferenceResults` surface.
  3. The historical variational-inference implementation remains visible as
     `approximate_fit!` / `VariationalConfig` scaffolded export surface, while
     Phase 27 keeps v1 release support MCMC-only.
  4. The inference support matrix is documented honestly before Phase 7 begins,
     and Phase 7 consumes that frozen artifact contract rather than redefining
     it.
**Plans:** 4 plans

Plans:
- [x] 06-01: Harden the current MCMC workflow, warning policy, and execution contract.
- [x] 06-02: Implement the canonical `InferenceResults` grouped export and predictive grouping surface.
- [x] 06-03: Implement `approximate_fit!`, `VariationalConfig`, and the first
      variational-inference implementation, now treated as scaffolded
      pre-v1-review history after Phase 27.
- [x] 06-04: Freeze the truthful inference support matrix and close the phase.

### Phase 7: Post-Modeling
**Goal:** Produce the downstream business outputs analysts need after fitting a
model, consuming the canonical grouped inference artifacts from Phase 6.
**Depends on:** Phase 6
**Requirements:** [POST-01]
**Success Criteria** (what must be TRUE):
  1. Analysts can compute contributions, shares, and decomposition from
     supported grouped time-series results.
  2. Analysts can generate response curves and marketing metrics such as ROAS
     from supported grouped time-series results.
  3. Post-model outputs remain traceable to modeled quantities through an
     explicit deterministic replay contract on top of `InferenceResults`, and
     they match Abacus on agreed fixtures for the same posterior draws.
  4. The Phase 7 support matrix is explicit before Phase 8 begins, including the
     bounded unsupported status of panel post-model outputs.
**Plans:** 3 plans

Plans:
- [x] 07-01: Implement contributions, shares, and decomposition outputs.
- [x] 07-02: Implement response-curve and business-metric calculations.
- [x] 07-03: Add parity tests, summary-table generation, and support-matrix closeout.

### Phase 8: Budget Optimization
**Goal:** Optimize media allocation using the modeled response functions and practical constraints.
**Depends on:** Phase 7
**Requirements:** [OPT-01]
**Success Criteria** (what must be TRUE):
  1. Analysts can optimize fixed budget across supported time-series channels
     under one explicit bounded constraint contract.
  2. The optimizer consumes the frozen Phase 7 response/metric surface
     reproducibly without reopening spend-shape or post-model semantics.
  3. Optimization outputs are parity-tested against Abacus on agreed fixtures,
     and the unsupported panel / pipeline semantics are documented honestly
     before Phase 9 begins.
**Plans:** 3 plans

Plans:
- [x] 08-01: Implement the bounded objective surface, constraint primitives, and typed optimization contract.
- [x] 08-02: Implement optimizer orchestration and the canonical result surface via JuMP + Ipopt.
- [x] 08-03: Add parity tests, comparison/audit outputs, and support-matrix closeout.

### Phase 9: Pipeline
**Goal:** Deliver the bounded YAML-driven workflow that orchestrates supported
time-series Epsilon runs from configuration to structured results.
**Depends on:** Phase 8
**Requirements:** [PIPE-01]
**Success Criteria** (what must be TRUE):
  1. Users can invoke an end-to-end pipeline from a CLI command on one bounded
     combined-CSV contract with fixed date parsing, chronological sorting, and
     duplicate-date rejection.
  2. Pipeline stages execute in the fixed intended order with clear artifacts,
     skip semantics, and error reporting, and blocked holdout validation runs
     as a side branch that does not overwrite the full-sample fit path.
  3. The output directory structure, `run_manifest.json`, `PipelineRunResult`,
     and core sidecars have predictable documented schemas compatible with the
     project’s documentation and parity goals.
  4. The Phase 9 support matrix is explicit: time-series first, MCMC-only,
     with panel and YAML-driven VI marked unsupported in that phase, and the
     CLI/runtime override surface stays bounded to the same `PipelineRunConfig`
     contract.
**Plans:** 4 plans

Plans:
- [x] 09-01: Implement pipeline config, context, and orchestration skeleton.
- [x] 09-02: Implement metadata, preflight, fit, and assessment stages.
- [x] 09-03: Implement validation, decomposition, diagnostics, curves, and
      optional optimization stages.
- [x] 09-04: Implement the CLI entry point and end-to-end integration coverage.

### Phase 10: Plotting
**Goal:** Provide a pragmatic Julia-native visualization/reporting layer for model diagnostics and MMM outputs without targeting Dash parity.
**Depends on:** Phase 9
**Requirements:** [PLOT-01]
**Success Criteria** (what must be TRUE):
  1. Users can render the bounded CairoMakie `Figure`-returning visual surface
     from the closed typed artifact contracts of Phases 6-9.
  2. Plots and exported report artifacts are consistent in theme, labeling, and
     output quality.
  3. Diagnostic visuals support debugging and interpretation of model behavior
     without requiring a replicated interactive dashboard surface, and the
     report-ready helper remains a post-hoc static export rather than a second
     pipeline path.
**Plans:** 3 plans

Plans:
- [x] 10-01: Implement plot theme and diagnostic plotting foundation.
- [x] 10-02: Implement contribution, decomposition, and response-curve plots.
- [x] 10-03: Implement optimization and report-ready visual outputs, keeping the
      UI surface intentionally simpler than Abacus Dash.

### Phase 11: Validation and Benchmarks
**Goal:** Build the final validation, benchmark, and release-doc
infrastructure on top of the landed v1 surface.
**Depends on:** Phase 10
**Requirements:** [VAL-01, VAL-02]
**Success Criteria** (what must be TRUE):
  1. Maintainers can run one explicit release-gate harness that distinguishes
     Abacus-reference rows from bounded Epsilon-only contract-validation
     rows across the supported v1 surface.
  2. Benchmark methodology and published results quantify performance
     honestly for the bounded v1 workloads, including any slower-than-Abacus
     cases.
  3. Documentation, benchmark summaries, and release-readiness criteria exist
     in one explicit maintainer-facing place.
**Plans:** 3 plans

Plans:
- [x] 11-01: Build the parity harness, exact canonical validation cases, and
      fixed artifact comparison table for final validation.
- [x] 11-02: Build and document the frozen benchmark workload matrix and run
      protocol.
- [x] 11-03: Finalize release docs, examples, and v1.0 readiness criteria.

### Phase 12: Parity Remediation
**Goal:** Repair the bounded time-series path so Epsilon can make honest
reference claims against Abacus where semantics truly match, while adopting the
most methodologically coherent bounded design where strict fidelity would be a
worse end state.
**Depends on:** Phase 11
**Requirements:** [PAR-01]
**Success Criteria** (what must be TRUE):
  1. The frozen reference row `VAL-TS-00-MCMC` fits in the same scaling/model
     space as Abacus, with explicit scale state and truthful original-scale
     reconstruction, and any holiday-bearing row is described as
     Abacus-reference only if its semantics genuinely match.
  2. Stage 60 is explicit and testable on those rows:
     `response_curve_results(...)` remains forward-pass contribution,
     `saturation_curve_results(...)` adds saturation-only, and
     `adstock_curve_results(...)` adds adstock with frozen grid/output-unit
     semantics and named pipeline artifacts.
  3. Stage 70 optimization semantics are realigned with that corrected
     contract rather than inheriting the pre-remediation curve surface.
  4. The runnable time-series demo/reference story is truthful for the final
     holiday/trend/seasonality contract, with automatic holidays using one
     pooled analyst-facing component by default and manual named holiday
     treatment living under `events`.
  5. Release-facing docs no longer overclaim parity, and release preparation
     remains paused until the repaired validation evidence exists.
**Plans:** 4 plans

Plans:
- [x] 12-01: Implement scaling and model-space parity for the bounded
      time-series fit path.
- [x] 12-02: Verify the landed 12-01 replay contract, add the explicit
      saturation-only and adstock curve families, reconcile the frozen
      `:michaelis_menten` parameter-ownership decision, and freeze the Stage 60
      pipeline/output contract.
- [x] 12-03: Reconcile optimization verification with the external methodology
      advice and replace the provisional holiday/component path with the final
      coherent design.
- [x] 12-04: Re-run validation, reconcile release docs, and decide whether
      release preparation can resume.

### Phase 13: Prediction-State and Contract Remediation
**Goal:** Close the concrete prediction-state, validation-contract, and
pipeline-config risks identified in the Phase 12 external code review before
release preparation resumes.
**Depends on:** Phase 12
**Requirements:** [PRED-01]
**Success Criteria** (what must be TRUE):
  1. Trend-enabled prediction and deterministic replay use fitted trend
     normalization/basis state rather than state recomputed from the date span
     of `new_data`.
  2. Holiday-enabled prediction and deterministic replay use fitted
     calendar-period exposure state rather than exposure recomputed from
     arbitrary holdout slices.
  3. Media inputs have one documented nonnegative-domain contract across direct
     APIs, transforms, prediction, and pipeline validation.
  4. Pipeline YAML rejects unknown top-level run keys that would otherwise
     silently disable or bypass intended behavior.
  5. Docs, artifact serialization, and the release gate reflect the repaired
     prediction-state and config contracts.
**Plans:** 6 plans

Plans:
- [x] 13-01: Freeze fitted feature-state contract.
- [x] 13-02: Implement trend-state prediction/replay remediation.
- [x] 13-03: Implement holiday exposure-state prediction/replay remediation.
- [x] 13-04: Harden the media input contract.
- [x] 13-05: Tighten pipeline YAML contract.
- [x] 13-06: Revalidate docs and release gate.

### Phase 14: Abacus Parity Recovery
**Goal:** Rebuild release readiness around demo-backed Abacus parity evidence
for the statistical and methodological MMM core, while keeping Julia-native
design choices honest where literal upstream fidelity would be misleading.
**Depends on:** Phase 12 methodology remediation, with relevant Phase 13
contract risks folded in where they block demo acceptance.
**Requirements:** [PARITY-01]
**Success Criteria** (what must be TRUE):
  1. The `timeseries`, `geo_panel`, and `geo_brand_panel` demo-style targets
     have fixture-backed config/data and model/replay gates.
  2. Pipeline manifests and stage-local artifact keys are validated against
     exported Abacus contracts for every accepted demo-style path.
  3. PyMC/NetCDF-specific Abacus artifacts are mapped to typed Julia-native
     artifacts only where the stage semantics genuinely match.
  4. Unsupported, pending, native, and deferred rows are visible in
     `.planning/ABACUS-PARITY-LEDGER.md`.
  5. Release-facing docs avoid broad Abacus parity claims not backed by
     ledger evidence.
**Plans:** 5 plans

Plans:
- [x] 14-01: Build the `timeseries` config/data fixture spine.
- [x] 14-02: Land the `timeseries` model and deterministic replay parity gate.
- [x] 14-03: Land one-dimensional `geo_panel` config/model/replay parity.
- [x] 14-04: Land multidimensional `geo_brand_panel` config/model/replay
      parity and panel-cell artifact semantics.
- [ ] 14-05: Complete pipeline manifest and artifact parity. Current state:
      `timeseries` Stage `00` through Stage `70` artifact-key parity is
      covered, and `geo_panel` / `geo_brand_panel` Stage `00`
      metadata/manifest, Stage `20` fit, Stage `30` assessment, and Stage
      `40` decomposition, Stage `50` diagnostics, and Stage `60`
      response-curve artifact-key parity are covered; expand panel downstream
      only when the next artifact semantics are fixture-backed.

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> ... -> 28

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 3/3 | Completed | quality gate, standards path, fixture export path |
| 2. Primitives | 4/4 | Completed | convolution, adstock, saturation, scaling |
| 3. Priors and Distributions | 3/3 | Completed | prior schema, distribution mapping, config deserialization, special-prior compatibility, custom distributions, shrinkage recipes |
| 4. Model Core | 5/5 | Completed | typed model/config/data structs, runnable Turing-backed MMMs, predictive paths, save/load, diagnostics, warnings |
| 5. MMM Features | 4/4 | Completed | frozen TimeSeriesMMM / PanelMMM feature-bundle matrix and explicit unsupported combinations |
| 6. Inference | 4/4 | Completed | hardened MCMC path, canonical `InferenceResults`, historical VI implementation now classified as scaffolded after Phase 27, frozen support matrix |
| 7. Post-Modeling | 3/3 | Completed | deterministic replay, typed post-model outputs, summary tables, Abacus parity coverage, frozen post-model matrix |
| 8. Budget Optimization | 3/3 | Completed | bounded fixed-budget optimizer, parity fixtures, comparison/audit outputs |
| 9. Pipeline | 4/4 | Completed | bounded time-series-first MCMC runner, CLI, and full Stage `00`-`70` contract |
| 10. Plotting | 3/3 | Completed | CairoMakie diagnostic, post-model, optimization, and deterministic bundle plotting surface |
| 11. Validation and Benchmarks | 3/3 | Completed | validation infrastructure, benchmark runner, published snapshot, and release-readiness docs |
| 12. Parity Remediation | 4/4 | Completed | scaling/model-space parity, Stage 60 curve parity, Stage 70 verification, coherent holiday/design contract, and final revalidation/release reconciliation landed |
| 13. Prediction-State and Contract Remediation | 6/6 | Completed | fitted trend/holiday prediction-state repair, media input contract hardening, pipeline YAML contract hardening, and final release-gate revalidation landed |
| 14. Abacus Parity Recovery | 5/5 | Plan complete | `timeseries`, `geo_panel`, and `geo_brand_panel` demo-backed evidence spine; `timeseries` pipeline Stage `00`-`70` artifact-key parity; `geo_panel` and `geo_brand_panel` pipeline Stage `00`, Stage `20`, Stage `30`, Stage `40`, Stage `50`, Stage `60`, and explicitly enabled Stage `70` historical-share optimization coverage, with panel Stage `35` deferred |
| 27. Scope Boundary Reconciliation | 4/4 | Completed | MCMC-only v1 inference boundary, VI/dashboard/AI out-of-scope table, release-doc and planning guardrails |
| 28. Toy MCMC Smoke Demo | 4/4 | Completed | tiny synthetic `TimeSeriesMMM` MCMC smoke demo, callable toy entry point, optional compact summaries, and focused example test landed |
