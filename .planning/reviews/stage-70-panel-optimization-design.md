# Stage 70 Panel Budget Optimization Design Recommendation for Epsilon.jl

## Executive Summary

**Verdict**: Include panel optimization in v1 with channel × panel-cell allocation, maximizing total expected response across all panels. Leverage existing panel response curve infrastructure (`(draw, panel, spend_point)` granularity) to build a statistically coherent optimization surface that preserves panel heterogeneity.

---

## 1. Should panel optimization be included in v1?
**Answer: YES**

**Rationale**:
- Panel response curves already implemented at panel-cell level (`ResponseCurveResults.values` dims: `(draw, panel, spend_point)`)
- `PanelMMM` is a first-class model kind in Epsilon with complete post-model artifacts
- Deferring creates an artificial feature gap between model fitting and optimization
- Core infrastructure (response curves, contribution replay) already supports panel-counterfactual evaluation

---

## 2. First supported allocation level
**Answer: Channel × panel-cell allocation**

**Rationale**:
- Matches existing response curve granularity (curves already computed per panel-cell)
- Preserves panel heterogeneity captured by hierarchical panel parameters
- Avoids information loss from aggregating to channel-only or channel × declared dimension
- Internal flat panel-cell axis is already the canonical representation for multidimensional panels

**Proposed Allocation Matrix**:
```julia
# allocation: (n_optimized_channels, n_panels)
# Each entry represents spend for channel i in panel j
```

---

## 3. Default objective
**Answer: Maximize total expected response across all panels (`:total_response`)**

