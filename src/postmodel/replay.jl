function _require_postmodel_time_series_results(
        results::InferenceResults,
        action::AbstractString,
    )
    results.spec.model_kind === :time_series_mmm ||
        throw(
        ArgumentError(
            "$action currently supports only time-series grouped inference artifacts; panel post-modeling is not supported in the current surface",
        ),
    )
    _reject_hsgp_media_postmodel_reporting(results.spec, action)
    isnothing(results.posterior) &&
        throw(
        ArgumentError(
            "$action requires grouped posterior draws on `InferenceResults.posterior`",
        ),
    )
    results.observed_data isa MMMData ||
        throw(
        ArgumentError(
            "$action requires `InferenceResults.observed_data` to carry MMMData",
        ),
    )
    return results.observed_data
end

function _reject_hsgp_media_postmodel_reporting(spec::MMMModelSpec, action::AbstractString)
    haskey(spec.priors, _HSGP_MEDIA_SPEC_STATE_KEY) || return nothing
    action in ("contribution_results", "decomposition_results") && return nothing
    throw(
        ArgumentError(
            "$action does not support HSGP media postmodel reporting; HSGP media postmodel reporting is deferred",
        ),
    )
end

function _hsgp_media_multiplier_for_postmodel_draw(
        spec::MMMModelSpec,
        data::MMMData,
        draw_values::AbstractVector,
        parameter_index::Dict{Symbol, Int},
    )
    haskey(spec.priors, _HSGP_MEDIA_SPEC_STATE_KEY) || return nothing

    state = _validate_hsgp_media_state_for_model_data(
        spec,
        data,
        "contribution_results",
    )
    runtime = _turing_hsgp_media_runtime(spec, data)
    Tuple(runtime.current_indices) == state.training.training_indices || throw(
        ArgumentError(
            "contribution_results requires observed dates to match retained HSGP training indices exactly",
        ),
    )
    eta = _required_draw_parameter(draw_values, parameter_index, :hsgp_media_eta)
    lengthscale = _required_draw_parameter(
        draw_values,
        parameter_index,
        :hsgp_media_lengthscale,
    )
    z = _required_draw_parameter_vector(
        draw_values,
        parameter_index,
        "hsgp_media_z",
        runtime.mode_count,
    )
    return _hsgp_media_multiplier(
        state,
        runtime.current_indices,
        eta,
        lengthscale,
        z,
    )
end

function _require_postmodel_panel_results(
        results::InferenceResults,
        action::AbstractString,
    )
    results.spec.model_kind === :panel_mmm ||
        throw(
        ArgumentError(
            "$action requires panel grouped inference artifacts",
        ),
    )
    isnothing(results.posterior) &&
        throw(
        ArgumentError(
            "$action requires grouped posterior draws on `InferenceResults.posterior`",
        ),
    )
    results.observed_data isa PanelMMMData ||
        throw(
        ArgumentError(
            "$action requires `InferenceResults.observed_data` to carry PanelMMMData",
        ),
    )
    return results.observed_data
end

function _postmodel_runtime(spec::MMMModelSpec)
    adstock_type = _transform_type(spec.adstock, :adstock)
    return (
        adstock_type = adstock_type,
        saturation_type = _transform_type(spec.saturation, :saturation),
        l_max = Int(get(spec.adstock, "l_max", 12)),
        normalize_adstock = Bool(get(spec.adstock, "normalize", false)),
        weibull_type = _weibull_runtime_type(adstock_type),
        channel_scale = spec.channel_scale,
        target_scale = spec.target_scale,
    )
end

function _postmodel_design_matrices(spec::MMMModelSpec, data::MMMData)
    control_transform_state = _control_transform_state_from_config(spec.controls)
    if _controls_transform(spec.controls) === :standardize && isnothing(control_transform_state)
        throw(
            ArgumentError(
                "post-model replay requires resolved standardized-control state on `InferenceResults.spec.controls`",
            ),
        )
    end

    controls_matrix, _ = _control_design_matrix(
        spec.controls,
        data.controls;
        control_transform_state,
    )
    return (
        controls = controls_matrix,
        events = _event_design_matrix(spec.events, data),
        holidays = _holiday_design_matrix(spec.holidays, data),
        seasonality = _seasonality_features(spec.seasonality, data.dates),
        trend = _trend_features(spec.trend, data.dates),
    )
end

