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
    _reject_time_varying_media_yaml(merged)

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
    panel_dims = _string_vector_or_empty(dimensions_cfg, :panel)

    try
        calibration = _parse_model_calibration_config(merged, panel_dims)
        extras = _top_level_extras(merged)
        isnothing(calibration) || (extras["calibration"] = calibration)
        return ModelConfig(
            date_column = _required_string(data_cfg, :date_column),
            target_column = _required_string(target_cfg, :column),
            target_type = _string_or_default(target_cfg, :type, "revenue"),
            channel_columns = _required_string_vector(media_cfg, :channels),
            control_columns = _string_vector_or_empty(media_cfg, :controls),
            dims = panel_dims,
            adstock = _deserialize_transform_config(adstock_cfg),
            saturation = _deserialize_transform_config(saturation_cfg),
            seasonality = _deserialize_transform_config(seasonality_cfg),
            trend = _deserialize_transform_config(trend_cfg),
            events = _deserialize_transform_config(events_cfg),
            holidays = _deserialize_holidays_config(holidays_cfg),
            controls = _deserialize_transform_config(controls_cfg),
            priors = typed_priors,
            extras = extras,
        )
    catch err
        err isa ArgumentError || rethrow()
        throw(ModelConfigError(sprint(showerror, err)))
    end
end

function _reject_time_varying_media_yaml(config::AbstractDict)
    haskey(config, "time_varying_media") && throw(
        ModelConfigError("time_varying_media is programmatic-only and cannot be set in YAML"),
    )
    media = get(config, "media", nothing)
    media isa AbstractDict && haskey(media, "time_varying_media") && throw(
        ModelConfigError("media.time_varying_media is programmatic-only and cannot be set in YAML"),
    )
    return nothing
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
    return String[String(item) for item in value]
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
    known = Set(
        (
            "calibration",
            "data",
            "target",
            "media",
            "dimensions",
            "seasonality",
            "trend",
            "events",
            "holidays",
            "controls",
            "priors",
            "fit",
        ),
    )
    return Dict{String, Any}(String(key) => value for (key, value) in config if !(String(key) in known))
end

function _parse_model_calibration_config(
        config::AbstractDict,
        panel_dims::AbstractVector{String},
    )
    block = _lookup(config, :calibration, nothing)
    isnothing(block) && return nothing
    block isa AbstractDict || throw(ModelConfigError("calibration must be a mapping"))
    _validate_model_calibration_yaml_contract(config, panel_dims)

    normalized = _normalize_config_value(block)
    allowed = Set(("steps", "lift_test", "lift_test_data", "cost_per_target", "cost_per_target_data"))
    extra = setdiff(Set(keys(normalized)), allowed)
    isempty(extra) ||
        throw(
        ArgumentError(
            "calibration includes unsupported keys: $(join(sort!(collect(extra)), ", "))",
        ),
    )

    steps = _parse_calibration_steps(normalized)
    lift_test = _parse_lift_test_calibration_rows(normalized)
    cost_per_target = _parse_cost_per_target_calibration_rows(normalized)
    isempty(steps) && isnothing(lift_test) && isnothing(cost_per_target) &&
        throw(ArgumentError("calibration must include at least one configured step"))
    return _build_calibration_input(steps, lift_test, cost_per_target)
end

function _validate_model_calibration_yaml_contract(
        config::AbstractDict,
        panel_dims::AbstractVector{String},
    )
    isempty(panel_dims) ||
        throw(
        ArgumentError(
            "calibration YAML is supported only for TimeSeriesMMM configs; dimensions.panel must be empty",
        ),
    )
    for key in (:vi, :variational, :approximate_fit)
        _has_key(config, key) ||
            continue
        throw(
            ArgumentError(
                "calibration YAML does not support variational inference; use TimeSeriesMMM with fit! (Turing/NUTS)",
            ),
        )
    end

    fit_cfg = _lookup(config, :fit, nothing)
    isnothing(fit_cfg) && return nothing
    fit_cfg isa AbstractDict || throw(ModelConfigError("fit configuration must be a mapping"))
    backend = _lookup(fit_cfg, :backend, nothing)
    isnothing(backend) && return nothing
    backend isa AbstractString ||
        throw(ModelConfigError("fit.backend must be a string when calibration is configured"))
    backend_name = lowercase(strip(String(backend)))
    backend_name in ("mcmc", "nuts", "turing") ||
        throw(
        ArgumentError(
            "calibration YAML supports only MCMC/Turing fit backends; got $(String(backend))",
        ),
    )
    return nothing
end

