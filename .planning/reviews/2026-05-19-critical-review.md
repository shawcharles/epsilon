# Epsilon.jl Critical Review
**Date**: 2026-05-19  
**Reviewer**: Senior Software Engineer (AI)  
**Scope**: Code Quality, Logic/Correctness, Architecture

---

## Executive Summary

Epsilon.jl is a well-structured Julia-native Bayesian MMM library that successfully ports Abacus methodology while maintaining cleaner boundaries. The codebase demonstrates strong statistical rigor in transforms, inference, and postmodel analytics. However, several critical issues require immediate attention: **misnamed saturation function**, **excessive public API surface**, and **undocumented panel-flattening semantics**.

**Overall Assessment**: B- (Strong foundation, targeted fixes needed before v1.0)

---

## 1. Critical Issues (Fix Immediately)

### 1.1 Misnamed `logistic_saturation` — Correctness Risk
**Location**: `src/transforms/saturation.jl`

**Problem**: The function `logistic_saturation(x, λ)` implements `tanh(λx/2)`, which is **not** the logistic function. The standard logistic is `1/(1 + exp(-kx))`. This creates severe risks:
- Users expecting logistic saturation get hyperbolic tangent
- Breaks methodological parity with Abacus (which uses actual logistic)
- Undermines scientific reproducibility

**Recommendation**:
```julia
# RENAME and introduce proper logistic
function tanh_saturation(x::Real, λ::Real; b=1.0)
    # Current implementation: tanh(λ*x/2) scaled by b
    return b * tanh(λ * x / 2)
end

function logistic_saturation(x::Real, k::Real)
    # Proper logistic: 1/(1 + exp(-k*x))
    return 1.0 / (1.0 + exp(-k * x))
end
```

**Migration Path**: Deprecate `logistic_saturation` in favor of `tanh_saturation` for the current behavior, add proper `logistic_saturation`.

---

### 1.2 Excessive Public API Surface — Maintainability Risk
**Location**: `src/Epsilon.jl` (150+ exports)

**Problem**: Exporting 150+ symbols creates:
- Namespace pollution for users
- Difficulty tracking breaking changes
- Unclear distinction between public API and internals

**Recommendation**: Adopt a **tiered export strategy**:
```julia
# Tier 1: Core public API (export these)
export fit!, approximate_fit!, predict, prior_predict
export ModelConfig, ModelResults, InferenceResults
export build_model, run_pipeline
export @prior, NormalPrior, BetaPrior  # key priors only

# Tier 2: Expert API (don't export, access via Epsilon.Transforms.logistic_saturation)
# All transforms, internal types, diagnostics

# Tier 3: Internal (never exported)
# All _prefixed functions, internal structs
```

---

### 1.3 Panel Coordinate Semantics Undocumented
**Location**: `src/mmm/panel.jl`, `src/postmodel/types.jl`

**Problem**: The "deterministic flat panel-cell axis" design is powerful but:
- No documentation on coordinate reconstruction from flat indices
- Unclear how multi-dimensional panels (geo × brand) map to flat indices
- `ContributionResults` has dimension `draw × time × panel × component` but "panel" meaning is ambiguous

**Recommendation**: Add `PanelCoordinate` struct and coordinate mapping utilities:
```julia
struct PanelCoordinate
    indices::NamedTuple  # (geo=1, brand=3)
    flat_index::Int      # deterministic mapping
end

function panel_coordinates(panel_dims::NamedTuple)::Vector{PanelCoordinate}
    # Generate all coordinate combinations with deterministic flat mapping
end
```

---

## 2. Code Quality Assessment

### Strengths
- **Type stability**: Good use of parametric types (`ModelResults{T}`, `InferenceResults{T}`)
- **Test coverage**: Strong validation suite with Abacus parity tests
- **Transforms**: Clean implementations of adstock/saturation with proper parameter validation
- **Inference**: Proper Turing.jl integration with NUTS, diagnostics bundling

### Weaknesses
- **Module file**: `src/Epsilon.jl` is a 200+ line include/export list with no clear grouping comments
- **Error messages**: Some transforms lack user-friendly error messages for parameter violations
- **Documentation**: Missing docstrings on ~40% of public functions (spot-checked)

### Recommendation
Add structured docstrings with examples:
```julia
"""
    hill_function(x, κ, s)

Hill function saturation: `1 - κ^s / (κ^s + x^s)`

# Arguments
- `x::Real`: Input spend value
- `κ::Real`: Half-saturation constant (spend at 50% response)
- `s::Real`: Hill coefficient (steepness)

# Example
```julia
julia> hill_function(100.0, 50.0, 2.0)
0.8
```
"""
```

---

## 3. Logic and Correctness

### Verified Correct
- ✅ All adstock implementations (binomial, geometric, delayed, weibull)
- ✅ Saturation functions (except naming issue above)
- ✅ Response curve computation with historical-scaling delta grid
- ✅ Contribution decomposition (additive components)
- ✅ Metric calculations (ROAS, mROAS, CPA) via finite differences
- ✅ MCMC diagnostics integration (rhat, ess, divergences)

### Concern: Response Curve Grid Semantics
**Location**: `src/postmodel/response_curves.jl`

The "historical-scaling delta grid" is methodologically sound but its configuration is buried. Users need clarity on:
- What delta values are used
- How historical scaling factor is computed
- Why this is preferred over aggregate spend grid (hint: preserves channel-specific distributions)

**Recommendation**: Expose grid configuration in `ModelConfig`:
```julia
@kwdef struct ResponseCurveConfig
    grid_type::Symbol = :historical_delta  # :historical_delta or :spend_range
    n_points::Int = 100
    delta_range::Tuple{Float64,Float64} = (-0.5, 2.0)  # as fraction of historical
end
```

