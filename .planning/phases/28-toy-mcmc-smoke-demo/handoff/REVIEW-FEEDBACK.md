# Review Feedback: Phase 28 Toy MCMC Smoke Demo

## Must Fix

- None. The previous Must Fix is resolved.

## Should Fix

- None. The previous progress-state inconsistency is resolved.

## Escalate

- None. No source/dependency edits or scope expansion need architect escalation.

## Cleared

- Scope is controlled. `git status --short --branch` shows docs/planning edits
  plus new `examples/toy_mmm/` and `test/examples/` files only; no `src/**`,
  `Project.toml`, or `Manifest.toml` changes are present.
- The previous test-contract Must Fix is resolved at
  `test/examples/toy_mcmc_smoke.jl:23-30`: the focused test now asserts the
  grouped posterior exists, disabled prior/predictive groups are absent,
  `observed_data` is the model data object, posterior draw count is `8`, and
  expected posterior parameters include `:intercept` and
  `Symbol("beta_media[1]")`.
- The `.planning/STATE.md` progress correction is resolved at
  `.planning/STATE.md:227-236` and `.planning/STATE.md:274-275`: progress is now
  `75%` while Phase 28 remains `3/4`, review pending, and commit pending.
- `BUILD-LOG.md` and `REVIEW-REQUEST.md` document the Must Fix patch and the
  updated focused test result: `make test-file FILE=test/examples/toy_mcmc_smoke.jl`
  passed with `27/27`.
- The callable result contract exists at `examples/toy_mmm/run_toy_mmm.jl:108-164`
  and returns `model`, `state`, `grouped`, `contribution_table`,
  `metric_table`, and `written_paths`.
- CLI include safety is correct: execution is guarded at
  `examples/toy_mmm/run_toy_mmm.jl:234-235`, with no `exit(main())` pattern.
  I verified `julia --project=. -e 'include("examples/toy_mmm/run_toy_mmm.jl");
  @assert isdefined(Main, :run_toy_mmm); println("include-safe")'` prints only
  `include-safe`.
- CLI argument parsing covers `--draws`, `--tune`, `--seed`, `--output-dir`,
  and help at `examples/toy_mmm/run_toy_mmm.jl:167-231`. I verified
  `julia --project=. examples/toy_mmm/run_toy_mmm.jl --help` reaches the help
  path without running the sampler.
- Mandatory contribution and metric summaries are implemented at
  `examples/toy_mmm/run_toy_mmm.jl:127-136`, with the deterministic `tv` grid
  `[0.0, observed_total / 2, observed_total]`.
- Output writing only happens when `output_dir` is supplied, creates the
  directory, and writes compact CSV/text files at
  `examples/toy_mmm/run_toy_mmm.jl:70-84` and `examples/toy_mmm/run_toy_mmm.jl:146-148`.
  I found no generated output artifacts in the untracked file list.
- README, docs, changelog, and planning wording stays bounded: the toy is framed
  as a local supported MCMC smoke demo, not release evidence, not a benchmark,
  not an Abacus parity claim, and not a broader support expansion.
- Verification stayed targeted. I checked `git diff --check` and
  `git diff --name-only -- src/ Project.toml Manifest.toml`; both produced no
  output in the first review. In this re-review, I ran
  `make test-file FILE=test/examples/toy_mcmc_smoke.jl`; it passed with `27/27`
  in `40.7s`. I did not run the full suite, consistent with the phase boundary.
