# Milestones — Epsilon MMM

> Phase definitions, acceptance criteria, and estimated timelines.

---

## Overview

```
M1 ──── M2 ──── M3 ──── M4 ──── M5 ──── M6 ──── M7 ──── M8 ──── M9 ──── M10 ──── M11 ──── M12
Found.  Prims   Prior   Core    Feat    Infer   Post    Optim   Pipe    Plot     Valid    Remed
~1wk    ~1wk    ~1wk    ~2wk    ~2wk    ~1wk    ~1wk    ~1wk    ~2wk    ~1.5wk   ~1wk     ~1-2wk
                                                                                           ──────
                                                                                    Total: ~15-18 weeks
```

---

## M1: Foundation ⏱️ ~1 week

**Goal:** Runnable Julia package with passing local quality gates, docs scaffold,
and aligned contributor standards.

**Deliverables:**
- [x] Canonical contributor docs point to `TECHNICAL-STANDARDS.md`
- [x] `Project.toml` compat and dependency declarations match actual use
- [x] `src/Epsilon.jl` and `test/runtests.jl` form a passing baseline package
- [x] Runic formatting check is enforced consistently
- [x] `Makefile` targets are truthful and pass locally
- [x] `.gitignore` covers Julia and docs artifacts
- [x] Documenter.jl docs build cleanly with canonical API docs included

**Acceptance:** `make test` green. `make docs` green. Local quality gate green.

**Tag:** `v0.0.1-dev`

---

## M2: Primitives ⏱️ ~1 week

**Goal:** All mathematical transforms ported and parity-tested.

**Deliverables:**
- [x] `src/transforms/convolution.jl` — batched convolution (both modes)
- [x] `src/transforms/adstock.jl` — 4 adstock types + normalization
- [x] `src/transforms/saturation.jl` — 4 saturation types
- [x] `src/transforms/scaling.jl` — scaling, normalization, and validation helpers
- [x] `test/transforms/` — parity tests against Abacus reference arrays
- [x] `test/fixtures/` — reference data exported from Abacus

**Acceptance:** All transforms match Abacus output within `atol=1e-10, rtol=1e-8`.

**Tag:** `v0.1.0-dev`

---

## M3: Priors & Distributions ⏱️ ~1 week

**Goal:** Complete the prior specification system and the custom/shrinkage prior recipes required by the port.

**Deliverables:**
- [x] `src/distributions/priors.jl` — `EpsilonPrior` struct, config deserialization
- [x] `src/distributions/special.jl` — special-prior compatibility plus `Scaled` and `SkewStudentT`; no separate Michaelis distribution is required
- [x] `src/distributions/shrinkage.jl` — Horseshoe, Finnish Horseshoe, R2D2
- [x] `src/distributions/masked.jl` — MaskedPrior
- [x] Distribution name mapping (PyMC → Distributions.jl, handling parameterization differences)
- [x] Tests for all currently supported distributions and prior recipes: config deserialization, instantiation, serialization, and helper-math checks

**Acceptance:** Supported prior configs deserialize correctly, Julia-side distribution instantiation is well-tested, and shrinkage/helper formulas are validated for the eventual model layer.

**Tag:** `v0.2.0-dev`

---

## M4: Model Core ⏱️ ~2 weeks

**Goal:** Working model builder with Turing `@model`, YAML config, and a
truthful minimal model lifecycle surface.

**Deliverables:**
- [x] `src/model/types.jl` — `AbstractModel` hierarchy, `ModelConfig`, `SamplerConfig`, `MMMData`
- [x] `src/model/config.jl` — YAML loading plus deterministic config merging for defaults, model block, and explicit user overrides
- [x] `src/model/builder.jl` — builder/orchestration shell plus a minimal real backend path
- [x] `src/model/io.jl` — save/load of model artifacts and fitted chains
- [x] `src/model/results.jl` — typed results extraction and results save/load
- [x] `src/model/diagnostics.jl` — typed diagnostics, convergence reporting, and sampler warnings
- [x] `src/mmm/model.jl` — basic Turing `@model` for time-series MMM
- [x] `src/mmm/media.jl` — extracted media transform component (adstock → saturation) for the current minimal MMM path
- [x] Integration test: build + sample a simple time-series MMM on synthetic data

