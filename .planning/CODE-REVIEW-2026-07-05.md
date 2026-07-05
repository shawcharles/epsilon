# Epsilon.jl — Critical Code Review

**Reviewer scope note:** The task brief requested a Python/data-analytics review, but the repository at `/home/user/Documents/GITHUB/shawcharles/epsilon/` is a **Julia** package (`Project.toml`, `src/*.jl`, Julia `Test` stdlib). Epsilon is a Bayesian Marketing-Mix-Modeling (MMM) library built on `Turing.jl`, `JuMP`/`Ipopt`, and `CairoMakie`, positioned as a Julia-native port of a Python reference library called **Abacus**. This review is written against the actual Julia codebase, using general software-engineering, statistical-modeling, and scientific-computing criteria equivalent to what would be applied to a Python data-analytics library.

**Repo stats:** ~20,551 LOC in `src/` (52 files) vs ~12,161 LOC in `test/` (60 files, excluding fixtures), 320 `@testset` blocks, 2,512 `@test` assertions, 410 docstring blocks, 0 `TODO`/`FIXME`/`XXX` markers in `src/`. Latest commit `a63b3d1`.

---

## Executive Summary

Epsilon is an unusually disciplined pre-release Julia package. It has an explicit style guide (`TECHNICAL-STANDARDS.md`), a per-layer test suite that roughly mirrors `src/`, `Aqua.jl` and `Documenter.doctest` wired into the default test run, and a well-maintained `.planning/` paper trail (`ARCHITECTURE.md`, `ROADMAP.md`, `ABACUS-PARITY-LEDGER.md`) that is rare even in mature open-source projects. The statistical core (adstock, saturation, scaling, priors) is generally implemented correctly against known MMM formulas and is validated with golden-fixture parity tests against the Python reference implementation ("Abacus").

The most material weaknesses are: **(1) no hosted CI by maintainer preference, and therefore local quality gates must be canonical** — `.github/workflows/` is intentionally empty, so the repo needs unambiguous `make` targets that developers actually run; **(2) `src/Epsilon.jl` is a 359-line, unstructured single entry point** with ~200 ungrouped `export` statements and 24 near-duplicated one-line dispatch forwarders; **(3) the budget optimizer depends on JuMP's legacy nonlinear registration API** (`JuMP.register`, `JuMP.set_nonlinear_objective`), a real upgrade-risk before any future JuMP major-version migration; and **(4) the whole statistical "correctness" story rests on parity against an external Python project (Abacus) that is not vendored or contained in this repo**, which is a methodological/reproducibility risk the maintainers themselves flag as unresolved (README: "broad Abacus parity is not yet certified").

None of these are fatal for a pre-1.0 package explicitly labeled "port in progress," but they are the highest-leverage things to fix before a public release.

---

## 1. Code Quality

### 1.1 Entry point / public API surface — `src/Epsilon.jl`

- **Ungrouped, flat export list.** Lines 3–196 are ~194 individual `export` statements with no `# --- Section ---` comments and no consistent ordering (alphabetical, by module, or by introduction order). Example excerpt (lines 3–6):
  ```julia
  export deserialize_model_config
  export deserialize_prior
  export EpsilonPrior
  export expand_masked_values
  ```
  A model-config deserializer, a prior deserializer, a prior type, and a masking utility from four unrelated subsystems are interleaved. For a ~200-symbol public API, this actively hurts discoverability and makes it hard to audit "is our public surface still small and intentional" (TECHNICAL-STANDARDS.md §"Short Version", item 5) — ironically the document explicitly asks reviewers to check exactly this.
- **52 `include()` calls with load-order-sensitive but uncommented dependencies** (lines 198–249). E.g. `model/types.jl` → `model/config.jl` → `mmm/*.jl` → `model/builder.jl` must load in that order because later files reference types defined earlier, but nothing in the file says so. Reordering these during a future refactor is a latent footgun with no compiler-enforced guardrail (Julia will just throw `UndefVarError` at include time, which is not self-explanatory to a newcomer).
- **~24 duplicated one-line dispatch forwarders** for `panel_coordinates`, `panel_axes`, `panel_axis`, `panel_coordinate` (lines 269–311), one method per result type:
  ```julia
  panel_coordinates(results::InferenceResults) = panel_coordinates(results.coordinate_metadata)
  panel_coordinates(results::ContributionResults) = panel_coordinates(results.coordinate_metadata)
  panel_coordinates(results::DecompositionResults) = panel_coordinates(results.coordinate_metadata)
  ... (5 more, x4 functions = 24 lines)
  ```
  Every one of these types apparently exposes the field `coordinate_metadata` under the same name — this is a textbook case for either (a) a shared abstract supertype/trait (`AbstractCoordinateResult`) with one generic method, or (b) a `HasCoordinateMetadata` trait. As written, adding a ninth result type requires remembering to add 4 more forwarder lines in this file, in a totally different place from where the ninth type is actually defined — a maintenance trap.
