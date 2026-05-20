using Turing
using Random

struct MCMCExecutionPlan
    mode::Symbol
    requested_chains::Int
    requested_cores::Int
    effective_cores::Int
    available_threads::Int
end

function Base.:(==)(lhs::MCMCExecutionPlan, rhs::MCMCExecutionPlan)
    return lhs.mode == rhs.mode &&
           lhs.requested_chains == rhs.requested_chains &&
           lhs.requested_cores == rhs.requested_cores &&
           lhs.effective_cores == rhs.effective_cores &&
           lhs.available_threads == rhs.available_threads
end

function _mcmc_execution_plan(config::SamplerConfig)
    available_threads = Base.Threads.nthreads()
    effective_cores = min(config.cores, config.chains)

    if config.chains == 1
        return MCMCExecutionPlan(
            :single,
            config.chains,
            config.cores,
            effective_cores,
            available_threads,
        )
    end

    if effective_cores > 1 && available_threads > 1 &&
       config.chains <= effective_cores && config.chains <= available_threads
        return MCMCExecutionPlan(
            :threads,
            config.chains,
            config.cores,
            effective_cores,
            available_threads,
        )
    end

    return MCMCExecutionPlan(
        :serial,
        config.chains,
        config.cores,
        effective_cores,
        available_threads,
    )
end

function _mcmc_executor(plan::MCMCExecutionPlan)
    plan.mode === :threads && return Turing.MCMCThreads()
    plan.mode === :serial && return Turing.MCMCSerial()
    throw(ArgumentError("single-chain execution does not use a multi-chain executor"))
end

function _sampler_rng(config::SamplerConfig; offset::Int = 0)
    isnothing(config.random_seed) && return Random.default_rng()
    return Random.MersenneTwister(config.random_seed + offset)
end

function _sample_posterior(rng, turing_model, sampler, config::SamplerConfig, plan::MCMCExecutionPlan)
    if plan.mode === :single
        return Turing.sample(
            rng,
            turing_model,
            sampler,
            config.draws;
            progress = config.progressbar,
        )
    end

    return Turing.sample(
        rng,
        turing_model,
        sampler,
        _mcmc_executor(plan),
        config.draws,
        config.chains;
        progress = config.progressbar,
    )
end

function _sample_prior(rng, predictive_model, config::SamplerConfig, plan::MCMCExecutionPlan)
    if plan.mode === :single
        return Turing.sample(
            rng,
            predictive_model,
            Turing.Prior(),
            config.draws;
            progress = config.progressbar,
        )
    end

    return Turing.sample(
        rng,
        predictive_model,
        Turing.Prior(),
        _mcmc_executor(plan),
        config.draws,
        config.chains;
        progress = config.progressbar,
    )
end

function _mcmc_fit_message(model_label::AbstractString, plan::MCMCExecutionPlan)
    if plan.mode === :threads
        return "$model_label fitted with the current Turing NUTS path using threaded multi-chain execution for $(plan.requested_chains) chains."
    elseif plan.mode === :serial
        return "$model_label fitted with the current Turing NUTS path using serial multi-chain execution for $(plan.requested_chains) chains."
    end
    return "$model_label fitted with the current Turing NUTS path using single-chain execution."
end

function _convergence_summary_message(report::ConvergenceReport)
    flagged = length(report.summary.flagged_parameters)
    return "Convergence checks completed for $(report.summary.nparameters) parameters; $(flagged) parameters breached current thresholds."
end

function _convergence_warning_message(warnings::ConvergenceWarnings)
    nwarnings = warnings.summary.nwarnings
    if nwarnings == 0
        return "No convergence warnings were generated."
    end
    return "Generated $(nwarnings) convergence warnings ($(warnings.summary.high) high, $(warnings.summary.medium) medium)."
end

function _sampler_diagnostics_message(diagnostics::SamplerDiagnostics)
    return "Sampler internals recorded $(diagnostics.numerical_error_count) numerical errors; max tree depth $(diagnostics.max_tree_depth), max steps $(diagnostics.max_n_steps)."
