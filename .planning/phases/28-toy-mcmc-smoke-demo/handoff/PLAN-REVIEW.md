# Plan Review: Phase 28 Toy MCMC Smoke Demo

## Must Fix

1. Resolve the response/metric summary contradiction before Builder starts.
   The plan says to compute one response or metric summary "if runtime remains
   acceptable", but the acceptance criteria require non-empty contribution and
   response/metric summaries. Make this mandatory with a tiny deterministic
   grid, e.g. `metric_results(grouped; channel = "tv", grid = [0.0,
   observed_total / 2, observed_total])`, and test the resulting
   `summary_table` is non-empty. If runtime is too high, shrink the toy data,
   draws, tune, or grid; do not leave the output optional.

2. Make the shared toy entry point a hard contract, not "where practical".
   The focused test is supposed to exercise the same toy code path, so the
   script should expose a callable function returning a small named result
   contract, such as `model`, `state`, `grouped`, `contribution_table`,
   `metric_table` or `response_table`, and `written_paths`. Keep CLI parsing as
   a thin wrapper around that function. Avoid an unconditional `exit(main())`
   pattern on include; guard CLI execution with the usual
   `abspath(PROGRAM_FILE) == @__FILE__` check.

## Should Fix

1. Pin down the sampler settings in the brief. The example and test should use
   `chains = 1`, `cores = 1`, `progressbar = false`, explicit `random_seed`,
   and `compute_convergence_checks = false`; otherwise a "toy smoke" can become
   slow or noisy for reasons unrelated to the slice. A small `target_accept`
   value can follow existing tests, but it should be explicit.

2. Avoid unnecessary grouped work. The brief currently calls
   `inference_results(model; include_prior = false, include_prior_predictive =
   false)`, which still leaves posterior predictive generation enabled by
   default. If the toy only needs post-model contribution and metric/response
   summaries, call with `include_posterior_predictive = false` too. If
   posterior predictive output is intentionally part of the demo, say so and
   test it.

3. Specify the toy data shape enough to prevent accidental modelling ambition.
   A self-contained `TimeSeriesMMM` with roughly 8-12 observations, two positive
   media channels, at most one simple control, no holidays/events, and a small
   adstock lag is enough. The target should be deterministic and positive. This
   keeps the example honest: it is a runnable smoke path, not synthetic
   econometric evidence.

4. Tighten the artifact-writing contract. Compact CSV/text output is fine, and
   `CSV`/`DataFrames` are already package dependencies, but the output directory
   should only be touched when supplied, should be created if missing, and the
   test should use `mktempdir()` and assert the expected files exist and are
   non-empty. Do not write under `examples/demo/results/` or commit generated
   outputs.

5. Add a light documentation check to the verification list. Because the slice
   updates README/docs/changelog/planning text but deliberately avoids the full
   suite, either run `make docs` if the docs edits add Documenter references, or
   keep the docs edits simple and record that docs build was intentionally not
   run. A cheap `rg` guard for forbidden framing such as "benchmark", "VI",
   "Dash", and "Abacus parity" in the new toy docs would also be useful.

6. Treat `git diff --name-only -- src/ Project.toml Manifest.toml` as a failing
   guard if it prints anything. The current command shape is right, but the
   review request/build log should record the empty output explicitly.

## Cleared

- The slice is properly bounded around a toy `TimeSeriesMMM` MCMC path and does
  not reopen VI, UI/dashboard, AI-advisor, benchmark, panel-validation, or
  release-prep scope.
- The plan correctly keeps `src/`, `Project.toml`, and `Manifest.toml` out of
  scope unless a concrete blocker is escalated before editing.
- The plan correctly avoids the existing Abacus-aligned `examples/demo/`
  pipeline runner and avoids claiming Abacus parity for synthetic toy data.
- Targeted verification is directionally right: run the toy command with tiny
  sampler settings, run the focused test through `make test-file`, Runic-check
  touched Julia files, run `git diff --check`, and verify no source/dependency
  files changed.
- Updating README/release docs/changelog/planning state is appropriate as long
  as the wording stays narrow: "fast supported MCMC smoke demo", not benchmark,
  not parity evidence, and not a broader v1 support expansion.
