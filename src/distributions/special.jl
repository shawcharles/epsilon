import Statistics: mean, var
import Random

abstract type AbstractSpecialPrior end

"""
    Scaled(base, scale)

Continuous distribution obtained by scaling draws from `base` by a positive
constant `scale`.
"""
struct Scaled{D <: ContinuousUnivariateDistribution, T <: Real} <: ContinuousUnivariateDistribution
    base::D
    scale::T

    function Scaled(base::D, scale::T) where {D <: ContinuousUnivariateDistribution, T <: Real}
        _require_finite_positive(scale, "scale")
        return new{D, T}(base, scale)
    end
end

"""
    SkewStudentT(; nu, mu=0, sigma=1, alpha=0)

Skew-Student-t distribution using the Azzalini-Capitanio parameterization.
When `alpha == 0`, this reduces to a location-scale Student-t distribution.
"""
struct SkewStudentT{T <: Real} <: ContinuousUnivariateDistribution
    nu::T
    mu::T
    sigma::T
    alpha::T

    function SkewStudentT(nu::T, mu::T, sigma::T, alpha::T) where {T <: Real}
        _require_finite_positive(nu, "nu")
        _require_finite_positive(sigma, "sigma")
        return new{T}(nu, mu, sigma, alpha)
    end
end

SkewStudentT(nu::Real, mu::Real, sigma::Real, alpha::Real) =
    SkewStudentT(promote(nu, mu, sigma, alpha)...)

SkewStudentT(; nu, mu = 0.0, sigma = 1.0, alpha = 0.0) = SkewStudentT(float(nu), float(mu), float(sigma), float(alpha))

"""
    LogNormalPrior(; mean, std, dims=nothing, centered=true)
    LogNormalPrior(; mu, sigma, dims=nothing, centered=true)

Log-normal prior parameterized by positive-scale mean and standard deviation.
"""
struct LogNormalPrior <: AbstractSpecialPrior
    parameters::Dict{Symbol, Any}
    dims::Union{Nothing, Tuple{Vararg{String}}}
    centered::Bool
end

"""
    LaplacePrior(; mu, b, dims=nothing, centered=true)

Laplace prior with optional non-centered bookkeeping metadata.
"""
struct LaplacePrior <: AbstractSpecialPrior
    parameters::Dict{Symbol, Any}
    dims::Union{Nothing, Tuple{Vararg{String}}}
    centered::Bool
end

function Base.:(==)(lhs::AbstractSpecialPrior, rhs::AbstractSpecialPrior)
    return typeof(lhs) === typeof(rhs) &&
        getfield(lhs, :dims) == getfield(rhs, :dims) &&
        getfield(lhs, :centered) == getfield(rhs, :centered) &&
        _special_parameter_equal(getfield(lhs, :parameters), getfield(rhs, :parameters))
end

function Base.hash(prior::AbstractSpecialPrior, h::UInt)
    return hash(
        (
            typeof(prior),
            getfield(prior, :dims),
            getfield(prior, :centered),
            _special_parameter_hash(getfield(prior, :parameters)),
        ),
        h,
    )
end

function LogNormalPrior(; dims = nothing, centered::Bool = true, kwargs...)
    parameters = Dict{Symbol, Any}(Symbol(key) => value for (key, value) in kwargs)
    (haskey(parameters, :mu) && haskey(parameters, :mean)) &&
        throw(ArgumentError("LogNormalPrior cannot specify both mu and mean"))
    (haskey(parameters, :sigma) && haskey(parameters, :std)) &&
        throw(ArgumentError("LogNormalPrior cannot specify both sigma and std"))
    if haskey(parameters, :mu) && !haskey(parameters, :mean)
        parameters[:mean] = pop!(parameters, :mu)
    end
    if haskey(parameters, :sigma) && !haskey(parameters, :std)
        parameters[:std] = pop!(parameters, :sigma)
    end
    Set(keys(parameters)) == Set((:mean, :std)) ||
        throw(ArgumentError("LogNormalPrior parameters must be mean and std"))
    return LogNormalPrior(parameters, _normalize_dims(dims), centered)
end

function LaplacePrior(; dims = nothing, centered::Bool = true, kwargs...)
    parameters = Dict{Symbol, Any}(Symbol(key) => value for (key, value) in kwargs)
    Set(keys(parameters)) == Set((:mu, :b)) ||
        throw(ArgumentError("LaplacePrior parameters must be mu and b"))
    return LaplacePrior(parameters, _normalize_dims(dims), centered)
