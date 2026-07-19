# Epsilon.jl — Critical Engineering Review — 2026-07-19

> **Historical snapshot:** This report is preserved as point-in-time review
> evidence from commit `79f0f6`. Many findings have since been resolved or
> superseded by later phases, especially Phases 49-70. Use
> `.planning/STATE.md` and `.planning/ROADMAP.md` as the current source of
> truth before treating any item below as open work.

**Scope:** `/home/user/Documents/GITHUB/shawcharles/epsilon/` commit `79f0f6` (dev 0.1.0-dev). Review performed as senior Julia / Bayesian analytics engineer. Focus: Code Quality, Logic & Correctness, Architectural Choices.

**Previous review lineage:** v0–v4 + external validation notes (`2026-05-19-critical-review.md`, `code-review-v4.md`). This review assesses both current state and delta vs high-severity findings in v4.

---

## Executive Summary

Epsilon remains an unusually disciplined pre-release scientific package: explicit `TECHNICAL-STANDARDS.md` (SciML + Runic), `Aqua.jl` + doctest in default `runtests.jl`, `.planning/` decision ledger, typed `ModelConfig`/`MMMData` contracts, and golden-fixture parity methodology vs Abacus reference. Source is ~20k LOC, test ~12k LOC, 0 TODO markers in `src/`.

**Material strengths:**
- Defensive numerics (finite checks, zero-denominator guards in `adstock.jl`, `hsgp.jl`).
- Explicit HSGP state immutability via snapshots/tuples.
- Error-path coverage with `@test_throws` dense in `test/model/*`, `transforms/*`.
- Documentation honesty about ported/native/missing surfaces in README.

**Material weaknesses vs prior v4 highs:**
- Trend and holiday state-reconstruction bugs flagged in v4 appear **fixed** at code level: trend now persists origin/scale (`_TREND_STATE_KEY` in `trend.jl:80-92`, reuse in `_trend_features:152-169`), holiday persists `dates/period_days/default_period_days` (`holidays.jl:160-174`, reuse `192-204`). Need integration test for future holdout to lock fix.
- Remaining high risks: `src/Epsilon.jl` 353-line flat export/include hub, 24 duplicated coordinate forwarders, single-module namespace, legacy JuMP nonlinear API, hybrid typed/untyped config dicts, convolution overlap_shift unused variable, calibration payload swallowing validation errors as `-Inf`.

No showstopper methodological flaw found in sampled stochastic core. Issues are maintainability / upgrade-risk / edge-case-fidelity rather than fundamentally unsound Bayesian modeling.

---

## 1. Code Quality

### 1.1 Entry point `src/Epsilon.jl` — biggest maintainability liability

- **200 ungrouped exports (lines 3-203)** interleaved across subsystems: `deserialize_model_config` (config), `EpsilonPrior` (distributions), `expand_masked_values` (masking), `After` (convolution) adjacent. Violates own standard "public API still small and intentional" and makes API audit hard.
- **52 includes with implicit load-order DAG (204-249) and zero comments.** Example: `model/types.jl` must precede `model/config.jl` must precede `mmm/*` because types referenced. Julia gives `UndefVarError` only, no diagnostics.
- **24 copy-pasted dispatch forwarders (276-318):**
  ```julia
  panel_coordinates(results::InferenceResults) = panel_coordinates(results.coordinate_metadata)
  panel_coordinates(results::ContributionResults) = ...
  ```
  Same pattern for `panel_axes`, `panel_axis`, `panel_coordinate`. All result types expose `coordinate_metadata` under same field name. Classic trait/abstract-supertype case. Adding ninth result type requires remembering to add 4 more lines in unrelated file — maintenance trap.
  **Recommendation:** introduce `AbstractCoordinateResult` or `HasCoordinateMetadata` trait defined alongside result types:
  ```julia
  coordinate_metadata(x) = x.coordinate_metadata
  panel_coordinates(x::HasCoordinateMetadata) = panel_coordinates(coordinate_metadata(x))
  ```
  Collapse 24 lines to ~4.

