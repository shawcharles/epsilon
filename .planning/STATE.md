# Project State

## Project Reference

See: .planning/PROJECT.md

**Core value:** Deliver a methodologically coherent Bayesian MMM library in
Julia by using validated reference behavior where it is methodologically
meaningful, proving comparison claims only where semantics genuinely match, and
letting Epsilon stand as an independent Julia MMM library.
**Current focus:** Phase 47 Public Identity Rewrite is complete. Epsilon's
public-facing root docs, selected user docs, and example READMEs now use
Epsilon-first identity language while preserving fixture-backed validation
provenance.

## Current Position

**Current Phase:** 47
**Current Phase Name:** Public Identity Rewrite
**Total Phases:** 47
**Current Plan:** `.planning/phases/47-public-identity-rewrite/PLAN.md`
**Total Plans in Phase:** 1 docs-and-guardrail public identity slice
**Status:** Phase 47 is complete. The public-facing README, contributor and
standards docs, selected Documenter pages, and example READMEs now present
Epsilon as an independent Julia MMM library with comparison-backed validation
where semantics match, rather than as an Abacus clone or Julia port. The
release-gate docs still preserve `VAL-TS-00-MCMC`, committed Abacus-derived
fixture provenance, and the Epsilon-native/reference-row distinction.
`test/api_exports.jl` now guards against reintroducing active dependent-product
phrasing such as "Abacus Julia port" while still allowing fixture paths and
validation provenance. The Phase 46 inventory table was corrected to stop
counting ignored `docs/build/` output. No runtime source, model semantics,
benchmarks, smoke harness, full suite, dependencies, manifests, or parity
status changed.

Phase 46 is complete. The phase inventories and classifies current Abacus
references so Epsilon can move towards Epsilon-first public identity language
without prematurely deleting or renaming fixture, exporter, parity ledger, or
historical validation provenance. The authoritative tracked-file inventory
records 172 files and 1821 matches, excluding `Manifest.toml`, `.jls`
artifacts, and the Phase 46 plan itself. No runtime, example, benchmark, smoke,
full suite, release, runtime-source, dependency, manifest, model-semantics, or
parity-status changes were made.

Phase 40 is complete. It reconciled `.planning/PROJECT.md`,
`.planning/ROADMAP.md`, `.planning/STATE.md`, and its own phase plan so the
control docs no longer present closed Phase 13, Phase 14 / Plan 14-05, Phase 38,
or Phase 39 work as pending. No runtime, test, example, benchmark, release,
manifest, dependency, or parity-status files changed.

