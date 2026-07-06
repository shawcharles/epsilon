# Review Request: Phase 28 Toy MCMC Smoke Demo

## Requested Review

Review the Builder implementation against:

- `AGENTS.md`
- `.planning/phases/28-toy-mcmc-smoke-demo/PLAN.md`
- `.planning/phases/28-toy-mcmc-smoke-demo/handoff/ARCHITECT-BRIEF.md`
- `.planning/phases/28-toy-mcmc-smoke-demo/handoff/PLAN-REVIEW.md`

Focus on scope control, toy result contract, CLI include safety, mandatory
metric summary behavior, artifact-writing behavior, test coverage, and wording
that must not imply release evidence, benchmark work, Abacus parity, VI, Dash,
AI-advisor, or broader support expansion.

The reviewer Must Fix has been patched: the focused test now asserts grouped
posterior draw count/parameter presence, absence of disabled prior and
predictive groups, and observed-data identity. `.planning/STATE.md` progress
now remains `75%` while review/commit are pending.

## Files To Review

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

## Verification Completed

- `julia --project=. examples/toy_mmm/run_toy_mmm.jl --draws 8 --tune 8 --output-dir "$(mktemp -d)"` passed.
- `make test-file FILE=test/examples/toy_mcmc_smoke.jl` passed with `27/27`
  after the reviewer Must Fix patch.
- `julia --project=@runic -m Runic --check --diff examples/toy_mmm/run_toy_mmm.jl test/examples/toy_mcmc_smoke.jl` passed.
- `rg -n "benchmark|VI|Dash|Abacus parity" examples/toy_mmm README.md docs/src/index.md docs/src/release.md` found only explicit toy disclaimers plus existing/global release-scope wording.
- `git diff --check` passed with no output.
- `git diff --name-only -- src/ Project.toml Manifest.toml` passed with no output.

## Known Gaps

- Reviewer pass has not yet been run.
- Full suite and docs build were not run for this bounded Builder slice.
- No commit has been made.
