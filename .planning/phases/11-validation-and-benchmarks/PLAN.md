# Phase 11 Plan - Validation and Benchmarks

**Phase:** 11
**Phase Name:** Validation and Benchmarks
**Status:** In Progress
**Last Reconciled:** 2026-04-23

## Objective

Close the v1 cycle by proving the supported Epsilon surface is correct,
measured, and release-ready without reopening modeling, inference, pipeline,
or plotting scope.

Phase 11 is the release-validation phase. It does not add new MMM features.
Instead, it turns the closed Phases 2-10 contracts into one explicit
maintainer-facing release gate covering:

- final Abacus parity on the supported comparable statistical surface
- benchmark methodology and published performance results
- final v1 usage and release-readiness documentation

The key constraint is honesty. Phase 11 must distinguish:

- surfaces that are truly Abacus-comparable and should pass parity checks
- bounded Epsilon-only surfaces that should pass contract-regression checks
- explicitly unsupported rows that are not part of the v1 release gate

## Entry Conditions

Phases 1-10 are closed and the following are already in place:

- deterministic transform parity fixtures under `test/fixtures/abacus/`
- typed model/config/data, results, diagnostics, and grouped inference
  surfaces
- the frozen Phase 5 supported feature matrix
- the frozen Phase 6 inference matrix
- the frozen Phase 7 post-model matrix plus retained Abacus-backed summary
  fixtures
- the frozen Phase 8 optimization contract plus retained Abacus-backed
  optimization fixtures
- the closed Phase 9 pipeline contract with fixed Stage `00`-`70` artifacts
- the closed Phase 10 plotting contract with bounded static exports

Phase 11 must validate and document those closed surfaces. It must not widen
them.

## Closed Base To Validate

The current closed base is:

- transforms:
  - convolution
  - adstock
  - saturation
  - scaling
- modeling:
  - `TimeSeriesMMM`
  - bounded `PanelMMM`
- inference:
  - `fit!`
  - `approximate_fit!`
  - `InferenceResults`
- post-modeling:
  - `contribution_results`
  - `decomposition_results`
  - `response_curve_results`
  - `metric_results`
  - `summary_table`
- optimization:
  - `optimize_budget`
  - `BudgetOptimizationResult`
  - `budget_impact_table`
  - `budget_audit_table`
- pipeline:
  - `run_pipeline`
  - `pipeline_main`
  - closed run-directory / manifest / sidecar schemas
- plotting:
  - bounded CairoMakie figure-returning plot APIs
  - `write_plot_bundle`

Phase 11 adds a release gate on top of that base.

## Phase 11 Release Gate Contract

Phase 11 freezes the validation contract up front:

- The final release gate is maintainer-facing, not a new user-facing runtime
  API surface.
- Abacus parity is required only for rows that are genuinely comparable to the
  validated Abacus statistical core.
- Bounded Epsilon-only rows are validated through contract-regression and
  integration checks, not by pretending Abacus-equivalent outputs already
  exist.
- Plotting is validated for information content and export correctness, not
  pixel-for-pixel visual parity.
- Benchmarking must publish methodology, environment, and measured results.
- Phase 11 does not require Epsilon to beat Abacus on every benchmark. It does
  require that measured performance be published honestly and that any slower
  cases be explained before release.

## Canonical Release Gate Matrix

| Surface | Gate Type | Canonical Artifacts | Notes |
|---|---|---|---|
| Transforms | Abacus exact parity | retained transform fixtures in `test/fixtures/abacus/` | Deterministic numeric tolerances remain the hard gate |
| Time-series MCMC modeling / inference / post-model / optimization | Abacus fixture-based numerical and statistical parity | new compact validation fixtures plus retained Phase 7 / 8 fixtures | This is the main Abacus-comparable v1 release surface |
| `TimeSeriesMMM` VI | Epsilon contract-regression gate | grouped-artifact, replay, optimization, and plotting regression tests | VI remains supported, but not a separate Abacus release-parity row |
| `PanelMMM` MCMC | Epsilon bounded contract-regression gate | small synthetic panel regression fixtures and integration tests | Panel support remains bounded and is not widened in Phase 11 |
| Pipeline | Epsilon schema and integration gate | fixed run directory, manifest, sidecars, and CLI integration coverage | Abacus pipeline parity is not the v1 target |
| Plotting | Epsilon information-content and export gate | figure-returning APIs, direct static export, deterministic bundle tree | No pixel parity or Dash parity gate |

