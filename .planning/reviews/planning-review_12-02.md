# External Planning Review

**Review Target:** Phase 12-02 — Post-Model And Curve Parity
**Reviewer:** External Planning Auditor
**Date:** 2026-04-24
**Codebase Commit:** 44e6c47e42f3034cbc06590d54f9a2de9e0fb1a3 (plus 12-01 implementation)

## Findings

- **high** — `.planning/phases/12-parity-remediation/PLAN.md` lines 226–241: 12-02 scope item "realign deterministic replay with the scaled-space contract and explicit original-scale reconstruction" is already completed by the 12-01 implementation. The 12-01 changes to `src/postmodel/replay.jl` (`_replayed_contribution_values` now scales channels by `channel_scale` and unseles all components by `target_scale`) and `src/postmodel/response_curves.jl` (scales channel data before replay, unseles by `target_scale`) have already realigned deterministic replay with the scaled-space contract. If 12-02 is executed as written, an implementer will either duplicate 12-01 work or waste time verifying that "realign" means "verify the 12-01 changes are correct" rather than "implement new alignment." The plan must explicitly state which 12-02 scope items are already satisfied by 12-01 and which remain.

- **high** — `.planning/phases/12-parity-remediation/PLAN.md` lines 232–234: The two new public APIs `saturation_curve_results(...)` and `adstock_curve_results(...)` are named but not specified. The plan does not define: (a) what computation each performs (saturation-only = apply saturation transform to scaled channel data without adstock? adstock = apply adstock transform without saturation?), (b) what the grid semantics are (same total-spend grid as forward-pass, or different), (c) what the typed result structs `SaturationCurveResults` and `AdstockCurveResults` contain, (d) whether the outputs are in original or scaled space, (e) how they interact with the `channel_scale`/`target_scale` contract from 12-01. Without these specifications, an implementer must reverse-engineer the Abacus semantics during execution, which is exactly the kind of ambiguity the frozen contract section is supposed to prevent.

- **high** — `.planning/phases/12-parity-remediation/PLAN.md` lines 235–236: "Reconcile parameter naming/ownership where the current external `beta_media` semantics differ materially from Abacus's saturation parameterization" is stated as a scope item but the discrepancy is not identified. The current Epsilon model uses `beta_media` as an external multiplier on transformed media (applied after adstock + saturation), while Abacus's Michaelis-Menten parameterization absorbs the coefficient into the saturation function. The plan does not state: (a) which saturation types are affected (only `:michaelis_menten`? also `:hill`?), (b) what the target parameterization is, (c) whether this requires a model-breaking change to the Turing model or only a replay-side adjustment. This is a design decision masquerading as a task.

- **medium** — `.planning/phases/12-parity-remediation/PLAN.md` lines 237–238: "Update typed post-model surfaces and plotting consumers to use the corrected curve semantics" is vague. The current `ResponseCurveResults` struct (in `src/postmodel/types.jl`) has fields `channel`, `spend_grid`, `spend_share_grid`, `observed_total_spend`, and `values`. The plan does not specify whether the new curve families share this struct shape, whether `summary_table` and `metric_results` must be extended, or what the plotting contract is for the new curve types. The current `response_curve_plot` in `src/plotting/postmodel.jl` renders a response curve with an optional marginal subplot; the plan does not specify whether saturation and adstock curves get the same plot type or different ones.

- **medium** — `.planning/phases/12-parity-remediation/PLAN.md` lines 183–186: The frozen Stage 60 contract says "Pipeline Stage `60_response_curves` must write all three artifact families for the repaired comparable rows, and plotting should consume those typed results rather than inventing pipeline-only special cases." However, the current pipeline Stage 60 implementation in `src/pipeline/stages.jl` (`_run_curves_stage!`) iterates over channels and calls `response_curve_results` + `metric_results` for each, then writes serialized artifacts and plots. The plan does not specify: (a) the artifact naming convention for the new curve families (e.g., `saturation_curve_results_tv.jls`?), (b) whether the stage should produce three separate artifact sets or one combined artifact, (c) whether the CSV summary tables need new columns or separate files, (d) how the plotting sub-stage should handle the three families. This is a pipeline contract change that needs the same level of upfront specification that the public API section received.

- **medium** — `.planning/STATE.md` lines 56, 98–99: STATE.md reports Phase 12 as "0 plans completed" and "Not started" with the pending todo "Execute 12-01." The 12-01 implementation has landed (channel_scale/target_scale fields on MMMModelSpec, scaling in fit/predict/prior_predict/replay/response_curves, pipeline metadata, test updates). STATE.md is stale and will misdirect anyone checking current project position.