function _parse_calibration_steps(block::Dict{String, Any})
    raw_steps = _lookup(block, :steps, nothing)
    raw_steps isa AbstractVector || throw(ModelConfigError("calibration.steps must be a list"))
    steps = CalibrationStepConfig[]
    for (index, raw_step) in enumerate(raw_steps)
        raw_step isa AbstractDict ||
            throw(ModelConfigError("calibration.steps[$(index)] must be a mapping"))
        step = _normalize_config_value(raw_step)
        allowed = Set(("method", "params"))
        extra = setdiff(Set(keys(step)), allowed)
        isempty(extra) ||
            throw(
            ArgumentError(
                "calibration.steps[$(index)] includes unsupported keys: $(join(sort!(collect(extra)), ", "))",
            ),
        )
        method = _lookup(step, :method, nothing)
        method isa AbstractString ||
            throw(ModelConfigError("calibration.steps[$(index)].method must be a string"))
        params = _lookup(step, :params, Dict{String, Any}())
        params isa AbstractDict ||
            throw(ModelConfigError("calibration.steps[$(index)].params must be a mapping"))
        push!(steps, CalibrationStepConfig(method = method, params = params))
    end
    return steps
end

function _parse_lift_test_calibration_rows(block::Dict{String, Any})
    raw = _single_calibration_rows_block(block, "lift_test", "lift_test_data")
    isnothing(raw) && return nothing
    rows = _normalize_config_value(raw)
    _reject_extra_calibration_row_keys(
        rows,
        Set(("channel", "x", "delta_x", "delta_y", "sigma")),
        "calibration.lift_test",
    )
    return LiftTestCalibrationRows(
        channel = _required_calibration_string_vector(rows, :channel, "calibration.lift_test.channel"),
        x = _required_calibration_real_vector(rows, :x, "calibration.lift_test.x"),
        delta_x = _required_calibration_real_vector(rows, :delta_x, "calibration.lift_test.delta_x"),
        delta_y = _required_calibration_real_vector(rows, :delta_y, "calibration.lift_test.delta_y"),
        sigma = _required_calibration_real_vector(rows, :sigma, "calibration.lift_test.sigma"),
    )
end

function _parse_cost_per_target_calibration_rows(block::Dict{String, Any})
    raw = _single_calibration_rows_block(block, "cost_per_target", "cost_per_target_data")
    isnothing(raw) && return nothing
    rows = _normalize_config_value(raw)
    _reject_extra_calibration_row_keys(
        rows,
        Set(("gathered_cpt", "targets", "sigma")),
        "calibration.cost_per_target",
    )
    return CostPerTargetCalibrationRows(
        gathered_cpt = _required_calibration_real_vector(rows, :gathered_cpt, "calibration.cost_per_target.gathered_cpt"),
        targets = _required_calibration_real_vector(rows, :targets, "calibration.cost_per_target.targets"),
        sigma = _required_calibration_real_vector(rows, :sigma, "calibration.cost_per_target.sigma"),
    )
end

function _reject_extra_calibration_row_keys(
        rows::Dict{String, Any},
        allowed::Set{String},
        name::AbstractString,
    )
    extra = setdiff(Set(keys(rows)), allowed)
    isempty(extra) ||
        throw(
        ArgumentError(
            "$(name) includes unsupported keys: $(join(sort!(collect(extra)), ", "))",
        ),
    )
    return nothing
end

function _single_calibration_rows_block(
        block::Dict{String, Any},
        preferred::AbstractString,
        alias::AbstractString,
    )
    has_preferred = haskey(block, preferred)
    has_alias = haskey(block, alias)
    has_preferred && has_alias &&
        throw(ArgumentError("calibration must not define both $(preferred) and $(alias)"))
    raw = has_preferred ? block[preferred] : has_alias ? block[alias] : nothing
    isnothing(raw) && return nothing
    raw isa AbstractDict || throw(ModelConfigError("calibration.$(preferred) must be a mapping"))
    return raw
end

function _required_calibration_string_vector(
        block::Dict{String, Any},
        key::Symbol,
        name::AbstractString,
    )
    value = _lookup(block, key, nothing)
    value isa AbstractVector || throw(ModelConfigError("$(name) must be a list"))
    all(item -> item isa AbstractString, value) ||
        throw(ModelConfigError("$(name) must be a list of strings"))
    return String[String(item) for item in value]
end

function _required_calibration_real_vector(
        block::Dict{String, Any},
        key::Symbol,
        name::AbstractString,
    )
    value = _lookup(block, key, nothing)
    value isa AbstractVector || throw(ModelConfigError("$(name) must be a list"))
    all(item -> item isa Real, value) ||
        throw(ModelConfigError("$(name) must be a list of numbers"))
    return Float64[Float64(item) for item in value]
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