- **Positive:** the file does have real, non-trivial docstrings for the handful of functions that are directly defined here (`fit!`, `approximate_fit!`, `summary_table`, `epsilon_version`, `prior_predict`), each with `@ref`-free but accurate prose describing dispatch behavior across `TimeSeriesMMM`/`PanelMMM`. That is good practice for a stub/dispatch file.

### 1.2 Transform layer — `src/transforms/adstock.jl` (representative sample, full file read)

- Public API functions (`binomial_adstock`, `geometric_adstock`, `delayed_adstock`, `weibull_adstock`) are clean, consistently shaped, well-documented, and validate inputs before doing math (`_validate_alpha`, `_validate_strict_alpha`, `_validate_positive`, lines 120–148) — this is good defensive coding.
- **Minor unused-parameter code smell:** `_geometric_adstock_weights(alpha::Real, l_max::Integer, x_type::Type)` (lines 184–187) never uses `x_type`; it exists purely to keep a uniform dispatch signature with `_binomial_adstock_weights`/`_weibull_adstock_weights`, which do use it. This is defensible for dispatch symmetry but is undocumented — a one-line comment would remove the "is this a bug?" reaction on first read.
- **Combinatorial explosion of near-identical multi-methods.** `_delayed_adstock_weights` and `_weibull_adstock_weights` each have 4 near-identical method overloads to handle every combination of `Real`/`AbstractArray` for their 2 parameters (lines 196–292, ~95 lines). Two of the four in each family are one-liners that just `fill()` a scalar into an array and re-dispatch (e.g. lines 221–229, 282–292) — reasonable Julia idiom for broadcasting-friendly APIs, but it means any future third parameter (e.g. adding a batch dimension to `l_max`) would require doubling method counts again. This is a case where a single generic method operating on `Base.broadcast`-lifted inputs would scale better and cut ~60 lines.
- Docstrings are present and good for every exported function, including edge-case behavior notes, e.g. the CDF weibull docstring (lines 95–97) explicitly documents an intentional Abacus-compatibility quirk ("Epsilon preserves the current Abacus convention of prepending a leading self-retention term... kernel has `l_max + 1` entries") — this is exactly the kind of "why," not just "what," documentation that's often missing in scientific code.

### 1.3 Optimization layer — `src/optimization/optimizer.jl` (full file read)

- Functions are short, single-purpose, and use `Float64` explicitly and consistently for numerical accumulation (e.g. `_clamped_current_spend`, lines 36–40), which is good for a nonlinear solver boundary layer.
- **Legacy JuMP API usage** (see §2.3 below for the correctness implication): `JuMP.register(model, operator_name, 1, evaluate, gradient, hessian)` (line 19) and `JuMP.set_nonlinear_objective(model, JuMP.MAX_SENSE, Expr(...))` (lines 103–107) both use JuMP's older nonlinear interface, which JuMP's own docs mark as legacy in favor of `@operator`/modern nonlinear expressions as of JuMP 1.x. This still works with the pinned `JuMP = "1.30.0"`, but is technical debt that will need remediation before a JuMP major-version bump.
- Iterative bound-projection helpers (`_rebalance_projected_allocation!`, `_apply_exact_projection_residual!`, `_project_to_constraint_bounds`, lines 138–230) are dense, mutate-in-place, and rely on subtle sign/tolerance reasoning without a single inline comment explaining the algorithm (why project post-solve at all, why iterate in `reverse`, why a `sqrt(eps(Float64))`-scale tolerance). This is exactly the kind of numerical bookkeeping code that most benefits from a short prose comment block, and currently has none — a maintainer six months from now (or a new contributor) will need to reverse-engineer the intent from the variable names alone.

### 1.4 General style-guide compliance

