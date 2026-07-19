# Local Performance Notes

Epsilon includes local benchmark scripts for maintainers who want to inspect
runtime and allocation behaviour. These scripts are not part of the normal user
workflow and should not be treated as release claims.

To run the local benchmark harness:

```bash
julia --project=benchmark -e 'using Pkg; Pkg.instantiate()'
julia --project=benchmark benchmark/run_benchmarks.jl --reference-machine
```

Benchmark outputs are written under `benchmark/results/`.

Use benchmark results as local engineering evidence only. They depend on the
machine, Julia version, thread count, dependency versions, sampler settings,
and current worktree state.
