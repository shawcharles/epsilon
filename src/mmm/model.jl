using Turing

const _DEFAULT_INTERCEPT_PRIOR = EpsilonPrior("Normal"; mu = 0.0, sigma = 2.0)
const _DEFAULT_SIGMA_PRIOR = EpsilonPrior("HalfNormal"; sigma = 1.0)
const _DEFAULT_MEDIA_BETA_PRIOR = EpsilonPrior("HalfNormal"; sigma = 1.0)
const _DEFAULT_CONTROL_BETA_PRIOR = EpsilonPrior("Normal"; mu = 0.0, sigma = 1.0)
const _DEFAULT_ALPHA_PRIOR = EpsilonPrior("Beta"; alpha = 1.0, beta = 3.0)
const _DEFAULT_THETA_PRIOR = EpsilonPrior("HalfNormal"; sigma = 1.0)
const _DEFAULT_WEIBULL_PDF_LAM_PRIOR = EpsilonPrior("Gamma"; alpha = 4.0, beta = 2.0)
const _DEFAULT_WEIBULL_PDF_K_PRIOR = EpsilonPrior("Gamma"; alpha = 9.0, beta = 3.0)
const _DEFAULT_WEIBULL_CDF_LAM_PRIOR = EpsilonPrior("Gamma"; alpha = 0.64, beta = 0.32)
const _DEFAULT_WEIBULL_CDF_K_PRIOR = EpsilonPrior("Gamma"; alpha = 0.64, beta = 0.32)
const _DEFAULT_LAM_PRIOR = LogNormalPrior(; mean = 1.0, std = 1.0)
const _DEFAULT_MM_ALPHA_PRIOR = EpsilonPrior("Gamma"; alpha = 4.0, beta = 2.0)
const _DEFAULT_MM_LAM_PRIOR = EpsilonPrior("HalfNormal"; sigma = 1.0)
const _DEFAULT_B_PRIOR = EpsilonPrior("HalfNormal"; sigma = 1.0)
const _DEFAULT_C_PRIOR = EpsilonPrior("HalfNormal"; sigma = 1.0)
const _DEFAULT_SLOPE_PRIOR = EpsilonPrior("HalfNormal"; sigma = 1.5)
const _DEFAULT_KAPPA_PRIOR = EpsilonPrior("HalfNormal"; sigma = 1.5)
const _DEFAULT_SEASONALITY_BETA_PRIOR = EpsilonPrior("Laplace"; mu = 0.0, b = 1.0)
const _DEFAULT_TREND_BETA_PRIOR = EpsilonPrior("Normal"; mu = 0.0, sigma = 1.0)
const _DEFAULT_TREND_DELTA_PRIOR = EpsilonPrior("Laplace"; mu = 0.0, b = 0.25)
const _DEFAULT_EVENT_BETA_PRIOR = EpsilonPrior("Normal"; mu = 0.0, sigma = 1.0)
const _DEFAULT_HOLIDAY_BETA_PRIOR = EpsilonPrior("Normal"; mu = 0.0, sigma = 1.0)

