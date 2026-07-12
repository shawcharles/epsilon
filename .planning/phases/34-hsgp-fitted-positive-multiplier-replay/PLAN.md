# Phase 34: HSGP Fitted Positive Multiplier Replay

## Status

Closed. Implemented under the Three Man Team workflow, independently reviewed,
and validated with one shared-namespace checkpoint.

## Objective

Port the deterministic fitted-state replay contract implicit in Abacus
SoftPlusHSGP: when evaluating a supplied HSGP coefficient draw on new inputs,
reuse the training basis centre, optional training basis de-meaning offset, and
training softplus mean. This prevents a discontinuity caused by recentering or
renormalising on prediction inputs. It remains a private, per-coefficient-draw
numerical foundation, not an HSGP model or supported time-varying-parameter
surface.

## Reference Boundary

Confirmed directly against the local Abacus checkout at
/home/user/Documents/GITHUB/tandpds/abacus:

- abacus/mmm/hsgp.py, HSGP.create_variable constructs the HSGP basis from
  registered training X - X_mid; its optional demeaned_basis operation subtracts
  the training basis column means before coefficient projection.
- abacus/mmm/hsgp.py, SoftPlusHSGP.create_variable computes
  f_mean = softplus(f).mean(axis=0), names it as a deterministic, and divides
  by that training value.
- SoftPlusHSGP.deterministics_to_replace returns the saved
  "{name}_f_mean" deterministic for out-of-sample graph replay specifically
  so the training/test multiplier remains continuous.
- abacus/tests/mmm/test_hsgp.py,
  test_soft_plus_hsgp_continous_with_new_data verifies that replay mechanism.

The exporter must exercise one real Abacus SoftPlusHSGP graph built with mutable
PyMC Data: construct it on training coordinates, retain its frozen training
centre and optional de-meaning offset, sample one deterministic seeded
coefficient draw, then call set_data for prediction coordinates and replay with
the saved f_mean deterministic replaced as Abacus does. It exports the
corresponding fixed coefficient literals plus training/prediction values for
Julia. This provides graph-lifecycle evidence for the retained-state contract,
while Epsilon still implements only its deterministic numerical equivalent.

## In Scope

- A private immutable _HSGPPositiveMultiplierState storing one concrete
  coefficient draw's replay state: mode and boundary settings, training basis
  centre, optional training basis column offset, an immutable defensive
  snapshot of weighted coefficients sqrt_psd .* z, and per-series training
  raw-softplus means.
- A private _fit_hsgp_positive_multiplier_state(x_training, sqrt_psd, z; m,
  L, drop_first = false, demeaned_basis = false) constructor. It computes fixed
  training geometry and a denominator only; it samples nothing.
- A private _hsgp_replay_positive_multiplier(x, state) evaluator returning a
  strictly positive multiplier on finite numeric inputs while dividing by the
  stored training denominator.
- A private basis-at-fixed-centre helper, used by state construction and
  replay, without changing Phase 32's _hsgp_basis_matrix contract.
- Fixture-backed training and prediction values for vector and m_retained x k
  matrix coefficients, including one demeaned-basis case and zero retained
  modes.
- Focused tests showing that replay uses the training denominator and training
  geometry rather than recomputing either from prediction inputs.
- ForwardDiff smoke coverage through z, eta, and lengthscale over the
  fit-state-plus-replay composition.

## Out Of Scope

- HSGP priors, centred/non-centred sampling decisions, Turing integration,
  posterior storage, or posterior predictive integration.
- YAML/config/API acceptance, HSGPKwargs, public exports, serialization, or
  model spec changes.
- Choosing whether a future multiplier belongs to intercept, media effects, or
  another model component.
- PanelMMM, periodic HSGP, multiple additional coordinate axes, and the Abacus
  tensor-contraction path for more than one extra coordinate axis.
- Automatic date/cadence conversion: callers supply a one-dimensional fitted
  numeric HSGP coordinate. Phase 31's date-index primitive remains separate.
- New dependencies, dashboard/UI, AI advisor, VI, benchmark work, or any
  change to the HSGP/TVP ledger status.

## Numerical Contract

For finite non-empty training coordinates x_training, supplied sqrt_psd, and
supplied standard-normal coefficient values z:

1. State records training_centre = minimum(x_training) / 2 +
   maximum(x_training) / 2, matching Phase 32's range-midpoint basis centre.
   It records retained-mode settings from m, L, and drop_first.
