function _apply_adstock(
        channels::AbstractMatrix,
        runtime;
        alpha = nothing,
        theta = nothing,
        lam = nothing,
        k = nothing,
    )
    if runtime.adstock_type === :none
        return channels
    elseif runtime.adstock_type === :geometric
        return geometric_adstock(
            channels,
            alpha,
            runtime.l_max;
            normalize = runtime.normalize_adstock,
            axis = 1,
            mode = After,
        )
    elseif runtime.adstock_type === :delayed
        return delayed_adstock(
            channels,
            alpha,
            theta,
            runtime.l_max;
            normalize = runtime.normalize_adstock,
            axis = 1,
            mode = After,
        )
    elseif runtime.adstock_type === :binomial
        return binomial_adstock(
            channels,
            alpha,
            runtime.l_max;
            normalize = runtime.normalize_adstock,
            axis = 1,
            mode = After,
        )
    elseif runtime.adstock_type === :weibull_pdf || runtime.adstock_type === :weibull_cdf
        return weibull_adstock(
            channels,
            lam,
            k,
            runtime.l_max;
            axis = 1,
            mode = After,
            type = runtime.weibull_type,
            normalize = runtime.normalize_adstock,
        )
    end

    throw(ArgumentError("unsupported adstock type in media path"))
end

function _apply_saturation(
        transformed_media::AbstractMatrix,
        runtime;
        alpha = nothing,
        lam = nothing,
        b = nothing,
        c = nothing,
        slope = nothing,
        kappa = nothing,
    )
    if runtime.saturation_type === :none
        return transformed_media
    elseif runtime.saturation_type === :logistic
        return centered_logistic_saturation(transformed_media, lam)
    elseif runtime.saturation_type === :tanh
        return tanh_saturation(transformed_media, b, c)
    elseif runtime.saturation_type === :michaelis_menten
        return michaelis_menten(transformed_media, alpha, lam)
    elseif runtime.saturation_type === :hill
        return hill_function(transformed_media, slope, kappa)
    end

    throw(ArgumentError("unsupported saturation type in media path"))
end

function _media_effect(transformed_media::AbstractMatrix, beta_media)
    return vec(sum(transformed_media .* reshape(beta_media, 1, :); dims = 2))
end
