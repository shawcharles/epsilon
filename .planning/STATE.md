# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-10)

**Core value:** Deliver a methodologically coherent Bayesian MMM library in
Julia by porting the validated Abacus statistical and methodological
functionality bottom-up and proving parity only where semantics genuinely
match.
**Current focus:** Phase 32 HSGP linearised geometry is planned and reviewed;
implementation has not started. The v1
release boundary remains MCMC/Turing-only for supported inference, while
`VariationalConfig` and `approximate_fit!` remain scaffolded pre-v1 review
exports. Variational inference, dashboard/UI parity, and AI advisor behaviour
remain explicitly out of scope for v1.

## Current Position

**Current Phase:** 32
**Current Phase Name:** HSGP Linearised Geometry Foundation
**Total Phases:** 32
**Current Plan:** Phase 32 plan is independently reviewed and ready for
Three Man Team implementation
**Total Plans in Phase:** 3 tasks
**Status:** Phase 32 is planned at
`.planning/phases/32-hsgp-linearized-geometry-foundation/PLAN.md`. It confines
the next slice to private deterministic HSGP basis/PSD geometry and
recommendation helpers, fixture-backed against Abacus/PyMC. It explicitly
excludes graph construction, Turing, config acceptance, public exports,
prediction, replay, panels, and TVP behaviour; the HSGP/time-varying ledger row
remains `missing`. Phase 31 is complete at
`.planning/phases/31-hsgp-time-index-foundation/PLAN.md`. It adds only the
private, fixture-backed `_infer_hsgp_time_index` cadence primitive: signed
daily offsets from the first supplied training date, explicit off-cadence and
empty-training rejection, and no public export. HSGP/TVP configuration, basis
construction, priors, Turing integration, prediction, and replay remain
unsupported; the HSGP/time-varying ledger row stays `missing`. Phase 30 is
complete at
`.planning/phases/30-csv-timeseries-quickstart/PLAN.md`. It adds the standalone
`examples/csv_mmm/` four-column CSV quickstart, fixed strict parsing and
chronological input guards, one tiny Turing/NUTS path, compact optional output,
and focused tests. This is not a package ingestion API, pipeline feature,
benchmark, release claim, or Abacus parity evidence; it does not touch source,
dependencies, exports, or model semantics. Phase 29 is complete at
`.planning/phases/29-toy-mcmc-path-hardening/PLAN.md`. The phase is bounded to
toy-example ergonomics: CLI malformed-integer error clarity, help/include
non-MCMC evidence, focused test coverage, and toy README/state updates. It
does not touch source runtime semantics, dependency files, exports, Abacus
parity claims, release evidence, benchmarks, VI, dashboard/UI, or AI advisor
surfaces. Phase 28 is complete at
`.planning/phases/28-toy-mcmc-smoke-demo/PLAN.md`. The implementation adds a
tiny synthetic `TimeSeriesMMM` toy MCMC smoke demo under `examples/toy_mmm/`,
with a callable `run_toy_mmm` entry point, optional compact CSV/text summary
outputs, and focused coverage in `test/examples/toy_mcmc_smoke.jl`. The toy
uses the supported Turing/NUTS MCMC path only and is documented as a smoke demo,
not release evidence, not a benchmark, not an Abacus parity claim, and not a
broader support expansion. Phase 27 is complete at
`.planning/phases/27-scope-boundary-reconciliation/PLAN.md`. Release-facing
docs and planning state stop presenting VI as a v1-supported backend.
`.planning/PROJECT.md` contains a marked v1 out-of-scope table for
`variational_inference`, `dashboard_ui`, and `ai_advisor`, each with
`out-of-scope-v1` status. `test/api_exports.jl` guards that table and rejects
legacy active VI support row IDs and phrases across release-facing docs and
planning files while allowing unsupported, out-of-scope, historical-superseded,
and export-existence contexts. `VariationalConfig` and `approximate_fit!`
remain exported scaffolded surfaces; no source files, dependency files,
runtime warnings, model semantics, or API cleanup candidates changed. Phase 26
is complete at
`.planning/phases/26-deprecated-validation-helper-migration-audit/PLAN.md`.
`.planning/API-EXPORT-CLEANUP-RFC.md` now treats Phase 22 as historical
candidate governance and records the current post-Phase-24 state in a marked
migration audit table. `test/api_exports.jl` parses and guards that table:
unique markers, exact header, exactly six rows, no duplicate symbols, all six
helpers still exported, exact symbol-set and migration-text agreement across
filtered helper exports, triage candidates, RFC candidates, runtime-design
source candidates, and audit rows, `Runtime Warning = landed`,
`Replacement Warning-Free = guarded`, `Ready To Unexport = no`, and non-empty
evidence. The implementation review cleared with no Must Fix items. Phase 25 is complete at
`.planning/phases/25-focused-test-file-harness/PLAN.md`. `test/runtests.jl`
now accepts exact layer selectors as before or bounded file selectors under
`test/`, with explicit rejection for unknown selectors, directories,
`test/runtests.jl`, parent traversal, absolute paths outside `test/`, missing
files, and mixed layer/file mode. `make test-file FILE=...` runs the selected
file inside the package test environment with `--depwarn=yes`. No runtime
source files, model semantics, exports, or Abacus parity claims changed. Phase
24 is complete at
`.planning/phases/24-runtime-deprecation-wrappers/PLAN.md`. The six Phase 22
validation-helper candidates now use public `Base.depwarn` wrappers around
warning-free `_validate_*` helpers. Direct public calls warn and preserve valid
`nothing` returns plus exact invalid `ArgumentError` messages; supported
constructors, loaders, and calibration payload builders remain warning-free.
Exports, `src/Epsilon.jl`, `docs/src/api.md` inventory rows, validation
predicates, modelling semantics, and Abacus parity claims did not change.
Phase 23 is complete at
`.planning/phases/23-runtime-deprecation-design/PLAN.md`. The design document
at `.planning/API-RUNTIME-DEPRECATION-DESIGN.md` records the future
runtime-deprecation implementation contract for the six Phase 22
validation-helper candidates. The key design decision is that later runtime
warnings must use public warning wrappers around warning-free internal
validation helpers, because the current validators are called by supported
constructors and builders. This is design hygiene only; no exports, runtime
warnings, modelling semantics, tests, user-facing docs, or Abacus API parity
claims changed. Phase 22 is complete at
`.planning/phases/22-public-api-export-cleanup-rfc/PLAN.md`. The candidate-only
cleanup RFC at `.planning/API-EXPORT-CLEANUP-RFC.md` marks six exported
validation helpers as planning-level `deprecation-candidate` rows, each with a
concrete migration path to an existing public constructor, loader, or payload
builder workflow. The focused `api_exports` lane now validates the RFC markers,
seven-column header, current/proposed lifecycle cells, exact no-runtime/export
decision text, current export and triage membership, one-to-one
`deprecation-candidate` coverage, and exact migration-text matches between the
RFC and `.planning/API-EXPORT-TRIAGE.md`. This is governance hygiene only; no
exports, runtime deprecation warnings, modelling semantics, or Abacus API
parity claims changed. Phase 21 is complete at
`.planning/phases/21-public-api-export-triage/PLAN.md`. The public API
lifecycle register at `.planning/API-EXPORT-TRIAGE.md` contains one row for
every current loaded export, copying `Domain` and `Support` from
`docs/src/api.md` and classifying conservatively as `keep-public`,
`keep-bounded`, `compatibility`, or `review-before-v1`. There are no
`deprecation-candidate` rows in the original Phase 21 snapshot because no
concrete reviewed migration path was known then. The focused `api_exports` lane
validates the triage table markers, six-column header,
duplicate/missing/stale symbols, inventory membership, Domain/Support matches,
controlled lifecycle values, non-empty rationales, and non-`n/a` migration
notes for any `deprecation-candidate` rows. Phase 20 is complete at
`.planning/phases/20-public-api-docstring-guard/PLAN.md`. The focused
`api_exports` test layer now keeps the Phase 19 inventory/export exact-match
checks and also treats doc lookup failures, `nothing`, and empty rendered docs
as missing documentation. It aggregates missing docstring failures into sorted
symbol lists, scans fenced Documenter `@docs` blocks under `docs/src`, and
requires every inventoried/exported symbol to appear as an exact stripped
`Epsilon.<symbol>` line using `String(symbol)` so bang-suffixed names are
covered. `test/basic.jl` now keeps only the version smoke test, so there is one
authoritative public API documentation guard. The package identity/public
exports ledger row remains `scaffolded`; this is documentation hygiene only,
not Abacus behavioural evidence. Phase 19 is complete at
`.planning/phases/19-public-api-export-hygiene/PLAN.md`. `docs/src/api.md`
now defines support bands and carries the marked machine-checkable public API
inventory, `test/api_exports.jl` compares that inventory exactly against
`Set(Symbol.(names(Epsilon; all = false, imported = false)))` minus `:Epsilon`,
and `docs/make.jl` includes the page in the docs navigation. The package
identity/public exports ledger row remains `scaffolded`; this phase documents
and guards the current surface without removing exports or claiming broad
Abacus API parity. Phase 18 is complete at
`.planning/phases/18-scenario-store-artifacts/PLAN.md`.
Phase 18 was planned
before implementation and the plan was reviewed by a subagent under the Three
Man Team workflow. The landed surface adds `ScenarioStoreArtifact`,
`write_scenario_store`, `load_scenario_store`, `scenario_store_plan`, and
`assert_scenario_store_compatible` for existing `ScenarioPlanResult` tables.
Stores carry trusted model metadata, model spec, coordinate metadata, objective,
channel order, and current-baseline fields; they write a typed
`scenario_store.jls` payload plus CSV inspection sidecars; they reject malformed
tables and incompatible metadata/spec/coordinate/baseline contracts before
comparison; and they remain local Epsilon/Julia-version-bound artifacts rather
than portable or untrusted interchange files. Phase 17 is complete at
`.planning/phases/17-calibration-yaml-pipeline/PLAN.md`. Task 17-01 landed
bounded public dict/YAML parsing for top-level `calibration` blocks:
`model_config_from_dict` and `load_public_config` now store a typed
`TimeSeriesCalibrationInput` in `ModelConfig.extras["calibration"]`, reject
panel and VI-like calibration configs, reject repeated or malformed steps, and
coerce YAML row vectors to the same concrete row types used by programmatic
constructors. Task 17-02 landed constructor threading: `TimeSeriesMMM` consumes
that parsed payload unchanged when constructor calibration keywords are absent,
rejects ambiguous parsed-plus-keyword calibration, preserves programmatic
constructor arguments, and `PanelMMM` rejects parsed calibration explicitly.
Task 17-03 landed bounded time-series MCMC pipeline acceptance: top-level
`calibration` YAML is accepted, `fit.backend` is MCMC/Turing-only, the
time-series metadata/fit path receives parsed calibration through
`ModelConfig`, and panel/VI-like calibration is rejected before fit. Task
17-04 closed docs, changelog, and ledger guardrails: the docs now show the
supported YAML shape and name the remaining unsupported paths, and the broad
calibration ledger row remains `scaffolded`. Phase 16 is complete at
`.planning/phases/16-scenario-planner-manual-allocation/PLAN.md`. Task 16-01
landed `ManualScenarioEvaluationResult` and
`evaluate_manual_scenario(results, scenario)` evaluate one bounded time-series
manual allocation against existing response surfaces without refitting,
re-optimizing, simulating future paths, or adding panel allocation semantics.
Task 16-02 landed evaluated manual scenarios into
`ScenarioPlanResult` totals, channel, allocation, and metadata tables with
explicit `manual_allocation` rows while preserving the existing optimizer-backed
`scenario_plan(::BudgetOptimizationResult)` contract. Task 16-03 landed:
compatible manual evaluations and one solved optimization result can now be
combined into one current/manual/optimized `ScenarioPlanResult` with hard
artifact and baseline mismatch rejection. Task 16-04 closed docs, changelog,
roadmap, state, and ledger guardrails for the bounded Phase 16 surface. Phase 15
Tasks 15-01 through 15-08 are landed.
Tasks 15-01 through
15-03 froze the
`TimeSeriesMMM`-only calibration contract, added typed calibration payloads,
and threaded raw/resolved calibration payloads through construction, fitting,
artifact traceability, serialization, and VI rejection. Task 15-04 added pure,
Turing-independent AD-compatible lift-test log-density helpers. Task 15-05
wired the lift-test term into `_time_series_mmm_model` via
`Turing.@addlogprob!`; Task 15-06 wired the cost-per-target soft-penalty term
into the same model via a second independent `Turing.@addlogprob!` call. Task
15-07 added fixture-backed integration evidence for the accepted combined
centered-logistic lift-test plus cost-per-target time-series MCMC path,
generated from Abacus scaling and graph-helper surfaces and verified against a
conditioned Turing logjoint. Task 15-08 closed user-facing docs, changelog,
ledger, and guardrail wording while deliberately keeping the calibration row
`scaffolded` because panel, VI, non-logistic lift-test saturation, Dash/UI, and
AI-advisor paths remain outside the bounded slice. Phase 13 contract/remediation issues
are fixed and revalidated; Plan 14-05 remains closed with parity audit
recorded. Release preparation remains paused pending final release-prep
decisions. The project has reset its
planning contract around `.planning/ABACUS-PARITY-LEDGER.md`: existing modules
are treated as `ported`, `native`, `scaffolded`, `missing`, or `deferred`
instead of being assumed Abacus-equivalent from phase completion alone. Plan
14-01 and 14-02 have landed the Abacus `timeseries` config/data fixture spine
plus a controlled deterministic posterior replay gate for contributions,
decomposition, response curves, and metric tables. Plan 14-03 has now landed
the Abacus `geo_panel` config/data fixture gate, panel-indexed model-core
semantics for scaling, alpha, beta-media, intercept, sigma, panel Fourier
seasonality, native pooled panel holidays, and deterministic panel
contribution/decomposition replay. Plan 14-04 has now landed the
`geo_brand_panel` multidimensional config/data fixture gate, deterministic
flattened panel-cell ordering for `("geo", "brand")`, model-spec coordinate
metadata, panel-indexed prior dimensions, runtime artifact-schema checks, and
deterministic multidimensional contribution/decomposition replay. Plan 14-05
has started with panel-cell response/metric semantics for `geo_brand_panel`;
the `timeseries` pipeline now validates Abacus-compatible Stage `00` through
Stage `70` artifact keys, using Julia-native serialized artifacts where Abacus
uses backend-specific PyMC/NetCDF files. The `geo_panel` and
`geo_brand_panel` pipelines now cover Stage `00` metadata/manifest parity and
Stage `20` fit artifact-key parity, Stage `30` assessment artifact-key parity,
Stage `40` decomposition artifact-key parity, and Stage `50` diagnostics
artifact-key parity, plus Stage `60` response-curve artifact-key parity. Stage
`70` panel optimization has a bounded v1 policy and implementation for
channel-total allocation with fixed historical within-channel panel-cell
shares, including `geo_panel` and `geo_brand_panel` pipeline artifact
coverage. Stage `35` panel holdout validation is now explicitly deferred for
v1. Plan 14-05 is complete: `timeseries` Stage `00` through Stage `70` is
covered; `geo_panel` and `geo_brand_panel` cover Stage `00`, Stage `20`, Stage
`30`, Stage `40`, Stage `50`, Stage `60`, and explicitly enabled Stage `70`
historical-share optimization, with panel Stage `35` deferred.
Optional Stage `05` prior-sensitivity planning is now also implemented as a
bounded scenario-config and manifest stage; it does not automatically refit
every scenario. The non-UI scenario planner surface now includes typed
current/manual/fixed-budget scenario specs, `scenario_plan(result)` comparison
tables over solved optimization results, time-series manual-allocation
evaluation over existing response surfaces, manual table projection, and
combined current/manual/optimized comparison for compatible artifacts.
Scenario planner local store artifacts are now landed for existing
`ScenarioPlanResult` tables, with typed payload load/replay and compatibility
guardrails.
Calibration/lift-test parity remains a `scaffolded` ledger row after Phase 17:
`TimeSeriesMMM` MCMC model-side likelihood wiring, fixture-backed integration
evidence, public dict/YAML parsing, and bounded time-series pipeline fitting
are landed for both accepted calibration terms, but the wider Abacus
calibration surface is not complete.
**Last Activity:** 2026-07-11
**Last Activity Description:** Phase 32 received an independently reviewed
implementation plan for private fixture-backed HSGP linearised geometry:
frequencies, fixed training basis, square-root PSD weights, and Abacus
recommendation heuristics only. Review tightened the exact covariance formulas,
heuristic constants/defaults, input contracts, fixture discrimination, and AD
boundary. No implementation or HSGP/TVP support claim has been made. Phase 31 added a fixture-backed internal
`Date` cadence-index primitive matched to Abacus `infer_time_index` for daily,
weekly, forward/backward, leap-boundary, and off-cadence cases. It preserves the
first supplied training date as origin, returns signed `Vector{Int}` indices,
and deliberately rejects empty training input with `ArgumentError`. The helper
is unexported and HSGP configuration remains rejected; no HSGP/TVP model,
prior, Turing, prediction, or replay behaviour was added. Phase 30 added a fixed-schema CSV
`TimeSeriesMMM` quickstart under `examples/csv_mmm/`. The internal example
loader requires `date,sales,tv,search`, parses ISO dates strictly, rejects
missing/malformed/non-finite values and duplicate dates with column-specific
errors, sorts accepted rows chronologically, and uses the existing bounded
Turing/NUTS MCMC path. Focused coverage includes the loader contract, CLI/help,
include safety, optional compact output files, and a tiny MCMC smoke run. No
source/runtime files, dependency files, exports, pipeline semantics, benchmarks,
release claims, or Abacus parity claims changed.
**Progress:** 100%
**Paused At:** `.planning/phases/32-hsgp-linearized-geometry-foundation/PLAN.md`

