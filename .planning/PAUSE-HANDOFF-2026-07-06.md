# Pause Handoff: 2026-07-06

## Current State

Development is paused after Phase 28.

Latest committed phase:

- Phase 28: Toy MCMC Smoke Demo
- Commit: `22b9627 Phase 28: add toy MCMC smoke demo`

Current branch state before this handoff commit:

- `main` is ahead of `origin/main` by 23 commits.
- Worktree was clean before this pause-handoff file was added.
- No `src/`, `Project.toml`, or `Manifest.toml` changes were made in Phase 28.

## What Just Landed

Phase 27 reconciled the v1 scope boundary:

- MCMC/Turing is the only v1-supported inference path.
- Variational inference, dashboard/UI parity, and AI advisor behaviour are out
  of scope for v1.
- Existing `VariationalConfig` and `approximate_fit!` exports remain scaffolded
  pre-v1 review surfaces.

Phase 28 added a fast supported-path smoke demo:

- `examples/toy_mmm/run_toy_mmm.jl`
- `examples/toy_mmm/README.md`
- `test/examples/toy_mcmc_smoke.jl`

The toy fits a tiny synthetic `TimeSeriesMMM` through `fit!`, extracts grouped
MCMC `InferenceResults`, computes contribution and metric summaries, and
optionally writes compact CSV/text outputs.

## Verification At Pause

Targeted Phase 28 verification passed:

```bash
julia --project=. examples/toy_mmm/run_toy_mmm.jl --draws 8 --tune 8 --output-dir "$(mktemp -d)"
make test-file FILE=test/examples/toy_mcmc_smoke.jl
julia --project=@runic -m Runic --check --diff examples/toy_mmm/run_toy_mmm.jl test/examples/toy_mcmc_smoke.jl
git diff --check
git diff --name-only -- src/ Project.toml Manifest.toml
```

The focused test passed with `27/27`.

No full suite was run, by design.

## Resume Guidance

On return:

1. Start by reading `AGENTS.md`, `.planning/STATE.md`, and this handoff.
2. Keep VI, dashboard/UI, AI advisor, benchmark refresh, and release-prep work
   out of scope unless explicitly requested.
3. For the next implementation phase, create a plan first and run a review pass
   before implementation.
4. Use targeted tests by default; reserve the full suite for phase-closing
   checkpoints that touch shared namespace/export risk or true release gates.

Reasonable next slice:

- A small documentation/example polish pass around the toy MCMC path, or
- a bounded MCMC-supported-path robustness check, if a concrete failure mode is
  identified.

Do not treat the toy smoke demo as release evidence, benchmark evidence, Abacus
parity evidence, or a broader support expansion.