Phase 39 is complete. It adds `scripts/smoke_supported_paths.sh` and
`make smoke` as a local supported-path smoke command for the toy MCMC and
fixed-schema CSV quickstart examples. The harness runs both examples with
small MCMC settings, writes outputs only to temporary directories, checks
non-empty compact summaries, and verifies `status=fit` plus `backend=turing`.
The phase did not add benchmarks, release evidence, Abacus parity claims, new
ingestion APIs, or new modelling surface. Independent plan review approved the
contract before implementation. Scoped verification passed:
`bash -n scripts/smoke_supported_paths.sh`, `make smoke`,
`make test-file FILE=test/examples/toy_mcmc_smoke.jl` (`92 / 92`), and
`make test-file FILE=test/examples/csv_mmm_quickstart.jl` (`114 / 114`).
Phase 38 is complete. It removed the public/runtime variational
surface, deleted the VI source and test leaf, made MCMC/Turing the sole fitting
contract, rejects retired configuration and artifact backend input, and retains
MCMC coverage at each former consumer boundary. Independent implementation
review approved the landed contract. A closure-gate regression in the synthetic
HSGP guard fixture was fixed by marking its chain-bearing artifact as a fitted
deterministic `:fixture`, then independently approved. The final
phase-closing `make check-full` gate passed `9925 / 9925` tests in `23m33.1s`
and completed the docs build successfully. Phase 37 permits grouped-posterior
`contribution_results` and
`decomposition_results` only for the exact retained TimeSeriesMMM HSGP training
grid. Each draw rebuilds the shared multiplier from immutable spec state and
the named HSGP posterior parameters after beta weighting and before target
unscaling. Non-media terms remain unchanged. The implementation rejects missing
HSGP draws and nonmatching observed-date sequences, including cadence-aligned
unseen, reordered, and duplicate dates. Curves, metrics, panels, YAML/pipeline,
optimisation, calibration, VI, generic HSGP, and TVP remain unsupported; the
HSGP/TVP ledger row remains `missing`. Independent implementation review found
no Must Fix or Should Fix items. The three focused tests passed, followed by
the one phase-closing `make check-full` gate: `10,055 / 10,055` tests in
`23m12.7s` and a successful docs build. Phase 36 is complete at
`.planning/phases/36-timeseries-hsgp-shared-media-multiplier/PLAN.md`. Phase 35 is complete at
`.planning/phases/35-timeseries-hsgp-media-methodology-contract/PLAN.md`. It
freezes the reviewed Phase 36 contract for a TimeSeriesMMM-only shared HSGP
media multiplier: explicit cadence/unit/prior rules, fixed geometry switches,
named non-centred Turing variables, retained training origin/index state,
schema-v2 migration, and strict wider-surface rejection. It is planning only:
no runtime source, tests, exports, YAML acceptance, dependencies, or HSGP/TVP
ledger status changed. Phase 36 subsequently implemented that contract and
closed without promoting the HSGP/TVP ledger row. Phase 34 is complete at
`.planning/phases/34-hsgp-fitted-positive-multiplier-replay/PLAN.md`. It adds
only a private, immutable concrete-draw replay state that preserves the HSGP
training centre, optional training basis offset, and training raw-softplus
mean. It excludes priors, graph construction, Turing, config acceptance,
public exports, prediction APIs, serialization, panels, and TVP behaviour; the
HSGP/time-varying ledger row remains `missing`. The implementation is reviewed;
focused verification passed `58 / 58`, and the one phase-closing `make test`
shared-namespace checkpoint passed `8,678 / 8,678` in `20m57.0s`. Phase 33 is
complete at
`.planning/phases/33-hsgp-softplus-positive-multiplier/PLAN.md`. It adds only
private, fixture-backed latent projection, PyTensor-thresholded softplus, and
time-axis mean-one positive multiplier helpers for supplied HSGP coefficient
values. It explicitly excludes priors, graph construction, Turing, config
acceptance, public exports, prediction, replay, panels, and TVP behaviour;
the HSGP/time-varying ledger row remains `missing`. The implementation was
independently reviewed; focused verification passed `46 / 46`, and the one
phase-closing `make test` shared-namespace checkpoint passed `8,620 / 8,620`
in `20m24.2s`. Phase 32 is complete at
`.planning/phases/32-hsgp-linearized-geometry-foundation/PLAN.md`. It confines
the slice to private deterministic HSGP basis/PSD geometry and recommendation
helpers, fixture-backed against Abacus/PyMC. It explicitly excludes graph
construction, Turing, config acceptance, public exports, prediction, replay,
panels, and TVP behaviour; the HSGP/time-varying ledger row remains `missing`.
Phase 31 is complete at
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
`permanently-retired` status for variational inference. `test/api_exports.jl` guards that table and rejects
legacy active VI support row IDs and phrases across release-facing docs and
planning files while allowing unsupported, out-of-scope, historical-superseded,
and historical contexts. The former variational exports were permanently
removed in Phase 38; no dependency files, MCMC semantics, or API cleanup
candidates changed. Phase 26
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
**Last Activity:** 2026-07-19
**Last Activity Description:** Phase 46 landed a reviewed planning-only
Abacus-reference decoupling plan. The plan records a tracked-file inventory,
classification contract, and future implementation sequence for public identity
cleanup, while keeping actual scrubbing, fixture renames, exporter changes, and
parity-ledger renames out of scope.
**Progress:** 100%
**Paused At:** `.planning/phases/46-abacus-reference-decoupling/PLAN.md`

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
| 31 | 3/3 | Completed | private fixture-backed HSGP cadence-index helper landed without HSGP/TVP support claims |
| 32 | 3/3 | Completed | private deterministic HSGP basis/PSD and recommendation foundation landed without graph/config/model support |
| 33 | 3/3 | Completed | private fixture-backed HSGP latent projection, stable softplus, and mean-one positive multiplier helpers landed |
| 34 | 3/3 | Completed | private fitted positive-multiplier replay state landed without public HSGP support |
| 35 | 3/3 | Completed | reviewed TimeSeriesMMM-only shared HSGP media multiplier methodology contract landed as planning-only work |
| 36 | 5/5 | Completed | bounded TimeSeriesMMM shared HSGP media multiplier landed with retained prediction state and strict wider-surface rejection |
| 37 | 4/4 | Completed | fitted-period HSGP contribution and decomposition replay landed for the retained training grid |
| 38 | 4/4 | Completed | variational inference surface permanently retired; MCMC/Turing is the sole fitting path |
| 39 | 1/1 | Completed | local supported-path smoke command landed for toy MCMC and CSV quickstart examples |
| 40 | 1/1 | Completed | planning truth reconciliation landed without runtime, test, example, benchmark, release, manifest, dependency, or parity-status changes |
| 41 | 1/1 | Completed | supported-path example output sidecars audited, documented, and guarded with focused content-contract tests |
| 42 | 1/1 | Completed | supported-path fitted-model and grouped-results roundtrips guarded for toy MCMC and CSV quickstart examples |
| 43 | 1/1 | Completed | canonical supported local workflow runbook landed with docs navigation and example README links |
| 44 | 1/1 | Completed | current-facing docs reconciled with Phase 43 state without runtime or release-surface changes |
| 45 | 1/1 | Completed | focused current-docs claim guard landed; future Abacus-reference decoupling noted as separate identity work |
| 46 | 1/1 | Completed | tracked-file inventory and classification plan landed for future Epsilon-first public identity cleanup |

