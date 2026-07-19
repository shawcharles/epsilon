# Phase 73: Pretty Terminal Runner Output

## Status

Landed.

## Objective

Make `julia --project=. runme.jl` feel like a polished command-line runner:
print the Epsilon ASCII header, show readable stage progress, and finish with
a structured run summary.

This is terminal UX only. It must not change model semantics, pipeline stages,
artifact layout, sampler defaults, config parsing, parity status, benchmarks,
release gates, or the existing programmatic `run_pipeline` contract.

## User Contract

When running:

```bash
julia --project=. runme.jl
```

or:

```bash
julia --project=. runme.jl data/demo/timeseries/config.yml --quick
```

the terminal should show:

- the ASCII header from `assets/ascii.txt`;
- a concise command context block: config path, output root, quick mode, and
  bundle-owned data/holiday note;
- stage progress lines with simple bars and status markers;
- a final structured summary with run name, run directory, manifest path,
  status, and completed/skipped/failed stage counts;
- clear failure output with the same header/structure and a non-zero exit.

## Architecture Decisions

- Keep `runme.jl` as the user-facing entry point for pretty output.
- Preserve the Phase 72 delegation principle: `runme.jl` still calls
  `pipeline_main(...)`; it does not parse or execute pipeline stages itself.
- Add a small internal pretty-output switch for the pipeline CLI/stage runner,
  enabled by `runme.jl` only through a narrow unexported helper with
  `try`/`finally` restoration. Do not use an environment variable; that would
  become an accidental external control surface for `pipeline_main`.
- Emit stage progress from `_run_pipeline_stage!`, because that function is the
  single stage lifecycle choke point. Do not add progress prints inside each
  modelling function.
- Use only Base/stdlib terminal output (`printstyled`, ANSI-safe plain text,
  fixed-width ASCII bars where useful). Do not add a dependency such as Term.jl
  or ProgressMeter.jl for this slice.
- Print `assets/ascii.txt` verbatim when readable even though the supplied file
  contains Unicode box-drawing characters rather than strict ASCII. Keep
  progress bars, status markers, and fallback header text plain ASCII for log
  readability.
- Make output robust in non-TTY logs. Colour may be used sparingly, but the
  plain-text content must remain understandable when colour is absent.

## In Scope

- Track and use `assets/ascii.txt` as the runner header.
- Enhance `runme.jl`:
  - load and print the ASCII header when available;
  - print a short context block before execution;
  - enable pretty pipeline output only for this runner invocation;
  - preserve delegated status-code exit behaviour.
- Add private terminal-format helpers in the pipeline layer if needed,
  including a private failure-summary path used by `pipeline_main` only when
  the unexported pretty mode is enabled.
- Add focused tests for:
  - header loading/fallback behaviour;
  - pretty mode enabling in `runme.jl`;
  - pure progress-bar/status formatting;
  - pretty failure output from a missing config or unsupported demo without
    MCMC;
  - one bounded successful runner subprocess only if existing focused runner
    coverage can be reused without expanding runtime materially.
- Update README/data/docs/changelog/planning state.

## Out of Scope

- Changing stage execution order, stage names, artifact keys, manifests, or
  directory layout.
- Changing sampler progress bars from Turing.
- Adding a new dependency.
- Adding dashboard/UI, curses/TUI, interactive prompts, spinners, or live
  redraw behaviour.
- Adding `--holidays-path` or other new modelling/config semantics.
- Running panel MCMC in tests.
- Full-suite execution.
- Benchmark, release, parity-ledger, dependency, manifest, fixture, or internal
  reference/provenance changes unrelated to the ASCII asset.

## File Allowlist

Expected tracked files:

- `assets/ascii.txt`
- `runme.jl`
- `src/pipeline/cli.jl`
- `src/pipeline/stages.jl`
- `test/pipeline/demo_configs_smoke.jl` or another focused `test/pipeline/*`
  file
- `README.md`
- `data/README.md`
- `docs/src/index.md`
- `docs/src/supported_paths.md`
- `docs/src/release.md`
- `CHANGELOG.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/73-pretty-terminal-runner-output/PLAN.md`

Ignored handoff files may be updated under `handoff/`.

Do not stage unrelated local drift:

- `.gitignore` currently has an unstaged `.codex/` ignore addition.
- `results/` is local runner output and should remain untracked/ignored or be
  removed after inspection.

