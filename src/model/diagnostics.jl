using MCMCChains
using Statistics

"""
    ParameterDiagnostics

Typed convergence and Monte Carlo error diagnostics for one parameter.
"""
struct ParameterDiagnostics
    rhat::Union{Missing, Float64}
    ess_bulk::Union{Missing, Float64}
    ess_tail::Union{Missing, Float64}
    mcse_mean::Union{Missing, Float64}
end

function Base.:(==)(lhs::ParameterDiagnostics, rhs::ParameterDiagnostics)
    return lhs.rhat == rhs.rhat &&
        lhs.ess_bulk == rhs.ess_bulk &&
        lhs.ess_tail == rhs.ess_tail &&
        lhs.mcse_mean == rhs.mcse_mean
end

"""
    ModelDiagnostics

Typed diagnostic summary extracted from fitted posterior chains.
"""
struct ModelDiagnostics
    metadata::ModelArtifactMetadata
    parameter_diagnostics::Dict{String, ParameterDiagnostics}
end

function Base.:(==)(lhs::ModelDiagnostics, rhs::ModelDiagnostics)
    return lhs.metadata == rhs.metadata &&
        lhs.parameter_diagnostics == rhs.parameter_diagnostics
end

"""
    SamplerDiagnostics

Typed summary of HMC/NUTS sampler internals extracted from fitted chains.
"""
struct SamplerDiagnostics
    metadata::ModelArtifactMetadata
    numerical_error_count::Int
    numerical_error_rate::Float64
    mean_abs_hamiltonian_energy_error::Float64
    max_abs_hamiltonian_energy_error::Float64
    max_abs_max_hamiltonian_energy_error::Float64
    max_tree_depth::Int
    mean_tree_depth::Float64
    max_n_steps::Int
    mean_n_steps::Float64
    mean_acceptance_rate::Float64
    mean_step_size::Float64
end

function Base.:(==)(lhs::SamplerDiagnostics, rhs::SamplerDiagnostics)
    return lhs.metadata == rhs.metadata &&
        lhs.numerical_error_count == rhs.numerical_error_count &&
        lhs.numerical_error_rate == rhs.numerical_error_rate &&
        lhs.mean_abs_hamiltonian_energy_error == rhs.mean_abs_hamiltonian_energy_error &&
        lhs.max_abs_hamiltonian_energy_error == rhs.max_abs_hamiltonian_energy_error &&
        lhs.max_abs_max_hamiltonian_energy_error == rhs.max_abs_max_hamiltonian_energy_error &&
        lhs.max_tree_depth == rhs.max_tree_depth &&
        lhs.mean_tree_depth == rhs.mean_tree_depth &&
        lhs.max_n_steps == rhs.max_n_steps &&
        lhs.mean_n_steps == rhs.mean_n_steps &&
        lhs.mean_acceptance_rate == rhs.mean_acceptance_rate &&
        lhs.mean_step_size == rhs.mean_step_size
end

"""
    SamplerWarning

Typed user-facing warning derived from sampler internals.
"""
struct SamplerWarning
    metric::Symbol
    severity::Symbol
    value::Float64
    threshold::Float64
    message::String
end

function Base.:(==)(lhs::SamplerWarning, rhs::SamplerWarning)
    return lhs.metric == rhs.metric &&
        lhs.severity == rhs.severity &&
        lhs.value == rhs.value &&
        lhs.threshold == rhs.threshold &&
        lhs.message == rhs.message
end

"""
    SamplerWarnings

Typed warning bundle derived from sampler diagnostics.
"""
struct SamplerWarnings
    metadata::ModelArtifactMetadata
    warnings::Vector{SamplerWarning}
    summary::NamedTuple
end

function Base.:(==)(lhs::SamplerWarnings, rhs::SamplerWarnings)
    return lhs.metadata == rhs.metadata &&
        lhs.warnings == rhs.warnings &&
        lhs.summary == rhs.summary
end

"""
    ConvergenceIssue

Typed convergence-threshold breach for one parameter and one metric.
"""
struct ConvergenceIssue
    parameter::String
    metric::Symbol
    value::Union{Missing, Float64}
    threshold::Float64
end

function Base.:(==)(lhs::ConvergenceIssue, rhs::ConvergenceIssue)
    return lhs.parameter == rhs.parameter &&
        lhs.metric == rhs.metric &&
        lhs.value == rhs.value &&
        lhs.threshold == rhs.threshold
end

"""
    ConvergenceReport

Typed convergence report derived from chain diagnostics and threshold rules.
"""
struct ConvergenceReport
    metadata::ModelArtifactMetadata
    issues::Vector{ConvergenceIssue}
    summary::NamedTuple