Phase 11 must keep that distinction explicit in docs and tests.

## Frozen Canonical Validation Case Matrix

Phase 11 freezes the release-gate corpus to these exact case IDs. `11-01`
should not choose cases ad hoc.

| Case ID | Support Row | Backend | Canonical Config | Canonical Data | Gate Type | Notes |
|---|---|---|---|---|---|---|
| `VAL-TS-00-MCMC` | `TS-00` | `fit!` / Turing NUTS | `test/fixtures/abacus/validation/ts00_mcmc/config.yml` | `test/fixtures/abacus/validation/ts00_mcmc/dataset.csv` | Abacus parity | Base time-series MMM validation case |
| `VAL-TS-04-MCMC` | `TS-04` | `fit!` / Turing NUTS | `test/fixtures/abacus/validation/ts04_mcmc/config.yml` | `test/fixtures/abacus/validation/ts04_mcmc/dataset.csv` | Abacus parity | Frozen richer time-series feature-bundle case: Fourier + changepoint + `events.windows` |
| `VAL-P-00-MCMC` | `P-00` | `fit!` / Turing NUTS | `test/fixtures/abacus/validation/p00_mcmc/config.yml` | `test/fixtures/abacus/validation/p00_mcmc/dataset.csv` | Epsilon contract validation | Bounded panel regression case; not an Abacus parity row |
| `VAL-PIPE-TS-00-MCMC` | `TS-00` via Phase 9 runner | `run_pipeline` / MCMC | `test/fixtures/abacus/validation/pipeline_ts00_mcmc/config.yml` | `test/fixtures/abacus/validation/pipeline_ts00_mcmc/dataset.csv` | Epsilon contract validation | Combined-CSV pipeline case with `validation.enabled = true` and `optimization.enabled = true` |

The canonical validation exporter for Abacus-comparable rows is:

- `scripts/export_abacus_validation_fixtures.py`

That exporter owns only:

- `VAL-TS-00-MCMC`
- `VAL-TS-04-MCMC`

The bounded Epsilon-only rows are committed as regression fixtures or generated
deterministically inside `test/validation/`; they are not mislabeled as
Abacus-exported parity fixtures.

## Canonical Dataset And Fixture Contract

Phase 11 should not rely on ad hoc local experiments. It should freeze one
maintainer-facing validation corpus:

- retained lower-layer deterministic fixtures:
  - `test/fixtures/abacus/*.jl`
  - `test/fixtures/abacus/postmodel_summary_cases.jl`
  - `test/fixtures/abacus/optimization/cases.jl`
- new final validation fixtures under:
  - `test/fixtures/abacus/validation/`

For each canonical case, the fixture corpus should contain compact release-gate
artifacts, not raw full chains:

- `config_metadata.json`
- `dataset_metadata.json`
- `posterior_summary.csv`
- `predictive_summary.csv`
- `postmodel_summary.json`
- `optimization_summary.json`

Phase 11 should prefer compact, stable summaries over giant draw dumps so the
release gate stays fast and reviewable.

`11-01` must also freeze the exact artifact schemas:

- `config_metadata.json`
  - fields:
    - `case_id`
    - `model_type`
    - `support_row`
    - `backend`
    - `random_seed`
    - `draws`
    - `tune`
    - `chains`
- `dataset_metadata.json`
  - fields:
    - `case_id`
    - `nobs`
    - `nchannels`
    - `has_controls`
    - `has_events`
    - `has_panel`
    - `date_type`
- `posterior_summary.csv`
  - keyed by:
    - `parameter`
  - compared columns:
    - `mean`
    - `sd`
    - `q05`
    - `q50`
    - `q95`
- `predictive_summary.csv`
  - keyed by:
    - `observation`
  - compared columns:
    - `mean`
    - `sd`
    - `q05`
    - `q50`
    - `q95`