@model function _time_series_mmm_model(
        target, channels, controls, events, holidays, runtime;
        lift_test_payload = nothing,
        cost_per_target_payload = nothing,
    )
    intercept ~ runtime.intercept_prior
    sigma ~ runtime.sigma_prior
    beta_media = fill(one(eltype(channels)), runtime.nchannels)
    if runtime.uses_external_media_beta
        beta_media ~ Turing.filldist(runtime.media_beta_prior, runtime.nchannels)
    end

    transformed_media = channels
    if runtime.adstock_type === :geometric || runtime.adstock_type === :binomial
        alpha ~ Turing.filldist(runtime.alpha_prior, runtime.nchannels)
        transformed_media = _apply_adstock(channels, runtime; alpha)
    elseif runtime.adstock_type === :delayed
        alpha ~ Turing.filldist(runtime.alpha_prior, runtime.nchannels)
        theta ~ Turing.filldist(runtime.theta_prior, runtime.nchannels)
        transformed_media = _apply_adstock(channels, runtime; alpha, theta)
    elseif runtime.adstock_type === :weibull_pdf || runtime.adstock_type === :weibull_cdf
        lam_adstock ~ Turing.filldist(runtime.adstock_lam_prior, runtime.nchannels)
        k_adstock ~ Turing.filldist(runtime.adstock_k_prior, runtime.nchannels)
        transformed_media = _apply_adstock(channels, runtime; lam = lam_adstock, k = k_adstock)
    elseif runtime.adstock_type === :none
        transformed_media = _apply_adstock(channels, runtime)
    end

    if runtime.saturation_type === :logistic
        lam ~ Turing.filldist(runtime.lam_prior, runtime.nchannels)
        transformed_media = _apply_saturation(transformed_media, runtime; lam)
    elseif runtime.saturation_type === :tanh
        b ~ Turing.filldist(runtime.b_prior, runtime.nchannels)
        c ~ Turing.filldist(runtime.c_prior, runtime.nchannels)
        transformed_media = _apply_saturation(transformed_media, runtime; b, c)
    elseif runtime.saturation_type === :michaelis_menten
        alpha_saturation ~ Turing.filldist(runtime.mm_alpha_prior, runtime.nchannels)
        lam ~ Turing.filldist(runtime.mm_lam_prior, runtime.nchannels)
        transformed_media = _apply_saturation(transformed_media, runtime; alpha = alpha_saturation, lam)
    elseif runtime.saturation_type === :hill
        slope ~ Turing.filldist(runtime.slope_prior, runtime.nchannels)
        kappa ~ Turing.filldist(runtime.kappa_prior, runtime.nchannels)
        transformed_media = _apply_saturation(transformed_media, runtime; slope, kappa)
    elseif runtime.saturation_type === :none
        transformed_media = _apply_saturation(transformed_media, runtime)
    end

    if !isnothing(lift_test_payload)
        runtime.saturation_type === :logistic ||
            throw(
            ArgumentError(
                "lift-test calibration is only supported for `logistic` saturation in the current model path",
            ),
        )
        lift_test_logdensity = try
            lift_test_payload_log_density(
                (x_row, lam_row) -> centered_logistic_saturation.(x_row, lam_row),
                lift_test_payload,
                lam,
            )
        catch err
            err isa ArgumentError || rethrow()
            -Inf
        end
        Turing.@addlogprob! lift_test_logdensity
    end

    if !isnothing(cost_per_target_payload)
        cost_per_target_logdensity = try
            cost_per_target_total_penalty(
                cost_per_target_payload.gathered_cpt,
                cost_per_target_payload.targets,
                cost_per_target_payload.sigma,
            )
        catch err
            err isa ArgumentError || rethrow()
            -Inf
        end
        Turing.@addlogprob! cost_per_target_logdensity
    end

    media_effect = _media_effect(transformed_media, beta_media)
    control_effect = zero.(media_effect)
    event_effect = zero.(media_effect)
    holiday_effect = zero.(media_effect)
    seasonality_effect = zero.(media_effect)
    trend_effect = zero.(media_effect)

    if !isnothing(controls)
        beta_controls ~ Turing.filldist(runtime.control_beta_prior, runtime.ncontrols)
        control_effect = vec(sum(controls .* reshape(beta_controls, 1, :); dims = 2))
    end

    if !isnothing(events)
        beta_events ~ Turing.filldist(runtime.event_beta_prior, runtime.nevents)
        event_effect = vec(sum(events .* reshape(beta_events, 1, :); dims = 2))
    end

    if !isnothing(holidays)
        beta_holidays ~ Turing.filldist(runtime.holiday_beta_prior, runtime.nholidays)
        holiday_effect = vec(sum(holidays .* reshape(beta_holidays, 1, :); dims = 2))
    end

    if runtime.seasonality_type === :fourier
        beta_seasonality ~ Turing.filldist(runtime.seasonality_beta_prior, runtime.nseasonality_terms)
        seasonality_effect = vec(
            sum(
                runtime.seasonality_features .* reshape(beta_seasonality, 1, :);
                dims = 2,
            ),
        )
    end

    if runtime.trend_type === :linear
        beta_trend ~ Turing.filldist(runtime.trend_beta_prior, runtime.ntrend_terms)
        trend_effect = vec(
            sum(
                runtime.trend_features .* reshape(beta_trend, 1, :);
                dims = 2,
            ),
        )
    elseif runtime.trend_type === :changepoint
        delta_trend ~ Turing.filldist(runtime.trend_delta_prior, runtime.ntrend_terms)
        trend_effect = vec(
            sum(
                runtime.trend_features .* reshape(delta_trend, 1, :);
                dims = 2,
            ),
        )
    end

    mu = intercept .+ media_effect .+ control_effect .+ event_effect .+ holiday_effect .+ seasonality_effect .+ trend_effect
    for i in eachindex(target)
        target[i] ~ Normal(mu[i], sigma)
    end

    return (; mu, media_effect, event_effect, holiday_effect, seasonality_effect, trend_effect)