function _posterior_draw_matrix(chain)
    values = Float64.(Array(chain))
    if ndims(values) == 2
        return values
    elseif ndims(values) == 3
        ndraws, nparameters, nchains = size(values)
        return reshape(
            permutedims(values, (1, 3, 2)),
            ndraws * nchains,
            nparameters,
        )
    end

    throw(ArgumentError("posterior chains must materialize to a 2D or 3D array"))
end

function _posterior_parameter_index(chain)
    return Dict(name => index for (index, name) in enumerate(names(chain, :parameters)))
end

function _validated_spend_grid(
        grid,
        action::AbstractString;
        require_multiple_points::Bool = false,
    )
    spend_grid = Float64.(collect(grid))
    isempty(spend_grid) &&
        throw(ArgumentError("$action requires a non-empty spend grid"))
    require_multiple_points && length(spend_grid) < 2 &&
        throw(ArgumentError("$action requires at least two spend points"))
    all(isfinite, spend_grid) ||
        throw(ArgumentError("$action requires a spend grid with only finite values"))
    all(>=(0.0), spend_grid) ||
        throw(ArgumentError("$action requires a nonnegative spend grid"))
    issorted(spend_grid) ||
        throw(ArgumentError("$action requires a strictly increasing spend grid"))
    all(diff(spend_grid) .> 0.0) ||
        throw(ArgumentError("$action requires a strictly increasing spend grid"))
    return spend_grid
end

function _require_response_curve_channel(spec::MMMModelSpec, channel::AbstractString)
    channel_name = String(channel)
    channel_index = get(spec.channel_indices, channel_name, nothing)
    isnothing(channel_index) &&
        throw(
        ArgumentError(
            "response_curve_results requires one supported media channel from `InferenceResults.spec.channel_columns`",
        ),
    )
    return channel_name, Int(channel_index)
end

function _required_draw_parameter(
        draw_values::AbstractVector,
        parameter_index::Dict{Symbol, Int},
        name::Symbol,
    )
    index = get(parameter_index, name, nothing)
    isnothing(index) &&
        throw(
        ArgumentError(
            "posterior chains are missing required parameter `$name` for deterministic replay",
        ),
    )
    return Float64(draw_values[index])
end

function _required_draw_parameter_vector(
        draw_values::AbstractVector,
        parameter_index::Dict{Symbol, Int},
        base_name::AbstractString,
        count::Integer,
    )
    Int(count) >= 0 || throw(ArgumentError("parameter count must be non-negative"))
    return [
        _required_draw_parameter(
                draw_values,
                parameter_index,
                Symbol("$(base_name)[$(index)]"),
            ) for index in 1:Int(count)
    ]
end

function _draw_panel_parameter_matrix(
        draw_values::AbstractVector,
        parameter_index::Dict{Symbol, Int},
        base_name::AbstractString,
        count::Integer,
        shape::Symbol,
        runtime,
    )
    values = _required_draw_parameter_vector(
        draw_values,
        parameter_index,
        base_name,
        count,
    )
    return _panel_parameter_matrix(values, shape, runtime)
end

function _draw_panel_feature_parameter_matrix(
        draw_values::AbstractVector,
        parameter_index::Dict{Symbol, Int},
        base_name::AbstractString,
        count::Integer,
        shape::Symbol,
        nfeatures::Integer,
        npanels::Integer,
    )
    values = _required_draw_parameter_vector(
        draw_values,
        parameter_index,
        base_name,
        count,
    )
    return _panel_feature_parameter_matrix(values, shape, nfeatures, npanels)
end

function _panel_parameter_component_value(values, channel::Integer, panel::Integer)
    values isa AbstractMatrix && return Float64(values[Int(channel), Int(panel)])
    values isa AbstractVector && return Float64(values[Int(channel)])
    return Float64(values)
end

function _panel_feature_component_value(values, feature::Integer, panel::Integer)
    values isa AbstractMatrix && return Float64(values[Int(feature), Int(panel)])
    values isa AbstractVector && return Float64(values[Int(feature)])
    return Float64(values)
end

