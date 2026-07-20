# Time-Series Demo

This is the canonical runnable Epsilon demo bundle.

Files:

- `config.yml`: time-series MMM configuration.
- `dataset.csv`: demo data with `date`, `revenue`, and six media channels.
- `holidays.csv`: bundle-local holiday calendar used by the config.

Run from the repository root:

```bash
julia --project=. runme.jl data/demo/timeseries/config.yml --quick
```

With no arguments, `runme.jl` uses this bundle and quick local settings:

```bash
julia --project=. runme.jl
```

The default config enables time-series holdout validation with a lighter
validation sampler, and disables budget optimisation. To run optimisation, add
an explicit Epsilon-native `optimization.total_budget` block.
