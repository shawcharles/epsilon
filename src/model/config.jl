using YAML

"""
    model_config_from_dict(config; defaults=Dict(), overrides=Dict())

Build a typed `ModelConfig` from a public YAML-style configuration dictionary.
Nested mappings are merged with precedence `defaults < config < overrides`.
Non-mapping values replace the whole node at the same path.
"""
function model_config_from_dict(
        config::AbstractDict;
        defaults::AbstractDict = Dict{String, Any}(),
        overrides::AbstractDict = Dict{String, Any}(),
        base_path::Union{Nothing, AbstractString} = nothing,
    )
    merged = _merge_public_config(defaults, config, overrides)
    merged = _resolve_model_relative_paths(merged; base_path)

    merged = _normalize_abacus_config_surface(merged)

    data_cfg = _required_mapping(merged, :data)
    target_cfg = _required_mapping(merged, :target)
    media_cfg = _required_mapping(merged, :media)

    dimensions_cfg = _mapping_or_empty(merged, :dimensions)
    priors_cfg = _mapping_or_empty(merged, :priors)
    seasonality_cfg = _mapping_or_empty(merged, :seasonality)
    trend_cfg = _mapping_or_empty(merged, :trend)
    events_cfg = _mapping_or_empty(merged, :events)
    holidays_cfg = _mapping_or_empty(merged, :holidays)
    controls_cfg = _mapping_or_empty(merged, :controls)

    adstock_cfg = _mapping_or_empty(media_cfg, :adstock)
    saturation_cfg = _mapping_or_empty(media_cfg, :saturation)

    typed_priors = isempty(priors_cfg) ? Dict{String, Any}() : Dict{String, Any}(deserialize_model_config(priors_cfg))

    try
        return ModelConfig(
            date_column = _required_string(data_cfg, :date_column),
            target_column = _required_string(target_cfg, :column),
            target_type = _string_or_default(target_cfg, :type, "revenue"),
            channel_columns = _required_string_vector(media_cfg, :channels),
            control_columns = _string_vector_or_empty(media_cfg, :controls),
            dims = _string_vector_or_empty(dimensions_cfg, :panel),
            adstock = _deserialize_transform_config(adstock_cfg),
            saturation = _deserialize_transform_config(saturation_cfg),
            seasonality = _deserialize_transform_config(seasonality_cfg),
            trend = _deserialize_transform_config(trend_cfg),
            events = _deserialize_transform_config(events_cfg),
            holidays = _deserialize_holidays_config(holidays_cfg),
            controls = _deserialize_transform_config(controls_cfg),
            priors = typed_priors,
            extras = _top_level_extras(merged),
        )
    catch err
        err isa ArgumentError || rethrow()
        throw(ModelConfigError(sprint(showerror, err)))
    end
end

function _normalize_abacus_config_surface(config::Dict{String, Any})
    normalized = _normalize_config_value(config)
    _hoist_abacus_saturation_beta!(normalized)
    _normalize_abacus_effects!(normalized)
    _normalize_abacus_holidays!(normalized)
    return normalized
end

function _hoist_abacus_saturation_beta!(config::Dict{String, Any})
    media_cfg = get(config, "media", nothing)
    media_cfg isa AbstractDict || return config
    saturation_cfg = get(media_cfg, "saturation", nothing)
    saturation_cfg isa AbstractDict || return config
    priors_cfg = get(saturation_cfg, "priors", nothing)
    priors_cfg isa AbstractDict || return config
    haskey(priors_cfg, "beta") || return config

    top_priors = get!(config, "priors", Dict{String, Any}())
    top_priors isa AbstractDict ||
        throw(ModelConfigError("priors must be a mapping when media.saturation.priors.beta is present"))
    haskey(top_priors, "beta_media") || (top_priors["beta_media"] = priors_cfg["beta"])
    delete!(priors_cfg, "beta")
    return config
end

function _normalize_abacus_effects!(config::Dict{String, Any})
    haskey(config, "seasonality") && return config
    effects = get(config, "effects", nothing)
    effects isa AbstractVector || return config

    for effect in effects
        effect isa AbstractDict || continue
        effect_type = get(effect, "type", nothing)
        effect_type isa AbstractString || continue
        lowercase(String(effect_type)) == "yearly_fourier" || continue
        order = get(effect, "order", nothing)
        order isa Integer ||
            throw(ModelConfigError("effects yearly_fourier.order must be an integer"))
        config["seasonality"] = Dict{String, Any}(
            "type" => "fourier",
            "n_order" => Int(order),
        )
        return config
    end

    return config
end

