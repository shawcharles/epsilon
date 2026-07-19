# Roadmap: Epsilon MMM

## Overview

Epsilon has moved beyond the original implementation scaffold into a bounded,
ledger-governed Julia MMM library. Historical phase completion is still not
evidence of broad Abacus parity by itself; the controlling record is
`.planning/ABACUS-PARITY-LEDGER.md`, where each surface is classified as
`ported`, `native`, `scaffolded`, `missing`, or `deferred`.

The bounded Abacus statistical and methodological evidence spine for
`timeseries`, `geo_panel`, and `geo_brand_panel` is now landed through Phase 14 /
Plan `14-05`. Broader release claims, benchmark refreshes, panel validation,
free channel-by-panel optimization, dashboard/UI, AI advisor behaviour, and any
future HSGP/TVP expansion require separate explicit plans rather than being the
automatic next milestone.

Current planning has subsequently landed through Phase 66. The recent sequence
is mostly bounded hardening and governance work: optimiser API/tolerance
cleanup, package-entry decomposition, calibration fail-fast validation,
methodology wording, AD-safety guards, prior-domain guards, and export-list
auditability. These phases do not change the parity ledger's controlling status
rows or imply a broader release claim.

## Historical Repository Review Snapshot

Historical repository state on 2026-05-18, retained to explain the parity reset
that later closed in Phase 14:

- `make test` and `make docs` have passed in prior phase work, but passing the
  existing suite is not sufficient to claim Abacus parity
- the Abacus fixture export/import path is established through
  `scripts/export_abacus_fixtures.py`
- the transform layer has the strongest fixture-backed parity evidence
- prior/distribution, model, inference, post-model, optimization, plotting, and
  pipeline modules existed but needed ledger-backed revalidation before broad
  parity claims; Phase 14 later closed the bounded demo-backed evidence spine
- `.planning/ABACUS-PARITY-LEDGER.md` became the controlling document for the
  implementation sequence
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
  made MCMC/Turing the only v1-supported inference backend. Phase 38
  subsequently permanently retired the former variational implementation;
  dashboard/UI parity and AI advisor behaviour remain explicitly deferred.
- Phase 28 is closed: a tiny synthetic
  `TimeSeriesMMM` toy MCMC smoke demo now lives under `examples/toy_mmm/`,
  exposes `run_toy_mmm`, writes compact summaries only when an output directory
  is supplied, and is covered by `test/examples/toy_mcmc_smoke.jl`. This is a
  supported-path smoke demo, not release evidence, not a benchmark, not an
  Abacus parity claim, and not a broader support expansion.
- Phase 29 is closed: the toy MCMC smoke path is hardened around CLI error
  clarity, help/include-safety evidence, and focused docs/tests,
  without touching source runtime semantics, dependencies, exports, Abacus
  parity claims, benchmarks, release evidence, VI, dashboard/UI, or AI advisor
  surfaces.
- Phase 30 is closed: `examples/csv_mmm/` provides a fixed-schema
  `date,sales,tv,search` time-series Turing/NUTS quickstart with strict typed
  validation, chronological sorting, duplicate-date rejection, direct CLI and
  include safety, compact outputs, and focused tests. It does not add a package
  ingestion API or change source, dependencies, pipeline semantics, benchmarks,
  release evidence, or Abacus parity claims.
- Phase 31 is closed: an internal `Date` cadence-index primitive is
  fixture-backed against Abacus `infer_time_index`, including forward/backward,
  leap-boundary, and off-cadence cases. This is foundation work only: HSGP/TVP
  configuration, basis construction, priors, Turing wiring, prediction, and
  replay remain unimplemented.
- Phase 32 is closed: private HSGP basis/PSD geometry and recommendation
  helpers are fixture-backed without graph construction, config acceptance, or
  model support.
- Phase 33 is closed: private HSGP latent projection, stable softplus, and
  mean-one positive multiplier helpers are fixture-backed without Turing
  priors, public config, or model support.
- Phase 34 is closed: private fitted-state replay for the HSGP positive
  multiplier preserves training geometry and the softplus denominator without
  widening support.
- Phase 35 is closed: the TimeSeriesMMM-only shared HSGP media-multiplier
  methodology contract was frozen before Turing integration.
- Phase 36 is closed: the reviewed TimeSeriesMMM-only shared media multiplier
  implementation landed with strict wider-surface rejection while the combined
  HSGP/TVP ledger row remained `missing`.
