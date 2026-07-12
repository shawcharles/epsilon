# Phase 35: Time-Series HSGP Media Methodology Contract

## Status

Closed. This planning-only phase created and independently reviewed the binding
design for Phase 36; it does not modify runtime source, tests, exports,
configuration acceptance, or dependencies.

## Objective

Resolve the methodological and software contract required before Epsilon puts a
sampled HSGP positive multiplier into the TimeSeriesMMM likelihood. Phases
31-34 established the private deterministic ingredients. The next step cannot
be another helper: it must decide model placement, temporal units, priors,
posterior replay, serialisation, and compatibility boundaries before any Turing
model code is written.

## Reference Boundary

The contract is grounded in the local Abacus checkout:

- abacus/mmm/models/panel_build.py builds baseline channel contributions and,
  when default time_varying_media is true, multiplies those contributions by one
  SoftPlusHSGP process before summing channels.
- abacus/mmm/tvp.py creates a SoftPlusHSGP with an Exponential amplitude prior,
  an inverse-gamma lengthscale prior, and the HSGP configuration.
- abacus/mmm/hsgp.py stores the training softplus mean and replaces that
  deterministic during prediction so the multiplier remains continuous.
- Epsilon src/mmm/model.jl currently computes media_effect by summing
  transformed media times beta_media, then rebuilds a Turing model for predict.
  A correct implementation must preserve the HSGP training geometry within
  that rebuild.

## Binding Decisions For The Later Implementation

1. First supported placement is TimeSeriesMMM media only. It is a shared
   time-indexed positive multiplier applied to every channel's baseline
   contribution before channel summation. It is not a channel-specific process.
   The initial path explicitly rejects Michaelis-Menten saturation, because
   that path embeds amplitude in alpha_saturation rather than beta_media; it is
   not silently forced through beta_media algebra.
2. Time-varying intercepts, PanelMMM, and multidimensional coefficient tensors
   remain excluded. They have different identifiability and coordinate
   contracts.
3. The first public entry point will be an explicit typed programmatic
   TimeVaryingMediaConfig. YAML/pipeline acceptance remains deferred until the
   model, prediction, serialisation, and error contracts have landed.
4. TimeVaryingMediaConfig requires explicit m, L, time_resolution,
   covariance, eta_prior, and lengthscale_prior. There are no implicit
   convenience defaults for m, L, or priors. It fixes drop_first = false and
   demeaned_basis = false in the first path, matching Abacus's default shared
   boolean media route; neither is configurable yet.
5. The multiplier uses a non-centred retained-mode coefficient vector
   z ~ Normal(0, 1). The runtime obtains sqrt_psd from sampled eta and
   lengthscale, then applies the existing private positive-multiplier machinery.
6. Epsilon will not claim literal Abacus default-prior parity in this slice:
   its current public prior mapper has no InverseGamma support. eta_prior and
   lengthscale_prior must each be scalar, dimensionless EpsilonPrior values of
   class Exponential, Gamma, HalfNormal, or LogNormal, with parameters accepted
   by instantiate_distribution and positive support. No vector, matrix, dims,
   masked, hierarchical, or arbitrary distribution recipe is accepted. Abacus
   default-prior parity is a separate future decision.
7. Temporal coordinates are integer cadence indices. The configuration's
   required positive time_resolution is measured in days and Phase 31 converts
   training/new dates relative to the first training date. m, L, and
   lengthscale are in those cadence-index units.
8. The first model declares scalar parameters hsgp_media_eta and
   hsgp_media_lengthscale plus a non-centred vector hsgp_media_z of exact length
   m, using the same names and distribution statements in fit, prior-predict,
   and predict rebuilds. Turing.predict must therefore consume fitted chain
   values rather than resample this latent path.
9. Fit validates Date-valued training dates and computes the cadence index by
   applying Phase 31's helper to the complete training date vector relative to
   itself. An unfitted prior_predict uses model.data as that training origin
   and evaluates new_data only as the prediction grid. Fitted predict uses the
   stored training grid. In both cases, every new date must be cadence-aligned.
