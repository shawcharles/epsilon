"""
    WeibullType

Kernel variants for [`weibull_adstock`](@ref).
"""
@enum WeibullType PDF CDF

"""
    binomial_adstock(x, alpha=0.5, l_max=12; normalize=false, axis=1, mode=After)

Apply binomial adstock along `axis`.

`alpha` may be a scalar or a batch-shaped array that broadcasts against the
non-convolved dimensions of `x`.
"""
function binomial_adstock(
    x::AbstractArray,
    alpha::Union{Real, AbstractArray} = 0.5,
    l_max::Integer = 12;
    normalize::Bool = false,
    axis::Integer = 1,
    mode::Union{ConvMode, AbstractString, Symbol} = After,
)
    l_max > 0 || throw(ArgumentError("l_max must be positive"))
    _validate_strict_alpha(alpha)

    weights = _binomial_adstock_weights(alpha, l_max, eltype(x))
    weights = normalize ? _normalize_last_axis(weights) : weights

    return batched_convolution(x, weights, axis, mode)
end

"""
    geometric_adstock(x, alpha=0.0, l_max=12; normalize=false, axis=1, mode=After)

Apply geometric adstock along `axis`.

`alpha` may be a scalar or a batch-shaped array that broadcasts against the
non-convolved dimensions of `x`.
"""
function geometric_adstock(
    x::AbstractArray,
    alpha::Union{Real, AbstractArray} = 0.0,
    l_max::Integer = 12;
    normalize::Bool = false,
    axis::Integer = 1,
    mode::Union{ConvMode, AbstractString, Symbol} = After,
)
    l_max > 0 || throw(ArgumentError("l_max must be positive"))
    _validate_alpha(alpha)

    weights = _geometric_adstock_weights(alpha, l_max, eltype(x))
    weights = normalize ? _normalize_last_axis(weights) : weights

    return batched_convolution(x, weights, axis, mode)
end

"""
    delayed_adstock(x, alpha=0.0, theta=0, l_max=12; normalize=false, axis=1, mode=After)

Apply delayed adstock along `axis`.

`alpha` and `theta` may be scalars or batch-shaped arrays that broadcast
against the non-convolved dimensions of `x`.
"""
function delayed_adstock(
    x::AbstractArray,
    alpha::Union{Real, AbstractArray} = 0.0,
    theta::Union{Real, AbstractArray} = 0,
    l_max::Integer = 12;
    normalize::Bool = false,
    axis::Integer = 1,
    mode::Union{ConvMode, AbstractString, Symbol} = After,
)
    l_max > 0 || throw(ArgumentError("l_max must be positive"))
    _validate_alpha(alpha)

    weights = _delayed_adstock_weights(alpha, theta, l_max, eltype(x))
    weights = normalize ? _normalize_last_axis(weights) : weights

    return batched_convolution(x, weights, axis, mode)
end

"""
    weibull_adstock(x, lam=1, k=1, l_max=12; axis=1, mode=After, type=PDF, normalize=false)

Apply Weibull adstock along `axis`.

`lam` and `k` may be scalars or batch-shaped arrays that broadcast against the
non-convolved dimensions of `x`.
"""
function weibull_adstock(
    x::AbstractArray,
    lam::Union{Real, AbstractArray} = 1,
    k::Union{Real, AbstractArray} = 1,
    l_max::Integer = 12;
    axis::Integer = 1,
    mode::Union{ConvMode, AbstractString, Symbol} = After,
    type::Union{WeibullType, AbstractString, Symbol} = PDF,
    normalize::Bool = false,
)
    l_max > 0 || throw(ArgumentError("l_max must be positive"))
    _validate_positive(lam, "lam")
    _validate_positive(k, "k")

    parsed_type = _parse_weibull_type(type)
    weights = _weibull_adstock_weights(parsed_type, lam, k, l_max, eltype(x))
    weights = normalize ? _normalize_last_axis(weights) : weights

    return batched_convolution(x, weights, axis, mode)
end

