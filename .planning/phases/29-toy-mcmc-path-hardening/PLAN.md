# Phase 29: Toy MCMC Path Hardening

## Status

Landed. The Three Man Team plan review cleared before code changes began, the
implementation review Must Fix was resolved, and scoped verification passed.

## Objective

Harden the Phase 28 toy `TimeSeriesMMM` MCMC smoke path so it is safe and
predictable as a first runnable example. This is example ergonomics and
regression coverage only: it does not change model semantics, inference
semantics, exports, dependency state, Abacus parity claims, or release evidence.

## Context

Phase 28 added `examples/toy_mmm/run_toy_mmm.jl`, a tiny synthetic
MCMC/Turing-only demo with optional compact outputs and focused coverage in
`test/examples/toy_mcmc_smoke.jl`. The current demo proves the happy path, but
the CLI and include boundaries are still lightly guarded. A first example is
often copied by users; invalid inputs should fail clearly and documentation
should explain what a successful smoke run does and does not mean.

## In Scope

- Keep the toy path MCMC/Turing-only and `TimeSeriesMMM`-only.
- Tighten CLI parsing for the existing options:
  - `--draws`
  - `--tune`
  - `--seed`
  - `--output-dir`
  - `-h` / `--help`
- Add clear `ArgumentError` failures for malformed integer option values.
- Preserve existing missing-value and unknown-argument failures.
- Add focused tests for parser/help/error paths that do not run MCMC.
- Add include-safety evidence that loading the example defines callable helpers
  without starting a sampler.
- Keep the existing tiny happy-path MCMC smoke assertion.
- Update the toy README with the success contract and explicit non-claims.
- Update planning/changelog state after implementation.

## Out Of Scope

- Any change under `src/`.
- Any change to `Project.toml` or `Manifest.toml`.
- Any model, sampler, posterior, post-model, optimization, pipeline, or
  calibration semantic change.
- Variational inference, dashboard/UI, AI advisor, Abacus parity, release-prep,
  benchmark, or full-suite validation work.
- Committing generated toy output files.

## Implementation Tasks

### Task 29-01: Plan And Review

- [x] Create this implementation plan.
- [x] Create/update `handoff/ARCHITECT-BRIEF.md`.
- [x] Run a reviewer pass over the plan before implementation.
- [x] Resolve or explicitly record review feedback.

### Task 29-02: CLI Contract Hardening

- [x] Add a small internal integer-option parser helper for the toy CLI.
- [x] Convert malformed integer values into option-specific `ArgumentError`
      messages.
- [x] Preserve the existing `run_toy_mmm` result contract and defaults.
- [x] Preserve direct-execution behaviour through `main(args = ARGS)`.

### Task 29-03: Focused Tests

- [x] Add non-MCMC parser tests for default options, help, missing values,
      malformed integer values, and unknown arguments.
- [x] Add an include-safety subprocess test that includes the toy script and
      proves no sampler/output path is invoked on include by asserting no
      `status=` or `backend=` smoke-run lines are printed and no toy output
      files are created in a temporary working directory.
- [x] Keep the existing happy-path smoke test small: one chain, low draw/tune
      counts, no full package suite.

### Task 29-04: Documentation And State

- [x] Update `examples/toy_mmm/README.md` with expected success output shape
      and CLI failure behaviour.
- [x] Update `CHANGELOG.md`.
- [x] Update `.planning/ROADMAP.md`.
- [x] Update `.planning/STATE.md`.
- [x] Mark this plan as landed only after verification passes.

## Acceptance Criteria

- `examples/toy_mmm/run_toy_mmm.jl --help` prints usage and does not run MCMC.
- Including `examples/toy_mmm/run_toy_mmm.jl` from another Julia process does
  not run MCMC or write outputs.
- Invalid toy CLI integer values fail with clear option-specific
  `ArgumentError` messages that include the option name and rejected value.
- Existing toy MCMC output semantics are unchanged.
- The focused toy test lane passes through the package test harness.
- Runic formatting passes for touched Julia files.
- `git diff --check` passes.
- No `src/`, `Project.toml`, or `Manifest.toml` files are touched.

## Verification Commands

Use scoped verification only:

```bash
julia --project=. examples/toy_mmm/run_toy_mmm.jl --help
make test-file FILE=test/examples/toy_mcmc_smoke.jl
julia --project=@runic -m Runic --check --diff examples/toy_mmm/run_toy_mmm.jl test/examples/toy_mcmc_smoke.jl
git diff --check
test -z "$(git diff --name-only -- src Project.toml Manifest.toml)"
```

Do not run the full suite for this phase unless the implementation unexpectedly
touches shared exported APIs, shared test namespace behaviour outside the toy
file, source runtime code, or dependency files.

## Review Notes

- Plan review cleared with no Must Fix items. Three Should Fix items were
  accepted before implementation: fail-closed forbidden-file verification,
  concrete help/include non-MCMC assertions, and explicit malformed-integer
  error-message shape.
- Implementation review found one Must Fix: overflowing integer strings must
  not leak `OverflowError` through the direct CLI process. The final fix uses
  `tryparse` to avoid exception chaining, and a subprocess test guards CLI
  stderr alongside the suggested `-h` test. The reviewer rechecked that
  remediation and cleared it with no remaining Must Fix items.

## Verification Results

- `julia --project=. examples/toy_mmm/run_toy_mmm.jl --help`: passed.
- `make test-file FILE=test/examples/toy_mcmc_smoke.jl`: passed, 92/92.
- `julia --project=@runic -m Runic --check --diff examples/toy_mmm/run_toy_mmm.jl test/examples/toy_mcmc_smoke.jl`: passed.
- `git diff --check`: passed.
- `test -z "$(git diff --name-only -- src Project.toml Manifest.toml)"`: passed.