end

function _unscale_predictive_targets(chain, target_scale::Float64)
    target_scale ≈ 1.0 && return chain
    param_names = collect(names(chain, :parameters))
    target_mask = [startswith(String(n), "target[") for n in param_names]
    any(target_mask) || return chain
    values = Array(chain)
    for (i, is_target) in enumerate(target_mask)
        is_target && (values[:, i, :] .*= target_scale)
    end
    return Chains(values, param_names; info = chain.info)
end

function _unscale_predictive_targets(chain, target_scale::AbstractVector{<:Real})
    all(isapprox.(target_scale, 1.0)) && return chain
    param_names = collect(names(chain, :parameters))
    values = Array(chain)
    for (index, name) in enumerate(param_names)
        panel = _target_parameter_panel_index(String(name))
        isnothing(panel) && continue
        values[:, index, :] .*= target_scale[panel]
    end
    return Chains(values, param_names; info = chain.info)
end

function _target_parameter_panel_index(name::AbstractString)
    startswith(name, "target[") || return nothing
    captures = match(r"^target\[\d+,\s*(\d+)\]$", name)
    isnothing(captures) && return nothing
    return parse(Int, captures.captures[1])
end

function _scale_channels(channels::AbstractMatrix, channel_scale::Vector{Float64})
    return channels ./ reshape(channel_scale, 1, :)
end

function _scale_channels(channels::AbstractArray{<:Any, 3}, channel_scale::AbstractMatrix)
    return channels ./ reshape(channel_scale, 1, size(channel_scale, 1), size(channel_scale, 2))
end

function _fit_time_series_mmm!(model::TimeSeriesMMM)
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

        calibration = _resolve_calibration_spec(
            model.config,
            model.calibration,
            spec.channel_scale,
            spec.target_scale,
        )
        lift_test_payload = isnothing(calibration) ? nothing : calibration.lift_test
        cost_per_target_payload = isnothing(calibration) ? nothing : calibration.cost_per_target

        turing_model = _time_series_mmm_model(
            scaled_target,
            scaled_channels,
            controls,
            events,
            holidays,
            runtime;
            lift_test_payload,
            cost_per_target_payload,
        )
        sampler = Turing.NUTS(model.sampler_config.tune, model.sampler_config.target_accept)
        execution_plan = _mcmc_execution_plan(model.sampler_config)
        rng = _sampler_rng(model.sampler_config)
        chain = _sample_posterior(rng, turing_model, sampler, model.sampler_config, execution_plan)
        metadata = _artifact_metadata("TimeSeriesMMM"; backend = :turing, fit_status = :fit)
        diagnostics_bundle = _mcmc_diagnostics_bundle(
            metadata,
            spec,
            chain,
            model.sampler_config.compute_convergence_checks,
        )
        message = _mcmc_fit_message("TimeSeriesMMM", execution_plan)
        !isempty(diagnostics_bundle.message) && (message *= " " * diagnostics_bundle.message)

        artifact = (;
            spec,
            runtime,
            chain,
            execution_plan,
            execution_backend = execution_plan.mode,
            diagnostics = diagnostics_bundle.diagnostics,
            sampler_diagnostics = diagnostics_bundle.sampler_diagnostics,
            sampler_warnings = diagnostics_bundle.sampler_warnings,
            convergence_report = diagnostics_bundle.convergence_report,
            convergence_warnings = diagnostics_bundle.convergence_warnings,
            metadata,
            calibration,
        )
        return _successful_turing_fit!(model, artifact, message)
    catch err
        _mark_failed_turing_fit!(model, err)
        rethrow()
    end
