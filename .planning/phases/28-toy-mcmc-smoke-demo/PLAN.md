# Phase 28: Toy MCMC Smoke Demo

## Status

Landed pending commit. Three Man Team plan review, Builder implementation, and
Reviewer clearance are complete. This phase follows the Phase 27 scope
correction by proving the supported v1 path with a tiny runnable toy model
rather than widening release scope or running benchmarks.

## Objective

Add a small, deterministic, programmatic toy `TimeSeriesMMM` example that a
developer can run locally to verify that the supported MCMC path works end to
end on synthetic data.

The toy should demonstrate:

- constructing `ModelConfig`, `SamplerConfig`, and `MMMData`;
- fitting `TimeSeriesMMM` through `fit!`;
- extracting grouped `InferenceResults`;
- computing at least one post-model summary from the fitted MCMC result;
- computing one deterministic metric summary on a tiny spend grid;
- writing a compact, inspectable summary artifact when an output directory is
  provided.

## Rationale

After Phase 27, Epsilon's v1 support boundary is intentionally MCMC-only.
The next useful maturity check is not a benchmark or release gate. It is a
small toy run that confirms a new user can execute the supported path without
the heavier Abacus-aligned pipeline demo.

## In Scope

1. Add a self-contained toy example under `examples/`.
2. Add a focused test that runs the toy example with very small sampler
   settings and verifies the key outputs.
3. Update README/docs/changelog/planning state to point to the toy as the
   fastest supported-path smoke demo.
4. Preserve existing model semantics and public APIs.

## Out Of Scope

- Any `src/` changes unless a concrete bug blocks the toy run.
- Any VI, dashboard/UI, AI-advisor, benchmark, or release-prep work.
- Any Abacus parity claim for the toy data.
- Running the full test suite.
- Changing the existing Abacus-aligned `examples/demo/` pipeline runner.
- Adding generated run outputs to version control.

## Implementation Tasks

### 28-01: Plan And Review

- [x] Write this phase plan.
- [x] Write the Three Man Team architect brief.
- [x] Get a plan-review pass before implementation.

### 28-02: Toy Example

- [x] Add a self-contained toy script under `examples/`.
- [x] Keep the default sampler small enough for routine local smoke use.
- [x] Support CLI overrides for draws, tune, random seed, and optional
      output directory.
- [x] Expose a callable toy entry point returning a small named result contract
      so the focused test exercises the same code path as the CLI.
- [x] Print a concise run summary without relying on generated artifacts.
- [x] If output is requested, create the directory and write compact CSV/text
      summaries only.

### 28-03: Focused Test And Docs

- [x] Add a focused test file that executes the toy path with tiny settings.
- [x] Assert fit status, backend, draw count, grouped result shape, and
      non-empty contribution and metric summary output.
- [x] Update README/docs/changelog/planning state with bounded wording:
      supported MCMC toy smoke demo, not benchmark, not Abacus parity.

### 28-04: Review, Verification, Commit

- [x] Write build log and review request.
- [x] Run the Three Man Team reviewer pass.
- [x] Resolve all Must Fix findings.
- [x] Run targeted verification only:
  - toy script command with tiny sampler settings;
  - focused test file through `make test-file FILE=...`;
  - Runic check on touched Julia files;
  - `git diff --check`;
  - `git diff --name-only -- src/ Project.toml Manifest.toml`.
- [x] Commit the reviewed toy smoke demo.

## Acceptance Criteria

- A local user can run a documented toy command without using the heavier
  pipeline demo.
- The toy uses `fit!` on `TimeSeriesMMM` with Turing/MCMC only.
- The toy exposes a callable `run_toy_mmm`-style entry point; CLI parsing is a
  thin wrapper and does not call `exit(main())` on include.
- The toy uses a small deterministic dataset: roughly 8-12 observations, two
  positive media channels, at most one simple control, no holidays/events, and
  a small adstock lag.
- Sampler defaults and tests use `chains = 1`, `cores = 1`,
  `progressbar = false`, explicit `random_seed`, and
  `compute_convergence_checks = false`.
- Grouped extraction disables prior, prior-predictive, and posterior-predictive
  generation unless the Builder documents a need to include them.
- The metric summary is mandatory and uses a tiny deterministic grid, such as
  `[0.0, observed_total / 2, observed_total]`, for one channel.
- The toy does not mention or exercise VI, dashboard/UI, AI advisor, Abacus
  parity, or benchmarks.
- The focused test exercises the same toy code path, not a separate duplicate
  model.
- If `--output-dir` is supplied, expected output files exist and are non-empty;
  no generated outputs are committed.
- No source or dependency files change unless a blocker is documented and
  reviewed.
- No full-suite run is performed for this bounded example/test slice.

## Verification

Targeted commands only. Exact commands should be finalised by the Builder once
the example path is chosen.

Expected shape:

```bash
julia --project=. examples/<toy-path>/run_toy_mmm.jl --draws 8 --tune 8 --output-dir <tmpdir>
make test-file FILE=test/<toy-test-path>.jl
julia --project=@runic -m Runic --check --diff <touched-julia-files>
rg -n "benchmark|VI|Dash|Abacus parity" examples/<toy-path> README.md docs/src/index.md docs/src/release.md
git diff --check
git diff --name-only -- src/ Project.toml Manifest.toml
```
