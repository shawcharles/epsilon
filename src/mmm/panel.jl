const _DEFAULT_PANEL_INTERCEPT_SCALE_PRIOR = EpsilonPrior("HalfNormal"; sigma = 1.0)

@model function _panel_mmm_model(target, channels, runtime)
    intercept ~ Turing.filldist(runtime.intercept_prior, runtime.nintercepts)
    intercept_effect = if runtime.intercept_shape === :panel
        reshape(intercept, 1, runtime.npanels)
    else
        panel_intercept_scale ~ runtime.panel_intercept_scale_prior
        panel_intercept_offset ~ Turing.filldist(Normal(0, panel_intercept_scale), runtime.npanels)
        centered_panel_offset = panel_intercept_offset .- mean(panel_intercept_offset)
        intercept[1] .+ reshape(centered_panel_offset, 1, runtime.npanels)
    end

    sigma ~ Turing.filldist(runtime.sigma_prior, runtime.nsigmas)

    beta_media_values = fill(one(eltype(channels)), runtime.nchannels, runtime.npanels)
    if runtime.uses_external_media_beta
        beta_media ~ Turing.filldist(runtime.media_beta_prior, runtime.nmedia_beta)
        beta_media_values = _panel_parameter_matrix(beta_media, runtime.media_beta_shape, runtime)
    end

    transformed_media = channels
    if runtime.adstock_type === :geometric || runtime.adstock_type === :binomial
        alpha ~ Turing.filldist(runtime.alpha_prior, runtime.nalpha)
        alpha_values = _panel_parameter_matrix(alpha, runtime.alpha_shape, runtime)
        transformed_media = _apply_panel_adstock(channels, runtime; alpha = alpha_values)
    elseif runtime.adstock_type === :delayed
        alpha ~ Turing.filldist(runtime.alpha_prior, runtime.nalpha)
        theta ~ Turing.filldist(runtime.theta_prior, runtime.ntheta)
        alpha_values = _panel_parameter_matrix(alpha, runtime.alpha_shape, runtime)
        theta_values = _panel_parameter_matrix(theta, runtime.theta_shape, runtime)
        transformed_media = _apply_panel_adstock(channels, runtime; alpha = alpha_values, theta = theta_values)
    elseif runtime.adstock_type === :weibull_pdf || runtime.adstock_type === :weibull_cdf
        lam_adstock ~ Turing.filldist(runtime.adstock_lam_prior, runtime.nadstock_lam)
        k_adstock ~ Turing.filldist(runtime.adstock_k_prior, runtime.nadstock_k)
        lam_adstock_values = _panel_parameter_matrix(lam_adstock, runtime.adstock_lam_shape, runtime)
        k_adstock_values = _panel_parameter_matrix(k_adstock, runtime.adstock_k_shape, runtime)
        transformed_media = _apply_panel_adstock(channels, runtime; lam = lam_adstock_values, k = k_adstock_values)
    elseif runtime.adstock_type === :none
        transformed_media = _apply_panel_adstock(channels, runtime)
    end

    if runtime.saturation_type === :logistic
        lam ~ Turing.filldist(runtime.lam_prior, runtime.nlam)
        lam_values = _panel_parameter_matrix(lam, runtime.lam_shape, runtime)
        transformed_media = _apply_panel_saturation(transformed_media, runtime; lam = lam_values)
    elseif runtime.saturation_type === :tanh
        b ~ Turing.filldist(runtime.b_prior, runtime.nb)
        c ~ Turing.filldist(runtime.c_prior, runtime.nc)
        b_values = _panel_parameter_matrix(b, runtime.b_shape, runtime)
        c_values = _panel_parameter_matrix(c, runtime.c_shape, runtime)
        transformed_media = _apply_panel_saturation(transformed_media, runtime; b = b_values, c = c_values)
    elseif runtime.saturation_type === :michaelis_menten
        alpha_saturation ~ Turing.filldist(runtime.mm_alpha_prior, runtime.nmm_alpha)
        lam ~ Turing.filldist(runtime.mm_lam_prior, runtime.nmm_lam)
        alpha_saturation_values = _panel_parameter_matrix(alpha_saturation, runtime.mm_alpha_shape, runtime)
        lam_values = _panel_parameter_matrix(lam, runtime.mm_lam_shape, runtime)
        transformed_media = _apply_panel_saturation(transformed_media, runtime; alpha = alpha_saturation_values, lam = lam_values)
    elseif runtime.saturation_type === :hill
        slope ~ Turing.filldist(runtime.slope_prior, runtime.nslope)
        kappa ~ Turing.filldist(runtime.kappa_prior, runtime.nkappa)
        slope_values = _panel_parameter_matrix(slope, runtime.slope_shape, runtime)
        kappa_values = _panel_parameter_matrix(kappa, runtime.kappa_shape, runtime)
        transformed_media = _apply_panel_saturation(transformed_media, runtime; slope = slope_values, kappa = kappa_values)
    elseif runtime.saturation_type === :none
        transformed_media = _apply_panel_saturation(transformed_media, runtime)
    end

    media_effect = _panel_media_effect(transformed_media, beta_media_values)
    holiday_effect = zero.(media_effect)
    seasonality_effect = zero.(media_effect)

    if !isnothing(runtime.holiday_features)
        beta_holidays ~ Turing.filldist(runtime.holiday_beta_prior, runtime.nholiday_beta)
        holiday_beta_values = _panel_feature_parameter_matrix(
            beta_holidays,
            runtime.holiday_beta_shape,
            runtime.nholidays,
            runtime.npanels,
        )
        holiday_effect = _panel_additive_feature_effect(runtime.holiday_features, holiday_beta_values)
    end

    if runtime.seasonality_type === :fourier
        beta_seasonality ~ Turing.filldist(
            runtime.seasonality_beta_prior,
            runtime.nseasonality_beta,
        )
        seasonality_beta_values = _panel_feature_parameter_matrix(
            beta_seasonality,
            runtime.seasonality_beta_shape,
            runtime.nseasonality_terms,
            runtime.npanels,
        )
        seasonality_effect = _panel_seasonality_effect(
            runtime.seasonality_features,
            seasonality_beta_values,
            runtime.npanels,
        )
    end

    mu = intercept_effect .+ media_effect .+ holiday_effect .+ seasonality_effect

    for panel in 1:runtime.npanels
        for time in 1:runtime.ntime
            target[time, panel] ~ Normal(mu[time, panel], _panel_parameter_value(sigma, runtime.sigma_shape, panel))
        end
    end

    return (; mu, media_effect, holiday_effect, seasonality_effect)
