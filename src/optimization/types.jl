"""
    BudgetChannelConstraint

Typed per-channel constraint audit record for the bounded optimization
surface. `observed_spend`, absolute bounds, and effective bounds are all in the
same original channel units and time aggregation level as the fitted input data.
"""
struct BudgetChannelConstraint
    channel::String
    observed_spend::Float64
    absolute_lower::Union{Nothing, Float64}
    absolute_upper::Union{Nothing, Float64}
    relative_lower::Union{Nothing, Float64}
    relative_upper::Union{Nothing, Float64}
    effective_lower::Float64
    effective_upper::Union{Nothing, Float64}
end

function Base.:(==)(lhs::BudgetChannelConstraint, rhs::BudgetChannelConstraint)
    return lhs.channel == rhs.channel &&
        lhs.observed_spend == rhs.observed_spend &&
        lhs.absolute_lower == rhs.absolute_lower &&
        lhs.absolute_upper == rhs.absolute_upper &&
        lhs.relative_lower == rhs.relative_lower &&
        lhs.relative_upper == rhs.relative_upper &&
        lhs.effective_lower == rhs.effective_lower &&
        lhs.effective_upper == rhs.effective_upper
end

"""
    BudgetConstraintAudit

Typed normalized constraint bundle for one bounded optimization problem.
`total_budget` and all nested spend-like constraint values use the same
original channel units and time aggregation level as the fitted input data.
"""
struct BudgetConstraintAudit
    total_budget::Float64
    optimized_channels::Vector{String}
    fixed_channels::Vector{String}
    channel_constraints::Vector{BudgetChannelConstraint}
end

function Base.:(==)(lhs::BudgetConstraintAudit, rhs::BudgetConstraintAudit)
    return lhs.total_budget == rhs.total_budget &&
        lhs.optimized_channels == rhs.optimized_channels &&
        lhs.fixed_channels == rhs.fixed_channels &&
        lhs.channel_constraints == rhs.channel_constraints
end

"""
    BudgetChannelSurface

Typed posterior-mean response surface for one optimized media channel over the
bounded spend domain. `observed_spend`, `spend_grid`, and effective
bounds are expressed in the original units of that channel, matching the fitted
input data and optimizer budget units.
"""
struct BudgetChannelSurface
    channel::String
    observed_spend::Float64
    spend_grid::Vector{Float64}
    response_grid::Vector{Float64}
    effective_lower::Float64
    effective_upper::Union{Nothing, Float64}
end

function Base.:(==)(lhs::BudgetChannelSurface, rhs::BudgetChannelSurface)
    return lhs.channel == rhs.channel &&
        lhs.observed_spend == rhs.observed_spend &&
        lhs.spend_grid == rhs.spend_grid &&
        lhs.response_grid == rhs.response_grid &&
        lhs.effective_lower == rhs.effective_lower &&
        lhs.effective_upper == rhs.effective_upper
end

"""
    BudgetOptimizationProblem

Typed bounded optimization problem assembled from canonical grouped
`InferenceResults` plus the fixed constraint contract.

This is the solver-agnostic problem surface consumed by optimizer orchestration
rather than re-parsing public optimization kwargs.

All spend-like fields (`total_budget`, `current_spend`, `fixed_spend`, channel
surface spend grids, and constraint bounds) use the same original channel units
and time aggregation level as the fitted input data. Epsilon does not convert
currencies, weekly/monthly aggregation, or thousands/millions scaling inside
this typed problem.
"""
struct BudgetOptimizationProblem
    metadata::ModelArtifactMetadata
    spec::MMMModelSpec
    coordinate_metadata::ModelCoordinateMetadata
    objective::Symbol
    total_budget::Float64
    optimized_channels::Vector{String}
    fixed_channels::Vector{String}
    current_spend::Vector{Float64}
    fixed_spend::Vector{Float64}
    baseline_response::Float64
    fixed_response::Float64
    current_response::Float64
    channel_surfaces::Vector{BudgetChannelSurface}
    constraint_audit::BudgetConstraintAudit
