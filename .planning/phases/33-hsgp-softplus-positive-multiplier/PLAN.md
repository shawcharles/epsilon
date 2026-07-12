# Phase 33: HSGP Latent Projection And Positive Multiplier Semantics

## Status

Closed. Implemented under the Three Man Team workflow, independently reviewed,
and validated with one shared-namespace checkpoint.

## Objective

Port the deterministic numerical step that Abacus's `SoftPlusHSGP.create_variable`
performs after PyMC/PyTensor materialises HSGP coefficients: project standard-normal
coefficients onto the fixed basis using the square-root PSD weights, apply a
numerically stable softplus, and multiplicatively re-centre the result to have mean
one over the time axis while remaining strictly positive. This closes the last pure
numerical ingredient of the HSGP time-varying multiplier contract. It is still not a
Turing model, prior, sampled coefficient, or supported configuration surface.

## Reference Boundary

Confirmed directly against the local Abacus checkout at
`/home/user/Documents/GITHUB/tandpds/abacus` (the same checkout
`scripts/export_abacus_fixtures.py` already targets):

- `abacus/mmm/hsgp.py`, `HSGP.create_variable`: builds `hsgp_coefs` as a
  `Prior("Normal", mu=0, sigma=sqrt_psd, dims=hsgp_dims, centered=False)`
  variable. The non-centered parametrisation composes as
  `hsgp_coefs = 0 + sqrt_psd * z` for a standard-normal raw variable `z`, with
  `sqrt_psd` broadcasting along the retained-mode axis. For `len(rest_dims) <= 1`
  it then computes `f = phi @ hsgp_coefs.T`.
- `abacus/mmm/hsgp.py`, `SoftPlusHSGP.create_variable` (line 1420):
  ```python
  f = super().create_variable(f"{name}_raw")   # = phi @ hsgp_coefs.T
  f = pt.softplus(f)
  f_mean = f.mean(axis=0)                       # mean over the time axis
  centered_f = f / f_mean                        # mean-one, strictly positive
  ```
  The class docstring states the intent explicitly: "We then normalize
  multiplicatively by the time-mean so the resulting multiplier has mean 1 over
  the first dimension while remaining strictly positive."
- The local PyTensor scalar softplus uses strict thresholded branches:
  `x < -37 => exp(x)`; `-37 <= x < 18 => log1p(exp(x))`;
  `18 <= x < 33.3 => x + exp(-x)`; and `x >= 33.3 => x`. Phase 33 will port
  those branches rather than merely claim approximate output compatibility
  with a common two-branch formula.

Phase 33 ports only this deterministic latent-projection/softplus/normalisation
step, given already-supplied `phi`, `sqrt_psd`, and standard-normal coefficients
`z`. It explicitly does not build the `Prior`/`Normal` coefficient distribution,
does not decide `centered` vs. non-centered sampling, and does not touch the
`len(rest_dims) > 1` tensor-contraction branch.

## In Scope

- A private `_hsgp_latent` helper computing
  `latent = phi * (sqrt_psd .* z)` for deterministic `phi`, `sqrt_psd`, and
  supplied standard-normal `z`, supporting both a length-`m` vector `z` (one
  time-varying series) and an `m x k` matrix `z` (`k` independent series, e.g.
  channels).
- A private thresholded, numerically stable `_hsgp_stable_softplus` elementwise
  helper matching the local PyTensor branch semantics.
- A private `_hsgp_positive_multiplier` helper composing latent projection,
  stable softplus, and mean-one normalisation over the time axis, matching
  Abacus `SoftPlusHSGP`.
- Fixture-backed parity against the real Abacus/PyTensor `pt.softplus` primitive
  for the softplus step, with the projection and normalisation cross-checked in
  Julia-native arithmetic against the same fixture inputs.
- Explicit zero-retained-mode behaviour (`m = 1, drop_first = true`): the
  multiplier is asserted to be exactly `1.0` at every time point and column.
- Explicit finite-domain hardening, including the case where an entire
  column's softplus output underflows to exactly zero (degenerate all-zero
  mean), which must raise `ArgumentError` rather than return `NaN` from `0/0`.
- `ForwardDiff` gradient smoke coverage through `z`, `sqrt_psd`, and (by
  composition) `eta`/`lengthscale` from Phase 32's `_hsgp_sqrt_psd`.

## Out Of Scope

- Building the `hsgp_coefs` `Normal(0, sqrt_psd)` distribution itself, choosing
  `centered` vs. non-centered sampling, or any `Turing.@model` integration.
- The `len(rest_dims) > 1` (e.g. `("geo", "brand")`) tensor-contraction branch;
  Phase 33 supports only the vector and single extra-axis matrix cases that
  `HSGP.create_variable` itself special-cases with `phi @ hsgp_coefs.T`.
