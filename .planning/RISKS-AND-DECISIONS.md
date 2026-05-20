# Risks & Decisions — Epsilon MMM

> Technical risks, open questions, and Architecture Decision Records (ADRs).

---

## Technical Risks

### 🔴 High Risk

#### R0: Model-Space Divergence From Abacus Scaling

**Risk:** The targeted methodology audit found that Epsilon had been fitting
the bounded comparable time-series row on raw channels and raw target, while
Abacus fits on max-scaled channels and target and reconstructs original-scale
outputs explicitly.

**Impact:** This changes saturation semantics, prior calibration, posterior
parameter meaning, original-scale contribution reconstruction, response-curve
interpretation, and downstream optimization behavior. It invalidates any
release claim that the current time-series row is already at approximate
Abacus parity.

**Mitigation:**
1. Reopen the roadmap with a dedicated parity-remediation phase instead of
   proceeding directly to release tagging.
2. Fix scaling/model-space semantics before touching downstream response-curve
   and optimization parity.
3. Treat Stage 60 curve-family semantics, Stage 70 optimization semantics, and
   the bounded holiday/demo comparable path as the remaining parity blockers
   after the model-space contract is repaired.
4. Re-run the release validation harness only after the downstream parity
   contract is repaired as well.

**Owner:** TBD
**Status:** 🟡 Partially mitigated by `12-01`; downstream Stage 60 / Stage 70 /
demo parity remains an active Phase 12 blocker

#### R1: HSGP (Hilbert Space Gaussian Processes)

**Risk:** HSGP is a critical feature in Abacus (used for flexible seasonality). PyMC has a built-in `pm.gp.HSGP` implementation. The Julia GP ecosystem (`AbstractGPs.jl`) does not have a direct HSGP equivalent.

**Impact:** If we can't port HSGP, we lose a key differentiator of Abacus over simpler Fourier seasonality.

**Mitigation:**
1. **Spike early in Phase 5 before downstream feature work depends on it**:
   investigate `AbstractGPs.jl` capabilities and any viable HSGP approximation
   path.
