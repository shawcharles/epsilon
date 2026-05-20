# External Planning Review

**Review Target:** Phase 12-03 — Optimization, Holidays, And Demo Comparability
**Reviewer:** External Planning Auditor
**Date:** 2026-04-24
**Codebase Commit:** 44e6c47e42f3034cbc06590d54f9a2de9e0fb1a3 (plus 12-01 implementation)

## Findings

- **critical** — `.planning/phases/12-parity-remediation/PLAN.md` lines 249–251: The `holidays.mode = "prophet_component"` path is named but not specified. This is the largest single work item in 12-03 and it is a new feature, not a remediation tweak. The plan does not define: (a) what "prophet_component" means computationally (Abacus generates Fourier-expanded holiday features from a holidays CSV filtered by country, which is fundamentally different from Epsilon's existing `events.columns` and `events.windows` binary-indicator paths), (b) the config schema (Abacus uses `holidays.mode`, `holidays.path`, `holidays.countries` — Epsilon has no `holidays` config key at all), (c) the holiday feature generation algorithm (how many Fourier terms, what window around each holiday, how overlapping holidays are handled), (d) how holiday components integrate into the Turing model (separate `beta_holidays` parameter block? shared with events? own prior?), (e) how holiday contributions appear in `ContributionResults` and `DecompositionResults`, (f) how holidays interact with the scaling contract from 12-01 (are holiday features scaled? they should not be channel-scaled, but target-scale unscale applies), (g) whether this requires changes to `_validate_model_data_alignment`, `_build_model_spec`, `_postmodel_design_matrices`, and `_contribution_component_layout`. Without these specifications, an implementer must design the entire holiday subsystem during execution, which is exactly the kind of scope creep the frozen contract section is supposed to prevent.

- **high** — `.planning/phases/12-parity-remediation/PLAN.md` lines 247–248: "Realign optimization semantics with the corrected scaled-space / original-scale contract and remove any remaining misleading approximation claims" is vague about what remains to be realigned. After 12-01, `response_curve_results` already produces original-scale outputs (channels scaled by `channel_scale`, contributions unscaled by `target_scale`). The optimization in `src/optimization/objective.jl` builds interpolated surfaces from `response_curve_results`, so it already operates in original scale. The `_baseline_and_fixed_response` function reads from `contribution_results`, which also produces original-scale outputs after 12-01. If there is a remaining semantic gap, it is not identified. If there is no remaining gap, this item should be stated as "verify that 12-01 changes already close the optimization alignment" rather than "realign optimization semantics."

- **high** — `.planning/phases/12-parity-remediation/PLAN.md` lines 252–254: "Update the runnable demo config and reference assets so the shipped Epsilon time-series demo is methodologically comparable to the copied Abacus time-series demo" does not specify what changes are needed. The current Epsilon demo config (`examples/demo/epsilon/timeseries/config.yml`) has no `holidays` section, no `trend` section, and uses `logistic` saturation while the Abacus demo uses `logistic` saturation with `holidays.mode: prophet_component, path: ../../holidays.csv, countries: UK`. The plan must enumerate the specific config changes needed and whether new reference result assets must be generated.

- **high** — `.planning/phases/12-parity-remediation/PLAN.md` lines 255–256: "Revalidate pipeline stage outputs that depend on the repaired post-model / optimization surfaces" is a task without a completion standard. Which stages? What constitutes "revalidated"? The pipeline has stages 00–70; stages 40 (decomposition), 50 (diagnostics), 60 (curves), and 70 (optimization) all depend on post-model surfaces. Does revalidation mean running the pipeline end-to-end and checking that no stage fails? Or does it mean comparing specific numerical outputs against Abacus reference values? The plan must specify.

- **medium** — `.planning/phases/12-parity-remediation/PLAN.md` lines 193–202: The Holiday/Demo Contract section says "the new bounded holiday/component path exists specifically to repair the comparable time-series methodology and demo/reference story" and "this is not a generic holiday-feature expansion phase." However, implementing `holidays.mode = "prophet_component"` requires: (a) a new config key `holidays` in `ModelConfig`, (b) a new holiday feature generator, (c) Turing model changes, (d) replay changes, (e) contribution/decomposition changes, (f) pipeline stage changes, (g) plotting changes, (h) test changes. This is a substantial feature regardless of how it is scoped. The plan should acknowledge the implementation surface area and estimate the work honestly, even if the feature is bounded.

- **medium** — `.planning/phases/12-parity-remediation/PLAN.md` lines 196–197: The plan says "binary `events.windows` remain supported as already shipped" but does not specify how `holidays.mode = "prophet_component"` coexists with `events.columns` and `events.windows`. Can a config have both? Are they mutually exclusive? If both are present, do they share a `beta_holidays`/`beta_events` parameter block or get separate blocks? The current `_events_columns` and `_events_windows` functions in `src/mmm/events.jl` handle the existing event paths; the holiday path needs to be specified as either extending the events system or being a separate system.

- **medium** — `.planning/phases/12-parity-remediation/PLAN.md` lines 258–259: The Abacus reference demo config at `examples/demo/reference/abacus/timeseries/config.yml` already has `holidays.mode: prophet_component` with `path: ../../holidays.csv` and `countries: UK`. The holidays.csv file exists at `examples/demo/reference/abacus/holidays.csv` (55,410 lines, 70+ countries). The plan does not specify whether Epsilon should: (a) read the same holidays.csv format, (b) use a subset (e.g., only UK holidays), or (c) generate holiday features differently. The holidays.csv format (`ds,holiday,country,year`) must be specified as the input contract.

- **low** — `.planning/phases/12-parity-remediation/PLAN.md` lines 243–259: 12-03 has no plan-level acceptance criteria. The phase-level acceptance criteria (lines 276–295) cover the full phase, not this sub-plan. An implementer cannot determine when 12-03 is done independently of the full phase closeout.

## Cross-Document Gaps

1. **PLAN.md vs. Abacus demo config**: The Abacus time-series demo config uses `holidays.mode: prophet_component` with a holidays CSV file. The Epsilon demo config has no holidays section. The plan references this gap but does not specify the bridge.

2. **PLAN.md vs. METHODOLOGY_AUDIT.md**: The methodology audit finding #5 says "The runnable Epsilon demo omits the Prophet-style holiday component used by the Abacus demo." The audit does not specify what the Prophet-style holiday component does computationally, leaving the implementation semantics undefined.

3. **PLAN.md vs. current events system**: The current Epsilon events system (`src/mmm/events.jl`) supports `events.columns` (explicit binary columns) and `events.windows` (generated binary windows from date ranges). The `prophet_component` holiday path is a different computation (Fourier expansion around holiday dates, not binary indicators). The plan does not specify whether holidays extend the events system or are a separate model component.

4. **PLAN.md vs. 12-01 implementation**: After 12-01, optimization already operates in original scale via the corrected `response_curve_results` and `contribution_results`. The 12-03 scope item "realign optimization semantics" may already be satisfied, but the plan does not acknowledge this.

5. **PLAN.md vs. RISKS-AND-DECISIONS.md**: The holiday/component path introduces a new feature into a remediation phase. This creates a risk of scope expansion that is not recorded in RISKS-AND-DECISIONS.md. The risk that the holiday implementation diverges from Abacus semantics (similar to the scaling divergence that motivated Phase 12) is not recorded.

## Recommended Planning Changes

1. **Specify the `holidays.mode = "prophet_component"` computation** in the frozen contract section of PLAN.md. At minimum, define:
   - **Config schema**: `holidays.mode` (string, required, only `"prophet_component"` supported), `holidays.path` (string, required, path to holidays CSV), `holidays.countries` (list of strings, required, ISO country codes to filter), `holidays.priors` (optional, same structure as events priors)
   - **Input contract**: holidays CSV with columns `ds` (date), `holiday` (name), `country` (ISO code), `year` (integer)
   - **Feature generation**: for each holiday in the filtered set that falls within the training date range, generate Fourier expansion features (specify `n_order` — Abacus uses the same `n_order` as the seasonality Fourier, or a separate parameter). The features are continuous (not binary), centered on the holiday date.
   - **Model integration**: holiday features get their own `beta_holidays` parameter block with configurable priors (default matching events prior), separate from `beta_events`
   - **Scaling**: holiday features are NOT channel-scaled (they are not channel data), but holiday contributions ARE target-scale-unscaled (they contribute to the target in scaled space)
   - **Coexistence**: `holidays` and `events` are mutually exclusive in v1 (a config has one or the other, not both). This avoids parameter-block collision and keeps the bounded scope honest.

2. **Clarify the optimization realignment scope**: State explicitly whether 12-01 already closes the optimization alignment gap (response curves and contributions are already in original scale), or identify the specific remaining semantic difference. If 12-01 closes it, reword the 12-03 item as "verify that optimization semantics are already aligned after 12-01 and 12-02."

3. **Enumerate the demo config changes**: List the specific changes needed to `examples/demo/epsilon/timeseries/config.yml`: add `holidays` section with `mode: prophet_component`, `path`, `countries`; verify that channel/adstock/saturation/seasonality/priors match the Abacus reference config; update `fit` block if needed.

4. **Specify the revalidation standard**: Define what "revalidate pipeline stage outputs" means — at minimum, "run the full pipeline on the repaired demo config and verify that stages 00–70 complete without error, and that stage 40/60/70 outputs are in original scale."

5. **Add plan-level acceptance criteria for 12-03**: At minimum:
   - `holidays.mode = "prophet_component"` produces holiday features that match Abacus's Prophet-style holiday component for the same input holidays CSV and country filter
   - Holiday contributions appear in `ContributionResults` and `DecompositionResults` as a separate component
   - The Epsilon demo config is methodologically comparable to the Abacus demo config (same channels, adstock, saturation, seasonality, holidays)
   - The pipeline runs end-to-end on the repaired demo config without error
   - Optimization outputs are in original scale

6. **Record the holiday scope risk** in RISKS-AND-DECISIONS.md: the risk that implementing a new feature (prophet_component holidays) in a remediation phase expands scope beyond the original parity gap, and the mitigation (bounded to one holiday mode, one config path, mutually exclusive with events).

7. **Specify the holidays/events coexistence rule**: State whether `holidays` and `events` can coexist in the same config or are mutually exclusive. Recommend mutually exclusive for v1 to keep the bounded scope honest.

## Conclusion

The planning set is not ready for 12-03 execution. The `holidays.mode = "prophet_component"` path is the dominant work item and it is a new feature, not a remediation adjustment, yet it has no specification beyond its name. The optimization realignment item may already be satisfied by 12-01 but the plan does not acknowledge this. The demo comparability item does not enumerate the specific config changes needed. The minimum changes needed are: (1) specify the prophet_component holiday computation, config schema, feature generation, model integration, and scaling contract at the same level of detail the frozen Stage 60 contract received, (2) clarify whether optimization realignment is already satisfied, and (3) enumerate the demo config changes and revalidation standard.