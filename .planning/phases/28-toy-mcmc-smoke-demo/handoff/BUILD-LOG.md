# Build Log: Phase 28 Toy MCMC Smoke Demo

## Builder Scope

Implemented the Phase 28 toy `TimeSeriesMMM` MCMC smoke demo only. No `src/**`,
`Project.toml`, or `Manifest.toml` edits were made.

## Changed Files

- `examples/toy_mmm/run_toy_mmm.jl`
- `examples/toy_mmm/README.md`
- `test/examples/toy_mcmc_smoke.jl`
- `README.md`
- `docs/src/index.md`
- `docs/src/release.md`
- `CHANGELOG.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/28-toy-mcmc-smoke-demo/PLAN.md`
- `.planning/phases/28-toy-mcmc-smoke-demo/handoff/BUILD-LOG.md`
- `.planning/phases/28-toy-mcmc-smoke-demo/handoff/REVIEW-REQUEST.md`

## Implementation Notes

- Added `run_toy_mmm(; draws, tune, seed, output_dir, verbose)` as the shared
  callable toy entry point.
- The toy constructs a deterministic 10-observation synthetic `TimeSeriesMMM`
  with two positive media channels, no controls, no events, no holidays, and
  geometric adstock `l_max = 2`.
- The sampler uses `chains = 1`, `cores = 1`, `progressbar = false`, explicit
  `random_seed`, and `compute_convergence_checks = false`.
- Grouped extraction calls `inference_results(model; include_prior = false,
  include_posterior_predictive = false, include_prior_predictive = false)`.
- The post-model path computes `contribution_results`, `summary_table`, and a
  mandatory `metric_results` summary for `tv` on `[0.0, observed_total / 2,
  observed_total]`.
- Optional output writes only compact `contribution_summary.csv`,
  `metric_summary.csv`, and `run_summary.txt` into the user-supplied output
  directory.
- CLI parsing is a thin wrapper guarded by `abspath(PROGRAM_FILE) == @__FILE__`
  and does not call `exit(main())` on include.

## Verification

- `julia --project=. examples/toy_mmm/run_toy_mmm.jl --draws 8 --tune 8 --output-dir "$(mktemp -d)"`
  - Passed.
  - Printed `status=fit`, `backend=turing`, `draws=8`, `tune=8`.
  - Wrote non-empty summaries under the temporary output directory.
- `make test-file FILE=test/examples/toy_mcmc_smoke.jl`
  - Passed: `27` tests, `27` passed after the reviewer Must Fix patch.
- `julia --project=@runic -m Runic --check --diff examples/toy_mmm/run_toy_mmm.jl test/examples/toy_mcmc_smoke.jl`
  - Passed with no diff.
- `rg -n "benchmark|VI|Dash|Abacus parity" examples/toy_mmm README.md docs/src/index.md docs/src/release.md`
  - Matches in `examples/toy_mmm/README.md`, `README.md`,
    `docs/src/index.md`, and `docs/src/release.md`.
  - New toy matches are explicit disclaimers: not release evidence, not a
    benchmark, not an Abacus parity claim, and not a broader support expansion.
  - Other matches are existing/global release-scope notes around benchmarks,
    unsupported VI, Dash/dashboard boundaries, and Abacus parity wording.
- `git diff --check`
  - Passed with no output.
- `git diff --name-only -- src/ Project.toml Manifest.toml`
  - Passed with no output.

## Known Gaps

- Three Man Team reviewer re-check is pending after the Must Fix patch.
- No full suite was run, per Phase 28 boundary.
- `make docs` was not run because docs edits are simple prose links and the
  phase verification list deliberately uses targeted checks.
- No commit was made by the Builder.

## Reviewer Must Fix Resolution

- The first review found that `test/examples/toy_mcmc_smoke.jl` checked the
  requested sampler draw count but did not prove the grouped posterior carried
  the expected draws or that disabled prior/predictive groups were absent.
- The focused test now asserts:
  - `result.grouped.prior === nothing`;
  - `result.grouped.posterior_predictive === nothing`;
  - `result.grouped.prior_predictive === nothing`;
  - `result.grouped.observed_data === result.model.data`;
  - `size(result.grouped.posterior, 1) == 8`;
  - expected posterior parameters including `:intercept` and
    `Symbol("beta_media[1]")`.
- `.planning/STATE.md` progress was corrected from `100%` to `75%` while
  review/commit remain pending.
