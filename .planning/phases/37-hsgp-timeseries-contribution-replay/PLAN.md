# Phase 37: HSGP Time-Series Contribution Replay

## Status

Landed on 2026-07-12 against the independently approved plan. Independent
implementation review found no Must Fix or Should Fix items. Scoped
verification passed, followed by the one phase-closing `make check-full` gate:
`10,055 / 10,055` tests in `23m12.7s` and a successful docs build.

## Objective

Make the bounded Phase 36 `TimeSeriesMMM` HSGP media fit interpretable on its
fitted training grid by replaying posterior draw-level HSGP-adjusted channel
contributions and the existing decomposition. This is not generic HSGP/TVP
support and does not reopen forward-looking curves or metrics.

## Frozen Contract

- Supported input: grouped posterior `InferenceResults` from the bounded,
  programmatic `TimeSeriesMMM` HSGP media path, on the exact retained training
  dates and cadence.
- Supported outputs: `contribution_results` and, transitively,
  `decomposition_results` only.
- Per draw and channel, replay exactly the fitted likelihood placement:

  ```text
  scaled channel -> adstock/saturation -> beta_media[channel]
  -> shared HSGP multiplier[time] -> target unscaling
  ```

- The multiplier is reconstructed per draw from immutable
  `_HSGP_MEDIA_SPEC_STATE_KEY` state and the exact posterior parameters
  `hsgp_media_eta`, `hsgp_media_lengthscale`, and `hsgp_media_z[1:m]`.
  Its normalisation denominator is always the retained training grid.
- Media components include the shared multiplier. Do not add an independent
  HSGP component or decompose `(multiplier - 1)` from baseline media; that
  would be a normalisation-dependent interaction, not an additive model term.
- Contributions are posterior-conditional fitted-period model allocations, not
  causal incrementality, realised-target decomposition, or a forecast
  attribution surface.

## Explicit Exclusions

- `response_curve_results`, `saturation_curve_results`,
  `adstock_curve_results`, and both `metric_results` routes remain rejected.
- Panel models, prediction/new-date attribution, prior draws, ModelResults
  without grouped posterior draws, YAML/pipeline, optimisation, calibration,
  VI, Michaelis-Menten, generic HSGP, and all TVP remain unsupported.
- No public structs, exports, artifact schemas, or dependency files change.

## Architecture

1. Split the Phase 36 postmodel capability guard so it continues to reject
   HSGP curve/metric calculation routes but permits time-series contribution
   replay.
2. Add one private replay helper which returns `nothing` for stationary specs;
   otherwise it resolves `_turing_hsgp_media_runtime(spec, data)`, extracts the
   complete HSGP posterior draw, and calls `_hsgp_media_multiplier`.
   Before replay, require the current inferred cadence indices to equal the
   retained `training_indices` tuple in the same order. Reuse the existing
   model-data state validator where possible. Cadence-aligned unseen dates,
   reordered dates, and any duplicate-date sequence that differs from the
   retained tuple are invalid for this fitted-period attribution surface even
   though they may be valid prediction dates.
3. In `_replayed_contribution_values`, build one multiplier per posterior draw
   and multiply each existing per-channel media path after beta weighting and
   before target unscaling. Do not affect intercepts, controls, events,
   holidays, seasonality, or trend.
4. Leave `decomposition_results` unchanged: it consumes the corrected additive
   contribution tensor and sums it over time.
5. Guard HSGP contribution/decomposition against a results artifact whose
   observed dates differ from its retained training state. Existing HSGP
   runtime date/cadence validation remains the authority.

## Tests

Add a self-contained `test/postmodel/hsgp_contribution_replay.jl` and register
it in `test/postmodel/runtests.jl`.

- Use fixed posterior chains with exact HSGP parameter names, at least two
  media channels with distinct betas, and a non-media component.
- Compare each media-channel path against manual scaled-transform × beta ×
  retained-state multiplier × target-scale calculation for two distinct HSGP
  draws.
- Prove the full contribution sum equals the conditioned model mean in original
  target units, the same multiplier applies to every media channel, non-media
  components are unchanged, and decomposition totals equal time-summed
  contributions.
- Reject missing eta, lengthscale, or any required `z` coordinate, malformed
  state, non-Date/off-cadence dates, aligned-unseen dates, reordered dates,
  nonmatching duplicate-date sequences, and training-grid mismatch.
- Update the Phase 36 guard test: contribution/decomposition now succeed;
  response, saturation, adstock, and both metric entry routes remain rejected.
- Retain ordinary time-series and panel replay regressions.

## Documentation And Ledger

Update public limitation wording to say contribution/decomposition reports are
available only as fitted-period, posterior-conditional HSGP-adjusted model
allocations. Note that existing summary and contribution/decomposition plotting
helpers consume these now-valid result objects; they are not new replay routes.
Keep curves, metrics, and all wider HSGP/TVP surfaces unsupported.
Keep the combined HSGP/TVP ledger row `missing` and distinguish Epsilon replay
evidence from the limited Abacus PanelMMM placement fixture.

## Verification

During implementation:

```bash
make test-file FILE=test/postmodel/hsgp_contribution_replay.jl
make test-file FILE=test/postmodel/hsgp_guard.jl
make test-file FILE=test/model/time_varying_media.jl
make format-check-touched
git diff --check
test -z "$(git diff --name-only -- Project.toml Manifest.toml)"
```

After independent implementation review, run exactly one `make check-full` at
Phase 37 closure. Do not regenerate Abacus fixtures unless fixture code changes.

## Review Questions

1. Does replay exactly match the fitted post-beta/pre-channel-sum multiplier
   placement for every posterior draw?
2. Does the training-grid restriction prevent a prediction attribution API from
   slipping through the existing `InferenceResults` interface?
3. Are curve/metric rejections complete and truthful after contribution support
   is enabled?
4. Does the reporting language avoid treating HSGP interaction terms as a
   standalone additive or causal effect?
