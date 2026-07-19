# Phase 68: Plotting Extension Boundary

## Status

Implemented.

## Objective

Move the CairoMakie-backed plotting implementation out of Epsilon's mandatory
runtime dependency set while preserving the existing public plotting names and
keeping non-plot modelling, inference, post-model, optimisation, scenario, and
pipeline workflows usable in headless installs.

This is dependency-boundary work only. It does not change model semantics,
sampling behaviour, pipeline non-plot artifacts, parity claims, dashboard/UI
scope, or the bounded plotting support matrix.

## Source Boundary

Primary review driver:

- `.planning/CRITICAL-REVIEW-2026-07-19.md`, recommendation 8: consider moving
  `CairoMakie` to a weak dependency / extension to reduce load time for
  headless inference users.

Current implementation facts:

- `Project.toml` lists `CairoMakie` in `[deps]`.
- `src/includes.jl` includes `src/plotting/*.jl` in the main package load path.
- `src/plotting/theme.jl` and `src/plotting/diagnostics.jl` directly
  `using CairoMakie`.
- `src/pipeline/stages.jl` writes many stage-local PNG artifacts by calling
  plotting functions and private Makie helper plots.
- `docs/Project.toml` currently depends only on `Documenter` and `Epsilon`;
  therefore public plotting docstrings must remain available without loading
  `CairoMakie`.

## In Scope

1. Add base-package plotting API stubs and clear no-backend fallback errors.
2. Move the CairoMakie implementation behind a Julia package extension:
   `ext/EpsilonCairoMakieExt.jl`.
3. Move `CairoMakie` from hard `[deps]` to `[weakdeps]`, keep compat bounds,
   and include it in test extras/targets so plotting tests still exercise the
   extension.
4. Preserve direct plotting API names:
   - `epsilon_theme`
   - `trace_plot`
   - `posterior_density_plot`
   - `prior_posterior_plot`
   - `observed_fitted_plot`
   - `residual_diagnostics_plot`
   - `contribution_plot`
   - `contribution_area_plot`
   - `decomposition_plot`
   - `response_curve_plot`
   - `saturation_curve_plot`
   - `adstock_curve_plot`
   - `budget_optimization_plot`
   - `write_plot_bundle`
5. Keep pipeline non-plot stage outputs available when plotting is unavailable.
   Plot artifact emission must be either:
   - emitted exactly as before when `CairoMakie` is loaded and the extension is
     active, or
   - skipped with explicit warnings and without stale plot artifact-path claims
     when the plotting backend is unavailable.
6. Update docs/changelog/planning state to describe optional plotting honestly.
7. Add focused tests proving:
   - base Epsilon loads without loading `CairoMakie`;
   - plotting calls fail clearly before the backend is loaded;
   - plotting tests still pass when `CairoMakie` is loaded;
   - pipeline plot artifacts are emitted only when the backend is active, with
     no false artifact paths when it is not.

## Out of Scope

- Changing plot appearance or plotting result semantics.
- Adding new plotting functions.
- Moving to Plotly, AlgebraOfGraphics, or any dashboard/UI surface.
- Changing MCMC, model, optimisation, scenario, or post-model numerics.
- Refactoring the entire package into submodules.
- Running the full test suite during iteration.
- Refreshing benchmarks or claiming release readiness.

## Design Contract

### Base Package

The base package keeps exported plotting function names as generic functions
with docstrings and fallback methods. Fallbacks throw a deterministic
`ArgumentError` such as:

```text
trace_plot requires optional plotting support; load CairoMakie before calling
plotting APIs, for example `using Epsilon, CairoMakie`.
```

This keeps `using Epsilon` lightweight and keeps documentation discoverable
without a plotting backend.

### Extension

`Project.toml` defines:

```toml
[weakdeps]
CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"

[extensions]
EpsilonCairoMakieExt = "CairoMakie"
```

The extension module:

- `using Epsilon`
- `using CairoMakie`
- `using Statistics`
- defines methods on `Epsilon.<plot_function>`
- owns Makie constants, palettes, save helpers, and plotting-only private
  helpers.

The extension must not introduce public exports of its own.

### Pipeline Boundary

Pipeline stages remain core. They must not directly reference Makie types or
constructors. Plot-writing is routed through small optional hooks, for example:

- `_plotting_backend_loaded()::Bool`
- `_maybe_save_plot!(artifact_paths, key, relative_path, absolute_path, plot_call, warnings)`
- backend-specific methods added by the extension for the actual figure
  construction and save.

When the backend is not loaded:

- core CSV/JLS/YAML artifacts are still written;
- stage status can still be `:completed` if required non-plot artifacts were
  produced;
- each affected stage records a warning once per stage;
- plot artifact keys are omitted rather than pointing at nonexistent files.

When the backend is loaded:

- existing plot artifact filenames and keys are preserved.

Existing backend-loaded pipeline artifact-key parity tests must remain
backend-loaded tests. Do not globally weaken tests that prove PNG keys/files for
the currently supported plotted pipeline surface. Add separate headless tests
for backend-unloaded behaviour instead.

The implementation must enumerate and cover every current plot-producing stage:

- Stage `10_pre_diagnostics`: `prior_predictive_plot`.
- Stage `20_model_fit`: `trace_plot`.
- Stage `30_model_assessment`: posterior predictive / fitted / residual plots,
  including panel assessment helpers.
- Stage `35_holdout_validation`: holdout timeseries and residual ACF plots.
- Stage `40_decomposition`: contribution, area, waterfall, and panel
  contribution/decomposition plots.
- Stage `50_diagnostics`: residual ACF and posterior density/prior-posterior
  plots.
- Stage `60_response_curves`: time-series and panel response/saturation/adstock
  plots.