end

function Base.:(==)(lhs::BudgetOptimizationProblem, rhs::BudgetOptimizationProblem)
    return lhs.metadata == rhs.metadata &&
        lhs.spec == rhs.spec &&
        lhs.coordinate_metadata == rhs.coordinate_metadata &&
        lhs.objective == rhs.objective &&
        lhs.total_budget == rhs.total_budget &&
        lhs.optimized_channels == rhs.optimized_channels &&
        lhs.fixed_channels == rhs.fixed_channels &&
        lhs.current_spend == rhs.current_spend &&
        lhs.fixed_spend == rhs.fixed_spend &&
        lhs.baseline_response == rhs.baseline_response &&
        lhs.fixed_response == rhs.fixed_response &&
        lhs.current_response == rhs.current_response &&
        lhs.channel_surfaces == rhs.channel_surfaces &&
        lhs.constraint_audit == rhs.constraint_audit
end

"""
    BudgetOptimizationResult

Typed canonical result surface for the public optimizer.

This typed artifact preserves the bounded optimizer output without exposing
solver-specific details in the public API. `current_spend`,
`optimized_spend`, and nested constraint audit spend values are reported in the
same original channel units and time aggregation level as the fitted input
data.
"""
struct BudgetOptimizationResult
    metadata::ModelArtifactMetadata
    spec::MMMModelSpec
    coordinate_metadata::ModelCoordinateMetadata
    objective::Symbol
    optimized_channels::Vector{String}
    fixed_channels::Vector{String}
    current_spend::Dict{String, Float64}
    optimized_spend::Dict{String, Float64}
    current_response::Float64
    optimized_response::Float64
    current_default_efficiency::Float64
    optimized_default_efficiency::Float64
    solver_status::Symbol
    objective_value::Float64
    convergence_metadata::Dict{String, Any}
    constraint_audit::BudgetConstraintAudit
end

function Base.:(==)(lhs::BudgetOptimizationResult, rhs::BudgetOptimizationResult)
    return lhs.metadata == rhs.metadata &&
        lhs.spec == rhs.spec &&
        lhs.coordinate_metadata == rhs.coordinate_metadata &&
        lhs.objective == rhs.objective &&
        lhs.optimized_channels == rhs.optimized_channels &&
        lhs.fixed_channels == rhs.fixed_channels &&
        lhs.current_spend == rhs.current_spend &&
        lhs.optimized_spend == rhs.optimized_spend &&
        lhs.current_response == rhs.current_response &&
        lhs.optimized_response == rhs.optimized_response &&
        lhs.current_default_efficiency == rhs.current_default_efficiency &&
        lhs.optimized_default_efficiency == rhs.optimized_default_efficiency &&
        lhs.solver_status == rhs.solver_status &&
        lhs.objective_value == rhs.objective_value &&
        lhs.convergence_metadata == rhs.convergence_metadata &&
        lhs.constraint_audit == rhs.constraint_audit
end

"""
    BudgetAllocationEvaluationResult

Typed posterior-draw evaluation for one fixed channel allocation.

This result scores an already supplied allocation without solving an
optimization problem or refitting the model. `allocation` and `total_budget`
use the same original channel units and time aggregation level as the fitted
model data. `response_draws` stores posterior total-response draws for the
allocation; `expected_response` is their mean.
"""
struct BudgetAllocationEvaluationResult
    metadata::ModelArtifactMetadata
    spec::MMMModelSpec
    coordinate_metadata::ModelCoordinateMetadata
    objective::Symbol
    allocation_kind::Symbol
    allocation::Dict{String, Float64}
    total_budget::Float64
    response_draws::Vector{Float64}
    expected_response::Float64
    default_efficiency::Float64
end