2. State constructs an un-demeaned training basis at that fixed centre. When
   demeaned_basis = true, it records basis_offset =
   mean(phi_training_raw; dims = 1) and uses phi_training_raw - basis_offset;
   otherwise it applies no offset.
3. State computes and defensively materialises weighted_coefficients =
   sqrt_psd .* z, then computes raw_training =
   softplus(phi_training * weighted_coefficients) and training_raw_mean =
   mean(raw_training; dims = 1). Every raw entry and denominator must be finite
   and strictly positive before construction succeeds. The state must not retain
   caller-owned sqrt_psd or z arrays, or expose mutable internal snapshots:
   neither caller mutation nor state-field mutation can pair a stored denominator
   with a changed numerator.
4. Replay builds a raw basis at the stored training centre, applies the stored
   training offset where present, evaluates stored weighted coefficients,
   applies Phase 33's exact thresholded softplus, checks every replay raw entry
   and final multiplier for finite strict positivity, and divides only by
   training_raw_mean.
5. Replay on x_training agrees with Phase 33's positive multiplier. Replay on
   new inputs is not renormalised to mean one over those inputs.
6. The zero-retained-mode case (m = 1, drop_first = true) yields exact 1.0
   values for both training and replay coordinates.
7. Inputs remain finite and shape-compatible under Phase 33's vector or
   m_retained x k matrix contract. State and helpers preserve AD-capable numeric
   types for sqrt_psd, z, eta, and lengthscale; no hard cast of these values to
   Float64 is allowed.
8. Do not add a prediction-domain rejection based on L. The basis equation is
   defined for finite coordinates and Abacus's continuous-new-data test
   evaluates a point slightly beyond its training-centred L interval. This
   phase provides deterministic replay, not a claim that extrapolation quality
   has been validated.

## Tasks

### Task 34-01: Contract And Fixture Design

- [x] Record this plan and resolve an independent review before builder work.
- [x] Extend scripts/export_abacus_fixtures.py with deterministic replay cases
  generated by one real Abacus SoftPlusHSGP graph with mutable PyMC Data. Build
  training geometry once, replay on new data with its saved f_mean deterministic
  replaced through deterministics_to_flat, and export its seeded coefficient
  draw as fixed Julia literals. Include:
  - an asymmetric vector case where prediction-local centring or
    renormalisation differs, with at least one finite prediction coordinate
    outside training_centre +/- L;
  - a two-series matrix case;
  - a demeaned-basis case proving the training column offset is reused; and
  - a zero-retained-mode case.
- [x] Write a new hsgp_fitted_replay_cases.jl fixture with training and
  prediction coordinates, settings, expected training centre and offset,
  expected training denominator, and expected training/replay multipliers.
- [x] Document the fixture in test/fixtures/abacus/README.md. Regeneration must
  restore unrelated generated fixture churn before commit.

### Task 34-02: Private Fitted-State Helpers

- [x] Add _HSGPPositiveMultiplierState,
  _fit_hsgp_positive_multiplier_state, and
  _hsgp_replay_positive_multiplier to src/mmm/hsgp.jl, plus the narrow
  fixed-centre basis helper they require.
- [x] Keep _hsgp_basis_matrix behaviour unchanged. It may delegate only if its
  Phase 32 centring and de-meaning output remains exactly unchanged.
- [x] Store immutable, freshly allocated weighted-coefficient, basis-offset,
  and denominator snapshots in state; do not store or expose caller-owned
  mutable arrays, and give replay no replacement values.
- [x] Fail with ArgumentError for invalid training inputs, mismatched modes,
  non-finite values, non-positive raw training values/means, non-positive
  replay raw values, non-finite replay multipliers, or malformed private state.
  Do not permit NaN, Inf, or prediction-local normalisation.
- [x] Do not modify src/Epsilon.jl, seasonality/config validation, model
  builders, inference, prediction/replay APIs, serialization, or public
  exports.

### Task 34-03: Evidence And Closure

- [x] Add and register test/model/hsgp_fitted_replay.jl.
- [x] Assert fixture parity for valid training and replay cases; compare state
  centre, offset, and denominator as well as final values.
- [x] Assert deliberately prediction-recentred and prediction-renormalised
  results differ from the asymmetric fixture case.