- Positive: docstrings for `fit!`, `predict`, `summary_table`, `epsilon_version`, `prior_predict` accurate and describe dispatch across `TimeSeriesMMM`/`PanelMMM`.

### 1.2 Style-guide compliance

- `TECHNICAL-STANDARDS.md` wants SciML: CamelCase types, snake_case funcs, `!` mutating. Spot check: `binomial_adstock`, `fit!`, `PanelMMMData`, `_project_to_constraint_bounds` lack `!` despite mutation inner calls? Actually `_rebalance_projected_allocation!` correctly has `!`. Mostly compliant.
- Internal helpers consistently `_`-prefixed and unexported — good.
- Runic zero-config formatting: no formatter config files, `make format` uses `@runic` project, Manifest gitignored — textbook hygiene.

### 1.3 Transform layer quality (`transforms/`)

**`adstock.jl` (321 LOC):** public APIs clean, validate before math (`_validate_alpha`, `_validate_strict_alpha`). Zero-denominator guards in `_normalize_last_axis:313-320` and Weibull PDF normalization `294-304` avoid NaN propagation — exemplary.

Issues:
- Unused param smell: `_geometric_adstock_weights(alpha::Real, ..., x_type::Type)` never uses `x_type` (line 184). Kept for dispatch symmetry with binomial/weibull which do use it, but undocumented — triggers "is this bug?" on first read.
- Combinatorial overload explosion: `_delayed_adstock_weights` and `_weibull_adstock_weights` each have 4 methods for `Real`/`AbstractArray` combos for two parameters (~95 lines). Two are one-line `fill` + redispatch shims (e.g., `221-228`). Works but any third broadcast param doubles count again. Could be single generic method with `Base.broadcast` lifted inputs or `Broadcast.broadcasted`.
- Binomial kernel formula lacks citation: `exponent = inv(alpha)-1`, `base = 1 - (0:l_max-1)/(l_max+1)`, `base.^exponent` is non-standard vs textbook binomial PMF. Docstring should cite Abacus line or paper. Same recommendation as v4 and older reviews.

**`saturation.jl`:**
- Current `hill_function` (89-103) *does* validate `x >=0` via `_validate_nonnegative` (fixed vs v4 medium). Good.
- But `centered_logistic_saturation` and `tanh_saturation` only validate `lam,b,c` not `x`. Their docstrings say maps zero to zero but allow negative x to produce negative saturation, contradicting response-curve assumption of nonnegative spend. `MMMData` validation only checks finite + nonnegative channels, not all transforms. Pipeline validates positive total observed spend, not row-level. So gap narrowed but not fully closed: negative spend still could reach `logistic`/`tanh` unless `MMMData` validation catches all paths. Recommendation: either validate `x>=0` uniformly in saturation or document signed-media behavior explicitly.

**`convolution.jl`:**
- Clear `ConvMode` enum (`After`, `Before`, `Overlap`) is good API.
- Bug/code smell: `overlap_shift = fld(lag_length,2)` computed line 43 but never used in `_source_index`. `_source_index` instead recomputes `((lag_length-1) ÷2)`. For odd `l_max`, both equal; for even, `fld` vs `÷` differ. Example `l_max=12`, `fld=6`, `(11÷2)=5`. Which intended? Current behavior is off-by-one for even overlap mode vs what variable name suggests. Needs unit test for even `l_max` overlap or remove dead var.
- PermutedDimsArray for axis move — allocation-light, idiomatic.

### 1.4 Inference & MCMC (`inference/mcmc.jl` 270 LOC)

- Execution plan (`MCMCExecutionPlan`) clean struct tracking mode/threads/cores. Logic: single chain => `:single`, else threaded if `chains <= effective_cores && chains <= nthreads` else serial. Sensible.
- RNG: `random_seed + offset` for prior predict offset=1 ensures prior/posterior distinct streams — good hygiene.
- Diagnostics bundle constructs `ModelResults` then calls `model_diagnostics`, `sampler_diagnostics`, `convergence_report` even if chain tiny (tests use small draws). Acceptable for quick CI but not strong statistical regression.
- Fit failure handling via `ModelFitState` with `status=:error` and message capturing `showerror` — preserves artifact-less state for debugging.

