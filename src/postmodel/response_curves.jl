function _time_series_curve_surface_context(
        results::InferenceResults,
        action::AbstractString,
        channel,
        grid,
    )
    data = _require_postmodel_time_series_results(results, action)
    spend_grid = _validated_spend_grid(grid, action)
    channel_name, channel_index = _require_response_curve_channel(results.spec, channel)
    observed_channel = Float64.(data.channels[:, channel_index])
    observed_total_spend = sum(observed_channel)

    observed_total_spend > 0.0 ||
        throw(
        ArgumentError(
            "$action requires the selected channel to have positive observed total spend",
        ),
    )

    return (
        spend_grid = spend_grid,
        spend_share_grid = spend_grid ./ observed_total_spend,
        channel_name = channel_name,
        channel_index = channel_index,
        observed_channel = observed_channel,
        observed_total_spend = observed_total_spend,
        runtime = _postmodel_runtime(results.spec),
        draw_matrix = _posterior_draw_matrix(results.posterior),
        parameter_index = _posterior_parameter_index(results.posterior),
    )
end

function _curve_surface_context(
        results::InferenceResults,
        action::AbstractString,
        channel;
        grid = nothing,
        delta_grid = nothing,
    )
    if results.spec.model_kind === :panel_mmm
        return _panel_curve_surface_context(results, action, channel, delta_grid)
    end

    isnothing(grid) &&
        throw(ArgumentError("$action requires `grid` for time-series curves"))
    return _time_series_curve_surface_context(results, action, channel, grid)
end

function _panel_curve_surface_context(
        results::InferenceResults,
        action::AbstractString,
        channel,
        delta_grid,
    )
    data = _require_postmodel_panel_results(results, action)
    isnothing(delta_grid) &&
        throw(
        ArgumentError(
            "$action requires `delta_grid` for panel curves; panel curves use historical-scaling semantics rather than an aggregate spend grid",
        ),
    )
    delta_values = _validated_spend_grid(delta_grid, action)
    channel_name, channel_index = _require_response_curve_channel(results.spec, channel)
    observed_spend = vec(sum(Float64.(data.channels[:, channel_index, :]); dims = 1))

    all(>(0.0), observed_spend) ||
        throw(
        ArgumentError(
            "$action requires every panel cell for the selected channel to have positive observed total spend",
        ),
    )

    return (
        delta_grid = delta_values,
        spend_grid = observed_spend * transpose(delta_values),
        channel_name = channel_name,
        channel_index = channel_index,
        observed_total_spend = observed_spend,
        runtime = _panel_turing_runtime(results.spec, data),
        spec = results.spec,
        data = data,
        draw_matrix = _posterior_draw_matrix(results.posterior),
        parameter_index = _posterior_parameter_index(results.posterior),
    )
end

function _curve_values(
        context,
        family::Symbol,
    )
    ndraws = size(context.draw_matrix, 1)
    npoints = length(context.spend_grid)
    values = zeros(Float64, ndraws, npoints)
    channel_scale_value = context.runtime.channel_scale[context.channel_index]

    for draw in 1:ndraws
        draw_values = vec(context.draw_matrix[draw, :])
        for point in 1:npoints
            scaled_channel = (context.observed_channel .* context.spend_share_grid[point]) ./
                channel_scale_value
            values[draw, point] = if family === :response
                sum(
                    _channel_contribution_path_for_draw(
                        scaled_channel,
                        context.runtime,
                        draw_values,
                        context.parameter_index,
                        context.channel_index,
                    ),
                ) * context.runtime.target_scale
            elseif family === :saturation
                sum(
                    _channel_saturation_path_for_draw(
                        scaled_channel,
                        context.runtime,
                        draw_values,
                        context.parameter_index,
                        context.channel_index,
                    ),
                ) * context.runtime.target_scale
            elseif family === :adstock
                sum(
                    _channel_adstock_path_for_draw(
                        scaled_channel,
                        context.runtime,
                        draw_values,
                        context.parameter_index,
                        context.channel_index,
                    ),
                ) * channel_scale_value
            else
                throw(ArgumentError("unsupported curve family `$family`"))
            end
        end
    end

    return values
end

function _panel_adstocked_media_for_draw(
        channels::AbstractArray,
        runtime,
        draw_values::AbstractVector,
        parameter_index::Dict{Symbol, Int},
    )
    if runtime.adstock_type === :geometric || runtime.adstock_type === :binomial
        alpha = _draw_panel_parameter_matrix(
            draw_values,
            parameter_index,
            "alpha",
            runtime.nalpha,
            runtime.alpha_shape,
            runtime,
        )
        return _apply_panel_adstock(channels, runtime; alpha)
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
        return _apply_panel_adstock(channels, runtime; alpha, theta)
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
        return _apply_panel_adstock(channels, runtime; lam, k)
    end

    return _apply_panel_adstock(channels, runtime)
end

function _panel_saturated_media_for_draw(
        channels::AbstractArray,
        runtime,
        draw_values::AbstractVector,
        parameter_index::Dict{Symbol, Int},
    )
    if runtime.saturation_type === :logistic
        lam = _draw_panel_parameter_matrix(
            draw_values,
            parameter_index,
            "lam",
            runtime.nlam,
            runtime.lam_shape,
            runtime,
        )
        return _apply_panel_saturation(channels, runtime; lam)
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
        return _apply_panel_saturation(channels, runtime; b, c)
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
        return _apply_panel_saturation(channels, runtime; alpha, lam)
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
        return _apply_panel_saturation(channels, runtime; slope, kappa)
    end

    return _apply_panel_saturation(channels, runtime)