end

function _fit_panel_mmm!(model::PanelMMM)
    try
        spec = build_model(model)
        runtime = _panel_turing_runtime(spec, model.data)
        scaled_channels = _scale_channels(model.data.channels, spec.channel_scale)
        scaled_target = model.data.target ./ reshape(spec.target_scale, 1, :)
        turing_model = _panel_mmm_model(
            scaled_target,
            scaled_channels,
            runtime,
        )
        sampler = Turing.NUTS(model.sampler_config.tune, model.sampler_config.target_accept)
        execution_plan = _mcmc_execution_plan(model.sampler_config)
        rng = _sampler_rng(model.sampler_config)
        chain = _sample_posterior(rng, turing_model, sampler, model.sampler_config, execution_plan)
        metadata = _artifact_metadata("PanelMMM"; backend = :turing, fit_status = :fit)
        diagnostics_bundle = _mcmc_diagnostics_bundle(
            metadata,
            spec,
            chain,
            model.sampler_config.compute_convergence_checks,
        )
        message = _mcmc_fit_message("PanelMMM", execution_plan)
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
        )
        return _successful_turing_fit!(model, artifact, message)
    catch err
        _mark_failed_turing_fit!(model, err)
        rethrow()
    end
end

function _predict_panel_mmm(model::PanelMMM, new_data::PanelMMMData)
    state = _require_successful_posterior_fit(model.fit_state, "predict")
    artifact = state.artifact
    _validate_model_data_alignment(artifact.spec, new_data)
    _validate_panel_prediction_data(model, new_data)

    runtime = _panel_turing_runtime(artifact.spec, new_data)
    target = Matrix{Union{Missing, eltype(new_data.target)}}(missing, size(new_data.target)...)
    scaled_channels = _scale_channels(new_data.channels, artifact.spec.channel_scale)
    predictive_model = _panel_mmm_model(
        target,
        scaled_channels,
        runtime,
    )
    scaled_chain = Turing.predict(predictive_model, state.artifact.chain)
    return _unscale_predictive_targets(scaled_chain, artifact.spec.target_scale)
end