10. ModelConfig owns TimeVaryingMediaConfig. MMMModelSpec owns an immutable
   HSGPTimeSeriesTrainingState containing training_origin::Date,
   time_resolution::Int, an immutable Tuple{Vararg{Int}} training-index
   snapshot, and its range-midpoint basis centre. The state also records m, L,
   covariance, drop_first = false, and demeaned_basis = false, so loaded or
   rebuilt prediction maps future dates from retained fitted state rather than
   mutable current model data or configuration.
11. For each posterior draw, the predictive model recomputes the denominator
   on the stored training coordinates from that draw's eta, lengthscale, and z,
   then evaluates the numerator on new coordinates. It never normalises
   prediction coordinates independently or stores one mutable denominator
   summary.
12. Model serialisation is required. New HSGP-capable payloads use schema
   version 2 and persist typed configuration plus HSGPTimeSeriesTrainingState
   through the model spec and fit artefact. Version-1 payloads migrate to
   explicit nothing HSGP fields and retain their existing no-HSGP behaviour;
   incomplete HSGP state fails closed. Save/load/new-date predict must agree
   with the pre-save fitted model for fixed chain draws.
13. TimeSeries calibration combined with time-varying media is rejected in the
    initial integration phase. Existing calibration terms deliberately describe
    saturation-only or precomputed cost semantics and do not yet establish the
    interaction with a temporal media multiplier.

## Proposed Later Implementation Boundary

The successor implementation phase may touch only:

- src/mmm/hsgp.jl for typed configuration validation and pure runtime helpers;
- src/model/builder.jl for TimeSeriesMMM and MMMModelSpec state ownership;
- src/mmm/model.jl for Turing sampling, likelihood placement, fit, prior
  prediction, and posterior prediction threading;
- src/model/io.jl for schema version 2, version-1 migration, and HSGP state
  serialisation guards;
- src/Epsilon.jl and docs only for the intentional typed public configuration;
- focused model, serialisation, and API tests plus generated Abacus fixtures.

It must not add PanelMMM, intercept variation, channel-specific multipliers,
YAML/pipeline support, free-form prior mappings, VI, dashboards, or AI advisor
work.

## Required Evidence For The Later Implementation

- A real Abacus PanelMMM placement fixture using default shared time-varying
  media, exported with a fixed coefficient/hyperparameter draw where possible,
  proving that the multiplier is applied before channel summation. It is
  placement evidence, not a TimeSeriesMMM product-parity claim.
- Fixed-draw checks that separately compare the HSGP multiplier to Abacus,
  the TimeSeriesMMM media likelihood to a manual Epsilon calculation, and
  each Epsilon-native eta/lengthscale prior density to its own instantiated
  distribution. Do not compare an aggregate log joint to Abacus.
- A training-grid prediction test proving the model path agrees with the
  private Phase 34 replay result for the same posterior draw.
- A new-date prediction test proving the rebuild uses training, not prediction,
  centring and denominator state.
- Explicit rejection tests for PanelMMM, time-varying intercept, channel-specific
  dimensions, Michaelis-Menten saturation, malformed/dimensioned priors,
  unsupported covariance, non-Date or misaligned training/prediction dates,
  and any calibration payload at construction, fit, and load boundaries.
- One small MCMC smoke test that observes non-centred HSGP coefficient,
  amplitude, and lengthscale parameters in the chain. It is evidence of model
  construction, not a convergence or benchmark claim.

## Tasks

### Task 35-01: Source And Prior Audit

- [x] Verify exact Abacus shared-media placement, time-index preparation,
  default HSGP hyperprior semantics, and prediction replacement lifecycle.
- [x] Verify Epsilon's present prior mapper and model-spec serialisation limits.
- [x] Record why inverse-gamma default-prior parity is deferred rather than
  silently approximated.

### Task 35-02: Integration Contract

- [x] Record the binding decisions above in an implementation-ready
  contract with exact source ownership and no unresolved default values.
- [x] Define the later typed programmatic configuration fields, scalar positive
  prior whitelist, fixed geometry switches, validation rules, and all explicit
  rejections.