end

function _predict_time_series_mmm(model::TimeSeriesMMM, new_data::MMMData)
    state = _require_successful_posterior_fit(model.fit_state, "predict")
    artifact = state.artifact
    spec = artifact.spec
    _validate_model_data_alignment(spec, new_data)

    control_transform_state = hasproperty(artifact.runtime, :control_transform_state) ?
        artifact.runtime.control_transform_state : nothing
    runtime, controls = _turing_runtime(
        spec,
        new_data;
        control_transform_state,
    )
    events = _event_design_matrix(spec.events, new_data)
    holidays = _holiday_design_matrix(spec.holidays, new_data)
    target = Vector{Union{Missing, eltype(new_data.target)}}(missing, nobs(new_data))
    scaled_channels = _scale_channels(new_data.channels, spec.channel_scale)
    predictive_model = _time_series_mmm_model(
        target,
        scaled_channels,
        controls,
        events,
        holidays,
        runtime,
    )
    scaled_chain = Turing.predict(predictive_model, state.artifact.chain)
    return _unscale_predictive_targets(scaled_chain, spec.target_scale)
end

function _prior_predict_time_series_mmm(
        model::TimeSeriesMMM,
        new_data::MMMData;
        draws_override::Union{Nothing, Int} = nothing,
        chains_override::Union{Nothing, Int} = nothing,
        cores_override::Union{Nothing, Int} = nothing,
    )
    artifact = if !isnothing(model.fit_state) &&
            model.fit_state.status === :fit &&
            !isnothing(model.fit_state.artifact) &&
            hasproperty(model.fit_state.artifact, :spec)
        model.fit_state.artifact
    else
        nothing
    end
    runtime_spec = isnothing(artifact) ? _build_model_spec(model.config, model.data) : artifact.spec
    _validate_model_data_alignment(runtime_spec, new_data)

    control_transform_state = if !isnothing(artifact) &&
            hasproperty(artifact, :runtime) &&
            hasproperty(artifact.runtime, :control_transform_state)
        artifact.runtime.control_transform_state
    elseif runtime_spec isa MMMModelSpec
        _control_transform_state_from_config(runtime_spec.controls)
    else
        nothing
    end
    runtime, controls = _turing_runtime(
        runtime_spec,
        new_data;
        control_transform_state,
    )
    events = _event_design_matrix(runtime_spec.events, new_data)
    holidays = _holiday_design_matrix(runtime_spec.holidays, new_data)
    target = Vector{Union{Missing, eltype(new_data.target)}}(missing, nobs(new_data))
    channel_scale = runtime_spec.channel_scale
    target_scale = runtime_spec.target_scale
    scaled_channels = _scale_channels(new_data.channels, channel_scale)
    predictive_model = _time_series_mmm_model(
        target,
        scaled_channels,
        controls,
        events,
        holidays,
        runtime,
    )
    config = if isnothing(draws_override) && isnothing(chains_override) && isnothing(cores_override)
        model.sampler_config
    else
        _sampler_config_with_draws(
            model.sampler_config,
            isnothing(draws_override) ? model.sampler_config.draws : draws_override;
            chains = isnothing(chains_override) ? model.sampler_config.chains : chains_override,
            cores = isnothing(cores_override) ? model.sampler_config.cores : cores_override,
        )
    end
    execution = _mcmc_execution_plan(config)
    rng = _sampler_rng(config; offset = 1)
    scaled_chain = _sample_prior(rng, predictive_model, config, execution)
    return _unscale_predictive_targets(scaled_chain, target_scale)
end

