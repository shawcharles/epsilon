# Phase 36: Time-Series HSGP Shared Media Multiplier

## Status

Tasks 36-01 through 36-03 are landed and independently reviewed on 2026-07-12.
Task 36-04 remains before Phase 36 closure.

## Objective

Implement the Phase 35 contract as the first model-facing HSGP capability:
a TimeSeriesMMM-only, shared, strictly positive, mean-one temporal multiplier
applied after per-channel media contributions and before their sum. The feature
is intentionally narrow but complete within that boundary: typed programmatic
configuration, NUTS sampling, prior prediction, posterior prediction on new
cadence-aligned dates, model save/load, and explicit rejection of all wider
surfaces.

## Frozen Contract

Phase 35 is binding. In particular:

- Supported model: TimeSeriesMMM with MCMC/NUTS only.
- Supported placement: one shared time multiplier multiplied into every
  post-transform, beta-weighted channel contribution before channel summation.
- Rejected: PanelMMM, time-varying intercepts, channel-specific multipliers,
  multidimensional HSGP coefficients, periodic HSGP, YAML/pipeline acceptance,
  VI, calibration, and Michaelis-Menten saturation.
- Configuration has explicit m, L, time_resolution, covariance, eta_prior, and
  lengthscale_prior. It fixes drop_first = false and demeaned_basis = false.
- Eta and lengthscale priors are scalar, dimensionless EpsilonPrior values of
  Exponential, Gamma, HalfNormal, or LogNormal only. InverseGamma is not
  accepted and no Abacus default-prior parity is claimed.
- HSGP coordinates are integer cadence indices. m, L, and lengthscale are in
  cadence-index units.
- Turing variables are exactly hsgp_media_eta, hsgp_media_lengthscale, and
  hsgp_media_z, where z is a non-centred vector of length m.

## Architecture

### Public Programmatic Configuration

Define and export TimeVaryingMediaConfig in src/model/types.jl. It carries:

- m::Int, at least one;
- L::Float64, finite and positive;
- time_resolution::Int, positive days;
- covariance::Symbol, one of expquad, matern32, matern52;
- eta_prior::EpsilonPrior and lengthscale_prior::EpsilonPrior;
- no configurable drop_first or demeaned_basis fields in this phase.

The public ModelConfig constructor gains a
time_varying_media::Union{Nothing, TimeVaryingMediaConfig} keyword. To preserve
the concrete ModelConfig layout embedded in version-1 artifacts, the constructor
stores a validated typed snapshot at extras["time_varying_media"]. It rejects an
ambiguous extras entry plus keyword. The existing ModelConfig struct itself does
not gain a field.

The YAML parser must reject both a merged top-level time_varying_media key and
media.time_varying_media with an explicit programmatic-only error. The check
runs after defaults and overrides merge but before extras extraction, so direct
YAML, defaults, and overrides cannot create an inert HSGP configuration. Neither
spelling may survive as an unknown extra.

### Immutable Spec State

Do not add fields to MMMModelSpec. Existing artifacts deserialize before a loader
can inspect a schema marker, so changing that public concrete struct risks
breaking old binary payloads.

Instead, model-spec construction creates private immutable structs:

- _HSGPTimeSeriesTrainingState:
  training_origin::Date, time_resolution::Int,
  training_indices::Tuple{Vararg{Int}}, training_centre::Float64,
  m::Int, L::Float64, covariance::Symbol, drop_first::Bool,
  demeaned_basis::Bool.
- _HSGPMediaPriorSnapshot: an immutable, scalar-only representation of the
  whitelisted prior family and validated numeric parameters.
- _HSGPMediaConfigSnapshot: the immutable scalar HSGP configuration plus the
  two prior snapshots.
- _HSGPMediaSpecState: the immutable config snapshot plus the training state.

