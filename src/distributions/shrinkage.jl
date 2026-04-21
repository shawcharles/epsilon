"""
    HorseshoePrior(; scale=1.0, dims=nothing, centered=true)

Global-local shrinkage prior recipe for sparse coefficients.
"""
struct HorseshoePrior <: AbstractSpecialPrior
    parameters::Dict{Symbol, Any}
    dims::Union{Nothing, Tuple{Vararg{String}}}
    centered::Bool
end

"""
    FinnishHorseshoePrior(; scale=1.0, slab_scale=2.5, slab_df=4.0, dims=nothing, centered=true)

Regularized horseshoe prior recipe with finite slab control.
"""
struct FinnishHorseshoePrior <: AbstractSpecialPrior
    parameters::Dict{Symbol, Any}
    dims::Union{Nothing, Tuple{Vararg{String}}}
    centered::Bool
end

"""
    R2D2Prior(; mean_R2=0.5, concentration=1.0, scale=1.0, dims=nothing, centered=true)

R2D2 shrinkage prior recipe using variance allocation weights.
"""
struct R2D2Prior <: AbstractSpecialPrior
    parameters::Dict{Symbol, Any}
    dims::Union{Nothing, Tuple{Vararg{String}}}
    centered::Bool
end

function HorseshoePrior(; dims = nothing, centered::Bool = true, kwargs...)
    parameters = Dict{Symbol, Any}(Symbol(key) => value for (key, value) in kwargs)
    haskey(parameters, :scale) || (parameters[:scale] = 1.0)
    Set(keys(parameters)) == Set((:scale,)) ||
        throw(ArgumentError("HorseshoePrior parameters must be scale"))
    _positive_parameter(parameters[:scale], "HorseshoePrior scale")
    return HorseshoePrior(parameters, _normalize_dims(dims), centered)
end

function FinnishHorseshoePrior(; dims = nothing, centered::Bool = true, kwargs...)
    parameters = Dict{Symbol, Any}(Symbol(key) => value for (key, value) in kwargs)
    haskey(parameters, :scale) || (parameters[:scale] = 1.0)
    haskey(parameters, :slab_scale) || (parameters[:slab_scale] = 2.5)
    haskey(parameters, :slab_df) || (parameters[:slab_df] = 4.0)
    Set(keys(parameters)) == Set((:scale, :slab_scale, :slab_df)) ||
        throw(ArgumentError("FinnishHorseshoePrior parameters must be scale, slab_scale, and slab_df"))
    _positive_parameter(parameters[:scale], "FinnishHorseshoePrior scale")
    _positive_parameter(parameters[:slab_scale], "FinnishHorseshoePrior slab_scale")
    _positive_parameter(parameters[:slab_df], "FinnishHorseshoePrior slab_df")
    return FinnishHorseshoePrior(parameters, _normalize_dims(dims), centered)
end

function R2D2Prior(; dims = nothing, centered::Bool = true, kwargs...)
    parameters = Dict{Symbol, Any}(Symbol(key) => value for (key, value) in kwargs)
    haskey(parameters, :mean_R2) || (parameters[:mean_R2] = 0.5)
    haskey(parameters, :concentration) || (parameters[:concentration] = 1.0)
    haskey(parameters, :scale) || (parameters[:scale] = 1.0)
    Set(keys(parameters)) == Set((:mean_R2, :concentration, :scale)) ||
        throw(ArgumentError("R2D2Prior parameters must be mean_R2, concentration, and scale"))
    mean_r2 = Float64(parameters[:mean_R2])
    0 < mean_r2 < 1 || throw(ArgumentError("R2D2Prior mean_R2 must lie in (0, 1)"))
    _positive_parameter(parameters[:concentration], "R2D2Prior concentration")
    _positive_parameter(parameters[:scale], "R2D2Prior scale")
    return R2D2Prior(parameters, _normalize_dims(dims), centered)
end

function to_dict(prior::HorseshoePrior)
    return _special_prior_to_dict("HorseshoePrior", prior)
end

function to_dict(prior::FinnishHorseshoePrior)
    return _special_prior_to_dict("FinnishHorseshoePrior", prior)
end

function to_dict(prior::R2D2Prior)
    return _special_prior_to_dict("R2D2Prior", prior)
end

"""
    horseshoe_coefficients(prior, z, local_scales, global_scale)

Apply the horseshoe coefficient construction to latent standard-normal draws
and shrinkage scales.
"""
function horseshoe_coefficients(
    prior::HorseshoePrior,
    z::AbstractArray,
    local_scales,
    global_scale,
)
    scale = Float64(prior.parameters[:scale])
    return Float64.(z) .* Float64.(local_scales) .* Float64(global_scale) .* scale
end

"""
    regularized_local_scales(prior, local_scales, global_scale)

Compute regularized local scales for the Finnish horseshoe.
"""
function regularized_local_scales(
    prior::FinnishHorseshoePrior,
    local_scales,
    global_scale,
)
    lambda = Float64.(local_scales)
    tau = Float64(global_scale)
    c2 = Float64(prior.parameters[:slab_scale])^2
    return sqrt.(c2 .* lambda .^ 2 ./ (c2 .+ tau^2 .* lambda .^ 2))
end

"""
    finnish_horseshoe_coefficients(prior, z, local_scales, global_scale)

Apply the regularized horseshoe coefficient construction.
"""
function finnish_horseshoe_coefficients(
    prior::FinnishHorseshoePrior,
    z::AbstractArray,
    local_scales,
    global_scale,
)
    lambda_tilde = regularized_local_scales(prior, local_scales, global_scale)
    scale = Float64(prior.parameters[:scale])
    return Float64.(z) .* lambda_tilde .* Float64(global_scale) .* scale
end

"""
    r2d2_variance_weights(prior, phi, tau2)

Convert simplex-like variance allocations and a global variance term into
coefficient variances.
"""
function r2d2_variance_weights(
    prior::R2D2Prior,
    phi,
    tau2,
)
    phi_values = Float64.(phi)
    all(phi_values .>= 0) || throw(ArgumentError("R2D2 variance weights require nonnegative phi values"))
    total = sum(phi_values)
    total > 0 || throw(ArgumentError("R2D2 variance weights require phi to sum to a positive value"))
    normalized_phi = phi_values ./ total
    return Float64(prior.parameters[:scale])^2 .* normalized_phi .* Float64(tau2)
end

"""
    r2d2_coefficients(prior, z, phi, tau2)

Apply the R2D2 coefficient construction to latent standard-normal draws.
"""
function r2d2_coefficients(
    prior::R2D2Prior,
    z::AbstractArray,
    phi,
    tau2,
)
    variances = r2d2_variance_weights(prior, phi, tau2)
    size(z) == size(variances) || throw(ArgumentError("z and phi must have matching shapes"))
    return Float64.(z) .* sqrt.(variances)
end

function instantiate_distribution(prior::HorseshoePrior)
    throw(ArgumentError("HorseshoePrior is a shrinkage prior recipe, not a standalone Distributions.jl object"))
end

function instantiate_distribution(prior::FinnishHorseshoePrior)
    throw(ArgumentError("FinnishHorseshoePrior is a shrinkage prior recipe, not a standalone Distributions.jl object"))
end

function instantiate_distribution(prior::R2D2Prior)
    throw(ArgumentError("R2D2Prior is a shrinkage prior recipe, not a standalone Distributions.jl object"))
end

function _positive_parameter(value, label::AbstractString)
    Float64(value) > 0 || throw(ArgumentError("$label must be positive"))
    return nothing
end