function _panel_intercept_values_for_draw(
        runtime,
        draw_values::AbstractVector,
        parameter_index::Dict{Symbol, Int},
    )
    intercept = _draw_panel_parameter_matrix(
        draw_values,
        parameter_index,
        "intercept",
        runtime.nintercepts,
        runtime.intercept_shape,
        runtime,
    )

    if runtime.intercept_shape === :panel
        return vec(intercept)
    end

    base = intercept isa AbstractArray ? Float64(first(intercept)) : Float64(intercept)
    offsets = _required_draw_parameter_vector(
        draw_values,
        parameter_index,
        "panel_intercept_offset",
        runtime.npanels,
    )
    centered_offsets = offsets .- mean(offsets)
    return base .+ centered_offsets
end

function _required_channel_draw_parameter(
        draw_values::AbstractVector,
        parameter_index::Dict{Symbol, Int},
        base_name::AbstractString,
        channel_index::Integer,
    )
    return _required_draw_parameter(
        draw_values,
        parameter_index,
        Symbol("$(base_name)[$(Int(channel_index))]"),
    )
end

function _channel_beta_for_draw(
        runtime,
        draw_values::AbstractVector,
        parameter_index::Dict{Symbol, Int},
        channel_index::Integer,
    )
    name = Symbol("beta_media[$(Int(channel_index))]")
    index = get(parameter_index, name, nothing)
    if isnothing(index)
        runtime.saturation_type === :michaelis_menten &&
            return 1.0
        throw(
            ArgumentError(
                "posterior chains are missing required parameter `$name` for deterministic replay",
            ),
        )
    end
    return Float64(draw_values[index])
end

function _channel_transformed_media_for_draw(
        channel_values::AbstractVector,
        runtime,
        draw_values::AbstractVector,
        parameter_index::Dict{Symbol, Int},
        channel_index::Integer,
    )
    channel_matrix = reshape(Float64.(channel_values), :, 1)
    transformed = if runtime.adstock_type === :geometric || runtime.adstock_type === :binomial
        alpha = [
            _required_channel_draw_parameter(
                draw_values,
                parameter_index,
                "alpha",
                channel_index,
            ),
        ]
        _apply_adstock(channel_matrix, runtime; alpha)
    elseif runtime.adstock_type === :delayed
        alpha = [
            _required_channel_draw_parameter(
                draw_values,
                parameter_index,
                "alpha",
                channel_index,
            ),
        ]
        theta = [
            _required_channel_draw_parameter(
                draw_values,
                parameter_index,
                "theta",
                channel_index,
            ),
        ]
        _apply_adstock(channel_matrix, runtime; alpha, theta)
    elseif runtime.adstock_type === :weibull_pdf || runtime.adstock_type === :weibull_cdf
        lam = [
            _required_channel_draw_parameter(
                draw_values,
                parameter_index,
                "lam_adstock",
                channel_index,
            ),
        ]
        k = [
            _required_channel_draw_parameter(
                draw_values,
                parameter_index,
                "k_adstock",
                channel_index,
            ),
        ]
        _apply_adstock(channel_matrix, runtime; lam, k)
    else
        _apply_adstock(channel_matrix, runtime)
    end

    saturated = if runtime.saturation_type === :logistic
        lam = [_required_channel_draw_parameter(draw_values, parameter_index, "lam", channel_index)]
        _apply_saturation(transformed, runtime; lam)
    elseif runtime.saturation_type === :tanh
        b = [_required_channel_draw_parameter(draw_values, parameter_index, "b", channel_index)]
        c = [_required_channel_draw_parameter(draw_values, parameter_index, "c", channel_index)]
        _apply_saturation(transformed, runtime; b, c)
    elseif runtime.saturation_type === :michaelis_menten
        alpha = [
            _required_channel_draw_parameter(
                draw_values,
                parameter_index,
                "alpha_saturation",
                channel_index,
            ),
        ]
        lam = [_required_channel_draw_parameter(draw_values, parameter_index, "lam", channel_index)]
        _apply_saturation(transformed, runtime; alpha, lam)
    elseif runtime.saturation_type === :hill
        slope = [
            _required_channel_draw_parameter(
                draw_values,
                parameter_index,
                "slope",
                channel_index,
            ),
        ]
        kappa = [
            _required_channel_draw_parameter(
                draw_values,
                parameter_index,
                "kappa",
                channel_index,
            ),
        ]
        _apply_saturation(transformed, runtime; slope, kappa)
    else
        _apply_saturation(transformed, runtime)
    end

    return vec(saturated)
end