- `dims`/coordinate handling, `pm.Deterministic` naming,
  `deterministics_to_replace`, out-of-sample prediction/replay of the fitted
  `f_mean`, or panel semantics.
- `seasonality.type = "hsgp"`, YAML/config acceptance, `HSGPKwargs`, public
  exports, or any decision about time-varying intercept vs. time-varying media
  effects.
- New dependencies, dashboard/UI, or AI advisor work.

## Numerical Contract

Given a training-range HSGP basis `phi::Matrix{Float64}` of shape
`(n, m_retained)` (from Phase 32's `_hsgp_basis_matrix`), square-root PSD
weights `sqrt_psd::AbstractVector` of length `m_retained` (from Phase 32's
`_hsgp_sqrt_psd`, AD-compatible), and standard-normal coefficients `z`:

- `z` is either an `AbstractVector` of length `m_retained` or an
  `AbstractMatrix` of shape `(m_retained, k)` with `k >= 1`; `sqrt_psd`
  broadcasts along the mode axis (the first/row axis of a matrix `z`), exactly
  matching Abacus's `sigma = sqrt_psd` broadcast on the mode axis of
  `hsgp_coefs` before the `phi @ hsgp_coefs.T` contraction.
- `_hsgp_latent(phi, sqrt_psd, z) = phi * (sqrt_psd .* z)`, returning a
  length-`n` vector for vector `z` or an `n x k` matrix for matrix `z`.
- `_hsgp_stable_softplus(x)` ports the local PyTensor thresholded branches
  exactly: `x < -37 => exp(x)`; `-37 <= x < 18 => log1p(exp(x))`;
  `18 <= x < 33.3 => x + exp(-x)`; and `x >= 33.3 => x`.
- `_hsgp_positive_multiplier(phi, sqrt_psd, z)`:
  1. `latent = _hsgp_latent(phi, sqrt_psd, z)`;
  2. `raw = _hsgp_stable_softplus.(latent)`;
  3. every `raw` entry must be finite and strictly positive before any mean is
     calculated, because partial Float64 underflow would otherwise produce a
     zero-valued multiplier despite a positive column mean;
  4. `raw_mean = mean(raw; dims = 1)` (a one-element vector for vector `raw`,
     one value per column for matrix `raw`), matching `f.mean(axis=0)`;
  5. `multiplier = raw ./ raw_mean`.
- Zero-retained-mode boundary: when `m_retained == 0` (e.g. `m = 1,
  drop_first = true`), `phi` has zero columns and `sqrt_psd`/`z` have zero rows,
  so `latent` is the exact zero vector/matrix of shape `(n,)` / `(n, k)`.
  `raw = softplus(0) = log(2)` (a positive constant) at every entry, so
  `raw_mean = log(2)` and `multiplier` is exactly `1.0` at every time point and
  column, not merely "close to one".
- Hardening: `phi` and `z` must be finite; `sqrt_psd` must be finite and
  non-negative; `phi`'s column count, `sqrt_psd`'s length, and `z`'s mode-axis
  length must agree, else
  `ArgumentError`. `n = size(phi, 1) >= 1` is required. If any `raw` entry is
  non-finite or non-positive (covering all- and partially-underflowed Float64
  softplus output), or if `raw_mean` is not finite and strictly positive,
  `_hsgp_positive_multiplier` raises `ArgumentError` before division. The
  final `multiplier` output must itself be finite and strictly positive; this
  is asserted in fixture tests, not merely assumed from the closed-form
  softplus argument.

## Tasks

### Task 33-01: Contract And Fixture Design

- [x] Record this plan and its review resolution.
- [x] Independently review the plan against the real `abacus/mmm/hsgp.py`
      `SoftPlusHSGP.create_variable` source and `pt.softplus` semantics before
      implementation (this pass is recorded under Review Notes below; a
      second implementation-time pass follows the existing Phase 31/32
      convention).
- [x] Extend `scripts/export_abacus_fixtures.py` with deterministic
      HSGP-positive-multiplier cases that reuse Phase 32's `phi`/`sqrt_psd`
      generation for at least the `:expquad` and one other covariance family,
      plus:
      - a vector `z` case (single time-varying series);
      - a matrix `z` case (`m_retained x 2`, two independent series);
      - the `m = 1, drop_first = true` zero-retained-mode case;
      - an extreme-negative-`z` case that drives an entire column's `softplus`
        output to exactly `0.0` in `Float64`, to fixture-back the hardening
        guard; and
      - a partial-underflow case with one zero and one positive softplus entry,
        proving entry-level validation occurs before mean normalisation; and
      - threshold-boundary softplus values at exactly `-37.0`, `18.0`, and
        `33.3`, plus one value from each open interval.
      Compute the softplus step by evaluating the real PyTensor
      `pt.softplus(...)` on the fixed numeric `latent = phi @ (sqrt_psd * z)`
      array (built in NumPy from the exported `phi`/`sqrt_psd`/`z` literals),
      then compute the mean-one normalisation in NumPy; do not resample
      `hsgp_coefs` as a random variable, since `z` is supplied literally for
      reproducibility. For the all-underflowed-column case, export the latent
      and raw softplus values plus `expected_error = :nonpositive_raw_mean`;
      do not calculate or serialize a normalised multiplier from NumPy's
      undefined `0 / 0` result.
- [x] Extend `test/fixtures/abacus/hsgp_linearized_cases.jl` (or add a new
      sibling fixture file, e.g.
      `test/fixtures/abacus/hsgp_positive_multiplier_cases.jl`) with
      provenance headers and only Julia literals for `z`, expected `latent`,
      expected `softplus` output, and expected `multiplier` for valid rows;
      error rows carry their expected error marker instead of a multiplier.

### Task 33-02: Pure Julia Latent And Multiplier Helpers

- [x] Add private `_hsgp_latent`, `_hsgp_stable_softplus`, and
      `_hsgp_positive_multiplier` helpers to `src/mmm/hsgp.jl`.
- [x] Support both vector and matrix `z` without duplicating the
      normalisation logic (`mean(...; dims = 1)` generalises across both
      shapes using `reshape`/broadcasting, avoiding separate vector/matrix
      code paths where possible).
- [x] Preserve AD-compatible numeric types through `z`, `sqrt_psd`, and any
      composed `eta`/`lengthscale` from Phase 32's `_hsgp_sqrt_psd`; do not
      hard-cast to `Float64` inside these helpers.
- [x] Implement the explicit raw-entry and raw-mean finite/positive guards
      described in the Numerical Contract before performing the division.
- [x] Do not modify `src/Epsilon.jl`, config/seasonality validation, model
      builders, inference, serialization, or public exports.

### Task 33-03: Fixture Evidence And Closure

- [x] Add `test/model/hsgp_positive_multiplier.jl` (or extend
      `test/model/hsgp_linearized.jl`) and register it in model runtests.
- [x] Assert fixture parity for vector and matrix `z`, across at least two
      covariance families, with numerical tolerances.
- [x] Assert the zero-retained-mode boundary yields an exact `1.0` multiplier
      at every time point and column.
- [x] Assert the degenerate all-underflowed-column case raises
  `ArgumentError` instead of `NaN`/`Inf`.
- [x] Assert a partially underflowed raw column also raises `ArgumentError`
      rather than emitting a zero-valued multiplier.
- [x] Assert pure-helper `ArgumentError`s for empty/non-finite input and
      mismatched `phi`/`sqrt_psd`/`z` mode-axis lengths.
- [x] Add `ForwardDiff` gradient smoke coverage through `z` and through
      `eta`/`lengthscale` end-to-end (via `_hsgp_sqrt_psd` then
      `_hsgp_positive_multiplier`).
- [x] Assert all helpers remain private and HSGP config remains rejected.
- [x] Document the fixture workflow and update ledger/changelog/roadmap/state
      without changing the HSGP/time-varying ledger row from `missing`.
- [x] At phase closure only, run one full-suite shared-namespace checkpoint
      because test registration changes; do not use it during normal
      iteration.

## Acceptance Criteria

- `_hsgp_positive_multiplier` output agrees with the generated Abacus/PyTensor
  `pt.softplus`-based fixtures for vector and matrix `z`, across the fixture
  covariance families, within numerical tolerance.
- The zero-retained-mode case yields an exact `1.0` multiplier, not an
  approximate one.
- The degenerate all-underflowed-column case is explicitly rejected with
  `ArgumentError` rather than silently returning `NaN`.
- Gradients through `z` and through `eta`/`lengthscale` (composed through
  Phase 32's `_hsgp_sqrt_psd`) are finite via `ForwardDiff`.
- No `Prior`, distribution, Turing model, sampler, configuration, export,
  prediction, replay, or panel surface changes.
- Julia tests consume only generated fixture literals and never invoke
  Python.
- The HSGP/time-varying ledger row remains `missing`.

## Verification

```bash
PYTHONNOUSERSITE=1 python scripts/export_abacus_fixtures.py
python -m py_compile scripts/export_abacus_fixtures.py
make test-file FILE=test/model/hsgp_positive_multiplier.jl
julia --project=@runic -m Runic --check --diff src/mmm/hsgp.jl test/model/hsgp_positive_multiplier.jl
git diff --check
test -z "$(git diff --name-only -- Project.toml Manifest.toml)"
# Final checkpoint only, after review:
make test
```

## Risks

| Risk | Mitigation |
|---|---|
| Misreading the non-centered coefficient composition order (`sqrt_psd * z` vs. `z * sqrt_psd`) | Confirmed directly against `abacus/mmm/hsgp.py` `Prior("Normal", mu=0, sigma=sqrt_psd, centered=False)` and non-centered composition semantics before writing the contract. |
| Naive `log(1 + exp(x))` softplus overflowing for large `x` | Port the local PyTensor strict threshold branches and fixture-check `-37.0`, `18.0`, `33.3`, and every open interval. |
| Zero/NaN multiplier from underflowed softplus entries | Explicit finite/positive guard on every `raw` entry before calculating means, fixture-backed with all- and partial-underflow cases. |
| Matrix orientation ambiguity between Abacus's `(channel, m)` coefficient layout and Julia's natural `(m, k)` layout | Document the `sqrt_psd` broadcast axis explicitly in the Numerical Contract and test both vector and matrix shapes against fixtures generated from the real `phi @ hsgp_coefs.T` contraction order. |
| AD breaks on the later Turing integration phase | Avoid hard `Float64` casts on `z`/`sqrt_psd`; add `ForwardDiff` smoke tests now, composed through Phase 32's `_hsgp_sqrt_psd`. |
| Numerical primitives are misrepresented as support | Keep helpers private, config rejection intact, and ledger status `missing`. |

## Review Notes

- Implementation review found no numerical, AD, security, fixture-provenance,
  or scope defect. It did catch unrelated fixture-header churn introduced by a
  full exporter regeneration; those generated files were restored before
  closure, leaving only the new Phase 33 fixture. Scoped verification passed:
  the focused package test reported `46 / 46` in `9.7s`, the fixture was
  byte-stable across regeneration, Runic passed, and `git diff --check` plus
  dependency-scope guards passed. The one phase-closing `make test`
  shared-namespace checkpoint then passed `8,620 / 8,620` in `20m24.2s`.

- The independent review pass confirmed the plan against the actual Abacus
  checkout (`/home/user/Documents/GITHUB/tandpds/abacus`) rather than the
  task description alone, and required three changes before approval:
  1. The exact non-centered coefficient composition
     (`hsgp_coefs = sqrt_psd .* z`, broadcasting `sqrt_psd` along the mode
     axis) had to be cited from `HSGP.create_variable`'s
     `Prior("Normal", mu=0, sigma=sqrt_psd, centered=False)` call, not assumed
     from the task description's shorthand.
  2. The softplus step must use PyTensor's numerically stable branchwise
     formula, not the naive `log(1 + exp(x))` form, and this must be
     fixture-checked in both branches.
  3. The mean-one normalisation must explicitly guard against an
     all-underflowed column producing `0/0`, since `softplus` can round to
     exactly `0.0` in `Float64` for sufficiently negative `latent`; this is a
     real floating-point failure mode, not a purely theoretical one, and is
     now a required fixture case and hardening rule rather than an implicit
     assumption.
  4. The all-underflowed-column fixture records the PyTensor-derived latent and
     raw softplus values only, then requires Epsilon's pre-division
     `:nonpositive_raw_mean` failure. It never treats NumPy's undefined `0/0`
     normalisation as a reference multiplier.
- The reviewer also confirmed that Phase 33's scope boundary
  (vector and single-extra-axis matrix `z` only, no `Prior`/Turing wiring, no
  `len(rest_dims) > 1` contraction) matches exactly what Abacus's own
  `HSGP.create_variable` special-cases with `phi @ hsgp_coefs.T`, so this
  phase does not silently under- or over-claim relative to the real
  reference implementation.
- The reviewer confirmed the zero-retained-mode boundary claim
  (`m = 1, drop_first = true` implies an exact `1.0` multiplier) algebraically
  before it was written into the Numerical Contract: with zero columns,
  `latent` is the exact zero array, `softplus(0) = log(2)` exactly, and the
  mean of a constant is that constant, so the ratio is exactly `1.0` in exact
  arithmetic and expected to hold to floating tolerance in `Float64`.
- A fresh independent review then found three additional contract gaps: a
  partially underflowed raw column can yield a zero multiplier despite a
  positive mean; local PyTensor uses thresholded rather than two-branch
  softplus semantics; and supplied `sqrt_psd` values need a non-negative
  contract. Those corrections are incorporated above. Re-approval is pending
  before builder implementation.
- Final review also required exact strict comparison ownership at the three
  PyTensor thresholds. The contract and fixture matrix now name `-37.0`,
  `18.0`, and `33.3` explicitly. The amended plan was independently approved
  for builder implementation with no remaining Must Fix findings.
