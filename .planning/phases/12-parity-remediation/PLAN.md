# Phase 12 Plan - Parity Remediation

**Phase:** 12
**Phase Name:** Parity Remediation
**Status:** In Progress
**Last Reconciled:** 2026-04-24

## Objective

Repair the bounded time-series path so Epsilon can make honest Abacus-reference
claims where semantics truly match, while choosing the more methodologically
coherent bounded Julia design where literal upstream fidelity would be a worse
end state.

Phase 12 exists because the targeted methodology audit in
[`METHODOLOGY_AUDIT.md`](../../../METHODOLOGY_AUDIT.md) found that the current
time-series implementation is not operating in the same model space as Abacus.
The highest-impact divergence is that Epsilon fits on raw channels and raw
target, while Abacus fits on max-scaled channels and target and reconstructs
original-scale outputs explicitly. That difference propagates into posterior
parameter meaning, prior calibration, contributions, response curves, and
optimization.

Phase 12 is therefore not a feature-expansion phase. It is a remediation phase
that must:

- restore shared model-space semantics with Abacus on the bounded reference
  time-series rows where comparison remains truthful
- rebuild downstream original-scale outputs on top of that corrected contract
- realign Stage 60 and Stage 70 methodology before release work resumes
- reconcile demo/reference assets and release claims with the corrected scope,
  including the possibility that some previously claimed comparable rows become
  Epsilon-native rows instead

## Entry Conditions

Phases 1-11 have landed substantial infrastructure that Phase 12 must reuse
rather than replace:

- transform parity fixtures exist and pass
- the bounded `TimeSeriesMMM` / `PanelMMM` model, inference, post-model,
  optimization, pipeline, and plotting layers are implemented
- the final validation harness and benchmark runner exist
- the targeted methodology audit has identified the current parity blockers

Phase 12 starts from a functioning Julia package, but not from a truthful
Abacus-parity state.

## Frozen Audit Findings To Close

Phase 12 fixes these findings as first-class scope, not as optional cleanup:

1. Epsilon fits on raw unscaled channels and target while Abacus fits in
   max-scaled space.
2. Epsilon original-scale contributions are native model outputs instead of
   reconstructed outputs from a scaled model space.
3. Epsilon exposes only forward-pass response curves while Abacus exposes
   saturation-only, forward-pass, and adstock artifacts.
4. Epsilon optimization runs on interpolated response surfaces derived from the
   current replay contract instead of Abacus-style graph semantics tied to the
   corrected scaling contract.
5. The runnable Epsilon demo and holiday contract were designed around a
   misleading `prophet_component` label rather than a coherent final additive
   split between trend, seasonality, holidays, and events.
6. Public release language currently overstates how comparable the bounded
   time-series path is to Abacus.

Phase 12 should not widen scope beyond those concrete parity blockers.

## Frozen Reference Rows

Phase 12 now freezes one guaranteed Abacus-reference row and one methodology
decision row:

- `VAL-TS-00-MCMC` remains the guaranteed Abacus-reference time-series row
- `VAL-TS-04-MCMC` remains the holiday-bearing decision row, but it should only
  be described as Abacus-reference if Epsilon adopts a true compatibility mode
  with matching semantics

No other rows are promoted to Abacus-reference status in Phase 12. In
particular:

- `VAL-P-00-MCMC` remains a bounded Epsilon-only panel validation row
- `VAL-PIPE-TS-00-MCMC` remains a bounded Epsilon-only pipeline validation row
- bounded VI and plotting remain Epsilon-only validation rows

All release-facing comparison language in Phase 12 must distinguish:

- genuine Abacus-reference rows
- Epsilon-native rows that are only cross-framework reference examples

## Phase 12 Remediation Contract

Phase 12 freezes the remediation rules up front:

- Shared model-space semantics come first. No downstream comparison claim is valid
  until channel/target scaling and original-scale reconstruction are aligned.
- Phase 12 must prefer methodological coherence over preserving previously
  landed convenience behavior when the two conflict.
- Literal Abacus fidelity is required only where Epsilon intends to keep an
  Abacus-reference claim; otherwise the better bounded Julia design wins and
  docs must say so explicitly.
- Existing Phase 6-11 infrastructure should be retained where it remains
  truthful after the model-space correction.
- If a previously supported row becomes temporarily unsupported during the
  remediation, docs and tests must say so explicitly rather than silently
  preserving the old claim.
- Release preparation remains paused until the Phase 12 closeout checks pass.
- Phase 12 must keep the plotting contract aligned with the closed Phase 9
  pipeline behavior:
  - stage-local plots remain part of successful pipeline run directories
  - `write_plot_bundle(run)` remains the post-hoc curated bundle helper