function _prior_predict_panel_mmm(model::PanelMMM, new_data::PanelMMMData)
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
    _validate_panel_prediction_data(model, new_data)

    runtime = _panel_turing_runtime(runtime_spec, new_data)
    target = Matrix{Union{Missing, eltype(new_data.target)}}(missing, size(new_data.target)...)
    scaled_channels = _scale_channels(new_data.channels, runtime_spec.channel_scale)
    predictive_model = _panel_mmm_model(
        target,
        scaled_channels,
        runtime,
    )
    config = model.sampler_config
    execution = _mcmc_execution_plan(config)
    rng = _sampler_rng(config; offset = 1)
    scaled_chain = _sample_prior(rng, predictive_model, config, execution)
    return _unscale_predictive_targets(scaled_chain, runtime_spec.target_scale)
end

function _panel_turing_runtime(config::ModelConfig, data::PanelMMMData)
    _validate_model_data_alignment(config, data)

    adstock_type = _transform_type(config.adstock, :adstock)
    saturation_type = _transform_type(config.saturation, :saturation)
    adstock_type in (:none, :geometric, :delayed, :binomial, :weibull_pdf, :weibull_cdf) ||
        throw(ArgumentError("PanelMMM supports only the current bounded adstock set"))
    saturation_type in (:none, :logistic, :tanh, :michaelis_menten, :hill) ||
        throw(ArgumentError("PanelMMM supports only the current bounded saturation set"))

    adstock_priors = _mapping_value(config.adstock, "priors")
    saturation_priors = _mapping_value(config.saturation, "priors")
    seasonality_priors = _mapping_value(config.seasonality, "priors")
    holidays_priors = _mapping_value(config.holidays, "priors")
    adstock_weibull_defaults = _default_weibull_adstock_priors(adstock_type)
    panel_dims = _panel_dim_names(config)
    seasonality_type = _seasonality_type(config.seasonality)
    seasonality_features = _seasonality_features(config.seasonality, data.dates)
    holiday_columns = _holidays_columns(config.holidays)
    holiday_features = _holiday_design_matrix(config.holidays, data)

    intercept_prior = _model_prior(config.priors, "intercept", _DEFAULT_INTERCEPT_PRIOR)
    sigma_prior = _panel_sigma_prior(config.priors)
    media_beta_prior = _model_prior(config.priors, "beta_media", _DEFAULT_MEDIA_BETA_PRIOR)
    holiday_beta_prior = _model_prior(holidays_priors, "beta", _DEFAULT_HOLIDAY_BETA_PRIOR)
    seasonality_beta_prior = _panel_seasonality_beta_prior(seasonality_priors, panel_dims)
    alpha_prior = _model_prior(adstock_priors, "alpha", _DEFAULT_ALPHA_PRIOR)
    theta_prior = _model_prior(adstock_priors, "theta", _DEFAULT_THETA_PRIOR)
    adstock_lam_prior = _model_prior(adstock_priors, "lam", adstock_weibull_defaults.lam)
    adstock_k_prior = _model_prior(adstock_priors, "k", adstock_weibull_defaults.k)
    lam_prior = _model_prior(saturation_priors, "lam", _DEFAULT_LAM_PRIOR)
    mm_alpha_prior = _model_prior(saturation_priors, "alpha", _DEFAULT_MM_ALPHA_PRIOR)
    mm_lam_prior = _model_prior(saturation_priors, "lam", _DEFAULT_MM_LAM_PRIOR)
    b_prior = _model_prior(saturation_priors, "b", _DEFAULT_B_PRIOR)
    c_prior = _model_prior(saturation_priors, "c", _DEFAULT_C_PRIOR)
    slope_prior = _model_prior(saturation_priors, "slope", _DEFAULT_SLOPE_PRIOR)
    kappa_prior = _model_prior(saturation_priors, "kappa", _DEFAULT_KAPPA_PRIOR)

    intercept_shape = _panel_prior_shape(intercept_prior, panel_dims; default = :scalar)
    sigma_shape = _panel_prior_shape(sigma_prior, panel_dims; default = :scalar)
    media_beta_shape = _panel_prior_shape(media_beta_prior, panel_dims; default = :channel)
    holiday_beta_shape = _panel_feature_prior_shape(holiday_beta_prior, panel_dims, "holiday"; default = :feature)
    seasonality_beta_shape = _panel_feature_prior_shape(
        seasonality_beta_prior,
        panel_dims,
        "fourier_mode";
        default = :feature_panel,
    )
    alpha_shape = _panel_prior_shape(alpha_prior, panel_dims; default = :channel)
    theta_shape = _panel_prior_shape(theta_prior, panel_dims; default = :channel)
    adstock_lam_shape = _panel_prior_shape(adstock_lam_prior, panel_dims; default = :channel)
    adstock_k_shape = _panel_prior_shape(adstock_k_prior, panel_dims; default = :channel)
    lam_shape = _panel_prior_shape(lam_prior, panel_dims; default = :channel)
    mm_alpha_shape = _panel_prior_shape(mm_alpha_prior, panel_dims; default = :channel)
    mm_lam_shape = _panel_prior_shape(mm_lam_prior, panel_dims; default = :channel)
    b_shape = _panel_prior_shape(b_prior, panel_dims; default = :channel)
    c_shape = _panel_prior_shape(c_prior, panel_dims; default = :channel)
    slope_shape = _panel_prior_shape(slope_prior, panel_dims; default = :channel)
    kappa_shape = _panel_prior_shape(kappa_prior, panel_dims; default = :channel)

    return (
        ntime = size(data.target, 1),
        npanels = size(data.target, 2),
        nchannels = size(data.channels, 2),
        nintercepts = _panel_parameter_length(intercept_shape, size(data.channels, 2), size(data.target, 2)),
        nsigmas = _panel_parameter_length(sigma_shape, size(data.channels, 2), size(data.target, 2)),
        nmedia_beta = _panel_parameter_length(media_beta_shape, size(data.channels, 2), size(data.target, 2)),
        nholidays = length(holiday_columns),
        nholiday_beta = _panel_feature_parameter_length(
            holiday_beta_shape,
            length(holiday_columns),
            size(data.target, 2),
        ),
        nseasonality_terms = size(seasonality_features, 2),
        nseasonality_beta = _panel_feature_parameter_length(
            seasonality_beta_shape,
            size(seasonality_features, 2),
            size(data.target, 2),
        ),
        nalpha = _panel_parameter_length(alpha_shape, size(data.channels, 2), size(data.target, 2)),
        ntheta = _panel_parameter_length(theta_shape, size(data.channels, 2), size(data.target, 2)),
        nadstock_lam = _panel_parameter_length(adstock_lam_shape, size(data.channels, 2), size(data.target, 2)),
        nadstock_k = _panel_parameter_length(adstock_k_shape, size(data.channels, 2), size(data.target, 2)),
        nlam = _panel_parameter_length(lam_shape, size(data.channels, 2), size(data.target, 2)),
        nmm_alpha = _panel_parameter_length(mm_alpha_shape, size(data.channels, 2), size(data.target, 2)),
        nmm_lam = _panel_parameter_length(mm_lam_shape, size(data.channels, 2), size(data.target, 2)),
        nb = _panel_parameter_length(b_shape, size(data.channels, 2), size(data.target, 2)),
        nc = _panel_parameter_length(c_shape, size(data.channels, 2), size(data.target, 2)),
        nslope = _panel_parameter_length(slope_shape, size(data.channels, 2), size(data.target, 2)),
        nkappa = _panel_parameter_length(kappa_shape, size(data.channels, 2), size(data.target, 2)),
        intercept_shape = intercept_shape,
        sigma_shape = sigma_shape,
        media_beta_shape = media_beta_shape,
        holiday_beta_shape = holiday_beta_shape,
        seasonality_beta_shape = seasonality_beta_shape,
        alpha_shape = alpha_shape,
        theta_shape = theta_shape,
        adstock_lam_shape = adstock_lam_shape,
        adstock_k_shape = adstock_k_shape,
        lam_shape = lam_shape,
        mm_alpha_shape = mm_alpha_shape,
        mm_lam_shape = mm_lam_shape,
        b_shape = b_shape,
        c_shape = c_shape,
        slope_shape = slope_shape,
        kappa_shape = kappa_shape,
        intercept_prior = instantiate_distribution(intercept_prior),
        sigma_prior = instantiate_distribution(sigma_prior),
        panel_intercept_scale_prior = instantiate_distribution(
            _model_prior(config.priors, "panel_intercept_scale", _DEFAULT_PANEL_INTERCEPT_SCALE_PRIOR),
        ),
        media_beta_prior = instantiate_distribution(media_beta_prior),
        holiday_beta_prior = instantiate_distribution(holiday_beta_prior),
        seasonality_beta_prior = instantiate_distribution(seasonality_beta_prior),
        uses_external_media_beta = saturation_type != :michaelis_menten,
        holiday_columns = holiday_columns,
        holiday_features = holiday_features,
        seasonality_type = seasonality_type,
        seasonality_features = seasonality_features,
        adstock_type = adstock_type,
        saturation_type = saturation_type,
        l_max = Int(get(config.adstock, "l_max", 12)),
        normalize_adstock = Bool(get(config.adstock, "normalize", false)),
        weibull_type = _weibull_runtime_type(adstock_type),
        alpha_prior = instantiate_distribution(alpha_prior),
        theta_prior = instantiate_distribution(theta_prior),
        adstock_lam_prior = instantiate_distribution(adstock_lam_prior),
        adstock_k_prior = instantiate_distribution(adstock_k_prior),
        lam_prior = instantiate_distribution(lam_prior),
        mm_alpha_prior = instantiate_distribution(mm_alpha_prior),
        mm_lam_prior = instantiate_distribution(mm_lam_prior),
        b_prior = instantiate_distribution(b_prior),
        c_prior = instantiate_distribution(c_prior),
        slope_prior = instantiate_distribution(slope_prior),
        kappa_prior = instantiate_distribution(kappa_prior),
    )
