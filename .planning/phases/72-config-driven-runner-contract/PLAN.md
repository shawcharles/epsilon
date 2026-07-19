# Phase 72: Config-Driven Runner Contract

## Status

Implemented.

## Objective

Add a repo-root Epsilon runner file, analogous in workflow convenience to
Abacus `runme.py`, so a user can execute the existing config-driven pipeline
with minimal Julia code.

The runner should make the `{config.yml, dataset.csv, holidays.csv}` triplet
easy to run, but it must delegate to the existing Epsilon pipeline entry point
instead of creating a second orchestration path.

## User Contract

Primary command:

```bash
julia --project=. runme.jl data/demo/timeseries/config.yml
```

Convenience demo command:

```bash
julia --project=. runme.jl demo timeseries --quick
```

Default command:

```bash
julia --project=. runme.jl
```

The default command should run the canonical `data/demo/timeseries/config.yml`
through the same quick local settings as `--quick`:

- `draws = 20`
- `tune = 20`
- `chains = 1`
- `cores = 1`
- `prior_samples = 5`
- `curve_points = 12`

All outputs should go under `results/` unless `--output-dir` is supplied. The
config remains the owner of bundle-local `dataset.csv` and `holidays.csv`
references; `--dataset-path` may continue to use the existing pipeline override
surface. A separate `--holidays-path` override is out of scope because the
current public pipeline contract does not expose it.

## Architecture Decisions

- Add a root `runme.jl` script rather than changing package exports.
- Use `using Epsilon` and call `pipeline_main(...)`; do not duplicate
  `PipelineRunConfig` parsing or `run_pipeline` exception handling.
- Exit with the integer status returned by `pipeline_main(...)`; do not allow a
  failed pipeline status to become a successful Julia process exit.
- Keep the runner as a thin convenience control plane:
  - translate `runme.jl <config>` to `epsilon run <config>`;
  - translate `runme.jl demo timeseries` to the canonical bundled config;
  - add optional `--quick` defaults for local smoke-sized runs.
- Inspect runner arguments only enough to remove `--quick` and detect already
  supplied quick-default flags, including `--flag=value`; all actual pipeline
  flag validation remains owned by `pipeline_main`.
- Keep `examples/demo/run_demo.jl` historical/reference-only. It should not
  become the current runner.
- Keep panel demos honest:
  - the runner may accept any config path and let `pipeline_main` enforce the
    existing pipeline support boundary;
  - no panel validation, panel calibration, free channel-by-panel optimisation,
    dashboard/UI, VI, or benchmark/release expansion is introduced.

## In Scope

- Add `runme.jl` at repo root.
- Add focused tests for runner help, default/demo/config forwarding, quick
  defaults, unsupported arguments, and failing config propagation.
- Add a `make run-demo-config` convenience target if it can stay a thin wrapper
  around `runme.jl`.
- Update user-facing docs that currently show the long
  `julia -e 'using Epsilon; run_pipeline(...)'` incantation.