## Performance Metrics

**Velocity:**
- Formal timing metrics are not being tracked yet.
- Use milestone status and completed plan checklists as the authoritative progress signal.

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 3 | Completed | n/a |
| 2 | 4 | Completed | n/a |
| 3 | 3 | Completed | n/a |
| 4 | 5 | Completed | n/a |
| 5 | 4 | Completed | n/a |
| 6 | 4 | Completed | n/a |
| 7 | 3 | Completed | n/a |
| 8 | 3 | Completed | n/a |
| 9 | 4 | Completed | n/a |
| 10 | 3 | Completed | n/a |
| 11 | 3 | Completed | n/a |
| 12 | 4/4 | Completed | scaling/model-space parity, Stage 60 curve parity, Stage 70 verification, coherent holiday/design contract, and final revalidation/release reconciliation landed |
| 13 | 6/6 | Completed | fitted trend/holiday prediction-state repair, media-domain validation, pipeline YAML contract hardening, and final release-gate revalidation landed |
| 14 | 5/5 | Plan complete | Abacus parity recovery across `timeseries`, `geo_panel`, and `geo_brand_panel` demo-style acceptance targets |
| 15 | 8/8 | Completed | `TimeSeriesMMM` MCMC calibration likelihood wiring, fixture-backed integration evidence, docs, changelog, and ledger guardrails landed for lift-test and cost-per-target terms |
| 16 | 4/4 | Completed | bounded non-UI manual-allocation evaluation, scenario-plan table projection, combined current/manual/optimized comparison, and docs/changelog/ledger guardrails landed |
| 17 | 4/4 | Completed | bounded calibration YAML/dict parsing, time-series constructor threading, time-series MCMC pipeline fit-stage support, and docs/changelog/ledger guardrails landed |
| 18 | 4/4 | Completed | local scenario-store artifacts for existing `ScenarioPlanResult` tables, CSV inspection sidecars, compatibility guardrails, and docs/changelog/ledger closure landed |
| 19 | 4/4 | Completed | public API support inventory, docs navigation, focused export guardrail, and conservative changelog/planning/ledger closure landed |
| 20 | 4/4 | Completed | public API docstring and Documenter `@docs` coverage guard landed as documentation hygiene only |
| 21 | 5/5 | Completed | public API lifecycle triage register and focused guard landed as governance hygiene only |
| 22 | 5/5 | Completed | candidate-only public API cleanup RFC and focused RFC/register guard landed; no runtime or export changes |
| 23 | 4/4 | Completed | runtime deprecation design contract landed for the six Phase 22 validation-helper candidates; no runtime or export changes |
| 24 | 5/5 | Completed | runtime deprecation wrappers landed for the six validation-helper candidates; constructors/loaders/builders stay warning-free; no export or parity-status changes |
| 25 | 4/4 | Completed | focused package-test file selectors and `make test-file FILE=...` landed for single-file local verification with test-only dependencies available |
| 26 | 4/4 | Completed | migration-readiness audit and focused guard landed for the six deprecated validation-helper exports; no export or runtime changes |
| 27 | 4/4 | Completed | MCMC-only v1 inference boundary, explicit VI/dashboard/AI out-of-scope table, release-doc and planning guardrails |
| 28 | 4/4 | Completed | toy `TimeSeriesMMM` MCMC smoke demo and focused example test landed; no source/runtime or dependency changes |
| 29 | 4/4 | Completed | toy CLI/input hardening, help/include safety, and focused regression coverage landed |
| 30 | 4/4 | Completed | fixed-schema CSV time-series MCMC quickstart, strict input guards, and scoped review/verification landed |