- [x] Define the model algebra for supported non-Michaelis-Menten paths:
  baseline_channel[t, channel] = transformed_media[t, channel] *
  beta_media[channel]; media_effect[t] =
  sum(baseline_channel[t, :] * multiplier[t]); reject the distinct
  Michaelis-Menten amplitude path.
- [x] Define exact parameter names/shapes and fit, unfitted prior-predict,
  fitted predict, immutable training-origin/cadence/index state, model-spec,
  schema-version, legacy-migration, serialisation, and posterior-draw
  denominator ownership.
- [x] Define the fixture and conditioned-log-joint acceptance strategy.

### Task 35-03: Independent Review And Closure

- [x] Obtain an independent review focused on identifiability, units, prior
  semantics, prediction state, calibration interaction, and scope.
- [x] Resolve every Must Fix before declaring the successor implementation
  builder-ready.
- [x] Update roadmap and state to identify Phase 36, not Phase 35, as the
  next implementation step. Keep HSGP/TVP ledger status missing.

## Acceptance Criteria

- The successor can be implemented without deciding m, L, cadence, prior
  whitelist, geometry switches, parameter names/shapes, multiplier placement,
  schema migration, or prediction-state rules ad hoc.
- Every claimed Abacus comparison is identified as either exact placement and
  replay parity, or an explicit Epsilon-native deviation.
- The design gives a safe TimeSeriesMMM-only model route and clear rejection
  boundaries for every wider surface.
- No runtime source, tests, exports, YAML acceptance, or dependencies change
  in this phase.

## Verification

    git diff --check
    test -z "$(git diff --name-only -- src test Project.toml Manifest.toml)"
    rg -n "Phase 35|TimeSeries HSGP" .planning/ROADMAP.md .planning/STATE.md

## Risks

| Risk | Mitigation |
|---|---|
| Treating HSGP as seasonality, an intercept effect, or Michaelis-Menten beta | Bind placement to shared non-Michaelis-Menten media contributions only. |
| Giving cadence-dependent hyperparameters misleading defaults | Require explicit m, L, time_resolution, and priors. |
| Pretending Epsilon has Abacus inverse-gamma default-prior parity | Restrict initial priors to honestly supported positive families. |
| Incorrect prediction from a rebuilt Turing model | Carry training time state and recompute per-draw denominator on that grid. |
| Calibration changes meaning silently | Reject its combination until a separate likelihood contract exists. |
| Scope expands into panel or channel-specific tensor semantics | Reject them explicitly and keep the ledger row missing. |

## Review Questions

1. Is a shared multiplier across all time-series non-Michaelis-Menten media
   channels the smallest
   meaningful first placement and faithful to Abacus's default boolean path?
2. Is requiring explicit priors and cadence parameters preferable to inventing
   unstable defaults while inverse-gamma support remains absent?
3. Does recomputing the per-draw denominator from posterior parameters and
   retained training state fully close prediction replay for the bounded path?
4. Are calibration rejection, schema version 2 migration, and exclusion of public YAML acceptance the right
   safety boundaries for the first model integration?

## Review Notes

- Initial independent review found five Must Fix issues: Michaelis-Menten did
  not fit the beta_media algebra; geometry switches and state ownership were
  not frozen; fit/prior-predict/predict parameter identity was incomplete;
  the prior whitelist and evidence claims were undecided; and serialisation was
  treated as optional. The contract now explicitly rejects Michaelis-Menten,
  fixes drop_first/demeaned_basis, names scalar Turing parameters and their
  lifecycle, whitelists scalar Epsilon-native positive priors, separates
  Epsilon likelihood/prior checks from Abacus multiplier placement evidence,
  and requires schema version 2 plus version-1 migration. Re-review is
  required before closure.
- Re-review required HSGPTimeSeriesTrainingState to retain the fitted Date
  origin, cadence, and an immutable integer-index snapshot in addition to basis
  geometry. Without these, a loaded model could not map a new Date to its
  original coordinate system. That requirement is now binding; final re-review
  is required before closure.
- Final re-review approved closure with no remaining Must Fix items and
  declared Phase 36 builder-ready under this frozen contract.