end

function Base.:(==)(lhs::ConvergenceReport, rhs::ConvergenceReport)
    return lhs.metadata == rhs.metadata &&
        lhs.issues == rhs.issues &&
        lhs.summary == rhs.summary
end

"""
    ConvergenceWarning

Typed user-facing warning derived from one convergence issue.
"""
struct ConvergenceWarning
    parameter::String
    metric::Symbol
    severity::Symbol
    message::String
end

function Base.:(==)(lhs::ConvergenceWarning, rhs::ConvergenceWarning)
    return lhs.parameter == rhs.parameter &&
        lhs.metric == rhs.metric &&
        lhs.severity == rhs.severity &&
        lhs.message == rhs.message
end

"""
    ConvergenceWarnings

Typed warning bundle derived from a convergence report.
"""
struct ConvergenceWarnings
    metadata::ModelArtifactMetadata
    warnings::Vector{ConvergenceWarning}
    summary::NamedTuple
end

function Base.:(==)(lhs::ConvergenceWarnings, rhs::ConvergenceWarnings)
    return lhs.metadata == rhs.metadata &&
        lhs.warnings == rhs.warnings &&
        lhs.summary == rhs.summary
end

"""
    model_diagnostics(results)
    model_diagnostics(model)

Extract typed chain diagnostics from fitted model results or a fitted model.
"""
function model_diagnostics(results::ModelResults)
    chain = results.chain
    bulk_df = ess(chain; kind = :bulk)
    tail_df = ess(chain; kind = :tail)
    rhat_df = rhat(chain)
    mcse_df = mcse(chain)

    parameter_diagnostics = Dict{String, ParameterDiagnostics}()
    for parameter in bulk_df.nt.parameters
        name = string(parameter)
        parameter_diagnostics[name] = ParameterDiagnostics(
            _metric_value(rhat_df, parameter, :rhat),
            _metric_value(bulk_df, parameter, :ess),
            _metric_value(tail_df, parameter, :ess),
            _metric_value(mcse_df, parameter, :mcse),
        )
    end

    return ModelDiagnostics(results.metadata, parameter_diagnostics)
end

function model_diagnostics(model::TimeSeriesMMM)
    return model_diagnostics(model_results(model; include_posterior_predictive = false))
end

"""
    sampler_diagnostics(results)
    sampler_diagnostics(model)

Extract typed HMC/NUTS sampler diagnostics from fitted model results or a fitted
model.
"""
function sampler_diagnostics(results::ModelResults)
    chain = results.chain
    numerical_error = _internal_metric(chain, :numerical_error)
    hamiltonian_energy_error = _internal_metric(chain, :hamiltonian_energy_error)
    max_hamiltonian_energy_error = _internal_metric(chain, :max_hamiltonian_energy_error)
    tree_depth = _internal_metric(chain, :tree_depth)
    n_steps = _internal_metric(chain, :n_steps)
    acceptance_rate = _internal_metric(chain, :acceptance_rate)
    step_size = _internal_metric(chain, :step_size)

    numerical_error_count = count(>(0.0), numerical_error)
    return SamplerDiagnostics(
        results.metadata,
        numerical_error_count,
        isempty(numerical_error) ? 0.0 : numerical_error_count / length(numerical_error),
        isempty(hamiltonian_energy_error) ? 0.0 : Statistics.mean(abs.(hamiltonian_energy_error)),
        isempty(hamiltonian_energy_error) ? 0.0 : maximum(abs.(hamiltonian_energy_error)),
        isempty(max_hamiltonian_energy_error) ? 0.0 : maximum(abs.(max_hamiltonian_energy_error)),
        isempty(tree_depth) ? 0 : Int(round(maximum(tree_depth))),
        isempty(tree_depth) ? 0.0 : Statistics.mean(tree_depth),
        isempty(n_steps) ? 0 : Int(round(maximum(n_steps))),
        isempty(n_steps) ? 0.0 : Statistics.mean(n_steps),
        isempty(acceptance_rate) ? 0.0 : Statistics.mean(acceptance_rate),
        isempty(step_size) ? 0.0 : Statistics.mean(step_size),
    )
end

function sampler_diagnostics(model::TimeSeriesMMM)
    return sampler_diagnostics(model_results(model; include_posterior_predictive = false))
end