**Incremental Acceptance:**
- [x] Can load YAML config and typed MMM data into validated Julia model objects.
- [x] Can build a backend-agnostic MMM specification from typed config and data.
- [x] Can run a minimal Turing-backed time-series MMM and obtain posterior chains on synthetic data.
- [x] Can produce prior and posterior predictive output and serialize the fitted artifact.
- [x] Can inspect typed results, diagnostics, convergence reports, and sampler warnings for the fitted artifact.

**Milestone Exit:** The incremental items above are complete, the current model-core surface is documented honestly, and remaining feature growth or broader inference hardening is handed off to Milestones 5 and 6 rather than being hidden inside an indefinitely expanding Phase 4.

**Closeout Decision:** richer grouped results export is deferred to Milestone 6.
Phase 4 ends at typed model-core artifacts, typed results, and typed
diagnostics/warning surfaces for the current minimal MMM path.

**Tag:** `v0.3.0-dev`

---

## M5: Features ⏱️ ~2 weeks

**Goal:** Broaden the Phase 4 MMM core into a practical MMM feature surface
without reopening model-core scope.

**Deliverables:**
- [x] `05-01` Seasonality baseline:
  - [x] Deterministic seasonal feature builders
  - [x] Fourier seasonality on `TimeSeriesMMM`
  - [x] HSGP ADR choosing bounded defer from the supported Phase 5 surface
- [x] `05-02` Trend, events, and controls:
  - [x] Supported `trend.type = "linear"` path
  - [x] Supported `trend.type = "changepoint"` path
  - [x] Supported `events.columns` path
  - [x] Supported generated `events.windows` path
  - [x] One explicitly documented richer-control path
- [x] `05-03` Panel and hierarchical structure:
  - [x] `PanelMMM` as the first supported panel target type
  - [x] Small synthetic panel path with hierarchical priors / offsets
  - [x] Explicit dims/coords/indexing contract for the supported panel case
- [x] `05-04` Feature integration and closeout:
  - [x] Supported Phase 5 config contract frozen with exact keys
  - [x] Supported feature-combination matrix, including unsupported combinations
  - [x] Accepted HSGP implementation landed, or bounded defer documented if 05-01 chose not to implement it in Phase 5

**Acceptance:**
- Can fit and sample a supported `seasonality.type = "fourier"` time-series MMM
  on synthetic data.
- Can fit and sample one supported trend path, one supported event path, and
  one supported richer-control path on synthetic data.
- Can fit and sample one supported small `PanelMMM` path on synthetic data.
- The supported Phase 5 feature matrix is documented explicitly, including
  unsupported combinations.
- HSGP is resolved honestly: either implemented within the supported Phase 5
  contract, or deferred with no public `seasonality.type = "hsgp"` contract in
  Milestone 5.

**Tag:** `v0.4.0-dev`

---

## M6: Inference ⏱️ ~1 week

**Goal:** Harden the current inference workflow, land the canonical grouped
`InferenceResults` surface, and add one bounded explicit VI path.

**Deliverables:**
- [x] `src/inference/mcmc.jl` — canonical MCMC wrapper / execution-policy ownership layer over the current fit path
- [x] `src/inference/diagnostics.jl` — hardened diagnostics plus explicit warning/failure taxonomy
- [x] `src/inference/results.jl` — `InferenceResults`, `inference_results`, and grouped-artifact save/load helpers
- [x] `src/inference/vi.jl` — `approximate_fit!`, `VariationalConfig`, and bounded ADVI support via AdvancedVI
- [x] dedicated `test/inference/` coverage for the supported inference matrix

**Acceptance:** Supported Phase 5 bundles run through a truthful MCMC workflow,
`InferenceResults` exists as the canonical grouped artifact surface, at least
one bounded `approximate_fit!` path is documented and tested, NetCDF / ArviZ
interchange is explicitly deferred, and unsupported combinations fail honestly.

**Tag:** `v0.5.0-dev`

---

## M7: Post-Modeling ✅

**Goal:** Contribution decomposition, response curves, and all marketing
metrics on top of the canonical grouped inference artifacts from Phase 6.