**Recent Trend:**
- Last 5 completed phases: 42, 43, 44, 45, 46.
- Trend: the recent work narrowed rather than widened the library contract.
  Phase 41 made the supported-path sidecar
  output contract more inspectable and better tested. Phase 42 guarded
  trusted-local fitted-model and grouped-results roundtrips. Phase 43 documented
  the supported local workflow without widening runtime support, and Phase 44
  reconciled current-facing docs so they no longer point future work at stale
  Phase 12/40 status. Phase 45 added a focused guard over those claims rather
  than another docs rewrite.
  Phase 46 converted the Abacus public-identity concern into a reviewed
  tracked-file inventory and future rewrite plan, without touching runtime or
  validation provenance.

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
| 6 | Historical decision: keep VI visible via `approximate_fit!` and `VariationalConfig`, with the YAML `fit` block remaining MCMC-only | Superseded by Phase 38: those exports are now permanently removed, and MCMC/Turing is the only fitting path |
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
| 38 | Permanently retire variational inference rather than stabilise it | Epsilon will not own an approximate-inference contract; MCMC/Turing remains the sole fitting path |
| 39 | Add smoke certification as a local supported-path command, not release evidence | Maintainers need a fast confidence command for the toy and CSV examples without confusing it for a benchmark or parity gate |
| 40 | Reconcile planning truth before choosing more work | Current-state docs are part of the project control surface; stale open checkboxes and handoffs create false next actions |
| 41 | Guard example output structure rather than posterior values | Tiny MCMC examples are useful for supported-path confidence, but their tests should stabilise keys, columns, and row counts instead of brittle posterior numerics |
| 42 | Guard trusted-local example artifact roundtrips rather than promise portability | The supported examples should prove fitted objects can survive Epsilon's existing Julia serialization path, but that is not a portable interchange, release, benchmark, or Abacus parity claim |
| 43 | Give supported local workflows one canonical runbook | The toy, CSV, compact-output, artifact-roundtrip, and smoke paths are mature enough to document together, but still must not be recast as release, benchmark, or parity evidence |
| 44 | Keep current-facing docs aligned with state | Stale docs can misdirect future work into false release-prep, benchmark, or parity assumptions even when runtime code is sound |
| 45 | Guard current docs before widening work | Current-facing claim drift is cheap to prevent with a focused test and expensive to untangle after future phases rely on stale wording |

## Pending Todos

- Phase 25 is complete; prefer `make test-file FILE=...` or
  `Pkg.test(; test_args=[...], julia_args=["--depwarn=yes"])` for focused
  single-file verification when files use test-only dependencies.
- Phase 38 is complete; variational inference is permanently retired. Do not
  reintroduce `VariationalConfig`, `approximate_fit!`, VI config acceptance, or
  VI artifact compatibility.
- Phase 39 is complete; keep `make smoke` as local supported-path confidence
  evidence only, not benchmark, release, or Abacus parity evidence.
- Phase 40 is complete; future work should start from the reconciled planning
  docs rather than older Phase 14/26/29 handoff text.
