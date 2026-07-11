# Phase 32: HSGP Linearised Geometry Foundation

## Status

Reviewed and ready for Three Man Team implementation. No implementation has
started.

## Objective

Port the deterministic, one-dimensional HSGP numerical ingredients that Abacus
uses before it creates PyMC graph objects: Laplacian frequencies, fixed basis
matrices, covariance spectral-density square roots, and the two deterministic
recommendation heuristics. This is not an HSGP model, time-varying parameter,
or supported configuration feature.

## Reference Boundary

Abacus `HSGP.create_variable` builds a PyMC `gp.HSGP`, calls
`prior_linearized`, then creates PyTensor random variables. Its numerical
outputs are the fixed eigenfunction matrix `phi` and `sqrt_psd` vector.
`prior_linearized` freezes the centre at the training input range midpoint;
Abacus separately uses `X_mid` in its `m`/`L` recommendation heuristic.

Phase 32 ports only the deterministic numerical boundary. Fixture generation
may call Abacus and its PyMC dependency, but Julia runtime and tests must not
call Python or create a Turing/PyMC-like graph.

## In Scope

- Private helpers in `src/mmm/hsgp.jl` for one-dimensional HSGP frequencies,
  basis matrices, square-root PSD weights, and recommendation heuristics.
- Fixture-backed parity against Abacus `approx_hsgp_hyperparams`,
  `create_m_and_L_recommendations`, and the exact PyMC
  `gp.HSGP.prior_linearized` primitive used by Abacus.
- Non-periodic `:expquad`, `:matern32`, and `:matern52` covariance families.
- Explicit Julia input hardening for invalid numerical domains and malformed
  recommendation inputs.
- Focused tests, fixture documentation, and conservative planning/ledger
  evidence. The HSGP/TVP ledger row remains `missing`.

## Out Of Scope

- `seasonality.type = "hsgp"`, YAML/config acceptance, public exports,
  `HSGPKwargs`, HSGP priors, or prior parsing.
- `Turing.@model`, sampled HSGP coefficients, MCMC, VI, `SoftPlusHSGP`, or
  mean-one positive multiplier semantics.
- Time-varying intercepts/media, prediction/replay, panels, periodic HSGP,
  transformations, new dependencies, dashboard/UI, or AI advisor work.

## Numerical Contract

For a finite numeric vector `x`, positive integer `m`, and positive boundary
`L`, compute the fixed one-dimensional basis from the training-range midpoint
`centre = (minimum(x) + maximum(x)) / 2`:

- modes are `j = 1:m`;
- frequencies are `omega_j = pi * j / (2L)`;
- basis columns are
  `phi_j(x) = L^(-1/2) * sin(omega_j * ((x - centre) + L))`;
- `drop_first` removes the first mode after construction;
- `demeaned_basis` subtracts each retained column mean after first-mode
  removal;
- square-root PSD weights correspond positionally to retained basis columns.

`_hsgp_basis_matrix` is training-geometry-only in this phase: it derives its
centre from its supplied training vector. Future prediction work must carry the
fitted centre rather than recomputing it from new inputs.

For `ell = lengthscale`, the one-dimensional covariance PSDs are the current
PyMC `power_spectral_density` formulas:

- `expquad`: `sqrt(2pi) * ell * exp(-0.5 * ell^2 * omega^2)`;
- `matern32`: `12sqrt(3) * ell * (3 + ell^2 * omega^2)^(-2)`;
- `matern52`: `(400sqrt(5) / 3) * ell * (5 + ell^2 * omega^2)^(-3)`.

The retained weights are exactly
`sqrt_psd_j = sqrt(eta^2 * S_covariance(omega_j, ell))`. The helper must
preserve an AD-compatible numeric type for `eta` and `lengthscale`; fixed basis
output may be `Matrix{Float64}`. It supports only the three non-periodic
covariance families listed above.

Pure-helper hardening is explicit: `_hsgp_frequencies` requires `m >= 1` and
finite `L > 0`; `_hsgp_basis_matrix` requires non-empty finite `x`, `m >= 1`,
and finite `L > 0`; `_hsgp_sqrt_psd` requires `m >= 1`, finite `L > 0`, and
finite `eta > 0` and `lengthscale > 0`. Each violation raises `ArgumentError`,
including non-finite values, rather than leaking reduction or numerical-domain
exceptions.

The recommendation helpers mirror Abacus's deterministic layers:

- `_approx_hsgp_hyperparams(x, x_center; lengthscale_range, covariance)`
  returns `(m, c)` with `S = maximum(abs.(x .- x_center))`, covariance
  constants `(a1, a2)` of `(3.2, 1.75)` for `:expquad`, `(4.1, 2.65)` for
  `:matern52`, and `(4.5, 3.42)` for `:matern32`, then
  `c = max(a1 * lengthscale_upper / S, 1.2)` and
  `m = floor(Int, a2 * c * S / lengthscale_lower)`;
- `_recommend_hsgp_basis(x, x_mid; lengthscale_lower, lengthscale_upper,
  covariance)` retains Abacus's `lengthscale_upper = nothing` default of
  `2 * x_mid`, calls the preceding helper, and returns `L = c * x_mid`.

