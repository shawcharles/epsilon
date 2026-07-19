# Phase 69: Config-Driven Demo Smoke Harness

## Status

Implemented.

## Objective

Add a fast local smoke harness for the Epsilon-native `data/demo/*` config
bundles so maintainers can verify the supported config-driven workflow:

```text
config.yml + dataset.csv + holidays.csv -> run_pipeline / model build -> temp results
```

This phase converts Phase 67's adapted demo configs from "files load" evidence
into a practical local workflow check without treating the result as benchmark,
release, or broad reference-parity evidence.

## Source Boundary

Current facts:

- `data/demo/timeseries/config.yml`,
  `data/demo/geo_panel/config.yml`, and
  `data/demo/geo_brand_panel/config.yml` are Epsilon-native configs with
  bundle-local `dataset.csv` and `holidays.csv` paths.
- `data/README.md` documents manual `run_pipeline(PipelineRunConfig(...))`
  commands but there is no single command that checks all three config-driven
  demo bundles.
- `make smoke` currently runs the synthetic toy MCMC example and the fixed
  schema CSV quickstart through `scripts/smoke_supported_paths.sh`; it does not
  exercise `data/demo/*`.
- `examples/demo/run_demo.jl` is a separate historical/reference-demo surface
  and remains time-series-only. Phase 69 should not widen that runner.
- Phase 68 made plotting optional. A headless smoke command must verify
  non-plot artifacts and warnings honestly without requiring `CairoMakie`.

## In Scope

1. Add a local smoke command for `data/demo/*`, likely:
   - `scripts/smoke_demo_configs.sh`
   - `make smoke-demo-configs`
2. Run the time-series demo config through the pipeline with tiny runtime
   overrides:
   - `draws = 8`
   - `tune = 8`
   - `chains = 1`
   - `cores = 1`
   - `prior_samples = 3`
   - `curve_points = 8`
   - deterministic seed
3. Write all smoke outputs into a temporary directory and clean it up on exit.
4. Verify required time-series non-plot pipeline artifacts, including:
   - `run_manifest.json`
   - Stage `00` metadata config copies
   - Stage `10` preflight/prior-predictive artifacts
   - Stage `20` model/inference/summary artifacts
   - Stage `30` assessment CSV artifacts
   - Stage `35` validation CSV/JLS artifacts, because the shipped
     `data/demo/timeseries/config.yml` enables validation by default
   - Stage `40` decomposition CSV/JLS artifacts
   - Stage `50` diagnostic JSON/JLS artifacts
   - Stage `60` response/metric CSV/JLS artifacts
5. Verify headless optional-plotting behaviour without depending on
   `CairoMakie`:
   - the pipeline completes without stage-local PNG requirements;
   - manifest warnings mention omitted plot artifacts when the plotting backend
     is not loaded;
   - no manifest artifact path points to a nonexistent PNG.
6. Check `geo_panel` and `geo_brand_panel` through lightweight config/data/model
   spec construction, not full MCMC sampling, unless implementation discovery
   shows a tiny panel pipeline run is reliably cheap.
7. Add focused tests for the script/Make target contract.
8. Update `data/README.md`, `docs/src/supported_paths.md`, and release-facing
   local-workflow docs only where needed to describe the new smoke command and
   its limits.
9. Update planning state and changelog.

## Out of Scope

- Full-suite execution during iteration.
- Benchmark snapshotting or benchmark claim changes.
- Release-readiness claims.
- Dashboard/UI or hosted workflow surfaces.
- Variational inference.
- Changing model, sampler, transform, post-model, scenario, or optimisation
  semantics.
- Widening `examples/demo/run_demo.jl`.
- Panel holdout validation.
- Panel calibration.
- Free channel-by-panel optimisation.
- Automatically fitting every panel demo through MCMC.
- Renaming internal reference fixture directories or the parity ledger.

## Design Contract

### Command Shape

The command should be deliberately local and boring:

```bash
make smoke-demo-configs
```

Internally it should call a shell script with environment overrides:

```bash
DRAWS=8 TUNE=8 PRIOR_SAMPLES=3 CURVE_POINTS=8 make smoke-demo-configs
```

The defaults must remain small enough for routine use. They are smoke settings,
not inference-quality settings.

### Time-Series Demo

The time-series path is the only demo that should run the full pipeline in this
phase. It must:

- pass `PipelineRunConfig` runtime overrides rather than editing YAML;
- write to `mktemp -d`;
- use `data/demo/timeseries/config.yml`;
- preserve the config's default `validation.enabled: true` setting and accept
  the resulting second tiny validation fit;
- assert `PipelineRunResult.status == :completed`;
- assert `run_manifest.json` and required non-plot artifacts exist and are
  non-empty;
- assert any plotted artifact keys are either backed by existing files or
  omitted with warnings, depending on backend availability.

### Panel Demos

The panel paths should use the existing Phase 67 lightweight construction
contract:

- load the pipeline configuration;
- build the correct pipeline context in a temp output directory;
- load `PanelMMMData`;
- construct `PanelMMM`;
- call `build_model(model)`;
- assert coordinate metadata and dimensions:
  - `geo_panel`: `dims == ("geo",)`;
  - `geo_brand_panel`: `dims == ("geo", "brand")`;
  - both have six media channels.

This verifies that the user-facing panel demo configs are structurally usable
without paying repeated MCMC cost.

### Failure Semantics

The script must fail closed:

- missing demo config/data/holiday files fail with a non-zero exit;
- failed model construction fails with a non-zero exit;
- missing required artifacts fail with a non-zero exit;
- nonexistent PNG artifact paths in the manifest fail with a non-zero exit.

### Documentation Semantics

Docs must say clearly:

- this is a local smoke harness;
- it is not a benchmark;
- it is not release evidence;
- the time-series demo runs a tiny MCMC pipeline;
- panel demos are checked through config/data/model-spec construction only;
- headless installs are supported and do not require `CairoMakie`.

## File Allowlist

Expected implementation files:

- `Makefile`
- `scripts/smoke_demo_configs.sh`
- `test/pipeline/demo_configs_smoke.jl`
- `test/pipeline/runtests.jl`
- `data/README.md`
- `docs/src/supported_paths.md`
- `docs/src/release.md`
- `CHANGELOG.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/69-config-driven-demo-smoke-harness/PLAN.md`

Optional if needed:

- `README.md`

Do not stage unrelated local drift:

- `.gitignore`
- `.planning/CRITICAL-REVIEW-2026-07-19.md`

## Tasks

### 69-01: Add Local Demo Config Smoke Script

- [x] Add `scripts/smoke_demo_configs.sh`.
- [x] Implement time-series tiny pipeline smoke against
      `data/demo/timeseries/config.yml`.
- [x] Implement panel config/data/model-spec smoke checks for
      `data/demo/geo_panel/config.yml` and
      `data/demo/geo_brand_panel/config.yml`.
- [x] Acceptance: the script writes only to a temporary directory, cleans up by
      default, and exits non-zero on missing required artifacts or invalid
      configs.

### 69-02: Add Make Target And Focused Tests

- [x] Add `make smoke-demo-configs`.
- [x] Add focused `test/pipeline/demo_configs_smoke.jl` coverage for the
      script's existence, executable syntax, Makefile target declaration, and
      core model-spec helper contract.
- [x] Include the focused test from `test/pipeline/runtests.jl`.
- [x] Acceptance: `bash -n scripts/smoke_demo_configs.sh` and
      `make test-file FILE=test/pipeline/demo_configs_smoke.jl` pass.

### 69-03: Document The Workflow Boundary

- [x] Update `data/README.md` with the new command.
- [x] Update `docs/src/supported_paths.md` with the local workflow and limits.
- [x] Update `docs/src/release.md` only to mention the local smoke command
      boundary, not release readiness.
- [x] Update `CHANGELOG.md`.
- [x] Acceptance: docs make the time-series full-pipeline versus panel
      load/build split explicit.

### 69-04: Planning State, Verification, And Commit

- [x] Mark this plan implemented.
- [x] Add Phase 69 to `.planning/ROADMAP.md`.
- [x] Update `.planning/STATE.md`.
- [x] Run scoped verification only:
      - `bash -n scripts/smoke_demo_configs.sh`;
      - `make smoke-demo-configs`;
      - `make test-file FILE=test/pipeline/demo_configs_smoke.jl`;
      - `make format-check-touched`;
      - `git diff --check`.
- [x] Commit reviewed changes.

Scoped verification completed:

```bash
bash -n scripts/smoke_demo_configs.sh
# passed

make test-file FILE=test/pipeline/demo_configs_smoke.jl
# passed: 18 / 18

make smoke-demo-configs
# passed; time-series pipeline including validation, plus geo_panel and
# geo_brand_panel config/data/model-spec checks

make format-check-touched
# passed

git diff --check
# passed
```

The first `make smoke-demo-configs` run reached the end of the two tiny
time-series fits but failed on the smoke script's warning-text assertion. The
implementation expected "plotting backend"; the actual Phase 68 warning says
"optional plotting support". The assertion was corrected and the smoke command
then passed.

Independent implementation review cleared the behaviour and documentation after
one Must Fix: `scripts/smoke_demo_configs.sh` matched the existing `/scripts/*`
ignore rule. The script was force-added deliberately rather than widening the
pre-existing `.gitignore` drift.

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Time-series demo MCMC is still too slow for a smoke command | Medium | Keep defaults tiny and allow env overrides; accept the second validation fit because it proves the literal shipped config, but reduce sampler settings before committing if runtime is poor. |
| Optional plotting makes artifact assertions brittle | Medium | Assert non-plot artifacts as required; validate PNG paths only if present; otherwise require explicit warnings. |
| Panel smoke silently becomes a broad panel-fit gate | Medium | Keep panel checks to config/data/model-spec construction in this phase. |
| Docs overstate the command as release evidence | High | Repeat "local smoke, not benchmark or release evidence" in docs and changelog. |
| Shell script duplicates too much Julia logic | Medium | Keep shell orchestration thin and perform artifact checks with small embedded Julia where structured manifest parsing matters. |

## Independent Review

Completed before implementation by a read-only subagent.

Accepted corrections:

- The time-series smoke must acknowledge that the shipped demo config enables
  validation. Phase 69 will preserve that default and verify Stage `10` and
  Stage `35` outputs rather than silently creating a smaller temp config.
- The headless plotting check must run in a fresh `using Epsilon` process that
  does not import `CairoMakie`.
- Focused tests should either check the Make target declaration or stop
  claiming Make-target test coverage. Phase 69 will check the declaration and
  use the actual `make smoke-demo-configs` command as behavioural verification.
- Public docs must expose only the smoke command and behavioural boundary, not
  private pipeline helper names used internally by tests.