**Recent Trend:**
- Last 5 completed plans: `14-01`, `14-02`, `14-03`, `14-04`, `14-05`
- Trend: Phase 12 closed the methodology-remediation pass, and Phase 14 has
  started rebuilding Abacus parity evidence from the `timeseries` demo-style
  config/data and deterministic replay gates, then expanded the evidence spine
  to `geo_panel` config/data, panel-indexed model-core semantics, and bounded
  deterministic panel replay. The evidence spine now includes
`geo_brand_panel` multidimensional config/data, dimension-order, model-spec,
runtime artifact-schema, controlled contribution/decomposition replay, and
panel-cell response/metric coverage. Pipeline recovery now exports Abacus's
`timeseries` pipeline contract and validates Epsilon's Stage `00` through
Stage `70` artifact keys against it, while preserving Julia-native file formats
where direct PyMC/NetCDF identity would be misleading. The pipeline evidence
spine now also includes `geo_panel` and `geo_brand_panel` Stage `00`
  metadata/manifest parity, Stage `20` fit artifact-key parity, Stage `30`
  assessment artifact-key parity, and Stage `40` decomposition artifact-key
  parity plus Stage `50` diagnostics artifact-key parity, with unsupported panel
  stages intentionally skipped; Stage `60` response-curve artifact-key parity is
  now also covered with explicit `delta_grid` historical-scaling semantics, and
  Stage `70` has a bounded historical-share optimization artifact path
  covering both `geo_panel` and `geo_brand_panel`.