function _channel_contribution_path_for_draw(
        channel_values::AbstractVector,
        runtime,
        draw_values::AbstractVector,
        parameter_index::Dict{Symbol, Int},
        channel_index::Integer,
    )
    transformed = _channel_transformed_media_for_draw(
        channel_values,
        runtime,
        draw_values,
        parameter_index,
        channel_index,
    )
    return transformed .* _channel_beta_for_draw(
        runtime,
        draw_values,
        parameter_index,
        channel_index,
    )
end

function _channel_saturation_path_for_draw(
        channel_values::AbstractVector,
        runtime,
        draw_values::AbstractVector,
        parameter_index::Dict{Symbol, Int},
        channel_index::Integer,
    )
    channel_matrix = reshape(Float64.(channel_values), :, 1)
    saturated = if runtime.saturation_type === :logistic
        lam = [_required_channel_draw_parameter(draw_values, parameter_index, "lam", channel_index)]
        _apply_saturation(channel_matrix, runtime; lam)
    elseif runtime.saturation_type === :tanh
        b = [_required_channel_draw_parameter(draw_values, parameter_index, "b", channel_index)]
        c = [_required_channel_draw_parameter(draw_values, parameter_index, "c", channel_index)]
        _apply_saturation(channel_matrix, runtime; b, c)
    elseif runtime.saturation_type === :michaelis_menten
        alpha = [
            _required_channel_draw_parameter(
                draw_values,
                parameter_index,
                "alpha_saturation",
                channel_index,
            ),
        ]
        lam = [_required_channel_draw_parameter(draw_values, parameter_index, "lam", channel_index)]
        _apply_saturation(channel_matrix, runtime; alpha, lam)
    elseif runtime.saturation_type === :hill
        slope = [
            _required_channel_draw_parameter(
                draw_values,
                parameter_index,
                "slope",
                channel_index,
            ),
        ]
        kappa = [
            _required_channel_draw_parameter(
                draw_values,
                parameter_index,
                "kappa",
                channel_index,
            ),
        ]
        _apply_saturation(channel_matrix, runtime; slope, kappa)
    else
        _apply_saturation(channel_matrix, runtime)
    end

    return vec(saturated) .* _channel_beta_for_draw(
        runtime,
        draw_values,
        parameter_index,
        channel_index,
    )
end

function _channel_adstock_path_for_draw(
        channel_values::AbstractVector,
        runtime,
        draw_values::AbstractVector,
        parameter_index::Dict{Symbol, Int},
        channel_index::Integer,
    )
    channel_matrix = reshape(Float64.(channel_values), :, 1)
    transformed = if runtime.adstock_type === :geometric || runtime.adstock_type === :binomial
        alpha = [
            _required_channel_draw_parameter(
                draw_values,
                parameter_index,
                "alpha",
                channel_index,
            ),
        ]
        _apply_adstock(channel_matrix, runtime; alpha)
    elseif runtime.adstock_type === :delayed
        alpha = [
            _required_channel_draw_parameter(
                draw_values,
                parameter_index,
                "alpha",
                channel_index,
            ),
        ]
        theta = [
            _required_channel_draw_parameter(
                draw_values,
                parameter_index,
                "theta",
                channel_index,
            ),
        ]
        _apply_adstock(channel_matrix, runtime; alpha, theta)
    elseif runtime.adstock_type === :weibull_pdf || runtime.adstock_type === :weibull_cdf
        lam = [
            _required_channel_draw_parameter(
                draw_values,
                parameter_index,
                "lam_adstock",
                channel_index,
            ),
        ]
        k = [
            _required_channel_draw_parameter(
                draw_values,
                parameter_index,
                "k_adstock",
                channel_index,
            ),
        ]
        _apply_adstock(channel_matrix, runtime; lam, k)
    else
        _apply_adstock(channel_matrix, runtime)
    end

    return vec(transformed)
end