"""
    sampler_warnings(diagnostics; numerical_error_threshold=0, tree_depth_threshold=10, acceptance_rate_threshold=0.65)
    sampler_warnings(results; ...)
    sampler_warnings(model; ...)

Build typed user-facing warnings from sampler diagnostics, fitted results, or a
fitted model.
"""
function sampler_warnings(
        diagnostics::SamplerDiagnostics;
        numerical_error_threshold::Int = 0,
        energy_error_threshold::Float64 = 100.0,
        tree_depth_threshold::Int = 10,
        acceptance_rate_threshold::Float64 = 0.65,
    )
    warnings = SamplerWarning[]

    if diagnostics.numerical_error_count > numerical_error_threshold
        push!(
            warnings,
            SamplerWarning(
                :numerical_error_count,
                :high,
                Float64(diagnostics.numerical_error_count),
                Float64(numerical_error_threshold),
                "Sampler recorded $(diagnostics.numerical_error_count) numerical errors, exceeding $(numerical_error_threshold).",
            ),
        )
    end

    if diagnostics.max_abs_max_hamiltonian_energy_error > energy_error_threshold
        push!(
            warnings,
            SamplerWarning(
                :max_abs_max_hamiltonian_energy_error,
                :high,
                diagnostics.max_abs_max_hamiltonian_energy_error,
                energy_error_threshold,
                "Sampler maximum absolute Hamiltonian energy error $(diagnostics.max_abs_max_hamiltonian_energy_error) exceeds $(energy_error_threshold).",
            ),
        )
    end

    if diagnostics.max_tree_depth >= tree_depth_threshold
        push!(
            warnings,
            SamplerWarning(
                :max_tree_depth,
                :medium,
                Float64(diagnostics.max_tree_depth),
                Float64(tree_depth_threshold),
                "Sampler reached tree depth $(diagnostics.max_tree_depth), meeting or exceeding $(tree_depth_threshold).",
            ),
        )
    end

    if diagnostics.mean_acceptance_rate < acceptance_rate_threshold
        push!(
            warnings,
            SamplerWarning(
                :mean_acceptance_rate,
                :medium,
                diagnostics.mean_acceptance_rate,
                acceptance_rate_threshold,
                "Sampler mean acceptance rate $(diagnostics.mean_acceptance_rate) is below $(acceptance_rate_threshold).",
            ),
        )
    end

    sort!(warnings; by = warning -> (String(warning.metric), String(warning.severity)))
    summary = (
        nwarnings = length(warnings),
        high = count(warning -> warning.severity === :high, warnings),
        medium = count(warning -> warning.severity === :medium, warnings),
        metrics = [warning.metric for warning in warnings],
    )
    return SamplerWarnings(diagnostics.metadata, warnings, summary)
end

function sampler_warnings(
        results::ModelResults;
        numerical_error_threshold::Int = 0,
        energy_error_threshold::Float64 = 100.0,
        tree_depth_threshold::Int = 10,
        acceptance_rate_threshold::Float64 = 0.65,
    )
    return sampler_warnings(
        sampler_diagnostics(results);
        numerical_error_threshold,
        energy_error_threshold,
        tree_depth_threshold,
        acceptance_rate_threshold,
    )
end

function sampler_warnings(
        model::TimeSeriesMMM;
        numerical_error_threshold::Int = 0,
        energy_error_threshold::Float64 = 100.0,
        tree_depth_threshold::Int = 10,
        acceptance_rate_threshold::Float64 = 0.65,
    )
    return sampler_warnings(
        sampler_diagnostics(model);
        numerical_error_threshold,
        energy_error_threshold,
        tree_depth_threshold,
        acceptance_rate_threshold,
    )
end

"""
    convergence_report(results; rhat_threshold=1.05, ess_threshold=100.0)
    convergence_report(model; rhat_threshold=1.05, ess_threshold=100.0)

Build a typed threshold-based convergence report from fitted model results or a
fitted model.
"""
function convergence_report(
        results::ModelResults;
        rhat_threshold::Float64 = 1.05,
        ess_threshold::Float64 = 100.0,
    )
    return convergence_report(
        model_diagnostics(results);
        rhat_threshold,
        ess_threshold,
    )
end

function convergence_report(
        model::TimeSeriesMMM;
        rhat_threshold::Float64 = 1.05,
        ess_threshold::Float64 = 100.0,
    )
    return convergence_report(
        model_results(model; include_posterior_predictive = false);
        rhat_threshold,
        ess_threshold,
    )
end

"""
    has_convergence_issues(report)

Return `true` when a convergence report contains any flagged metrics.
"""
has_convergence_issues(report::ConvergenceReport) = !isempty(report.issues)