function _normalize_abacus_holidays!(config::Dict{String, Any})
    holidays_cfg = get(config, "holidays", nothing)
    holidays_cfg isa AbstractDict || return config
    mode = get(holidays_cfg, "mode", nothing)
    mode isa AbstractString || return config
    lowercase(strip(String(mode))) == "prophet_component" || return config
    holidays_cfg["mode"] = "auto"
    return config
end

"""
    sampler_config_from_dict(config; defaults=Dict(), overrides=Dict())

Build a typed `SamplerConfig` from either a top-level public config or a nested
sampler mapping. Nested mappings are merged with precedence
`defaults < config < overrides`.
"""
function sampler_config_from_dict(
        config::AbstractDict;
        defaults::AbstractDict = Dict{String, Any}(),
        overrides::AbstractDict = Dict{String, Any}(),
    )
    merged = _merge_public_config(defaults, config, overrides)
    fit_cfg = _has_key(merged, :fit) ? _lookup(merged, :fit) : merged
    fit_cfg isa AbstractDict || throw(ModelConfigError("fit configuration must be a mapping"))

    try
        return SamplerConfig(
            draws = _integer_or_default(fit_cfg, :draws, 1000),
            tune = _integer_or_default(fit_cfg, :tune, 1000),
            chains = _integer_or_default(fit_cfg, :chains, 4),
            cores = _integer_or_default(fit_cfg, :cores, _integer_or_default(fit_cfg, :chains, 4)),
            target_accept = _real_or_default(fit_cfg, :target_accept, 0.8),
            random_seed = _optional_integer(fit_cfg, :random_seed, nothing),
            progressbar = _bool_or_default(fit_cfg, :progressbar, true),
            compute_convergence_checks = _bool_or_default(fit_cfg, :compute_convergence_checks, true),
        )
    catch err
        err isa ArgumentError || rethrow()
        throw(ModelConfigError(sprint(showerror, err)))
    end
end

"""
    load_public_config(path; defaults=Dict(), overrides=Dict())

Load a YAML config file and return typed model and sampler config objects plus
the merged effective mapping.
"""
function load_public_config(
        path::AbstractString;
        defaults::AbstractDict = Dict{String, Any}(),
        overrides::AbstractDict = Dict{String, Any}(),
    )
    raw = YAML.load_file(path)
    raw isa AbstractDict || throw(ModelConfigError("top-level YAML content must be a mapping"))
    merged = _merge_public_config(defaults, raw, overrides)
    merged = _resolve_model_relative_paths(merged; base_path = dirname(abspath(path)))
    model = model_config_from_dict(merged; base_path = dirname(abspath(path)))
    sampler = sampler_config_from_dict(merged)
    return (model_config = model, sampler_config = sampler, raw = merged)
end

"""
    load_model_config(path; defaults=Dict(), overrides=Dict())

Load and return only the typed `ModelConfig`.
"""
function load_model_config(
        path::AbstractString;
        defaults::AbstractDict = Dict{String, Any}(),
        overrides::AbstractDict = Dict{String, Any}(),
    )
    return load_public_config(path; defaults, overrides).model_config
end

"""
    load_sampler_config(path; defaults=Dict(), overrides=Dict())

Load and return only the typed `SamplerConfig`.
"""
function load_sampler_config(
        path::AbstractString;
        defaults::AbstractDict = Dict{String, Any}(),
        overrides::AbstractDict = Dict{String, Any}(),
    )
    return load_public_config(path; defaults, overrides).sampler_config
end

function _required_mapping(config::AbstractDict, key::Symbol)
    value = _lookup(config, key, nothing)
    value isa AbstractDict || throw(ModelConfigError("$(String(key)) must be a mapping"))
    return value
end

function _mapping_or_empty(config::AbstractDict, key::Symbol)
    value = _lookup(config, key, Dict{String, Any}())
    value isa AbstractDict || throw(ModelConfigError("$(String(key)) must be a mapping"))
    return value
end

function _required_string(config::AbstractDict, key::Symbol)
    value = _lookup(config, key, nothing)
    value isa AbstractString || throw(ModelConfigError("$(String(key)) must be a string"))
    return String(value)
end

function _required_string_vector(config::AbstractDict, key::Symbol)
    _has_key(config, key) || throw(ModelConfigError("$(String(key)) must be present"))
    return _string_vector_or_empty(config, key, required = true)
end

function _string_vector_or_empty(config::AbstractDict, key::Symbol; required::Bool = false)
    value = _lookup(config, key, required ? nothing : Any[])
    if isnothing(value)
        throw(ModelConfigError("$(String(key)) must be a list of strings"))
    end
    value isa AbstractVector || throw(ModelConfigError("$(String(key)) must be a list of strings"))
    all(item -> item isa AbstractString, value) ||
        throw(ModelConfigError("$(String(key)) must be a list of strings"))
    return [String(item) for item in value]