end

function to_dict(prior::LogNormalPrior)
    return _special_prior_to_dict("LogNormalPrior", prior)
end

function to_dict(prior::LaplacePrior)
    return _special_prior_to_dict("LaplacePrior", prior)
end

function deserialize_special_prior(value::AbstractDict)
    class_name = _lookup(value, :special_prior)
    class_name isa AbstractString || throw(ArgumentError("special_prior must be a string"))

    dims = _lookup(value, :dims, nothing)
    centered = Bool(_lookup(value, :centered, true))
    kwargs = if _has_key(value, :kwargs)
        nested = _lookup(value, :kwargs)
        nested isa AbstractDict || throw(ArgumentError("kwargs must be a mapping"))
        Dict{Symbol, Any}(Symbol(key) => _deserialize_nested(item) for (key, item) in nested)
    else
        Dict{Symbol, Any}(
            Symbol(key) => _deserialize_nested(item) for (key, item) in value if !(
                    Symbol(key) in Set((:special_prior, :dims, :centered, :kwargs))
                )
        )
    end

    if class_name == "LogNormalPrior"
        return LogNormalPrior(; kwargs..., dims, centered)
    elseif class_name == "LaplacePrior"
        return LaplacePrior(; kwargs..., dims, centered)
    elseif class_name == "HorseshoePrior"
        return HorseshoePrior(; kwargs..., dims, centered)
    elseif class_name == "FinnishHorseshoePrior"
        return FinnishHorseshoePrior(; kwargs..., dims, centered)
    elseif class_name == "R2D2Prior"
        return R2D2Prior(; kwargs..., dims, centered)
    end

    throw(ArgumentError("unknown special prior type: $class_name"))
end

function instantiate_distribution(prior::LogNormalPrior)
    mean_value = _required_parameter(prior.parameters, "LogNormalPrior", :mean)
    std_value = _required_parameter(prior.parameters, "LogNormalPrior", :std)
    _is_scalar_like(mean_value) ||
        throw(ArgumentError("LogNormalPrior mean must be scalar to instantiate a Distributions.jl object"))
    _is_scalar_like(std_value) ||
        throw(ArgumentError("LogNormalPrior std must be scalar to instantiate a Distributions.jl object"))

    mean_float = Float64(mean_value)
    std_float = Float64(std_value)
    _require_finite_positive(mean_float, "LogNormalPrior mean")
    _require_finite_positive(std_float, "LogNormalPrior std")

    mu_log = log(mean_float^2 / sqrt(mean_float^2 + std_float^2))
    sigma_log = sqrt(log(1 + std_float^2 / mean_float^2))
    return LogNormal(mu_log, sigma_log)
end

function instantiate_distribution(prior::LaplacePrior)
    mu = _required_parameter(prior.parameters, "LaplacePrior", :mu)
    b = _required_parameter(prior.parameters, "LaplacePrior", :b)
    _is_scalar_like(mu) ||
        throw(ArgumentError("LaplacePrior mu must be scalar to instantiate a Distributions.jl object"))
    _is_scalar_like(b) ||
        throw(ArgumentError("LaplacePrior b must be scalar to instantiate a Distributions.jl object"))
    _require_finite_positive(b, "LaplacePrior b")
    return Laplace(Float64(mu), Float64(b))
end

function _require_finite_positive(value::Real, label::AbstractString)
    isfinite(value) && value > zero(value) || throw(ArgumentError("$label must be finite and positive"))
    return nothing
end

function _special_prior_to_dict(class_name::AbstractString, prior::AbstractSpecialPrior)
    payload = Dict{String, Any}(
        "special_prior" => class_name,
        "kwargs" => Dict(String(key) => _serialize_prior_value(value) for (key, value) in getfield(prior, :parameters)),
    )
    if !isnothing(getfield(prior, :dims))
        payload["dims"] = collect(getfield(prior, :dims))
    end
    if !getfield(prior, :centered)
        payload["centered"] = false
    end
    return payload
end

function _special_parameter_equal(lhs::AbstractDict, rhs::AbstractDict)
    keys(lhs) == keys(rhs) || return false
    for key in keys(lhs)
        if !_parameter_value_equal(lhs[key], rhs[key])
            return false
        end
    end
    return true
