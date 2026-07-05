function model_diagnostics(model::PanelMMM)
    return model_diagnostics(model_results(model; include_posterior_predictive = false))
end

function sampler_diagnostics(model::PanelMMM)
    return sampler_diagnostics(model_results(model; include_posterior_predictive = false))
end

function sampler_warnings(
        model::PanelMMM;
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

function convergence_report(
        model::PanelMMM;
        rhat_threshold::Float64 = 1.05,
        ess_threshold::Float64 = 100.0,
    )
    return convergence_report(
        model_results(model; include_posterior_predictive = false);
        rhat_threshold,
        ess_threshold,
    )
end

function convergence_warnings(
        model::PanelMMM;
        rhat_threshold::Float64 = 1.05,
        ess_threshold::Float64 = 100.0,
    )
    return convergence_warnings(convergence_report(model; rhat_threshold, ess_threshold))
end