end

function _panel_curve_values(context, family::Symbol)
    ndraws = size(context.draw_matrix, 1)
    npoints = length(context.delta_grid)
    npanels = context.runtime.npanels
    values = zeros(Float64, ndraws, npanels, npoints)
    scaled_channels = _scale_channels(Float64.(context.data.channels), context.spec.channel_scale)

    for draw in 1:ndraws
        draw_values = vec(context.draw_matrix[draw, :])
        beta_media = if context.runtime.uses_external_media_beta
            _draw_panel_parameter_matrix(
                draw_values,
                context.parameter_index,
                "beta_media",
                context.runtime.nmedia_beta,
                context.runtime.media_beta_shape,
                context.runtime,
            )
        else
            fill(1.0, context.runtime.nchannels, context.runtime.npanels)
        end

        for point in 1:npoints
            scenario_channels = zero(scaled_channels)
            scenario_channels[:, context.channel_index, :] .=
                scaled_channels[:, context.channel_index, :] .* context.delta_grid[point]

            transformed = if family === :response
                _panel_transformed_media_for_draw(
                    scenario_channels,
                    context.runtime,
                    draw_values,
                    context.parameter_index,
                )
            elseif family === :saturation
                _panel_saturated_media_for_draw(
                    scenario_channels,
                    context.runtime,
                    draw_values,
                    context.parameter_index,
                )
            elseif family === :adstock
                _panel_adstocked_media_for_draw(
                    scenario_channels,
                    context.runtime,
                    draw_values,
                    context.parameter_index,
                )
            else
                throw(ArgumentError("unsupported curve family `$family`"))
            end

            for panel in 1:npanels
                values[draw, panel, point] = if family === :adstock
                    sum(view(transformed, :, context.channel_index, panel)) *
                        context.spec.channel_scale[context.channel_index, panel]
                else
                    beta = _panel_parameter_component_value(
                        beta_media,
                        context.channel_index,
                        panel,
                    )
                    sum(view(transformed, :, context.channel_index, panel)) *
                        beta *
                        context.spec.target_scale[panel]
                end
            end
        end
    end

    return values
end

function _curve_result(
        result_type::Type,
        results::InferenceResults,
        action::AbstractString,
        family::Symbol;
        channel,
        grid = nothing,
        delta_grid = nothing,
    )
    context = _curve_surface_context(
        results,
        action,
        channel;
        grid,
        delta_grid,
    )
    values = results.spec.model_kind === :panel_mmm ?
        _panel_curve_values(context, family) :
        _curve_values(context, family)
    spend_share_grid = results.spec.model_kind === :panel_mmm ?
        context.delta_grid :
        context.spend_share_grid

    return result_type(
        results.metadata,
        results.spec,
        results.coordinate_metadata,
        context.channel_name,
        context.spend_grid,
        spend_share_grid,
        context.observed_total_spend,
        values,
    )
end

"""
    response_curve_results(results::InferenceResults; channel, grid=nothing, delta_grid=nothing)

Compute a draw-level forward-pass contribution curve for one supported media
channel from grouped `InferenceResults`.

For time-series results, `grid` is interpreted in original total-spend units
across the observed horizon for the selected channel. For panel results, pass
`delta_grid`; each delta rescales the observed historical spend path for every
panel cell and the returned surface stays at panel-cell/channel level. This
canonical Stage 60 surface preserves the observed temporal spend shape and
replays the full scaled media path: channel scaling, adstock, saturation, and
coefficient ownership.
"""
function response_curve_results(
        results::InferenceResults;
        channel,
        grid = nothing,
        delta_grid = nothing,
    )
    return _curve_result(
        ResponseCurveResults,
        results,
        "response_curve_results",
        :response;
        channel,
        grid,
        delta_grid,
    )
end

"""
    saturation_curve_results(results::InferenceResults; channel, grid=nothing, delta_grid=nothing)

Compute a draw-level saturation-only curve for one supported media channel from
grouped `InferenceResults`.

For time-series results, `grid` uses the same original-unit total-spend
contract as `response_curve_results(results; channel, grid)`. For panel
results, pass `delta_grid` to apply the same panel-cell historical-scaling
contract as `response_curve_results`. The replay path bypasses adstock and
returns saturation-only contribution in observed target units.
"""
function saturation_curve_results(
        results::InferenceResults;
        channel,
        grid = nothing,
        delta_grid = nothing,
    )
    return _curve_result(
        SaturationCurveResults,
        results,
        "saturation_curve_results",
        :saturation;
        channel,
        grid,
        delta_grid,
    )
end

"""
    adstock_curve_results(results::InferenceResults; channel, grid=nothing, delta_grid=nothing)

Compute a draw-level adstock-only curve for one supported media channel from
grouped `InferenceResults`.

For time-series results, `grid` uses the same original-unit total-spend
contract as the other Stage 60 curve families. For panel results, pass
`delta_grid` to apply the same panel-cell historical-scaling contract as
`response_curve_results`. The replay path bypasses saturation and downstream
target coefficienting. Returned values stay in original
channel-spend-equivalent units.
"""
function adstock_curve_results(
        results::InferenceResults;
        channel,
        grid = nothing,
        delta_grid = nothing,
    )
    return _curve_result(
        AdstockCurveResults,
        results,
        "adstock_curve_results",
        :adstock;
        channel,
        grid,
        delta_grid,
    )
end