- Phase 37 is closed: HSGP contribution/decomposition replay is bounded to the
  exact retained fitted TimeSeriesMMM training grid.
- Phase 38 is closed: the pre-release VI surface was permanently retired, and
  MCMC/Turing is the only supported inference contract.
- Phase 39 is closed: local toy/CSV supported-path smoke certification landed
  without benchmarks or release claims.
- Phase 40 is closed: stale planning docs were reconciled after Phase 39.
- Phase 41 is closed: compact supported-path output sidecars were audited and
  lightly hardened.
- Phase 42 is closed: trusted-local fitted-model and grouped-result roundtrips
  were proven for the toy and CSV supported paths.
- Phase 43 is closed: the supported-path user workflow runbook landed.
- Phase 44 is closed: current-facing docs were reconciled to the Phase 43
  supported-path state.
- Phase 45 is closed: focused docs-claim guards now protect current-status,
  VI-retirement, supported-workflow, and trusted-local wording.
- Phase 46 is closed: Abacus reference surfaces were inventoried and
  classified before public identity cleanup.
- Phase 47 is closed: public-facing identity language now presents Epsilon as
  an independent Julia MMM library while preserving validation provenance.
- Phase 48 is closed: remaining internal provenance renames were assessed and
  mostly parked behind alias-first or post-v1 policies.
- Phase 49 is closed: the suspected even-kernel overlap-convolution bug was
  disproved against the reference and locked with focused tests.
- Phase 50 is closed: fitted trend and automatic-holiday prediction state is
  regression-locked for future prediction.
- Phase 51 is closed: public model-config parsing now rejects unsupported
  top-level keys while preserving narrow compatibility extras.
- Phase 52 is closed: spend-domain saturation/media inputs reject negative
  values while signed low-level tanh remains supported.
- Phase 53 is closed: budget optimisation moved off the legacy JuMP nonlinear
  registration/objective API.
- Phase 54 is closed: optimiser projection residual handling now has tighter
  tolerance checks and fail-closed behaviour.
- Phase 55 is closed: the API/export hub decomposition assessment recommended
  export extraction, include-order documentation, and forwarder ownership
  cleanup rather than a broad namespace rewrite.
- Phase 56 is closed: public export declarations were extracted from
  `src/Epsilon.jl` into `src/exports.jl` with the loaded export set preserved.
- Phase 57 is closed: runtime includes were moved to `src/includes.jl` with
  documented layer ordering and unchanged load order.
- Phase 58 is closed: panel-coordinate forwarders moved to their owning model
  leaf without changing public exports.
- Phase 59 is closed: calibration likelihood validation now fails at the
  payload/config boundary rather than being swallowed inside the Turing model.
- Phase 60 is closed: methodology docstrings now clarify binomial adstock and
  budget/spend units.
- Phase 61 is closed: model-data validation keeps AD scalar compatibility while
  rejecting invalid ordinary inputs.
- Phase 62 is closed: the overlap-convolution contract is documented and locked
  for odd/even impulse cases.
- Phase 63 is closed: prior constructors reject non-finite or non-positive
  positive-parameter values.
- Phase 64 is closed: the flat-namespace assessment parks internal submodules
  until after the first usable release path is stable.
- Phase 65 is closed: `src/exports.jl` is grouped by API-domain comments while
  preserving the exact export set.
- Phase 66 is closed: project-control docs were reconciled after Phase 65, with
  no runtime, test, docs-site, changelog, parity-ledger, fixture, dependency,
  benchmark, or release-claim changes.

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
      MCMC-only and document dashboard/UI and AI advisor behaviour as out of
      scope for v1. Superseded for inference implementation by Phase 38.
- [x] **Phase 28: Toy MCMC Smoke Demo** - Add a tiny synthetic `TimeSeriesMMM`
      MCMC smoke demo plus focused test coverage, without treating it as
      release evidence, benchmark work, Abacus parity, or broader support
      expansion.
- [x] **Phase 29: Toy MCMC Path Hardening** - Harden the toy smoke demo's CLI,
      help, include-safety, and focused tests without changing model semantics,
      dependencies, exports, release evidence, or Abacus parity claims.
- [x] **Phase 30: CSV Time-Series MCMC Quickstart** - Add a fixed-schema
      `date,sales,tv,search` `TimeSeriesMMM` MCMC quickstart with strict
      CSV/data-boundary guards and focused evidence, without adding a package
      ingestion API, pipeline support, source changes, or parity claims.