## Current Base To Repair

The current remediation target is:

- model fitting:
  - `src/mmm/model.jl`
  - `src/mmm/media.jl`
  - typed model/config/spec surfaces in `src/model/`
- grouped artifacts and replay:
  - `src/inference/results.jl`
  - `src/postmodel/replay.jl`
  - `src/postmodel/contributions.jl`
  - `src/postmodel/response_curves.jl`
- optimization:
  - `src/optimization/objective.jl`
  - `src/optimization/optimizer.jl`
- pipeline/demo:
  - `src/pipeline/`
  - `examples/demo/`
- release validation/docs:
  - `test/validation/`
  - `docs/src/release.md`
  - `README.md`

Phase 12 must repair those layers in that dependency order.

## Frozen Public Contract Changes

Phase 12 freezes the public contract consequences of the remediation now rather
than leaving them to implementation-time design:

### Scaled-Space State

- the bounded comparable `TimeSeriesMMM` row must carry explicit scale state for
  channels and target
- that state must be present on the typed fitted-spec / grouped-artifact path
  rather than hidden only inside internal runtime objects
- the canonical public storage point is the typed model/spec/artifact layer used
  by:
  - `MMMModelSpec`
  - `InferenceResults.spec`
  - pipeline metadata sidecars for the repaired reference-bearing rows
- v1 does not add a second public scaled-output API surface; public predictive,
  contribution, response, metric, and optimization outputs remain in original
  units
- Phase 12 may retain scaled internal intermediates for replay or validation,
  but those are implementation details unless explicitly exported later

### Pipeline / Validation Sidecars

Phase 12 freezes the downstream schema impact:

- validation fixtures for repaired reference-bearing rows must include explicit scale
  metadata
- pipeline sidecars for repaired reference-bearing rows must expose enough metadata to
  show:
  - whether the fit used bounded Abacus-style scaling
  - the per-channel `channel_scale`
  - the `target_scale`
- Phase 12 should prefer extending existing metadata sidecars over inventing a
  second parallel manifest tree

### Stage 60 Public Surface

Phase 12 does not leave Stage 60 shape open. The bounded public contract after
remediation is:

- `response_curve_results(results; ...)`
  - remains the canonical forward-pass contribution curve API
- `saturation_curve_results(results; ...)`
  - new public typed result for the saturation-only curve family
- `adstock_curve_results(results; ...)`
  - new public typed result for the adstock carryover curve family

The frozen semantics are:

- `response_curve_results(results; channel, grid)`
  - uses the total-spend grid in original channel units
  - preserves the observed temporal spend shape for the selected channel
  - applies the repaired comparable-row media path in full:
    - channel scaling
    - adstock
    - saturation
    - coefficient ownership consistent with the repaired comparable model path
  - returns draw-level values in original target units
- `saturation_curve_results(results; channel, grid)`
  - uses the same total-spend grid and the same observed temporal spend-shape
    preservation rule as `response_curve_results`
  - applies channel scaling and the comparable saturation transform, but
    bypasses adstock carryover
  - returns draw-level values in original target units so it remains directly
    comparable to the other Stage 60 contribution-style curve families
- `adstock_curve_results(results; channel, grid)`
  - uses the same total-spend grid and the same observed temporal spend-shape
    preservation rule as `response_curve_results`
  - applies channel scaling and adstock carryover, but bypasses saturation and
    downstream target-space coefficienting
  - returns draw-level values in original channel-spend-equivalent units,
    because adstock-only output is a transformed-media/carryover surface rather
    than a target-space contribution surface

The corresponding typed result surfaces are:

- `ResponseCurveResults` for forward-pass contribution curves
- `SaturationCurveResults` for saturation-only curves
- `AdstockCurveResults` for adstock curves

The frozen typed-shape rule is:

- `SaturationCurveResults` and `AdstockCurveResults` should mirror the existing
  `ResponseCurveResults` layout as closely as possible:
  - `metadata`
  - `spec`
  - `coordinate_metadata`
  - `channel`
  - `spend_grid`
  - `spend_share_grid`
  - `observed_total_spend`
  - draw-level `values`
- the meaning of `values` differs by family and must be documented explicitly:
  - forward-pass and saturation-only are in original target units
  - adstock-only is in original channel-spend-equivalent units

Pipeline Stage `60_response_curves` must write all three artifact families for
the repaired reference-bearing rows, and plotting should consume those typed results
rather than inventing pipeline-only special cases.

The frozen Stage `60_response_curves` pipeline contract is:

- serialized per-channel artifacts:
  - `response_curve_<channel_slug>.jls`
  - `saturation_curve_<channel_slug>.jls`
  - `adstock_curve_<channel_slug>.jls`
- one combined long-form summary CSV:
  - `curve_summary.csv`
  - required columns:
    - `curve_family`
    - `channel`
    - `spend`
    - `spend_share`
    - `mean`
    - `lower`
    - `upper`
    - `observed_total_spend`
- stage-local plots for each family:
  - `response_curve_<channel_slug>.png`
  - `saturation_curve_<channel_slug>.png`
  - `adstock_curve_<channel_slug>.png`
- `metric_results(...)` remains a forward-pass consumer and should not be
  silently widened to saturation-only or adstock-only semantics

### Holiday / Demo Contract

External methodology advice has reopened the holiday/demo question. The frozen
Phase 12 target is now:

- one coherent native automatic holiday path built as a **single pooled holiday
  pulse/share regressor** with one analyst-facing `holiday` component
- yearly Fourier continues to own smooth repeating annual structure
- trend continues to own low-frequency non-periodic baseline movement
- manual named holiday dummies/windows live under `events`, not `controls`
- `prophet_component` may only survive as an explicit future compatibility
  mode; it is not the required v1 end state and must not be described as the
  native automatic holiday path

This is not a generic holiday-feature expansion phase:

- binary `events.windows` remain supported as already shipped
- the new bounded holiday path exists specifically to repair the additive-model
  semantics and the demo/reference story
- if a true Prophet-style compatibility mode is not implemented, the shipped
  demo may remain a useful cross-framework reference but must not be described
  as an Abacus-parity holiday row

The frozen native `holidays` config schema is:

- `holidays.mode` — string, required, only `"auto"` supported for the native
  v1 path
- `holidays.path` — string, required, path to a holidays CSV file
- `holidays.countries` — list of strings, required, ISO country codes to filter
  from the holidays CSV
- `holidays.priors` — optional mapping for the single holiday coefficient;
  defaults to `Normal(0, 1)` for `beta`

The frozen holidays CSV input contract is:

- columns: `ds` (ISO date string), `holiday` (name string), `country` (ISO
  country code string), `year` (integer)
- the existing `examples/demo/reference/abacus/holidays.csv` file satisfies
  this contract

The frozen native automatic-holiday feature generation rule is:

- filter the holidays CSV to the requested `countries`
- collapse the calendar to one pooled holiday exposure series rather than one
  column per holiday name
- daily data: the pooled exposure is a binary `0/1` pulse
- aggregated data: the pooled exposure is holiday-day share within the modeled
  period, e.g. `holiday_days_in_period / days_in_period`
- no Fourier smoothing of the holiday calendar in the native automatic path
- the resulting modeled surface is one pooled holiday regressor with one MMM
  coefficient and one analyst-facing holiday contribution

The frozen model integration rule is:

- the automatic holiday regressor is a separate semantic model block even if it
  reuses controls-style matrix plumbing internally
- holiday exposure is NOT channel-scaled
- holiday contributions ARE target-scale-unscaled
- automatic holiday contributions appear in `ContributionResults` and
  `DecompositionResults` as one pooled `holiday` component with kind
  `:holiday`

The frozen coexistence rule is:

- automatic `holidays` may coexist with `events`
- exact duplicate definitions must be rejected explicitly
- manual named holiday treatment belongs under `events` as `event:<name>`
  components, not under `controls`

### Parameter Ownership Reconciliation

Phase 12 also closes the parameter-ownership decision that the methodology
audit surfaced:

- the bounded reconciliation target is `:michaelis_menten`
- logistic, tanh, and hill should retain the existing external `beta_media`
  ownership unless new code evidence shows the comparable Abacus row differs
- the comparable `:michaelis_menten` row must match Abacus's coefficient
  ownership semantics rather than preserving Epsilon's previous convenience
  parameterization
- this is allowed to be a model/runtime/artifact change, not just a replay-side
  shim, if the posterior parameter meaning must change to reach parity
- 12-02 must not reopen the affected-type set during implementation; the frozen
  decision is that `:michaelis_menten` is the required reconciliation target

## Plan Set

### 12-01 Scaling And Model-Space Parity

Close the foundational gap first:

- implement Abacus-matching max scaling of channels and target on the frozen
  reference-bearing time-series rows where that claim still applies
- carry `channel_scale` and `target_scale` through the typed runtime/spec /
  grouped-artifact contract
- reconstruct original-scale predictive and contribution outputs explicitly
  rather than natively from a raw-scale fit
- recalibrate the bounded reference-bearing priors and parameter semantics around the
  corrected scaled space