function Base.:(==)(
        lhs::BudgetAllocationEvaluationResult,
        rhs::BudgetAllocationEvaluationResult,
    )
    return lhs.metadata == rhs.metadata &&
        lhs.spec == rhs.spec &&
        lhs.coordinate_metadata == rhs.coordinate_metadata &&
        lhs.objective == rhs.objective &&
        lhs.allocation_kind == rhs.allocation_kind &&
        lhs.allocation == rhs.allocation &&
        lhs.total_budget == rhs.total_budget &&
        lhs.response_draws == rhs.response_draws &&
        lhs.expected_response == rhs.expected_response &&
        lhs.default_efficiency == rhs.default_efficiency
end

"""
    BudgetAllocationDecisionSummary

Typed posterior decision summary for one evaluated allocation against a
reference allocation.

Response fields summarise the evaluated allocation's posterior total-response
draws. Uplift fields summarise paired draw differences against the reference
allocation. Percentage uplift is draw-wise uplift divided by the reference draw
where numerically defined. `probability_beats_reference` is the posterior share
of paired draws where the evaluated allocation exceeds the reference.
"""
struct BudgetAllocationDecisionSummary
    metadata::ModelArtifactMetadata
    spec::MMMModelSpec
    coordinate_metadata::ModelCoordinateMetadata
    objective::Symbol
    reference_allocation_kind::Symbol
    allocation_kind::Symbol
    allocation::Dict{String, Float64}
    total_budget::Float64
    interval_probability::Float64
    response_mean::Float64
    response_median::Float64
    response_std::Float64
    response_interval_lower::Float64
    response_interval_upper::Float64
    uplift_mean::Float64
    uplift_median::Float64
    uplift_std::Float64
    uplift_interval_lower::Float64
    uplift_interval_upper::Float64
    uplift_pct_mean::Float64
    uplift_pct_median::Float64
    uplift_pct_interval_lower::Float64
    uplift_pct_interval_upper::Float64
    probability_beats_reference::Float64
end

function Base.:(==)(
        lhs::BudgetAllocationDecisionSummary,
        rhs::BudgetAllocationDecisionSummary,
    )
    return lhs.metadata == rhs.metadata &&
        lhs.spec == rhs.spec &&
        lhs.coordinate_metadata == rhs.coordinate_metadata &&
        lhs.objective == rhs.objective &&
        lhs.reference_allocation_kind == rhs.reference_allocation_kind &&
        lhs.allocation_kind == rhs.allocation_kind &&
        lhs.allocation == rhs.allocation &&
        lhs.total_budget == rhs.total_budget &&
        lhs.interval_probability == rhs.interval_probability &&
        lhs.response_mean == rhs.response_mean &&
        lhs.response_median == rhs.response_median &&
        lhs.response_std == rhs.response_std &&
        lhs.response_interval_lower == rhs.response_interval_lower &&
        lhs.response_interval_upper == rhs.response_interval_upper &&
        lhs.uplift_mean == rhs.uplift_mean &&
        lhs.uplift_median == rhs.uplift_median &&
        lhs.uplift_std == rhs.uplift_std &&
        lhs.uplift_interval_lower == rhs.uplift_interval_lower &&
        lhs.uplift_interval_upper == rhs.uplift_interval_upper &&
        lhs.uplift_pct_mean == rhs.uplift_pct_mean &&
        lhs.uplift_pct_median == rhs.uplift_pct_median &&
        lhs.uplift_pct_interval_lower == rhs.uplift_pct_interval_lower &&
        lhs.uplift_pct_interval_upper == rhs.uplift_pct_interval_upper &&
        lhs.probability_beats_reference == rhs.probability_beats_reference
end

const _SUPPORTED_BUDGET_UTILITIES = (
    :mean_response,
    :lower_interval_response,
    :probability_of_improvement,
    :risk_adjusted_response,
)

function _budget_utility_symbol(utility)
    symbol = if utility isa Symbol
        utility
    elseif utility isa AbstractString
        Symbol(lowercase(String(utility)))
    else
        throw(ArgumentError("budget utility must be a Symbol or string"))
    end
    symbol in _SUPPORTED_BUDGET_UTILITIES ||
        throw(
        ArgumentError(
            "unsupported budget utility `$symbol`; supported utilities are $(join(_SUPPORTED_BUDGET_UTILITIES, ", "))",
        ),
    )
    return symbol