Store the latter only under the reserved private key
"_hsgp_media_spec_state" in MMMModelSpec.priors. Existing prior lookup functions
must ignore this key. Runtime code instantiates fresh distributions from the
private snapshots; it must never retain an EpsilonPrior or its mutable
parameters dictionary. The state is copied by existing spec/artifact workflows
without changing MMMModelSpec layout.

Tests must mutate the source TimeVaryingMediaConfig and its prior parameter
dictionaries after fit, then prove fixed-chain prediction is unchanged. This is
a lifecycle contract, not a cosmetic immutability claim.

Build this state only from a TimeSeriesMMM training data vector of Date values.
Validate every training date through the Phase 31 cadence-index helper relative
to the fitted training origin. HSGP configuration with integer/non-Date dates
fails clearly without changing generic MMMData support.

### Runtime And Turing Model

Refactor TimeSeriesMMM fit so it builds the model spec first and uses
_turing_runtime(spec, data) as the canonical runtime path. The spec runtime
resolves the private state bundle, maps the current data dates against retained
training origin/cadence, and exposes immutable training and prediction index
arrays plus validated scalar priors.

When HSGP media is disabled, preserve the existing byte-for-byte media path.

When enabled:

1. Sample hsgp_media_eta from eta_prior.
2. Sample hsgp_media_lengthscale from lengthscale_prior.
3. Sample hsgp_media_z from a standard-Normal fill distribution of length m.
4. Form sqrt PSD from the existing private HSGP helper.
5. Evaluate the existing private fixed-centre basis on both retained training
   indices and current prediction indices, with the frozen geometry flags.
6. Compute the positive multiplier denominator only on retained training
   indices, then divide current raw softplus values by that denominator.
7. Form baseline_channel = transformed_media .* beta_media across the channel
   axis, multiply each row by the shared multiplier, and sum channels to obtain
   media_effect.

The model must declare the same HSGP variables and distribution statements in
fit, unfitted prior prediction, and fitted posterior-predictive rebuilds. It
must not branch around latent-variable declarations. Turing.predict therefore
consumes the fitted chain parameters rather than resampling a different process.

The existing Michaelis-Menten route is rejected before model creation whenever
HSGP media is configured. Existing calibration payloads are rejected at
TimeSeriesMMM construction, fit, and load. PanelMMM and approximate_fit!
reject any HSGP-media configuration explicitly before their runtime/model paths.

### Prediction Lifecycle

- Fit: derive a state bundle from model.data, persist it inside the model spec
  and fit artifact, and sample the HSGP variables.
- Unfitted prior_predict: derive the state bundle from model.data, then map
  new_data dates against that fitted origin and cadence. It never uses new_data
  to define training geometry.
- Fitted predict and fitted prior_predict: use artifact.spec's private state
  bundle, never mutable model.config extras or model.data.
- For every posterior draw, recompute the training-grid denominator from that
  draw's eta, lengthscale, and z; no single mutable or posterior-averaged
  denominator is stored.
- New dates may precede or follow training dates but must be cadence-aligned.

### Model Payload Versioning

Keep _MODEL_IO_SCHEMA_VERSION unchanged because it is shared by model, result,
and inference payload families.

Add a model_payload_schema_version field to TimeSeriesMMM and PanelMMM model
payloads. Newly written model payloads use value 2 while their existing
metadata/schema fields remain unchanged. A central private validator runs after
deserialisation and before a loaded object is returned or assigned any fitted
state. It admits exactly this v2 HSGP state matrix:

- configured but unfitted: typed configuration is present and no private spec
  state is present;
- built but unfitted: typed configuration and a matching validated private spec
  state are present;
- fitted: typed configuration, matching validated private spec state, and
  matching fitted-artifact spec state are present.

The model loader otherwise accepts:

- legacy model payloads without model_payload_schema_version as v1, only when
  no HSGP media state is present;
- v2 payloads with validated config/spec HSGP state pairing;
- no other model payload version.

