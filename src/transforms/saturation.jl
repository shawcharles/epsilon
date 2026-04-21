"""
    logistic_saturation(x, lam=0.5)

Apply logistic saturation elementwise.

`lam` may be a scalar or an array that broadcasts against `x`.
"""
function logistic_saturation(
    x::Union{Real, AbstractArray},
    lam::Union{Real, AbstractArray} = 0.5,
)
    _validate_nonnegative(lam, "lam")
    out_type = promote_type(_input_eltype(x), _parameter_eltype(lam))
    target_ndims = max(_input_ndims(x), _input_ndims(lam))
    x_array = _reshape_for_broadcast(_parameter_array(x, out_type), target_ndims)
    lam_array = _reshape_for_broadcast(_parameter_array(lam, out_type), target_ndims)
    return @. (one(out_type) - exp(-lam_array * x_array)) / (one(out_type) + exp(-lam_array * x_array))
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
    out_type = promote_type(_input_eltype(x), _parameter_eltype(b), _parameter_eltype(c))
    target_ndims = max(_input_ndims(x), _input_ndims(b), _input_ndims(c))
    x_array = _reshape_for_broadcast(_parameter_array(x, out_type), target_ndims)
    b_array = _reshape_for_broadcast(_parameter_array(b, out_type), target_ndims)
    c_array = _reshape_for_broadcast(_parameter_array(c, out_type), target_ndims)
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
    out_type = promote_type(_input_eltype(x), _parameter_eltype(alpha), _parameter_eltype(lam))
    target_ndims = max(_input_ndims(x), _input_ndims(alpha), _input_ndims(lam))
    x_array = _reshape_for_broadcast(_parameter_array(x, out_type), target_ndims)
    alpha_array = _reshape_for_broadcast(_parameter_array(alpha, out_type), target_ndims)
    lam_array = _reshape_for_broadcast(_parameter_array(lam, out_type), target_ndims)
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
    out_type = promote_type(_input_eltype(x), _parameter_eltype(slope), _parameter_eltype(kappa))
    target_ndims = max(_input_ndims(x), _input_ndims(slope), _input_ndims(kappa))
    x_array = _reshape_for_broadcast(_parameter_array(x, out_type), target_ndims)
    slope_array = _reshape_for_broadcast(_parameter_array(slope, out_type), target_ndims)
    kappa_array = _reshape_for_broadcast(_parameter_array(kappa, out_type), target_ndims)
    return @. one(out_type) - (kappa_array ^ slope_array) / ((kappa_array ^ slope_array) + (x_array ^ slope_array))
end

function _validate_nonnegative(value::Real, name::AbstractString)
    value >= 0 || throw(ArgumentError("$name must be nonnegative"))
    return nothing
end

function _validate_nonnegative(value::AbstractArray, name::AbstractString)
    all(value .>= 0) || throw(ArgumentError("$name must be nonnegative"))
    return nothing
end

function _parameter_eltype(value::Real)
    return typeof(float(value))
end

function _input_eltype(value::Real)
    return typeof(float(value))
end

function _input_eltype(value::AbstractArray)
    return float(eltype(value))
end

function _input_ndims(value::Real)
    return 0
end

function _input_ndims(value::AbstractArray)
    return ndims(value)
end

function _parameter_eltype(value::AbstractArray)
    return float(eltype(value))
end

function _parameter_array(value::Real, out_type::Type)
    return convert(out_type, value)
end

function _parameter_array(value::AbstractArray, out_type::Type)
    return out_type.(value)
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
