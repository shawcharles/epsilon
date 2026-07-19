# Phase 74: Plotted Runner Output

## Status

Landed.

## Objective

Make the human-facing repo runner generate stage-local plot artifacts by
default when running:

```bash
julia --project=. runme.jl
```

or:

```bash
julia --project=. runme.jl data/demo/timeseries/config.yml --quick
```

This phase exists because the current run manifest correctly reports that
plotting was unavailable: `runme.jl` loaded only `Epsilon`, and the root project
could not load `CairoMakie`.

## Key Design Decision

Promote `CairoMakie` from a test/weak dependency to a root runtime dependency
so the repo-local `julia --project=. runme.jl` command can load it without
asking users to mutate their environment first.

This is a real install-time dependency cost, not a cosmetic metadata shuffle.
For Phase 74 we accept that hard dependency because the user-facing
config/data/holidays runner should generate plotted outputs out of the box in
the root project. We are choosing that over a separate runner environment for
now.

This does not mean `using Epsilon` should eagerly import CairoMakie. The
plotting code remains behind the existing package extension, and `runme.jl` is
the only code path that opts into loading the plotting backend by default.

## User Contract

The default runner should:

- try to load `CairoMakie` before invoking `pipeline_main`;
- print `Plots        : enabled (PNG)` when the plotting backend is active;
- produce the existing stage-local `.png` plot artifacts in the run directory;
- fall back with a clear `Plots        : unavailable (...)` line if plotting
  cannot be loaded;
- support `--no-plots` as an explicit opt-out that suppresses pipeline plot
  artifact generation even if `CairoMakie` is already loaded in the process;
- preserve all existing pipeline/model semantics and artifact keys.

The default image format remains PNG. JPEG export is out of scope because model
diagnostic plots are line/text-heavy and PNG is the correct lossless default.

## In Scope

- `Project.toml` dependency metadata update for `CairoMakie`.
- `runme.jl` plotting opt-in:
  - parse and remove `--no-plots`;
  - reject `--no-plots=<value>`;
  - attempt to load `CairoMakie` unless plots are disabled;
  - disable pipeline plot generation for the duration of the run when
    `--no-plots` is supplied;
  - include plotting status in the context block;
  - keep execution delegated to `pipeline_main`.
- Focused tests in the existing pipeline demo smoke file:
  - translation removes runner-only `--no-plots`;
  - normal pipeline CLI remains unchanged;
  - `--no-plots` produces the existing no-plot warning path;
  - default runner path produces at least one expected PNG artifact.
- Documentation/changelog/planning updates.

## Out of Scope

- JPEG output.
- New plotting APIs.
- Plot design changes.
- Dashboard/UI work.
- Changing `run_pipeline` or normal `pipeline_main` behaviour.
- Changing sampler defaults, model semantics, config schema, stage order,
  stage names, or non-plot artifact keys.
- Full-suite verification.

## File Allowlist

Expected files:

- `Project.toml`
- `runme.jl`
- `src/plotting/api.jl`
- `src/pipeline/stages.jl`
- `test/pipeline/demo_configs_smoke.jl`
- `README.md`
- `data/README.md`
- `docs/src/index.md`
- `docs/src/supported_paths.md`
- `docs/src/release.md`
- `CHANGELOG.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/74-plotted-runner-output/PLAN.md`

Do not stage unrelated local drift:

- `.gitignore`
- `assets/ascii.txt`
- `results/`

## Tasks

### 74-01: Dependency Boundary

- [x] Move CairoMakie into the root runtime dependency surface so
      `julia --project=. runme.jl` can load it directly.
- [x] Keep the package extension boundary intact so `using Epsilon` does not
      eagerly load CairoMakie.
- [x] Do not stage a root `Manifest.toml`; it is ignored local environment
      state. Local verification may require `Pkg.resolve()` or
      `Pkg.instantiate()`, but only `Project.toml` belongs in the commit.
- [x] Acceptance: `using Epsilon` alone leaves the plotting extension unloaded,
      then `@eval Main using CairoMakie` succeeds in the root project and
      activates plotting support.

### 74-02: Runner Plot Loading