- [x] **Phase 31: HSGP Time-Index Foundation** - Add a private,
      fixture-backed cadence-index primitive without claiming HSGP/TVP support
      or widening model/config behaviour.
- [x] **Phase 32: HSGP Linearised Geometry Foundation** - Add private,
      fixture-backed HSGP basis/PSD geometry and recommendation primitives
      without graph construction, configuration acceptance, or model support.
- [x] **Phase 33: HSGP Latent Projection And Positive Multiplier Semantics** -
      Add private, fixture-backed helpers for the HSGP latent projection,
      numerically stable softplus, and mean-one positive multiplier
      normalisation matching Abacus `SoftPlusHSGP`, without Turing coefficient
      priors, configuration acceptance, or model support.
- [x] **Phase 34: HSGP Fitted Positive Multiplier Replay** - Add private,
      fixture-backed fitted-state replay that reuses training geometry and the
      training softplus denominator, without HSGP priors, Turing integration,
      configuration acceptance, or model support.
- [x] **Phase 35: Time-Series HSGP Media Methodology Contract** - Freeze the
      TimeSeriesMMM-only shared-media multiplier placement, temporal units,
      prior, prediction-state, and exclusion decisions before any Turing
      integration or public configuration is implemented.
- [x] **Phase 36: Time-Series HSGP Shared Media Multiplier** - Implement the
      reviewed TimeSeriesMMM-only non-centred shared positive multiplier with
      typed programmatic configuration, retained prediction state, schema-v2
      serialisation, and strict rejection of wider surfaces. Closed with
      independent review and the single `make check-full` closure gate; the
      combined HSGP/TVP ledger row remains `missing`.
- [x] **Phase 37: HSGP Time-Series Contribution Replay** - Bounded
      posterior-only fitted-period contribution and decomposition replay is
      implemented for the Phase 36 shared media multiplier. Closed with
      independent review and the single `make check-full` closure gate; HSGP
      curves, metrics, panels, YAML/pipeline, optimisation, and TVP remain
      unsupported.
- [x] **Phase 38: Permanent VI Surface Retirement** - Removed the pre-release
      `VariationalConfig` and `approximate_fit!` API, made MCMC/Turing the sole
      inference contract, and rejected legacy variational artefacts and config
      inputs without adding a compatibility bridge. Closed with independent
      review and the phase-closing `make check-full` gate: `9925 / 9925` tests
      in `23m33.1s` plus a successful docs build.
- [x] **Phase 39: Supported-Path Smoke Certification** - Added one local
      supported-path smoke command for the toy MCMC and fixed-schema CSV
      quickstart examples, without benchmarks, release claims, Abacus parity
      claims, or new modelling/API surface. Closed with independent plan review
      and scoped smoke/example verification.
- [x] **Phase 40: Planning Truth Reconciliation** - Reconcile stale planning
      and project-control documents after Phase 39 without changing runtime
      code, tests, examples, benchmarks, release artefacts, manifests, or Abacus
      parity status rows.
- [x] **Phase 41: Supported-Path Output Usability Audit** - Audit and lightly
      harden the compact output sidecars produced by the toy MCMC and
      fixed-schema CSV quickstart examples, without changing model semantics,
      widening support, running benchmarks, or making release claims.
- [x] **Phase 42: Supported-Path Artifact Roundtrip Audit** - Prove the toy MCMC
      and fixed-schema CSV quickstart fitted model and grouped inference result
      objects can be saved and reloaded through existing trusted-local Epsilon
      APIs, without new CLI flags, artifact formats, benchmarks, release claims,
      or model semantics changes.
- [x] **Phase 43: Supported-Path User Workflow Runbook** - Add a canonical
      docs-backed runbook for the supported toy, CSV, compact-output, artifact
      roundtrip, and local smoke workflow without changing runtime behavior,
      widening artifacts, running benchmarks, making release claims, or changing
      Abacus parity status.
- [x] **Phase 44: Current Docs Truth Reconciliation** - Reconcile current-facing
      docs with the Phase 43 state without changing runtime behavior, tests,
      examples, benchmarks, release artifacts, or Abacus parity status.
- [x] **Phase 45: Current Docs Claim Guard** - Add focused regression guards
      for stale current-status wording, VI retirement, supported local workflow
      evidence boundaries, and trusted-local `.jls` wording without changing
      runtime behavior, examples, benchmarks, release artifacts, or Abacus
      parity status.