Because ModelConfig and MMMModelSpec layouts remain unchanged, v1 payloads can
deserialize before migration. The v1 path fills no HSGP state and preserves
existing behaviour. A v2 HSGP model with absent, malformed, or mismatched
private spec state fails closed. This is validation of well-formed, trusted
local Julia Serialization artifacts only: deserialisation executes before this
validator, so model files are not an untrusted interchange format. Compatibility
is supported only within the compatible Epsilon and Julia runtime range already
enforced by package metadata.

Result and inference-result payload schemas do not change, but their loaders
must invoke the same private HSGP-state validator on embedded specs before
returning an object. This prevents a corrupt embedded state from bypassing the
model loader.

### Unsupported Postmodel Surfaces

The existing contribution, decomposition, response-curve, saturation-curve,
and metric routines assume stationary media contributions. Phase 36 does not
silently reuse those formulas for HSGP results. It adds a single private
capability guard at their common replay/curve entry points that rejects HSGP
media results with a clear `ArgumentError` explaining that postmodel reporting
is deferred. The guard must cover public aliases, including decomposition and
metric routes, and is tested at each public entry point. Phase 36 therefore
keeps model fit/prediction correct without claiming postmodel parity it has not
implemented.

Save/load acceptance must prove fixed-chain new-date posterior prediction
matches before and after serialization.

## File Ownership

Implementation may modify only:

- src/model/types.jl
- src/model/config.jl
- src/mmm/hsgp.jl
- src/model/builder.jl
- src/mmm/model.jl
- src/model/io.jl
- src/model/results.jl
- src/inference/results.jl
- src/inference/vi.jl
- src/postmodel/replay.jl
- src/postmodel/response_curves.jl
- src/Epsilon.jl
- docs/src/api.md
- scripts/export_abacus_fixtures.py
- test/fixtures/abacus/README.md
- test/fixtures/abacus/hsgp_time_varying_media_cases.jl
- test/model/config.jl
- test/model/builder.jl
- test/model/time_varying_media.jl
- test/model/io.jl
- test/model/results.jl
- test/inference/results.jl
- test/postmodel/contributions.jl
- test/postmodel/response_curves.jl
- test/postmodel/metrics.jl
- test/model/runtests.jl
- test/api_exports.jl
- .planning/API-EXPORT-TRIAGE.md
- planning, ledger, roadmap, state, changelog, and ignored Three Man Team
  handoffs at closeout.

Do not change Project.toml, Manifest.toml, PanelMMM runtime/model code,
pipeline runtime/config, public postmodel API signatures, or broader
result/inference schemas.

## Tasks

### Task 36-01: Typed Configuration And State Boundary

**Status:** Landed. This establishes the public configuration, immutable
private state, and rejection boundary only; no Turing HSGP runtime exists until
Task 36-03.

- Add TimeVaryingMediaConfig with docstring, validation, equality, scalar-prior
  whitelist, and intentional export. Add its API inventory/triage row, an
  `@docs` entry on the existing API page, and export/doc tests.
- Add the ModelConfig programmatic keyword and extras snapshot route without
  changing ModelConfig layout. Reject extras/keyword ambiguity.
- Reject both time_varying_media YAML spellings after merge, PanelMMM, VI,
  calibration combinations,
  Michaelis-Menten, malformed priors, non-Date data, and invalid cadence.
- Add private immutable training/spec state structures and install the state
  bundle in the reserved MMMModelSpec.priors key. Convert mutable public priors
  to immutable scalar snapshots; reconstruct distributions only from snapshots.
- Test type/config construction, private-key integrity, API inventory/docs,
  YAML rejection, source-config mutation immunity, and all unsupported-surface
  rejections.

### Task 36-02: Fixture And Pure Runtime Evidence

**Status:** Landed. The Abacus fixture proves only the explicitly enabled
PanelMMM boolean-path placement; Epsilon's distinct range-midpoint multiplier
replay is validated separately against the Phase 34 oracle. No Turing runtime
has been introduced.