- `postmodel_summary.json`
  - fields:
    - `contribution_component_means`
    - `decomposition_component_totals`
    - `response_curve_mean`
    - `metric_mean`
- `optimization_summary.json`
  - fields:
    - `objective_value`
    - `current_total_response`
    - `optimized_total_response`
    - `channel_current_spend`
    - `channel_optimized_spend`
    - `channel_spend_delta`

The exporter and fixture README must document:

- the local Abacus checkout path assumed
- the exact case IDs above that it owns
- the exact datasets/configs used
- how to regenerate the final validation fixture set deterministically

## Frozen Parity Comparison Table

Phase 11 fixes the comparison contract now so `11-01` does not choose fields or
tolerances at implementation time.

| Artifact | Cases | Keyed By / Reducer | Compared Fields | Tolerance Policy |
|---|---|---|---|---|
| transform fixture arrays | retained transform fixtures | full-array compare; report `maximum(abs.(Δ))` and `maximum(abs.(Δ) ./ max.(abs.(ref), eps()))` | all array elements | `atol = 1e-10`, `rtol = 1e-8` |
| `posterior_summary.csv` | `VAL-TS-00-MCMC`, `VAL-TS-04-MCMC` | keyed by `parameter` | schema + finite summary columns | compact artifact schema / finiteness gate; detailed posterior parity remains covered by retained lower-layer fixtures |
| `predictive_summary.csv` | `VAL-TS-00-MCMC`, `VAL-TS-04-MCMC` | keyed by `observation`; fitted-response replay on observed design | `mean`, `sd`, `q05`, `q50`, `q95` | `mean` / `q50`: `atol = 8e-2`, `rtol = 2e-1`; `sd`: `atol = 1.5e-1`, `rtol = 1.0`; `q05` / `q95`: `atol = 2.5e-1`, `rtol = 3e-1` |
| `postmodel_summary.json` | `VAL-TS-00-MCMC`, `VAL-TS-04-MCMC` | keyed by component / grid point / metric name | schema, key sets, and finite payloads for `contribution_component_means`, `decomposition_component_totals`, `response_curve_mean`, `metric_mean` | compact artifact schema / finiteness gate; detailed post-model parity remains covered by retained Phase 7 fixtures |
| `optimization_summary.json` | `VAL-TS-00-MCMC`, `VAL-TS-04-MCMC` where optimization is enabled | keyed by channel name plus top-level scalar fields | exact `channel_current_spend`; finite optimization payload; budget equality | spend fields: `atol = 1e-6`, `rtol = 1e-6`; optimization payload otherwise uses bounded schema / budget-consistency checks, with detailed optimization parity covered by retained Phase 8 fixtures |

The bounded Epsilon-only contract-validation rows do not reuse this table.
Their release gate is schema / behavior / integration correctness, not a false
Abacus-parity comparison.

## Benchmark Contract

Phase 11 also freezes the benchmark contract up front:

- micro-benchmarks are maintainer tools, not part of `make test`
- benchmark execution must be reproducible from a dedicated `benchmark/`
  entry point
- reported benchmark results must include:
  - Julia version
  - package environment / commit hash
  - machine / CPU summary
  - dataset / config identity
  - warmup policy
  - metric definitions
- benchmark results are committed only for the frozen reference run protocol
  below; ad hoc local benchmark files stay uncommitted

## Frozen Benchmark Workload Matrix

`11-02` must implement exactly this benchmark matrix.

