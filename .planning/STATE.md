# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-10)

**Core value:** Deliver a methodologically coherent Bayesian MMM library in
Julia by porting the validated Abacus statistical and methodological
functionality bottom-up and proving parity only where semantics genuinely
match.
**Current focus:** Phase 15 calibration likelihood integration is closed.
`TimeSeriesMMM` MCMC now has both lift-test and cost-per-target calibration
likelihood terms wired into `_time_series_mmm_model`, with fixture-backed
integration evidence and user-facing docs for the accepted bounded path. Panel
calibration, VI calibration, pipeline/YAML calibration ingestion, broader
lift-test saturation families, Dash/UI workflows, and AI-advisor behaviour
remain out of scope until separate contracts exist.

## Current Position

**Current Phase:** 15
**Current Phase Name:** Calibration Likelihood Integration
**Total Phases:** 15
**Current Plan:** Phase 15 complete
**Total Plans in Phase:** 8 tasks
**Status:** Phase 15 Tasks 15-01 through 15-08 are landed. Tasks 15-01 through
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
`scaffolded` because unsupported panel, VI, pipeline/YAML, non-logistic
lift-test saturation, Dash/UI, and AI-advisor paths remain outside the bounded
slice. Phase 13 contract/remediation issues
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
every scenario. The non-UI scenario planner surface is now started with typed
current/manual/fixed-budget scenario specs and `scenario_plan(result)`
comparison tables over solved optimization results.
Calibration/lift-test parity remains a `scaffolded` ledger row after Phase 15:
`TimeSeriesMMM` MCMC model-side likelihood wiring, fixture-backed integration
evidence, and docs are landed for both accepted calibration terms, but the
wider Abacus calibration surface is not complete.
**Last Activity:** 2026-07-05
**Last Activity Description:** Repo-wide pre-existing Runic drift was cleared
with the existing `make format` target across `src/`, `test/`, and `docs/`.
This was a mechanical formatter-only cleanup; no model, API, fixture, or
methodology semantics were intentionally changed. Verification was scoped to
the relevant local gate: `make format-check` passed, and `git diff --check`
reported no whitespace errors. A broader `make check-release` run was started
too aggressively for this formatter-only slice and was stopped before
completion.
**Progress:** 100%
**Paused At:** `.planning/phases/15-calibration-likelihood-integration/.continue-here.md`

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
| 6 | Keep VI as an explicit Julia-only API via `approximate_fit!` and `VariationalConfig`, with the YAML `fit` block remaining MCMC-only | Prevents the existing MCMC config surface from becoming a hidden mixed-backend contract during Phase 6 |
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
| 14 | Defer only AI advisor and Dash/dashboard parity by default | Epsilon is a Julia port of Abacus statistical and methodological functionality; other Abacus surfaces remain in scope unless the parity ledger explicitly says otherwise |
| 14 | Promote one-dimensional `geo_panel` replay to accepted deterministic gate | Panel contribution/decomposition replay now reconstructs original-scale panel artifacts from controlled posterior fixtures, but multidimensional panel and downstream response/optimization parity remain separate slices |
| 14 | Flatten multidimensional panel cells while retaining declared panel dimensions in metadata | Epsilon keeps the bounded sampler and replay internals on one panel-cell axis, but `geo_brand_panel` metadata preserves Abacus `("geo", "brand")` ordering and coordinate values for honest artifact schemas |
| 14 | Prefer explicit Epsilon-native method names when Abacus-inspired naming is misleading | `centered_logistic_saturation` names the actual zero-baselined logistic-family curve while the older `logistic_saturation` API remains as a compatibility alias |
| 14 | Expose panel coordinate reconstruction as a small public helper surface | `PanelCoordinate` and `panel_coordinates` make the flat panel-cell axis inspectable without changing model/result schemas or sampler tensors |
| 14 | Make panel observation-count semantics explicit | `ntime`, `npanels`, and `npanel_observations` distinguish shared time rows from flattened panel-cell observations while preserving `nobs(::PanelMMMData)` compatibility |
| 14 | Add ordered panel-axis metadata | `PanelAxis`, `panel_axis`, and `panel_axes` make `panel_cell` the explicit flat artifact axis while keeping declared coordinate columns in model order |

## Pending Todos

- Expand the scenario planner only behind concrete non-UI planning contracts,
  such as manual-allocation response evaluation or saved scenario-store
  artifacts. Automatic scenario refits remain outside the current surface.
- Phase 15 calibration likelihood integration is closed; keep the calibration
  row `scaffolded` until a separate contract implements panel, VI,
  pipeline/YAML, broader saturation-family, or UI calibration paths.
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

**Last Date:** 2026-07-05
**Stopped At:** Phase 15 is closed. Tasks 15-01 through 15-08 are landed:
contract freeze, typed payloads, config/spec threading, pure AD-compatible
lift-test log-density helpers, lift-test `Turing.@addlogprob!` wiring,
cost-per-target `Turing.@addlogprob!` wiring, fixture-backed combined
calibration integration evidence, and docs/changelog/ledger guardrail closure.
The accepted scope is still `TimeSeriesMMM` MCMC only and centered-logistic
lift-test calibration only. Panel calibration, VI calibration, pipeline/YAML
calibration ingestion, broader lift-test saturation families, scenario refits,
Dash/UI, and AI-advisor functionality remain out of scope. Resume with a new
post-Phase-15 priority decision.
**Resume File:** `.planning/phases/15-calibration-likelihood-integration/.continue-here.md`