function _turing_runtime(config::ModelConfig, data::MMMData; control_transform_state = nothing)
    adstock_type = _transform_type(config.adstock, :adstock)
    saturation_type = _transform_type(config.saturation, :saturation)
    seasonality_type = _seasonality_type(config.seasonality)
    trend_type = _trend_type(config.trend)

    adstock_type in (:none, :geometric, :delayed, :binomial, :weibull_pdf, :weibull_cdf) ||
        throw(ArgumentError("only `geometric`, `delayed`, `binomial`, and Weibull adstock are supported in the current Turing model path"))
    saturation_type in (:none, :logistic, :tanh, :michaelis_menten, :hill) ||
        throw(ArgumentError("only `logistic`, `tanh`, `michaelis_menten`, and `hill` saturation are supported in the current Turing model path"))
    seasonality_type in (:none, :fourier) ||
        throw(ArgumentError("only `fourier` seasonality is supported in the current Turing model path"))
    trend_type in (:none, :linear, :changepoint) ||
        throw(
        ArgumentError(
            "only `linear` and `changepoint` trend are supported in the current Turing model path",
        ),
    )

    adstock_priors = _mapping_value(config.adstock, "priors")
    saturation_priors = _mapping_value(config.saturation, "priors")
    seasonality_priors = _mapping_value(config.seasonality, "priors")
    trend_priors = _mapping_value(config.trend, "priors")
    events_priors = _mapping_value(config.events, "priors")
    holidays_priors = _mapping_value(config.holidays, "priors")
    controls_priors = _mapping_value(config.controls, "priors")
    adstock_weibull_defaults = _default_weibull_adstock_priors(adstock_type)
    seasonality_features = _seasonality_features(config.seasonality, data.dates)
    trend_features = _trend_features(config.trend, data.dates)
    event_columns = _events_columns(config.events)
    holiday_columns = _holidays_columns(config.holidays)
    controls_transform = _controls_transform(config.controls)
    controls_matrix, resolved_control_transform_state = _control_design_matrix(
        config.controls,
        data.controls;
        control_transform_state,
    )

    return (
            nchannels = size(data.channels, 2),
            ncontrols = isnothing(controls_matrix) ? 0 : size(controls_matrix, 2),
            nevents = length(event_columns),
            nholidays = length(holiday_columns),
            nseasonality_terms = size(seasonality_features, 2),
            ntrend_terms = size(trend_features, 2),
            intercept_prior = instantiate_distribution(_model_prior(config.priors, "intercept", _DEFAULT_INTERCEPT_PRIOR)),
            sigma_prior = instantiate_distribution(_model_prior(config.priors, "sigma", _DEFAULT_SIGMA_PRIOR)),
            media_beta_prior = instantiate_distribution(_model_prior(config.priors, "beta_media", _DEFAULT_MEDIA_BETA_PRIOR)),
            uses_external_media_beta = saturation_type != :michaelis_menten,
            control_beta_prior = instantiate_distribution(_control_beta_prior(config.priors, controls_priors)),
            event_beta_prior = instantiate_distribution(
                _model_prior(events_priors, "beta", _DEFAULT_EVENT_BETA_PRIOR),
            ),
            holiday_beta_prior = instantiate_distribution(
                _model_prior(holidays_priors, "beta", _DEFAULT_HOLIDAY_BETA_PRIOR),
            ),
            adstock_type = adstock_type,
            saturation_type = saturation_type,
            l_max = Int(get(config.adstock, "l_max", 12)),
            normalize_adstock = Bool(get(config.adstock, "normalize", false)),
            weibull_type = _weibull_runtime_type(adstock_type),
            alpha_prior = instantiate_distribution(_model_prior(adstock_priors, "alpha", _DEFAULT_ALPHA_PRIOR)),
            theta_prior = instantiate_distribution(_model_prior(adstock_priors, "theta", _DEFAULT_THETA_PRIOR)),
            adstock_lam_prior = instantiate_distribution(_model_prior(adstock_priors, "lam", adstock_weibull_defaults.lam)),
            adstock_k_prior = instantiate_distribution(_model_prior(adstock_priors, "k", adstock_weibull_defaults.k)),
            lam_prior = instantiate_distribution(_model_prior(saturation_priors, "lam", _DEFAULT_LAM_PRIOR)),
            mm_alpha_prior = instantiate_distribution(_model_prior(saturation_priors, "alpha", _DEFAULT_MM_ALPHA_PRIOR)),
            mm_lam_prior = instantiate_distribution(_model_prior(saturation_priors, "lam", _DEFAULT_MM_LAM_PRIOR)),
            b_prior = instantiate_distribution(_model_prior(saturation_priors, "b", _DEFAULT_B_PRIOR)),
            c_prior = instantiate_distribution(_model_prior(saturation_priors, "c", _DEFAULT_C_PRIOR)),
            slope_prior = instantiate_distribution(_model_prior(saturation_priors, "slope", _DEFAULT_SLOPE_PRIOR)),
            kappa_prior = instantiate_distribution(_model_prior(saturation_priors, "kappa", _DEFAULT_KAPPA_PRIOR)),
            seasonality_type = seasonality_type,
            seasonality_features = seasonality_features,
            seasonality_beta_prior = instantiate_distribution(
                _model_prior(seasonality_priors, "beta", _DEFAULT_SEASONALITY_BETA_PRIOR),
            ),
            trend_type = trend_type,
            trend_features = trend_features,
            trend_beta_prior = instantiate_distribution(
                _model_prior(trend_priors, "beta", _DEFAULT_TREND_BETA_PRIOR),
            ),
            trend_delta_prior = instantiate_distribution(
                get(trend_priors, "delta", _DEFAULT_TREND_DELTA_PRIOR),
            ),
            event_columns = event_columns,
            holiday_columns = holiday_columns,
            controls_transform = controls_transform,
            control_transform_state = resolved_control_transform_state,
        ), controls_matrix
