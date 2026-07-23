# Current Scope And Limitations

Epsilon is a public beta library for local, reproducible Bayesian marketing mix
modelling in Julia. The current release is useful for small and medium local
MMM workflows, especially when the modelling process needs to be explicit,
scriptable, and inspectable.

The package is not trying to be a complete commercial MMM platform. Some areas
are intentionally narrow while the core API settles.

## What Is Supported Today

The strongest supported path is a time-series MMM run from a local
configuration bundle:

```text
config.yml
dataset.csv
holidays.csv
```

That workflow supports:

- Turing/NUTS MCMC fitting for time-series models;
- adstock and saturation transforms;
- holidays, events, controls, Fourier seasonality, and trend terms where
  configured;
- structured result folders with manifests, diagnostics, fit summaries,
  decomposition outputs, response curves, plots when available, and skipped
  stage markers;
- blocked holdout validation for time-series models;
- bounded lift-test and cost-per-target calibration for the maintained
  time-series MCMC path;
- fixed-budget channel optimisation over fitted response surfaces.

Panel models are supported on a bounded surface. They are useful for declared
panel dimensions and deterministic coordinate metadata, but they should not yet
be treated as feature-equivalent to the time-series path.

## What Is Intentionally Out Of Scope

The following are not part of the maintained public surface:

- variational inference;
- hosted dashboards, managed services, AI advisors, or background UI workflows;
- panel holdout validation;
- panel calibration;
- free channel-by-panel optimisation;
- fully automated prior-sensitivity refitting;
- arbitrary future spend-path simulation;
- portable binary interchange for Julia `.jls` artifacts.

Unsupported paths should fail clearly or write explicit skipped-stage markers
when they are optional pipeline stages. Epsilon should not silently substitute a
different statistical model.

## Runtime Expectations

Epsilon uses Turing/NUTS MCMC for the maintained fitting path. This gives a
transparent Bayesian workflow, but it is not the fastest possible execution
strategy for every model shape. Larger runs can take material local compute
time, especially when validation performs an additional refit.

Use `runme.jl ... --quick` or small sampler overrides when checking that a
configuration bundle is wired correctly. Increase draws, tuning, and chains only
when the goal is statistical inference rather than a workflow smoke check.

Runtime reduction remains an engineering priority, but speed work should not
come at the cost of unclear model semantics.

## Local Verification

Epsilon uses local verification scripts rather than hosted CI as the canonical
release gate. For routine changes, prefer focused checks:

```bash
make format-check
make smoke
make test-file FILE=test/inference/recovery.jl
```

Before a release-facing tag or publication, run:

```bash
make check-release
```

See [Supported Local Workflows](supported_paths.md) for the runnable demo
workflow and [Support Boundaries](release.md) for the detailed support matrix.