- Stage `70_optimisation`: budget optimisation and aliased optimisation plot
  artifacts.

## File Allowlist

Expected implementation files:

- `Project.toml`
- `src/exports.jl`
- `src/includes.jl`
- `src/plotting/api.jl`
- `src/plotting/theme.jl`
- `src/plotting/diagnostics.jl`
- `src/plotting/postmodel.jl`
- `src/plotting/optimization.jl`
- `src/plotting/bundle.jl`
- `src/pipeline/stages.jl`
- `ext/EpsilonCairoMakieExt.jl`
- `test/api_exports.jl`
- `test/plotting/runtests.jl`
- `test/plotting/diagnostics.jl`
- `test/plotting/postmodel.jl`
- `test/plotting/optimization.jl`
- `test/plotting/bundle.jl`
- `test/pipeline/run.jl`
- `docs/src/index.md`
- `docs/src/api.md`
- `docs/src/release.md`
- `CHANGELOG.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/68-plotting-extension-boundary/PLAN.md`

Do not stage unrelated local drift:

- `.gitignore`
- `.planning/CRITICAL-REVIEW-2026-07-19.md`

## Tasks

### 68-01: Freeze Optional-Plotting Contract

- [x] Add base plotting API stubs and fallback errors.
- [x] Add tests for base-load behaviour and fallback messages.
- [x] Acceptance: `using Epsilon` does not load `CairoMakie`; direct plotting
      names remain exported and fail with clear backend guidance before
      `CairoMakie` is loaded.

### 68-02: Move Makie Implementation Into Extension

- [x] Add `ext/EpsilonCairoMakieExt.jl`.
- [x] Move CairoMakie imports and concrete plot methods into the extension.
- [x] Convert `Project.toml` dependency metadata to weak dependency +
      extension + plotting test extra.
- [x] Acceptance: `using Epsilon, CairoMakie` loads the extension and the
      existing plotting tests pass with no visual-semantics change.

### 68-03: Decouple Pipeline Stage Plot Emission

- [x] Remove direct Makie calls from `src/pipeline/stages.jl`.
- [x] Route plot artifacts through optional backend hooks.
- [x] Preserve previous plot keys and filenames when backend is active.
- [x] Omit plot keys and add explicit stage warnings when backend is absent.
- [x] Acceptance: focused pipeline tests cover both backend-loaded and
      backend-unloaded behaviour without running the full suite.

### 68-04: Docs, Planning State, And Verification

- [x] Update docs to say plotting is optional and requires loading
      `CairoMakie`.
- [x] Update changelog and planning state.
- [x] Run scoped verification only:
      - `julia --project=. -e 'using Epsilon; @assert Base.get_extension(Epsilon, :EpsilonCairoMakieExt) === nothing; err = try trace_plot(nothing); nothing catch e; e end; @assert err isa ArgumentError; @assert occursin("optional plotting support", sprint(showerror, err)); println("base-stub-ok")'`;
      - `make test-file FILE=test/api_exports.jl`;
      - `make test-file FILE=test/plotting/diagnostics.jl`;
      - `make test-file FILE=test/plotting/runtests.jl`;
      - `make test-file FILE=test/pipeline/run.jl`;
      - `make format-check-touched`.
- [x] Commit and push.

## Risks

- **Pipeline artifact contract drift:** existing pipeline tests expect PNG
  artifact paths. Mitigation: preserve those paths when the backend is active
  and explicitly test omitted paths/warnings when it is absent.
- **Extension load ambiguity:** Julia extensions load only when the weak
  dependency is loaded. Mitigation: document `using Epsilon, CairoMakie` and
  test both sides.
- **Docstring loss:** if plotting methods live only in the extension, docs
  could lose public API text. Mitigation: keep docstrings on base stubs.
- **Internal helper access:** extension code cannot assume unexported core
  helper names are in scope. Mitigation: either qualify needed Epsilon internals
  explicitly or keep plotting-only helpers inside the extension.

## Independent Review

Completed before implementation by a read-only subagent. Findings accepted and
incorporated:

- Backend-loaded pipeline artifact parity assertions must remain intact; add
  separate headless tests rather than weakening existing plotted-path tests.
- Enumerate every plot-producing pipeline hook before implementation, including
  panel-only private helpers.
- Base stubs must not mention Makie-specific types such as `Figure`, `Axis`,
  `Theme`, `RGBAf`, `colorant`, `with_theme`, or `save`.
- The real `write_plot_bundle` method belongs in the extension; the base
  package keeps only the public docstring and fallback.
- Use `Base.get_extension(Epsilon, :EpsilonCairoMakieExt) === nothing` for the
  isolated no-backend check.
- Add `CairoMakie` to `[extras]` and `[targets].test` after moving it to
  `[weakdeps]`.
- Update `docs/src/api.md` as well as index/release docs.

## Verification Evidence

- `julia --project=. -e 'using Epsilon; @assert Base.get_extension(Epsilon, :EpsilonCairoMakieExt) === nothing; err = try trace_plot(nothing); nothing catch e; e end; @assert err isa ArgumentError; @assert occursin("optional plotting support", sprint(showerror, err)); println("base-stub-ok")'`
  passed and printed `base-stub-ok`.
- `make test-file FILE=test/api_exports.jl` passed: `5596` assertions.
- `make test-file FILE=test/plotting/diagnostics.jl` passed: `37`
  assertions.
- `make test-file FILE=test/plotting/runtests.jl` passed: `132`
  assertions.
- `make test-file FILE=test/pipeline/run.jl` passed: `884` assertions.
- `make format-check-touched` passed.
- `make test-file FILE=test/api_exports.jl` was rerun after docs wording
  updates and passed: `5596` assertions.
- `make docs` passed locally; Documenter emitted the expected local deployment
  auto-detection warning only.