end

function _sampler_warning_message(warnings::SamplerWarnings)
    nwarnings = warnings.summary.nwarnings
    if nwarnings == 0
        return "No sampler warnings were generated."
    end
    return "Generated $(nwarnings) sampler warnings ($(warnings.summary.high) high, $(warnings.summary.medium) medium)."
end

function _mcmc_diagnostics_bundle(
    metadata::ModelArtifactMetadata,
    spec::MMMModelSpec,
    chain,
    compute_convergence_checks::Bool,
)
    if !compute_convergence_checks
        return (
            diagnostics = nothing,
            sampler_diagnostics = nothing,
            sampler_warnings = nothing,
            convergence_report = nothing,
            convergence_warnings = nothing,
            message = "",
        )
    end

    results = ModelResults(
        metadata,
        spec,
        chain;
        posterior_predictive = nothing,
        prior_predictive = nothing,
    )
    diagnostics = model_diagnostics(results)
    sampler_summary = sampler_diagnostics(results)
    sampler_warnings_bundle = sampler_warnings(sampler_summary)
    report = convergence_report(results)
    warnings = convergence_warnings(report)
    message = join(
        (
            _sampler_diagnostics_message(sampler_summary),
            _sampler_warning_message(sampler_warnings_bundle),
            _convergence_summary_message(report),
            _convergence_warning_message(warnings),
        ),
        " ",
    )
    return (
        diagnostics,
        sampler_diagnostics = sampler_summary,
        sampler_warnings = sampler_warnings_bundle,
        convergence_report = report,
        convergence_warnings = warnings,
        message,
    )
end

function _successful_turing_fit!(
    model::Union{TimeSeriesMMM, PanelMMM},
    artifact,
    message::AbstractString,
)
    return _successful_fit!(model, :turing, artifact, message)
end

function _fit_error_message(model::Union{TimeSeriesMMM, PanelMMM}, err)
    model_label = nameof(typeof(model))
    return "$(model_label) fit! failed before producing a valid Turing artifact: $(sprint(showerror, err))"
end

function _mark_failed_turing_fit!(model::Union{TimeSeriesMMM, PanelMMM}, err)
    return _mark_failed_fit!(model, :turing, _fit_error_message(model, err))
end

function _successful_fit!(
    model::Union{TimeSeriesMMM, PanelMMM},
    backend::Symbol,
    artifact,
    message::AbstractString,
)
    state = ModelFitState(
        :fit,
        backend;
        artifact,
        message,
    )
    model.fit_state = state
    return state
end

function _mark_failed_fit!(
    model::Union{TimeSeriesMMM, PanelMMM},
    backend::Symbol,
    message::AbstractString,
)
    state = ModelFitState(
        :error,
        backend;
        artifact = nothing,
        message,
    )
    model.fit_state = state
    return state
end

function _require_successful_fit_state(state::Union{Nothing, ModelFitState}, action::AbstractString)
    isnothing(state) && throw(ArgumentError("fit! must be called before $action"))
    state.status === :fit ||
        throw(ArgumentError("cannot $action because the last fit! failed: $(state.message)"))
    isnothing(state.artifact) &&
        throw(ArgumentError("cannot $action because the last fit! did not produce an artifact"))
    return state
end

function _require_successful_posterior_fit(state::Union{Nothing, ModelFitState}, action::AbstractString)
    state = _require_successful_fit_state(state, action)
    state.backend in (:turing, :variational) ||
        throw(
            ArgumentError(
                "$action currently supports only posterior-backed fit states",
            ),
        )
    hasproperty(state.artifact, :chain) ||
        throw(ArgumentError("cannot $action because the last fit! did not produce posterior draws"))
    return state
end

function _require_successful_turing_fit(state::Union{Nothing, ModelFitState}, action::AbstractString)
    state = _require_successful_fit_state(state, action)
    state.backend === :turing ||
        throw(ArgumentError("$action currently supports only Turing-backed fit states"))
    return state
end