- update validation fixtures, pipeline metadata sidecars, and direct parity
  tests for the corrected fit path

This plan owns the reference-critical decision that any row still described as
Abacus-reference must share the same fitted model space as Abacus.

12-01 is now the baseline, not open scope for 12-02:

- the bounded reference-bearing time-series fit path uses explicit max scaling
- `channel_scale` / `target_scale` flow through the typed spec/artifact path
- predictive outputs, forward-pass replay outputs, and grouped metadata carry
  the repaired original-scale reconstruction contract

12-02 must treat those items as already landed and only verify them where they
are downstream prerequisites for the new curve-family work.

### 12-02 Post-Model And Curve Parity

Once the fitted model space is corrected:

- verify that the 12-01 replay/original-scale contract remains truthful for the
  repaired reference-bearing rows rather than reimplementing it
- add the missing Stage 60 curve families needed for parity under the frozen
  public contract:
  - `response_curve_results(...)` remains forward-pass contribution
  - `saturation_curve_results(...)` adds saturation-only
  - `adstock_curve_results(...)` adds adstock
- implement the frozen `:michaelis_menten` parameter-ownership reconciliation
  needed where a reference-row parity claim still applies
- update typed post-model surfaces and plotting consumers to use the corrected
  curve semantics and the frozen Stage 60 artifact naming/output contract

This plan closes the current Stage 60 methodology gap. The testable symptom is
not a generic “odd response curve”; it is that any forward-pass row still
claimed as Abacus-reference must no longer be dominated by the pre-12-01
raw-scale saturation mismatch, and the repaired curve families must match their
Abacus counterparts on the frozen reference-bearing validation rows within the
declared tolerances.

12-02 is complete only when all of the following are true:

1. `response_curve_results(...)`, `saturation_curve_results(...)`, and
   `adstock_curve_results(...)` exist as typed public APIs with the frozen grid
   and output-unit semantics above.
2. The `:michaelis_menten` reference-bearing row uses the reconciled coefficient
   ownership contract consistently across fit, replay, Stage 60 exports, and
   plotting consumers.
3. Stage `60_response_curves` writes the frozen artifact set and summary schema
   for the repaired reference-bearing rows.
4. The repaired curve families match Abacus wherever a row still carries an
   Abacus-reference claim within the declared Stage 60 tolerances.

12-02 is now the baseline, not open scope for 12-03:

- `response_curve_results(...)`, `saturation_curve_results(...)`, and
  `adstock_curve_results(...)` exist as typed public APIs
- Stage `60_response_curves` writes the frozen per-channel artifact family and
  long-form `curve_summary.csv`
- plotting and `write_plot_bundle(run)` consume the typed Stage 60 results
  directly rather than inventing pipeline-only curve semantics
- the remaining open methodology work is Stage 70 semantics plus the bounded
  holiday/demo design and release-claim reconciliation

### 12-03 Optimization, Holidays, And Demo Comparability

Status: landed on 2026-04-24.

After the corrected curve contract exists:

1. **Verify optimization alignment.** After 12-01 and 12-02,
   `response_curve_results` and `contribution_results` already produce
   original-scale outputs. The optimization in `src/optimization/objective.jl`
   builds interpolated surfaces from those outputs, so it already operates in
   original scale. The `_baseline_and_fixed_response` function reads from
   `contribution_results`, which is also original-scale after 12-01. 12-03
   must verify this alignment holds end-to-end rather than reimplement it. If a
   remaining semantic gap is discovered during verification, it must be
   documented and fixed before proceeding to the holiday work.

2. **Replace the provisional holiday contract.** Remove the current semantic
   claim that `holidays.mode = "prophet_component"` is the bounded native
   holiday path. Add the frozen native `holidays` config path with schema
   (`mode`, `path`, `countries`, `priors`) and carry it through `MMMModelSpec`
   and the typed artifact path.

3. **Implement the pooled automatic holiday generator.** Add a function that
   reads the holidays CSV, filters by country, matches holidays to the modeled
   date range, and produces one pooled holiday exposure series:
   - daily: binary `0/1` pulse
   - aggregated: holiday-day share in the modeled period
   This replaces the current per-holiday indicator-column behavior on the
   native automatic path.

4. **Integrate one pooled holiday block into the Turing model.** Keep a single
   holiday coefficient with configurable priors (default `Normal(0, 1)`).
   Automatic holiday exposure is NOT channel-scaled but its contribution IS
   target-scale-unscaled, consistent with the 12-01 scaling contract.

5. **Move manual holiday treatment under `events`.** Preserve manual named
   holiday windows/dummies as ordinary event inputs. Allow `holidays` and
   `events` to coexist unless they encode the same underlying feature
   definition, in which case validation must reject the duplication.