## Decisions Made

| Phase | Summary | Rationale |
|-------|---------|-----------|
| Bootstrap | Convert existing milestone and architecture docs into a real GSD roadmap | The repo had planning content but no executable planning backbone |
| 1 | Do foundation work before numerical porting | Docs, tests, and package structure should stabilize before deeper model work |
| Bootstrap | Keep the port strategy bottom-up | Lower layers enable parity tests and reduce ambiguity for higher layers |
| 1 | Treat passing local quality gates as the real Phase 1 exit criterion | The repo already had scaffold files, but `make test` and `make docs` had to become true before Phase 2 work |
| 2 | Use generated Julia fixtures from local Abacus runs instead of Python during Julia tests | Keeps parity tests deterministic and keeps Python out of the Julia test runtime |
| 3 | Represent prior config as Julia-native `EpsilonPrior` objects before wiring Turing-specific model code | Keeps Phase 3 testable without coupling config parsing to the eventual model builder |
| 3 | Treat current Abacus special priors as config/runtime compatibility objects first and defer Turing-specific plate behavior to Phase 4 | Preserves momentum while avoiding premature coupling to the unfinished model layer |
| 3 | Do not invent unsupported Abacus custom distributions when the upstream code only exposes a transform or helper concept | Keeps the port anchored to real behavior instead of stale milestone wording |
| 3 | Represent shrinkage priors as recipe objects plus deterministic helper math before the Turing model layer exists | Lets Phase 3 validate serialization and core formulas without faking full probabilistic-program integration |
| 3 | Close Michaelis scope at the saturation layer rather than inventing a separate prior/distribution type | The upstream port target exposes Michaelis-Menten as a transform, so a standalone distribution would add unsupported surface area |
| 4 | Introduce typed config and data containers before building Turing model orchestration | Keeps Phase 4 testable in slices and reduces ambiguity before sampler/builder code lands |
| 4 | Defer richer grouped results export to Phase 6 instead of keeping it in late Phase 4 | Grouped export depends on broader inference/reporting hardening and would blur the Model Core boundary |
| 5 | Start 05-02 with one bounded linear-trend path instead of jumping directly to time-varying trend or events | Keeps the first additive feature slice honest, testable, and aligned with the current `TimeSeriesMMM` contract |
| 5 | Use a bounded piecewise-linear changepoint trend as the first supported time-varying trend path and keep intercept ownership at the model level | Preserves the upstream trend shape while excluding the terminal unidentified changepoint coefficient and avoiding a second competing intercept contract on `TimeSeriesMMM` |
| 5 | Use `PanelMMM` plus centered panel intercept offsets as the first supported panel slice | Lands a real panel/hierarchical path without overloading `TimeSeriesMMM` or pretending broader panel feature support already exists |
| 5 | Freeze Phase 5 as a supported feature-bundle matrix rather than an implied combinatorial surface | Keeps the package contract honest and makes closeout testable without inventing unsupported combinations |
| 6 | Fix the canonical grouped inference artifact contract as Julia-native `InferenceResults` and defer NetCDF / ArviZ-native interchange from Phase 6 | Removes implementation-time ambiguity before grouped export, VI, and Phase 7 consumers depend on the artifact surface |
| 6 | Historical decision: keep VI visible via `approximate_fit!` and `VariationalConfig`, with the YAML `fit` block remaining MCMC-only | Superseded by Phase 27 for v1 release support: those exports remain scaffolded pre-v1 review surfaces, while MCMC/Turing is the only supported v1 inference path |
| 6 | Freeze the inference support matrix explicitly instead of leaving backend availability implicit in docs and tests | Makes the Phase 6 contract truthful before Phase 7 consumes it |
| 7 | Keep Phase 7 post-modeling time-series first and consume canonical `InferenceResults` directly | Avoids reopening inference contracts or inventing premature panel decomposition/response semantics |
| 7 | Carry resolved standardized-control replay state inside `MMMModelSpec.controls` instead of widening `InferenceResults` | Keeps deterministic replay faithful for grouped `new_data` artifacts while preserving the frozen grouped-artifact contract |
| 8 | Use one bounded fixed-budget time-series-first optimization contract via `JuMP.jl + Ipopt.jl` | Removes solver/objective ambiguity before Phase 8 implementation and keeps optimization downstream of the frozen Phase 7 response/metric surface |
| 9 | Keep the Phase 9 pipeline time-series first, MCMC-only, and Julia-native in its artifact/output contract | Avoids reopening panel, VI, and NetCDF/report semantics while the first disk-backed runner is being landed |
| 9 | Land `run_pipeline(config)` first as a truthful pending scaffold rather than pretending Stage `00`-`70` execution already exists | Keeps the Phase 9 contract executable at `09-01` without misrepresenting later stage behavior |
| 9 | Switch the top-level pipeline run status to `:completed` only once the full enabled Stage `00`-`70` surface succeeds | Preserves a truthful completed-run contract after `09-03` without blurring partial and full pipeline execution |
| 11 | Distinguish Abacus parity rows from bounded Epsilon-only validation rows in the final release gate | Keeps Phase 11 honest about what is truly comparable to Abacus and what should instead pass contract-regression checks |
| 12 | Reopen the roadmap for methodology remediation before any release branch or tag | The methodology audit found a structural model-space divergence from Abacus, so release preparation must pause until the bounded methodology and reference claims are repaired truthfully |
| 13 | Reopen planning for prediction-state and config-contract remediation before release prep | The external code review found concrete risks in trend/holiday holdout replay, media-domain validation, and pipeline YAML parsing that can mislead users or invalidate release behavior |
| 14 | Reset release readiness around the Abacus parity ledger | Demo-backed parity is required before broad release claims; historical phase completion is not sufficient evidence |
| 27 | Keep v1 inference support MCMC-only and mark VI, dashboard/UI parity, and AI advisor behaviour out of scope for v1 | Removes the contradiction between historical VI implementation work and the current release boundary without removing exports or changing runtime behaviour |
| 14 | Defer only AI advisor and Dash/dashboard parity by default | Epsilon is a Julia port of Abacus statistical and methodological functionality; other Abacus surfaces remain in scope unless the parity ledger explicitly says otherwise |
| 14 | Promote one-dimensional `geo_panel` replay to accepted deterministic gate | Panel contribution/decomposition replay now reconstructs original-scale panel artifacts from controlled posterior fixtures, but multidimensional panel and downstream response/optimization parity remain separate slices |
| 14 | Flatten multidimensional panel cells while retaining declared panel dimensions in metadata | Epsilon keeps the bounded sampler and replay internals on one panel-cell axis, but `geo_brand_panel` metadata preserves Abacus `("geo", "brand")` ordering and coordinate values for honest artifact schemas |
| 14 | Prefer explicit Epsilon-native method names when Abacus-inspired naming is misleading | `centered_logistic_saturation` names the actual zero-baselined logistic-family curve while the older `logistic_saturation` API remains as a compatibility alias |
| 14 | Expose panel coordinate reconstruction as a small public helper surface | `PanelCoordinate` and `panel_coordinates` make the flat panel-cell axis inspectable without changing model/result schemas or sampler tensors |
| 14 | Make panel observation-count semantics explicit | `ntime`, `npanels`, and `npanel_observations` distinguish shared time rows from flattened panel-cell observations while preserving `nobs(::PanelMMMData)` compatibility |
| 14 | Add ordered panel-axis metadata | `PanelAxis`, `panel_axis`, and `panel_axes` make `panel_cell` the explicit flat artifact axis while keeping declared coordinate columns in model order |