**Rationale**:
- Directly analogous to time-series `optimize_budget` objective
- Well-defined: sum of posterior-mean response across all panels and time periods
- Avoids premature complexity (profit/utility requires cost data and pricing assumptions not yet in Epsilon's data contract)
- Consistent with existing `BudgetOptimizationProblem` objective field

**Evaluation Formula**:
```julia
total_response = baseline_response + fixed_response + 
                sum over (channel, panel) of response_curve(channel, panel, spend)
```

---

## 4. Incremental budget distribution across panels
**Answer: Optimized freely across panels**

**Rationale**:
- Historical panel shares may reflect historical constraints, not optimal allocation
- Response curves already capture panel-specific saturation/adstock properties
- Business constraints can be applied via panel-total bounds if needed
- Free optimization allows the solver to exploit panel heterogeneity naturally

**Note**: Optimizer determines optimal distribution; no preset sharing required.

---

## 5. Constraints for v1
**Supported in v1**:
- **Channel × panel bounds**: Per `(channel, panel)` absolute/relative bounds
- **Panel total bounds**: Min/max total spend per panel
- **Fixed channels**: Channels excluded from optimization (existing behavior)
- **Channel bounds**: Aggregate bounds across all panels for a channel

**Explicitly deferred**:
- Fixed panel allocations (approximated with tight panel-total bounds)
- Minimum/maximum spend share constraints (v1.1)
- Advanced fairness constraints (v2.0)

**Proposed Constraint Types**:
```julia
struct PanelBudgetChannelConstraint
    channel::String
    panel::String
    observed_spend::Float64
    absolute_lower::Union{Nothing, Float64}
    absolute_upper::Union{Nothing, Float64}
    relative_lower::Union{Nothing, Float64}
    relative_upper::Union{Nothing, Float64}
    effective_lower::Float64
    effective_upper::Union{Nothing, Float64}
end

struct PanelTotalConstraint
    panel::String
    lower::Union{Nothing, Float64}
    upper::Union{Nothing, Float64}
end

struct PanelBudgetConstraintAudit
    total_budget::Float64
    optimized_channels::Vector{String}
    fixed_channels::Vector{String}
    panel_names::Vector{String}
    channel_panel_constraints::Matrix{PanelBudgetChannelConstraint}  # (channel, panel)
    panel_total_constraints::Vector{PanelTotalConstraint}
end
```

---

## 6. Summary artifacts to emit

**Required outputs**:

| Artifact | Type | Dimensions |
|----------|------|------------|
| Aggregate channel allocation | `Dict{String, Float64}` | channel → total spend |
| Channel × panel allocation | `Matrix{Float64}` | (channel, panel) |
| Panel-level allocation | `Vector{Float64}` | panel total |
| Expected response distributions | `Matrix{Float64}` | (draw, panel) |
| Channel ROAS | `Dict{String, Float64}` | channel → ROAS |
| Channel × panel ROAS | `Matrix{Float64}` | (channel, panel) |
| Panel ROAS | `Vector{Float64}` | panel → ROAS |

**Extended Result Type**:
```julia
struct PanelBudgetOptimizationResult
    metadata::ModelArtifactMetadata
    spec::MMMModelSpec
    coordinate_metadata::ModelCoordinateMetadata
    objective::Symbol
    optimized_channels::Vector{String}
    fixed_channels::Vector{String}
    panel_names::Vector{String}
    
    # Spend allocations
    current_spend::Matrix{Float64}  # (channel, panel)
    optimized_spend::Matrix{Float64}  # (channel, panel)
    
    # Response metrics
    current_response::Float64
    optimized_response::Float64
    current_default_efficiency::Float64
    optimized_default_efficiency::Float64
    
    # Solver metadata
    solver_status::Symbol
    objective_value::Float64
    convergence_metadata::Dict{String, Any}
    constraint_audit::PanelBudgetConstraintAudit
    
    # New v1 artifacts
    response_distributions::Matrix{Float64}  # (draw, panel)
    channel_roas::Dict{String, Float64}
    channel_panel_roas::Matrix{Float64}
    panel_roas::Vector{Float64}
end
```

---

## 7. Main methodological risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| **Identifiability** | High | Document requirement for sufficient data per panel; prefer hierarchical pooling for small panels |
| **Extrapolation beyond historical panel spend** | High | Use historical-scaling delta grid (existing panel curve contract); warn when optimized spend exceeds observed range |
| **Panel heterogeneity** | Medium | Naturally handled by panel-specific response curves; optimizer exploits heterogeneity |
| **Fairness/business constraints** | Medium | Support panel-total bounds in v1; defer advanced fairness to v1.1 |
| **Misleading precision from posterior summaries** | Medium | Report credible intervals for response/ROAS; warn about small-panel inference in docs |

---

## 8. Recommended v1 Design & Deferral List

### Implement in v1
- [x] Channel × panel-cell allocation (flat panel axis)
- [x] Maximize total expected response objective
- [x] Channel × panel bounds + panel total bounds
- [x] Full summary artifacts (channel, panel, channel×panel levels)
- [x] Integration with existing `optimize_budget` API (new method for `InferenceResults{<:PanelMMM}`)

### Explicitly Defer
- [ ] Profit/utility objectives (requires cost data architecture)
- [ ] Channel × declared dimension allocation (e.g., channel × geo) — flat panel-cell is more fundamental
- [ ] Advanced fairness constraints (Gini coefficients, min-response guarantees)
- [ ] Panel holdout validation (already deferred per project context)
- [ ] Fixed panel allocations (approximated with tight bounds)

---

## Implementation Sketch

### New file: `src/optimization/panel.jl`

**Key functions**:
1. `_build_panel_budget_optimization_problem(results::InferenceResults; ...)`
   - Assemble optimization problem from panel `InferenceResults`
   - Build per-channel per-panel response surfaces from `ResponseCurveResults`
   - Compute baseline/fixed response using panel contributions

2. `_evaluate_panel_budget_objective(problem, allocation_matrix)`
   - Evaluate total response at `(n_channels, n_panels)` allocation
   - Sum across channels, panels, and time (using posterior-mean curves)

3. `optimize_budget(results::InferenceResults{<:PanelMMM}; ...)`
   - Main API method (extends existing `optimize_budget` for time-series)
   - Accepts: `total_budget`, `channels`, `budget_bounds` (nested channel→panel), `panel_bounds`, `delta_grid`

4. `panel_budget_impact_table(result::PanelBudgetOptimizationResult)`
   - Channel×panel impact summary (current vs. optimized spend/response)

5. `panel_budget_audit_table(result::PanelBudgetOptimizationResult)`
   - Constraint audit at channel×panel and panel-total level

### API Extension
```julia
# Existing time-series method
function optimize_budget(results::InferenceResults{<:TimeSeriesMMM}; kwargs...)

# New panel method
function optimize_budget(
    results::InferenceResults{<:PanelMMM};
    total_budget::Real,
    channels = nothing,
    budget_bounds = nothing,  # Dict(channel => Dict(panel => (lower=..., upper=...)))
    panel_bounds = nothing,    # Dict(panel => (lower=..., upper=...))
    delta_grid = nothing,      # Historical-scaling grid for response curves
    objective = :total_response,
)
    # Build panel optimization problem
    # Run solver (reuse existing optimizer infrastructure)
    # Return PanelBudgetOptimizationResult
end
```

---

## Documentation Warnings

Add to `optimize_budget` docstring for panel results:

```julia
"""
    optimize_budget(results::InferenceResults{<:PanelMMM}; ...)

Optimize budget allocation for panel MMM.

!!! warning "Panel Optimization Caveats"
    1. Panel optimization requires sufficient data per panel for identifiable 
       response curves. Panels with sparse spend history may produce unreliable 
       optimization results.
    2. Response curves use historical-scaling semantics (delta grid). Optimized 
       spend levels far outside historical ranges may extrapolate beyond the 
       validated curve domain.
    3. The optimizer freely allocates across panels by default. Apply 
       `panel_bounds` if business constraints require specific panel allocations.
    4. Optimization uses posterior-mean response surfaces. Examine 
       `response_distributions` in the result to assess posterior uncertainty.
    5. For panels with few observations, prefer hierarchical prior sharing 
       (e.g., `prior.dims = ["channel", "geo"]`) to improve identifiability.
"""
```

---

## Rationale for Coherence with Epsilon Design Philosophy

1. **Leverages existing infrastructure**: Uses panel response curves, contribution replay, and coordinate metadata already implemented
2. **Preserves panel heterogeneity**: Doesn't aggregate away the panel structure the model worked to capture
3. **Consistent with time-series optimization**: Same objective, similar constraint contract, extended for panel dimensions
4. **Statistically honest**: Reports posterior distributions, warns about extrapolation and identifiability
5. **Bounded scope for v1**: Defers complex objectives (profit) and fairness constraints until core surface is validated