end

function _string_or_default(config::AbstractDict, key::Symbol, default::AbstractString)
    value = _lookup(config, key, default)
    value isa AbstractString || throw(ModelConfigError("$(String(key)) must be a string"))
    return String(value)
end

function _integer_or_default(config::AbstractDict, key::Symbol, default::Integer)
    value = _lookup(config, key, default)
    value isa Integer || throw(ModelConfigError("$(String(key)) must be an integer"))
    return Int(value)
end

function _optional_integer(config::AbstractDict, key::Symbol, default)
    value = _lookup(config, key, default)
    isnothing(value) && return nothing
    value isa Integer || throw(ModelConfigError("$(String(key)) must be an integer or null"))
    return Int(value)
end

function _real_or_default(config::AbstractDict, key::Symbol, default::Real)
    value = _lookup(config, key, default)
    value isa Real || throw(ModelConfigError("$(String(key)) must be numeric"))
    return Float64(value)
end

function _bool_or_default(config::AbstractDict, key::Symbol, default::Bool)
    value = _lookup(config, key, default)
    value isa Bool || throw(ModelConfigError("$(String(key)) must be boolean"))
    return value
end

function _deserialize_transform_config(config::AbstractDict)
    output = Dict{String, Any}(String(key) => value for (key, value) in config)
    if haskey(output, "priors")
        priors_value = output["priors"]
        priors_value isa AbstractDict || throw(ModelConfigError("transform priors must be a mapping"))
        output["priors"] = Dict{String, Any}(deserialize_model_config(priors_value))
    end
    return output
end

function _deserialize_holidays_config(config::AbstractDict)
    output = Dict{String, Any}(String(key) => value for (key, value) in config)
    if haskey(output, "countries")
        countries = output["countries"]
        if countries isa AbstractString
            output["countries"] = [String(countries)]
        elseif countries isa AbstractVector
            output["countries"] = [String(country) for country in countries]
        else
            throw(ModelConfigError("holidays.countries must be a string or list of strings"))
        end
    end
    if haskey(output, "priors")
        priors_value = output["priors"]
        priors_value isa AbstractDict || throw(ModelConfigError("holidays.priors must be a mapping"))
        output["priors"] = Dict{String, Any}(deserialize_model_config(priors_value))
    end
    return output
end

function _top_level_extras(config::AbstractDict)
    known = Set(("data", "target", "media", "dimensions", "seasonality", "trend", "events", "holidays", "controls", "priors", "fit"))
    return Dict{String, Any}(String(key) => value for (key, value) in config if !(String(key) in known))
end

function _merge_public_config(
        defaults::AbstractDict,
        config::AbstractDict,
        overrides::AbstractDict,
    )
    merged = _normalize_config_value(defaults)
    merged = _deep_merge_config(merged, _normalize_config_value(config))
    merged = _deep_merge_config(merged, _normalize_config_value(overrides))
    return merged
end

function _deep_merge_config(
        base::Dict{String, Any},
        override::Dict{String, Any},
    )
    merged = copy(base)
    for (key, override_value) in override
        if haskey(merged, key) &&
                merged[key] isa AbstractDict &&
                override_value isa AbstractDict
            merged[key] = _deep_merge_config(
                _normalize_config_value(merged[key]),
                _normalize_config_value(override_value),
            )
        else
            merged[key] = override_value
        end
    end
    return merged
end

function _normalize_config_value(value::AbstractDict)
    return Dict{String, Any}(
        String(key) => _normalize_config_value(item) for (key, item) in value
    )
end

function _normalize_config_value(value::AbstractVector)
    value isa AbstractString && return String(value)
    return [_normalize_config_value(item) for item in value]
end

function _normalize_config_value(value::Tuple)
    return tuple((_normalize_config_value(item) for item in value)...)
end

function _normalize_config_value(value)
    value isa AbstractString && return String(value)
    return value
end

function _resolve_model_relative_paths(
        config::Dict{String, Any};
        base_path::Union{Nothing, AbstractString},
    )
    isnothing(base_path) && return config
    resolved = _normalize_config_value(config)
    holidays_cfg = get(resolved, "holidays", nothing)
    if holidays_cfg isa AbstractDict && haskey(holidays_cfg, "path")
        path = holidays_cfg["path"]
        if path isa AbstractString && !isabspath(path)
            holidays_cfg["path"] = normpath(joinpath(base_path, String(path)))
        end
    end
    return resolved
end