2. **Fallback A:** Port the HSGP math manually from PyMC's source code (basis functions + spectral density → Turing @model). This is feasible since HSGP is ultimately a linear approximation.
3. **Fallback B:** Use Fourier seasonality as default; HSGP as optional advanced feature added later.
4. **Reference:** [Riutort-Mayol et al., 2023](https://arxiv.org/abs/2004.11408) — the original HSGP paper.

**05-01 Decision Rubric:**
- Keep HSGP in Phase 5 only if all of the following are true:
  - there is a viable Julia implementation path that does not reopen Phase 4
    model-core boundaries
  - a synthetic fit can sample through the current Turing-backed MMM path with
    the proposed HSGP seasonality layer
  - the public config contract for HSGP can be stated with exact keys and
    bounds during 05-01
  - at least one bounded integration test can land within the Phase 5 feature
    matrix
- If any of those checks fail, HSGP is bounded-deferred:
  - Fourier remains the supported Phase 5 seasonality baseline
  - no public `seasonality.type = "hsgp"` path is exposed in Phase 5
  - the defer outcome must be recorded explicitly rather than treated as
    “probably later”

**Owner:** TBD  
**Status:** 🟡 Strategy resolved for Phase 5 — HSGP is bounded-deferred from the current supported surface

---

#### R2: Deterministic Tracking in Turing.jl

**Risk:** Abacus uses `pm.Deterministic` extensively (~80 references) to track intermediate values during sampling (channel contributions, transformed media, response curves). Turing.jl doesn't have a direct equivalent — it requires `generated_quantities()` as a post-hoc step, which means deterministics are computed AFTER sampling, not during.

**Impact:** If `generated_quantities` is slow or doesn't support all needed intermediate values, post-modeling analysis (contributions, response curves) could be incomplete or slow.

**Mitigation:**
1. Do not make `generated_quantities()` the public Phase 7 contract.
2. Use deterministic replay from grouped posterior draws, observed data, and
   typed spec/coordinate metadata as the canonical post-modeling contract.
3. Keep `generated_quantities()` as an optional implementation technique only if
   it helps internal efficiency without changing the public artifact surface.

**Owner:** TBD  
**Status:** 🟡 Bounded by ADR-015; no longer a public-contract blocker for Phase 7

---

#### R3: Autodiff Compatibility

**Risk:** All transforms (adstock, saturation, convolution) must work with Turing's autodiff backends (ForwardDiff.jl, ReverseDiff.jl). Julia code with mutation (e.g., `x[i] = ...`) may break ReverseDiff. The batched convolution uses loops and indexing that may not differentiate cleanly.

**Impact:** If transforms aren't autodiff-compatible, NUTS sampling won't work → project-blocking.

**Mitigation:**
1. Run an explicit autodiff sweep for landed transforms with
   `ForwardDiff.gradient` and `ReverseDiff.gradient` before the first
   Turing-backed model sprint is considered complete.
2. Avoid in-place mutation in transform hot paths. Use functional style: `map`, broadcasting, `reduce`.
3. If ReverseDiff fails, try `Zygote.jl` or `Enzyme.jl` as alternative backends.
4. Write custom `ChainRulesCore.rrule` if needed for specific transforms.

**Owner:** TBD  
**Status:** 🟡 Transform smoke tests now cover `ForwardDiff` and `ReverseDiff`; broader model-level autodiff risk remains

---

### 🟡 Medium Risk

#### R4: Turing.jl Performance on Large Models

**Risk:** Abacus models can be large (100+ parameters for panel models with many geos/channels). Turing.jl's performance on high-dimensional models may degrade versus PyMC+nutpie.

**Impact:** If sampling is slower than Abacus for large models, the performance benefit of Julia is negated.

**Mitigation:**
1. Benchmark early (M3): sample a 100-parameter model in both Abacus and Epsilon, compare ESS/sec.
2. Use `Turing.setadbackend(:reversediff)` for high-dimensional models (reverse-mode is O(1) in parameter count).
3. Consider `DynamicHMC.jl` as alternative sampler if `AdvancedHMC` is slow.
4. Explore `Pathfinder.jl` for fast initialization.

**Owner:** TBD  
**Status:** 🔴 Not started

---

#### R5: Julia Ecosystem Stability

**Risk:** The Turing.jl ecosystem is actively evolving. Breaking changes between versions of Turing, DynamicPPL, AdvancedHMC, etc. could require maintenance.

**Impact:** Dependency updates could break Epsilon between releases.

**Mitigation:**
1. Pin compat bounds tightly in `Project.toml`.
2. Review compatibility with new Turing releases before widening bounds or upgrading dependencies.
3. Stay engaged with Turing.jl community (Discourse, GitHub issues).

**Owner:** TBD  
**Status:** 🟡 Ongoing

---

#### R6: Panel Data Hierarchical Models

**Risk:** Abacus's `PanelMMM` uses complex hierarchical priors with geo-level and brand-level offsets. Mapping PyMC's `dims` system to Turing's `filldist` + manual indexing may produce subtle bugs or performance issues in multi-dimensional plate structures.

**Impact:** Panel models are the primary use case. Bugs here affect all production models.

**Mitigation:**
1. Start with a simple 2-geo, 2-channel test case. Validate posterior against Abacus.
2. Gradually scale to real-world panel sizes (20+ geos, 10+ channels).
3. Consider using `TuringGLM.jl` as reference for hierarchical model patterns.

**Owner:** TBD  
**Status:** 🔴 Not started

---

### 🟢 Low Risk

#### R7: Plotting Parity

**Risk:** Makie.jl and Matplotlib have different APIs and default aesthetics. Plots may not look identical.

**Impact:** Visual differences only — no statistical impact. Since Epsilon does
not target Plotly Dash parity for v1, the practical risk is limited to
producing clear static outputs rather than replicating the Abacus app surface.

**Mitigation:** Define Epsilon theme early. Prioritize information content over
visual parity, and treat simple static or file-based report outputs as
sufficient for v1.

---

#### R8: Julia Learning Curve

**Risk:** Team familiarity with Julia may be limited compared to Python.

**Impact:** Slower initial velocity; more bugs in idiomatic Julia patterns.

**Mitigation:** Julia's syntax is close to Python. Invest 1-2 days upfront in Julia training. Use Julia linting and formatting tools.

---

## Open Questions

| # | Question | Status | Decision |
|---|----------|--------|----------|
| Q1 | Should we use `Plots.jl` (simpler) or `Makie.jl` (more powerful) for non-Dash plotting? | 🟢 Closed | Phase 10 fixes `CairoMakie.jl` as the canonical static backend; `AlgebraOfGraphics.jl` is optional internal help, and `Plots.jl` is outside the bounded public contract. |
| Q2 | Should we support both `ForwardDiff` and `ReverseDiff` as autodiff backends? | 🟡 Open | Default to ReverseDiff (better for >20 params); ForwardDiff as fallback |
| Q3 | Should `generated_quantities` be called inside sampling or post-hoc? | 🟢 Closed | Not a public Phase 7 contract decision; deterministic replay from grouped posterior artifacts is canonical, and `generated_quantities()` is an optional internal implementation detail only |
| Q4 | Should we use `JuMP.jl` or `Optim.jl` for budget optimization? | 🟢 Closed | Phase 8 fixes `JuMP.jl + Ipopt.jl` as the canonical constrained solver path; `Optim.jl` is deferred from the bounded public contract. |
| Q5 | Should we keep Abacus YAML config format exactly or redesign for Julia? | 🟡 Open | Keep compatible where possible; extend for Julia-specific features |
| Q6 | Should we support `NetCDF` output for ArviZ interop? | 🟢 Closed | Phase 6 fixes the canonical grouped artifact contract as Julia-native `InferenceResults` and explicitly defers NetCDF / ArviZ-native interchange |
| Q7 | How do we handle Julia's time-to-first-plot latency for CLI usage? | 🟡 Open | PackageCompiler.jl for production; accept latency in dev |
| Q8 | Should the CLI be a Julia script or compiled binary? | 🟡 Open | Script initially; compiled via PackageCompiler.jl for production |

---

## Architecture Decision Records (ADRs)

### ADR-001: Julia as Target Language

**Status:** ✅ Accepted  
**Date:** 2026-04-21  
**Context:** Considered Go, Rust, C++, Julia for porting Abacus.  
**Decision:** Julia with Turing.jl — only ecosystem that matches PyMC feature-for-feature with native compiled performance.  
**Consequences:** Team needs Julia fluency. Ecosystem is younger than Python but mature enough.

---

### ADR-002: Turing.jl as Probabilistic Programming Framework

**Status:** ✅ Accepted  
**Date:** 2026-04-21  
**Context:** Considered Gen.jl as alternative.  
**Decision:** Turing.jl — larger community, better documentation, more active development, NUTS/HMC built-in.  
**Consequences:** Tied to Turing's `@model` macro pattern. Must handle deterministics via `generated_quantities`.

---

### ADR-003: Bottom-Up Porting Strategy

**Status:** ✅ Accepted  
**Date:** 2026-04-21  
**Context:** Could port top-down (pipeline first) or bottom-up (primitives first).  
**Decision:** Bottom-up — transforms first, then priors, then model core, then pipeline.  
**Consequences:** Each layer is independently testable. Slower to get end-to-end demo but more reliable.

---

### ADR-004: Composition over Inheritance

**Status:** ✅ Accepted  
**Date:** 2026-04-21  
**Context:** Abacus uses deep Python class hierarchies (5 levels). Julia doesn't support multiple inheritance.  
**Decision:** Use abstract types (shallow hierarchy) + multiple dispatch + composition via struct fields.  
**Consequences:** More idiomatic Julia. May require refactoring the mental model from Abacus's OOP design.

---

### ADR-005: Project Name — Epsilon

**Status:** ✅ Accepted  
**Date:** 2026-04-21  
**Context:** Needed a brand name for the Julia port.  
**Decision:** Epsilon (ε) — the statistical error term, representing precision and the irreducible uncertainty that Bayesian inference quantifies.  
**Consequences:** Clean namespace, strong technical identity, memorable.

---

### ADR-006: GSD Workflow

**Status:** ✅ Accepted  
**Date:** 2026-04-21  
**Context:** Needed a project management approach.  
**Decision:** GSD (Getting Stuff Done) — milestone-driven, clear acceptance criteria, documentation-first.  
**Consequences:** Higher upfront planning investment. Better long-term velocity and quality.

---

### ADR-007: Abacus Parity Scope Excludes Dash

**Status:** ✅ Accepted  
**Date:** 2026-04-21  
**Context:** Abacus's library and statistical methodology are production-grade,
but its Plotly Dash component is still beta.  
**Decision:** Epsilon v1 targets parity for the validated MMM/statistical core
and may omit or simplify the Dash/UI layer.  
**Consequences:** Plotting remains in scope, but only as practical Julia-native
diagnostic and analyst outputs rather than an interactive dashboard clone.

---

### ADR-016: Reopen Release Readiness After The Methodology Audit

**Status:** ✅ Accepted
**Date:** 2026-04-23
**Context:** Phase 11 landed the release-gate harness and readiness docs, but
the targeted methodology audit found that the bounded comparable time-series
row still diverges from Abacus in model-space scaling, original-scale
reconstruction, curve semantics, and optimization semantics.
**Decision:** Pause release preparation and add a dedicated Phase 12 parity
remediation track before any `v1.0.0-rc1` branch or tag.
**Consequences:** The roadmap is no longer considered complete. Phase 11
remains valuable as validation infrastructure, but the parity claim must be
repaired before release-facing docs or tags can be treated as truthful.

---

### ADR-008: Richer Grouped Results Export Belongs To Phase 6

**Status:** ✅ Accepted
**Date:** 2026-04-21
**Context:** By late Phase 4, Epsilon already had model save/load, typed
results, typed diagnostics, convergence reporting, sampler warnings, and a
minimal runnable Turing-backed MMM. The open question was whether richer
grouped results export should be used to keep Phase 4 open or be treated as
later inference/reporting work.
**Decision:** Defer richer grouped results export to Phase 6.
**Consequences:** Phase 4 closes at the typed model-core contract. Phase 5 can
focus on MMM feature breadth, and Phase 6 becomes the place to harden grouped
exports and broader inference/reporting surfaces without blurring the Model
Core boundary.

---

### ADR-009: Phase 5 Panel Path Uses `PanelMMM`

**Status:** ✅ Accepted
**Date:** 2026-04-21
**Context:** The first Phase 5 panel / hierarchical path needs explicit model
boundaries. Extending `TimeSeriesMMM` to absorb panel semantics would blur the
single-series contract established in Phase 4 and risk reopening model-core
scope.
**Decision:** Introduce `PanelMMM <: AbstractMMMModel` as the supported Phase 5
panel target type. Keep `TimeSeriesMMM` as the single-series path.
**Consequences:** Panel dims, hierarchical priors, and indexing rules can land
without overloading the current time-series contract. A broader unification of
single-series and panel MMM types is a later design question, not a default
Phase 5 assumption.

---

### ADR-010: HSGP Is Deferred From The Supported Phase 5 Surface

**Status:** ✅ Accepted
**Date:** 2026-04-21
**Context:** Phase 5 required an early HSGP decision before downstream feature
work depended on it. The current codebase now has a bounded Fourier seasonality
path on `TimeSeriesMMM`, but HSGP would still require additional model-layer
work, a concrete public config contract, and bounded integration coverage.
**Decision:** Defer HSGP from the supported Phase 5 surface. Phase 5 continues
with Fourier as the supported seasonality baseline and does not expose a public
`seasonality.type = "hsgp"` path.
**Consequences:** The package has an honest Phase 5 seasonality contract and
can move into 05-02 without carrying an unresolved GP dependency. Any HSGP
implementation attempt must re-enter through a later explicitly scoped plan.

---

### ADR-011: First Supported Time-Varying Trend Uses Abacus-Style Changepoints

**Status:** ✅ Accepted
**Date:** 2026-04-22
**Context:** Phase 5 plan 05-02 required an explicit decision for the first
supported time-varying trend path. The current `TimeSeriesMMM` surface already
has a model-level intercept and a bounded `trend.type = "linear"` baseline, so
adding an unconstrained alternate trend contract risked reopening the core
model surface.
**Decision:** Use an Abacus-inspired piecewise-linear changepoint trend as the
first supported time-varying trend path on `TimeSeriesMMM`. The public contract is
`trend.type = "changepoint"` with required `trend.n_changepoints` and optional
`trend.priors.delta`. `trend.include_intercept` is not supported; intercept
ownership stays with the model-level intercept.
**Consequences:** Phase 5 now has a bounded and documented time-varying trend
path that preserves the upstream piecewise-linear trend shape while excluding
the terminal all-zero changepoint basis term, which avoids sampling an
unidentified final coefficient. Later trend expansion can build from this
explicit baseline instead of revisiting the original decision.

---

### ADR-012: Phase 6 Uses Julia-Native `InferenceResults` And Defers NetCDF Interchange

**Status:** ✅ Accepted
**Date:** 2026-04-22
**Context:** Phase 6 needs one settled grouped-artifact contract before grouped
export, VI, and Phase 7 consumers begin implementation. Leaving the grouped
surface or ArviZ / NetCDF interop open would force implementation-time design
choices into multiple later plans.
**Decision:** Phase 6 will use Julia-native `InferenceResults` as the canonical
grouped inference artifact surface. `ModelResults` remains the lighter flat
surface. NetCDF / ArviZ-native interchange is explicitly deferred from Phase 6.
**Consequences:** Grouped export, persistence, and downstream consumers can
target one concrete artifact contract. Documentation may describe conceptual
mapping to ArviZ-style groups, but Phase 6 does not promise a NetCDF or
ArviZ-native export format.

---

### ADR-013: Phase 6 VI Is An Explicit Julia API, Not A YAML Mode On `fit!`

**Status:** ✅ Accepted
**Date:** 2026-04-22
**Context:** Phase 6 needs a bounded VI path, but the existing external config
surface already treats `fit!`, `SamplerConfig`, and the YAML `fit` block as the
canonical MCMC path. Allowing VI to appear as a hidden backend switch on that
surface would make the user contract ambiguous.
**Decision:** Phase 6 introduces the explicit Julia VI API
`approximate_fit!(model, config::VariationalConfig = VariationalConfig())`.
`fit!`, `SamplerConfig`, and the YAML `fit` block remain MCMC-only throughout
Phase 6.
**Consequences:** The VI contract is honest and bounded. The package avoids
pretending that YAML-driven VI or mixed-backend `fit!` semantics are already in
scope before the later pipeline phase opens them intentionally.

---

### ADR-014: Phase 7 Consumes `InferenceResults` Directly And Starts Time-Series First

**Status:** ✅ Accepted
**Date:** 2026-04-22
**Context:** Phase 6 froze the inference contract across `TimeSeriesMMM` MCMC,
`TimeSeriesMMM` VI, and bounded `PanelMMM` MCMC. Phase 7 needs analyst-facing
outputs, but leaving post-model consumers free to target raw posterior objects
or invent panel decomposition semantics during implementation would reopen the
very ambiguity that Phase 6 just closed.
**Decision:** Phase 7 will consume canonical `InferenceResults` directly as its
input surface and will support post-model outputs on the bounded time-series
surface first. Panel post-model outputs are explicitly deferred from Phase 7.
Phase 7 outputs remain in the observed target units already carried by the
current grouped artifact contract; no separate inverse-scaling contract is
introduced for the current supported model path.
**Consequences:** Contributions, decomposition, response curves, and business
metrics can be implemented without redefining the inference artifact surface or
inventing premature panel aggregation semantics. Phase 8 can depend on the
frozen Phase 7 response/metric surface instead of recalculating business outputs
directly from raw posterior objects.

---

### ADR-015: Phase 7 Uses Deterministic Replay Instead Of Widening `InferenceResults`

**Status:** ✅ Accepted
**Date:** 2026-04-22
**Context:** Phase 7 needs term-traceable contributions, decomposition, response
curves, and business metrics, but the Phase 6 grouped artifact contract was
explicitly frozen around posterior/prior draws, predictive draws, metadata,
coordinates, and observed data. Leaving Phase 7 free to extend
`InferenceResults` or depend on `generated_quantities()` would reopen that
contract during implementation.
**Decision:** Phase 7 will compute post-model deterministic quantities by
replaying the frozen Phase 5 time-series transform and additive-term logic from
`InferenceResults.posterior`, `InferenceResults.observed_data`,
`InferenceResults.spec`, and `InferenceResults.coordinate_metadata`.
`InferenceResults` itself is not widened in Phase 7, and
`generated_quantities()` is not the public contract.
**Consequences:** The canonical inference artifact remains stable. Phase 7 gains
an execution-safe deterministic contract that works for both supported MCMC and
supported VI time-series artifacts, while panel post-model outputs remain
explicitly deferred.

---

### ADR-016: Persist Resolved Standardized-Control Replay State In `MMMModelSpec`

**Status:** ✅ Accepted
**Date:** 2026-04-22
**Context:** Deterministic replay in Phase 7 is required to consume
`InferenceResults.posterior`, `InferenceResults.observed_data`, and
`InferenceResults.spec` directly. For grouped time-series artifacts produced
with `controls.transform = "standardize"` on `new_data`, replay cannot recover
the fit-time scaling state from `observed_data` alone without drifting from the
actual predictive contract.
**Decision:** Resolved standardized-control state is carried inside
`MMMModelSpec.controls` under a private internal key when grouped or fitted
time-series specs are materialized. `InferenceResults` itself is still not
widened with new deterministic groups.
**Consequences:** Phase 7 replay remains faithful for the supported
standardized-controls bundle, including grouped `new_data` artifacts, while the
public grouped-artifact contract stays centered on `posterior`, `observed_data`,
`spec`, and coordinate metadata.

---

### ADR-017: Phase 7 Response Curves Use Total-Spend Grids And Preserve Observed Spend Shape

**Status:** ✅ Accepted
**Date:** 2026-04-22
**Context:** `07-02` needs one truthful response/metric contract for supported
time-series grouped artifacts. Leaving response curves underspecified would let
Phase 7 or Phase 8 drift between incompatible interpretations such as pure
saturation curves, fully re-optimized paths, or ad hoc spend scaling that no
longer matches the observed channel trajectory.
**Decision:** `response_curve_results(results; channel, grid)` uses
`grid` as total spend in original units across the observed horizon for the
selected channel. The current bounded Phase 7 implementation preserves the
observed temporal spend shape for that channel, scales the path to each
requested total-spend point, and replays the selected channel contribution from
the grouped posterior. `metric_results` derives ROAS, mROAS, CPA, and mCPA
from that same response surface instead of introducing a parallel formula path.
**Consequences:** Phase 7 response and business-metric outputs stay anchored to
one deterministic replay contract that works for both supported MCMC and
supported VI time-series artifacts. Phase 8 optimization must consume this
frozen response/metric surface rather than reopen spend-scaling semantics.

---

### ADR-018: Phase 8 Uses `JuMP.jl + Ipopt.jl` For A Bounded Fixed-Budget Time-Series Optimizer

**Status:** ✅ Accepted
**Date:** 2026-04-22
**Context:** Phase 8 needs one truthful optimization contract on top of the
frozen Phase 7 response and metric surfaces. Leaving solver choice open between
`JuMP.jl` and `Optim.jl`, or leaving objective/constraint semantics vague,
would force implementation-time design choices into the solver layer and make
parity testing harder.
**Decision:** Phase 8 will use `JuMP.jl + Ipopt.jl` as the canonical solver
path for one bounded optimization problem:

- fixed total budget across selected time-series channels
- posterior-mean total-response objective
- total-budget equality, absolute bounds, and reference-relative spend
  guardrails as the supported constraint set
- no panel optimization, no date-level pacing, and no multi-objective trade-off
  surface in the bounded Phase 8 contract

`Optim.jl` remains outside the bounded public contract.
**Consequences:** Phase 8 gets one explicit constrained-solver story that
matches the current planning scope and current Component Mapping guidance.
Implementation and parity work can target one concrete optimization contract
instead of maintaining multiple backend paths.

---

### ADR-019: Phase 9 Pipeline Starts Time-Series First, MCMC-Only, And Uses Julia-Native Run Artifacts

**Status:** ✅ Accepted
**Date:** 2026-04-23
**Context:** Phase 9 needs to turn the closed Phases 6-8 surfaces into one
disk-backed YAML-driven runner. Leaving pipeline scope open across panel runs,
YAML-driven VI, split CSV ingestion, or NetCDF/report semantics would force the
first runner implementation to reopen contracts that earlier phases explicitly
froze.
**Decision:** Phase 9 will start from one bounded pipeline contract:

- time-series first
- MCMC-only through the existing YAML `fit` block and `fit!`
- one combined CSV dataset path with fixed YAML-declared column mapping,
  chronological sort before model construction, and duplicate-date rejection
- runner-only YAML keys limited to `data.dataset_path`, optional
  `validation`, and optional `optimization`
- Julia-native serialized stage artifacts plus schema-fixed CSV / JSON / YAML
  sidecars
- `run_manifest.json` and `PipelineRunResult` as the canonical run-level
  machine-readable / typed result pair
- `35_holdout_validation` as a side branch that writes
  `PipelineValidationResult` and never overwrites Stage `20_model_fit`
  full-sample artifacts
- CLI overrides bounded to the same `PipelineRunConfig` runtime surface
- no separate report/plot stage in Phase 9
- no panel or YAML-driven VI pipeline support

**Consequences:** Phase 9 can land one truthful runner without pretending that
panel pipeline semantics, VI orchestration, NetCDF interchange, or plot/report
bundles are already supported. Later phases can widen the runner deliberately
instead of inheriting accidental pipeline behavior from the first
implementation.

---

### ADR-020: Phase 10 Uses CairoMakie As The Canonical Static Plotting Backend

**Status:** ✅ Accepted
**Date:** 2026-04-23
**Context:** Phase 10 needs one truthful plotting contract on top of the closed
Phases 6-9 typed artifact surfaces. Leaving the plotting backend open between
`Plots.jl` and `Makie.jl`, or leaving static export versus dashboard semantics
implicit, would force implementation-time design choices into every plot
surface and make the public plotting API ambiguous.
**Decision:** Phase 10 fixes `CairoMakie.jl` as the canonical backend. Public
plotting functions return Makie `Figure` objects and use Makie's normal
`save(...)` path for static export. `AlgebraOfGraphics.jl` may be used
internally where helpful, but it is not a required part of the bounded public
contract. Plotting remains intentionally smaller than the Abacus Dash surface:
no web dashboard and no interactive app contract. Successful Phase 9 runs do
write stage-local plot artifacts into the run directory, while
`write_plot_bundle(run)` remains the separate curated post-hoc bundle export.
**Consequences:** Phase 10 gets one explicit static-plot story that is aligned
with the project scope and the current dependency plan. Plotting can stay
focused on information content and report-ready exports without reopening
pipeline or UI architecture.

---

### ADR-021: Phase 11 Uses A Split Release Gate For Abacus Parity Versus Epsilon-Only Contract Validation

**Status:** ✅ Accepted
**Date:** 2026-04-23
**Context:** Phase 11 needs one truthful release gate for the closed Phases
2-10 surfaces. Leaving the final validation phase as a generic "prove parity
and beat Abacus on benchmarks" step would overstate what is truly comparable to
Abacus and would turn bounded Epsilon-only rows such as pipeline, plotting,
and the current explicit VI / panel slices into undefined implementation-time
judgment calls.
**Decision:** Phase 11 distinguishes:

- Abacus-comparable parity rows:
  - deterministic transform fixtures
  - canonical time-series MCMC statistical outputs
  - retained post-model and optimization parity fixtures
- bounded Epsilon-only contract-validation rows:
  - explicit VI row
  - bounded `PanelMMM` row
  - pipeline contract
  - plotting contract

The canonical Phase 11 release-gate case IDs are:

- `VAL-TS-00-MCMC`
- `VAL-TS-04-MCMC`
- `VAL-P-00-MCMC`
- `VAL-PIPE-TS-00-MCMC`

The requirement layer must mirror that split directly through `VAL-01`; the
final release gate is not defined as universal Abacus parity across all
supported Epsilon rows.

Phase 12 later narrowed the guaranteed Abacus-reference row set to
`VAL-TS-00-MCMC`. `VAL-TS-04-MCMC` remains in the validation corpus as a
holiday-bearing cross-framework reference case, but it is no longer a literal
Abacus-parity claim unless a separate compatibility mode is added.

Benchmarking is also frozen as an honest publication requirement rather than a
universal speed-win claim. Phase 11 must publish methodology, environment, and
measured results, and any slower-than-Abacus cases must be documented rather
than hidden behind a blanket "faster on all benchmarks" gate.
**Consequences:** The v1 release gate becomes executable and reviewable. Phase
11 can close on truthful evidence without reopening unsupported rows or making
claims the current bounded surface cannot defend.