- The project claims (`TECHNICAL-STANDARDS.md` §3) "functions/variables use `snake_case`," "mutating functions end in `!`," "abstract types begin with `Abstract`." Spot checks (`fit!`, `approximate_fit!`, `AbstractMMMModel`, `AbstractModel`, `_project_to_constraint_bounds!` is *not* mutating in name form even though some sibling functions with `!` do mutate, e.g. `_rebalance_projected_allocation!`) are broadly compliant. No violations were found in the sampled files.
- Internal helpers are consistently prefixed with `_` and left unexported, matching the "internal APIs stay unexported until intentionally promoted" rule (§3).

---

## 2. Logic and Correctness

### 2.1 Adstock transforms (`src/transforms/adstock.jl`)

- **Geometric adstock** (lines 184–187): `alpha .^ (0:l_max-1)` — correct classic geometric-decay kernel `w_l = α^l`.
- **Delayed adstock** (lines 196–204): `alpha .^ ((lag - theta)^2)` — matches the peak-delayed adstock formulation used in Bayesian MMM literature (peak at `lag == theta`).
- **Binomial adstock** (lines 165–170):
  ```julia
  exponent = inv(convert(out_type, alpha)) - one(out_type)
  base = one(out_type) .- out_type.(collect(0:(l_max - 1))) ./ out_type(l_max + 1)
  return base .^ exponent
  ```
  This is a non-standard power-law kernel with **no formula citation anywhere in the docstring or code**, and it does not correspond to a textbook Binomial-PMF-based adstock despite the function name `binomial_adstock`. It is presumably an intentional 1:1 port of the upstream Abacus/PyMC-Marketing "binomial adstock" implementation, but as written there is no way for a reader (or reviewer) to verify the formula is correct without independently reading the Abacus source. **Recommendation:** add a formula reference/citation (paper or upstream source line) directly in the docstring, since this is precisely the kind of "trust me" numerical code that most needs a paper trail.
- **Weibull CDF weights** (lines 305–309): builds `survival = exp.(-((t/lam)^k))`, prepends a leading `1.0` term, then does a cumulative product. This means the "self-retention" term is always exactly `1.0` regardless of `lam`/`k`, which the docstring (lines 95–97) explicitly flags as a known Abacus-compatibility quirk rather than a bug — good, because otherwise this would read as an off-by-one.
- **Weibull PDF weights min-max normalization** (lines 294–304): normalizes weights into `[0,1]` by `(w - min)/(max - min)`, with an explicit zero-denominator guard (`zero_denominator`/`safe_denominator`/`ifelse`, lines 300–304) that falls back to `1.0` when `max == min` (i.e., a flat kernel). This is correct defensive numerical code — good catch on a real edge case (e.g., `k=1` PDF with certain `lam` can produce a nearly-flat kernel at low resolution).
- `_normalize_last_axis` (lines 313–320) similarly guards a `denominator == 0` case with an `ifelse`-based mask rather than a plain division, avoiding `NaN`/`Inf` propagation. This defensive pattern repeats correctly across the file — a real strength.

### 2.2 Budget optimizer feasibility logic (`src/optimization/optimizer.jl`)

