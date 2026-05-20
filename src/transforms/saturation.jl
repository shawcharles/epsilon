"""
    centered_logistic_saturation(x, lam=0.5)

Apply centered logistic saturation elementwise.

This curve is `2 / (1 + exp(-lam * x)) - 1`, computed as the numerically
stable equivalent `tanh(lam * x / 2)`. It maps zero input to zero output and
approaches one for large nonnegative input.

`lam` may be a scalar or an array that broadcasts against `x`.
"""
function centered_logistic_saturation(
        x::Union{Real, AbstractArray},
        lam::Union{Real, AbstractArray} = 0.5,
    )
    _validate_nonnegative(lam, "lam")
    target_ndims = max(_input_ndims(x), _input_ndims(lam))
    x_array = _reshape_for_broadcast(_parameter_array(x), target_ndims)
    lam_array = _reshape_for_broadcast(_parameter_array(lam), target_ndims)
    z = lam_array .* x_array
    return tanh.(z ./ 2)
end

"""
    logistic_saturation(x, lam=0.5)

Legacy compatibility alias for [`centered_logistic_saturation`](@ref).

New code should call `centered_logistic_saturation` directly. The public config
value `media.saturation.type = "logistic"` currently uses this centered
logistic curve for compatibility with existing Epsilon model semantics.
"""
function logistic_saturation(
        x::Union{Real, AbstractArray},
        lam::Union{Real, AbstractArray} = 0.5,
    )
    return centered_logistic_saturation(x, lam)
end

"""
    tanh_saturation(x, b=0.5, c=0.5)

Apply tanh saturation elementwise.

`b` and `c` may be scalars or arrays that broadcast against `x`.
"""
function tanh_saturation(
        x::Union{Real, AbstractArray},
        b::Union{Real, AbstractArray} = 0.5,
        c::Union{Real, AbstractArray} = 0.5,
    )
    _validate_positive(b, "b")
    _validate_positive(c, "c")
    target_ndims = max(_input_ndims(x), _input_ndims(b), _input_ndims(c))
    x_array = _reshape_for_broadcast(_parameter_array(x), target_ndims)
    b_array = _reshape_for_broadcast(_parameter_array(b), target_ndims)
    c_array = _reshape_for_broadcast(_parameter_array(c), target_ndims)
    return @. b_array * tanh(x_array / (b_array * c_array))
end

"""
    michaelis_menten(x, alpha, lam)

Apply the Michaelis-Menten saturation curve elementwise.

`alpha` and `lam` may be scalars or arrays that broadcast against `x`.
"""
function michaelis_menten(
        x::Union{Real, AbstractArray},
        alpha::Union{Real, AbstractArray},
        lam::Union{Real, AbstractArray},
    )
    _validate_positive_parameter(alpha, "alpha")
    _validate_positive_parameter(lam, "lam")
    target_ndims = max(_input_ndims(x), _input_ndims(alpha), _input_ndims(lam))
    x_array = _reshape_for_broadcast(_parameter_array(x), target_ndims)
    alpha_array = _reshape_for_broadcast(_parameter_array(alpha), target_ndims)
    lam_array = _reshape_for_broadcast(_parameter_array(lam), target_ndims)
    return @. alpha_array * x_array / (lam_array + x_array)
end

"""
    hill_function(x, slope, kappa)

Apply the Hill saturation curve elementwise.

`slope` and `kappa` may be scalars or arrays that broadcast against `x`.
"""
function hill_function(
        x::Union{Real, AbstractArray},
        slope::Union{Real, AbstractArray},
        kappa::Union{Real, AbstractArray},
    )
    _validate_nonnegative(x, "x")
    _validate_positive_parameter(slope, "slope")
    _validate_positive_parameter(kappa, "kappa")
    target_ndims = max(_input_ndims(x), _input_ndims(slope), _input_ndims(kappa))
    x_array = _reshape_for_broadcast(_parameter_array(x), target_ndims)
    slope_array = _reshape_for_broadcast(_parameter_array(slope), target_ndims)
    kappa_array = _reshape_for_broadcast(_parameter_array(kappa), target_ndims)
    kappa_pow = kappa_array .^ slope_array
    x_pow = x_array .^ slope_array
    return one.(kappa_pow) .- kappa_pow ./ (kappa_pow .+ x_pow)
end

function _validate_nonnegative(value::Real, name::AbstractString)
    value >= 0 || throw(ArgumentError("$name must be nonnegative"))
    return nothing
end

function _validate_nonnegative(value::AbstractArray, name::AbstractString)
    all(value .>= 0) || throw(ArgumentError("$name must be nonnegative"))
    return nothing
end

function _validate_positive_parameter(value::Real, name::AbstractString)
    value > 0 || throw(ArgumentError("$name must be positive"))
    return nothing
end

function _validate_positive_parameter(value::AbstractArray, name::AbstractString)
    all(value .> 0) || throw(ArgumentError("$name must be positive"))
    return nothing
end

function _input_ndims(value::Real)
    return 0
end

function _input_ndims(value::AbstractArray)
    return ndims(value)
end

function _parameter_array(value::Real)
    return value
end

function _parameter_array(value::AbstractArray)
    return value
end

function _reshape_for_broadcast(value::Real, target_ndims::Integer)
    return value
end

function _reshape_for_broadcast(value::AbstractArray, target_ndims::Integer)
    current_ndims = ndims(value)
    current_ndims >= target_ndims && return value
    shape = ntuple(i -> i <= target_ndims - current_ndims ? 1 : size(value, i - (target_ndims - current_ndims)), target_ndims)
    return reshape(value, shape)
end