end

function _turing_runtime(spec::MMMModelSpec, data::MMMData; control_transform_state = nothing)
    _validate_model_data_alignment(spec, data)

    adstock_type = _transform_type(spec.adstock, :adstock)
    saturation_type = _transform_type(spec.saturation, :saturation)
    seasonality_type = _seasonality_type(spec.seasonality)
    trend_type = _trend_type(spec.trend)

    adstock_type in (:none, :geometric, :delayed, :binomial, :weibull_pdf, :weibull_cdf) ||
        throw(ArgumentError("only `geometric`, `delayed`, `binomial`, and Weibull adstock are supported in the current Turing model path"))
    saturation_type in (:none, :logistic, :tanh, :michaelis_menten, :hill) ||
        throw(ArgumentError("only `logistic`, `tanh`, `michaelis_menten`, and `hill` saturation are supported in the current Turing model path"))
    seasonality_type in (:none, :fourier) ||
        throw(ArgumentError("only `fourier` seasonality is supported in the current Turing model path"))
    trend_type in (:none, :linear, :changepoint) ||
        throw(
        ArgumentError(
            "only `linear` and `changepoint` trend are supported in the current Turing model path",
        ),
    )

    adstock_priors = _mapping_value(spec.adstock, "priors")
    saturation_priors = _mapping_value(spec.saturation, "priors")
    seasonality_priors = _mapping_value(spec.seasonality, "priors")
    trend_priors = _mapping_value(spec.trend, "priors")
    events_priors = _mapping_value(spec.events, "priors")
    holidays_priors = _mapping_value(spec.holidays, "priors")
    controls_priors = _mapping_value(spec.controls, "priors")
    adstock_weibull_defaults = _default_weibull_adstock_priors(adstock_type)
    seasonality_features = _seasonality_features(spec.seasonality, data.dates)
    trend_features = _trend_features(spec.trend, data.dates)
    event_columns = _events_columns(spec.events)
    holiday_columns = _holidays_columns(spec.holidays)
    controls_transform = _controls_transform(spec.controls)
    controls_matrix, resolved_control_transform_state = _control_design_matrix(
        spec.controls,
        data.controls;
        control_transform_state,
    )

    return (
            nchannels = size(data.channels, 2),
            ncontrols = isnothing(controls_matrix) ? 0 : size(controls_matrix, 2),
            nevents = length(event_columns),
            nholidays = length(holiday_columns),
            nseasonality_terms = size(seasonality_features, 2),
            ntrend_terms = size(trend_features, 2),
            intercept_prior = instantiate_distribution(_model_prior(spec.priors, "intercept", _DEFAULT_INTERCEPT_PRIOR)),
            sigma_prior = instantiate_distribution(_model_prior(spec.priors, "sigma", _DEFAULT_SIGMA_PRIOR)),
            media_beta_prior = instantiate_distribution(_model_prior(spec.priors, "beta_media", _DEFAULT_MEDIA_BETA_PRIOR)),
            uses_external_media_beta = saturation_type != :michaelis_menten,
            control_beta_prior = instantiate_distribution(_control_beta_prior(spec.priors, controls_priors)),
            event_beta_prior = instantiate_distribution(
                _model_prior(events_priors, "beta", _DEFAULT_EVENT_BETA_PRIOR),
            ),
            holiday_beta_prior = instantiate_distribution(
                _model_prior(holidays_priors, "beta", _DEFAULT_HOLIDAY_BETA_PRIOR),
            ),
            adstock_type = adstock_type,
            saturation_type = saturation_type,
            l_max = Int(get(spec.adstock, "l_max", 12)),
            normalize_adstock = Bool(get(spec.adstock, "normalize", false)),
            weibull_type = _weibull_runtime_type(adstock_type),
            alpha_prior = instantiate_distribution(_model_prior(adstock_priors, "alpha", _DEFAULT_ALPHA_PRIOR)),
            theta_prior = instantiate_distribution(_model_prior(adstock_priors, "theta", _DEFAULT_THETA_PRIOR)),
            adstock_lam_prior = instantiate_distribution(_model_prior(adstock_priors, "lam", adstock_weibull_defaults.lam)),
            adstock_k_prior = instantiate_distribution(_model_prior(adstock_priors, "k", adstock_weibull_defaults.k)),
            lam_prior = instantiate_distribution(_model_prior(saturation_priors, "lam", _DEFAULT_LAM_PRIOR)),
            mm_alpha_prior = instantiate_distribution(_model_prior(saturation_priors, "alpha", _DEFAULT_MM_ALPHA_PRIOR)),
            mm_lam_prior = instantiate_distribution(_model_prior(saturation_priors, "lam", _DEFAULT_MM_LAM_PRIOR)),
            b_prior = instantiate_distribution(_model_prior(saturation_priors, "b", _DEFAULT_B_PRIOR)),
            c_prior = instantiate_distribution(_model_prior(saturation_priors, "c", _DEFAULT_C_PRIOR)),
            slope_prior = instantiate_distribution(_model_prior(saturation_priors, "slope", _DEFAULT_SLOPE_PRIOR)),
            kappa_prior = instantiate_distribution(_model_prior(saturation_priors, "kappa", _DEFAULT_KAPPA_PRIOR)),
            seasonality_type = seasonality_type,
            seasonality_features = seasonality_features,
            seasonality_beta_prior = instantiate_distribution(
                _model_prior(seasonality_priors, "beta", _DEFAULT_SEASONALITY_BETA_PRIOR),
            ),
            trend_type = trend_type,
            trend_features = trend_features,
            trend_beta_prior = instantiate_distribution(
                _model_prior(trend_priors, "beta", _DEFAULT_TREND_BETA_PRIOR),
            ),
            trend_delta_prior = instantiate_distribution(
                get(trend_priors, "delta", _DEFAULT_TREND_DELTA_PRIOR),
            ),
            event_columns = event_columns,
            holiday_columns = holiday_columns,
            controls_transform = controls_transform,
            control_transform_state = resolved_control_transform_state,
        ), controls_matrix