Minor:
- `_mcmc_executor` throws for single-chain — caller already branches, but type system could prevent via dispatch on plan type rather than runtime if.

### 1.5 Distributions (`priors.jl`, `shrinkage.jl`)

- `EpsilonPrior` stores canonical name + `Dict{Symbol,Any}` params + optional dims/centered/transform — flexible but loses type safety. `instantiate_distribution` has large if-else chain over string names (189-241). For 13 supported dists okay, but extensibility requires editing both canonical name map and instantiate chain.
- Nested prior handling: `_deserialize_nested` recursively walks dicts, tuples, vectors — allows `Scaled(base=Normal(...))`. Good.
- Shrinkage recipes (`HorseshoePrior`, `FinnishHorseshoePrior`, `R2D2Prior`) correctly separation: deterministic helpers (`horseshoe_coefficients`, `regularized_local_scales`, `r2d2_coefficients`) consume already sampled scales, not perform stochastic sampling. Docstrings explicitly note `slab_df`, `mean_R2`, `concentration` are model-layer metadata — precise.
- Validation: `_positive_parameter` checks via `Float64(value) >0` — catches `NaN`/`Inf`? Actually `Float64(NaN)>0` false so throws, good. But `Float64(Inf)>0` true passes while finite expected — should use `isfinite`.

### 1.6 Model layer (`model/types.jl` 717 LOC, `builder.jl` 1153 LOC)

