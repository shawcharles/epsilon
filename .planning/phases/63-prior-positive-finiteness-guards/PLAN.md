# Phase 63: Prior Positive-Finiteness Guards

Status: Implemented

## Objective

Close the finite-prior validation gap identified by the July engineering
review: positive scale, shape, rate, degrees-of-freedom, and shrinkage recipe
parameters must be finite as well as positive.

The target is deliberately narrow. It hardens positive prior parameters that
currently admit `Inf`, without redesigning the general `EpsilonPrior`
configuration surface or validating location/support parameters that may
legitimately be unbounded in some distributions.

## Current Boundary

Live audit confirmed these examples currently construct successfully:

- `HorseshoePrior(; scale = Inf)`
- `FinnishHorseshoePrior(; scale = Inf)`
- `FinnishHorseshoePrior(; slab_scale = Inf)`
- `FinnishHorseshoePrior(; slab_df = Inf)`
- `R2D2Prior(; concentration = Inf)`
- `R2D2Prior(; scale = Inf)`
- `instantiate_distribution(EpsilonPrior("Scaled"; ..., scale = Inf))`
- `instantiate_distribution(EpsilonPrior("SkewStudentT"; nu = Inf, sigma = 1.0))`
- `instantiate_distribution(EpsilonPrior("SkewStudentT"; nu = 7.0, sigma = Inf))`
- `instantiate_distribution(EpsilonPrior("Normal"; mu = 0.0, sigma = Inf))`

`R2D2Prior(; mean_R2 = Inf)` already fails because it is constrained to
`(0, 1)`. `Exponential(lam = Inf)` currently fails indirectly after rate
inversion, but this phase should make the Epsilon-side error explicit and
consistent for positive rate parameters.

## Scope

In scope:

- `src/distributions/priors.jl`
  - Add private helpers for required/optional positive finite scalar
    parameters.
  - Use them for positive parameters in ordinary instantiable priors:
    `sigma`, `alpha`, `beta`, `rate`/`lam`, `b`, `nu`, and scale aliases.
  - Leave location/skewness/truncation-bound parameters on existing code paths.
- `src/distributions/special.jl`
  - Require `Scaled.scale` to be finite positive.
  - Require `SkewStudentT.nu` and `SkewStudentT.sigma` to be finite positive.
  - Require `LogNormalPrior.mean`, `LogNormalPrior.std`, and `LaplacePrior.b`
    to be finite where they are instantiated into Distributions.jl objects.
  - Leave `SkewStudentT.mu`, `SkewStudentT.alpha`, and `LaplacePrior.mu`
    location/skew parameters out of scope.
- `src/distributions/shrinkage.jl`
  - Require shrinkage recipe positive parameters to be finite as well as
    positive.
  - Preserve existing error-message shape where practical.
- Tests:
  - Add focused `Inf` rejection tests in `test/distributions/priors.jl`,
    `test/distributions/special.jl`, and `test/distributions/shrinkage.jl`.
- `CHANGELOG.md`
  - Add a short `Unreleased / Changed` note for the hardening.
- This plan file.

Out of scope:

- Rejecting infinite truncation bounds such as `TruncatedNormal.lower` or
  `TruncatedNormal.upper`.
- Rejecting infinite location/skewness parameters in this slice.
- Changing distribution names, serialisation payloads, public exports, model
  builder code, pipeline code, docs pages, fixtures, ROADMAP, STATE, parity
  ledger, benchmarks, smoke harness, or release gates.
- Running the full suite.
- Staging the pre-existing `.gitignore` drift or the untracked
  `.planning/CRITICAL-REVIEW-2026-07-19.md`.

## File Allowlist

Implementation may touch only:

- `src/distributions/priors.jl`
- `src/distributions/special.jl`
- `src/distributions/shrinkage.jl`
- `test/distributions/priors.jl`
- `test/distributions/special.jl`
- `test/distributions/shrinkage.jl`
- `CHANGELOG.md`
- `.planning/phases/63-prior-positive-finiteness-guards/PLAN.md`

The following local files are explicitly non-phase drift and must remain
unstaged:

- `.gitignore`
- `.planning/CRITICAL-REVIEW-2026-07-19.md`

## Tasks

### Task 63-01: Plan Review

Acceptance criteria:

- [x] Independent reviewer confirms the positive-parameter boundary is correct.
- [x] Reviewer confirms location/skewness/support-bound validation should stay
      out of scope.
- [x] Reviewer confirms the focused distribution tests are sufficient without
      running the full suite.

Verification:

- [x] Review result is recorded in this plan before implementation.

### Task 63-02: Ordinary Prior Instantiation Guards

Acceptance criteria:

- [x] Ordinary instantiable priors reject `Inf` for positive scale, shape,
      rate, and degrees-of-freedom parameters before constructing
      Distributions.jl objects.
- [x] Required-parameter missing-key errors remain unchanged.
- [x] Nested-prior rejection remains unchanged.
- [x] Truncation bounds and location/skewness parameters are not changed.

Verification:

- [x] `test/distributions/priors.jl` covers representative finite-positive
      rejection cases.

### Task 63-03: Special And Shrinkage Prior Guards

Acceptance criteria:

