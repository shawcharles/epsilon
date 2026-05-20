const _RESOLVED_CONTROL_TRANSFORM_STATE_KEY = "_resolved_transform_state"

function _controls_transform(config::Dict{String, Any})
    raw = get(config, "transform", "none")
    raw isa AbstractString || throw(ArgumentError("controls.transform must be a string"))
    normalized = lowercase(String(raw))
    return isempty(normalized) ? :none : Symbol(normalized)
end

function _resolved_control_transform_state_payload(state)
    isnothing(state) && return nothing
    return Dict{String, Any}(
        "mean" => Float64.(copy(state.mean)),
        "scale" => Float64.(copy(state.scale)),
    )
end

function _control_transform_state_from_config(config::Dict{String, Any})
    raw = get(config, _RESOLVED_CONTROL_TRANSFORM_STATE_KEY, nothing)
    isnothing(raw) && return nothing
    raw isa AbstractDict ||
        throw(
            ArgumentError(
                "resolved controls transform state must be a mapping when present",
            ),
        )

    mean = get(raw, "mean", nothing)
    scale = get(raw, "scale", nothing)
    mean isa AbstractVector ||
        throw(
            ArgumentError(
                "resolved controls transform state must include a vector `mean`",
            ),
        )
    scale isa AbstractVector ||
        throw(
            ArgumentError(
                "resolved controls transform state must include a vector `scale`",
            ),
        )

    return (; mean = Float64.(collect(mean)), scale = Float64.(collect(scale)))
end

function _controls_spec_config(
    config::Dict{String, Any};
    control_transform_state = nothing,
)
    spec_config = copy(config)
    payload = _resolved_control_transform_state_payload(control_transform_state)
    isnothing(payload) || (spec_config[_RESOLVED_CONTROL_TRANSFORM_STATE_KEY] = payload)
    return spec_config
end

function _validate_controls_config(config::Dict{String, Any})
    controls_transform = _controls_transform(config)
    controls_transform in (:none, :standardize) ||
        throw(ArgumentError("controls.transform must be `none` or `standardize` in the current model path"))
    keys_set = Set(String(key) for key in keys(config))
    isempty(setdiff(keys_set, Set(["transform", "priors"]))) ||
        throw(
            ArgumentError(
                "controls supports only `transform` and `priors` in the current model path",
            ),
        )
    priors = get(config, "priors", Dict{String, Any}())
    priors isa AbstractDict || throw(ArgumentError("controls.priors must be a mapping"))
    prior_keys = Set(String(key) for key in keys(priors))
    isempty(setdiff(prior_keys, Set(["beta"]))) ||
        throw(
            ArgumentError(
                "controls supports only controls.priors.beta in the current model path",
            ),
        )
    return nothing
end

function _fit_control_design_matrix(config::Dict{String, Any}, controls)
    isnothing(controls) && return (nothing, nothing)

    values = Float64.(controls)
    controls_transform = _controls_transform(config)
    if controls_transform === :none
        return values, nothing
    end

    scaler = StandardScaler()
    transformed = fit_transform!(scaler, values)
    state = (; mean = copy(scaler.mean), scale = copy(scaler.scale))
    return transformed, state
end

function _apply_control_design_matrix(config::Dict{String, Any}, controls, state)
    isnothing(controls) && return nothing

    values = Float64.(controls)
    controls_transform = _controls_transform(config)
    if controls_transform === :none
        return values
    end

    isnothing(state) &&
        throw(ArgumentError("control transform state must be provided for standardized controls"))
    return (values .- reshape(state.mean, 1, :)) ./ reshape(state.scale, 1, :)
end

function _control_design_matrix(
    config::Dict{String, Any},
    controls;
    control_transform_state = nothing,
)
    if isnothing(control_transform_state)
        matrix, fitted_state = _fit_control_design_matrix(config, controls)
        return matrix, fitted_state
    end

    return _apply_control_design_matrix(config, controls, control_transform_state),
    control_transform_state
end