## Stage Progress Semantics

Progress bars count the current record position against all stage records in
the run manifest, including optional stages that are initially `skipped`.
Stages that are already `skipped` do not emit a running line from
`_run_pipeline_stage!`, but they are included in the final status counts.

Final summary counts report every status present in `result.stage_records`,
including `completed`, `skipped`, `failed`, `not_reached`, `pending`, and
`running`. Successful runs should normally contain only `completed` and
`skipped`.

## Tasks

### 73-01: Freeze The Pretty Output Contract

- [x] Add private formatting helpers for header, context, stage progress, and
      final summary.
- [x] Keep helpers deterministic enough to test without a live MCMC run.
- [x] Acceptance: terminal output has a stable textual contract while colour
      and exact elapsed times are not test-critical.

### 73-02: Wire Pretty Mode Through The Existing Runner Path

- [x] `runme.jl` prints the ASCII header and context before calling
      `pipeline_main`.
- [x] `runme.jl` enables private pretty pipeline output for the duration of the
      call and restores any previous setting afterwards.
- [x] Stage progress prints from the central stage lifecycle function.
- [x] Final structured summary prints from the existing pipeline CLI success
      path.
- [x] Structured failure summary prints from the existing pipeline CLI failure
      path when private pretty mode is enabled, without changing
      `run_pipeline` or normal `pipeline_main` behaviour.
- [x] Acceptance: `pipeline_main` remains the execution owner and process exit
      code is still delegated.

### 73-03: Add Focused Tests

- [x] Test pure formatting helpers without fitting.
- [x] Test `runme.jl --help` or a missing config path includes the header and
      failure structure without stack traces.
- [x] Reuse the existing `test/pipeline/demo_configs_smoke.jl` successful tiny
      runner subprocess only if the additional assertions do not add another
      MCMC run.
- [x] Acceptance: focused tests lock the terminal contract without full-suite
      or repeated pipeline runs.

### 73-04: Update Documentation And State

- [x] Document that `runme.jl` is the polished terminal runner.
- [x] Keep programmatic docs focused on `run_pipeline(PipelineRunConfig(...))`.
- [x] Mark Phase 73 complete after implementation review and scoped
      verification.

## Verification

Scoped only:

```bash
make test-file FILE=test/pipeline/demo_configs_smoke.jl
make format-check-touched
git diff --check
{ git diff --name-only; git diff --cached --name-only; git ls-files --others --exclude-standard; } | sort
```

Run `git diff --cached --check` after staging.

No full suite is required unless this phase changes exports, package load
order, public pipeline config semantics, or shared namespace behaviour.

Verified:

- `make test-file FILE=test/pipeline/demo_configs_smoke.jl` passed
  (`73 / 73`, `2m38.5s`).
- `make format-check-touched` passed.
- `git diff --check` passed.
- `julia --project=. --startup-file=no runme.jl --help` printed the header
  and usage contract.

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Pretty runner becomes a second pipeline control plane | High | Keep `runme.jl` delegating to `pipeline_main`; stage prints live in the existing lifecycle hook. |
| Terminal output breaks log readability | Medium | Use simple text and avoid TUI redraw/spinners. |
| Tests become slow | Medium | Test formatting directly; reuse the existing single tiny runner subprocess. |
| New dependency bloat | Medium | Use Base/stdlib output only. |
| Results directory drift | Low | Do not stage `results/`; prefer temp dirs in tests. |

## Independent Review

Completed before implementation by a read-only subagent.

Accepted corrections:

- Removed the environment-variable pretty-mode option; implementation must use
  a private unexported helper with `try`/`finally` restoration.
- Added an explicit private pretty failure-summary route for the pipeline CLI
  catch path.
- Defined progress/count semantics over all manifest stage records.
- Clarified that the header asset is printed verbatim while bars/status/fallback
  text remain plain ASCII.

Post-implementation review findings resolved before commit:

- Pretty stage hooks are best-effort and swallow cosmetic output failures so
  terminal rendering cannot convert a successful stage into a failed stage or
  mask the original failure during rethrow.
- Header loading falls back to plain `EPSILON` if the asset cannot be read,
  not only when the file is missing.
- Focused tests now assert normal non-pretty `pipeline_main(["run"])` output
  remains unchanged and does not acquire the runner header or pretty failure
  summary.