function _validate_alpha(alpha::Real)
    0 <= alpha <= 1 || throw(ArgumentError("alpha must satisfy 0 <= alpha <= 1"))
    return nothing
end

function _validate_alpha(alpha::AbstractArray)
    all(0 .<= alpha .<= 1) || throw(ArgumentError("alpha must satisfy 0 <= alpha <= 1"))
    return nothing
end

function _validate_strict_alpha(alpha::Real)
    0 < alpha <= 1 || throw(ArgumentError("alpha must satisfy 0 < alpha <= 1"))
    return nothing
end

function _validate_strict_alpha(alpha::AbstractArray)
    all(0 .< alpha .<= 1) || throw(ArgumentError("alpha must satisfy 0 < alpha <= 1"))
    return nothing
end

function _validate_positive(value::Real, name::AbstractString)
    value > 0 || throw(ArgumentError("$name must be positive"))
    return nothing
end

function _validate_positive(value::AbstractArray, name::AbstractString)
    all(value .> 0) || throw(ArgumentError("$name must be positive"))
    return nothing
end

function _parse_weibull_type(type::WeibullType)
    return type
end

function _parse_weibull_type(type::Symbol)
    return _parse_weibull_type(String(type))
end

function _parse_weibull_type(type::AbstractString)
    normalized = lowercase(type)
    normalized == "pdf" && return PDF
    normalized == "cdf" && return CDF
    throw(ArgumentError("invalid WeibullType `$type`"))
end

function _binomial_adstock_weights(alpha::Real, l_max::Integer, x_type::Type)
    out_type = promote_type(float(x_type), typeof(float(alpha)))
    exponents = fill(out_type(inv(alpha) - 1), l_max)
    base = out_type.(1 .- collect(0:(l_max - 1)) ./ (l_max + 1))
    return base .^ exponents
end

function _binomial_adstock_weights(alpha::AbstractArray, l_max::Integer, x_type::Type)
    out_type = promote_type(float(x_type), float(eltype(alpha)))
    alpha_array = out_type.(alpha)
    exponent_shape = ntuple(_ -> 1, ndims(alpha_array))
    exponents = reshape((inv.(alpha_array) .- 1), size(alpha_array)..., 1)
    base = reshape(
        out_type.(1 .- collect(0:(l_max - 1)) ./ (l_max + 1)),
        exponent_shape...,
        l_max,
    )
    return base .^ exponents
end

function _geometric_adstock_weights(alpha::Real, l_max::Integer, x_type::Type)
    out_type = promote_type(float(x_type), typeof(float(alpha)))
    exponents = zero(Int):(l_max - 1)
    return out_type.(alpha) .^ exponents
end

function _geometric_adstock_weights(alpha::AbstractArray, l_max::Integer, x_type::Type)
    out_type = promote_type(float(x_type), float(eltype(alpha)))
    alpha_array = out_type.(alpha)
    exponent_shape = ntuple(_ -> 1, ndims(alpha_array))
    exponents = reshape(out_type.(collect(0:(l_max - 1))), exponent_shape..., l_max)
    alpha_reshaped = reshape(alpha_array, size(alpha_array)..., 1)
    return alpha_reshaped .^ exponents
end

function _delayed_adstock_weights(
    alpha::Real,
    theta::Real,
    l_max::Integer,
    x_type::Type,
)
    out_type = promote_type(float(x_type), typeof(float(alpha)), typeof(float(theta)))
    exponents = out_type.((collect(0:(l_max - 1)) .- theta) .^ 2)
    return out_type(alpha) .^ exponents
end

function _delayed_adstock_weights(
    alpha::AbstractArray,
    theta::AbstractArray,
    l_max::Integer,
    x_type::Type,
)
    batch_shape = _broadcast_batch_shape(size(alpha), size(theta))
    out_type = promote_type(float(x_type), float(eltype(alpha)), float(eltype(theta)))
    alpha_array = broadcast((a, _t) -> convert(out_type, a), alpha, theta)
    theta_array = broadcast((_a, t) -> convert(out_type, t), alpha, theta)
    indices = reshape(out_type.(collect(0:(l_max - 1))), ntuple(_ -> 1, length(batch_shape))..., l_max)
    alpha_reshaped = reshape(alpha_array, batch_shape..., 1)
    theta_reshaped = reshape(theta_array, batch_shape..., 1)
    return alpha_reshaped .^ ((indices .- theta_reshaped) .^ 2)