end

function _budget_utility_interval_probability(interval_probability)
    probability = Float64(interval_probability)
    isfinite(probability) && 0.0 < probability < 1.0 ||
        throw(ArgumentError("budget utility interval_probability must be in (0, 1)"))
    return probability
end

function _budget_utility_risk_aversion(risk_aversion)
    value = Float64(risk_aversion)
    isfinite(value) && value >= 0.0 ||
        throw(ArgumentError("budget utility risk_aversion must be finite and nonnegative"))
    return value
end

"""
    BudgetUtilitySpec(utility=:mean_response; interval_probability=0.9, risk_aversion=1.0)

Typed utility-function contract for posterior budget-allocation decisions.

Supported utilities are:

- `:mean_response`
- `:lower_interval_response`
- `:probability_of_improvement`
- `:risk_adjusted_response`

The default utility is posterior mean response, matching the existing bounded
optimiser's maintained objective. `interval_probability` controls the lower
credible-bound utility. `risk_aversion` controls the standard-deviation penalty
for risk-adjusted response.
"""
struct BudgetUtilitySpec
    utility::Symbol
    interval_probability::Float64
    risk_aversion::Float64
end

function BudgetUtilitySpec(
        utility = :mean_response;
        interval_probability = 0.9,
        risk_aversion = 1.0,
    )
    return BudgetUtilitySpec(
        _budget_utility_symbol(utility),
        _budget_utility_interval_probability(interval_probability),
        _budget_utility_risk_aversion(risk_aversion),
    )
end

"""
    PanelBudgetOptimizationResult

Typed canonical result surface for panel budget optimization.

Panel optimization preserves the Stage 60 panel response-curve contract by
optimizing channel-level budget totals and applying each channel's historical
panel-cell spend shares to the optimized total. The result therefore exposes
the same channel-level allocation fields as `BudgetOptimizationResult` plus
panel-cell audit matrices for downstream reporting.

Channel-level and panel-cell spend fields use the same original channel units
and time aggregation level as the fitted `PanelMMMData` channels. Historical
panel shares distribute those channel totals; they do not perform currency,
calendar aggregation, or unit conversion.
"""
struct PanelBudgetOptimizationResult
    metadata::ModelArtifactMetadata
    spec::MMMModelSpec
    coordinate_metadata::ModelCoordinateMetadata
    objective::Symbol
    optimized_channels::Vector{String}
    fixed_channels::Vector{String}
    current_spend::Dict{String, Float64}
    optimized_spend::Dict{String, Float64}
    current_response::Float64
    optimized_response::Float64
    current_default_efficiency::Float64
    optimized_default_efficiency::Float64
    solver_status::Symbol
    objective_value::Float64
    convergence_metadata::Dict{String, Any}
    constraint_audit::BudgetConstraintAudit
    panel_allocation_mode::Symbol
    panel_names::Vector{String}
    panel_coordinates::Dict{String, Vector{String}}
    historical_panel_shares::Matrix{Float64}
    current_channel_panel_spend::Matrix{Float64}
    optimized_channel_panel_spend::Matrix{Float64}
    current_channel_panel_response::Matrix{Float64}
    optimized_channel_panel_response::Matrix{Float64}
    channel_delta::Dict{String, Float64}
end