6. **Integrate pooled holidays into deterministic replay.** Update
   `_postmodel_design_matrices` to generate the pooled holiday exposure from
   the spec's `holidays` config. Update `_contribution_component_layout` to
   include one pooled `holiday` component with kind `:holiday`. Update
   `_replayed_contribution_values` to replay that contribution with
   target-scale unscaling.

7. **Update the demo/reference story.** Modify
   `examples/demo/epsilon/timeseries/config.yml` and `examples/demo/README.md`
   so the shipped demo uses the native pooled holiday path and is described
   honestly as:
   - an Epsilon-native bounded methodology demo, or
   - an Abacus-reference row only if a separate true compatibility mode is
     later implemented and selected.

8. **Revalidate the pipeline.** Run the full pipeline on the repaired demo
   config and verify that stages 00–70 complete without error. Specifically
   verify that:
   - Stage 40 (decomposition) includes one pooled holiday component
   - Stage 60 (curves) stays in original scale and does not invent
     holiday-specific curve families
   - Stage 70 (optimization) produces original-scale budget recommendations

12-03 is complete only when all of the following are true:

1. The optimization path produces original-scale budget recommendations
   end-to-end, verified by checking that `optimize_budget` output values are
   in the same units as the observed target.
2. The native automatic holiday path produces one pooled holiday pulse/share
   regressor from the holidays CSV filtered by country, matching the frozen
   feature generation rule.
3. Holiday contributions appear in `ContributionResults` and
   `DecompositionResults` as one pooled `holiday` component with kind
   `:holiday`, in original target units.
4. The Epsilon demo config at `examples/demo/epsilon/timeseries/config.yml`
   includes the native automatic holiday path and is documented honestly as
   either an Epsilon-native demo or a compatibility-mode demo, depending on the
   selected implementation.
5. The full pipeline runs end-to-end on the repaired demo config without error,
   and stages 40/60/70 outputs include the pooled holiday component and remain in
   original scale.
6. `ModelConfig` validation allows `holidays` plus `events` unless they define
   the same underlying feature, in which case the duplication is rejected.

This plan closes the current gap between the copied Abacus demo assets, the
shipped Epsilon runnable demo, and the now-frozen coherent additive design.

### 12-04 Revalidation And Release Reconciliation

Status: landed on 2026-04-24.

Close the remediation phase truthfully:

- regenerate and rerun the final validation harness on the repaired comparable
  rows
- reconcile the release docs, README, and benchmark/readiness language with the
  repaired methodology/reference state
- explicitly decide whether `v1.0.0-rc1` preparation can resume
- if the reference claim is still not sufficient, leave the repo in a truthful
  non-release state with the remaining blockers recorded

Phase 12 does not automatically re-close release readiness just because code
has changed. The final docs and validation evidence must justify it.

## Acceptance Criteria

Phase 12 is complete only when all of the following are true:

1. The guaranteed Abacus-reference row `VAL-TS-00-MCMC` fits in the same
   scaling/model space as Abacus, with explicit `channel_scale` /
   `target_scale` state and truthful original-scale reconstruction.
2. Time-series contributions, posterior/predictive outputs, and all three
   Stage 60 curve artifact families are methodologically aligned with Abacus
   where a real Abacus-reference claim is still being made.
3. Optimization semantics on those reference-bearing rows are no longer
   resting on the previously divergent response-surface contract.
4. The shipped time-series demo/reference story is truthful for
   holiday/component handling and cross-framework comparison, including any
   narrowing of the Abacus-reference claim and any Epsilon-native automatic
   holiday design.
5. Release and README/docs language no longer overclaim parity, and any
   unchecked release-readiness items remain visibly unchecked until Phase 12
   closes.
6. The final validation harness demonstrates repaired comparison where
   comparison is real and remains explicit about any still-bounded
   Epsilon-only surfaces.

## Explicit Non-Goals

Phase 12 does not:

- reopen Dash or report-product parity
- widen panel scope beyond the already bounded path
- introduce unrelated v2 methodology beyond what is needed to close the
  current methodology/reference gap
- add unrelated v2 feature work
- restart release tagging before the remediation acceptance criteria pass

## Exit Outcome

If Phase 12 succeeds, the repo returns to a truthful release-preparation state
with repaired reference claims only on the bounded time-series surface where
the semantics genuinely match.

If Phase 12 does not fully succeed, the repo must remain explicit that Epsilon
is a bounded Julia MMM package with useful functionality, but not yet an
Abacus-reference release candidate on the disputed rows.