- Update `CHANGELOG.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, and this
  plan.

## Out of Scope

- Changing `src/pipeline/cli.jl`, `PipelineRunConfig`, or `run_pipeline`
  semantics unless a test exposes a direct wrapper defect that cannot be
  solved in the runner.
- Adding a holidays override flag.
- Adding a new package binary/build step.
- Running panel MCMC as part of runner tests.
- Adding or changing model features, sampler defaults, stage semantics, plot
  behaviour, scenario planner behaviour, calibration behaviour, benchmarks,
  release gates, fixtures, parity-ledger status, dependencies, or manifests.
- Changing historical/reference `examples/demo/*` surfaces except for
  cross-linking if needed.

## File Allowlist

Expected tracked files:

- `runme.jl`
- `Makefile`
- `test/pipeline/demo_configs_smoke.jl` or a new focused runner test file under
  `test/pipeline/`
- `README.md`
- `data/README.md`
- `docs/src/index.md`
- `docs/src/supported_paths.md`
- `docs/src/release.md`
- `CHANGELOG.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/72-config-driven-runner-contract/PLAN.md`

Ignored handoff files may be updated under `handoff/`.

## Tasks

### 72-01: Freeze The Runner Contract

- [x] Write `runme.jl` as a thin command translator over `pipeline_main`.
- [x] Support:
  - `runme.jl` defaulting to the canonical time-series demo with quick
    settings;
  - `runme.jl <config_path> [pipeline flags...]`;
  - `runme.jl demo timeseries [pipeline flags...]`;
  - `--quick` as a local override bundle for draws/tune/chains/cores,
    prior-samples, and curve-points only when those flags are not already
    supplied;
  - `-h` / `--help`.
- [x] Reject unsupported demo names and unknown runner-level commands with a
      clear non-zero exit.
- [x] Acceptance: the script does no model work itself and delegates all real
      execution to `pipeline_main`, and the Julia process exits with the
      delegated status code.

### 72-02: Add Focused Runner Tests

- [x] Add tests that call the runner in a subprocess with tiny settings and a
      temporary output directory.
- [x] Verify the config-path form creates a completed manifest and prints
      delegated success output; verify default/demo/config forms through the
      runner translation helper rather than running three separate MCMC
      subprocesses.
- [x] Verify help succeeds and malformed usage fails without stack traces.
- [x] Verify `bash` syntax is irrelevant; this is a Julia script and should be
      tested through `julia --project=. runme.jl ...`.
- [x] Acceptance: the focused runner test proves the user-facing control plane
      without running the full suite.

### 72-03: Add The Local Convenience Target

- [x] Add `make run-demo-config`, defaulting to `DEMO=timeseries`.
- [x] Forward environment variables or Make variables for small runtime
      overrides without duplicating pipeline logic.
- [x] Verify the Makefile target is wired to `runme.jl` in the focused runner
      test.
- [x] Acceptance: users can run the current canonical demo with one Make
      command, while `runme.jl` remains the direct language-level runner.

### 72-04: Update Documentation And Planning State

- [x] Update docs to prefer `runme.jl` for the config-driven demo path.
- [x] Keep `run_pipeline(PipelineRunConfig(...))` documented for programmatic
      use.
- [x] Keep all claims scoped to local workflow usability, not benchmark,
      release, or parity evidence.
- [x] Mark Phase 72 complete in planning docs after implementation checks so
      the implementation reviewer can inspect the proposed final resume state.

## Verification

Scoped only:

```bash
make test-file FILE=test/pipeline/demo_configs_smoke.jl
make format-check-touched
git diff --check
{ git diff --name-only; git diff --cached --name-only; git ls-files --others --exclude-standard; } | sort
```

Run `git diff --cached --check` after staging.

The focused test file must include Make target wiring coverage for
`run-demo-config`. A direct `make run-demo-config` smoke may be used only if the
focused subprocess tests do not already exercise the same command path.

No full suite is required unless the implementation changes shared exports,
package load order, or `src/pipeline/cli.jl`.

Verified before implementation review:

- `make test-file FILE=test/pipeline/demo_configs_smoke.jl`: passed,
  `43 / 43`, `3m00.8s`.
- After implementation review fixes, `make test-file
  FILE=test/pipeline/demo_configs_smoke.jl` passed again, `44 / 44`,
  `3m29.2s`.
- `make format-check-touched`: passed.
- `git diff --check`: passed.
- Changed-file inventory showed the Phase 72 files plus unrelated local drift
  in `.gitignore` and `assets/ascii.txt`; those unrelated files are not part
  of this phase and must not be staged with this commit.

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Runner drifts from package CLI | Medium | Delegate to `pipeline_main`; do not parse pipeline flags independently beyond `--quick` removal. |
| User assumes `--holidays-path` exists | Low | Document that holidays remain config-owned in this phase. |
| Default command creates large local runs | Medium | Default to quick local settings and `results/`. |
| Panel demo command overclaims support | Medium | Only special-case `demo timeseries`; arbitrary config paths use existing pipeline enforcement. |
| Tests become slow | Medium | Use tiny MCMC settings and one focused pipeline test file. |

## Independent Review

Completed before implementation by a read-only subagent.

Accepted corrections:

- Pin `--quick` to `draws=20`, `tune=20`, `chains=1`, `cores=1`,
  `prior_samples=5`, and `curve_points=12`.
- Make process exit-code propagation from `pipeline_main` explicit.
- Keep `--quick` parsing shallow and preserve `--flag=value` detection.
- Add explicit Make target wiring verification.

Implementation review found no Must Fix items. Two Should Fix items were
resolved before commit:

- Removed an undocumented `run <config>` compatibility form from `runme.jl`.
- Added a focused missing-config subprocess assertion proving delegated
  `pipeline_main` failures exit non-zero through `runme.jl`.
