# Epsilon Benchmarks

This directory owns the frozen Phase 11 benchmark contract.

The benchmark suite is intentionally bounded to the committed workload matrix:

- micro benchmarks
  - `B-T1-CONV`
  - `B-T2-GEOM`
  - `B-T3-WEIBULL`
  - `B-T4-HILL`
  - `B-T5-SCALING`
- workflow benchmarks
  - `B-W1-FIT`
  - `B-W2-GROUPED`
  - `B-W3-POSTMODEL`
  - `B-W4-PIPELINE`

The canonical benchmark entry point is:

```bash
julia --project=benchmark -e 'using Pkg; Pkg.instantiate()'
julia --project=benchmark benchmark/run_benchmarks.jl --reference-machine
```

That command writes the published snapshot files:

- `benchmark/results/reference_machine.json`
- `benchmark/results/reference_machine.md`

The benchmark runner loads the package under development from the repo root via
`LOAD_PATH`, so the benchmark environment stays dedicated to benchmark-only
tooling while still exercising the local checkout.

## Frozen Run Protocol

Micro benchmarks:

- one warmup invocation discarded
- `BenchmarkTools.jl` with `evals = 1`, `samples = 50`
- committed metrics:
  - median time
  - memory estimate
  - allocation count

Workflow benchmarks:

- one warmup run discarded
- three timed repetitions in separate Julia processes
- fixed direct-modeling sampler overrides for `B-W1-FIT`, `B-W2-GROUPED`, and
  `B-W3-POSTMODEL`:
  - `random_seed = 7`
  - `chains = 2`
  - `draws = 120`
  - `tune = 60`
  - `target_accept = 0.85`
- `B-W4-PIPELINE` uses the same frozen `draws` / `tune` / `chains` /
  `random_seed` overrides but inherits `target_accept = 0.8` from the
  canonical pipeline fixture YAML because the bounded `PipelineRunConfig`
  surface does not expose a `target_accept` override
- committed metrics:
  - median wall-clock seconds
  - median peak RSS when available
  - median bulk ESS/sec when the workload includes MCMC output

The workflow runner uses the exact canonical validation cases already frozen in
Phase 11:

- `VAL-TS-00-MCMC`
- `VAL-PIPE-TS-00-MCMC`

`B-W2-GROUPED` and `B-W3-POSTMODEL` consume prepared artifacts derived from the
same fixed `VAL-TS-00-MCMC` fit rather than refitting inside those workloads.

## Published Snapshot Policy

Commit only the frozen reference-run outputs:

- `benchmark/results/reference_machine.json`
- `benchmark/results/reference_machine.md`

Ad hoc local benchmark outputs should be written elsewhere and kept out of the
release gate.

## Notes

- The frozen Phase 11 benchmark contract publishes measured Epsilon results for
  the bounded v1 surface. It does not make a blanket claim that Epsilon is
  universally faster than Abacus.
- Any direct Epsilon-vs-Abacus timing comparison should be treated as a
  separate maintainer analysis, not as an implicit property of the committed
  benchmark snapshot.
- The currently committed reference snapshot records `git_dirty = true`. Rerun
  the frozen suite from a clean tagged worktree for the final release artifact.