- [x] **Phase 46: Abacus Reference Decoupling Plan** - Audit and classify
      Abacus references so future public identity cleanup can make Epsilon
      stand as an independent MMM library without deleting internal validation
      provenance or changing runtime behavior.
- [x] **Phase 47: Public Identity Rewrite** - Rewrite current public-facing
      identity language so Epsilon presents as an independent Julia MMM library
      while preserving fixture-backed validation provenance and adding a focused
      dependent-product phrase guard.
- [x] **Phase 48: Internal Provenance Rename Assessment** - Assess remaining
      Abacus-named fixture, exporter, demo, source, and ledger surfaces and
      freeze an alias-first, post-v1-ledger-rename plan without starting any
      renames.
- [x] **Phase 49: Convolution Overlap Parity Lock** - Disprove the suspected
      even-kernel `Overlap` behavioural bug against the local reference,
      preserve current numerics, add an explicit length-4 parity-lock test, and
      remove the dead source-index parameter.
- [x] **Phase 50: Trend And Holiday Prediction-State Lock** - Add focused
      integration evidence that fitted time-series prediction uses stored trend
      origin/scale and automatic-holiday period state for future data, even
      after mutable live config drift.
- [x] **Phase 51: Public Config Top-Level Typo Guard** - Harden direct public
      model config parsing so unsupported top-level keys fail closed while
      preserving narrow compatibility extras and pipeline runner-key stripping.
- [x] **Phase 52: Saturation Media Domain Contract** - Lock the pre-v1
      saturation/media-domain split: spend-domain saturation primitives reject
      negative `x`, signed tanh remains a low-level reference-backed primitive,
      and MMM media/curve surfaces keep nonnegative spend guardrails.
- [x] **Phase 53: JuMP Nonlinear Operator Migration** - Move budget
      optimisation off the legacy JuMP nonlinear registration/objective API
      while preserving the bounded optimisation contract.
- [x] **Phase 54: Optimization Projection Tolerance Guard** - Harden
      optimisation projection tolerance and residual handling so infeasible
      allocations fail closed.
- [x] **Phase 55: API Export Hub Decomposition Assessment** - Assess entry-point
      decomposition and choose small structural cleanup over internal submodule
      churn.
- [x] **Phase 56: Export Declarations Extraction** - Move public export
      declarations into `src/exports.jl` while preserving the loaded export set.
- [x] **Phase 57: Include Order Documentation** - Move runtime includes into
      `src/includes.jl` with documented layer ordering and unchanged load order.
- [x] **Phase 58: Panel Coordinate Forwarder Ownership** - Move panel-coordinate
      forwarders into their model-layer owner without changing public exports.
- [x] **Phase 59: Calibration Likelihood Fail-Fast Boundary** - Validate
      calibration likelihood payloads at the public boundary instead of relying
      on model-internal broad exception swallowing.
- [x] **Phase 60: Methodology Docstring Units Clarity** - Clarify binomial
      adstock provenance and budget/spend units in methodology-facing
      docstrings.
- [x] **Phase 61: AD-Safety Validation Audit** - Preserve AD scalar validation
      compatibility while keeping ordinary invalid inputs fail-closed.
- [x] **Phase 62: Convolution Overlap Contract Clarity** - Document and lock the
      retained overlap-convolution contract for odd and even impulse cases.
- [x] **Phase 63: Prior Positive-Finiteness Guards** - Require finite positive
      parameters for bounded prior/distribution constructors.
- [x] **Phase 64: Flat Namespace Risk Assessment** - Park internal submodules
      until after the first usable release path is stable.
- [x] **Phase 65: Export List Domain Grouping** - Group `src/exports.jl` by
      API-domain comments while preserving the exact public export set.
- [x] **Phase 66: Planning Truth Reconciliation** - Reconcile project-control
      docs after Phase 65 without runtime, test, docs-site, changelog,
      parity-ledger, fixture, dependency, benchmark, or release-claim changes.

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
implementation. Phase 27 reclassified that surface as scaffolded pre-v1
review, and Phase 38 later permanently removed it.
**Depends on:** Phase 5
**Requirements:** [INFER-01, INFER-02, INFER-03]
**Success Criteria** (what must be TRUE):
  1. Users can run truthful MCMC workflows on the supported Phase 5 surface
     with reproducible settings and explicit warning/failure behavior.
  2. Users can inspect and persist grouped inference artifacts through one
     canonical Julia-native `InferenceResults` surface.
  3. The historical variational-inference implementation was removed in Phase
     38; `approximate_fit!` and `VariationalConfig` are no longer public API.
  4. The inference support matrix is documented honestly before Phase 7 begins,
     and Phase 7 consumes that frozen artifact contract rather than redefining
     it.
