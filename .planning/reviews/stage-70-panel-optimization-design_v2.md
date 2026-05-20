# Stage 70 Panel Budget Optimization — Design Recommendation (v2)

**Author:** External methodology advisor
**Scope:** Epsilon.jl Stage 70 (`src/optimization/`) extension to `PanelMMM`
**Status:** Recommendation for implementation planning
**Supersedes:** `stage-70-panel-optimization-design.md` (v1) — where they disagree, v2 takes precedence

---

## TL;DR

1. **Include panel optimization in v1**, but at a *channel-level allocation* with *historical-share within-channel panel disaggregation*. **Do not** open free channel × panel-cell allocation in the first release.
2. Default objective: **maximize posterior-mean total response summed across panels and time**, on the same `:total_response` symbol used for time series.
3. Free channel × panel allocation, profit objectives, share constraints, and fairness constraints are **explicitly deferred** to a clearly labelled v1.1 channel × panel mode behind a flag, gated on tighter validity-domain guardrails.
4. The single largest methodological risk is **panel-conditional extrapolation**: panel response curves in Epsilon use a *historical-scaling delta grid* (`δ ∈ ℝ⁺` rescaling each panel's observed spend path), so the curves are only locally trustworthy near `δ = 1`. Free cross-panel reallocation drives some panels far from `δ = 1` and others close to it — that asymmetric extrapolation must be explicit in the contract, not buried in documentation.
5. The implementation should reuse the Phase 8 JuMP/Ipopt + monotone cubic interpolation contract. The only new primitive is a per-channel two-level disaggregation rule (channel total → per-panel allocation), which is fully implied by the chosen "preserve historical panel shares" semantics.

This is more conservative than the v1 review on purpose. Epsilon's bounded design philosophy is to refuse to invent semantics the underlying surfaces cannot actually support, and the current panel response-curve contract does not yet support free cross-panel reallocation honestly.

---

## 1. Should panel optimization be in v1 at all?

**Recommendation: yes, but only at channel-level allocation with historical within-channel panel shares.**

**Rationale.**

- The model already provides what is needed for *channel-level* optimization: panel contributions and panel response curves exist as canonical post-model artifacts.
- Skipping optimization entirely for panel models creates an artificial cliff between Stage 60 (curves exist) and Stage 70 (no allocation tool), and forces analysts to roll their own optimizer against the typed curve surface — which is exactly the situation Phase 8 was designed to avoid.
- However, opening *full* channel × panel-cell allocation in v1 conflates two design problems:
  (a) the well-understood "how do we move money between media channels" problem, and
  (b) the much harder "how do we move money between panel cells" problem, which is highly susceptible to extrapolation, identifiability under hierarchical pooling, and business-fairness constraints.
- The conservative v1 surface answers (a) for panel models without pretending to have solved (b).

**What "in v1" means concretely:**

- `optimize_budget(results::InferenceResults{<:PanelMMM}; ...)` returns a typed `PanelBudgetOptimizationResult`.
- The decision variable is *channel-level* total spend across panels.
- Within-channel disaggregation to panels uses **fixed historical panel shares** (see Section 4).
- The result carries both the channel-level allocation and the implied channel × panel allocation as audit output.
- Free channel × panel allocation is explicitly unsupported in v1; the optimizer raises a contract error if `panel_bounds` or `panel_allocation_mode = :free` are passed.

---

## 2. First supported allocation level

**Recommendation: channel-level, with historical within-channel panel shares applied deterministically.**

The v1 review proposes channel × panel-cell allocation. I disagree for v1 for one structural reason: the panel response-curve contract Epsilon already froze does not support honest free panel-cell allocation.

**Why.** Look at `_panel_curve_surface_context` in `src/postmodel/response_curves.jl`:

```julia
delta_values = _validated_spend_grid(delta_grid, action)
observed_spend = vec(sum(channels[:, channel_index, :]; dims = 1))
spend_grid = observed_spend * transpose(delta_values)   # (panel × delta) absolute spend
```

The panel response curves are computed by **rescaling each panel cell's *own* historical spend path** by a shared deltas vector `δ`. This means:

- For each panel `p`, the curve `response_p(δ)` is parameterised by `δ` (a multiplier), not by absolute spend.
- The shape of the curve, including its adstock dynamics and saturation behavior, assumes the *within-panel intra-horizon spend shape stays fixed*. Only the total scale changes.
- The validity of the curve is highest near `δ = 1` (observed history) and degrades monotonically as `δ` moves away from 1.
- The validity domain is **panel-specific**: a panel with `observed_spend_p = $1k` evaluated at `δ = 2` is on much firmer footing than a panel with `observed_spend_p = $1M` evaluated at `δ = 0.001`, even though both have the same `δ`.

Free channel × panel allocation forces the optimizer to push some panels to very small `δ` and others to very large `δ`. Because Epsilon's saturation and adstock parameters were estimated jointly with the observed within-panel shape, this is not just "a bit of extrapolation" — it is *systematically* asymmetric extrapolation that the response-curve contract was not designed to certify.

By contrast, **channel-level allocation with proportional within-channel panel scaling** evaluates every panel curve at exactly the same `δ`. The validity of the answer degrades smoothly with `|δ - 1|`, and Epsilon can document a single, honest extrapolation guardrail.

This is also more interpretable: the channel-level decision variable is what advertisers actually control (media buying budgets are typically negotiated at the channel or campaign level, not the geo × channel level).

**v1 allocation contract:**

```
Decision variable: x_c  ∈ ℝ⁺ for each optimized channel c
Constraint:        Σ_c x_c = total_budget   (over optimized channels)
Disaggregation:    s_{c,p} = (S_{c,p}^obs / S_c^obs) · x_c
                   where S_{c,p}^obs = observed total spend for channel c in panel p
                         S_c^obs     = Σ_p S_{c,p}^obs
Per-panel delta:   δ_{c,p} = s_{c,p} / S_{c,p}^obs = x_c / S_c^obs
                   ← identical across panels for channel c (by construction)
```

The last identity is the key statistical guarantee: every panel is evaluated at the *same* delta point on its curve, so the validity-domain reasoning is uniform across panels.

**v1.1 channel × panel mode (deferred):** keep the same API but accept `panel_allocation_mode = :free`, gated on stricter per-panel delta bounds (see Section 5). This is the natural extension once Epsilon validates the curve surface under non-uniform-delta evaluation, ideally with a panel-aware Stage 35 holdout. Until that validation exists, this mode is not statistically certified.

---

## 3. Default objective

**Recommendation: `:total_response` — maximize the posterior-mean of total modelled response, summed across panels and time, on the original target scale.**

This matches the existing Phase 8 contract for time series and avoids reopening objective semantics. Concretely:

```
total_response(x) = baseline_response                              (fixed)
                  + Σ_{c ∈ fixed channels} R_c^obs                  (fixed)
                  + Σ_{c ∈ optimized channels} Σ_{p ∈ panels} f_{c,p}(x_c · w_{c,p})
```

where:

- `w_{c,p} = S_{c,p}^obs / S_c^obs` is the historical share of channel `c` going to panel `p`,
- `f_{c,p}(·)` is the posterior-mean response surface for channel `c`, panel `p`, evaluated via monotone cubic interpolation over the channel-level decision variable (see Section 6 for grid construction).

**Why not other objectives:**

- **Weighted response**: requires panel weights as user input. There is no canonical default. Defer to v1.1 with documented semantics.
- **Average response**: averaging hides panel heterogeneity and is rarely what advertisers actually want. Provide it only as a derived summary, not an objective.
- **Profit / utility**: Epsilon has no cost / margin data contract. Profit objectives require extending the model spec to carry per-channel cost-per-impression or margin coefficients. This is a *new data contract*, not just an optimizer feature, and belongs in a separate planning ticket.
- **Fairness / constrained objectives**: these are constraints, not objectives. Support them as constraints in v1.1, not as alternative objective symbols.

The default behaviour is identical to time series: maximize total expected response. The fact that Epsilon happens to be a panel model is invisible in the objective definition itself — it manifests only in how the channel response is decomposed.

---

## 4. How should incremental budget be distributed across panels?

**Recommendation: fixed historical panel shares, applied within each channel.**

For each optimized channel `c`, when the optimizer chooses `x_c`, the spend in panel `p` is mechanically `s_{c,p} = (S_{c,p}^obs / S_c^obs) · x_c`. Panels are *not* a degree of freedom in v1.

**Why this is the right default, not a placeholder:**

1. **Statistical coherence with the curve contract.** As argued in Section 2, the panel response-curve contract is *defined* on per-panel delta multipliers. Holding historical shares fixed means all panels for a given channel are evaluated at the same delta, which is exactly the regime where the curves are best-calibrated.
2. **Identifiability under hierarchical pooling.** In a hierarchical panel model, small panels borrow strength from the population. Their effective response surface partially reflects the population-mean response, not their own data. Free reallocation toward such panels is, in practice, reallocation toward the population mean — which can produce optimistic but unidentifiable answers. Holding shares fixed sidesteps this entirely.
3. **Operational realism.** In most real-world MMM applications, panel-level allocations are decisions made by separate planning teams, not by the optimizer. Geo-level allocation typically reflects market structure, distribution, and sales-team coverage — not a free response-maximization decision. Defaulting to "preserve current geo mix" is closer to the standard analyst workflow than "let the optimizer reassign 70% of geo A's budget to geo B".
4. **Avoids inventing semantics the surfaces can't certify.** Free panel allocation requires the optimizer to evaluate `f_{c,p}(δ)` at very different `δ` per panel. Until Epsilon has a documented panel-curve validity domain (Stage 35-style panel holdout, or at minimum domain-of-historical-deltas characterization), free reallocation is not honest.

**Equal panel shares** is methodologically wrong: it implicitly asserts that all panels have the same demand structure, which contradicts everything the hierarchical model was fit to learn.

**Free across panels** is the v1.1 mode and explicitly deferred (see Section 5).

**Constrained-by-bounds with relative guardrails** is the natural v1.1 contract for incremental flexibility: per-channel-panel `relative_bounds ∈ [0.8, 1.2]` of historical shares would let the optimizer move money between panels within a tight range. This is mechanically the same primitive as time-series `relative_bounds`. It still belongs in v1.1 because it requires the optimizer to evaluate non-uniform `δ` across panels.

---

## 5. Constraints for v1

### Supported in v1

| Constraint family | Semantics | Rationale |
|---|---|---|
| **Total-budget equality** | `Σ_c x_c = total_budget` | Same as time-series Phase 8. |
| **Channel absolute bounds** | `lower_c ≤ x_c ≤ upper_c` in original spend units | Same primitive as time-series `budget_bounds`. |
| **Channel relative bounds** | `lower_c · S_c^obs ≤ x_c ≤ upper_c · S_c^obs` | Same primitive as time-series `relative_bounds`. |
| **Channel subset selection** | unselected channels held at observed spend (per-panel shares preserved) | Same primitive as time-series `channels=`. |
| **Per-channel delta-domain guardrails** | Implicit: documented validity band on `δ_c = x_c / S_c^obs` | Surfaces the curve-extrapolation risk explicitly in the audit (Section 6). |

### Explicitly deferred to v1.1+

- **Channel × panel absolute bounds.** Not supportable until free panel allocation is enabled. In v1, the per-(channel, panel) spend is mechanically determined by `x_c` and historical shares.
- **Panel total bounds.** Same reason. In v1, panel totals are an output, not a free variable.
- **Minimum / maximum panel spend share constraints.**
- **Fairness constraints** (min response per panel, equal-response constraints, Gini-style metrics on per-panel response).
- **Fixed-spend channels at non-observed values.** v1 supports "hold at observed" only.
- **Cross-channel ratio constraints.** Also explicitly out of scope in Phase 8.
- **Date-level pacing or intra-horizon shape changes.**

### Why this is the right place to draw the line

Channel × panel bounds are *not* a small extension. They imply a `(n_channels × n_panels)`-dimensional decision space, individually-evaluated per-panel response surfaces at non-uniform `δ`, and panel-specific validity guardrails. Each of those is independently risky. Bundling them into v1 forces all of those risks to be carried before the simpler channel-level path is even battle-tested.

The bounded design philosophy here is: **the v1 surface should answer one well-posed optimization question per panel model, not invite all of the harder questions at once.**

---

## 6. Summary artifacts to emit

### Required v1 outputs (artifacts)

Reusing the existing Stage 70 directory layout under `70_optimisation/`, with panel-specific tables added.

#### 6.1 `BudgetOptimizationResult`-compatible scalar / channel-level outputs

These mirror the time-series result so dashboards and downstream tooling stay uniform:

| Field | Type | Notes |
|---|---|---|
| `objective` | `Symbol` | `:total_response` |
| `optimized_channels` | `Vector{String}` | preserved order from spec |
| `fixed_channels` | `Vector{String}` | |
| `current_spend` | `Dict{String, Float64}` | channel → total observed spend |
| `optimized_spend` | `Dict{String, Float64}` | channel → optimized total spend |
| `current_response` | `Float64` | total modelled response at observed allocation, posterior mean |
| `optimized_response` | `Float64` | total modelled response at optimized allocation, posterior mean |
| `current_default_efficiency` | `Float64` | ROAS for revenue targets, CPA for conversion targets, computed as in time series |
| `optimized_default_efficiency` | `Float64` | |
| `solver_status`, `objective_value`, `convergence_metadata` | as time series | |
| `constraint_audit::BudgetConstraintAudit` | as time series | |

#### 6.2 New panel-only artifacts

| Artifact | Shape | Notes |
|---|---|---|
| `panel_coordinate_table` | tidy table, one row per panel cell | columns: flat panel index, declared coordinate columns (e.g. `geo`, `brand`). Reuses Epsilon's existing coordinate-metadata projection. |
| `channel_panel_current_spend` | tidy table, one row per `(channel, panel)` | `channel`, panel coordinates, `current_spend`, `panel_share_within_channel` |
| `channel_panel_optimized_spend` | tidy table, one row per `(channel, panel)` | `channel`, panel coordinates, `optimized_spend`, `panel_share_within_channel`. In v1, `panel_share_within_channel_optimized == panel_share_within_channel_current` by construction. |
| `panel_response_summary` | tidy table, one row per panel | panel coordinates, `current_response`, `optimized_response`, `response_delta`, `response_delta_share` (panel's share of total response uplift) |
| `channel_panel_response_summary` | tidy table, one row per `(channel, panel)` | channel, panel coordinates, `current_response_contribution`, `optimized_response_contribution`, `delta_response` |
| `channel_delta_audit` | tidy table, one row per optimized channel | `channel`, `observed_total_spend`, `optimized_total_spend`, `delta = optimized / observed`, `delta_min_observed_panel`, `delta_max_observed_panel`, `delta_in_validity_band::Bool` |
| `panel_curve_evaluation_audit` | tidy table, one row per `(channel, panel, point)` | optional debug artifact: spend used, response value, distance from observed-historical spend |

#### 6.3 Posterior uncertainty summaries

Optional but recommended in v1: per-channel and per-panel response credible intervals at the optimized allocation, computed by evaluating the per-draw response surface at the optimized allocation. The optimizer itself still uses posterior-mean surfaces (Phase 8 contract), but reporting must not hide posterior spread.

```
channel_optimized_response_quantiles      :: Dict{String, NamedTuple{(:q025, :q500, :q975)}}
panel_optimized_response_quantiles        :: Dict{Int,    NamedTuple{(:q025, :q500, :q975)}}
total_optimized_response_quantiles        :: NamedTuple{(:q025, :q500, :q975)}
```

This is the single most important safeguard against the "misleading precision" risk (Section 7.5).

#### 6.4 ROAS / mROAS / CPA / mCPA

In v1, report the **default efficiency** (ROAS for revenue, CPA for conversion) at three resolutions:

- aggregate (already in `optimized_default_efficiency`)
- per channel
- per `(channel, panel)`

Marginal ROAS / marginal CPA are derivable from the same monotone cubic interpolation derivative `∂f_{c,p}/∂x_c` already used by the solver. Expose them on the channel and `(channel, panel)` tables.

```julia
struct PanelChannelEfficiencySummary
    channel::String
    optimized_spend::Float64
    optimized_response_contribution::Float64
    average_efficiency::Float64       # ROAS or CPA depending on target_type
    marginal_efficiency::Float64      # mROAS or mCPA at the optimized point
end
```

Do **not** report panel-only ROAS without also reporting the underlying channel × panel breakdown — aggregated panel ROAS hides which channels drove the panel result and invites misinterpretation as a panel-targeting recommendation.

#### 6.5 Proposed Julia result type

```julia
struct PanelBudgetOptimizationResult
    # --- match BudgetOptimizationResult shape for tooling compatibility ---
    metadata::ModelArtifactMetadata
    spec::MMMModelSpec
    coordinate_metadata::ModelCoordinateMetadata
    objective::Symbol
    optimized_channels::Vector{String}
    fixed_channels::Vector{String}
    current_spend::Dict{String, Float64}            # channel-level
    optimized_spend::Dict{String, Float64}          # channel-level
    current_response::Float64
    optimized_response::Float64
    current_default_efficiency::Float64
    optimized_default_efficiency::Float64
    solver_status::Symbol
    objective_value::Float64
    convergence_metadata::Dict{String, Any}
    constraint_audit::BudgetConstraintAudit         # channel-level only in v1

    # --- panel-specific extensions ---
    panel_allocation_mode::Symbol                   # :historical_shares in v1; :free in v1.1
    panel_index::Vector{Int}                        # flat panel-cell axis
    panel_coordinates::DataFrame                    # declared coords keyed by panel_index
    historical_panel_shares::Matrix{Float64}        # (n_channels, n_panels)
    current_channel_panel_spend::Matrix{Float64}    # (n_channels, n_panels)
    optimized_channel_panel_spend::Matrix{Float64}  # (n_channels, n_panels)
    current_channel_panel_response::Matrix{Float64} # (n_channels, n_panels), posterior mean
    optimized_channel_panel_response::Matrix{Float64}
    channel_delta_audit::DataFrame                  # validity-band audit (Section 7.2)
    posterior_response_quantiles::DataFrame         # tidy: (channel?, panel?, q025, q500, q975)
end
```

The matrices are stored on the flat panel-cell axis; the `panel_coordinates` DataFrame is the canonical way to recover declared dimensions (e.g. geo × brand) for reporting.

---

## 7. Main methodological risks

The risks are roughly in order of practical severity.

### 7.1 Panel-conditional extrapolation along the delta dimension (HIGH)

The panel response curves are valid in a *band* around `δ = 1`, and that band is panel-specific (a function of the observed within-panel spend variability over the modelled horizon). The v1 design holds `δ` uniform across panels for any given channel, which makes this risk easy to surface — but it does not eliminate it.

**Mitigation:**

- Define a documented validity band for channel-level deltas, e.g. `δ ∈ [0.5, 2.0]` as a default soft warning threshold. Make the threshold configurable.
- In `channel_delta_audit`, emit `delta_in_validity_band::Bool` per channel and warn (don't fail) when violated.
- Document that "validity band" is heuristic: it is *not* a posterior-credible bound on the curve, just a flag for "the optimizer has moved this channel a long way from observed history."
- Optionally: extend the per-panel curve metadata in Stage 60 to record `(δ_min_observed, δ_max_observed)` per panel cell, where `δ_min_observed` is `min_t (spend_t / mean_t(spend))` and similarly for max. Surface this in the audit.

### 7.2 Identifiability under hierarchical pooling (HIGH for sparse panels)

Hierarchical panel models partially pool small-data panels toward the population. The fitted response curve for a sparse panel is, statistically, a smoothed reflection of the larger panels — it is not independent evidence about that panel.

**Mitigation:**

- Document the requirement that optimization is most defensible when each panel has a non-trivial amount of historical spend per channel.
- Surface `S_{c,p}^obs` per cell in the audit; let analysts see which cells are sparse.
- Strongly recommend (in docs) that analysts using small geos or rare brand × geo combinations interpret the per-panel optimized response with caution.
- This risk does *not* affect v1 channel-level allocation as much as it would v1.1 free panel allocation: in v1, the panel allocation is mechanically driven by historical shares, so sparse-panel curves are only weighted by their historical contribution to the channel total.

### 7.3 Panel heterogeneity collapsing to a channel curve (MEDIUM)

If all panels for a channel have similar response shapes, the channel-level optimization is essentially evaluating a single curve. If panels are very heterogeneous, summing per-panel curves is mathematically correct under v1 (because shares are fixed), but the *interpretation* of channel-level marginal ROAS gets less stable.

**Mitigation:**

- Provide the `channel_panel_response_summary` artifact so heterogeneity is visible, not hidden.
- Report marginal efficiency at both channel and channel × panel resolution.

### 7.4 Business-fairness drift (MEDIUM)

Even though v1 holds within-channel panel shares fixed, *between-channel* allocation changes can still shift relative emphasis across panels. For example, if channel A is geo-targeted to one region and channel B is national, reallocating budget from A to B will shift effective spend coverage across panels.

**Mitigation:**

- This is unavoidable as long as channels have differing geo distributions. The right surface is to expose `panel_response_summary` so the implied per-panel response shift is visible and auditable.
- Defer formal fairness constraints to v1.1.

### 7.5 Misleading precision from posterior-mean optimization (MEDIUM)

The optimizer is deterministic on posterior-mean surfaces. The reported optimum is a *point estimate*; the credible interval around it can be wide.

**Mitigation:**

- Always report posterior quantiles of total / channel / panel optimized response (Section 6.3).
- In docs and CLI output, prefer phrasing like "expected response under the posterior mean response surface" rather than "expected response."
- Provide a notebook recipe (not a v1 feature) for evaluating the chosen allocation across posterior draws to characterize allocation-conditional uncertainty.

### 7.6 Mismatch with adstock semantics under reallocation (MEDIUM — inherited)

The methodology audit already flagged that surface-based optimization carries over adstock from the *historical* spend path shape, not from the reallocated total. This is inherited from Phase 8 time series and does not get worse under v1 panel: because intra-channel panel shares are fixed, the within-panel intra-horizon shape is preserved exactly. Time-series-level adstock approximation is the same as time series and not panel-specific.

**Mitigation:** Inherit from time-series. Document the same caveat.

### 7.7 Fairness/business constraint misuse (LOW for v1, HIGH if v1.1 is opened prematurely)

If channel × panel bounds are eventually supported, analysts will use them as soft "fairness levers." Without careful design, infeasible combinations of channel-total, panel-total, and channel × panel bounds will become routine and the failure messages will be opaque.

**Mitigation:** When v1.1 opens, fully specify constraint-conflict diagnostics before solver orchestration. Do not open v1.1 until that design is settled.

---

## 8. Recommended v1 design summary, and explicit deferral list

### Implement in v1

- New file `src/optimization/panel.jl` implementing the panel-aware optimizer.
- Public entry point: dispatch `optimize_budget(results::InferenceResults; ...)` such that `PanelMMM` results route to the new panel builder.
- Decision variable: channel-level total spend; within-channel disaggregation by fixed historical panel shares.
- Default objective: `:total_response`, posterior-mean total response summed across panels and time, on the original target scale.
- Constraints in v1: total-budget equality, channel absolute bounds, channel relative bounds, channel subset selection.
- Solver: reuse Phase 8 JuMP/Ipopt + monotone cubic interpolation. The objective is `baseline + fixed + Σ_c [Σ_p f_{c,p}(x_c · w_{c,p})]`, registered as a smooth nonlinear operator per channel (one operator per channel, internally summing over panels).
- Artifacts: full panel result type (Section 6.5), channel-level scalars matching the time-series result, plus the new panel tables.
- Documentation: prominent warning block describing delta-validity bands, fixed-panel-share semantics, and the deferred channel × panel mode.
- Tests:
  - Construction parity with time-series optimizer when the panel model has a single panel.
  - Determinism: same inputs ⇒ same allocation ⇒ same audit.
  - Constraint audit correctness for absolute and relative bounds.
  - Negative coverage: rejecting `panel_bounds`, rejecting `panel_allocation_mode = :free`, rejecting unknown panel coordinate columns.
  - Validity-band warning triggered when delta exceeds default thresholds.
  - Posterior-quantile artifact populated and finite.

### Explicitly deferred (v1.1 and later)

- Channel × panel-cell free allocation (`panel_allocation_mode = :free`).
- Channel × panel absolute / relative bounds.
- Panel total bounds.
- Per-panel weighted objectives (`maximize Σ_p w_p · response_p`).
- Fairness constraints (min-per-panel-response guarantees, response Gini caps, equal-share-of-uplift constraints).
- Profit / utility objectives (requires extending the data contract with cost/margin coefficients).
- Cross-channel ratio constraints.
- Date-level pacing / intra-horizon shape decisions.
- Panel-aware holdout validation feeding optimizer trust regions (inherits from the deferred Stage 35 panel holdout).

### Out of scope permanently for Stage 70

- AI advisor surface.
- Dashboard parity.
- Scenario-planner-style draft overrides.

---

## 9. Implementation sketch

### 9.1 File layout

```
src/optimization/
  panel.jl           ← new: panel problem builder + dispatch
  panel_audit.jl     ← new: tidy-table artifact builders (panel coordinates, delta audit, etc.)
  types.jl           ← extend: add PanelBudgetOptimizationResult
  objective.jl       ← reuse: monotone cubic interpolation
  constraints.jl     ← reuse: channel constraint normalisation
  optimizer.jl       ← reuse: JuMP/Ipopt orchestration; replace per-channel operator with panel-summed operator
```

### 9.2 Channel operator under panel disaggregation

In `_register_channel_operator!`, replace the single-curve interpolation with a sum over panels:

```julia
function _register_panel_channel_operator!(model, channel_surfaces_per_panel, share_per_panel, index)
    n_panels = length(channel_surfaces_per_panel)
    interps = [_surface_interpolation(s, "optimize_budget") for s in channel_surfaces_per_panel]
    shares  = collect(share_per_panel)
    function evaluate(x::Float64)
        s = 0.0
        @inbounds for p in 1:n_panels
            s += _evaluate(interps[p], x * shares[p])
        end
        return s
    end
    function gradient(x::Float64)
        g = 0.0
        @inbounds for p in 1:n_panels
            g += _evaluate_derivative(interps[p], x * shares[p]) * shares[p]
        end
        return g
    end
    function hessian(x::Float64)
        h = 0.0
        @inbounds for p in 1:n_panels
            h += _evaluate_second_derivative(interps[p], x * shares[p]) * shares[p]^2
        end
        return h
    end
    op = Symbol("panel_budget_response_$(index)")
    JuMP.register(model, op, 1, evaluate, gradient, hessian)
    return op
end
```

This preserves the Phase 8 differentiability contract: the objective remains `C¹` (actually `C²`) in each `x_c` so Ipopt continues to work.

### 9.3 Per-channel spend grid for panel surfaces

For each optimized channel, build the channel-level grid using the same Phase 8 rule (`0`, `observed_total`, `total_budget`, finite bounds, sorted-unique), and translate it to a per-panel grid by multiplying by `w_{c,p}`. Use that to materialize each `f_{c,p}` via the existing panel response-curve machinery, then construct one interpolation per `(channel, panel)`.

### 9.4 Public API

```julia
function optimize_budget(
    results::InferenceResults{<:PanelMMM};
    total_budget::Real,
    channels = nothing,
    budget_bounds = nothing,         # channel-level only
    relative_bounds = nothing,       # channel-level only
    objective::Symbol = :total_response,
    grid = nothing,                  # channel-level grid; per-panel derived deterministically
    panel_allocation_mode::Symbol = :historical_shares,  # only :historical_shares supported in v1
    delta_validity_band::Tuple{Float64,Float64} = (0.5, 2.0),
)
    panel_allocation_mode === :historical_shares ||
        throw(ArgumentError("optimize_budget on PanelMMM supports only :historical_shares in v1; :free is deferred to v1.1"))
    # build PanelBudgetOptimizationProblem, solve, package PanelBudgetOptimizationResult
end
```

### 9.5 Docs warning block (mandatory)

The `optimize_budget` docstring for the panel method must include the following block verbatim or equivalent:

```
!!! warning "Panel optimization is bounded by design in v1"

    * The decision variable is the *channel-level* total spend across panels.
      Within each channel, spend is mechanically disaggregated to panels using
      historical panel shares (`s_{c,p} = (S_{c,p}^obs / S_c^obs) · x_c`).

    * Free panel-cell reallocation is *not* supported in v1
      (`panel_allocation_mode = :free` is reserved for v1.1 and will throw a
      contract error in this release).

    * Panel response curves use historical-scaling delta semantics: each panel's
      observed within-horizon spend shape is held fixed, and only the total scale
      is varied. Optimization results far outside the historical delta band
      (default `[0.5, 2.0]`) are flagged in `channel_delta_audit` but not blocked.
      Treat such allocations as exploratory, not validated.

    * The optimizer maximizes posterior-mean total response. Posterior credible
      intervals on the optimized response are reported in the result
      (`posterior_response_quantiles`) and should always be inspected before
      acting on a recommended allocation.

    * Sparse panels (panels with little historical spend on a given channel) are
      partially pooled by the hierarchical model. Their per-panel curves
      partially reflect the population-mean curve; this is statistically
      legitimate but should be communicated when reporting per-panel ROAS or
      per-panel optimized response.
```

---

## 10. Rationale: why this differs from v1 review

The v1 review (`stage-70-panel-optimization-design.md`) recommends free channel × panel-cell allocation in v1. That recommendation is internally consistent — it leverages the panel response curve granularity that Epsilon already produces — but it under-weights three things:

1. **The curve contract was not designed for non-uniform-delta evaluation.** The historical-scaling delta grid implicitly assumes the within-panel intra-horizon spend shape is fixed and only the scale is varied. Free panel reallocation breaks the uniform-delta assumption that makes the validity-band reasoning clean.
2. **Hierarchical pooling makes per-panel curves co-dependent.** Free reallocation toward sparse panels will be statistically optimistic in a way that is hard to communicate honestly to advertisers.
3. **The v1 review accepts that fixed-panel allocations are "approximated with tight panel-total bounds"**, but if panel-total bounds are present they are essentially the same primitive as free panel allocation with a bounding rectangle — and that primitive carries the same risks.

The bounded design philosophy that motivated Phase 8 ("freeze a small, statistically honest surface and refuse to invent semantics the underlying surfaces cannot certify") points to a smaller v1 surface that the v1 review proposes. v2 brings the recommendation in line with that philosophy.

When Stage 35 panel holdout or equivalent per-panel curve validation lands, opening v1.1 free panel allocation becomes defensible. Until then, channel-level allocation with historical within-channel shares is the surface that Epsilon can certify honestly.

---

## 11. Acceptance checklist

A Stage 70 panel implementation is complete when:

- [ ] `optimize_budget(results::InferenceResults{<:PanelMMM}; ...)` exists, dispatches correctly, returns `PanelBudgetOptimizationResult`.
- [ ] Single-panel models produce numerically identical optimization output to the time-series `optimize_budget` (deterministic parity, not just statistical agreement).
- [ ] Channel absolute bounds, channel relative bounds, channel subset selection all flow through the existing `BudgetConstraintAudit` primitive correctly.
- [ ] `panel_bounds`, `panel_allocation_mode = :free`, profit objectives, and any unsupported objective symbol raise `ArgumentError` with a clear message before solver construction.
- [ ] Per-channel `δ_c = x_c / S_c^obs` is computed and emitted in `channel_delta_audit`, with a `delta_in_validity_band::Bool` column.
- [ ] `posterior_response_quantiles` is populated and tested for finiteness and ordering (`q025 ≤ q500 ≤ q975`).
- [ ] Panel coordinate columns from `ModelCoordinateMetadata` are preserved in all per-panel tidy tables.
- [ ] Documentation includes the panel-optimization warning block verbatim.
- [ ] Negative-coverage tests exist for every deferred constraint family.

Once those land, Stage 70 has a statistically coherent v1 panel surface without overreaching into v1.1 territory.