- `_feasible_initial_allocation` (lines 42–77) constructs a JuMP warm-start point by first setting every channel to its lower bound, then greedily filling remaining budget up to each channel's *clamped current spend*, then filling any further remainder up to each channel's upper bound, and finally dumping any last residual onto the final channel (line 74: `allocation[end] += remaining_budget`). This last step is a **potential constraint violation**: if `constraints[end]` has a tight `effective_upper`, dumping the full residual onto it in line 74 can push it above its own upper bound, momentarily producing an *infeasible* warm start (JuMP/Ipopt can usually recover, but it undermines the purpose of computing a "feasible" initial point at all, and the function's own name promises feasibility). **Recommendation:** either prove (and comment) why this can't happen given the two preceding loops, or add a defensive `@assert`/clamp before returning.
- `_solve_budget_optimization_problem` (lines 255–293) checks solver success via `JuMP.is_solved_and_feasible(model; allow_local = true)` (line 259) — using `allow_local = true` means a locally-optimal (not necessarily globally-optimal) nonlinear solve is accepted silently. Given the objective is built from monotone cubic Hermite interpolants over discrete posterior-mean response curves (per the optimization-layer subagent findings), the objective is not guaranteed concave, so Ipopt's local optimum is not guaranteed global. This is a legitimate modeling limitation worth documenting explicitly in the `optimize_budget` docstring rather than leaving implicit in a keyword flag buried in solver-status code.

### 2.3 JuMP legacy API risk (cross-cutting correctness/maintainability issue)

`JuMP.register` (optimizer.jl:19) and `JuMP.set_nonlinear_objective(..., Expr(...))` (optimizer.jl:103–107) belong to JuMP's older nonlinear-modeling pathway. It still functions correctly under the pinned `JuMP = "1.30.0"`, so this is not a present-day correctness bug, but it is a real risk: if/when JuMP formally removes the legacy interface, this file will need a rewrite, and in the meantime the newer `@operator` interface offers better type stability and AD performance that Epsilon is not benefiting from despite the project's own stated preference for type-stable, performant numerical code (`TECHNICAL-STANDARDS.md` §9).

### 2.4 Statistical validation methodology

The project's correctness story for the statistical core is explicitly **parity-testing against an external, non-vendored reference implementation** ("Abacus," a Python library), via `test/fixtures/abacus/*.jl` golden-value fixtures and `test/validation/parity.jl`. This is a reasonable strategy for a deliberate "faithful port," but:
- The README itself states "broad Abacus parity is not yet certified" and enumerates entire categories (HSGP/time-varying parameters, Mundlak/correlated random effects, calibration/lift tests, panel holdout validation, free channel-by-panel optimization) as `missing`/`deferred`.
- Most generated fixture files already record the exporter, local Abacus root, and Abacus git revision in their headers, including `(dirty)` where applicable. The reproducibility gap is therefore narrower than "no provenance": the remaining requirement is to keep that header convention consistent across all fixture exporters and document the convention in `test/fixtures/abacus/README.md`, rather than adding provenance from scratch.

---

## 3. Architectural Choices

### 3.1 Layering

The codebase is organized into clear, cleanly-named layers that map to a typical MMM pipeline: `distributions/` (priors) → `model/` (config, types, builder) → `mmm/` (domain features: seasonality, trend, events, holidays, controls, calibration, media, panel) → `inference/` (MCMC/VI wrappers, diagnostics) → `postmodel/` (contributions, decomposition, response curves, metrics) → `optimization/` (budget optimizer) → `scenario_planner.jl` → `pipeline/` (CLI/config/orchestration) → `plotting/`. This is a sound, conventional architecture for a statistical modeling package and is easy to navigate once the load order in `Epsilon.jl` is understood.

### 3.2 Single monolithic module, no submodules

Everything lives under one `module Epsilon`, with 52 `include()`s creating one flat namespace. For a package this size (20K+ LOC across 9 subsystems) this is workable today but will become a scaling problem: there's no compiler-enforced boundary preventing, say, `plotting/` code from directly reaching into `optimization/`-internal helper functions, since everything shares one namespace. A future refactor into Julia submodules (`Epsilon.Transforms`, `Epsilon.Optimization`, etc.) or package extensions (e.g., moving `CairoMakie`-dependent plotting into a `Requires.jl`/package-extension boundary) would both enforce the layering the directory structure already implies and reduce the mandatory dependency footprint for users who only need the statistical core (see §7 Dependencies).

### 3.3 Dependency direction between `optimization`, `postmodel`, and `plotting`

`Epsilon.jl`'s include order (`postmodel/*` before `optimization/*` before `pipeline/*` before `plotting/*`) suggests a clean one-directional dependency: `optimization` consumes `postmodel` result types (e.g. `response_curve_results`) to build objective surfaces, and `plotting` consumes both. This is the right direction of coupling for a modeling library (compute layers should not depend on presentation layers), and the code sampled is consistent with it — no evidence of `postmodel` or `optimization` importing from `plotting`.

### 3.4 Coordinate/panel metadata duplication pattern

As flagged in §1.1, eight different result types (`InferenceResults`, `ContributionResults`, `DecompositionResults`, `ResponseCurveResults`, `SaturationCurveResults`, `AdstockCurveResults`, `MetricResults`, `PanelBudgetOptimizationResult`) all expose the same `coordinate_metadata` field and need the same 4 accessor methods. This is an architectural smell: it indicates a missing shared abstraction (trait or common supertype) at the `postmodel`/`optimization` result-type layer, not just a style issue in `Epsilon.jl`. Introducing `AbstractPanelCoordinateResult` (or a `HasCoordinateMetadata` trait with `coordinate_metadata(x) = x.coordinate_metadata`) at the type-definition sites, with one set of generic accessor methods, would collapse ~24 lines into ~4 and make the invariant ("every panel-aware result has this field") explicit and enforced by the type system rather than by convention.

### 3.5 CLI/pipeline entry point

`bin/epsilon` (9 lines) is a minimal, correct bash wrapper: it resolves the project root relative to the script location, activates the project environment, and calls `Epsilon.pipeline_main()`, forwarding CLI args after `--`. This is idiomatic and appropriately thin — all real logic lives in `src/pipeline/cli.jl`, which is the right place for it.

---

## 4. Documentation

### 4.1 Docstring coverage

410 docstring (`"""`) blocks across `src/` for 52 files — roughly 8 per file on average, which is a healthy ratio for a library of this size. `TECHNICAL-STANDARDS.md` §7 mandates "every exported symbol needs a docstring" and "usage examples should be runnable `jldoctest` blocks where practical," and this is enforced in CI-equivalent form by `doctest(Epsilon; manual = false)` in `test/runtests.jl:19` — i.e., broken doctest examples fail the test suite, not just a docs build. This is a strong, self-verifying documentation discipline that most Python data-science libraries (which rarely doctest) do not have.

### 4.2 Quality of individual docstrings (spot check)

- `binomial_adstock`/`geometric_adstock`/`delayed_adstock`/`weibull_adstock` (adstock.jl:1–118): consistently describe signature, defaults, broadcasting semantics for array-valued parameters, and — notably — call out an intentional deviation from a naive implementation (the Weibull CDF self-retention quirk, lines 95–97). This is the standard the rest of the codebase should be held to.
- `optimize_budget` (optimizer.jl:295–311): documents supported constraint types, panel-vs-time-series dispatch behavior, and explicitly documents a known limitation ("Free channel-by-panel allocation... intentionally deferred because..."). Good practice — deferred scope is stated in the docstring, not just in a planning doc that a downstream user is unlikely to read.
- **Gap:** no docstring in the sampled files states physical **units** for spend/response quantities (dollars? thousands? local currency?) — this matters for a budget optimizer where a caller could plausibly misinterpret `total_budget` units. This should be added to `optimize_budget`'s docstring and to `MMMData`/`PanelMMMData` type docs.

### 4.3 `Epsilon.jl` documentation gaps

The one real documentation weak spot found: the 52 `include()` statements (lines 198–249) that encode a load-order dependency graph have zero comments. This is not a docstring gap (nothing here is a public API), but it is an architecture-comprehension gap for new contributors, and directly contradicts the spirit of TECHNICAL-STANDARDS.md's demand for clarity — a short comment block grouping includes by subsystem with a one-line rationale would fix this cheaply.

### 4.4 External documentation

`README.md` is unusually thorough and honest about project maturity — it defines a `ported`/`native`/`scaffolded`/`missing`/`deferred` taxonomy for every surface and links to a living parity ledger (`.planning/ABACUS-PARITY-LEDGER.md`, 37KB). This is exemplary "don't oversell your alpha software" documentation practice, rare in the wild. `CONTRIBUTING.md` is short but points reviewers at `TECHNICAL-STANDARDS.md` and states concrete PR expectations (formatting, tests, docs, justified Abacus deviations).

---

## 5. Testing

### 5.1 Structure and scale

- `test/runtests.jl` (20 lines) is a thin orchestrator: it includes 10 layer-specific `runtests.jl` files plus `basic.jl`, then runs `Aqua.test_all(Epsilon; ambiguities = false)` and `doctest(Epsilon; manual = false)` as part of the *same* test run (lines 18–19). This matches TECHNICAL-STANDARDS.md §6 ("runtests.jl stays thin," "Aqua.jl is part of the default quality gate," "Documenter.doctest is part of the test suite") exactly.
- Scale: 60 test files (excl. fixtures) vs 52 src files, 12,161 test LOC vs 20,551 src LOC (ratio ≈0.59), 320 `@testset` blocks, 2,512 `@test` assertions. Test-to-source LOC ratio below 1.0 is on the lower side for a statistically-sensitive numerical library (many mature scientific Julia packages run closer to 1:1 or higher), though line-count ratios are a blunt proxy and much of the "missing" LOC is in the more inherently verbose plotting/pipeline glue rather than the statistical core.
- Every `src/` subsystem (`model`, `mmm` [tested under `test/model/*` in some cases and dedicated files in others], `transforms`, `distributions`, `inference`, `optimization`, `postmodel`, `plotting`, `pipeline`, `scenario_planner`) has a corresponding `test/<layer>/` directory and thin `runtests.jl`, matching TECHNICAL-STANDARDS.md §6's prescribed grouping precisely.

### 5.2 Golden-fixture / parity testing methodology

`test/fixtures/abacus/*.jl` (16+ fixture files, e.g. `geometric_adstock_cases.jl`, `hill_function_cases.jl`, `lift_test_likelihood_cases.jl`) plus `test/validation/parity.jl` implement the "Statistical behavior gets comparison tests against Abacus fixtures" requirement (TECHNICAL-STANDARDS.md §6). This is a strong methodology for a deliberate numerical port: it converts "did we implement the same formula as the reference implementation" from a code-review judgment call into an automated, versioned, regression-tested assertion. This is one of the most valuable and best-executed parts of the whole test suite.

### 5.3 Error-path coverage

`@test_throws` usage is present and reasonably dense in the layers where input validation matters most: `test/model/calibration.jl` (45 occurrences), `test/model/types.jl` (30), `test/model/config.jl` (21), `test/transforms/scaling.jl` (19), `test/transforms/adstock.jl` (19). This indicates error/exception paths (invalid config, out-of-range parameters, malformed calibration payloads) are meaningfully exercised, not just happy-path tested — a common gap in data-science codebases that this project avoids.

### 5.4 Reproducibility of stochastic tests

TECHNICAL-STANDARDS.md §6 explicitly mandates "Randomized tests must set explicit seeds." This review did not exhaustively verify every MCMC/VI test file for a `Random.seed!(...)` call, but the standard being explicitly written down and the project's overall compliance elsewhere in the sampled files makes this plausible; **recommendation**: grep the full `test/inference/` and `test/optimization/` suites for un-seeded `rand`/`randn` calls as a follow-up local lint step (e.g., an Aqua-style custom check) rather than relying on manual review discipline alone.

### 5.5 Gap: hosted CI is intentionally absent; local gates must be canonical

See §7.2 — the entire test suite described above, however well-organized, is currently **not automatically run on any push or pull request**, because `.github/workflows/` contains zero files by maintainer choice. That is acceptable if the project treats local scripts as the source of truth: routine scoped checks need named commands, and phase-closing/full-release checks need one canonical full gate. The risk is not "no GitHub Actions" specifically; the risk is ambiguity about which local checks prove a change.

---

## 6. Performance

### 6.1 Transform layer

- Adstock weight builders (`_geometric_adstock_weights`, `_delayed_adstock_weights`, etc., adstock.jl:165–292) are vectorized (`.^`, `.-`, broadcasting) rather than hand-rolled loops, and reuse `reshape`/`ntuple` to support batched/array-valued parameters without writing separate N-dimensional loop code — idiomatic, allocation-light Julia broadcasting style.
- `promote_type(float(x_type), typeof(float(alpha)))` (adstock.jl:166) is computed once per call at the top of each weight-builder, not inside a hot inner loop — correct placement to avoid repeated type-promotion overhead.
- Kernel sizes are bounded by `l_max` (typically ≤ dozens for weekly/monthly MMM data), and the convolution itself is delegated to a shared `batched_convolution` (not reviewed in full here) — the adstock weight construction itself is `O(l_max)` or `O(l_max × batch_size)`, not a bottleneck at typical MMM scales (channels × weeks in the hundreds to low thousands).

### 6.2 Optimization layer

- The budget optimizer's per-solve cost is dominated by Ipopt's interior-point iterations, not by the Julia glue code; the glue code itself (`_feasible_initial_allocation`, `_project_to_constraint_bounds`) is `O(nchannels)` per call with small constant factors — appropriate, since `nchannels` is typically small (tens, not thousands) for a marketing budget problem.
- Per-channel response curves are pre-interpolated once via monotone cubic Hermite splines and registered as JuMP nonlinear operators (optimizer.jl:9–21) rather than re-evaluated from raw discrete grid data inside the solver's inner loop — this is the right performance pattern (amortize interpolation setup cost once, reuse a smooth cheap-to-evaluate closure for every solver iteration).
- **Legacy-API cost:** the `JuMP.register`-based path (see §2.3) is known in the JuMP ecosystem to have worse type-stability/AD-performance characteristics than the modern `@operator` interface for exactly this "many small per-channel scalar nonlinear operators" use case — this is a performance concern as well as a maintainability one, not flagged anywhere in the code or docs.

### 6.3 No visible egregious anti-patterns

Sampled files show no obvious `O(n²)` patterns where `O(n)` would do, no unnecessary global mutable state, and consistent use of concrete numeric types (`Float64`) at solver boundaries rather than loosely-typed containers that would trigger type instability. This is consistent with the project's stated performance rule (TECHNICAL-STANDARDS.md §9: "keep hot-path functions type-stable... benchmark before micro-optimizing") and with the presence of a dedicated `benchmark/` harness (`benchmark/run_benchmarks.jl`, `benchmark/Project.toml`) for tracking regressions, even though "benchmark regression tracking" is explicitly listed as *deferred* in TECHNICAL-STANDARDS.md §8 rather than currently enforced.

---

## 7. Dependencies

### 7.1 Root `Project.toml`

13 direct dependencies, every one with an explicit, non-wildcard `[compat]` bound (confirmed by direct read of `Project.toml`):

| Dependency | Compat bound | Role |
|---|---|---|
| CSV | 0.10.15 | data I/O |
| CairoMakie | 0.15.9 | plotting backend |
| DataFrames | 1.7 | tabular data |
| Dates, Random, Serialization, Statistics | 1.10 | stdlib |
| Distributions | 0.25.125 | priors/likelihoods |
| Ipopt | 1.14.1 | NLP solver |
| JSON3 | 1.14 | serialization |
| JuMP | 1.30.0 | optimization modeling |
| MCMCChains | 7.7.0 | MCMC diagnostics |
| Turing | 0.43.7 | probabilistic programming / MCMC |
| YAML | 0.4.16 | config format |

`julia = "1.10"` is the declared floor. Test-only deps (`Aqua`, `Documenter`, `ForwardDiff`, `ReverseDiff`, `Test`) are correctly isolated under `[extras]`/`[targets]` rather than pulled into the main `[deps]`, keeping the runtime dependency graph lean — this matches TECHNICAL-STANDARDS.md §5 ("keep the main package lean").

**Compat bounds are unusually tight** — several are pinned to an exact patch version (e.g. `Ipopt = "1.14.1"`, `MCMCChains = "7.7.0"`, `Distributions = "0.25.125"`) rather than a caret-range floor (`^1.14.1`, which Julia's `[compat]` semantics actually apply by default unless the entry starts with `=`). Julia's default compat semantics for a bound like `"1.14.1"` already mean "≥1.14.1, <2.0.0" (caret behavior is implicit), so these are not as restrictive as they look at first glance, but they do mean every dependency's latest breaking-safe minor/patch bump is auto-accepted, which is standard and fine — no action needed here, just noting the bounds are correctly *present*, satisfying §5's requirement, and not overly loose (no `"*"` found anywhere).

### 7.2 No hosted CI configuration exists

`.github/workflows/` was confirmed empty via direct filesystem check (`ls -la .github/workflows/` → 0 files). The maintainer preference is to avoid GitHub Actions and rely on local scripts instead. That shifts the quality-gate requirement rather than removing it:
- routine scoped iteration needs a fast command that does not pay the ~20 minute full-suite cost,
- subsystem work needs named focused lanes that recreate any shared test helper context,
- phase-closing and pre-merge work need a single full local gate that runs formatting, `Pkg.test()`, Aqua, doctests, and docs build,
- known repo-wide Runic drift must not make scoped work unreproducible.

The highest-leverage fix is therefore **canonical local gate scripts**, not hosted CI. `make check`, `make check-optimization`, `make check-validation`, and `make check-full` are the appropriate enforcement surface for this repo.

### 7.3 Manifest handling

`Manifest.toml` (root, `docs/`, `benchmark/`) is correctly `.gitignore`'d (confirmed: `/Manifest.toml`, `/docs/Manifest.toml` present in `.gitignore`), which is the right choice for a *library* package (as opposed to an application, where committing the Manifest for full reproducibility would be preferred). This is textbook-correct Julia package hygiene.

### 7.4 Formatter/linter configuration

`Runic.jl` is used as a zero-configuration formatter, invoked via `make format`/`make format-check` targets (`Makefile`) using a separate `--project=@runic` shared environment rather than adding Runic as a project dependency — a clean way to avoid polluting the package's own dependency graph with a dev-tool. No `.JuliaFormatter.toml` or similar config file was found, which is expected and correct since Runic is explicitly zero-config by design (per TECHNICAL-STANDARDS.md §2's own rationale). No linter beyond Runic (formatting only, not static analysis) is configured; JET static analysis is explicitly deferred (§8).

### 7.5 License

`LICENSE` file is present at the repository root (not read in full in this pass, but its presence was confirmed in the file listing); a public statistical library benefits from an OSI-approved permissive license (MIT/Apache-2.0/BSD) for adoption — recommend explicitly confirming and stating the license name in `README.md`'s top section if not already done, since it currently is not mentioned in the first 80 lines of the README.

### 7.6 Dependency risk assessment

No deprecated or unusually niche packages were found. `Turing.jl`, `Distributions.jl`, `JuMP`/`Ipopt`, `CairoMakie`, `DataFrames.jl`, `CSV.jl`, `YAML.jl`, `MCMCChains.jl` are all mainstream, actively-maintained packages in the Julia scientific-computing ecosystem, and the pinned versions (Turing 0.43.7, JuMP 1.30.0, Distributions 0.25.125) correspond to genuinely current releases at time of review — there is no evidence of the project depending on an abandoned or stale package. The main risk is architectural rather than version-related: bundling `CairoMakie` (a heavyweight plotting stack) as a hard, non-optional dependency of the main package (rather than as a package extension/weak dependency) means every user of the statistical core pays the compile-time/load-time cost of a full plotting backend even if they never plot anything — this is worth revisiting once Julia's package-extension mechanism is adopted for `plotting/`.

---

## 8. Prioritized Recommendations

1. **Make local quality gates canonical.** Keep `.github/workflows/` empty if that is the project policy, but encode routine and full verification in first-class `make` targets: scoped touched-file formatting plus focused tests for day-to-day work, and a full local gate for phase closures and pre-merge checks.
2. **Refactor `src/Epsilon.jl`'s export list and duplicated dispatch forwarders.** Group exports by subsystem with section comments; collapse the ~24 `panel_coordinates`/`panel_axes`/`panel_axis`/`panel_coordinate` forwarders (lines 269–311) into a shared trait or abstract supertype defined alongside the result types themselves, not centrally in the entry-point file.
3. **Migrate `src/optimization/optimizer.jl` off JuMP's legacy nonlinear API** (`JuMP.register`, `Expr`-based `set_nonlinear_objective`) to the modern `@operator`/nonlinear-expression interface before the next JuMP major version, and document the local-vs-global optimum caveat (`allow_local = true`, optimizer.jl:259) directly in `optimize_budget`'s docstring.
4. **Add formula citations to non-obvious statistical kernels**, especially `_binomial_adstock_weights` (adstock.jl:165–182), which currently has no traceable reference for its power-law formula despite the "binomial" name suggesting a different, more standard construction.
5. **Add explicit units documentation** (currency/scale of `total_budget`, `spend`, response metrics) to `optimize_budget`, `MMMData`, and `PanelMMMData` docstrings.
6. **Consider moving `CairoMakie`-backed plotting into a package extension** to shrink the mandatory dependency/compile footprint for statistical-core-only users, consistent with the project's own stated "keep the main package lean" dependency policy.
7. **Audit Abacus fixture provenance for consistency.** Generated fixture headers already record exporter, local Abacus root, and git revision in many files; ensure every exporter preserves that convention, document the `(dirty)` suffix, and add a periodic manual re-sync checklist.
8. **Add a small `@assert`/clamp safety net (or a comment proving correctness) to `_feasible_initial_allocation`'s final residual-dump step** (optimizer.jl:74), which can theoretically push the last channel above its own upper bound before the solver even starts.

---

## 9. Overall Assessment

For a package explicitly labeled pre-release ("Abacus Julia port in progress"), Epsilon.jl is well above the median bar for engineering discipline in scientific/statistical software: it has a written style standard that is largely followed in the sampled files, doctested public documentation, a well-partitioned test suite with genuine golden-fixture numerical validation, and an unusually honest, granular account of its own incompleteness in the README and `.planning/` ledger. The gaps are concentrated and fixable: local quality gates need to be canonical because hosted CI is intentionally absent, one overgrown entry-point file would benefit from a straightforward refactor, and the optimizer depends on JuMP's legacy nonlinear API. None of these undermine the soundness of the statistical core itself, which — where sampled — implements standard MMM transform mathematics correctly and defends against the numerical edge cases (division by zero, degenerate kernels) that most commonly cause silent bugs in this domain.