**Deliverables:**
- [x] `src/postmodel/types.jl` — typed post-model result surfaces consuming `InferenceResults`
- [x] `src/postmodel/replay.jl` — deterministic replay of additive/media-response terms from grouped posterior draws, observed data, and spec
- [x] `src/postmodel/contributions.jl` — channel contributions, shares, consuming Phase 6 `InferenceResults`
- [x] `src/postmodel/decomposition.jl` — waterfall decomposition
- [x] `src/postmodel/response_curves.jl` — counterfactual response computation
- [x] `src/postmodel/metrics.jl` — ROAS, mROAS, CPA, mCPA
- [x] `src/postmodel/summary.jl` — summary table generation
- [x] `test/postmodel/` parity and negative-coverage surface for supported time-series outputs

**Acceptance:** Supported time-series contributions, decomposition, response
curves, and metrics match Abacus for the same posterior draws (within `1e-6`)
while consuming the canonical Phase 6 grouped inference surface rather than a
parallel ad hoc artifact format. The deterministic replay contract is explicit
and does not widen `InferenceResults`. Panel post-model outputs remain
explicitly deferred.

**Tag:** `v0.6.0-dev`

---

## M8: Budget Optimization ⏱️ ~1 week

**Goal:** Working fixed-budget optimizer with bounded constraints via JuMP on
top of the frozen Phase 7 response/metric surface.

**Deliverables:**
- [x] `src/optimization/types.jl` — typed optimization result / config surfaces
- [x] `src/optimization/objective.jl` — fixed-budget posterior-mean response objective
- [x] `src/optimization/constraints.jl` — total-budget equality, absolute bounds, reference-relative guardrails
- [x] `src/optimization/optimizer.jl` — bounded optimizer orchestration
- [x] `src/optimization/summary.jl` — comparison and audit projections over bounded optimization results
- [x] Integration with JuMP + Ipopt as the canonical constrained solver path
- [x] Parity test: same optimal allocation and objective summaries as Abacus on agreed fixtures

**Acceptance:** Optimizer finds correct allocations for the supported
time-series contract, handles the bounded Phase 8 constraint set honestly, and
matches Abacus on the frozen Phase 8 fixture matrix within the defined Phase 8
tolerances.

**Tag:** `v0.7.0-dev`

---

## M9: Pipeline ⏱️ ~2 weeks

**Goal:** End-to-end YAML-driven pipeline on the bounded time-series MCMC
surface, consuming the frozen Phases 6-8 contracts through one structured run
directory.

**Deliverables:**
- [x] `src/pipeline/config.jl` — runner config parsing, combined-CSV schema/date validation, and runner-only YAML validation
- [x] `src/pipeline/context.jl` — typed run context, `PipelineRunResult` / `PipelineStageRecord`, and manifest ownership
- [x] `src/pipeline/stages/` — fixed stage list:
  - [x] `00_run_metadata`
  - [x] `10_pre_diagnostics`
  - [x] `20_model_fit`
  - [x] `30_model_assessment`
  - [x] `35_holdout_validation`
  - [x] `40_decomposition`
  - [x] `50_diagnostics`
  - [x] `60_response_curves`
  - [x] `70_optimisation`
- [x] `src/pipeline/run.jl` — orchestrator with timing, skip, failure handling, and explicit full-sample vs holdout branch ownership
- [x] `src/pipeline/cli.jl` — thin `epsilon run config.yaml` CLI with only the bounded `PipelineRunConfig` override flags
- [x] Structured run-directory schema with Julia-native serialized artifacts plus schema-fixed CSV / JSON / YAML sidecars
- [x] Typed `PipelineValidationResult` plus documented `run_manifest.json` / stage-record schema
- [x] Full integration coverage on a supported time-series config and dataset

**Acceptance:** `epsilon run` produces a complete, correct, bounded run
directory for the supported time-series MCMC workflow. Combined CSV ingestion,
manifest/result schema, and sidecar schema are truthful and fixed. Optional
validation and optimization stages skip honestly when disabled or absent, and
validation does not overwrite full-sample fit artifacts. Panel and YAML-driven
VI remain explicitly unsupported in the closed Phase 9 surface.

**Tag:** `v0.8.0-dev`

---

## M10: Plotting ⏱️ ~1.5 weeks

**Goal:** Julia-native visualizations and report artifacts for core MMM outputs,
without reproducing the Abacus Dash app.

**Deliverables:**
- [x] `src/plotting/theme.jl` — canonical `CairoMakie` theme ownership
- [x] `src/plotting/diagnostics.jl` — trace, posterior-density,
      prior-versus-posterior, observed-versus-fitted, and residual-diagnostics
      plots on the bounded grouped inference surface