function _panel_transformed_media_for_draw(
        channels::AbstractArray,
        runtime,
        draw_values::AbstractVector,
        parameter_index::Dict{Symbol, Int},
    )
    transformed = if runtime.adstock_type === :geometric || runtime.adstock_type === :binomial
        alpha = _draw_panel_parameter_matrix(
            draw_values,
            parameter_index,
            "alpha",
            runtime.nalpha,
            runtime.alpha_shape,
            runtime,
        )
        _apply_panel_adstock(channels, runtime; alpha)
    elseif runtime.adstock_type === :delayed
        alpha = _draw_panel_parameter_matrix(
            draw_values,
            parameter_index,
            "alpha",
            runtime.nalpha,
            runtime.alpha_shape,
            runtime,
        )
        theta = _draw_panel_parameter_matrix(
            draw_values,
            parameter_index,
            "theta",
            runtime.ntheta,
            runtime.theta_shape,
            runtime,
        )
        _apply_panel_adstock(channels, runtime; alpha, theta)
    elseif runtime.adstock_type === :weibull_pdf || runtime.adstock_type === :weibull_cdf
        lam = _draw_panel_parameter_matrix(
            draw_values,
            parameter_index,
            "lam_adstock",
            runtime.nadstock_lam,
            runtime.adstock_lam_shape,
            runtime,
        )
        k = _draw_panel_parameter_matrix(
            draw_values,
            parameter_index,
            "k_adstock",
            runtime.nadstock_k,
            runtime.adstock_k_shape,
            runtime,
        )
        _apply_panel_adstock(channels, runtime; lam, k)
    else
        _apply_panel_adstock(channels, runtime)
    end

    if runtime.saturation_type === :logistic
        lam = _draw_panel_parameter_matrix(
            draw_values,
            parameter_index,
            "lam",
            runtime.nlam,
            runtime.lam_shape,
            runtime,
        )
        return _apply_panel_saturation(transformed, runtime; lam)
    elseif runtime.saturation_type === :tanh
        b = _draw_panel_parameter_matrix(
            draw_values,
            parameter_index,
            "b",
            runtime.nb,
            runtime.b_shape,
            runtime,
        )
        c = _draw_panel_parameter_matrix(
            draw_values,
            parameter_index,
            "c",
            runtime.nc,
            runtime.c_shape,
            runtime,
        )
        return _apply_panel_saturation(transformed, runtime; b, c)
    elseif runtime.saturation_type === :michaelis_menten
        alpha = _draw_panel_parameter_matrix(
            draw_values,
            parameter_index,
            "alpha_saturation",
            runtime.nmm_alpha,
            runtime.mm_alpha_shape,
            runtime,
        )
        lam = _draw_panel_parameter_matrix(
            draw_values,
            parameter_index,
            "lam",
            runtime.nmm_lam,
            runtime.mm_lam_shape,
            runtime,
        )
        return _apply_panel_saturation(transformed, runtime; alpha, lam)
    elseif runtime.saturation_type === :hill
        slope = _draw_panel_parameter_matrix(
            draw_values,
            parameter_index,
            "slope",
            runtime.nslope,
            runtime.slope_shape,
            runtime,
        )
        kappa = _draw_panel_parameter_matrix(
            draw_values,
            parameter_index,
            "kappa",
            runtime.nkappa,
            runtime.kappa_shape,
            runtime,
        )
        return _apply_panel_saturation(transformed, runtime; slope, kappa)
    end

    return _apply_panel_saturation(transformed, runtime)
end

function _contribution_component_layout(
        spec::MMMModelSpec,
        design_matrices,
    )
    component_names = String["intercept"]
    component_kinds = Symbol[:intercept]

    media_range = let start = length(component_names) + 1
        append!(component_names, ["media:$(name)" for name in spec.channel_columns])
        append!(component_kinds, fill(:media, spec.nchannels))
        start:(length(component_names))
    end

    control_range = if !isnothing(design_matrices.controls)
        start = length(component_names) + 1
        append!(component_names, ["control:$(name)" for name in spec.control_columns])
        append!(component_kinds, fill(:control, spec.ncontrols))
        start:(length(component_names))
    else
        nothing
    end

    event_names = _events_columns(spec.events)
    event_range = if !isnothing(design_matrices.events)
        start = length(component_names) + 1
        append!(component_names, ["event:$(name)" for name in event_names])
        append!(component_kinds, fill(:event, length(event_names)))
        start:(length(component_names))
    else
        nothing
    end

    holiday_range = if !isnothing(design_matrices.holidays)
        start = length(component_names) + 1
        push!(component_names, "holiday")
        push!(component_kinds, :holiday)
        start:(length(component_names))
    else
        nothing
    end

    seasonality_index = if size(design_matrices.seasonality, 2) > 0
        push!(component_names, "seasonality")
        push!(component_kinds, :seasonality)
        length(component_names)
    else
        nothing
    end

    trend_index = if size(design_matrices.trend, 2) > 0
        push!(component_names, "trend")
        push!(component_kinds, :trend)
        length(component_names)
    else
        nothing
    end

    return (
        component_names = component_names,
        component_kinds = component_kinds,
        intercept_index = 1,
        media_range = media_range,
        control_range = control_range,
        event_range = event_range,
        holiday_range = holiday_range,
        seasonality_index = seasonality_index,
        trend_index = trend_index,
    )