Unlike Abacus's incidental failures, Epsilon will explicitly reject empty,
non-finite, zero-span, and invalid-positive-domain recommendation inputs with
`ArgumentError`: `x_center` and `x_mid` must be finite scalars, `x_mid > 0`,
and the resolved bounds must satisfy `0 < lower < upper`. This is Epsilon-native
hardening, not error-message parity.

## Tasks

### Task 32-01: Contract And Fixture Design

- [ ] Record the architect brief and this plan.
- [ ] Independently review the plan against Abacus and PyMC's
      `prior_linearized` source before implementation.
- [ ] Extend `scripts/export_abacus_fixtures.py` with deterministic fixed
      cases for all three covariance families, a discriminating asymmetric
      input `[0.0, 1.0, 10.0]` whose range midpoint differs from its mean,
      `drop_first`, `demeaned_basis`, and at least one non-unit `eta` case.
- [ ] Export heuristic `(m, c)` and `(m, L)` expectations by calling real
      Abacus helpers; export `phi` and `sqrt_psd` using the real PyMC primitive
      that Abacus calls.
- [ ] Create `test/fixtures/abacus/hsgp_linearized_cases.jl` with provenance
      headers and only Julia literals.

### Task 32-02: Pure Julia Geometry

- [ ] Add private `_hsgp_frequencies`, `_hsgp_basis_matrix`, and
      `_hsgp_sqrt_psd` helpers to `src/mmm/hsgp.jl`.
- [ ] Add private `_approx_hsgp_hyperparams` and `_recommend_hsgp_basis`
      helpers with documented Epsilon hardening.
- [ ] Preserve `drop_first` then demeaned-basis ordering, training-range
      midpoint centring, covariance mode order, and AD-compatible hyperparameter
      arithmetic.
- [ ] Do not modify `src/Epsilon.jl`, config/seasonality validation, model
      builders, inference, serialization, or public exports.

### Task 32-03: Fixture Evidence And Closure

- [ ] Add `test/model/hsgp_linearized.jl` and register it in model runtests.
- [ ] Assert fixture parity with numerical tolerances, basis/PSD alignment,
      column demeaning, first-mode removal, and recommendation values.
- [ ] Assert that `m = 1, drop_first = true` yields a valid `n x 0` basis and
      zero-length aligned PSD vector.
- [ ] Assert pure-helper `ArgumentError`s for empty/non-finite input, invalid
      `m`/`L`, and invalid `eta`/`lengthscale`, in addition to recommendation
      input hardening.
- [ ] Add invalid-input and `ForwardDiff` gradient smoke coverage.
- [ ] Assert all helpers remain private and HSGP config remains rejected.
- [ ] Document the fixture workflow and update ledger/changelog/roadmap/state
      without changing HSGP/TVP status from `missing`.
- [ ] At phase closure only, run one full-suite shared-namespace checkpoint
      because test registration changes; do not use it during normal iteration.

## Acceptance Criteria

- Fixed `phi` and `sqrt_psd` outputs agree with generated Abacus/PyMC fixtures
  for each supported covariance family and basis option.
- Heuristic `(m, c)` and `(m, L)` outputs agree with Abacus for valid fixture
  cases; Epsilon hardening cases fail clearly before undefined arithmetic.
- `eta` and `lengthscale` gradients through `_hsgp_sqrt_psd` are finite and
  agree across supported forward/reverse AD checks where applicable.
- No graph object, sampler, configuration, export, model, prediction, replay,
  or panel surface changes.
- Julia tests consume only generated fixture literals and never invoke Python.
- The HSGP/time-varying ledger row remains `missing`.

## Verification

```bash
PYTHONNOUSERSITE=1 python scripts/export_abacus_fixtures.py
python -m py_compile scripts/export_abacus_fixtures.py
make test-file FILE=test/model/hsgp_linearized.jl
julia --project=@runic -m Runic --check --diff src/mmm/hsgp.jl test/model/hsgp_linearized.jl
git diff --check
test -z "$(git diff --name-only -- Project.toml Manifest.toml)"
# Final checkpoint only, after review:
make test
```

## Risks

| Risk | Mitigation |
|---|---|
| PyMC implementation changes underneath Abacus | Generate compact fixtures from the local Abacus checkout and preserve its revision/dirty provenance. |
| Confusing `X_mid` with basis centre | Test asymmetric vectors and keep range-midpoint and recommendation inputs as distinct helper arguments. |
| Basis/PSD modes become misaligned | Derive both from the same retained mode range and test shapes/column order explicitly. |
| AD breaks on future Turing integration | Avoid hard `Float64` casts of `eta` and `lengthscale`; add AD smoke tests now. |
| Numerical primitives are misrepresented as support | Keep helpers private, config rejection intact, and ledger status `missing`. |

## Review Notes

- The independent reviewer required the exact Abacus heuristic constants,
  rounding, `lengthscale_upper = nothing` default, and valid input domains to
  be frozen in the plan before implementation.
- The reviewer required exact one-dimensional PyMC PSD formulas, a non-unit
  `eta` fixture, a vector whose range midpoint differs from its arithmetic
  mean, and the `m = 1, drop_first = true` zero-column boundary.
- The reviewer also required explicit finite-domain `ArgumentError` contracts
  for each pure helper. All findings were incorporated and the plan was
  approved on re-review.
