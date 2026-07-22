# Verifying Epsilon Locally

Epsilon uses local verification commands rather than hosted CI as the primary
quality gate. Choose the smallest check that matches the change you are making.
The full suite is intentionally not the default iteration command.

## Environment Setup

Instantiate the package environment:

```bash
make instantiate
```

Check that the package loads:

```bash
julia --project=. -e 'using Epsilon; println("Epsilon loaded")'
```

The `Makefile` sets `JULIA_PKG_SERVER_REGISTRY_PREFERENCE=eager` by default for
package operations.

## Fast Workflow Smoke Check

Run the maintained demo-config smoke harness:

```bash
make smoke
```

This is the preferred quick confidence check for the config-driven workflow. It
runs the bundled demo configs with small sampler settings and writes outputs to
temporary directories, not to the repository's canonical `results/` examples.

The explicit alias is:

```bash
make smoke-demo-configs
```

## Reviewer Demo

Run a small reproducible reviewer demo that writes a local result folder and
checks the resulting manifest:

```bash
make reviewer-demo
```

This runs the bundled time-series config through `runme.jl` with quick sampler
settings, then verifies that `run_manifest.json` reports a completed run with no
failed stages. It is intended for reviewers who want to exercise the real
pipeline and inspect concrete outputs without waiting for the heavier panel
demos. On the maintainer's local machine, this reviewer demo completed in about
two minutes; runtime will vary by hardware, Julia version, and package
precompilation state.

By default, outputs are written under `results/reviewer_quick_demo_<timestamp>/`.
Those local reviewer outputs are ignored by Git. Override the output root or run
name with environment variables:

```bash
OUTPUT_DIR=/tmp/epsilon-review RUN_NAME=my_review make reviewer-demo
```

## Scoped Development Checks

Use targeted checks while editing.

For formatting:

```bash
make format-check
```

For one test file:

```bash
make test-file FILE=test/api_exports.jl
```

For the core model suite:

```bash
make test-model
```

For validation or optimisation changes:

```bash
make test-validation
make test-optimization
```

For documentation:

```bash
make docs
```

`test/api_exports.jl` is especially important after documentation or public API
edits. It checks the exported-symbol inventory and cross-document support
claims.

## Full Release Gate

Use the full gate before public release tags, registry/JOSS preparation, or
changes that plausibly affect multiple subsystems:

```bash
make check-release
```

This runs formatting, the full package test suite, and documentation. On the
maintainer's local machine, the full test suite has taken roughly 25 minutes;
runtime will vary with hardware, Julia version, package precompilation state,
and sampler-heavy tests.

The full test target alone is:

```bash
make test
```

## Canonical Demo Output Reproduction

The repository includes committed canonical output examples for the maintained
time-series and geo-panel demo bundles. To reproduce fresh local runs without
overwriting those examples, use a different `--run-name`:

```bash
julia --project=. runme.jl data/demo/timeseries/config.yml \
  --output-dir results --run-name local_timeseries_demo
```

```bash
julia --project=. runme.jl data/demo/geo_panel/config.yml \
  --output-dir results --run-name local_geo_panel_demo
```

Full demo runs use MCMC and may take materially longer than the smoke harness.
The geo-panel demo is useful for inspecting the panel workflow, but it is not
the first install test. The geo-brand-panel demo is available as a data/config
bundle, but it is not recommended as a routine verification run under the
current sampler settings.