end

function _replayed_contribution_values(results::InferenceResults)
    results.spec.model_kind === :panel_mmm && return _replayed_panel_contribution_values(results)

    data = _require_postmodel_time_series_results(results, "contribution_results")
    spec = results.spec
    runtime = _postmodel_runtime(spec)
    design_matrices = _postmodel_design_matrices(spec, data)
    layout = _contribution_component_layout(spec, design_matrices)
    draw_matrix = _posterior_draw_matrix(results.posterior)
    parameter_index = _posterior_parameter_index(results.posterior)

    ndraws = size(draw_matrix, 1)
    ncomponents = length(layout.component_names)
    values = zeros(Float64, ndraws, nobs(data), ncomponents)
    target_scale = runtime.target_scale

    # Scale channels to match the scaled space the model was fitted in
    channels = _scale_channels(Float64.(data.channels), runtime.channel_scale)

    for draw in 1:ndraws
        draw_values = vec(draw_matrix[draw, :])
        hsgp_multiplier = _hsgp_media_multiplier_for_postmodel_draw(
            spec,
            data,
            draw_values,
            parameter_index,
        )
        # Intercept is in scaled target space; unscale to original
        values[draw, :, layout.intercept_index] .= _required_draw_parameter(
            draw_values,
            parameter_index,
            :intercept,
        ) .* target_scale

        for (local_index, component_index) in enumerate(layout.media_range)
            # Channel contribution is in scaled space; unscale to original
            media_path = _channel_contribution_path_for_draw(
                view(channels, :, local_index),
                runtime,
                draw_values,
                parameter_index,
                local_index,
            )
            !isnothing(hsgp_multiplier) && (media_path .*= hsgp_multiplier)
            values[draw, :, component_index] .= media_path .* target_scale
        end

        if !isnothing(layout.control_range)
            beta_controls = _required_draw_parameter_vector(
                draw_values,
                parameter_index,
                "beta_controls",
                spec.ncontrols,
            )
            # Controls are in scaled space; unscale to original
            control_contributions = design_matrices.controls .* reshape(beta_controls, 1, :)
            for (local_index, component_index) in enumerate(layout.control_range)
                values[draw, :, component_index] .= control_contributions[:, local_index] .* target_scale
            end
        end

        if !isnothing(layout.event_range)
            beta_events = _required_draw_parameter_vector(
                draw_values,
                parameter_index,
                "beta_events",
                size(design_matrices.events, 2),
            )
            # Events are in scaled space; unscale to original
            event_contributions = design_matrices.events .* reshape(beta_events, 1, :)
            for (local_index, component_index) in enumerate(layout.event_range)
                values[draw, :, component_index] .= event_contributions[:, local_index] .* target_scale
            end
        end

        if !isnothing(layout.holiday_range)
            beta_holidays = _required_draw_parameter_vector(
                draw_values,
                parameter_index,
                "beta_holidays",
                size(design_matrices.holidays, 2),
            )
            holiday_contributions =
                design_matrices.holidays .* reshape(beta_holidays, 1, :)
            for (local_index, component_index) in enumerate(layout.holiday_range)
                values[draw, :, component_index] .= holiday_contributions[:, local_index] .* target_scale
            end
        end

        if !isnothing(layout.seasonality_index)
            beta_seasonality = _required_draw_parameter_vector(
                draw_values,
                parameter_index,
                "beta_seasonality",
                size(design_matrices.seasonality, 2),
            )
            # Seasonality is in scaled space; unscale to original
            values[draw, :, layout.seasonality_index] .= vec(
                design_matrices.seasonality * beta_seasonality,
            ) .* target_scale
        end

        if !isnothing(layout.trend_index)
            trend_parameter_base = _trend_type(spec.trend) === :changepoint ? "delta_trend" : "beta_trend"
            beta_trend = _required_draw_parameter_vector(
                draw_values,
                parameter_index,
                trend_parameter_base,
                size(design_matrices.trend, 2),
            )
            # Trend is in scaled space; unscale to original
            values[draw, :, layout.trend_index] .= vec(design_matrices.trend * beta_trend) .* target_scale
        end
    end

    return (
        data = data,
        component_names = layout.component_names,
        component_kinds = layout.component_kinds,
        values = values,
    )
