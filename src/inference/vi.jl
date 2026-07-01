using MCMCChains
using Random
using Turing

function approximate_fit!(
    model::TimeSeriesMMM,
    config::VariationalConfig = VariationalConfig(),
)
    if !isnothing(model.calibration)
        err = ArgumentError(
            "approximate_fit! does not support calibrated TimeSeriesMMM models; calibration likelihood terms are only supported through fit! (Turing NUTS)",
        )
        _mark_failed_variational_fit!(model, err)
        throw(err)
    end
    return _approximate_fit_time_series_mmm!(model, config)
end

function approximate_fit!(
    model::PanelMMM,
    config::VariationalConfig = VariationalConfig(),
)
    err = ArgumentError(
        "approximate_fit! currently supports only TimeSeriesMMM; PanelMMM variational inference is not supported in the current Phase 6 surface",
    )
    _mark_failed_variational_fit!(model, err)
    throw(err)
end

function _approximate_fit_time_series_mmm!(
    model::TimeSeriesMMM,
    config::VariationalConfig,
)
    try
        runtime, controls = _turing_runtime(model.config, model.data)
        spec = _build_model_spec(
            model.config,
            model.data;
            control_transform_state = runtime.control_transform_state,
        )
        model.built_model = spec
        events = _event_design_matrix(model.config.events, model.data)
        holidays = _holiday_design_matrix(model.config.holidays, model.data)
        scaled_channels = _scale_channels(model.data.channels, spec.channel_scale)
        scaled_target = model.data.target ./ spec.target_scale
        turing_model = _time_series_mmm_model(
            scaled_target,
            scaled_channels,
            controls,
            events,
            holidays,
            runtime,
        )
        rng = _variational_rng(config)
        q0 = _variational_family(rng, turing_model, config)
        q, _, _ = Turing.Variational.vi(
            rng,
            turing_model,
            q0,
            config.max_iters;
            show_progress = config.progressbar,
        )
        chain = _materialize_variational_chain(rng, q, turing_model, config.draws)
        metadata = _artifact_metadata("TimeSeriesMMM"; backend = :variational, fit_status = :fit)
        artifact = (;
            spec,
            runtime,
            chain,
            variational_config = config,
            approximation_family = config.family,
            materialized_draws = config.draws,
            metadata,
        )
        message = _variational_fit_message("TimeSeriesMMM", config)
        return _successful_fit!(model, :variational, artifact, message)
    catch err
        _mark_failed_variational_fit!(model, err)
        rethrow()
    end
end

function _variational_rng(config::VariationalConfig; offset::Int = 0)
    isnothing(config.random_seed) && return Random.default_rng()
    return Random.MersenneTwister(config.random_seed + offset)
end

function _variational_family(
    rng,
    turing_model,
    config::VariationalConfig,
)
    if config.family === :meanfield_gaussian
        return Turing.Variational.q_meanfield_gaussian(rng, turing_model)
    end

    throw(
        ArgumentError(
            "VariationalConfig.family currently supports only :meanfield_gaussian",
        ),
    )
end

function _materialize_variational_chain(
    rng,
    approximation,
    turing_model,
    draws::Int,
)
    sample_matrix = reshape(rand(rng, approximation, draws), :, draws)
    logdensity = Turing.DynamicPPL.LogDensityFunction(turing_model)
    params_matrix = reshape(
        [Turing.DynamicPPL.ParamsWithStats(sample_matrix[:, index], logdensity) for index in 1:draws],
        :,
        1,
    )
    return Turing.AbstractMCMC.from_samples(MCMCChains.Chains, params_matrix)
end

function _variational_fit_message(
    model_label::AbstractString,
    config::VariationalConfig,
)
    return "$model_label fitted with the current mean-field Gaussian ADVI path for $(config.max_iters) iterations and materialized $(config.draws) posterior draws."
end

function _variational_fit_error_message(model::Union{TimeSeriesMMM, PanelMMM}, err)
    model_label = nameof(typeof(model))
    return "$(model_label) approximate_fit! failed before producing a valid variational artifact: $(sprint(showerror, err))"
end

function _mark_failed_variational_fit!(model::Union{TimeSeriesMMM, PanelMMM}, err)
    return _mark_failed_fit!(model, :variational, _variational_fit_error_message(model, err))
end

function _sampler_config_with_draws(
    config::SamplerConfig,
    draws::Int;
    chains::Int = config.chains,
    cores::Int = config.cores,
)
    return SamplerConfig(
        draws = draws,
        tune = config.tune,
        chains = chains,
        cores = cores,
        target_accept = config.target_accept,
        random_seed = config.random_seed,
        progressbar = config.progressbar,
        compute_convergence_checks = config.compute_convergence_checks,
    )
end