end

function _delayed_adstock_weights(
    alpha::Real,
    theta::AbstractArray,
    l_max::Integer,
    x_type::Type,
)
    out_type = promote_type(float(x_type), typeof(float(alpha)), float(eltype(theta)))
    alpha_array = fill(convert(out_type, alpha), size(theta))
    return _delayed_adstock_weights(alpha_array, theta, l_max, x_type)
end

function _delayed_adstock_weights(
    alpha::AbstractArray,
    theta::Real,
    l_max::Integer,
    x_type::Type,
)
    out_type = promote_type(float(x_type), float(eltype(alpha)), typeof(float(theta)))
    theta_array = fill(convert(out_type, theta), size(alpha))
    return _delayed_adstock_weights(alpha, theta_array, l_max, x_type)
end

function _weibull_adstock_weights(
    type::WeibullType,
    lam::Real,
    k::Real,
    l_max::Integer,
    x_type::Type,
)
    out_type = promote_type(float(x_type), typeof(float(lam)), typeof(float(k)))
    t = out_type.(collect(1:l_max))
    return _weibull_weights_from_arrays(type, t, out_type(lam), out_type(k))
end

function _weibull_adstock_weights(
    type::WeibullType,
    lam::AbstractArray,
    k::AbstractArray,
    l_max::Integer,
    x_type::Type,
)
    batch_shape = _broadcast_batch_shape(size(lam), size(k))
    out_type = promote_type(float(x_type), float(eltype(lam)), float(eltype(k)))
    lam_array = broadcast((l, _k) -> convert(out_type, l), lam, k)
    k_array = broadcast((_l, shape) -> convert(out_type, shape), lam, k)
    t = reshape(out_type.(collect(1:l_max)), ntuple(_ -> 1, length(batch_shape))..., l_max)
    lam_reshaped = reshape(lam_array, batch_shape..., 1)
    k_reshaped = reshape(k_array, batch_shape..., 1)
    return _weibull_weights_from_arrays(type, t, lam_reshaped, k_reshaped)
end

function _weibull_adstock_weights(
    type::WeibullType,
    lam::Real,
    k::AbstractArray,
    l_max::Integer,
    x_type::Type,
)
    out_type = promote_type(float(x_type), typeof(float(lam)), float(eltype(k)))
    lam_array = fill(convert(out_type, lam), size(k))
    return _weibull_adstock_weights(type, lam_array, k, l_max, x_type)
end

function _weibull_adstock_weights(
    type::WeibullType,
    lam::AbstractArray,
    k::Real,
    l_max::Integer,
    x_type::Type,
)
    out_type = promote_type(float(x_type), float(eltype(lam)), typeof(float(k)))
    k_array = fill(convert(out_type, k), size(lam))
    return _weibull_adstock_weights(type, lam, k_array, l_max, x_type)
end

function _weibull_weights_from_arrays(type::WeibullType, t, lam, k)
    if type === PDF
        scaled_t = t ./ lam
        weights = (k ./ lam) .* (scaled_t .^ (k .- 1)) .* exp.(-(scaled_t .^ k))
        min_weights = minimum(weights; dims = ndims(weights))
        max_weights = maximum(weights; dims = ndims(weights))
        return (weights .- min_weights) ./ (max_weights .- min_weights)
    else
        survival = exp.(-((t ./ lam) .^ k))
        prefix_shape = size(survival)[1:(end - 1)]
        padded = cat(ones(eltype(survival), prefix_shape..., 1), survival; dims = ndims(survival))
        return cumprod(padded; dims = ndims(padded))
    end
end

function _normalize_last_axis(weights::AbstractArray)
    return weights ./ sum(weights; dims = ndims(weights))
end