"""
    convergence_warnings(report)
    convergence_warnings(results; rhat_threshold=1.05, ess_threshold=100.0)
    convergence_warnings(model; rhat_threshold=1.05, ess_threshold=100.0)

Build typed user-facing warnings from a convergence report, fitted results, or
fitted model.
"""
function convergence_warnings(report::ConvergenceReport)
    warnings = [
        ConvergenceWarning(
                issue.parameter,
                issue.metric,
                _warning_severity(issue.metric),
                _warning_message(issue),
            ) for issue in report.issues
    ]
    sort!(warnings; by = warning -> (warning.parameter, String(warning.metric)))
    summary = (
        nwarnings = length(warnings),
        flagged_parameters = sort!(collect(Set(warning.parameter for warning in warnings))),
        high = count(warning -> warning.severity === :high, warnings),
        medium = count(warning -> warning.severity === :medium, warnings),
    )
    return ConvergenceWarnings(report.metadata, warnings, summary)
end

function convergence_warnings(
        results::ModelResults;
        rhat_threshold::Float64 = 1.05,
        ess_threshold::Float64 = 100.0,
    )
    return convergence_warnings(convergence_report(results; rhat_threshold, ess_threshold))
end

function convergence_warnings(
        model::TimeSeriesMMM;
        rhat_threshold::Float64 = 1.05,
        ess_threshold::Float64 = 100.0,
    )
    return convergence_warnings(convergence_report(model; rhat_threshold, ess_threshold))
end

"""
    has_convergence_warnings(warnings)

Return `true` when a convergence warning bundle contains any warnings.
"""
has_convergence_warnings(warnings::ConvergenceWarnings) = !isempty(warnings.warnings)

"""
    has_numerical_errors(diagnostics)

Return `true` when sampler diagnostics record any numerical-error transitions.
"""
has_numerical_errors(diagnostics::SamplerDiagnostics) = diagnostics.numerical_error_count > 0

"""
    has_sampler_warnings(warnings)

Return `true` when a sampler warning bundle contains any warnings.
"""
has_sampler_warnings(warnings::SamplerWarnings) = !isempty(warnings.warnings)

function _metric_value(frame, parameter::Symbol, column::Symbol)
    value = frame[parameter, column]
    ismissing(value) && return missing
    return Float64(value)
end

function _internal_metric(chain, name::Symbol)
    name in names(chain, :internals) || return Float64[]
    return vec(Float64.(Array(chain[name])))
end

function convergence_report(
        diagnostics::ModelDiagnostics;
        rhat_threshold::Float64 = 1.05,
        ess_threshold::Float64 = 100.0,
    )
    issues = ConvergenceIssue[]

    for (name, parameter_diagnostics) in diagnostics.parameter_diagnostics
        if !ismissing(parameter_diagnostics.rhat) && parameter_diagnostics.rhat > rhat_threshold
            push!(issues, ConvergenceIssue(name, :rhat, parameter_diagnostics.rhat, rhat_threshold))
        end
        if !ismissing(parameter_diagnostics.ess_bulk) && parameter_diagnostics.ess_bulk < ess_threshold
            push!(issues, ConvergenceIssue(name, :ess_bulk, parameter_diagnostics.ess_bulk, ess_threshold))
        end
        if !ismissing(parameter_diagnostics.ess_tail) && parameter_diagnostics.ess_tail < ess_threshold
            push!(issues, ConvergenceIssue(name, :ess_tail, parameter_diagnostics.ess_tail, ess_threshold))
        end
    end

    sort!(issues; by = issue -> (issue.parameter, String(issue.metric)))
    summary = (
        nparameters = length(diagnostics.parameter_diagnostics),
        flagged_parameters = sort!(collect(Set(issue.parameter for issue in issues))),
        nissues = length(issues),
        rhat_failures = count(issue -> issue.metric === :rhat, issues),
        ess_bulk_failures = count(issue -> issue.metric === :ess_bulk, issues),
        ess_tail_failures = count(issue -> issue.metric === :ess_tail, issues),
        rhat_threshold = rhat_threshold,
        ess_threshold = ess_threshold,
    )
    return ConvergenceReport(diagnostics.metadata, issues, summary)
end

function _warning_severity(metric::Symbol)
    metric === :rhat && return :high
    return :medium
end

function _warning_message(issue::ConvergenceIssue)
    if issue.metric === :rhat
        return "Parameter $(issue.parameter) has R-hat $(issue.value), exceeding $(issue.threshold)."
    elseif issue.metric === :ess_bulk
        return "Parameter $(issue.parameter) has bulk ESS $(issue.value), below $(issue.threshold)."
    end
    return "Parameter $(issue.parameter) has tail ESS $(issue.value), below $(issue.threshold)."
end