end

function _parameter_value_equal(lhs, rhs)
    if lhs isa AbstractArray && rhs isa AbstractArray
        return size(lhs) == size(rhs) && all(_parameter_value_equal.(lhs, rhs))
    end
    return lhs == rhs
end

function _special_parameter_hash(parameters::AbstractDict)
    pairs = Vector{Any}()
    for key in sort!(collect(keys(parameters)); by = string)
        push!(pairs, (key, _parameter_hash_value(parameters[key])))
    end
    return Tuple(pairs)
end

function _parameter_hash_value(value)
    if value isa AbstractArray
        return (size(value), map(_parameter_hash_value, collect(value)))
    end
    return value
end

function _is_special_prior_mapping(value::AbstractDict)
    return _has_key(value, :special_prior)
end

function _is_scalar_like(value)
    return value isa Real
end

Distributions.minimum(d::Scaled) = d.scale * minimum(d.base)
Distributions.maximum(d::Scaled) = d.scale * maximum(d.base)
Distributions.insupport(d::Scaled, x::Real) = insupport(d.base, x / d.scale)
Distributions.rand(d::Scaled) = d.scale * rand(d.base)
Distributions.rand(rng::Random.AbstractRNG, d::Scaled) = d.scale * rand(rng, d.base)
Distributions.rand(d::Scaled, dims::Dims) = d.scale .* rand(d.base, dims)
Distributions.rand(d::Scaled, dim1::Int, moredims::Int...) =
    d.scale .* rand(d.base, dim1, moredims...)
Distributions.rand(rng::Random.AbstractRNG, d::Scaled, dims::Dims) =
    d.scale .* rand(rng, d.base, dims)
Distributions.rand(rng::Random.AbstractRNG, d::Scaled, dim1::Int, moredims::Int...) =
    d.scale .* rand(rng, d.base, dim1, moredims...)
Distributions.pdf(d::Scaled, x::Real) = pdf(d.base, x / d.scale) / d.scale
Distributions.logpdf(d::Scaled, x::Real) = logpdf(d.base, x / d.scale) - log(d.scale)
mean(d::Scaled) = d.scale * mean(d.base)
var(d::Scaled) = d.scale^2 * var(d.base)

Distributions.minimum(::SkewStudentT) = -Inf
Distributions.maximum(::SkewStudentT) = Inf
Distributions.insupport(::SkewStudentT, x::Real) = isfinite(x)

function Distributions.pdf(d::SkewStudentT, x::Real)
    z = (x - d.mu) / d.sigma
    tdist = TDist(d.nu)
    arg = d.alpha * z * sqrt((d.nu + 1) / (d.nu + z^2))
    return 2 / d.sigma * pdf(tdist, z) * cdf(TDist(d.nu + 1), arg)
end

function Distributions.logpdf(d::SkewStudentT, x::Real)
    z = (x - d.mu) / d.sigma
    tdist = TDist(d.nu)
    arg = d.alpha * z * sqrt((d.nu + 1) / (d.nu + z^2))
    return log(2) - log(d.sigma) + logpdf(tdist, z) + logcdf(TDist(d.nu + 1), arg)
end

function Distributions.rand(d::SkewStudentT)
    z = rand(SkewNormal(0.0, 1.0, d.alpha))
    v = rand(Chisq(d.nu)) / d.nu
    return d.mu + d.sigma * z / sqrt(v)
end

function Distributions.rand(rng::Random.AbstractRNG, d::SkewStudentT)
    z = rand(rng, SkewNormal(0.0, 1.0, d.alpha))
    v = rand(rng, Chisq(d.nu)) / d.nu
    return d.mu + d.sigma * z / sqrt(v)
end

Distributions.rand(d::SkewStudentT, dim1::Int, moredims::Int...) =
    rand(Random.default_rng(), d, dim1, moredims...)

Distributions.rand(d::SkewStudentT, dims::Dims) = rand(Random.default_rng(), d, dims)

function Distributions.rand(rng::Random.AbstractRNG, d::SkewStudentT, dims::Dims)
    return [rand(rng, d) for _ in CartesianIndices(dims)]
end

function Distributions.rand(
        rng::Random.AbstractRNG,
        d::SkewStudentT,
        dim1::Int,
        moredims::Int...,
    )
    return rand(rng, d, (dim1, moredims...))
end