end

function _panel_turing_runtime(spec::MMMModelSpec, data::PanelMMMData)
    _validate_model_data_alignment(spec, data)

    adstock_type = _transform_type(spec.adstock, :adstock)
    saturation_type = _transform_type(spec.saturation, :saturation)
    adstock_type in (:none, :geometric, :delayed, :binomial, :weibull_pdf, :weibull_cdf) ||
        throw(ArgumentError("PanelMMM supports only the current bounded adstock set"))
    saturation_type in (:none, :logistic, :tanh, :michaelis_menten, :hill) ||
        throw(ArgumentError("PanelMMM supports only the current bounded saturation set"))

    adstock_priors = _mapping_value(spec.adstock, "priors")
    saturation_priors = _mapping_value(spec.saturation, "priors")
    seasonality_priors = _mapping_value(spec.seasonality, "priors")
    holidays_priors = _mapping_value(spec.holidays, "priors")
    adstock_weibull_defaults = _default_weibull_adstock_priors(adstock_type)
    panel_dims = _panel_dim_names(spec)
    seasonality_type = _seasonality_type(spec.seasonality)
    seasonality_features = _seasonality_features(spec.seasonality, data.dates)
    holiday_columns = _holidays_columns(spec.holidays)
    holiday_features = _holiday_design_matrix(spec.holidays, data)

    intercept_prior = _model_prior(spec.priors, "intercept", _DEFAULT_INTERCEPT_PRIOR)
    sigma_prior = _panel_sigma_prior(spec.priors)
    media_beta_prior = _model_prior(spec.priors, "beta_media", _DEFAULT_MEDIA_BETA_PRIOR)
    holiday_beta_prior = _model_prior(holidays_priors, "beta", _DEFAULT_HOLIDAY_BETA_PRIOR)
    seasonality_beta_prior = _panel_seasonality_beta_prior(seasonality_priors, panel_dims)
    alpha_prior = _model_prior(adstock_priors, "alpha", _DEFAULT_ALPHA_PRIOR)
    theta_prior = _model_prior(adstock_priors, "theta", _DEFAULT_THETA_PRIOR)
    adstock_lam_prior = _model_prior(adstock_priors, "lam", adstock_weibull_defaults.lam)
    adstock_k_prior = _model_prior(adstock_priors, "k", adstock_weibull_defaults.k)
    lam_prior = _model_prior(saturation_priors, "lam", _DEFAULT_LAM_PRIOR)
    mm_alpha_prior = _model_prior(saturation_priors, "alpha", _DEFAULT_MM_ALPHA_PRIOR)
    mm_lam_prior = _model_prior(saturation_priors, "lam", _DEFAULT_MM_LAM_PRIOR)
    b_prior = _model_prior(saturation_priors, "b", _DEFAULT_B_PRIOR)
    c_prior = _model_prior(saturation_priors, "c", _DEFAULT_C_PRIOR)
    slope_prior = _model_prior(saturation_priors, "slope", _DEFAULT_SLOPE_PRIOR)
    kappa_prior = _model_prior(saturation_priors, "kappa", _DEFAULT_KAPPA_PRIOR)

    intercept_shape = _panel_prior_shape(intercept_prior, panel_dims; default = :scalar)
    sigma_shape = _panel_prior_shape(sigma_prior, panel_dims; default = :scalar)
    media_beta_shape = _panel_prior_shape(media_beta_prior, panel_dims; default = :channel)
    holiday_beta_shape = _panel_feature_prior_shape(holiday_beta_prior, panel_dims, "holiday"; default = :feature)
    seasonality_beta_shape = _panel_feature_prior_shape(
        seasonality_beta_prior,
        panel_dims,
        "fourier_mode";
        default = :feature_panel,
    )
    alpha_shape = _panel_prior_shape(alpha_prior, panel_dims; default = :channel)
    theta_shape = _panel_prior_shape(theta_prior, panel_dims; default = :channel)
    adstock_lam_shape = _panel_prior_shape(adstock_lam_prior, panel_dims; default = :channel)
    adstock_k_shape = _panel_prior_shape(adstock_k_prior, panel_dims; default = :channel)
    lam_shape = _panel_prior_shape(lam_prior, panel_dims; default = :channel)
    mm_alpha_shape = _panel_prior_shape(mm_alpha_prior, panel_dims; default = :channel)
    mm_lam_shape = _panel_prior_shape(mm_lam_prior, panel_dims; default = :channel)
    b_shape = _panel_prior_shape(b_prior, panel_dims; default = :channel)
    c_shape = _panel_prior_shape(c_prior, panel_dims; default = :channel)
    slope_shape = _panel_prior_shape(slope_prior, panel_dims; default = :channel)
    kappa_shape = _panel_prior_shape(kappa_prior, panel_dims; default = :channel)

    return (
        ntime = size(data.target, 1),
        npanels = size(data.target, 2),
        nchannels = size(data.channels, 2),
        nintercepts = _panel_parameter_length(intercept_shape, size(data.channels, 2), size(data.target, 2)),
        nsigmas = _panel_parameter_length(sigma_shape, size(data.channels, 2), size(data.target, 2)),
        nmedia_beta = _panel_parameter_length(media_beta_shape, size(data.channels, 2), size(data.target, 2)),
        nholidays = length(holiday_columns),
        nholiday_beta = _panel_feature_parameter_length(
            holiday_beta_shape,
            length(holiday_columns),
            size(data.target, 2),
        ),
        nseasonality_terms = size(seasonality_features, 2),
        nseasonality_beta = _panel_feature_parameter_length(
            seasonality_beta_shape,
            size(seasonality_features, 2),
            size(data.target, 2),
        ),
        nalpha = _panel_parameter_length(alpha_shape, size(data.channels, 2), size(data.target, 2)),
        ntheta = _panel_parameter_length(theta_shape, size(data.channels, 2), size(data.target, 2)),
        nadstock_lam = _panel_parameter_length(adstock_lam_shape, size(data.channels, 2), size(data.target, 2)),
        nadstock_k = _panel_parameter_length(adstock_k_shape, size(data.channels, 2), size(data.target, 2)),
        nlam = _panel_parameter_length(lam_shape, size(data.channels, 2), size(data.target, 2)),
        nmm_alpha = _panel_parameter_length(mm_alpha_shape, size(data.channels, 2), size(data.target, 2)),
        nmm_lam = _panel_parameter_length(mm_lam_shape, size(data.channels, 2), size(data.target, 2)),
        nb = _panel_parameter_length(b_shape, size(data.channels, 2), size(data.target, 2)),
        nc = _panel_parameter_length(c_shape, size(data.channels, 2), size(data.target, 2)),
        nslope = _panel_parameter_length(slope_shape, size(data.channels, 2), size(data.target, 2)),
        nkappa = _panel_parameter_length(kappa_shape, size(data.channels, 2), size(data.target, 2)),
        intercept_shape = intercept_shape,
        sigma_shape = sigma_shape,
        media_beta_shape = media_beta_shape,
        holiday_beta_shape = holiday_beta_shape,
        seasonality_beta_shape = seasonality_beta_shape,
        alpha_shape = alpha_shape,
        theta_shape = theta_shape,
        adstock_lam_shape = adstock_lam_shape,
        adstock_k_shape = adstock_k_shape,
        lam_shape = lam_shape,
        mm_alpha_shape = mm_alpha_shape,
        mm_lam_shape = mm_lam_shape,
        b_shape = b_shape,
        c_shape = c_shape,
        slope_shape = slope_shape,
        kappa_shape = kappa_shape,
        intercept_prior = instantiate_distribution(intercept_prior),
        sigma_prior = instantiate_distribution(sigma_prior),
        panel_intercept_scale_prior = instantiate_distribution(
            _model_prior(spec.priors, "panel_intercept_scale", _DEFAULT_PANEL_INTERCEPT_SCALE_PRIOR),
        ),
        media_beta_prior = instantiate_distribution(media_beta_prior),
        holiday_beta_prior = instantiate_distribution(holiday_beta_prior),
        seasonality_beta_prior = instantiate_distribution(seasonality_beta_prior),
        uses_external_media_beta = saturation_type != :michaelis_menten,
        holiday_columns = holiday_columns,
        holiday_features = holiday_features,
        seasonality_type = seasonality_type,
        seasonality_features = seasonality_features,
        adstock_type = adstock_type,
        saturation_type = saturation_type,
        l_max = Int(get(spec.adstock, "l_max", 12)),
        normalize_adstock = Bool(get(spec.adstock, "normalize", false)),
        weibull_type = _weibull_runtime_type(adstock_type),
        alpha_prior = instantiate_distribution(alpha_prior),
        theta_prior = instantiate_distribution(theta_prior),
        adstock_lam_prior = instantiate_distribution(adstock_lam_prior),
        adstock_k_prior = instantiate_distribution(adstock_k_prior),
        lam_prior = instantiate_distribution(lam_prior),
        mm_alpha_prior = instantiate_distribution(mm_alpha_prior),
        mm_lam_prior = instantiate_distribution(mm_lam_prior),
        b_prior = instantiate_distribution(b_prior),
        c_prior = instantiate_distribution(c_prior),
        slope_prior = instantiate_distribution(slope_prior),
        kappa_prior = instantiate_distribution(kappa_prior),
    )
