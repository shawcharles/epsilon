using YAML

"""
    model_config_from_dict(config)

Build a typed `ModelConfig` from a public YAML-style configuration dictionary.
"""
function model_config_from_dict(config::AbstractDict)
    data_cfg = _required_mapping(config, :data)
    target_cfg = _required_mapping(config, :target)
    media_cfg = _required_mapping(config, :media)

    dimensions_cfg = _mapping_or_empty(config, :dimensions)
    priors_cfg = _mapping_or_empty(config, :priors)

    adstock_cfg = _mapping_or_empty(media_cfg, :adstock)
    saturation_cfg = _mapping_or_empty(media_cfg, :saturation)

    typed_priors = isempty(priors_cfg) ? Dict{String, Any}() : Dict{String, Any}(deserialize_model_config(priors_cfg))

    return ModelConfig(
        date_column = _required_string(data_cfg, :date_column),
        target_column = _required_string(target_cfg, :column),
        target_type = _string_or_default(target_cfg, :type, "revenue"),
        channel_columns = _required_string_vector(media_cfg, :channels),
        control_columns = _string_vector_or_empty(media_cfg, :controls),
        dims = _string_vector_or_empty(dimensions_cfg, :panel),
        adstock = _deserialize_transform_config(adstock_cfg),
        saturation = _deserialize_transform_config(saturation_cfg),
        priors = typed_priors,
        extras = _top_level_extras(config),
    )
end

"""
    sampler_config_from_dict(config)

Build a typed `SamplerConfig` from either a top-level public config or a nested
sampler mapping.
"""
function sampler_config_from_dict(config::AbstractDict)
    fit_cfg = _has_key(config, :fit) ? _lookup(config, :fit) : config
    fit_cfg isa AbstractDict || throw(ModelConfigError("fit configuration must be a mapping"))

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
end

"""
    load_public_config(path)

Load a YAML config file and return typed model and sampler config objects plus
the raw parsed mapping.
"""
function load_public_config(path::AbstractString)
    raw = YAML.load_file(path)
    raw isa AbstractDict || throw(ModelConfigError("top-level YAML content must be a mapping"))
    model = model_config_from_dict(raw)
    sampler = sampler_config_from_dict(raw)
    return (model_config = model, sampler_config = sampler, raw = raw)
end

"""
    load_model_config(path)

Load and return only the typed `ModelConfig`.
"""
load_model_config(path::AbstractString) = load_public_config(path).model_config

"""
    load_sampler_config(path)

Load and return only the typed `SamplerConfig`.
"""
load_sampler_config(path::AbstractString) = load_public_config(path).sampler_config

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

function _top_level_extras(config::AbstractDict)
    known = Set(("data", "target", "media", "dimensions", "priors", "fit"))
    return Dict{String, Any}(String(key) => value for (key, value) in config if !(String(key) in known))
end
