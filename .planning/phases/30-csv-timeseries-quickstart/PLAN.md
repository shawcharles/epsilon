# Phase 30: CSV Time-Series MCMC Quickstart

## Status

Landed. Plan and implementation reviews cleared after resolving the Boolean
CSV-coercion Must Fix; scoped verification passed.

## Objective

Provide one small, runnable, CSV-backed `TimeSeriesMMM` quickstart that turns a
visible bundled dataset into typed `MMMData`, fits through the supported
Turing/NUTS MCMC path, and writes the same compact local summaries as the toy
smoke example. This teaches the direct data boundary without claiming that
arbitrary CSV layouts, the pipeline, parity, or release validation are covered.

## Contract And Design Decisions

- Ship a deterministic bundled CSV with exactly four columns: `date`, `sales`,
  `tv`, and `search`.
- Use `CSV.read(..., DataFrame; normalizenames = false, strict = true)` with
  `date` materialised as `String`. Parse it with `DateFormat("yyyy-mm-dd")`,
  then materialise `sales`, `tv`, and `search` as finite numeric vectors before
  `MMMData` construction. Parser/date/missing/non-finite failures must be
  clear `ArgumentError`s naming the affected column; do not infer dates,
  targets, or channel columns from arbitrary input.
- Sort every parsed row into ascending date order and reject duplicate parsed
  dates. `MMMData` itself does not impose this time-series input contract.
- Reject unexpected columns and negative media values at the example boundary
  so the fixed schema cannot silently drop data or obscure Epsilon's
  nonnegative-media requirement.
- Keep CSV loading as an internal helper inside the example script. Do not add
  a package-level ingestion API, change the pipeline, or widen exports.
- Keep the model contract deliberately equivalent to the Phase 28 toy path:
  two media channels, `TimeSeriesMMM`, one Turing/NUTS chain, explicit seed,
  disabled progress/convergence checks, and grouped inference plus compact
  contribution/metric summaries.
- `--data PATH` is the only data-path option. It defaults to the bundled file
  resolved relative to `@__DIR__`, and a missing path must fail clearly.
- Use a callable `run_csv_mmm(...)`, a thin `main(args = ARGS)`, and
  `if abspath(PROGRAM_FILE) == @__FILE__; main(); end` so including the script
  cannot fit or write output. Its help path must not start MCMC.
- Pin the tiny sampler contract: one chain/core, `progressbar = false`,
  `compute_convergence_checks = false`, a fixed default seed, and low default
  draw/tune counts. The CLI rejects non-positive draw/tune values before model
  construction.

## In Scope

- A new `examples/csv_mmm/` directory containing a checked-in tiny CSV fixture,
  runnable Julia script, and concise README describing its exact schema and
  non-claims.
- Focused `test/examples/` coverage for CSV-to-`MMMData` conversion, missing
  required columns, help/include safety, and one tiny MCMC happy path.
- Root README, changelog, roadmap, and state updates that describe this as an
  example-only CSV quickstart.
- Ignored local Three Man Team handoff files.

## Out Of Scope

- `src/**`, package exports, `Project.toml`, `Manifest.toml`, and dependencies.
- General-purpose CSV ingestion, YAML/pipeline changes, column inference,
  arbitrary schemas, panel data, data cleaning, missing-value imputation, or
  reporting/UI work.
- Model, sampler, posterior, post-model, calibration, optimisation, or
  prediction semantic changes.
- Variational inference, dashboard/UI, AI advisor, Abacus parity, benchmarks,
  release-prep claims, fixtures under `test/fixtures/abacus/`, and full-suite
  validation.

## Implementation Tasks

### Task 30-01: Plan And Review

- [x] Create/update the local architect brief and this plan.
- [x] Run a fresh-context plan review before implementation.
- [x] Resolve all Must Fix items before Builder work begins.

### Task 30-02: Explicit CSV Example Boundary

- [x] Add the deterministic bundled `date,sales,tv,search` CSV fixture.
- [x] Add a small `load_csv_mmm_data(path)` helper in the example script.
- [x] Parse the date field using the documented ISO format and construct
      `MMMData` with the declared target/channel mapping.
- [x] Reject a missing required column with a clear `ArgumentError` naming the
      missing column.
- [x] Reject malformed/missing dates and missing/non-finite numeric cells with
      clear column-specific `ArgumentError`s.
- [x] Sort parsed rows chronologically and reject duplicate parsed dates.
- [x] Reject unexpected columns and negative `tv`/`search` values with clear
      `ArgumentError`s.
- [x] Add direct-script parsing for `--data`, `--draws`, `--tune`, `--seed`,
      `--output-dir`, and `-h` / `--help`, preserving clear integer failures.

### Task 30-03: Runnable MCMC And Focused Tests