- Phase 41 is complete; toy and CSV sidecar outputs are documented and guarded,
  but remain local supported-path evidence only, not benchmark, release, Abacus
  parity, reporting, or ingestion evidence.
- Phase 42 is complete; toy and CSV fitted-model and grouped-results roundtrips
  are guarded through existing trusted-local APIs, but these artifacts remain
  Julia/Epsilon-version-bound local serialization, not portable interchange or
  release evidence.
- Phase 43 is complete; use `docs/src/supported_paths.md` as the canonical
  supported local workflow runbook for toy, CSV, compact sidecars,
  trusted-local artifact roundtrips, and `make smoke`.
- Phase 44 is complete; current-facing docs now describe the Phase 43 state
  without implying a new release gate, benchmark refresh, or Abacus parity
  certification.
- Phase 45 is complete; current-docs claim guards are in
  `test/api_exports.jl`. Keep this lane focused on current support, release,
  VI, local-workflow evidence, and trusted-local artifact wording.
- Phase 46 is complete as that separate reviewed plan: classify public identity
  language, public evidence boundaries, internal validation provenance,
  historical planning records, API/test implementation details, and dead
  scaffolding before any Abacus-reference scrub. It is now complete.
- Recommended next identity slice: create Phase 47 for the first bounded public
  docs rewrite over `README.md`, selected `docs/src/*.md`, selected example
  READMEs, `CONTRIBUTING.md`, `TECHNICAL-STANDARDS.md`, planning hooks, and a
  focused `test/api_exports.jl` guard. Do not rename fixtures, generated
  constants, exporter scripts, or `.planning/ABACUS-PARITY-LEDGER.md` there.
- HSGP/TVP broader support remains bounded: Phase 36/37 cover only the
  TimeSeriesMMM shared-media multiplier and retained-grid contribution replay.
  Do not add new HSGP/TVP config, prediction, panel, curve, metric, optimization,
  YAML, or pipeline support without a separate reviewed implementation plan.
- Phase 15 calibration likelihood integration is closed; keep the calibration
  row `scaffolded` until a separate contract implements panel,
  broader saturation-family, or UI calibration paths. Variational calibration
  is permanently retired with the inference backend.
- Keep Stage `35` panel holdout validation deferred unless a concrete
  methodological requirement and fixture-backed contract are added.
- Do not force free channel-by-panel allocation, panel-total bounds, fairness
  constraints, or aggregate panel budget semantics into the pipeline before a
  separate validity contract exists.
- Keep Phase 13 remediation behavior protected by focused regression tests.
- Treat release-branch/tag work and benchmark refreshes as explicit future
  decisions, not as the automatic next action.

## Blockers

- There is no current blocker for the completed Phase 40 planning reconciliation
  slice.
- Release branch/tag work remains unstarted and should only proceed after an
  explicit release-prep decision.
- Broad Abacus parity claims beyond the ledger-backed `timeseries`,
  `geo_panel`, and `geo_brand_panel` evidence spine remain blocked on explicit
  acceptance evidence.
- Repo-wide `make format-check` is now clean after the formatter-only Runic
  drift cleanup. Keep day-to-day verification scoped; do not run the full suite
  for future formatter-only changes.
- Benchmark refresh work remains unstarted future work and should only run under
  an explicit benchmark/release plan.

## Accumulated Context

### Roadmap Evolution

- Phase 13 added: Prediction-State and Contract Remediation
- Abacus parity ledger added as the new release-readiness roadmap; module
  completion is no longer sufficient evidence for Abacus parity.
- Phase 14 added: Abacus Parity Recovery
- Phase 38 permanently retired variational inference.
- Phase 39 added local supported-path smoke certification.
- Phase 40 reconciled stale planning truth after Phase 39.
- Phase 41 audited and guarded supported-path example output sidecars.
- Phase 42 audited and guarded trusted-local fitted-model and grouped-results
  roundtrips for the supported toy and CSV examples.
- Phase 43 added the canonical supported local workflow runbook and cross-links.
- Phase 44 reconciled current-facing docs after Phase 43.
- Phase 45 added focused guards for current-facing docs claims.
- Phase 46 landed the Abacus-reference decoupling plan.

## Session

**Last Date:** 2026-07-19
**Stopped At:** Phase 46 is complete. The next recommended slice is a reviewed
Phase 47 public identity rewrite plan using the Phase 46 classification
contract.
**Resume File:** `.planning/phases/46-abacus-reference-decoupling/PLAN.md`