end

function _panel_seasonality_beta_prior(priors::Dict{String, Any}, panel_dims::Tuple{Vararg{String}})
    haskey(priors, "beta") && return priors["beta"]
    return EpsilonPrior("Laplace"; mu = 0.0, b = 1.0, dims = (panel_dims..., "fourier_mode"))
end

function _panel_sigma_prior(priors::Dict{String, Any})
    sigma_prior = get(priors, "sigma", nothing)
    sigma_prior isa EpsilonPrior && return sigma_prior

    likelihood_prior = get(priors, "likelihood", nothing)
    if likelihood_prior isa EpsilonPrior
        nested_sigma = get(likelihood_prior.parameters, :sigma, nothing)
        nested_sigma isa EpsilonPrior && return nested_sigma
    end
    return _DEFAULT_SIGMA_PRIOR
end

function _panel_prior_shape(prior, panel_dims::Tuple{Vararg{String}}; default::Symbol)
    prior isa EpsilonPrior || return default
    dims = prior.dims
    isnothing(dims) && return default
    has_channel = "channel" in dims
    panel_dim_count = count(dim -> dim in dims, panel_dims)
    0 < panel_dim_count < length(panel_dims) &&
        throw(ArgumentError("PanelMMM priors must include either all panel dimensions or none"))
    has_panel = panel_dim_count == length(panel_dims)
    has_channel && has_panel && return :channel_panel
    has_channel && return :channel
    has_panel && return :panel
    return :scalar