## Pending Todos

- Phase 26 is complete; the six deprecated validation-helper exports remain
  exported and not ready to unexport, with migration-audit consistency guarded
  by `test/api_exports.jl`.
- Phase 28 is complete; do not treat the toy smoke demo as release evidence,
  benchmark evidence, Abacus parity evidence, or a broader support expansion.
- Phase 29 is complete; keep the toy path a smoke demo only, not release
  evidence, benchmark evidence, Abacus parity evidence, or a broader support
  expansion.
- Phase 25 is complete; prefer `make test-file FILE=...` or
  `Pkg.test(; test_args=[...], julia_args=["--depwarn=yes"])` for focused
  single-file verification when files use test-only dependencies.
- Phase 24 is complete; direct calls to the six validation-helper candidates
  now warn, but the `deprecation-candidate` rows are still not export removals
  or stable v1 API decisions.
- Phase 22 remains candidate-only for export cleanup; no unexport/removal phase
  has landed.
- Phase 31 is complete. The next HSGP/TVP slice must start with a separate
  methodological contract for basis construction and parameter semantics; do
  not infer HSGP support from the private cadence-index helper.
- Phase 32 is planned and independently reviewed. Keep implementation private
  and numerical only; do not accept HSGP config or add graph/model semantics.
- Phase 15 calibration likelihood integration is closed; keep the calibration
  row `scaffolded` until a separate contract implements panel,
  broader saturation-family, or UI calibration paths. VI calibration remains
  outside v1 because variational inference itself is out of scope for v1.