- Extend the fixture exporter using a real Abacus PanelMMM graph with the
  boolean time_varying_media path explicitly enabled and its internal TVP
  configuration default-derived, with a fixed seed. Export baseline per-channel
  contribution, shared multiplier, and final channel contribution values as
  placement evidence only.
- Add pure HSGP runtime helpers that construct the shared multiplier from
  retained training state, current indices, eta, lengthscale, and z without
  Float64-casting sampled values.
- Assert fixed-draw multiplier parity against the existing Phase 34 oracle and
  the new placement identity baseline_channel .* multiplier.
- Assert Epsilon media likelihood against a manual Epsilon Normal likelihood.
  Assert Epsilon-native eta/lengthscale prior log densities against their own
  instantiated distributions. Do not compare an aggregate log joint to Abacus.
- Add a ForwardDiff smoke test through the pure runtime helper to demonstrate
  that eta/lengthscale remain dual-compatible and no Float64 conversion leaks
  into the model path.

### Task 36-03: Turing, Fit, And Prediction Threading

**Status:** Landed. The TimeSeries MCMC path now resolves HSGP runtime state
from the immutable spec, declares the frozen non-centred latent variables, and
threads them through fit and prediction. Focused evidence covers retained-grid
new-date replay, fixed-chain `Turing.predict` consumption of eta, lengthscale,
and z, mutable-config boundary hardening, and a small NUTS wiring smoke. This
does not close serialisation, postmodel, documentation, or the phase checkpoint.

- Refactor fit to construct the spec before runtime resolution and use the spec
  as runtime authority.
- Add the named non-centred HSGP variables and contribution placement to
  _time_series_mmm_model while preserving the unconfigured path.
- Thread state through fit, unfitted prior_predict, fitted prior_predict, and
  predict. Ensure Turing.predict has identical HSGP variable statements.
- Add a conditioned DynamicPPL test that fixes hsgp_media_eta,
  hsgp_media_lengthscale, hsgp_media_z, beta_media, and every remaining sampled
  variable required by the model. Compare both Epsilon's returned media effect
  and Epsilon's own conditioned log joint against a manually separated
  multiplier, media-likelihood, and prior calculation. Do not compare an
  aggregate Abacus log joint.
- Add fixed-draw Turing tests for media effect, training-grid replay, and
  new-date replay that would fail under prediction-local centring or
  normalisation.
- Add one small seeded NUTS smoke test confirming all three HSGP parameter
  groups occur in the chain. It is not a convergence or benchmark claim.

### Task 36-04: Model Payload Compatibility And Closure

- Add model-payload-v2 writing/loading and the central post-deserialisation
  state-matrix validator without changing shared result/inference schemas.
- Test v1 no-HSGP payload loading, v2 HSGP round trip, malformed/missing HSGP
  state rejection, all configured/built/fitted state-matrix cases, mutation
  immunity, and pre/post-save fixed-chain new-date prediction equality.
- Invoke the same validator from result and inference-result loaders; test that
  malformed embedded HSGP state is rejected there as well.
- Add and test the central HSGP postmodel guard across contribution,
  decomposition, response, saturation, and metric public routes.
- Update docs with the programmatic-only configuration and every explicit
  limitation. Do not document YAML support.
- Update changelog, state, roadmap, and parity ledger without promoting the
  HSGP/TVP row above missing.
- Run focused tests during iteration. Run exactly one full suite at phase
  closure because exports, model test registration, and serialized-model
  behaviour change.

## Acceptance Criteria

- A typed TimeVaryingMediaConfig activates only the bounded TimeSeriesMMM MCMC
  shared-media multiplier.
- The multiplier is placed after each supported channel contribution and before
  channel summation.
- Fit, unfitted prior prediction, fitted prior prediction, and posterior
  prediction use retained training date/cadence/geometry state and the same
  Turing parameter identity.
