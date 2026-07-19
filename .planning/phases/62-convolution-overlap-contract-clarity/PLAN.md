# Phase 62: Convolution Overlap Contract Clarity

Status: Implemented

## Objective

Make `batched_convolution(..., mode = Overlap)`'s odd/even kernel alignment
contract explicit in public documentation and focused tests, without changing
runtime behaviour.

Phase 49 already resolved the engineering review's suspected even-kernel bug:
the dead `overlap_shift` parameter was removed, current source-index arithmetic
was preserved, and a length-4 parity-lock test was added. Phase 62 is a
follow-on clarity slice so future readers do not rediscover the same ambiguity.

## Current Boundary

Current implementation:

- `After`: `x_t = t - lag + 1`
- `Before`: `x_t = t + lag_length - lag`
- `Overlap`: `x_t = t + ((lag_length - 1) ÷ 2) - lag + 1`

For `Overlap`, the current formula means an impulse at source index 3 with
weights `[10, 20, 30]` produces `[0, 10, 20, 30, 0]`, and with
`[10, 20, 30, 40]` produces `[0, 10, 20, 30, 40]`. The even-kernel convention
is intentionally the parity-preserving Epsilon/reference orientation locked in
Phase 49, not a newly introduced mathematical centring rule.

## Scope

In scope:

- `src/transforms/convolution.jl`
  - Clarify the public docstring for `Overlap` alignment.
  - Keep the existing source-index arithmetic unchanged.
- `test/transforms/convolution.jl`
  - Add focused impulse tests that pin odd- and even-length `Overlap`
    alignment side by side.
  - Preserve the existing fixture-backed parity loop.
- `CHANGELOG.md`
  - Add a small `Unreleased / Changed` note describing the documentation/test
    clarity, with no behaviour-change claim.
- This plan file.

Out of scope:

- Changing `After`, `Before`, or `Overlap` numeric behaviour.
- Regenerating fixtures or editing generated fixture files.
- Changing adstock formulas, model code, pipeline code, docs pages, exports,
  ROADMAP, STATE, parity ledger, benchmarks, smoke harness, dependencies, or
  release gates.
- Running the full suite.
- Staging the pre-existing `.gitignore` drift or the untracked
  `.planning/CRITICAL-REVIEW-2026-07-19.md`.

## File Allowlist

Implementation may touch only:

- `src/transforms/convolution.jl`
- `test/transforms/convolution.jl`
- `CHANGELOG.md`
- `.planning/phases/62-convolution-overlap-contract-clarity/PLAN.md`

The following local files are explicitly non-phase drift and must remain
unstaged:

- `.gitignore`
- `.planning/CRITICAL-REVIEW-2026-07-19.md`

## Tasks

### Task 62-01: Plan Review

Acceptance criteria:

- [x] Independent reviewer confirms Phase 49 already closed the behavioural
      bug suspicion.
- [x] Reviewer confirms Phase 62 should preserve current numerics.
- [x] Reviewer confirms the file allowlist and scoped verification are tight.

Verification:

- [x] Review result is recorded in this plan before implementation.

### Task 62-02: Public Contract Wording

Acceptance criteria:

- [x] `batched_convolution` docstring explains that `Overlap` uses a
      parity-preserving overlap orientation.
- [x] The docstring states the even-kernel convention explicitly enough that
      readers will not infer the opposite half-sample shift.
- [x] Source-index arithmetic remains unchanged.

Verification:

- [x] `git diff` confirms only docstring wording changed in
      `src/transforms/convolution.jl`.

### Task 62-03: Odd/Even Impulse Lock

Acceptance criteria:

- [x] Tests cover an odd-length `Overlap` impulse case.
- [x] Tests cover an even-length `Overlap` impulse case.
- [x] The even-length expected output remains the Phase 49 parity-locked
      `[0, 10, 20, 30, 40]` result.
- [x] Existing fixture-backed parity tests remain in place.

Verification:

- [x] `make test-file FILE=test/transforms/convolution.jl` passes.
- [x] `make format-check-touched` passes.
- [x] `git diff --check` passes.
- [x] `git diff --name-only | sort` confirms only allowlisted files plus known
      pre-existing local drift are present.
- [x] `git diff --cached --check` passes before commit.
- [x] `git diff --cached --name-only | sort` confirms the staged allowlist.
- [x] `git status --short --branch` is checked before commit.

## Independent Review Questions

Before implementation, an independent reviewer must check:

- whether the Phase 49 evidence makes behaviour changes inappropriate here;
- whether the proposed odd/even impulse tests express the contract without
  duplicating generated fixtures;
- whether `CHANGELOG.md` should be included for a public docstring/test
  clarification;
- whether docs build is necessary for this slice; and
- whether the scoped test command is sufficient without running the full suite.

## Independent Review Result

The independent reviewer approved Phase 62 as a contract-clarity follow-on to
Phase 49:

- Preserve the Phase 49 numerics and do not reopen the behavioural fix.
- Avoid fixture regeneration, ROADMAP, STATE, parity ledger, and full-suite
  work.
- Do not run `make docs` unless the docstring change adds new Documenter
  markup or examples; the planned prose-only wording does not need it.
- Avoid describing even-kernel `Overlap` as simply "centred", because that
  reintroduces the half-sample ambiguity. Use "parity-preserving overlap
  orientation" and show odd/even impulse examples.
- A changelog note is acceptable if it clearly says clarification/test lock
  only, with no convolution behaviour change.

## Landing Notes

- Reworded the `Overlap` enum doc and `batched_convolution` public docstring
  from ambiguous "centered overlap" wording to "parity-preserving overlap
  orientation".
- Added explicit odd- and even-length impulse examples to the public docstring.
- Replaced the Phase 49 even-only test with side-by-side odd/even impulse
  alignment checks while preserving the fixture-backed parity loop.
- Added a changelog note that describes the clarification and test lock without
  claiming any convolution behaviour change.
- Left source-index arithmetic untouched:
  `t + ((lag_length - 1) ÷ 2) - lag + 1`.
- Left fixtures, generated files, ROADMAP, STATE, parity ledger, docs pages,
  exports, dependencies, benchmarks, smoke harness, and release gates untouched.
- Left non-phase local drift unstaged: `.gitignore` currently adds
  `graphify-out/`, and `.planning/CRITICAL-REVIEW-2026-07-19.md` remains
  untracked.

Scoped verification:

```bash
make test-file FILE=test/transforms/convolution.jl
# Epsilon.jl: 23 passed / 23 total, 4.1s

make format-check-touched
git diff --check
# both passed with no output

git diff --name-only | sort
# .gitignore
# CHANGELOG.md
# src/transforms/convolution.jl
# test/transforms/convolution.jl

git ls-files --others --exclude-standard | sort
# .planning/CRITICAL-REVIEW-2026-07-19.md
# .planning/phases/62-convolution-overlap-contract-clarity/PLAN.md
```