end

function _transform_type(config::Dict{String, Any}, name::Symbol)
    raw = get(config, "type", "none")
    raw isa AbstractString || throw(ArgumentError("$(String(name)) type must be a string"))
    normalized = lowercase(String(raw))
    return isempty(normalized) ? :none : Symbol(normalized)
end

function _validate_adstock_config(config::Dict{String, Any})
    adstock_type = _transform_type(config, :adstock)
    adstock_type in (:none, :geometric, :delayed, :binomial, :weibull_pdf, :weibull_cdf) ||
        throw(
        ArgumentError(
            "adstock.type must be `none`, `geometric`, `delayed`, `binomial`, `weibull_pdf`, or `weibull_cdf` in the current model path",
        ),
    )

    allowed_keys = adstock_type === :none ? Set(["type"]) : Set(["type", "l_max", "normalize", "priors"])
    keys_set = Set(String(key) for key in keys(config))
    isempty(setdiff(keys_set, allowed_keys)) ||
        throw(
        ArgumentError(
            "adstock supports only `type`, `l_max`, `normalize`, and `priors` in the current model path",
        ),
    )

    if adstock_type !== :none
        l_max = get(config, "l_max", 12)
        l_max isa Integer || throw(ArgumentError("adstock.l_max must be a positive integer"))
        Int(l_max) > 0 || throw(ArgumentError("adstock.l_max must be positive"))

        normalize = get(config, "normalize", false)
        normalize isa Bool || throw(ArgumentError("adstock.normalize must be boolean"))

        priors = get(config, "priors", Dict{String, Any}())
        priors isa AbstractDict || throw(ArgumentError("adstock.priors must be a mapping"))
        prior_keys = Set(String(key) for key in keys(priors))
        allowed_priors = if adstock_type === :delayed
            Set(["alpha", "theta"])
        elseif adstock_type === :weibull_pdf || adstock_type === :weibull_cdf
            Set(["lam", "k"])
        elseif adstock_type === :geometric || adstock_type === :binomial
            Set(["alpha"])
        else
            Set{String}()
        end
        isempty(setdiff(prior_keys, allowed_priors)) ||
            throw(
            ArgumentError(
                "adstock.priors keys are not valid for adstock.type = `$(String(adstock_type))` in the current model path",
            ),
        )
    end

    return nothing