end

function _panel_contribution_component_layout(spec::MMMModelSpec, runtime)
    component_names = String["intercept"]
    component_kinds = Symbol[:intercept]

    media_range = let start = length(component_names) + 1
        append!(component_names, ["media:$(name)" for name in spec.channel_columns])
        append!(component_kinds, fill(:media, spec.nchannels))
        start:(length(component_names))
    end

    holiday_index = if runtime.nholidays > 0
        push!(component_names, "holiday")
        push!(component_kinds, :holiday)
        length(component_names)
    else
        nothing
    end

    seasonality_index = if runtime.seasonality_type === :fourier && runtime.nseasonality_terms > 0
        push!(component_names, "seasonality")
        push!(component_kinds, :seasonality)
        length(component_names)
    else
        nothing
    end

    return (
        component_names = component_names,
        component_kinds = component_kinds,
        intercept_index = 1,
        media_range = media_range,
        holiday_index = holiday_index,
        seasonality_index = seasonality_index,
    )
end

function _replayed_panel_contribution_values(results::InferenceResults)
    data = _require_postmodel_panel_results(results, "contribution_results")
    spec = results.spec
    runtime = _panel_turing_runtime(spec, data)
    layout = _panel_contribution_component_layout(spec, runtime)
    draw_matrix = _posterior_draw_matrix(results.posterior)
    parameter_index = _posterior_parameter_index(results.posterior)

    ndraws = size(draw_matrix, 1)
    ntime = size(data.target, 1)
    npanels = size(data.target, 2)
    ncomponents = length(layout.component_names)
    values = zeros(Float64, ndraws, ntime, npanels, ncomponents)
    channels = _scale_channels(Float64.(data.channels), spec.channel_scale)
    target_scale = reshape(Float64.(spec.target_scale), 1, :)

    for draw in 1:ndraws
        draw_values = vec(draw_matrix[draw, :])

        intercept_values = _panel_intercept_values_for_draw(runtime, draw_values, parameter_index)
        values[draw, :, :, layout.intercept_index] .=
            reshape(intercept_values, 1, :) .* target_scale

        transformed_media = _panel_transformed_media_for_draw(
            channels,
            runtime,
            draw_values,
            parameter_index,
        )
        beta_media = if runtime.uses_external_media_beta
            _draw_panel_parameter_matrix(
                draw_values,
                parameter_index,
                "beta_media",
                runtime.nmedia_beta,
                runtime.media_beta_shape,
                runtime,
            )
        else
            fill(1.0, runtime.nchannels, runtime.npanels)
        end

        for (channel_index, component_index) in enumerate(layout.media_range)
            for panel in 1:npanels
                beta = _panel_parameter_component_value(beta_media, channel_index, panel)
                values[draw, :, panel, component_index] .=
                    transformed_media[:, channel_index, panel] .* beta .* spec.target_scale[panel]
            end
        end

        if !isnothing(layout.holiday_index)
            beta_holidays = _draw_panel_feature_parameter_matrix(
                draw_values,
                parameter_index,
                "beta_holidays",
                runtime.nholiday_beta,
                runtime.holiday_beta_shape,
                runtime.nholidays,
                runtime.npanels,
            )
            holiday_effect = _panel_additive_feature_effect(
                runtime.holiday_features,
                beta_holidays,
            )
            values[draw, :, :, layout.holiday_index] .= holiday_effect .* target_scale
        end

        if !isnothing(layout.seasonality_index)
            beta_seasonality = _draw_panel_feature_parameter_matrix(
                draw_values,
                parameter_index,
                "beta_seasonality",
                runtime.nseasonality_beta,
                runtime.seasonality_beta_shape,
                runtime.nseasonality_terms,
                runtime.npanels,
            )
            seasonality_effect = _panel_seasonality_effect(
                runtime.seasonality_features,
                beta_seasonality,
                runtime.npanels,
            )
            values[draw, :, :, layout.seasonality_index] .= seasonality_effect .* target_scale
        end
    end

    return (
        data = data,
        component_names = layout.component_names,
        component_kinds = layout.component_kinds,
        values = values,
    )
end