- [x] `src/plotting/postmodel.jl` — contribution, stacked contribution,
      decomposition, and response-curve plots on the closed Phase 7 result
      surfaces
- [x] `src/plotting/optimization.jl` — current-versus-optimized budget
      comparison plots on `BudgetOptimizationResult`
- [x] `src/plotting/bundle.jl` — deterministic static plot-bundle export over a
      successful `PipelineRunResult`, without mutating the closed Phase 9 run
      directory contract
- [x] `test/plotting/` — information-content and file-export coverage for the
      bounded public plotting surface

**Acceptance:** Core plots render correctly, save successfully as static files,
and stay anchored to the closed typed artifact surfaces from Phases 6-9.
Phase 10 requires no Plotly Dash parity, no interactive dashboard surface, and
no pipeline-stage mutation to count as complete. The bounded support matrix is:
diagnostics on grouped inference artifacts, time-series-first post-model and
optimization plots, no VI trace plots, no panel post-model/optimization plots,
and a post-hoc deterministic `png` plot-bundle helper over successful pipeline
runs.

**Tag:** `v0.9.0-dev`

---

## M11: Validation & Benchmarks ⏱️ ~1 week

**Goal:** Final v1 release gate: parity validated where Abacus comparison is
real, bounded Epsilon-only surfaces regression-checked honestly, and
benchmarks / release docs published.

**Deliverables:**
- [x] Final release-gate matrix distinguishing:
  - [x] Abacus-comparable parity rows
  - [x] bounded Epsilon-only contract-validation rows
- [x] `scripts/export_abacus_validation_fixtures.py`
- [x] compact final validation fixtures under `test/fixtures/abacus/validation/`
- [x] `test/validation/` parity / regression harness
- [ ] exact canonical validation case IDs / configs:
  - [x] `VAL-TS-00-MCMC`
  - [x] `VAL-TS-04-MCMC`
  - [x] `VAL-P-00-MCMC`
  - [x] `VAL-PIPE-TS-00-MCMC`
- [x] fixed artifact comparison table with explicit fields and tolerances
- [x] `benchmark/` runner, workload matrix, and documented run protocol
- [x] published benchmark result snapshots plus docs summary
- [x] final README / docs reconciliation and v1.0.0-rc1 readiness checklist

**Acceptance:** The validation infrastructure, benchmark methodology, and
release-doc scaffolding exist and are runnable. Phase 12 later narrowed the
guaranteed Abacus-reference release-gate row to `VAL-TS-00-MCMC`; the
holiday-bearing `VAL-TS-04-MCMC` fixture remains a compact cross-framework
reference case rather than a live Abacus-parity claim.

**Tag:** `v1.0.0-rc1-infra`

---

## M12: Parity Remediation ⏱️ ~1-2 weeks

**Goal:** Repair the bounded time-series methodology gap revealed by the audit
before any release branch or tag resumes.

**Deliverables:**
- [x] Abacus-matching channel/target scaling on the bounded comparable
      time-series fit path
- [x] Explicit `channel_scale` / `target_scale` style state carried through the
      typed model/runtime/artifact contract
- [x] Original-scale reconstruction for predictive and contribution outputs on
      top of the corrected scaled model space
- [x] Stage 60 parity repair:
  - [x] saturation-only curves
  - [x] forward-pass contribution curves
  - [x] adstock curves
- [x] Stage 70 parity repair over the corrected curve/model-space contract
- [x] Runnable demo/reference reconciliation for holiday/component handling
- [x] Reconciled release docs and validation claims after the repaired parity
      evidence exists

**Acceptance:** The guaranteed Abacus-reference time-series row
`VAL-TS-00-MCMC` now matches Abacus in model-space scaling semantics,
original-scale reconstruction, curve semantics, and downstream optimization
methodology closely enough that the release docs can honestly describe it as an
Abacus-reference row. Any holiday-bearing row must remain explicitly
Epsilon-native/reference unless a separate true compatibility mode is added.

**Tag:** Conditional - `v1.0.0-rc1` only if M12 acceptance passes

---

## Release: v1.0.0

**Criteria for v1.0:**
- All 12 milestones achieved
- Documentation complete with examples
- At least one real-world dataset tested
- No known material methodology regressions vs Abacus on the guaranteed
  Abacus-reference row
- Performance benchmarks published