end

function _validate_saturation_config(config::Dict{String, Any})
    saturation_type = _transform_type(config, :saturation)
    saturation_type in (:none, :logistic, :tanh, :michaelis_menten, :hill) ||
        throw(
        ArgumentError(
            "saturation.type must be `none`, `logistic`, `tanh`, `michaelis_menten`, or `hill` in the current model path",
        ),
    )

    allowed_keys = saturation_type === :none ? Set(["type"]) : Set(["type", "priors"])
    keys_set = Set(String(key) for key in keys(config))
    isempty(setdiff(keys_set, allowed_keys)) ||
        throw(
        ArgumentError(
            "saturation supports only `type` and `priors` in the current model path",
        ),
    )

    if saturation_type !== :none
        priors = get(config, "priors", Dict{String, Any}())
        priors isa AbstractDict || throw(ArgumentError("saturation.priors must be a mapping"))
        prior_keys = Set(String(key) for key in keys(priors))
        allowed_priors = if saturation_type === :logistic
            Set(["lam"])
        elseif saturation_type === :tanh
            Set(["b", "c"])
        elseif saturation_type === :michaelis_menten
            Set(["alpha", "lam"])
        elseif saturation_type === :hill
            Set(["slope", "kappa"])
        else
            Set{String}()
        end
        isempty(setdiff(prior_keys, allowed_priors)) ||
            throw(
            ArgumentError(
                "saturation.priors keys are not valid for saturation.type = `$(String(saturation_type))` in the current model path",
            ),
        )
    end

    return nothing
end

function _mapping_value(config::Dict{String, Any}, key::AbstractString)
    value = get(config, key, Dict{String, Any}())
    value isa AbstractDict || throw(ArgumentError("$key must be a mapping"))
    return Dict{String, Any}(String(k) => v for (k, v) in value)
end

function _model_prior(priors::Dict{String, Any}, key::AbstractString, default)
    return get(priors, key, default)
end

function _control_beta_prior(priors::Dict{String, Any}, controls_priors::Dict{String, Any})
    return get(controls_priors, "beta", _DEFAULT_CONTROL_BETA_PRIOR)
end

function _weibull_runtime_type(adstock_type::Symbol)
    adstock_type === :weibull_pdf && return PDF
    adstock_type === :weibull_cdf && return CDF
    return nothing
end

function _default_weibull_adstock_priors(adstock_type::Symbol)
    if adstock_type === :weibull_pdf
        return (; lam = _DEFAULT_WEIBULL_PDF_LAM_PRIOR, k = _DEFAULT_WEIBULL_PDF_K_PRIOR)
    elseif adstock_type === :weibull_cdf
        return (; lam = _DEFAULT_WEIBULL_CDF_LAM_PRIOR, k = _DEFAULT_WEIBULL_CDF_K_PRIOR)
    end
    return (; lam = _DEFAULT_WEIBULL_PDF_LAM_PRIOR, k = _DEFAULT_WEIBULL_PDF_K_PRIOR)
end
