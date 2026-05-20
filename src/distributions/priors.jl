using Distributions

const _PRIOR_SPECIAL_KEYS = Set((:dist, :distribution, :kwargs, :dims, :centered, :transform))

"""
    ModelConfigError

Raised when one or more model configuration entries cannot be deserialized into
prior objects.
"""
struct ModelConfigError <: Exception
    message::String
end

Base.showerror(io::IO, err::ModelConfigError) = print(io, err.message)

"""
    EpsilonPrior(distribution; dims=nothing, centered=true, transform=nothing, kwargs...)

Store a config-defined prior specification in a Julia-native form.
"""
struct EpsilonPrior
    distribution::String
    parameters::Dict{Symbol, Any}
    dims::Union{Nothing, Tuple{Vararg{String}}}
    centered::Bool
    transform::Union{Nothing, String}
end

function Base.:(==)(lhs::EpsilonPrior, rhs::EpsilonPrior)
    return lhs.distribution == rhs.distribution &&
           lhs.parameters == rhs.parameters &&
           lhs.dims == rhs.dims &&
           lhs.centered == rhs.centered &&
           lhs.transform == rhs.transform
end

function EpsilonPrior(
    distribution::AbstractString,
    parameters::AbstractDict{<:Any, <:Any};
    dims = nothing,
    centered::Bool = true,
    transform = nothing,
)
    normalized_parameters = Dict{Symbol, Any}(
        Symbol(key) => value for (key, value) in parameters
    )
    return EpsilonPrior(
        _canonical_distribution_name(distribution),
        normalized_parameters,
        _normalize_dims(dims),
        centered,
        _normalize_transform(transform),
    )
end

function EpsilonPrior(
    distribution::AbstractString;
    dims = nothing,
    centered::Bool = true,
    transform = nothing,
    kwargs...,
)
    return EpsilonPrior(
        distribution,
        Dict{Symbol, Any}(Symbol(key) => value for (key, value) in kwargs);
        dims,
        centered,
        transform,
    )
end

"""
    deserialize_prior(value)

Deserialize a dictionary-based prior specification into an `EpsilonPrior`.
Supports both `distribution: ...` and legacy `dist` / `kwargs` shapes.
"""
function deserialize_prior(value::EpsilonPrior)
    return value
end

function deserialize_prior(value::AbstractDict)
    if _is_special_prior_mapping(value)
        return deserialize_special_prior(value)
    end
    if _is_masked_prior_mapping(value)
        return deserialize_masked_prior(value)
    end
    _is_prior_mapping(value) ||
        throw(ArgumentError("value does not describe a supported prior mapping"))

    distribution = _read_distribution_name(value)
    dims = _lookup(value, :dims, nothing)
    centered = _lookup(value, :centered, true)
    transform = _lookup(value, :transform, nothing)
    parameters = _extract_prior_parameters(value)

    return EpsilonPrior(
        distribution,
        parameters;
        dims,
        centered = Bool(centered),
        transform,
    )
end

"""
    deserialize_model_config(model_config; non_distributions=())

Walk a model configuration dictionary and convert prior-like mappings into
`EpsilonPrior` values. Non-prior entries are preserved.
"""
function deserialize_model_config(
    model_config::AbstractDict;
    non_distributions = (),
)
    ignored = Set(string.(collect(non_distributions)))
    parse_errors = String[]
    parsed = Dict{Any, Any}()

    for (name, value) in model_config
        key = string(name)
        if key in ignored ||
           value isa EpsilonPrior ||
           (value isa AbstractVector && !(value isa AbstractString)) ||
           !(value isa AbstractDict)
            parsed[name] = value
            continue
        end

        if !(_is_prior_mapping(value) || _is_special_prior_mapping(value) || _is_masked_prior_mapping(value))
            parsed[name] = value
            continue
        end

        try
            parsed[name] = deserialize_prior(value)
        catch err
            push!(parse_errors, "Parameter $name: $(sprint(showerror, err))")
            parsed[name] = value
        end
    end

    if !isempty(parse_errors)
        throw(
            ModelConfigError(
                "$(length(parse_errors)) errors occurred while parsing model configuration. " *
                "Errors: $(join(parse_errors, ", "))",
            ),
        )
    end

    return parsed
end