end

function _panel_feature_prior_shape(
        prior,
        panel_dims::Tuple{Vararg{String}},
        feature_dim::AbstractString;
        default::Symbol,
    )
    prior isa EpsilonPrior || return default
    dims = prior.dims
    isnothing(dims) && return default
    has_feature = feature_dim in dims
    panel_dim_count = count(dim -> dim in dims, panel_dims)
    0 < panel_dim_count < length(panel_dims) &&
        throw(ArgumentError("PanelMMM feature priors must include either all panel dimensions or none"))
    has_panel = panel_dim_count == length(panel_dims)
    has_feature && has_panel && return :feature_panel
    has_feature && return :feature
    has_panel && return :panel
    return :scalar
end

function _panel_parameter_length(shape::Symbol, nchannels::Integer, npanels::Integer)
    shape === :channel_panel && return Int(nchannels * npanels)
    shape === :channel && return Int(nchannels)
    shape === :panel && return Int(npanels)
    return 1
end

function _panel_feature_parameter_length(shape::Symbol, nfeatures::Integer, npanels::Integer)
    shape === :feature_panel && return Int(nfeatures * npanels)
    shape === :feature && return Int(nfeatures)
    shape === :panel && return Int(npanels)
    return 1
end

function _panel_parameter_matrix(values, shape::Symbol, runtime)
    shape === :channel_panel && return reshape(values, runtime.nchannels, runtime.npanels)
    shape === :channel && return values
    shape === :panel && return reshape(values, 1, runtime.npanels)
    return values[1]