| Benchmark ID | Workload | Input Identity | Protocol | Committed Result |
|---|---|---|---|---|
| `B-T1-CONV` | `batched_convolution` representative 3D overlap/add case | `benchmark/inputs/transform_cases.toml::conv_3d_overlap` | BenchmarkTools micro-benchmark | yes |
| `B-T2-GEOM` | geometric adstock representative matrix case | `benchmark/inputs/transform_cases.toml::geometric_adstock_matrix` | BenchmarkTools micro-benchmark | yes |
| `B-T3-WEIBULL` | Weibull PDF adstock representative matrix case | `benchmark/inputs/transform_cases.toml::weibull_pdf_matrix` | BenchmarkTools micro-benchmark | yes |
| `B-T4-HILL` | Hill saturation representative vector case | `benchmark/inputs/transform_cases.toml::hill_vector` | BenchmarkTools micro-benchmark | yes |
| `B-T5-SCALING` | standardization / scaling representative matrix case | `benchmark/inputs/transform_cases.toml::standardize_controls_matrix` | BenchmarkTools micro-benchmark | yes |
| `B-W1-FIT` | time-series MCMC fit wall-clock | `VAL-TS-00-MCMC` | workflow benchmark | yes |
| `B-W2-GROUPED` | `inference_results` materialization | fitted artifact from `B-W1-FIT` | workflow benchmark | yes |
| `B-W3-POSTMODEL` | response / metric / optimization representative path | grouped artifact from `B-W1-FIT` | workflow benchmark | yes |
| `B-W4-PIPELINE` | full pipeline wall-clock | `VAL-PIPE-TS-00-MCMC` | workflow benchmark | yes |

The benchmark suite is bounded to those workloads only.

The frozen run protocol is:

- micro-benchmarks:
  - one warmup invocation discarded
  - `BenchmarkTools.jl` with `evals = 1`, `samples = 50`
  - committed metrics:
    - median time
    - memory estimate
    - allocation count
- workflow benchmarks:
  - fixed settings:
    - `random_seed = 7`
    - `chains = 2`
    - `draws = 120`
    - `tune = 60`
    - `target_accept = 0.85`
  - one warmup run discarded
  - three timed repetitions in separate Julia processes
  - committed metrics:
    - median wall-clock seconds
    - median peak RSS when available
    - ESS/sec when the workload includes MCMC output

The benchmark result commit policy is:

- commit only:
  - `benchmark/results/reference_machine.json`
  - `benchmark/results/reference_machine.md`
- both files must include machine and environment metadata
- ad hoc local comparison outputs stay uncommitted and outside the release gate

The benchmark suite is therefore bounded to:

- transform micro-benchmarks:
  - `B-T1-CONV`
  - `B-T2-GEOM`
  - `B-T3-WEIBULL`
  - `B-T4-HILL`
  - `B-T5-SCALING`
- workflow / macro benchmarks:
  - `B-W1-FIT`
  - `B-W2-GROUPED`
  - `B-W3-POSTMODEL`
  - `B-W4-PIPELINE`
- MCMC quality-adjacent reporting where available:
  - ESS/sec
  - allocation counts
  - coarse memory usage

Phase 11 should publish benchmark results as:

- machine-readable benchmark output under `benchmark/results/`
- human-readable benchmark documentation in docs

`BenchmarkTools.jl` is the canonical Phase 11 benchmark dependency.
`PkgBenchmark.jl` may be added only if it materially improves result tracking;
it is not required for honest Phase 11 closeout.

## Release Documentation Contract

Phase 11 closes the v1 release-doc contract:

- README and docs must describe the truthful supported surface at release time
- the release docs must distinguish:
  - supported rows
  - unsupported rows
  - Abacus-comparable parity rows
  - Epsilon-only bounded rows
- maintainers must have one explicit release-readiness checklist for v1.0.0-rc1

The final docs bundle should include:

- final quickstart guidance
- supported-surface summary
- validation / parity methodology summary
- benchmark methodology and published results
- release-readiness checklist with known residual limitations

## Explicitly Not Required In Phase 11

The following are not part of the bounded Phase 11 contract:

- new MMM features
- reopening HSGP
- widening panel post-model, optimization, pipeline, or plotting scope
- YAML-driven VI
- NetCDF / ArviZ-native interchange
- Dash parity
- pixel-for-pixel plot parity
- a universal claim that Epsilon must outperform Abacus on every workload

## Module Ownership

Phase 11 should land under:

- `scripts/`
  - `export_abacus_validation_fixtures.py`
- `test/validation/`
  - final parity / release-gate harness
- `test/fixtures/abacus/validation/`
  - compact final validation fixtures