- Keep Stage `35` panel holdout validation deferred unless a concrete
  methodological requirement and fixture-backed contract are added.
- Do not force free channel-by-panel allocation, panel-total bounds, fairness
  constraints, or aggregate panel budget semantics into the pipeline before a
  separate validity contract exists.
- Keep Phase 13 remediation behavior protected by focused regression tests as
  downstream release-prep and demo acceptance work continues.
- Prepare the actual release branch / tag workflow only after Phase 14
  demo-backed acceptance closes.
- Refresh the benchmark snapshot from a clean worktree before publishing a
  release artifact.

## Blockers

- Release branch/tag work is blocked on final release-prep decisions and a
  clean benchmark snapshot, not on Phase 13 remediation.
- Broad Abacus parity claims beyond the ledger-backed `timeseries`,
  `geo_panel`, and `geo_brand_panel` evidence spine remain blocked on explicit
  acceptance evidence.
- Repo-wide `make format-check` is now clean after the formatter-only Runic
  drift cleanup. Keep day-to-day verification scoped; do not run the full suite
  for future formatter-only changes.
- The clean-worktree benchmark rerun remains outstanding if maintainers want a
  release artifact without the current published `git_dirty = true` note.

## Accumulated Context

### Roadmap Evolution

- Phase 13 added: Prediction-State and Contract Remediation
- Abacus parity ledger added as the new release-readiness roadmap; module
  completion is no longer sufficient evidence for Abacus parity.
- Phase 14 added: Abacus Parity Recovery

## Session

**Last Date:** 2026-07-06
**Stopped At:** Phase 26 is complete. The deprecated validation-helper
migration audit is recorded and guarded; choose the next bounded release-prep
slice before making export removals or broader v1 API claims.
**Resume File:** `.planning/phases/26-deprecated-validation-helper-migration-audit/PLAN.md`