**Plans:** 4 plans

Plans:
- [x] 06-01: Harden the current MCMC workflow, warning policy, and execution contract.
- [x] 06-02: Implement the canonical `InferenceResults` grouped export and predictive grouping surface.
- [x] 06-03: Implement `approximate_fit!`, `VariationalConfig`, and the first
      variational-inference implementation, now superseded by Phase 38's
      permanent removal.
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
- [x] 14-05: Complete pipeline manifest and artifact parity. Current state:
      `timeseries` Stage `00` through Stage `70` artifact-key parity is
      covered, and `geo_panel` / `geo_brand_panel` Stage `00`
      metadata/manifest, Stage `20` fit, Stage `30` assessment, and Stage
      `40` decomposition, Stage `50` diagnostics, and Stage `60`
      response-curve artifact-key parity are covered. Explicitly enabled Stage
      `70` historical-share optimization is also covered for both panel paths;
      Stage `35` panel holdout validation remains deferred.

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> ... -> 66

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 3/3 | Completed | quality gate, standards path, fixture export path |
| 2. Primitives | 4/4 | Completed | convolution, adstock, saturation, scaling |
| 3. Priors and Distributions | 3/3 | Completed | prior schema, distribution mapping, config deserialization, special-prior compatibility, custom distributions, shrinkage recipes |
| 4. Model Core | 5/5 | Completed | typed model/config/data structs, runnable Turing-backed MMMs, predictive paths, save/load, diagnostics, warnings |
| 5. MMM Features | 4/4 | Completed | frozen TimeSeriesMMM / PanelMMM feature-bundle matrix and explicit unsupported combinations |
| 6. Inference | 4/4 | Completed | hardened MCMC path, canonical `InferenceResults`, historical variational implementation later permanently retired in Phase 38, frozen support matrix |
| 7. Post-Modeling | 3/3 | Completed | deterministic replay, typed post-model outputs, summary tables, Abacus parity coverage, frozen post-model matrix |
| 8. Budget Optimization | 3/3 | Completed | bounded fixed-budget optimizer, parity fixtures, comparison/audit outputs |
| 9. Pipeline | 4/4 | Completed | bounded time-series-first MCMC runner, CLI, and full Stage `00`-`70` contract |
| 10. Plotting | 3/3 | Completed | CairoMakie diagnostic, post-model, optimization, and deterministic bundle plotting surface |
| 11. Validation and Benchmarks | 3/3 | Completed | validation infrastructure, benchmark runner, published snapshot, and release-readiness docs |
| 12. Parity Remediation | 4/4 | Completed | scaling/model-space parity, Stage 60 curve parity, Stage 70 verification, coherent holiday/design contract, and final revalidation/release reconciliation landed |
| 13. Prediction-State and Contract Remediation | 6/6 | Completed | fitted trend/holiday prediction-state repair, media input contract hardening, pipeline YAML contract hardening, and final release-gate revalidation landed |
| 14. Abacus Parity Recovery | 5/5 | Plan complete | `timeseries`, `geo_panel`, and `geo_brand_panel` demo-backed evidence spine; `timeseries` pipeline Stage `00`-`70` artifact-key parity; `geo_panel` and `geo_brand_panel` pipeline Stage `00`, Stage `20`, Stage `30`, Stage `40`, Stage `50`, Stage `60`, and explicitly enabled Stage `70` historical-share optimization coverage, with panel Stage `35` deferred |
| 15. Calibration Likelihood Integration | 8/8 | Completed | bounded `TimeSeriesMMM` MCMC lift-test and cost-per-target calibration likelihood integration landed; panel, VI, broader saturation, UI, and advisor surfaces remain out of scope |
| 16. Scenario Planner Manual Allocation Evaluation | 4/4 | Completed | current/manual/fixed-budget scenario specs, manual-allocation response evaluation, and current/manual/optimized comparison with mismatch rejection landed |
| 17. Calibration YAML And Pipeline Integration | 4/4 | Completed | bounded public time-series calibration parsing, construction, and MCMC pipeline fit-stage threading landed |
| 18. Scenario Store Artifacts | 4/4 | Completed | local typed scenario-store artifacts and CSV inspection sidecars landed for existing non-UI scenario plans |
| 19. Public API Export Hygiene | 4/4 | Completed | public export inventory and focused guard landed without changing exports |
| 20. Public API Docstring Guard | 4/4 | Completed | exported public-symbol docstring and Documenter `@docs` coverage guard landed |
| 21. Public API Export Triage | 5/5 | Completed | lifecycle triage register and focused guard landed for current exports |
| 22. Public API Export Cleanup RFC | 5/5 | Completed | candidate-only cleanup RFC and focused RFC/register guard landed |
| 23. Runtime Deprecation Design | 4/4 | Completed | runtime-deprecation design contract landed for six validation-helper candidates |
| 24. Runtime Deprecation Wrappers | 5/5 | Completed | runtime warnings landed for six direct validation-helper calls while internal callers stay warning-free |
| 25. Focused Test File Harness | 4/4 | Completed | single-file `Pkg.test` selector and `make test-file FILE=...` helper landed |
| 26. Deprecated Validation Helper Migration Audit | 4/4 | Completed | migration-readiness audit and focused guard landed; helpers remain exported |
| 27. Scope Boundary Reconciliation | 4/4 | Completed | MCMC-only v1 inference boundary, dashboard/AI out-of-scope table, release-doc and planning guardrails; inference retirement later completed in Phase 38 |
| 28. Toy MCMC Smoke Demo | 4/4 | Completed | tiny synthetic `TimeSeriesMMM` MCMC smoke demo, callable toy entry point, optional compact summaries, and focused example test landed |
| 29. Toy MCMC Path Hardening | 4/4 | Completed | CLI malformed-integer errors, `-h`/`--help`, include-safety evidence, focused docs, and toy test hardening landed |
| 30. CSV Time-Series MCMC Quickstart | 4/4 | Completed | fixed-schema CSV time-series MCMC quickstart, strict input guards, and scoped review/verification landed |
| 31. HSGP Time-Index Foundation | 3/3 | Completed | private fixture-backed signed cadence-index helper; HSGP/TVP model support remains missing |
| 32. HSGP Linearised Geometry Foundation | 3/3 | Completed | private fixture-backed deterministic basis/PSD and recommendation foundation; HSGP/TVP model support remains missing |
| 33. HSGP Latent Projection And Positive Multiplier Semantics | 3/3 | Completed | private fixture-backed latent projection, stable softplus, and mean-one positive multiplier helpers landed |
| 34. HSGP Fitted Positive Multiplier Replay | 3/3 | Completed | private fitted positive-multiplier replay state landed without public HSGP support |
| 35. Time-Series HSGP Media Methodology Contract | 3/3 | Completed | reviewed TimeSeriesMMM-only shared-media multiplier contract landed as planning-only methodology work |
| 36. Time-Series HSGP Shared Media Multiplier | 5/5 | Completed | bounded TimeSeriesMMM shared HSGP media multiplier landed with retained prediction state and strict wider-surface rejection |
| 37. HSGP Time-Series Contribution Replay | 4/4 | Completed | fitted-period HSGP contribution and decomposition replay landed for the Phase 36 retained training grid |
| 38. Permanent VI Surface Retirement | 4/4 | Completed | `VariationalConfig`, `approximate_fit!`, VI source/tests, and legacy config/artifact acceptance removed; MCMC/Turing is the sole fitting path |
| 39. Supported-Path Smoke Certification | 1/1 | Completed | local `make smoke` command landed for toy MCMC and CSV quickstart supported-path smoke checks |
| 40. Planning Truth Reconciliation | 1/1 | Completed | project-control docs reconciled after Phase 39 without runtime, test, example, benchmark, release, manifest, dependency, or parity-status changes |
| 41. Supported-Path Output Usability Audit | 1/1 | Completed | toy and CSV example sidecar outputs audited, documented, and guarded with focused content-contract tests without model, source, benchmark, release, or parity-status changes |
| 42. Supported-Path Artifact Roundtrip Audit | 1/1 | Completed | bounded toy and CSV fitted-model/grouped-results roundtrip audit landed using existing trusted-local persistence APIs only |
| 43. Supported-Path User Workflow Runbook | 1/1 | Completed | docs-only canonical runbook landed for toy, CSV, compact-output, trusted-local artifact roundtrip, and local smoke workflows |
| 44. Current Docs Truth Reconciliation | 1/1 | Completed | docs-only reconciliation of stale current-facing status wording landed after Phase 43 |
| 45. Current Docs Claim Guard | 1/1 | Completed | focused guard landed for current-facing docs claim boundaries, with future Abacus-reference decoupling preserved as separate planned identity work |
| 46. Abacus Reference Decoupling Plan | 1/1 | Completed | inventory and classification plan landed for future Epsilon-first public identity cleanup |
| 47. Public Identity Rewrite | 1/1 | Completed | Epsilon-first public identity wording landed across root docs, selected user docs, and example READMEs while preserving fixture-backed validation provenance and adding a focused dependent-product phrase guard |
| 48. Internal Provenance Rename Assessment | 1/1 | Completed | planning-only assessment landed for remaining Abacus-named fixture, exporter, demo, source, and ledger surfaces; future fixture migration must be alias-first with visible provenance, demo path migration needs a result-sidecar policy, and ledger rename is post-v1 only |
| 49. Convolution Overlap Parity Lock | 1/1 | Completed | suspected even-length `Overlap` bug was disproved against local Abacus; current numerics preserved, explicit length-4 parity-lock test added, and the dead `overlap_shift` source-index parameter removed |
| 50. Trend And Holiday Prediction-State Lock | 1/1 | Completed | fitted `TimeSeriesMMM` future prediction now has focused integration evidence that trend origin/scale and automatic-holiday default period state are read from the fitted artifact spec rather than recomputed from holdout data or mutable live config |
| 51. Public Config Top-Level Typo Guard | 1/1 | Completed | direct public model config parsing now rejects unsupported top-level keys with deterministic errors, preserves only narrow `effects`/`validation` allowances, and pipeline config strips already allowed runner-only blocks before model parsing |
| 52. Saturation Media Domain Contract | 1/1 | Completed | spend-domain centred-logistic/logistic and Michaelis-Menten saturation reject negative `x`, signed tanh remains reference-backed, and MMM media/curve boundaries keep nonnegative spend checks |
| 53. JuMP Nonlinear Operator Migration | 1/1 | Completed | optimisation moved from legacy JuMP nonlinear registration/objective APIs to the newer nonlinear operator path |
| 54. Optimization Projection Tolerance Guard | 1/1 | Completed | optimiser projection tolerance and residual handling now fail closed instead of silently returning infeasible allocations |
| 55. API Export Hub Decomposition Assessment | 1/1 | Completed | package-entry decomposition was assessed; small structural cleanup was selected over internal submodule churn |
| 56. Export Declarations Extraction | 1/1 | Completed | public export declarations moved from `src/Epsilon.jl` to `src/exports.jl` with the loaded export set preserved |
| 57. Include Order Documentation | 1/1 | Completed | runtime includes moved to `src/includes.jl` with documented layer ordering and unchanged load order |
| 58. Panel Coordinate Forwarder Ownership | 1/1 | Completed | panel-coordinate forwarders moved to the model layer without changing public exports |
| 59. Calibration Likelihood Fail-Fast Boundary | 1/1 | Completed | calibration payload validation now fails at the public/config boundary before Turing model execution |
| 60. Methodology Docstring Units Clarity | 1/1 | Completed | methodology-facing docstrings clarify binomial adstock provenance and budget/spend units |
| 61. AD-Safety Validation Audit | 1/1 | Completed | model-data validation preserves AD scalar compatibility while keeping ordinary invalid input checks fail-closed |
| 62. Convolution Overlap Contract Clarity | 1/1 | Completed | retained overlap-convolution semantics are documented and locked for odd/even impulse cases |
| 63. Prior Positive-Finiteness Guards | 1/1 | Completed | bounded prior/distribution constructors now reject non-finite or non-positive positive-parameter values |
| 64. Flat Namespace Risk Assessment | 1/1 | Completed | planning-only assessment parks internal submodules until after the first usable release path is stable |
| 65. Export List Domain Grouping | 1/1 | Completed | `src/exports.jl` is grouped by API-domain comments while preserving the exact public export set |
| 66. Planning Truth Reconciliation | 1/1 | Completed | project-control docs reconciled after Phase 65 without runtime, test, docs-site, changelog, parity-ledger, fixture, dependency, benchmark, or release-claim changes |