- [x] `Scaled` rejects infinite scale.
- [x] `SkewStudentT` rejects infinite `nu` and `sigma`.
- [x] `LogNormalPrior` and `LaplacePrior` instantiation reject infinite
      positive parameters.
- [x] Shrinkage recipe constructors reject infinite positive recipe
      parameters.

Verification:

- [x] `test/distributions/special.jl` and `test/distributions/shrinkage.jl`
      cover the new rejection cases.

### Task 63-04: Scoped Verification And Commit

Acceptance criteria:

- [x] Changelog records the hardening without implying API or behaviour beyond
      validation tightening.
- [x] Only allowlisted files are staged.
- [x] Pre-existing local drift remains unstaged.

Verification:

- [x] `make test-file FILE=test/distributions/priors.jl` passes.
- [x] `make test-file FILE=test/distributions/special.jl` passes.
- [x] `make test-file FILE=test/distributions/shrinkage.jl` passes.
- [x] `make format-check-touched` passes.
- [x] `git diff --check` passes.
- [x] `git diff --name-only | sort` confirms only allowlisted files plus known
      pre-existing local drift are present.
- [x] `git diff --cached --check` passes before commit.
- [x] `git diff --cached --name-only | sort` confirms the staged allowlist.
- [x] `git status --short --branch` is checked before commit.

## Independent Review Questions

Before implementation, an independent reviewer must check:

- whether `Inf` rejection should happen in Epsilon helpers before
  Distributions.jl construction;
- whether the proposed positive-parameter list is complete without expanding
  into location/skewness/support-bound validation;
- whether `LogNormalPrior` and `LaplacePrior` should be included because they
  instantiate through Epsilon-owned positive checks;
- whether the three focused distribution test files are the right verification
  surface; and
- whether a full-suite or docs build is unnecessary for this validation-only
  slice.

## Independent Review Result

The independent reviewer approved Phase 63 with implementation guardrails:

- The scope is correctly limited to finite-positive scale, shape, rate,
  degrees-of-freedom, and shrinkage recipe parameters.
- Validate by distribution semantics rather than blanket parameter names.
  `Cauchy` uses `alpha` as a location alias, so it must not be caught by a
  generic `alpha` rule.
- Add private required/optional positive-finite helpers in `priors.jl` while
  preserving missing-key errors.
- Harden exported `Scaled` and `SkewStudentT` constructors directly, not only
  `instantiate_distribution`.
- Harden `LogNormalPrior.mean`, `LogNormalPrior.std`, and `LaplacePrior.b` at
  instantiation only; leave `LaplacePrior.mu`, `SkewStudentT.mu`, and
  `SkewStudentT.alpha` alone.
- Tighten `shrinkage.jl`'s `_positive_parameter` helper to require
  finite-positive values.
- The three focused distribution test files are the right verification surface;
  no full suite or docs build is needed for this validation-only slice.

## Landing Notes

- Added private positive-finite parameter helpers in `src/distributions/priors.jl`
  and applied them by distribution semantics, not blanket parameter names.
- Preserved the explicit `Scaled scale cannot be a nested prior parameter`
  rejection path before checking finite positivity.
- Hardened positive ordinary prior parameters: `sigma`, `alpha`/`beta` where
  they are shape/scale parameters, `lam`/`lambda`/`rate`, `b`, `nu`, and scale
  aliases.
- Left Cauchy's `alpha` location alias, truncation bounds, location parameters,
  and skewness parameters out of scope.
- Hardened exported `Scaled` and `SkewStudentT` constructors directly, plus
  `LogNormalPrior` and `LaplacePrior` instantiation-time positive parameters.
- Tightened shrinkage recipe constructor validation for horseshoe,
  Finnish-horseshoe, and R2D2 finite-positive parameters.
- Added focused `Inf` rejection coverage in the three distribution test files.
- Added a changelog note under `Unreleased / Changed`.
- Left distribution names, exports, model builder code, pipeline code, docs
  pages, fixtures, ROADMAP, STATE, parity ledger, benchmarks, smoke harness,
  and release gates untouched.
- Left non-phase local drift unstaged: `.gitignore` currently adds
  `graphify-out/`, and `.planning/CRITICAL-REVIEW-2026-07-19.md` remains
  untracked.

Scoped verification:

```bash
make test-file FILE=test/distributions/priors.jl
# Epsilon.jl: 47 passed / 47 total, 4.6s

make test-file FILE=test/distributions/special.jl
# Epsilon.jl: 71 passed / 71 total, 7.3s

make test-file FILE=test/distributions/shrinkage.jl
# Epsilon.jl: 25 passed / 25 total, 4.9s

make format-check-touched
git diff --check
# both passed with no output

git diff --name-only | sort
# .gitignore
# CHANGELOG.md
# src/distributions/priors.jl
# src/distributions/shrinkage.jl
# src/distributions/special.jl
# test/distributions/priors.jl
# test/distributions/shrinkage.jl
# test/distributions/special.jl

git ls-files --others --exclude-standard | sort
# .planning/CRITICAL-REVIEW-2026-07-19.md
# .planning/phases/63-prior-positive-finiteness-guards/PLAN.md
```