- **medium** — `.planning/phases/12-parity-remediation/PLAN.md` lines 240–241: "This plan closes the methodology gap behind the current 'odd response curve' symptom." The symptom is referenced but never defined in the plan or in the methodology audit. If this refers to a specific observable behavior (e.g., response curves not passing through the observed spend point, or curves showing unexpected shapes due to the old unscaled model space), it should be stated as a testable condition. Without it, there is no falsifiable completion criterion for this claim.

- **low** — `.planning/phases/12-parity-remediation/PLAN.md` lines 276–295: The Phase 12 acceptance criteria are phase-level, not plan-level. 12-02 has no plan-specific acceptance criteria or completion standard. An implementer cannot determine when 12-02 is done independently of the full phase closeout. Each sub-plan should have at least one falsifiable completion condition.

## Cross-Document Gaps

1. **STATE.md vs. codebase**: STATE.md says Phase 12 has 0 completed plans and is "Not started." The 12-01 implementation has landed in the codebase. STATE.md is materially stale.

2. **PLAN.md 12-02 scope vs. 12-01 implementation**: The 12-02 scope item "realign deterministic replay with the scaled-space contract" overlaps with work already completed in 12-01. The plan does not acknowledge this overlap or distinguish what remains.

3. **PLAN.md frozen contract vs. Abacus reference**: The frozen Stage 60 public contract names `saturation_curve_results` and `adstock_curve_results` but does not reference the specific Abacus implementation that defines the expected semantics. The Abacus codebase has distinct saturation-only and adstock carryover curve computations, but the plan does not map the Epsilon API to those computations.

4. **PLAN.md vs. RISKS-AND-DECISIONS.md**: Risk R0 ("Model-Space Divergence From Abacus Scaling") is the Phase 12 blocker. The 12-01 implementation addresses the scaling divergence, but RISKS-AND-DECISIONS.md has not been updated to reflect partial closure. The 12-02 curve-family risk (that the new curve families may not match Abacus semantics) is not recorded.

5. **GSD-BOARD.md vs. codebase**: The GSD board shows Phase 12 as 🔴 (not started). The 12-01 implementation has landed, so at minimum 12-01 should be marked in progress or complete.

## Recommended Planning Changes

1. **Update STATE.md** to reflect that 12-01 is complete: change Phase 12 plans completed from 0 to 1, update the pending todos to "Execute 12-02", and update the last activity description.

2. **Rewrite the 12-02 scope in PLAN.md** to explicitly separate: (a) items already satisfied by 12-01 (deterministic replay alignment, original-scale reconstruction in contributions and response curves), which should be listed as "verified by 12-02" rather than "implemented by 12-02"; and (b) items that remain as new 12-02 work (saturation_curve_results, adstock_curve_results, parameter naming reconciliation, plotting/pipeline updates).

3. **Specify the two new curve-family APIs** in the frozen contract section of PLAN.md with the same level of detail that `response_curve_results` received: computation semantics (what transforms are applied, in what order, with or without beta_media), grid semantics (same total-spend grid or different), output space (original scale, consistent with 12-01 target_scale contract), and typed result struct fields.

4. **Specify the parameter naming reconciliation** as a concrete decision rather than a task: state which saturation types are affected, what the current Epsilon behavior is, what the target Abacus behavior is, and whether the fix is a model-breaking change or a replay-only adjustment. If the decision cannot be made now, flag it as an open question with a trigger condition.

5. **Specify the Stage 60 pipeline changes**: artifact naming convention for the three curve families, whether the stage produces three separate or one combined artifact set, and how the plotting sub-stage handles the three families.

6. **Add plan-level acceptance criteria for 12-02**: at minimum, a falsifiable condition for each new public API (e.g., "saturation_curve_results returns draw-level values in original scale for match the Abacus saturation-only curve computation for the comparable rows") and a condition for the "odd response curve" symptom (e.g., "response curves for the comparable rows pass through the observed spend/response point within tolerance X").

7. **Update GSD-BOARD.md** to mark 12-01 as complete and 12-02 as in progress.

## Conclusion

The planning set is not ready for 12-02 execution in its current form. The 12-02 scope description contains a significant overlap with the already-completed 12-01 work, and the two new public APIs (`saturation_curve_results`, `adstock_curve_results`) are named but not specified. The parameter naming reconciliation item is a design decision that has not been made. Without these specifications, an implementer would need to reverse-engineer Abacus semantics during execution, which contradicts the plan's own principle of freezing the public contract up front. The minimum changes needed are: (1) update STATE.md and GSD-BOARD.md to reflect 12-01 completion, (2) rewrite 12-02 scope to separate verified-from-12-01 items from new work, and (3) specify the new curve-family APIs and parameter reconciliation decision at the same level of detail that the frozen Stage 60 contract section aspires to.