function Base.:(==)(lhs::PanelBudgetOptimizationResult, rhs::PanelBudgetOptimizationResult)
    return lhs.metadata == rhs.metadata &&
        lhs.spec == rhs.spec &&
        lhs.coordinate_metadata == rhs.coordinate_metadata &&
        lhs.objective == rhs.objective &&
        lhs.optimized_channels == rhs.optimized_channels &&
        lhs.fixed_channels == rhs.fixed_channels &&
        lhs.current_spend == rhs.current_spend &&
        lhs.optimized_spend == rhs.optimized_spend &&
        lhs.current_response == rhs.current_response &&
        lhs.optimized_response == rhs.optimized_response &&
        lhs.current_default_efficiency == rhs.current_default_efficiency &&
        lhs.optimized_default_efficiency == rhs.optimized_default_efficiency &&
        lhs.solver_status == rhs.solver_status &&
        lhs.objective_value == rhs.objective_value &&
        lhs.convergence_metadata == rhs.convergence_metadata &&
        lhs.constraint_audit == rhs.constraint_audit &&
        lhs.panel_allocation_mode == rhs.panel_allocation_mode &&
        lhs.panel_names == rhs.panel_names &&
        lhs.panel_coordinates == rhs.panel_coordinates &&
        lhs.historical_panel_shares == rhs.historical_panel_shares &&
        lhs.current_channel_panel_spend == rhs.current_channel_panel_spend &&
        lhs.optimized_channel_panel_spend == rhs.optimized_channel_panel_spend &&
        lhs.current_channel_panel_response == rhs.current_channel_panel_response &&
        lhs.optimized_channel_panel_response == rhs.optimized_channel_panel_response &&
        lhs.channel_delta == rhs.channel_delta
end

"""
    BudgetOptimizationDiagnostics

Typed audit surface for one solved bounded budget optimisation result.

This result summarises the total-spend, total-response, default-efficiency,
marginal-response, solver, and constraint state of an existing
`BudgetOptimizationResult` or `PanelBudgetOptimizationResult`. It does not
change the solved allocation and does not imply per-channel response
attribution; channel-level diagnostics are reported separately through
`optimization_diagnostics_table`.
"""
struct BudgetOptimizationDiagnostics
    metadata::ModelArtifactMetadata
    spec::MMMModelSpec
    coordinate_metadata::ModelCoordinateMetadata
    objective::Symbol
    solver_status::Symbol
    optimized_channels::Vector{String}
    fixed_channels::Vector{String}
    current_total_spend::Float64
    optimized_total_spend::Float64
    spend_delta::Float64
    current_response::Float64
    optimized_response::Float64
    response_delta::Float64
    response_lift_pct::Float64
    current_default_efficiency::Float64
    optimized_default_efficiency::Float64
    default_efficiency_delta::Float64
    default_efficiency_lift_pct::Float64
    current_marginal_response::Dict{String, Float64}
    optimized_marginal_response::Dict{String, Float64}
    convergence_metadata::Dict{String, Any}
    constraint_audit::BudgetConstraintAudit
end

function Base.:(==)(lhs::BudgetOptimizationDiagnostics, rhs::BudgetOptimizationDiagnostics)
    return lhs.metadata == rhs.metadata &&
        lhs.spec == rhs.spec &&
        lhs.coordinate_metadata == rhs.coordinate_metadata &&
        lhs.objective == rhs.objective &&
        lhs.solver_status == rhs.solver_status &&
        lhs.optimized_channels == rhs.optimized_channels &&
        lhs.fixed_channels == rhs.fixed_channels &&
        lhs.current_total_spend == rhs.current_total_spend &&
        lhs.optimized_total_spend == rhs.optimized_total_spend &&
        lhs.spend_delta == rhs.spend_delta &&
        lhs.current_response == rhs.current_response &&
        lhs.optimized_response == rhs.optimized_response &&
        lhs.response_delta == rhs.response_delta &&
        lhs.response_lift_pct == rhs.response_lift_pct &&
        lhs.current_default_efficiency == rhs.current_default_efficiency &&
        lhs.optimized_default_efficiency == rhs.optimized_default_efficiency &&
        lhs.default_efficiency_delta == rhs.default_efficiency_delta &&
        lhs.default_efficiency_lift_pct == rhs.default_efficiency_lift_pct &&
        lhs.current_marginal_response == rhs.current_marginal_response &&
        lhs.optimized_marginal_response == rhs.optimized_marginal_response &&
        lhs.convergence_metadata == rhs.convergence_metadata &&
        lhs.constraint_audit == rhs.constraint_audit
end
