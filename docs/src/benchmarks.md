# Benchmarks

Phase 11 freezes one bounded benchmark suite for the supported v1 surface. The
goal is honest measurement, not a blanket “faster than Abacus” claim.

The canonical benchmark entry point is:

```bash
julia --project=benchmark -e 'using Pkg; Pkg.instantiate()'
julia --project=benchmark benchmark/run_benchmarks.jl --reference-machine
```

The committed reference snapshot lives at:

- `benchmark/results/reference_machine.json`
- `benchmark/results/reference_machine.md`

## Methodology

The frozen workload matrix is:

- micro:
  - `B-T1-CONV`
  - `B-T2-GEOM`
  - `B-T3-WEIBULL`
  - `B-T4-HILL`
  - `B-T5-SCALING`
- workflow:
  - `B-W1-FIT`
  - `B-W2-GROUPED`
  - `B-W3-POSTMODEL`
  - `B-W4-PIPELINE`

Micro protocol:

- one discarded warmup invocation
- `BenchmarkTools.jl` with `evals = 1`, `samples = 50`
- committed metrics:
  - median time
  - memory estimate
  - allocation count

Workflow protocol:

- one discarded warmup run
- three timed repetitions in separate Julia processes
- fixed direct-modeling sampler settings for `B-W1-FIT`, `B-W2-GROUPED`, and
  `B-W3-POSTMODEL`:
  - `random_seed = 7`
  - `chains = 2`
  - `draws = 120`
  - `tune = 60`
  - `target_accept = 0.85`
- `B-W4-PIPELINE` uses the same frozen `draws` / `tune` / `chains` /
  `random_seed` overrides but inherits `target_accept = 0.8` from the frozen
  pipeline fixture YAML because the bounded `PipelineRunConfig` surface does
  not expose a `target_accept` override
- committed metrics:
  - median wall-clock seconds
  - median peak RSS when `/usr/bin/time` is available
  - median bulk ESS/sec when the workload includes MCMC output

No direct Abacus timings are part of this frozen `11-02` suite. The published
snapshot therefore documents measured Epsilon performance only and avoids a
false universal speed claim.

## Reference Machine

The current committed snapshot was produced on:

- hostname: `unit`
- OS / arch: `Linux / x86_64`
- CPU: `alderlake`
- CPU threads: `22`
- Julia threads: `1`
- total memory: `33,054,949,376` bytes
- Julia: `1.12.6`
- Epsilon: `0.1.0-dev`
- git commit: `44e6c47e42f3034cbc06590d54f9a2de9e0fb1a3`
- dirty worktree: `true`

## Results

### Micro Benchmarks

| ID | Workload | Median Time (ns) | Memory (bytes) | Allocations |
|---|---|---:|---:|---:|
| `B-T1-CONV` | `batched_convolution` representative 3D overlap/add case | `822,915` | `867,016` | `52,218` |
| `B-T2-GEOM` | geometric adstock representative matrix case | `608,252` | `603,976` | `36,598` |
| `B-T3-WEIBULL` | Weibull PDF adstock representative matrix case | `606,758` | `609,240` | `36,654` |
| `B-T4-HILL` | Hill saturation representative vector case | `79,760` | `66,080` | `19` |
| `B-T5-SCALING` | standardization / scaling representative matrix case | `8,177` | `62,784` | `29` |

### Workflow Benchmarks

| ID | Workload | Median Wall Time (s) | Median Peak RSS (KB) | Median Bulk ESS/sec |
|---|---|---:|---:|---:|
| `B-W1-FIT` | time-series MCMC fit wall-clock | `62.72` | `2,503,300` | `0.263` |
| `B-W2-GROUPED` | `inference_results` materialization | `50.85` | `2,446,160` | `0.325` |
| `B-W3-POSTMODEL` | response / metric / optimization representative path | `43.04` | `2,444,816` | `n/a` |
| `B-W4-PIPELINE` | full pipeline wall-clock | `80.67` | `2,439,732` | `2.186` |

## Interpretation

- The bounded post-model and optimization path (`B-W3-POSTMODEL`) is materially
  cheaper than a full refit because it consumes prepared grouped artifacts from
  the fitted model path.
- `B-W4-PIPELINE` is the heaviest published row because it exercises the
  bounded Stage `00`-`70` pipeline surface, including validation and optional
  optimization.
- The current committed snapshot was captured from a dirty worktree. That
  provenance is recorded explicitly, and maintainers should rerun the frozen
  suite from a clean tagged worktree for the final release artifact.
- These numbers are reference-machine results, not portability guarantees.
  Maintainers should rerun the committed suite locally when evaluating
  regressions on materially different hardware or Julia versions.