- [x] Add runner-only `--no-plots` parsing.
- [x] Default to attempting `CairoMakie` load.
- [x] Implement a narrow internal plot-disable gate around the pipeline run so
      `--no-plots` suppresses artifact generation even when CairoMakie is
      already loaded.
- [x] Print plotting status in the runner context.
- [x] Preserve delegated `pipeline_main` status behaviour.
- [x] Acceptance: the runner can produce plotted pipeline artifacts without
      becoming a second pipeline control plane.

Active backend plot rendering/saving failures remain fatal in Phase 74. If
CairoMakie is loaded and a plot cannot be rendered or saved, the pipeline
should fail rather than silently shipping incomplete plotted evidence. The
warning-only path remains reserved for backend absence or explicit `--no-plots`.

### 74-03: Focused Evidence

- [x] Extend existing runner smoke coverage without adding a second default
      expensive run.
- [x] Check at least one expected `.png` artifact exists in the default plotted
      runner path.
- [x] Check `--no-plots` preserves the no-plot warning/omitted-artifact path.
- [x] Acceptance: scoped tests prove both plotted and no-plot runner modes.

### 74-04: Documentation And State

- [x] Update user-facing docs to say `runme.jl` writes PNG plots by default.
- [x] Keep PNG as the documented default and explain JPEG is not the native
      pipeline format.
- [x] Mark Phase 74 landed after implementation review and verification.

## Verification

Scoped only:

```bash
julia --project=. --startup-file=no -e 'using Epsilon; @assert Base.get_extension(Epsilon, :EpsilonCairoMakieExt) === nothing; @eval Main using CairoMakie; @assert Epsilon._plotting_backend_loaded(); println("PLOTTING_EXTENSION_OK")'
make test-file FILE=test/pipeline/demo_configs_smoke.jl
make format-check-touched
git diff --check
```

Run `git diff --cached --check` after staging.

No full suite is required unless this phase changes exports, package load order
outside the runner, public pipeline config semantics, or shared namespace
behaviour.

Verified:

- Lazy-extension check passed:
  `julia --project=. --startup-file=no -e 'using Epsilon; @assert Base.get_extension(Epsilon, :EpsilonCairoMakieExt) === nothing; @eval Main using CairoMakie; @assert Epsilon._plotting_backend_loaded(); println("PLOTTING_EXTENSION_OK")'`.
- `make test-file FILE=test/pipeline/demo_configs_smoke.jl` passed
  (`99 / 99`, `5m10.6s`).

Implementation notes:

- The first plotted smoke run exposed a Julia world-age failure when the
  dynamically loaded extension's `_save_pipeline_plot_impl!` method was called
  from already-compiled pipeline code. `_save_pipeline_plot!` now calls the
  extension implementation via `Base.invokelatest`.
- The second plotted smoke run exposed the same world-age class in diagnostics
  helper calls for prior/posterior plots. Those direct extension helper calls
  now also use `Base.invokelatest`.
- Post-implementation review found that diagnostics still used the raw
  `_plotting_backend_loaded()` predicate for prior/posterior plot selection.
  That branch now uses `_pipeline_plots_enabled()` so `--no-plots` suppresses
  all plotting-side diagnostics work when CairoMakie is already loaded. The
  focused smoke file includes an in-process loaded-backend `runme_main`
  regression for this contract.

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Dependency bloat | Medium | CairoMakie is loaded only by the runner; `using Epsilon` remains lazy via extension. |
| Runner hides plotting load failure | Medium | Print explicit plotting status in the context block. |
| Tests become slow | Medium | Reuse the existing tiny runner subprocess and add one no-plot smoke only if bounded. |
| Public API drift | High | Do not export new names or change `pipeline_main`/`run_pipeline`. |

## Independent Review

Completed before implementation.

Accepted corrections:

- The dependency decision now explicitly accepts the install-time CairoMakie
  cost for repo-local plotted runner ergonomics.
- `--no-plots` now means suppress plot artifact generation for the duration of
  the run, not merely "do not attempt to load CairoMakie".
- Verification now asserts `using Epsilon` alone keeps the plotting extension
  unloaded before loading CairoMakie.
- Active-backend rendering/saving failures remain fatal by design.
- The ignored root `Manifest.toml` is called out as local environment state
  that must not be staged.