"""
    instantiate_distribution(prior)

Build a `Distributions.jl` distribution from an `EpsilonPrior` whose parameters
are concrete scalar values.
"""
function instantiate_distribution(prior::EpsilonPrior)
    params = prior.parameters
    distribution = prior.distribution

    if distribution == "Scaled"
        base = _required_parameter(params, distribution, :base)
        scale = _required_parameter(params, distribution, :scale)
        _is_nested_distribution_parameter(scale) &&
            throw(ArgumentError("Scaled scale cannot be a nested prior parameter"))
        base_distribution = _resolve_distribution_parameter(base)
        base_distribution isa ContinuousUnivariateDistribution ||
            throw(ArgumentError("Scaled base must be a continuous univariate distribution"))
        return Scaled(base_distribution, scale)
    elseif distribution == "SkewStudentT"
        _has_nested_distribution_parameters(params) &&
            throw(ArgumentError("cannot instantiate SkewStudentT with nested prior parameters"))
        nu = _required_parameter(params, distribution, :nu)
        mu = _optional_parameter(params, 0.0, :mu)
        sigma = _optional_parameter(params, 1.0, :sigma)
        alpha = _optional_parameter(params, 0.0, :alpha)
        return SkewStudentT(nu, mu, sigma, alpha)
    end

    _has_nested_distribution_parameters(prior.parameters) &&
        throw(ArgumentError("cannot instantiate $(prior.distribution) with nested prior parameters"))

    if distribution == "Normal"
        mu = _optional_parameter(params, 0.0, :mu)
        sigma = _required_parameter(params, distribution, :sigma)
        return Normal(mu, sigma)
    elseif distribution == "HalfNormal"
        sigma = _required_parameter(params, distribution, :sigma)
        return truncated(Normal(0.0, sigma), 0.0, Inf)
    elseif distribution == "Beta"
        alpha = _required_parameter(params, distribution, :alpha)
        beta = _required_parameter(params, distribution, :beta)
        return Beta(alpha, beta)
    elseif distribution == "Gamma"
        alpha = _required_parameter(params, distribution, :alpha)
        beta = _required_parameter(params, distribution, :beta, :rate)
        return Gamma(alpha, inv(beta))
    elseif distribution == "Exponential"
        lam = _required_parameter(params, distribution, :lam, :lambda, :rate)
        return Exponential(inv(lam))
    elseif distribution == "Laplace"
        mu = _optional_parameter(params, 0.0, :mu)
        b = _required_parameter(params, distribution, :b)
        return Laplace(mu, b)
    elseif distribution == "LogNormal"
        mu = _optional_parameter(params, 0.0, :mu)
        sigma = _required_parameter(params, distribution, :sigma)
        return LogNormal(mu, sigma)
    elseif distribution == "Uniform"
        lower = _required_parameter(params, distribution, :lower)
        upper = _required_parameter(params, distribution, :upper)
        return Uniform(lower, upper)
    elseif distribution == "Weibull"
        alpha = _required_parameter(params, distribution, :alpha)
        beta = _required_parameter(params, distribution, :beta)
        return Weibull(alpha, beta)
    elseif distribution == "Cauchy"
        location = _optional_parameter(params, 0.0, :mu, :alpha)
        scale = _required_parameter(params, distribution, :beta, :sigma)
        return Cauchy(location, scale)
    elseif distribution == "HalfCauchy"
        scale = _required_parameter(params, distribution, :beta, :sigma)
        return truncated(Cauchy(0.0, scale), 0.0, Inf)
    elseif distribution == "StudentT"
        nu = _required_parameter(params, distribution, :nu)
        mu = _optional_parameter(params, 0.0, :mu)
        sigma = _optional_parameter(params, 1.0, :sigma)
        return mu + sigma * TDist(nu)
    elseif distribution == "TruncatedNormal"
        mu = _optional_parameter(params, 0.0, :mu)
        sigma = _required_parameter(params, distribution, :sigma)
        lower = _optional_parameter(params, -Inf, :lower)
        upper = _optional_parameter(params, Inf, :upper)
        return truncated(Normal(mu, sigma), lower, upper)
    end

    throw(ArgumentError("$(distribution) is not currently instantiable in Epsilon"))
end

function to_dict(prior::EpsilonPrior)
    payload = Dict{String, Any}(
        "distribution" => prior.distribution,
    )
    for (key, value) in prior.parameters
        payload[String(key)] = _serialize_prior_value(value)
    end
    if !isnothing(prior.dims)
        payload["dims"] = collect(prior.dims)
    end
    if !prior.centered
        payload["centered"] = false
    end
    if !isnothing(prior.transform)
        payload["transform"] = prior.transform
    end
    return payload
end