- Model save/load preserves fixed-chain new-date predictions.
- Model, result, and inference-result loaders reject invalid embedded HSGP
  state after trusted-local deserialisation.
- All wider surfaces reject clearly and HSGP/TVP ledger status remains missing.
- Every fixture/backed claim distinguishes Abacus PanelMMM placement evidence
  from Epsilon TimeSeriesMMM model evidence.
- HSGP result postmodel reporting rejects rather than silently omitting the
  multiplier.
- No change to dependency files, panels, pipeline, VI semantics, public
  postmodel signatures, or broader serialization formats.

## Verification

    PYTHONNOUSERSITE=1 python scripts/export_abacus_fixtures.py
    python -m py_compile scripts/export_abacus_fixtures.py
    make test-file FILE=test/model/time_varying_media.jl
    make test-file FILE=test/model/config.jl
    make test-file FILE=test/model/io.jl
    make test-file FILE=test/model/results.jl
    make test-file FILE=test/inference/results.jl
    make test-file FILE=test/postmodel/contributions.jl
    make test-file FILE=test/postmodel/response_curves.jl
    make test-file FILE=test/api_exports.jl
    julia --project=@runic -m Runic --check --diff <all-touched-julia-files>
    git diff --check
    test -z "$(git diff --name-only -- Project.toml Manifest.toml)"
    # Final checkpoint only after implementation review:
    make test

## Risks

| Risk | Mitigation |
|---|---|
| Old model artifacts fail before schema migration runs | Keep concrete ModelConfig/MMMModelSpec layouts unchanged and use a model-only payload discriminator. |
| Turing predict samples a different HSGP path | Freeze names/shapes/statements and test chain consumption on training and new dates. |
| Prediction recovers geometry from mutable current inputs | Persist immutable state in spec and test config/data drift immunity. |
| Mutable public priors alter persisted semantics | Snapshot scalar prior family/parameters privately and prove post-fit public mutation cannot change replay. |
| Abacus evidence overstates parity | Label fixture as PanelMMM placement evidence; separately test Epsilon likelihood and priors. |
| Priors have unsupported/dimensional semantics | Whitelist scalar dimensionless positive EpsilonPrior classes. |
| New support leaks into panel, YAML, calibration, or VI | Reject at constructor/config, fit, prediction, load, and backend boundaries. |
| Existing postmodel outputs omit the multiplier | Reject every affected contribution/decomposition/curve/metric entry point until a separately designed postmodel phase. |
| Invalid state enters via result artifacts | Validate embedded HSGP specs in model, result, and inference-result loaders. |
| Serialization validation is mistaken for file security | Document Julia Serialization artifacts as trusted-local only; validation occurs after deserialisation. |

## Review Questions

1. Does the typed-extras plus reserved private spec-state route preserve version-1
   model payload deserialisation without weakening the frozen state contract?
2. Does the state matrix and shared embedded-spec validator cover configured,
   built, fitted, model, result, and inference-result lifecycle states without
   claiming untrusted-file safety?
3. Does the specified latent-variable identity cover every Turing lifecycle,
   including unfitted prior prediction and Turing.predict?
4. Is the fixture/manual-likelihood split and conditioned DynamicPPL test
   sufficiently honest about Abacus placement evidence versus Epsilon-native
   priors and log-joint behaviour?

## Review Notes

Two independent pre-implementation reviews cleared this plan on 2026-07-12:

- Numerical/Turing review approved latent-variable identity, conditioned-log-
  joint evidence, AD coverage, the immutable replay contract, and postmodel
  guard placement.
- API/IO/security review approved post-merge YAML rejection, immutable scalar
  snapshots, the trusted-local serialisation boundary, API evidence, and the
  configured/built/fitted state-matrix validator.

No Turing integration begins until this reviewed plan is the builder's working
contract.
