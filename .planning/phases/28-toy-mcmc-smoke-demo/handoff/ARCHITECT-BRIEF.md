# Architect Brief: Phase 28 Toy MCMC Smoke Demo

## Step Name

Phase 28: Toy MCMC Smoke Demo

## Objective

Create a tiny runnable toy `TimeSeriesMMM` MCMC example over synthetic data,
plus a focused test proving it fits and produces grouped/post-model output.
This is a maturity smoke demo for the supported v1 path, not a benchmark and
not an Abacus parity claim.

## Files In Scope

- `examples/**`
- `test/**`
- `README.md`
- `docs/src/index.md`
- `docs/src/release.md`
- `CHANGELOG.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/28-toy-mcmc-smoke-demo/**`

## Files Out Of Scope

- `src/**`, unless a concrete reviewed blocker prevents the toy from running.
- `Project.toml`
- `Manifest.toml`
- `benchmark/**`
- Existing generated demo results under `examples/demo/results/**`
- Any VI, dashboard/UI, AI-advisor, or release-prep implementation.

## Constraints

- Use the supported MCMC path only: `TimeSeriesMMM` plus `fit!`.
- Keep the toy synthetic and small. Do not use Abacus fixtures or copied demo
  data.
- Keep the example self-contained; do not depend on test helper functions.
- Default sampler settings should be small enough for a local smoke run.
- The focused test may use even smaller settings than the documented default.
- Use `chains = 1`, `cores = 1`, `progressbar = false`, explicit
  `random_seed`, and `compute_convergence_checks = false`.
- Avoid source changes. If source changes become necessary, stop and document
  the blocker for architect review before editing `src/`.
- Do not run the full suite.
- Do not add generated output files to git.

## Required Implementation Shape

1. Add a script such as `examples/toy_mmm/run_toy_mmm.jl`.
2. Structure the script so the test can call the same toy function without
   shelling out. The script must expose a callable function, such as
   `run_toy_mmm(; draws, tune, seed, output_dir)`, returning a named result
   contract with at least `model`, `state`, `grouped`, `contribution_table`,
   `metric_table`, and `written_paths`.
   CLI parsing must be a thin wrapper guarded by
   `abspath(PROGRAM_FILE) == @__FILE__`; do not call `exit(main())` on include.
3. Expose CLI flags for at least:
   - `--draws`;
   - `--tune`;
   - `--seed`;
   - `--output-dir`.
4. The toy should:
   - construct a deterministic synthetic time-series dataset with roughly
     8-12 observations, two positive media channels, at most one simple
     control, no holidays/events, and a small adstock lag;
   - fit `TimeSeriesMMM`;
   - call `inference_results(model; include_prior = false, include_posterior_predictive = false, include_prior_predictive = false)`;
   - compute `contribution_results` and `summary_table`;
   - compute one mandatory metric summary for one channel using a tiny
     deterministic grid, for example `[0.0, observed_total / 2, observed_total]`.
5. The toy should write compact CSV/text output only when `--output-dir` is
   supplied. It must create that directory if missing.
6. Add a focused test file, likely under `test/examples/`, that calls the toy
   function with tiny sampler settings and asserts the accepted output
   contract.

## Acceptance Criteria

- The toy command succeeds with tiny sampler settings.
- The focused test passes through `make test-file`.
- The toy reports a successful `:fit` state and `:turing` backend.
- The toy output includes non-empty contribution and response/metric summaries.
- The focused test uses `mktempdir()` for output and asserts expected files
  exist and are non-empty.
- The example and docs state that this is MCMC-only and not a benchmark or
  Abacus parity claim.
- `git diff --name-only -- src/ Project.toml Manifest.toml` prints nothing.
- Review feedback has no unresolved Must Fix items before commit.

## Verification Commands

The Builder may choose exact paths, but must run the targeted equivalents of:

```bash
julia --project=. examples/toy_mmm/run_toy_mmm.jl --draws 8 --tune 8 --output-dir "$(mktemp -d)"
make test-file FILE=test/examples/toy_mcmc_smoke.jl
julia --project=@runic -m Runic --check --diff examples/toy_mmm/run_toy_mmm.jl test/examples/toy_mcmc_smoke.jl
rg -n "benchmark|VI|Dash|Abacus parity" examples/toy_mmm README.md docs/src/index.md docs/src/release.md
git diff --check
git diff --name-only -- src/ Project.toml Manifest.toml
```