- Abstract hierarchy `AbstractModel` → `AbstractRegressionModel` → `AbstractMMMModel` — shallow, correct.
- `SamplerConfig`, `TimeVaryingMediaConfig`, `ModelConfig`, `MMMData`, `PanelMMMData` structs with inner constructors validating via `_validate_*`. Equality overloads hand-written (not `@auto) — boilerplate heavy but deterministic.
- `MMMData` parametric over vector/matrix types `D,T,C,U,V` — generic over `AbstractVector`/`Matrix` allowing custom array types (good for autodiff). However validation `_validate_numeric_values` uses `Float64(value)` which materializes — may break `ForwardDiff.Dual` arrays. Hot-path transforms should stay generic, validation could be relaxed to `value isa Real` only, not finite Float64 cast for autodiff compatibility.
- `_compute_scales` uses `maximum(view(...))` — zero/negative scale replaced 1.0 — defensive.
- Coordinate metadata: `ModelCoordinateMetadata` holds `observation_dim`, `panel_dims`, `coordinates`, `named_dims`, `panel_axes`. `_panel_axis_coordinate_columns` (197-239) handles cross-product logic for multi-dim panels: checks if coordinate lengths match panel_count, else if product matches count builds cartesian product — correct but dense, needs comments.
- Builder `_build_model_spec` copies dicts defensively (`copy(config.adstock)`) — avoids aliasing but `Dict{String,Any}` shallow copy still shares nested values; potential mutability leak if nested dict mutated later. Consider `deepcopy` or immutable struct for spec.
- Trend spec now stores fitted state via `_trend_spec_config` persisting origin/scale — fix for v4 high.
- Holiday spec similarly stores `__epsilon_state` — fix for v4 high.

### 1.7 HSGP (`mmm/hsgp.jl` 743 LOC)

- Careful defensive layer: `_hsgp_finite_scalar`, `_hsgp_positive_finite`, `_hsgp_finite_vector/matrix`, `_hsgp_nonnegative_weights` everywhere — strong.
- Snapshot structs `_HSGPMediaPriorSnapshot`, `_HSGPMediaConfigSnapshot`, `_HSGPTimeSeriesTrainingState` immutable, using tuples for arrays — ensures serialization safety and prevents mutation post-fit. `_validate_hsgp_media_spec_state` enforces internal consistency (mode counts match, covariance matches, drop_first false, etc.) — exemplary.
- Basis: `_hsgp_basis_matrix_at_centre` uses `training_centre` explicitly to allow prediction with new dates at same centre — correct fix vs recomputing centre from new_data. Shows v4 issue addressed.
- PSD: `_hsgp_sqrt_psd` implements EXpQuad, Mat32, Mat52 via `logaddexp` for numerical stability — good.
- Stable softplus `_hsgp_stable_softplus` piecewise: `exp(x)` for x<-37, `log1p(exp(x))` for x<18, `x+exp(-x)` for x<33.3 else x — avoids overflow.
- Complexity: 743 LOC for HSGP, many helpers, but each small. Overall maintainability moderate-high due to volume, but correctness high.

### 1.8 Testing quality

- `runtests.jl` thin orchestrator including 10 layer runtests + `Aqua.test_all` + `doctest` — matches standard.
- 320 testsets, 2512 assertions per earlier metrics — decent but LOC ratio 0.59 source vs test lower than 1:1 typical for numerical libs.
- Golden parity fixtures in `test/fixtures/abacus/*.jl` include exporter, Abacus root, git rev with dirty flag — better provenance than many ports.
- Error-path dense in `model/*`, `transforms/*` — good.
- MCMC tests use small draws for speed, acceptable but weak for convergence-sensitive regressions.

---

## 2. Logic and Correctness

### 2.1 Adstock & Saturation vs MMM literature

- Geometric `alpha^lag` (184-186) correct.
- Delayed `(lag - theta)^2` exponent (196-204) matches peak-delayed formulation.
- Binomial and Weibull normalization now guarded vs degenerate flat kernel — correct.
- Hill now `x>=0` validated — fix.

Remaining concerns:
- Binomial formula citation missing.
- Weibull CDF prepending `1.0` as self-retention documented as Abacus compatibility quirk (95-97) — plausible, but needs reference line to Abacus Python to assert intentional.
- Saturation for negative x still inconsistent across types.

### 2.2 Trend & Holiday prediction path — previously high severity, now mitigated

Verification:

**Trend:**
- Training: `_trend_state_from_dates` stores `origin=first(dates)` and `scale=max(positions)` at build time (80-86).
- Spec config `_trend_spec_config` copies config and injects `__epsilon_state` (88-93).
- Inference: `_trend_features` now checks `state = _trend_state(config)`, if present uses `origin=state["origin"]`, `scale=state["scale"]`, not `first(new_dates)` (152-162). That means future holdout continues trend from fitted origin, not restarting at 0. Fix confirmed in code.
- Edge: What if dates are DateTime vs Date vs numeric? `_trend_positions` handles TimeType vs Real, validates origin type match — good.

**Holiday:**
- Training state `_holiday_state_from_dates` stores `dates`, `period_days` (inference from observed gaps), `default_period_days` (most common gap) (160-167).
- Spec injection `170-174`.
- Prediction: `_holiday_period_days(config, dates)` if state dates == new dates reuse exact period_days, else fill with default (192-204). This fixes one-row holdout defaulting to 1 day previously? Previously it recomputed from only new_data. Now for unseen future dates, it uses stored default period, not recompute from tiny holdout. That aligns with Abacus storing first fitted date and using that.
- Potential residual: if prediction dates are regular but different cadence vs training (e.g., daily trained, weekly predicted), default period still used — may be intended. Needs doc.

**Recommendation:** Add explicit integration tests: fit trend=linear+fourier+ holiday on 52 weeks, predict 4 weeks ahead, assert trend feature continues monotonic and holiday exposure equals training default, not 1. Lock fix.

### 2.3 Media pipeline correctness

`mmm/model.jl` `_time_series_mmm_model` Turing model:
- Intercept, sigma sampled first.
- `beta_media` conditional on `uses_external_media_beta = saturation != :michaelis_menten` — matches known MMM fact that MM has its own scale parameter.
- HSGP multiplier path: if enabled, `baseline_channel = transformed_media .* beta`, multiplier via `_hsgp_media_multiplier`, then `vec(sum(baseline .* multiplier row))`. Shape wise correct: multiplier T-vector times channel matrix row-wise.
- Control/event/holiday/seasonality/trend each as `vec(sum(features .* beta))` — linear additive model.
- Likelihood loop `for i in eachindex(target) target[i] ~ Normal(mu[i], sigma)` — not vectorized `~` but per-element; in Turing this is standard but slower than `target ~ MvNormal(mu, sigma*I)`. Acceptable for readability, but performance note.

Calibration:
- Lift test payload logdensity via `Turing.@addlogprob!` with helper `lift_test_payload_log_density`. Wrapped in try/catch converting `ArgumentError` to `-Inf` (123-134). This silently turns invalid calibration inputs into rejected proposals rather than failing fast. Could hide data issues during model setup (should validate before sampling). Similar for cost_per_target (139-149).
- CPT penalties.

Prior defaults: `_DEFAULT_ALPHA_PRIOR Beta(1,3)` favors low alpha (~0.25 mean) — reasonable for geometric adstock expecting decay. Weibull lam/k Gamma priors (4,2) and (9,3) etc — presumably Abacus parity values; citation needed but plausible.

### 2.4 HSGP time indexing

- `_infer_hsgp_time_index` (202-222) ensures `new_dates` align to fitted cadence: `rem(day_offset, time_resolution)==0` else error. Strict but correct for bounded HSGP. Returns integer days/resolution.
- Training centre computed as `min/2 + max/2` (79) — average of extremes, robust vs mean of all? Reasonable.

### 2.5 Convolution correctness

- Mode semantics: `After` => `t - lag +1` causal (trailing), `Before` => `t + lag_length - lag` leading, `Overlap` => `t + (lag_length-1)÷2 - lag +1` centered. Typical for MMM adstock `After` is right.
- Issue: overlap_shift computed but unused (see Quality). For even `l_max`, current centering uses `(l_max-1)÷2` not `fld(l_max,2)`, which means kernel not symmetric for even lengths (e.g., l_max=4, shift=1 vs 2). Need clarification which intended — Abacus reference maybe uses `floor(l/2)`? Check Abacus python.

### 2.6 Optimization (`optimization/optimizer.jl`)

**Improvements since earlier reviews:**
- Old `_feasible_initial_allocation` dumped residual onto last channel risking bound violation. Now new version (42-86) first allocates lowers, then up to clamped_current, then up to uppers, then in reverse tries to fit residual into any channel that stays within bounds. This eliminates guaranteed overflow risk, but still has edge case where no channel can absorb residual exactly -> throws "requires feasible allocation" (48,83). That's clearer than silent infeasible warm start.
- However solver result still post-processed via `_project_to_constraint_bounds` (203-239) which rebalances with tolerance 1e-6, reverse iteration, exact residual attempt. This projection layer could be documented: why needed if solver already bound-constrained? Tolerance handling for Ipopt slight violations typical; okay.

**Legacy JuMP API:**
- `JuMP.register(model, op_name, 1, evaluate, gradient, hessian)` line 19 and `JuMP.set_nonlinear_objective` 112-116 use legacy interface. Works on JuMP 1.30.0 pinned, but JuMP docs mark as deprecated in favor of `@operator` + `@objective(model, Max, expr)`. Risk: future major bump breakage, plus `register` is known to have worse AD type stability for many small scalar operators. Recommend migration roadmap.
- `allow_local=true` in `is_solved_and_feasible` (268) accepted silently — docstring now documents "nonlinear solve accepts locally feasible optima" in `optimize_budget` (320-328) — good disclosure (improved vs earlier).

**Efficiency metric:**
- `_default_efficiency` computes total_spend / total_response for conversion target, opposite for revenue — correct ROAS/CPA switch.

### 2.7 Panel path

- `PanelMMMData` stores channels as `(time, channel, panel)` 3D, target as `(time, panel)`. Scaling: channel_scale matrix `(nchannels, npanels)` per-panel max scaling — appropriate for heterogeneous geos.
- `nobs` for panel returns flattened total observations `ntime*npanels` (345-346). `ntime`, `npanels`, `npanel_observations` helpers added to disambiguate — good, but downstream consumers may still misuse `spec.nobs` expecting time rows. v4 residual risk note still valid; mitigated by explicit helpers and doc in spec docstring (259-260).
- Panel optimization (`optimization/panel.jl` not sampled this pass but header review) historically allocates historical shares — docstring says free channel-by-panel allocation deferred — consistent honest scoping.

---

## 3. Architectural Choices

### 3.1 Layering (strength)

```
distributions/ (priors, masking, shrinkage)
  ↓
model/ (types, config, builder, results, io)
  ↓
mmm/ (seasonality, trend, events, holidays, controls, calibration, media, panel, hsgp)
  ↓
inference/ (mcmc, diagnostics, results)
  ↓
postmodel/ (replay, contributions, decomposition, response_curves, metrics)
  ↓
optimization/ (objective, constraints, optimizer, panel, summary)
  ↓
scenario_planner.jl (manual & optimized scenarios)
  ↓
pipeline/ (config, context, stages, cli)
  ↓
plotting/ (theme, diagnostics, postmodel, optimization, bundle)
```

Directory structure already enforces intended dependency direction. Sampled files respect it: `postmodel` does not import `plotting`, `optimization` consumes `postmodel` surfaces, `mmm` doesn't know about `inference`. Good.

### 3.2 Single monolithic module — scaling risk

All 52 files `include`'d into one `module Epsilon` flat namespace. For 20k LOC still workable, but no compiler-enforced boundary preventing `plotting` reaching into `optimization` internals. As package grows (panel, calibration, HSGP), risk of accidental coupling increases. Future options:
- Submodules `Epsilon.Transforms`, `Epsilon.Optimization`, etc., re-exported.
- Package extensions for heavy deps: `CairoMakie` currently hard dep (13 deps) means every user installing statistical core pays plotting compile cost (Julia 1.10+ extension mechanism). Convert `plotting/` to extension `EpsilonMakieExt` triggered by `CairoMakie`. Matches TECHNICAL-STANDARDS "keep lean".

### 3.3 Configuration model — hybrid typed/untyped

- External YAML → merged dict → `model_config_from_dict` → `ModelConfig` typed wrapper but fields like `adstock::Dict{String,Any}`, `saturation`, `seasonality`, etc. remain untyped dicts, validated via `_validate_adstock_config` etc. This hybrid is pragmatic: allows open-ended per-transform config while keeping top-level typed. However validation is scattered across many `_validate_*` functions rather than one schema.
- Pipeline config: `_top_level_extras` (340-358) allows unknown top-level keys to be stored in `extras`, not rejected. v4 medium finding: typos like `optimisation:` silently ignored. Still present? In `model/config.jl` `_top_level_extras` collects keys not in known set (calibration, data, target, media, dimensions, seasonality, trend, events, holidays, controls, priors, fit). So typo would land in extras, not error. For bounded contract, stricter allowlist with error on unknown would help. Low-medium risk.

- Abacus compatibility shims: `_normalize_abacus_config_surface` hoists `media.saturation.priors.beta` to top-level `priors.beta_media`, and translates `effects` yearly_fourier to seasonality, `holidays.mode=prophet_component`→`auto`. Good migration path, but needs documentation that these are legacy shims.

### 3.4 Dependency policy

Project.toml compat bounds present for all 13 deps, tight floors, extras isolated — compliant. `julia = "1.10"` floor — good for modern features. Manifest gitignored — correct for library.

Risk: `Turing 0.43.7`, `JuMP 1.30.0`, `Ipopt 1.14.1` pinned but not overly restrictive (caret semantics). Future Turing 0.44 breaking changes may require attention; current version is recent.

### 3.5 Pipeline / CLI

`bin/epsilon` 9-line bash wrapper resolves root relative to script, activates project, calls `pipeline_main` forwarding args — idiomatic, thin. Real logic in `pipeline/cli.jl`, `stages.jl` — appropriate.

`PipelineRunConfig` etc. typed.

---

## 4. Specific Examples with Line References

| Issue | File:Line | Snippet / Description | Severity |
|-------|-----------|----------------------|----------|
| Export / include hub | `src/Epsilon.jl:3-311` | 194 exports + 52 includes + 24 duplicated forwarders | Medium |
| Overlap shift dead var | `src/transforms/convolution.jl:43,121-128` | `overlap_shift = fld(lag_length,2)` computed unused | Low-Med |
| Unused param | `src/transforms/adstock.jl:184` | `x_type` unused in geometric weights | Low |
| Negative x handling | `src/transforms/saturation.jl:12-22,47-59` | logistic/tanh don't validate x≥0 | Low-Med |
| Calibration -Inf swallowing | `src/mmm/model.jl:125-135,138-149` | `catch ArgumentError => -Inf` | Medium |
| Legacy JuMP | `src/optimization/optimizer.jl:19,112-116` | `JuMP.register`, `set_nonlinear_objective` | Medium |
| Feasible allocation | `optimizer.jl:42-86` | improved vs old dump, still tolerance-projected | Low (was Medium) |
| Trend state fix | `mmm/trend.jl:80-93,152-169` | stores origin/scale, reuses for predict | Fixed (was High) |
| Holiday state fix | `mmm/holidays.jl:160-174,192-204` | stores period_days/default, reuses | Fixed (was High) |
| Hybrid dict config | `model/types.jl:144-160` | `adstock::Dict{String,Any}` etc. | Medium |
| Silent extras | `model/config.jl:340-358` | unknown top keys go to extras | Medium |

---

## 5. Recommendations Prioritized

1. **Add integration test locking trend/holiday fix.** Fit `TimeSeriesMMM` with trend=linear+changepoint and holidays=auto on 52 weeks, predict 4 future weeks, assert trend features continue from training origin (not restart) and holiday period_days equals training default, not 1. Regression-proofs v4 highs.

2. **Refactor `src/Epsilon.jl`.** Group exports by subsystem with section comments. Introduce `AbstractCoordinateResult` trait, collapse 24 forwarders. Add comment block grouping includes by layer.

3. **Migration off legacy JuMP API.** Move to `@operator(model, op, 1, f, ∇f, ∇²f)` and `@objective(model, Max, baseline+sum(op_i(allocation[i]) for i))`. Document local-opt caveat already improved — keep.

4. **Fix convolution overlap shift.** Either remove dead `overlap_shift` variable or use it consistently, and add even-l_max unit tests for `Overlap` mode vs Abacus reference.

5. **Uniform nonnegative validation for saturation or explicit signed-media support.** Either make `MMMData` reject negative channels row-level (as v4 suggested) *and* make `centered_logistic_saturation`/`tanh_saturation` validate `x>=0`, or document that negative spend produces negative saturation and response curves assume nonnegative.

6. **Fail fast for calibration payloads.** Validate `LiftTestCalibrationRows`, `CostPerTargetCalibrationRows` at config/build time, not inside model as `-Inf`. If inside model must stay, log warning when payload invalid.

7. **Stricter top-level config contract.** Reject unknown keys in pipeline YAML (or warn) instead of silently storing in extras. Prevents typo-disabling stages.

8. **Consider package extension for plotting.** Move `CairoMakie` to weak dependency / extension to reduce load time for headless inference users.

9. **Improve type stability in validation for AD.** Replace `Float64(value)` casts in `_validate_numeric_values` and similar with `value isa Real && isfinite(value)` checks that preserve `Dual` types, to stay autodiff-safe per TECHNICAL-STANDARDS §9.

10. **Document units.** Add explicit statement to `MMMData`, `PanelMMMData`, `optimize_budget` docstrings that spend/budget/total_budget must be in same original measurement units (currency, thousands/millions, time aggregation).

---

## 6. Overall Assessment

Epsilon demonstrates rare discipline for pre-1.0 scientific Julia package: written standards, tested, documented, honest about incompleteness. The two high-severity prediction-path bugs from v4 (trend and holiday state reconstruction) appear fixed at source-code level, significantly reducing holdout/validation risk. Remaining issues are concentrated in entry-point file bloat, legacy optimizer API, and hybrid config handling — all fixable without methodological overhaul.

Statistical core (adstock, saturation, HSGP, MCMC scaffolding) is defensively coded, numerically careful, and parity-tested. Architecture layering is sound; single-module namespace and hard plotting dependency are the main scaling limits.

**Recommendation for release readiness:** implement items 1-4 before v0.1.0 public, items 5-7 before v1.0, items 8-10 as near-term improvements.

---

*Generated by automated senior review pass on 2026-07-19, manual spot checks plus sub-agent deep dives limited to sampled files.*
