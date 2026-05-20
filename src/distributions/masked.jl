"""
    MaskedPrior(prior, mask; mask_dims=prior.dims, active_dim=nothing)

Represent a prior defined only on the active entries of a boolean mask.
"""
struct MaskedPrior
    prior::Any
    mask::BitArray
    dims::Tuple{Vararg{String}}
    active_dim::String
end

function Base.:(==)(lhs::MaskedPrior, rhs::MaskedPrior)
    return lhs.prior == rhs.prior &&
           lhs.dims == rhs.dims &&
           lhs.active_dim == rhs.active_dim &&
           lhs.mask == rhs.mask
end

function MaskedPrior(prior, mask; mask_dims = prior_dims(prior), active_dim = nothing)
    dims = _normalize_dims(mask_dims)
    isnothing(dims) && throw(ArgumentError("MaskedPrior requires prior dims"))
    prior_dims(prior) == dims || throw(ArgumentError("mask dims must match prior.dims order"))
    bitmask = BitArray(Bool.(mask))
    active_name = isnothing(active_dim) ? "non_null_dims:" * join(dims, "_") : String(active_dim)
    return MaskedPrior(prior, bitmask, dims, active_name)
end

prior_dims(prior::EpsilonPrior) = prior.dims
prior_dims(prior::AbstractSpecialPrior) = getfield(prior, :dims)
prior_dims(prior::MaskedPrior) = prior.dims

"""
    active_count(prior)

Return the number of active entries in a masked prior.
"""
active_count(prior::MaskedPrior) = count(prior.mask)

"""
    expand_masked_values(prior, active_values; fill=0.0)

Expand active-subset values back to the full masked shape.
"""
function expand_masked_values(prior::MaskedPrior, active_values; fill = 0.0)
    values = collect(active_values)
    length(values) == active_count(prior) ||
        throw(ArgumentError("active_values length must equal the number of active mask entries"))

    fill_value = Float64(fill)
    output = Base.fill(fill_value, size(prior.mask))
    output[prior.mask] = Float64.(values)
    return output
end

function to_dict(prior::MaskedPrior)
    return Dict(
        "class" => "MaskedPrior",
        "data" => Dict(
            "prior" => _serialize_prior_value(prior.prior),
            "mask" => Array(prior.mask),
            "mask_dims" => collect(prior.dims),
            "active_dim" => prior.active_dim,
        ),
    )
end

function deserialize_masked_prior(value::AbstractDict)
    payload = _has_key(value, :data) ? _lookup(value, :data) : value
    payload isa AbstractDict || throw(ArgumentError("MaskedPrior payload must be a mapping"))

    prior_value = _lookup(payload, :prior)
    mask = _lookup(payload, :mask)
    mask_dims = _lookup(payload, :mask_dims, prior_dims(_deserialize_nested(prior_value)))
    active_dim = _lookup(payload, :active_dim, nothing)

    return MaskedPrior(_deserialize_nested(prior_value), mask; mask_dims, active_dim)
end

function instantiate_distribution(prior::MaskedPrior)
    throw(ArgumentError("MaskedPrior does not map to a single Distributions.jl object"))
end

function _is_masked_prior_mapping(value::AbstractDict)
    if _has_key(value, :class)
        return _lookup(value, :class) == "MaskedPrior"
    end

    return !_has_key(value, :distribution) &&
           !_has_key(value, :dist) &&
           !_has_key(value, :special_prior) &&
           _has_key(value, :prior) &&
           _has_key(value, :mask) &&
           (_has_key(value, :mask_dims) || _has_key(value, :active_dim))
end
