function _trend_type(config::Dict{String, Any})
    raw = get(config, "type", "none")
    raw isa AbstractString || throw(ArgumentError("trend type must be a string"))
    normalized = lowercase(String(raw))
    return isempty(normalized) ? :none : Symbol(normalized)
end

const _TREND_STATE_KEY = "__epsilon_state"

function _validate_trend_config(config::Dict{String, Any}; allow_state::Bool = false)
    trend_type = _trend_type(config)
    trend_type in (:none, :linear, :changepoint) ||
        throw(
        ArgumentError(
            "trend.type must be `none`, `linear`, or `changepoint` in the current model path",
        ),
    )

    haskey(config, "include_intercept") &&
        throw(
        ArgumentError(
            "trend.include_intercept is not supported in the current model path; use the model intercept instead",
        ),
    )

    priors = get(config, "priors", Dict{String, Any}())
    priors isa AbstractDict || throw(ArgumentError("trend.priors must be a mapping"))
    prior_keys = Set(String(key) for key in keys(priors))
    keys_set = Set(String(key) for key in keys(config))
    allow_state || !(_TREND_STATE_KEY in keys_set) ||
        throw(ArgumentError("trend.$_TREND_STATE_KEY is reserved for fitted Epsilon model state"))
    allowed_common = allow_state ? Set(["type", "priors", _TREND_STATE_KEY]) : Set(["type", "priors"])

    if trend_type === :changepoint
        allowed = union(allowed_common, Set(["n_changepoints"]))
        isempty(setdiff(keys_set, allowed)) ||
            throw(
            ArgumentError(
                "changepoint trend supports only `type`, `n_changepoints`, and `priors` in the current model path",
            ),
        )
        n_changepoints = get(config, "n_changepoints", nothing)
        n_changepoints isa Integer ||
            throw(ArgumentError("trend.n_changepoints must be a positive integer"))
        Int(n_changepoints) > 0 ||
            throw(ArgumentError("trend.n_changepoints must be positive"))
        isempty(setdiff(prior_keys, Set(["delta"]))) ||
            throw(
            ArgumentError(
                "changepoint trend supports only trend.priors.delta in the current model path",
            ),
        )
    elseif trend_type === :linear
        isempty(setdiff(keys_set, allowed_common)) ||
            throw(
            ArgumentError(
                "linear trend supports only `type` and `priors` in the current model path",
            ),
        )
        isempty(setdiff(prior_keys, Set(["beta"]))) ||
            throw(
            ArgumentError(
                "linear trend supports only trend.priors.beta in the current model path",
            ),
        )
    end

    return nothing
end

function _trend_term_names(config::Dict{String, Any})
    trend_type = _trend_type(config)
    trend_type === :none && return String[]
    trend_type === :linear && return ["linear"]
    trend_type === :changepoint &&
        return ["changepoint_$(i)" for i in 1:Int(config["n_changepoints"])]
    throw(ArgumentError("unsupported trend type: $(trend_type)"))
end

function _trend_state_from_dates(dates::AbstractVector)
    positions = _trend_positions(dates)
    return Dict{String, Any}(
        "origin" => first(dates),
        "scale" => isempty(positions) ? 0.0 : maximum(Float64.(positions)),
    )
end

function _trend_spec_config(config::Dict{String, Any}, dates::AbstractVector)
    resolved = copy(config)
    _trend_type(resolved) === :none && return resolved
    resolved[_TREND_STATE_KEY] = _trend_state_from_dates(dates)
    return resolved
end

function _trend_state(config::Dict{String, Any})
    state = get(config, _TREND_STATE_KEY, nothing)
    isnothing(state) && return nothing
    state isa AbstractDict || throw(ArgumentError("trend.$_TREND_STATE_KEY must be a mapping"))
    haskey(state, "origin") || throw(ArgumentError("trend.$_TREND_STATE_KEY.origin is missing"))
    haskey(state, "scale") || throw(ArgumentError("trend.$_TREND_STATE_KEY.scale is missing"))
    scale = state["scale"]
    scale isa Real || throw(ArgumentError("trend.$_TREND_STATE_KEY.scale must be numeric"))
    Float64(scale) >= 0.0 || throw(ArgumentError("trend.$_TREND_STATE_KEY.scale must be nonnegative"))
    return state
end

function _trend_positions(dates::AbstractVector; origin = first(dates))
    if all(value -> value isa Dates.TimeType, dates)
        origin isa Dates.TimeType ||
            throw(ArgumentError("fitted trend origin must be Date/DateTime-like for Date/DateTime-like dates"))
        return Float64.(Dates.value.(dates .- origin))
    elseif all(value -> value isa Real, dates)
        origin isa Real || throw(ArgumentError("fitted trend origin must be numeric for numeric dates"))
        return Float64.(dates .- origin)
    end

    throw(
        ArgumentError(
            "trend features require `MMMData.dates` to be numeric or Date/DateTime-like",
        ),
    )
end

function _normalize_trend_positions(positions::AbstractVector; scale = nothing)
    values = Float64.(positions)
    scale_value = isnothing(scale) ? (isempty(values) ? 0.0 : maximum(values)) : Float64(scale)
    return scale_value > 0.0 ? values ./ scale_value : zeros(Float64, length(values))
end

function _linear_trend_features(positions::AbstractVector; scale = nothing)
    return reshape(_normalize_trend_positions(positions; scale), :, 1)
end

function _changepoint_trend_features(
        positions::AbstractVector,
        n_changepoints::Integer;
        scale = nothing,
    )
    Int(n_changepoints) > 0 || throw(ArgumentError("n_changepoints must be positive"))
    normalized = _normalize_trend_positions(positions; scale)
    order = Int(n_changepoints)
    changepoints = collect(range(0.0, 1.0; length = order + 1))[1:order]
    features = Matrix{Float64}(undef, length(normalized), length(changepoints))

    for (index, changepoint) in enumerate(changepoints)
        features[:, index] = max.(0.0, normalized .- changepoint)
    end

    return features
end

function _trend_features(config::Dict{String, Any}, dates::AbstractVector)
    trend_type = _trend_type(config)
    trend_type === :none && return zeros(Float64, length(dates), 0)

    _validate_trend_config(config; allow_state = true)
    state = _trend_state(config)
    origin = isnothing(state) ? first(dates) : state["origin"]
    scale = isnothing(state) ? nothing : state["scale"]
    positions = _trend_positions(dates; origin)
    trend_type === :linear && return _linear_trend_features(positions; scale)
    trend_type === :changepoint &&
        return _changepoint_trend_features(
        positions,
        Int(config["n_changepoints"]),
        scale = scale,
    )

    throw(ArgumentError("unsupported trend type: $(trend_type)"))
end