end

function _panel_feature_parameter_matrix(values, shape::Symbol, nfeatures::Integer, npanels::Integer)
    shape === :feature_panel && return reshape(values, Int(nfeatures), Int(npanels))
    shape === :feature && return values
    shape === :panel && return reshape(values, 1, Int(npanels))
    return values[1]
end

function _panel_parameter_for_panel(values, panel::Integer)
    values isa AbstractMatrix && return view(values, :, panel)
    values isa AbstractVector && return values
    return values
end

function _panel_parameter_value(values, shape::Symbol, panel::Integer)
    shape === :panel && return values[panel]
    return values[1]
end

function _apply_panel_adstock(
        channels::AbstractArray,
        runtime;
        alpha = nothing,
        theta = nothing,
        lam = nothing,
        k = nothing,
    )
    ndims(channels) == 3 || throw(ArgumentError("panel channels must be 3-dimensional"))
    slices = [
        _apply_adstock(
                channels[:, :, panel],
                runtime;
                alpha = _panel_parameter_for_panel(alpha, panel),
                theta = _panel_parameter_for_panel(theta, panel),
                lam = _panel_parameter_for_panel(lam, panel),
                k = _panel_parameter_for_panel(k, panel),
            ) for panel in axes(channels, 3)
    ]
    return cat(slices...; dims = 3)