- [x] Fit the loaded `MMMData` through the current supported Turing/NUTS path.
- [x] Return a small named result contract including the loaded data, fit state,
      grouped results, summary tables, and optional written paths.
- [x] Add non-MCMC tests for loading, chronological sorting, missing required
      columns, malformed/missing dates, missing/non-finite numeric values,
      nonexistent paths, CLI/help, and include safety.
- [x] Add one tiny one-chain MCMC smoke assertion against the bundled CSV.
- [x] Assert the result retains the loaded data and declared channel order,
      and creates non-empty expected files when `output_dir` is provided.

### Task 30-04: Documentation And Closure

- [x] Document the exact CSV schema, invocation, expected success shape, and
      explicit non-claims in the example README.
- [x] Link the quickstart from the root README without replacing the faster
      synthetic smoke command.
- [x] Update changelog, roadmap, and state for implementation review.
- [x] Update the plan and local handoff logs with review and verification
      evidence before commit.

## Acceptance Criteria

- A bundled CSV runs through the documented command and produces `status=fit`
  and `backend=turing` on the tiny MCMC path.
- `load_csv_mmm_data` builds an `MMMData` with the intended dates, target,
  channel order, and channel names.
- A CSV missing any declared required column fails with a clear
  `ArgumentError` that names that column.
- Malformed/missing dates and missing/non-finite numeric values fail with clear
  column-specific `ArgumentError`s; rows are sorted by parsed date and
  duplicates are rejected.
- Unexpected columns and negative media values fail before `MMMData`
  construction rather than being silently ignored or reported generically.
- `--help` and separate-process `include` do not run MCMC or write outputs.
- The quickstart is documented as a direct four-column teaching path, not a
  general ingestion API, pipeline feature, benchmark, release claim, or
  Abacus parity evidence.
- The focused package test file passes, Runic passes for touched Julia files,
  `git diff --check` passes, and the diff does not touch `src/`,
  `Project.toml`, or `Manifest.toml`.

## Verification Commands

Use scoped verification only:

```bash
julia --project=. examples/csv_mmm/run_csv_mmm.jl --help
make test-file FILE=test/examples/csv_mmm_quickstart.jl
julia --project=@runic -m Runic --check --diff examples/csv_mmm/run_csv_mmm.jl test/examples/csv_mmm_quickstart.jl
git diff --check
test -z "$(git diff --name-only -- src Project.toml Manifest.toml)"
```

Do not run the full suite unless this phase unexpectedly changes shared source,
exports, test-namespace behaviour, or dependency state.

## Risks And Mitigations

| Risk | Mitigation |
|---|---|
| Example overpromises generic ingestion | Fix the schema in code and README; reject missing named columns. |
| CSV date parsing varies by host locale | Use ISO values and an explicit date format. |
| Chronology/duplicates silently change time-series semantics | Sort all parsed rows together and reject duplicate parsed dates. |
| MCMC smoke becomes slow or flaky | Keep a one-chain, low draw/tune deterministic smoke run; put loader/error tests outside MCMC. |
| Copying example logic creates semantic drift | Keep configuration visibly small and test the direct result contract; do not create a premature package abstraction. |

## Review Notes

- Fresh-context plan review cleared the bounded example-only scope and scoped
  verification strategy. It found three Must Fix gaps: concrete typed parsing
  and column-specific failure behaviour, chronology/duplicate handling, and a
  mechanically explicit callable/CLI include-safe shape. All three are now
  incorporated above before Builder work.
- The reviewer also requested a fixed `--data` default/path error contract,
  exact small sampler settings, and stronger result/output assertions. Those
  Should Fix items are accepted above.
- The first implementation review found no Must Fix items. Its two Should Fix
  items are incorporated: draw/tune CLI values must be positive, and the
  focused test retains one output-directory MCMC integration fit instead of
  sampling twice merely to cover the trivial no-output branch.
- Final implementation review found and resolved one Must Fix: `Bool <: Real`
  would otherwise let CSV-inferred Boolean media values become `1.0`/`0.0`.
  The loader now rejects Booleans before numeric coercion and the focused test
  covers that path. The review also prompted parser-error and channel-alignment
  assertions. It recommended positive CLI draw/tune validation, which is now
  enforced with option-specific errors before model construction.

## Verification Results

- `julia --project=. examples/csv_mmm/run_csv_mmm.jl --help`: passed.
- `make test-file FILE=test/examples/csv_mmm_quickstart.jl`: passed after the
  final Boolean-coercion regression fix.
- Direct non-MCMC boundary probe for Boolean CSV media and non-positive draws:
  passed (`csv-boundaries-ok`).
- `julia --project=@runic -m Runic --check --diff examples/csv_mmm/run_csv_mmm.jl test/examples/csv_mmm_quickstart.jl`: passed.
- `git diff --check`: passed.
- `test -z "$(git diff --name-only -- src Project.toml Manifest.toml)"`: passed.