---

## 4. Architectural Assessment

### Strengths
- **Clean separation**: `mmm/` (specification) vs `model/` (building) vs `postmodel/` (analytics)
- **Result immutability**: `ModelResults`, `InferenceResults` are well-typed containers
- **Pipeline orchestration**: `pipeline/` provides reproducible CLI workflow
- **Validation**: Parity tests against Abacus are robust

### Weaknesses
- **Circular dependencies risk**: With 150+ exports, hard to track dependencies
- **Panel optimization scope**: `src/optimization/panel.jl` only supports `:historical_shares` allocation—limits use cases
- **Scenario planner**: `scenario_planner.jl` is isolated, unclear integration with core types

### Architectural Recommendation: Introduce `Analysis` Abstraction
Currently, postmodel results are computed ad-hoc. Introduce a unified analysis workflow:

```julia
abstract type AbstractAnalysis end

struct ResponseCurveAnalysis <: AbstractAnalysis
    config::ResponseCurveConfig
    results::ResponseCurveResults
end

struct ContributionAnalysis <: AbstractAnalysis
    results::ContributionResults
    decomposition::DecompositionResults
end

function run_analysis!(model_results::ModelResults, ::Type{ResponseCurveAnalysis})
    # Centralized analysis dispatch
end
```

This enables:
- Lazy evaluation of expensive postmodel computations
- Caching of intermediate results
- Extensibility for new analysis types

---

## 5. Proposed Artifact Schemas

### 5.1 Enhanced `ModelResults` Schema
```julia
struct ModelResults{T<:AbstractFloat}
    # Existing fields...
    posterior_draws::Array{T,3}    # draw × time × [panel]
    posterior_predictive::Array{T,3}
    
    # NEW: Coordinate metadata
    coordinate_metadata::CoordinateMetadata
    
    # NEW: Analysis cache
    analysis_cache::Dict{Symbol,AbstractAnalysis}
end

struct CoordinateMetadata
    panel_dims::Union{Nothing,NamedTuple}  # (geo=5, brand=3) or nothing
    panel_coordinates::Union{Nothing,Vector{PanelCoordinate}}
    time_coordinates::Vector{Date}
    channel_names::Vector{String}
end
```

### 5.2 `ResponseCurveResults` Schema (Verified Correct)
Current schema is sound:
```julia
struct ResponseCurveResults{T<:AbstractFloat}
    draws::Array{T,3}           # draw × panel × spend_point (or 2D for timeseries)
    spend_grid::Matrix{T}       # panel × spend_point
    delta_values::Vector{T}      # historical scaling deltas
    channel_names::Vector{String}
    panel_coordinates::Union{Nothing,Vector{PanelCoordinate}}
end
```

No changes needed—this is well-designed.

---

## 6. Documentation Warnings Needed

Add these warnings to `docs/src/index.md` and function docstrings:

### 6.1 Saturation Function Warning
```julia
!!! warning "Saturation Function Naming"
    `logistic_saturation` in versions < 0.3 actually implements hyperbolic tangent.
    Use `tanh_saturation` for the current behavior, or `logistic_saturation` (v0.3+)
    for proper logistic function.
```

### 6.2 Panel Flat Index Warning
```julia
!!! note "Panel Coordinate Mapping"
    Multi-dimensional panels (e.g., geo × brand) are flattened to a 1D axis
    using lexicographic ordering of coordinate combinations. Use
    `panel_coordinates(panel_dims)` to reconstruct named coordinates from
    flat indices in results.
```

### 6.3 Response Curve Grid Warning
```julia
!!! warning "Historical-Scaling Delta Grid"
    Response curves use historical-scaling deltas (not aggregate spend ranges)
    to preserve channel-specific spend distributions. This means:
    - x-axis represents fractional changes from historical spend
    - Curves are comparable across channels with different spend scales
    - Grid is centered on observed historical values
```

---

## 7. Implementation Priority

### P0 (Fix in < 1 week)
1. **Rename `logistic_saturation`** → `tanh_saturation`, add proper logistic
2. **Add deprecation warnings** for renamed functions
3. **Document panel coordinate mapping** in `panel.jl`

### P1 (Fix in < 1 month)
4. **Tier the public API** — reduce exports to ~30 core symbols
5. **Add `CoordinateMetadata`** to `ModelResults`
6. **Document all saturation functions** with examples

### P2 (Fix before v1.0)
7. **Introduce `AbstractAnalysis`** abstraction
8. **Expose response curve config** in `ModelConfig`
9. **Add scenario planner integration** tests

---

## 8. Statistical/Methodological Notes

### Correctness Verified
- Adstock weight normalization ✓
- Saturation parameter bounds ✓
- MCMC NUTS sampling ✓
- Turing integration ✓
- Posterior predictive checks ✓

### Abacus Parity
- Parity tests in `test/validation/parity.jl` are comprehensive
- Recommend adding automated parity CI check against pinned Abacus commit

---

## Conclusion

Epsilon.jl is **architecturally sound** with **correct core logic**. The P0 issues (misnamed saturation, undocumented panel semantics) are straightforward fixes that will prevent user confusion and methodological errors. The P1/P2 recommendations will improve maintainability and extensibility for v1.0.

**Next Steps**:
1. Create GitHub issues for P0/P1/P2 items
2. Implement P0 fixes in a `fix/saturation-naming` branch
3. Update documentation with warnings above
4. Consider adopting [Semantic Versioning](https://semver.org/) explicitly before v1.0