end

function _apply_panel_saturation(
        transformed_media::AbstractArray,
        runtime;
        alpha = nothing,
        lam = nothing,
        b = nothing,
        c = nothing,
        slope = nothing,
        kappa = nothing,
    )
    ndims(transformed_media) == 3 ||
        throw(ArgumentError("panel media must be 3-dimensional"))
    slices = [
        _apply_saturation(
                transformed_media[:, :, panel],
                runtime;
                alpha = _panel_parameter_for_panel(alpha, panel),
                lam = _panel_parameter_for_panel(lam, panel),
                b = _panel_parameter_for_panel(b, panel),
                c = _panel_parameter_for_panel(c, panel),
                slope = _panel_parameter_for_panel(slope, panel),
                kappa = _panel_parameter_for_panel(kappa, panel),
            ) for panel in axes(transformed_media, 3)
    ]
    return cat(slices...; dims = 3)
end

function _panel_media_effect(transformed_media::AbstractArray, beta_media)
    beta = beta_media isa AbstractMatrix ? reshape(beta_media, 1, size(beta_media, 1), size(beta_media, 2)) :
        beta_media isa AbstractVector ? reshape(beta_media, 1, :, 1) : beta_media
    weighted = transformed_media .* beta
    return dropdims(sum(weighted; dims = 2); dims = 2)
end

function _panel_additive_feature_effect(features::AbstractArray, beta)
    ndims(features) == 3 ||
        throw(ArgumentError("panel additive features must be 3-dimensional"))
    if beta isa AbstractMatrix && size(beta, 1) == size(features, 2)
        slices = [
            vec(sum(features[:, :, panel] .* reshape(view(beta, :, panel), 1, :); dims = 2))
                for panel in axes(features, 3)
        ]
        return hcat(slices...)
    elseif beta isa AbstractVector && length(beta) == size(features, 2)
        slices = [
            vec(sum(features[:, :, panel] .* reshape(beta, 1, :); dims = 2))
                for panel in axes(features, 3)
        ]
        return hcat(slices...)
    elseif beta isa AbstractMatrix && size(beta, 1) == 1
        feature_totals = dropdims(sum(features; dims = 2); dims = 2)
        return feature_totals .* reshape(beta, 1, :)
    else
        feature_totals = dropdims(sum(features; dims = 2); dims = 2)
        return feature_totals .* beta
    end
end

function _panel_seasonality_effect(features::AbstractMatrix, beta, npanels::Integer)
    if beta isa AbstractMatrix && size(beta, 1) == size(features, 2)
        return features * beta
    elseif beta isa AbstractVector && length(beta) == size(features, 2)
        return repeat(features * beta, 1, Int(npanels))
    elseif beta isa AbstractMatrix && size(beta, 1) == 1
        return vec(sum(features; dims = 2)) .* reshape(beta, 1, :)
    else
        return repeat(vec(sum(features; dims = 2)) .* beta, 1, Int(npanels))
    end
end

function _validate_panel_prediction_data(model::PanelMMM, new_data::PanelMMMData)
    state = model.fit_state
    isnothing(state) && return nothing
    hasproperty(state.artifact, :spec) || return nothing

    panel_dim = _flat_panel_dim_name(state.artifact.spec)
    fitted_panel_names = get(state.artifact.spec.coordinate_metadata.coordinates, panel_dim, nothing)
    isnothing(fitted_panel_names) && return nothing
    new_data.panel_names == fitted_panel_names ||
        throw(
        ArgumentError(
            "PanelMMM prediction currently requires new_data.panel_names to match fitted panel names in order",
        ),
    )
    return nothing
end