- [x] Assert training replay equals Phase 33 and zero mode returns exact ones.
- [x] Assert mutation of the original sqrt_psd and z arrays after state fitting
  does not change replay values, proving the denominator cannot be paired with
  an altered numerator.
- [x] Assert internal weighted-coefficient, basis-offset, and denominator state
  snapshots cannot be mutated in place.
- [x] Add finite/shape/underflow error tests, including a valid training state
  whose prediction-only softplus underflows, and ForwardDiff gradient smoke
  tests through z, eta, and lengthscale across fit plus replay.
- [x] Assert helpers remain private and seasonality.type = "hsgp" remains
  rejected.
- [x] Update plan, changelog, roadmap, state, and parity ledger conservatively;
  the HSGP/TVP row stays missing.
- [x] Run focused tests and targeted Runic during iteration. Run exactly one
  full suite only at phase closure because model runtests registration changes.

## Acceptance Criteria

- Private state reproduces Phase 33 on training inputs and fixture-backed
  PyMC/PyTensor values on prediction inputs without recentering or
  renormalising prediction data.
- Demeaned-basis replay reuses the training column offset.
- State cannot mix a stored denominator with mutated, replacement, or exposed
  mutable weights or coefficients.
- Vector/matrix cases, zero modes, invalid domains, and AD propagation have
  focused coverage.
- No public/config/model/inference/panel/serialization surface changes.
- The HSGP/time-varying ledger row remains missing.

## Verification

    PYTHONNOUSERSITE=1 python scripts/export_abacus_fixtures.py
    python -m py_compile scripts/export_abacus_fixtures.py
    make test-file FILE=test/model/hsgp_fitted_replay.jl
    julia --project=@runic -m Runic --check --diff src/mmm/hsgp.jl test/model/hsgp_fitted_replay.jl test/model/runtests.jl
    git diff --check
    test -z "$(git diff --name-only -- Project.toml Manifest.toml)"
    # Final checkpoint only, after implementation review:
    make test

## Risks

| Risk | Mitigation |
|---|---|
| Prediction basis silently recentres | Store and fixture-assert training range midpoint; use it for every replay basis. |
| Demeaned basis shifts at prediction time | Store training column offset and assert prediction-local offset differs. |
| Denominator paired with another posterior draw | State owns immutable snapshots; replay takes coordinates only. |
| Extrapolation restriction invents incompatible semantics | Permit finite coordinates and state the lack of extrapolation-quality claims. |
| Pure replay is misrepresented as support | Keep helpers private, config rejected, ledger missing, and model surfaces untouched. |

## Review Questions

1. Is a per-concrete-draw private state the correct boundary, or is there a
   hidden requirement to support posterior-array batches before model design?
2. Does the fixture strategy provide honest Abacus evidence without claiming
   PyMC graph-lifecycle equivalence?
3. Are stored centre, de-meaning offset, and denominator sufficient to prevent
   fitted-state discontinuity in the bounded vector/matrix case?
4. Are any exclusions too narrow or too broad for a pure replay foundation?

## Review Notes

- Initial independent review found three Must Fix issues: retaining mutable
  caller arrays could pair an old denominator with a changed numerator;
  prediction-only Float64 softplus underflow was not guarded; and PyMC-geometry
  fixtures alone would not prove Abacus's retained mutable-data replay path.
  The numerical contract, fixture task, state ownership rule, and test matrix
  above now require defensive weighted-coefficient snapshots, replay-time raw
  validation, and one actual Abacus SoftPlusHSGP mutable-data graph. A short
  re-review is required before builder approval.
- The amended plan was re-reviewed and approved for builder implementation with
  no remaining Must Fix findings. The reviewer confirmed that the defensive
  snapshot, replay-time validation, mutable-data graph fixture, outside-L case,
  and retained-mode terminology close the identified contract gaps.
- Implementation review then found that copied arrays stored in the private
  state were still externally mutable through its fields. The implementation
  must use immutable snapshots for weighted coefficients, offsets, and
  denominators, with direct state-mutation regression coverage, before it can
  be approved or closed.
- Remediation review found one further malformed-private-state path: metadata
  could claim a narrower coefficient element type than the immutable tuple
  actually held, causing silent coercion during replay. Validation now checks
  every tuple element against its recorded type before materialising a fresh
  local array. The re-review approved the corrected implementation. Focused
  verification passed `58 / 58` in `10.4s`; fixture regeneration was
  byte-stable, Runic passed, and diff/dependency scope guards passed.
