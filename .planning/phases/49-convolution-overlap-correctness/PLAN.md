# Phase 49: Convolution Overlap Parity Lock

Status: Landed

## Objective

Lock `batched_convolution(..., mode = Overlap)` parity for even-length kernels
and remove a dead/misleading source-index parameter without changing numerical
behaviour.

This phase is a narrow review-driven correctness hardening slice. It does not
touch adstock formulas, fixture generation, model code, pipeline code, release
gates, benchmarks, or broader reference-decoupling work.

## Finding Verification

The 2026-07-19 engineering review flagged `src/transforms/convolution.jl` as a
possible even-`l_max` off-by-one bug: `overlap_shift = fld(lag_length, 2)` is
computed and passed to `_source_index`, but `_source_index` ignores it and
recomputes `((lag_length - 1) ÷ 2)`.

Current source confirms the dead/misleading parameter:

- `src/transforms/convolution.jl`: `overlap_shift = fld(lag_length, 2)`
- `_source_index(..., overlap_shift, Overlap)` currently returns
  `t + ((lag_length - 1) ÷ 2) - lag + 1`

The local reference implementation at
`/home/user/Documents/GITHUB/tandpds/abacus/abacus/mmm/transforms/convolution.py`
uses:

```python
zeros_left = pt.zeros((*x_batch_shape, lags // 2), dtype=x.dtype)
zeros_right = pt.zeros((*x_batch_shape, (lags - 1) // 2), dtype=x.dtype)
```

Therefore even-length `Overlap` kernels require a left shift of `lags ÷ 2`, not
`(lags - 1) ÷ 2`.

However, live comparison against the local reference implementation disproved
the behavioural bug. PyTensor `convolve1d` orientation means Epsilon's current
`((lag_length - 1) ÷ 2)` source-index arithmetic matches Abacus for even-length
`Overlap`.

Verified hand case:

```text
x = [0, 0, 1, 0, 0]
w = [10, 20, 30, 40]
mode = Overlap
Epsilon output = [0, 10, 20, 30, 40]
Abacus output  = [0, 10, 20, 30, 40]
```

The correct fix is therefore to lock this parity explicitly and remove the
unused parameter, not to change alignment.

## File Allowlist

Implementation may touch only:

- `src/transforms/convolution.jl`
- `test/transforms/convolution.jl`
- `.planning/phases/49-convolution-overlap-correctness/PLAN.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`

The pre-existing untracked `.planning/CRITICAL-REVIEW-2026-07-19.md` remains
outside this phase and must not be staged.

## Tasks

### Task 49-01: Lock Even-Overlap Parity

Add focused deterministic tests in `test/transforms/convolution.jl` for
one-dimensional even-length `Overlap` kernels.

Acceptance criteria:

- [x] A hand-computed impulse/vector case proves the current Epsilon
      length-4 `Overlap` output matches Abacus.
- [x] The test passes on the current implementation.
- [x] The test would fail under the incorrect behavioural change
      `t + overlap_shift - lag + 1`.
- [x] Existing fixture-backed Abacus parity tests remain in place.

Verification:

- [x] `make test-file FILE=test/transforms/convolution.jl`

### Task 49-02: Remove Dead Overlap Parameter

Remove the unused `overlap_shift` local and `_source_index` parameter while
preserving the current `Overlap` source-index arithmetic.

Acceptance criteria:

- [x] `After` source indexing remains `t - lag + 1`.
- [x] `Before` source indexing remains `t + lag_length - lag`.
- [x] `Overlap` source indexing remains `t + ((lag_length - 1) ÷ 2) - lag + 1`.
- [x] The dead `overlap_shift` local/parameter is removed.
- [x] A short comment explains why the formula preserves Abacus/PyTensor
      convolution-orientation parity for even kernels.

Verification:

- [x] `make test-file FILE=test/transforms/convolution.jl`
- [x] `make test-file FILE=test/transforms/adstock.jl`

### Task 49-03: Planning Closure

Update roadmap/state once the focused transform lane passes.

Acceptance criteria:

- [x] `.planning/ROADMAP.md` records Phase 49.
- [x] `.planning/STATE.md` records the landed scope and exact verification.
- [x] The plan is marked landed.

Verification:

- [ ] `git diff --check`
- [ ] `git diff --cached --check`
- [ ] exact changed-file allowlist check

## Out Of Scope

- Regenerating Abacus fixtures.
- Editing generated fixture files.
- Changing adstock formulas or adstock tests outside any indirect coverage from
  the convolution primitive.
- Running full suite, `make smoke`, benchmarks, docs build, or release gates.
- Refactoring `Epsilon.jl` exports, coordinate forwarders, JuMP APIs,
  calibration, trend/holiday tests, or saturation validation.

## Verification Plan

Use scoped checks only:

```bash
make test-file FILE=test/transforms/convolution.jl
make test-file FILE=test/transforms/adstock.jl
make format-check-touched
git diff --check
git diff --cached --check
```

No full suite is required. This slice touches one deterministic transform
primitive and its focused test file; it does not touch shared test namespace
imports, model runtime, source exports, package dependencies, docs build inputs,
or pipeline behaviour. The focused adstock lane is included because adstock
delegates to `batched_convolution` and existing adstock fixtures include
even-length `Overlap` coverage.

## Review Questions

Independent review must check before implementation:

- whether the reference semantics have been read correctly;
- whether the proposed parity-lock test passes current Epsilon and would fail
  under the incorrect `overlap_shift` behavioural change;
- whether any adstock fixture/test lane is necessary in addition to the focused
  convolution lane;
- whether `CHANGELOG.md` should stay out of scope because no public behaviour
  changes;
- whether the file allowlist is tight enough; and
- whether the scoped verification plan is sufficient.

Review completed before implementation. The initial behavioural-fix plan was
rejected because it would introduce a parity regression. The approved scope is
to preserve current numerics, add even-kernel `Overlap` parity-lock tests,
remove the dead/misleading `overlap_shift` local/parameter, run both
convolution and adstock focused lanes, and keep `CHANGELOG.md` out of scope.