function _canonical_distribution_name(name::AbstractString)
    normalized = lowercase(replace(strip(name), r"[\s_\-]" => ""))
    canonical = get(
        Dict(
            "normal" => "Normal",
            "halfnormal" => "HalfNormal",
            "beta" => "Beta",
            "gamma" => "Gamma",
            "exponential" => "Exponential",
            "laplace" => "Laplace",
            "lognormal" => "LogNormal",
            "uniform" => "Uniform",
            "weibull" => "Weibull",
            "cauchy" => "Cauchy",
            "halfcauchy" => "HalfCauchy",
            "studentt" => "StudentT",
            "skewstudentt" => "SkewStudentT",
            "scaled" => "Scaled",
            "truncatednormal" => "TruncatedNormal",
        ),
        normalized,
        nothing,
    )
    isnothing(canonical) &&
        throw(ArgumentError("unknown distribution name: $name"))
    return canonical
end

function _normalize_dims(value)
    isnothing(value) && return nothing
    value isa AbstractString && return (String(value),)
    value isa Symbol && return (String(value),)
    return Tuple(String(item) for item in value)
end

function _normalize_transform(value)
    isnothing(value) && return nothing
    return String(value)
end

function _extract_prior_parameters(value::AbstractDict)
    if _has_key(value, :kwargs)
        kwargs = _lookup(value, :kwargs)
        kwargs isa AbstractDict || throw(ArgumentError("kwargs must be a mapping"))
        parameters = Dict{Symbol, Any}(
            Symbol(key) => _deserialize_nested(item) for (key, item) in kwargs
        )
        for (key, item) in value
            symbol_key = Symbol(key)
            symbol_key in _PRIOR_SPECIAL_KEYS && continue
            parameters[symbol_key] = _deserialize_nested(item)
        end
        return parameters
    end

    return Dict{Symbol, Any}(
        Symbol(key) => _deserialize_nested(item) for (key, item) in value if !(Symbol(key) in _PRIOR_SPECIAL_KEYS)
    )
end

function _deserialize_nested(value)
    value isa EpsilonPrior && return value
    value isa AbstractSpecialPrior && return value
    value isa MaskedPrior && return value
    if value isa AbstractDict
        if _is_special_prior_mapping(value) || _is_masked_prior_mapping(value) || _is_prior_mapping(value)
            return deserialize_prior(value)
        end
        return Dict(key => _deserialize_nested(item) for (key, item) in value)
    end
    if value isa Tuple
        return tuple((_deserialize_nested(item) for item in value)...)
    end
    if value isa AbstractVector && !(value isa AbstractString)
        return [_deserialize_nested(item) for item in value]
    end
    return value
end

function _is_prior_mapping(value::AbstractDict)
    return _has_key(value, :distribution) || _has_key(value, :dist)
end

function _read_distribution_name(value::AbstractDict)
    has_distribution = _has_key(value, :distribution)
    has_dist = _has_key(value, :dist)
    has_distribution && has_dist &&
        throw(ArgumentError("prior mapping must not define both `distribution` and `dist`"))
    raw_name = has_distribution ? _lookup(value, :distribution) : _lookup(value, :dist)
    raw_name isa AbstractString || throw(ArgumentError("distribution name must be a string"))
    return raw_name
end

function _has_key(mapping::AbstractDict, key::Symbol)
    return haskey(mapping, key) || haskey(mapping, String(key))
end

function _lookup(mapping::AbstractDict, key::Symbol)
    haskey(mapping, key) && return mapping[key]
    string_key = String(key)
    haskey(mapping, string_key) && return mapping[string_key]
    throw(KeyError(key))
end

function _lookup(mapping::AbstractDict, key::Symbol, default)
    return _has_key(mapping, key) ? _lookup(mapping, key) : default
end

function _required_parameter(parameters::AbstractDict{Symbol, Any}, distribution::AbstractString, names::Symbol...)
    for name in names
        haskey(parameters, name) && return parameters[name]
    end
    labels = join(string.(names), " or ")
    throw(ArgumentError("$distribution prior is missing required parameter $labels"))
end

function _optional_parameter(parameters::AbstractDict{Symbol, Any}, default, names::Symbol...)
    for name in names
        haskey(parameters, name) && return parameters[name]
    end
    return default
end

function _serialize_prior_value(value)
    if value isa EpsilonPrior || value isa AbstractSpecialPrior || value isa MaskedPrior
        return to_dict(value)
    end
    if value isa Tuple
        return collect(value)
    end
    if value isa AbstractArray
        return collect(value)
    end
    return value
end

function _resolve_distribution_parameter(value)
    if value isa EpsilonPrior || value isa AbstractSpecialPrior
        return instantiate_distribution(value)
    end
    value isa MaskedPrior &&
        throw(ArgumentError("cannot instantiate distributions with MaskedPrior parameters"))
    return value
end

function _has_nested_distribution_parameters(parameters::AbstractDict)
    return any(_is_nested_distribution_parameter, values(parameters))
end

function _is_nested_distribution_parameter(value)
    return value isa EpsilonPrior || value isa AbstractSpecialPrior || value isa MaskedPrior
end