- `benchmark/`
  - `Project.toml`
  - `README.md`
  - `inputs/`
  - benchmark runner and suites
  - published result snapshots
- `docs/`
  - release validation and benchmark docs

Phase 11 should consume the closed surfaces from:

- `src/transforms/`
- `src/model/`
- `src/inference/`
- `src/postmodel/`
- `src/optimization/`
- `src/pipeline/`
- `src/plotting/`

It should not take ownership of those runtime contracts.

## Plan Breakdown

### 11-01 Final Parity Harness And Validation Fixtures

**Goal:** freeze the v1 release-gate matrix, create the final validation
fixtures, and land one explicit parity / contract-validation harness.

**Deliverables:**

- `scripts/export_abacus_validation_fixtures.py`
- `test/fixtures/abacus/validation/`
- `test/validation/`
- exact canonical case IDs and file paths are committed rather than chosen
  inside implementation
- the artifact comparison table above is encoded directly in the release-gate
  harness, including the compact fitted-response replay comparison and bounded
  schema checks for the post-model / optimization sidecars
- docs for fixture regeneration and release-gate execution

**Acceptance:**

- the supported v1 release-gate matrix is encoded in committed tests rather
  than implied by the phase docs
- time-series MCMC Abacus-comparable rows have committed compact validation
  fixtures and fixed tolerances for the fitted-response replay surface
- retained transform, post-model, and optimization parity fixtures are folded
  into one final validation story instead of remaining isolated phase-local
  checks
- bounded VI, panel, pipeline, and plotting rows are validated through
  explicit contract-regression coverage with no false Abacus parity claim
- maintainers can run one explicit final validation target locally

**Status:** Completed

### 11-02 Benchmarks And Published Performance Results

**Goal:** measure the bounded v1 surface reproducibly and publish the results
honestly.

**Deliverables:**

- `benchmark/Project.toml`
- `benchmark/README.md`
- `benchmark/inputs/transform_cases.toml`
- benchmark runner and suites
- machine-readable result snapshots under `benchmark/results/`
- docs page summarizing benchmark methodology and results

**Acceptance:**

- benchmark commands are reproducible and documented
- micro and workflow benchmark scopes are fixed to the workload matrix above
- reported benchmark artifacts include environment and machine metadata
- published results cover the exact benchmark IDs above
- any slower-than-Abacus cases are documented honestly instead of hidden behind
  a blanket speed claim

**Status:** Completed

### 11-03 Release Docs And v1.0 Readiness Closeout

**Goal:** close the v1 documentation and readiness contract on top of the
validated and benchmarked surface.

**Deliverables:**

- final README / docs reconciliation for the truthful supported surface
- release validation / benchmark docs
- v1.0.0-rc1 readiness checklist
- known limitations / unsupported rows summary

**Acceptance:**

- `VAL-01` and `VAL-02` are satisfied honestly
- docs describe the actual supported v1 surface rather than the planning
  aspiration
- release-readiness criteria are explicit and reviewable
- Phase 11 closes without hidden follow-up work inside the v1 release gate

**Status:** Completed

## Verification Strategy

Phase 11 verification is release-gate oriented.

Required checks:

- final validation harness passes locally
- existing `make test` and `make docs` still pass
- benchmark suite runs from the documented `benchmark/` entry point
- release docs build cleanly and point to the canonical validation / benchmark
  artifacts
- supported versus unsupported v1 rows are documented consistently across:
  - `README.md`
  - `docs/src/index.md`
  - `REQUIREMENTS.md`
  - `ROADMAP.md`
  - `STATE.md`

Phase 11 should avoid:

- giant opaque fixture blobs
- undocumented one-off benchmark notebooks
- release conclusions that depend on uncommitted local machine context

## Phase Exit Criteria

Phase 11 is complete when:

- the final release-gate matrix is explicit and committed
- the Abacus-comparable supported v1 surface passes the final parity harness
- bounded Epsilon-only supported rows pass explicit contract-regression checks
- benchmark methodology and results are published honestly
- release docs and the v1.0.0-rc1 readiness checklist are complete
- the repo can move into v1 release candidate preparation without reopening
  feature scope
