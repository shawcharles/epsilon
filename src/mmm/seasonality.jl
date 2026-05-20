const _YEARLY_FOURIER_PERIOD = 365.25

"""
    fourier_features(dayofperiod, period, n_order)

Construct a Fourier design matrix with `n_order` sine modes followed by
`n_order` cosine modes for the provided within-period positions.

This ordering matches Abacus's retained Fourier helpers:
`sin_1, sin_2, ..., cos_1, cos_2, ...`.
"""
function fourier_features(dayofperiod::AbstractVector, period::Real, n_order::Integer)
    period > 0 || throw(ArgumentError("period must be positive"))
    n_order > 0 || throw(ArgumentError("n_order must be positive"))

    values = Float64.(dayofperiod)
    order = Int(n_order)
    features = Matrix{Float64}(undef, length(values), 2 * order)
    scaled = 2π .* values ./ Float64(period)

    for i in 1:order
        features[:, i] = sin.(i .* scaled)
        features[:, order + i] = cos.(i .* scaled)
    end

    return features
end

function _seasonality_type(config::Dict{String, Any})
    raw = get(config, "type", "none")
    raw isa AbstractString || throw(ArgumentError("seasonality type must be a string"))
    normalized = lowercase(String(raw))
    return isempty(normalized) ? :none : Symbol(normalized)
end

function _validate_seasonality_config(config::Dict{String, Any})
    seasonality_type = _seasonality_type(config)
    seasonality_type in (:none, :fourier) ||
        throw(ArgumentError("seasonality.type must be `none` or `fourier` in the current model path"))
    priors = get(config, "priors", Dict{String, Any}())
    priors isa AbstractDict || throw(ArgumentError("seasonality.priors must be a mapping"))
    prior_keys = Set(String(key) for key in keys(priors))
    keys_set = Set(String(key) for key in keys(config))

    if seasonality_type === :fourier
        isempty(setdiff(keys_set, Set(["type", "n_order", "priors"]))) ||
            throw(
                ArgumentError(
                    "fourier seasonality supports only `type`, `n_order`, and `priors` in the current model path",
                ),
            )
        n_order = get(config, "n_order", nothing)
        n_order isa Integer || throw(ArgumentError("seasonality.n_order must be a positive integer"))
        Int(n_order) > 0 || throw(ArgumentError("seasonality.n_order must be positive"))
        isempty(setdiff(prior_keys, Set(["beta"]))) ||
            throw(
                ArgumentError(
                    "fourier seasonality supports only seasonality.priors.beta in the current model path",
                ),
            )
    else
        isempty(setdiff(keys_set, Set(["type"]))) ||
            throw(
                ArgumentError(
                    "seasonality.type = `none` supports only `type` in the current model path",
                ),
            )
    end

    return nothing
end

function _fourier_mode_names(n_order::Integer)
    n_order > 0 || throw(ArgumentError("n_order must be positive"))
    order = Int(n_order)
    return vcat(
        ["sin_$(i)" for i in 1:order],
        ["cos_$(i)" for i in 1:order],
    )
end

function _seasonality_positions(dates::AbstractVector)
    if all(value -> value isa Union{Dates.Date, Dates.DateTime}, dates)
        return Float64.(Dates.dayofyear.(dates))
    elseif all(value -> value isa Real, dates)
        return Float64.(dates)
    end

    throw(
        ArgumentError(
            "fourier seasonality requires `MMMData.dates` to be numeric or Date/DateTime-like",
        ),
    )
end

function _seasonality_features(config::Dict{String, Any}, dates::AbstractVector)
    seasonality_type = _seasonality_type(config)
    seasonality_type === :none && return zeros(Float64, length(dates), 0)

    _validate_seasonality_config(config)
    n_order = Int(config["n_order"])
    return fourier_features(_seasonality_positions(dates), _YEARLY_FOURIER_PERIOD, n_order)
end
