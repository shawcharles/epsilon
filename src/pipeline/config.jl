using YAML

"""
    PipelineRunConfig(; config_path, output_dir="results", run_name=nothing, dataset_path=nothing, prior_samples=20, curve_points=100, draws=nothing, tune=nothing, chains=nothing, cores=nothing, random_seed=nothing)

Bounded runtime configuration for the Phase 9 pipeline runner.

`PipelineRunConfig` owns the CLI/API override surface that may be merged onto a
YAML pipeline config at runtime without widening the underlying MMM contract.
The closed Phase 9 runtime contract freezes the keyword shape, runner-only YAML
stripping, and bounded stage-execution override surface without widening the
underlying MMM API.
"""
struct PipelineRunConfig
    config_path::String
    output_dir::String
    run_name::Union{Nothing, String}
    dataset_path::Union{Nothing, String}
    prior_samples::Int
    curve_points::Int
    draws::Union{Nothing, Int}
    tune::Union{Nothing, Int}
    chains::Union{Nothing, Int}
    cores::Union{Nothing, Int}
    random_seed::Union{Nothing, Int}
end

function Base.:(==)(lhs::PipelineRunConfig, rhs::PipelineRunConfig)
    return lhs.config_path == rhs.config_path &&
        lhs.output_dir == rhs.output_dir &&
        lhs.run_name == rhs.run_name &&
        lhs.dataset_path == rhs.dataset_path &&
        lhs.prior_samples == rhs.prior_samples &&
        lhs.curve_points == rhs.curve_points &&
        lhs.draws == rhs.draws &&
        lhs.tune == rhs.tune &&
        lhs.chains == rhs.chains &&
        lhs.cores == rhs.cores &&
        lhs.random_seed == rhs.random_seed
end

function PipelineRunConfig(;
        config_path,
        output_dir::AbstractString = "results",
        run_name = nothing,
        dataset_path = nothing,
        prior_samples::Integer = 20,
        curve_points::Integer = 100,
        draws = nothing,
        tune = nothing,
        chains = nothing,
        cores = nothing,
        random_seed = nothing,
    )
    config = PipelineRunConfig(
        String(config_path),
        String(output_dir),
        isnothing(run_name) ? nothing : String(run_name),
        isnothing(dataset_path) ? nothing : String(dataset_path),
        Int(prior_samples),
        Int(curve_points),
        _optional_pipeline_integer(draws),
        _optional_pipeline_integer(tune),
        _optional_pipeline_integer(chains),
        _optional_pipeline_integer(cores),
        _optional_pipeline_integer(random_seed),
    )
    _validate_pipeline_run_config(config)
    return config
end

const _PIPELINE_ALLOWED_FIT_KEYS = Set(
    (
        "backend",
        "draws",
        "tune",
        "chains",
        "cores",
        "target_accept",
        "random_seed",
        "progressbar",
        "compute_convergence_checks",
    )
)
const _PIPELINE_ALLOWED_VALIDATION_KEYS = Set(("enabled", "holdout_rows"))
const _PIPELINE_ALLOWED_OPTIMIZATION_KEYS = Set(
    (
        "enabled",
        "total_budget",
        "channels",
        "budget_bounds",
        "relative_bounds",
        "objective",
        "grid",
        "panel_allocation_mode",
    )
)
const _PIPELINE_ALLOWED_PRIOR_SENSITIVITY_KEYS = Set(
    (
        "enabled",
        "reference",
        "scenario_policy",
        "allow_model_structure_overrides",
        "scenarios",
    )
)
const _PIPELINE_ALLOWED_PRIOR_SCENARIO_KEYS = Set(("description", "reason", "overrides"))
const _PIPELINE_PRIOR_SENSITIVITY_POLICIES = Set(("manual", "conservative_mmm"))
const _PIPELINE_PRIOR_SCENARIO_NAME_PATTERN = r"^[a-z][a-z0-9_]*$"
const _PIPELINE_RESERVED_PRIOR_SCENARIO_NAMES = Set(
    (
        "baseline",
        "control",
        "controls",
        "diagnostics",
        "fit",
        "intercept",
        "likelihood",
        "media",
        "seasonality",
        "trend",
        "validation",
    )
)
const _PIPELINE_BLOCKED_TOP_LEVEL_KEYS = Set(("vi", "variational", "approximate_fit"))
const _PIPELINE_ALLOWED_TOP_LEVEL_KEYS = Set(
    (
        "ai_advisor",
        "calibration",
        "controls",
        "data",
        "dimensions",
        "effects",
        "events",
        "fit",
        "holidays",
        "media",
        "optimization",
        "original_scale_vars",
        "prior_sensitivity",
        "priors",
        "seasonality",
        "target",
        "trend",
        "validation",
    ),
)

function _validate_pipeline_run_config(config::PipelineRunConfig)
    _validate_nonempty_string(config.config_path, "config_path")
    _validate_nonempty_string(config.output_dir, "output_dir")

    if !isnothing(config.run_name)
        _validate_nonempty_string(config.run_name, "run_name")
        occursin(r"[\\/]", config.run_name) &&
            throw(ArgumentError("run_name must not contain path separators"))
    end

    if !isnothing(config.dataset_path)
        _validate_nonempty_string(config.dataset_path, "dataset_path")
    end

    config.prior_samples > 0 || throw(ArgumentError("prior_samples must be positive"))
    config.curve_points >= 2 || throw(ArgumentError("curve_points must be at least 2"))
    _validate_optional_pipeline_integer(config.draws, "draws"; allow_zero = false)
    _validate_optional_pipeline_integer(config.tune, "tune"; allow_zero = true)
    _validate_optional_pipeline_integer(config.chains, "chains"; allow_zero = false)
    _validate_optional_pipeline_integer(config.cores, "cores"; allow_zero = false)
    return nothing
end

function _optional_pipeline_integer(value)
    isnothing(value) && return nothing
    value isa Integer || throw(ArgumentError("runtime overrides must be integers or nothing"))
    return Int(value)
end

function _validate_nonempty_string(value::AbstractString, name::AbstractString)
    isempty(strip(String(value))) && throw(ArgumentError("$name must not be empty"))
    return nothing
end

function _validate_optional_pipeline_integer(
        value::Union{Nothing, Int},
        name::AbstractString;
        allow_zero::Bool,
    )
    isnothing(value) && return nothing
    if allow_zero
        value >= 0 || throw(ArgumentError("$name must be nonnegative"))
    else
        value > 0 || throw(ArgumentError("$name must be positive"))
    end
    return nothing
end

function _load_pipeline_configuration(config::PipelineRunConfig)
    isfile(config.config_path) ||
        throw(ArgumentError("run_pipeline requires an existing config file"))

    source_yaml = read(config.config_path, String)
    raw = YAML.load_file(config.config_path)
    raw isa AbstractDict || throw(ModelConfigError("top-level YAML content must be a mapping"))

    normalized_raw = _normalize_config_value(raw)
    _validate_pipeline_top_level_contract(normalized_raw)
    resolved = _apply_pipeline_runtime_overrides(normalized_raw, config)
    resolved = _resolve_model_relative_paths(
        resolved;
        base_path = dirname(abspath(config.config_path)),
    )
    _validate_pipeline_fit_contract(resolved)
    dataset_path = _pipeline_dataset_path(resolved)

    stripped = _strip_pipeline_runner_keys(resolved)

    model_config = model_config_from_dict(
        stripped;
        base_path = dirname(abspath(config.config_path)),
    )
    sampler_config = sampler_config_from_dict(stripped)
    is_panel_config = !isempty(model_config.dims)

    validation_config = is_panel_config ? nothing : _parse_pipeline_validation_config(resolved)
    prior_sensitivity_config = _parse_pipeline_prior_sensitivity_config(resolved)
    optimization_config = if is_panel_config
        _parse_pipeline_panel_optimization_config(resolved)
    else
        _parse_pipeline_optimization_config(resolved)
    end

    return (
        source_yaml = source_yaml,
        dataset_path = dataset_path,
        raw_config = normalized_raw,
        resolved_config = resolved,
        model_config_dict = stripped,
        model_config = model_config,
        sampler_config = sampler_config,
        prior_sensitivity_config = prior_sensitivity_config,
        validation_config = validation_config,
        optimization_config = optimization_config,
        metadata_only = is_panel_config,
    )
end

function _pipeline_dataset_path(config::Dict{String, Any})
    data_cfg = _lookup(config, :data, nothing)
    data_cfg isa AbstractDict || throw(ModelConfigError("data must be a mapping"))
    dataset_path = _lookup(data_cfg, :dataset_path, nothing)
    dataset_path isa AbstractString ||
        throw(
        ArgumentError(
            "run_pipeline requires data.dataset_path to be present as a combined CSV path",
        ),
    )
    _validate_nonempty_string(String(dataset_path), "data.dataset_path")
    return String(dataset_path)
end

function _validate_pipeline_top_level_contract(config::Dict{String, Any})
    top_level_keys = Set(String(key) for key in keys(config))
    unknown = setdiff(top_level_keys, union(_PIPELINE_ALLOWED_TOP_LEVEL_KEYS, _PIPELINE_BLOCKED_TOP_LEVEL_KEYS))
    isempty(unknown) ||
        throw(
        ArgumentError(
            "run_pipeline received unsupported top-level YAML keys: $(join(sort!(collect(unknown)), ", "))",
        ),
    )

    for key in _PIPELINE_BLOCKED_TOP_LEVEL_KEYS
        haskey(config, key) ||
            continue
        throw(
            ArgumentError(
                "run_pipeline rejects `$key`: Epsilon permanently supports only MCMC/Turing fitting",
            ),
        )
    end

    data_cfg = _lookup(config, :data, Dict{String, Any}())
    data_cfg isa AbstractDict || throw(ModelConfigError("data must be a mapping"))
    for key in ("x_path", "y_path")
        haskey(data_cfg, key) ||
            continue
        throw(
            ArgumentError(
                "run_pipeline supports only one combined CSV dataset path via data.dataset_path; separate data.$key inputs are unsupported",
            ),
        )
    end
    return nothing
end

function _apply_pipeline_runtime_overrides(
        raw::Dict{String, Any},
        config::PipelineRunConfig,
    )
    overrides = Dict{String, Any}()

    if !isnothing(config.dataset_path)
        overrides["data"] = Dict{String, Any}("dataset_path" => config.dataset_path)
    end

    fit_overrides = Dict{String, Any}()
    for key in (:draws, :tune, :chains, :cores, :random_seed)
        value = getfield(config, key)
        isnothing(value) && continue
        fit_overrides[String(key)] = value
    end
    isempty(fit_overrides) || (overrides["fit"] = fit_overrides)

    return _deep_merge_config(raw, overrides)
end

function _validate_pipeline_fit_contract(config::Dict{String, Any})
    fit_cfg = _lookup(config, :fit, nothing)
    isnothing(fit_cfg) && return nothing
    fit_cfg isa AbstractDict || throw(ModelConfigError("fit configuration must be a mapping"))

    fit_keys = Set(String(key) for key in keys(fit_cfg))
    extra = setdiff(fit_keys, _PIPELINE_ALLOWED_FIT_KEYS)
    isempty(extra) ||
        throw(
        ArgumentError(
            "run_pipeline does not support additional fit keys in the bounded Phase 9 YAML surface: $(join(sort!(collect(extra)), ", "))",
        ),
    )
    _validate_pipeline_fit_backend(fit_cfg)
    return nothing
end

function _validate_pipeline_fit_backend(fit_cfg::AbstractDict)
    backend = _lookup(fit_cfg, :backend, nothing)
    isnothing(backend) && return nothing
    backend isa AbstractString ||
        throw(ModelConfigError("fit.backend must be a string"))
    backend_name = lowercase(strip(String(backend)))
    backend_name in ("mcmc", "nuts", "turing") ||
        throw(
        ArgumentError(
            "run_pipeline supports only MCMC/Turing fit backends; got $(String(backend))",
        ),
    )
    return nothing
end

function _parse_pipeline_validation_config(config::Dict{String, Any})
    block = _lookup(config, :validation, nothing)
    isnothing(block) && return nothing
    block isa AbstractDict || throw(ModelConfigError("validation must be a mapping"))

    block = _normalize_config_value(block)
    keys_seen = Set(String(key) for key in keys(block))
    extra = setdiff(keys_seen, _PIPELINE_ALLOWED_VALIDATION_KEYS)
    isempty(extra) ||
        throw(
        ArgumentError(
            "validation supports only enabled and holdout_rows in the bounded Phase 9 surface",
        ),
    )

    enabled = _bool_or_default(block, :enabled, true)
    holdout_rows = _lookup(block, :holdout_rows, nothing)
    if enabled
        holdout_rows isa Integer ||
            throw(ArgumentError("validation.holdout_rows must be an integer when validation is enabled"))
        holdout_rows > 0 ||
            throw(ArgumentError("validation.holdout_rows must be positive"))
    elseif !isnothing(holdout_rows)
        holdout_rows isa Integer ||
            throw(ArgumentError("validation.holdout_rows must be an integer when provided"))
        holdout_rows > 0 ||
            throw(ArgumentError("validation.holdout_rows must be positive"))
    end

    return Dict{String, Any}(
        "enabled" => enabled,
        "holdout_rows" => isnothing(holdout_rows) ? nothing : Int(holdout_rows),
    )
end

function _parse_pipeline_prior_sensitivity_config(config::Dict{String, Any})
    block = _lookup(config, :prior_sensitivity, nothing)
    isnothing(block) && return nothing
    block isa AbstractDict || throw(ModelConfigError("prior_sensitivity must be a mapping"))

    block = _normalize_config_value(block)
    keys_seen = Set(String(key) for key in keys(block))
    extra = setdiff(keys_seen, _PIPELINE_ALLOWED_PRIOR_SENSITIVITY_KEYS)
    isempty(extra) ||
        throw(
        ArgumentError(
            "prior_sensitivity includes unsupported keys: $(join(sort!(collect(extra)), ", "))",
        ),
    )

    enabled = _bool_or_default(block, :enabled, true)
    reference = strip(String(_lookup(block, :reference, "reference")))
    _validate_pipeline_prior_scenario_name(reference)
    policy = String(_lookup(block, :scenario_policy, "manual"))
    policy in _PIPELINE_PRIOR_SENSITIVITY_POLICIES ||
        throw(
        ArgumentError(
            "prior_sensitivity.scenario_policy must be manual or conservative_mmm",
        ),
    )
    allow_model_structure_overrides =
        _bool_or_default(block, :allow_model_structure_overrides, false)

    scenarios_block = _lookup(block, :scenarios, Dict{String, Any}())
    scenarios_block isa AbstractDict ||
        throw(ModelConfigError("prior_sensitivity.scenarios must be a mapping"))
    scenarios = Dict{String, Any}()
    for (raw_name, raw_scenario) in scenarios_block
        name = String(raw_name)
        _validate_pipeline_prior_scenario_name(name)
        raw_scenario isa AbstractDict ||
            throw(ModelConfigError("prior_sensitivity scenario `$name` must be a mapping"))
        scenario = _normalize_config_value(raw_scenario)
        scenario_keys = Set(String(key) for key in keys(scenario))
        scenario_extra = setdiff(scenario_keys, _PIPELINE_ALLOWED_PRIOR_SCENARIO_KEYS)
        isempty(scenario_extra) ||
            throw(
            ArgumentError(
                "prior_sensitivity scenario `$name` includes unsupported keys: $(join(sort!(collect(scenario_extra)), ", "))",
            ),
        )
        overrides = _lookup(scenario, :overrides, Dict{String, Any}())
        overrides isa AbstractDict ||
            throw(ModelConfigError("prior_sensitivity scenario `$name`.overrides must be a mapping"))
        normalized_overrides = Dict{String, Any}()
        for (path, value) in overrides
            path_string = String(path)
            isempty(strip(path_string)) &&
                throw(ArgumentError("prior_sensitivity override paths must be non-empty strings"))
            _classify_prior_sensitivity_override_path(path_string)
            normalized_overrides[path_string] = _normalize_config_value(value)
        end
        scenarios[name] = Dict{String, Any}(
            "description" => _optional_prior_sensitivity_string(scenario, "description"),
            "reason" => _optional_prior_sensitivity_string(scenario, "reason"),
            "overrides" => normalized_overrides,
        )
    end

    if haskey(scenarios, reference) && !isempty(scenarios[reference]["overrides"])
        throw(
            ArgumentError(
                "The configured prior_sensitivity.reference scenario must not define overrides",
            ),
        )
    end

    classifications = Dict{String, String}(
        name => _classify_prior_sensitivity_overrides(scenario["overrides"]) for
            (name, scenario) in scenarios
    )
    if !allow_model_structure_overrides
        model_structure_scenarios = sort!(
            [
                name for (name, classification) in classifications if
                    classification == "model_structure_sensitivity"
            ],
        )
        isempty(model_structure_scenarios) ||
            throw(
            ArgumentError(
                "prior_sensitivity scenarios include model-structure overrides ($(join(model_structure_scenarios, ", "))); set allow_model_structure_overrides: true to run them explicitly",
            ),
        )
    end

    return Dict{String, Any}(
        "enabled" => enabled,
        "reference" => reference,
        "scenario_policy" => policy,
        "allow_model_structure_overrides" => allow_model_structure_overrides,
        "scenarios" => scenarios,
    )
end

function _parse_pipeline_optimization_config(config::Dict{String, Any})
    block = _lookup(config, :optimization, nothing)
    isnothing(block) && return nothing
    block isa AbstractDict || throw(ModelConfigError("optimization must be a mapping"))

    block = _normalize_config_value(block)
    keys_seen = Set(String(key) for key in keys(block))
    extra = setdiff(keys_seen, _PIPELINE_ALLOWED_OPTIMIZATION_KEYS)
    isempty(extra) ||
        throw(
        ArgumentError(
            "optimization includes unsupported keys for the bounded Phase 9 surface: $(join(sort!(collect(extra)), ", "))",
        ),
    )

    enabled = _bool_or_default(block, :enabled, true)
    if enabled
        haskey(block, "total_budget") ||
            throw(
            ArgumentError(
                "optimization.total_budget must be present when optimization is enabled",
            ),
        )
    end

    if haskey(block, "total_budget")
        block["total_budget"] isa Real ||
            throw(ArgumentError("optimization.total_budget must be numeric"))
        block["total_budget"] > 0 ||
            throw(ArgumentError("optimization.total_budget must be positive"))
    end

    if haskey(block, "objective")
        objective = block["objective"]
        objective_symbol = objective isa Symbol ? objective : Symbol(lowercase(String(objective)))
        objective_symbol === :total_response ||
            throw(
            ArgumentError(
                "optimization.objective currently supports only :total_response in the bounded Phase 9 surface",
            ),
        )
        block["objective"] = String(objective_symbol)
    end

    block["enabled"] = enabled
    return Dict{String, Any}(String(key) => value for (key, value) in block)
end

function _parse_pipeline_panel_optimization_config(config::Dict{String, Any})
    block = _lookup(config, :optimization, nothing)
    isnothing(block) && return nothing
    block isa AbstractDict || throw(ModelConfigError("optimization must be a mapping"))

    normalized = _normalize_config_value(block)
    keys_seen = Set(String(key) for key in keys(normalized))
    if isempty(intersect(keys_seen, _PIPELINE_ALLOWED_OPTIMIZATION_KEYS))
        return nothing
    end
    return _parse_pipeline_optimization_config(config)
end

function _strip_pipeline_runner_keys(config::Dict{String, Any})
    stripped = _normalize_config_value(config)
    delete!(stripped, "prior_sensitivity")
    delete!(stripped, "validation")
    delete!(stripped, "optimization")
    if haskey(stripped, "data")
        data_cfg = stripped["data"]
        data_cfg isa AbstractDict || throw(ModelConfigError("data must be a mapping"))
        delete!(data_cfg, "dataset_path")
    end
    return stripped
end

function _validate_pipeline_prior_scenario_name(name::AbstractString)
    isempty(name) && throw(ArgumentError("prior sensitivity scenario names must be non-empty"))
    occursin(_PIPELINE_PRIOR_SCENARIO_NAME_PATTERN, String(name)) ||
        throw(
        ArgumentError(
            "prior sensitivity scenario name `$name` must be a lowercase slug using letters, numbers, and underscores",
        ),
    )
    lowercase(String(name)) in _PIPELINE_RESERVED_PRIOR_SCENARIO_NAMES &&
        throw(
        ArgumentError(
            "prior sensitivity scenario name `$name` is reserved; use a modelling scenario name such as reference, shorter_memory, or tighter_media_effect",
        ),
    )
    return nothing
end

function _optional_prior_sensitivity_string(config::Dict{String, Any}, key::AbstractString)
    haskey(config, key) || return nothing
    value = config[key]
    isnothing(value) && return nothing
    value isa AbstractString ||
        throw(ModelConfigError("prior_sensitivity scenario `$key` must be a string or null"))
    return String(value)
end

function _split_prior_sensitivity_override_path(path::AbstractString)
    parts = String.(strip.(split(String(path), ".")))
    (isempty(parts) || any(isempty, parts)) &&
        throw(ArgumentError("override path `$path` contains an empty segment"))
    return parts
end

function _classify_prior_sensitivity_override_path(path::AbstractString)
    parts = _split_prior_sensitivity_override_path(path)
    normalized = join(parts, ".")
    if first(parts) == "priors" && length(parts) >= 2
        return "prior_sensitivity"
    end
    if length(parts) >= 4 &&
            parts[1] == "media" &&
            parts[2] in ("adstock", "saturation") &&
            parts[3] == "priors"
        return "prior_sensitivity"
    end
    if normalized in ("media.adstock.l_max", "media.adstock.type", "media.saturation.type")
        return "model_structure_sensitivity"
    end
    throw(
        ArgumentError(
            "Unsupported prior sensitivity override path `$path`. Supported paths are media.adstock.priors.*, media.saturation.priors.*, top-level priors.*, and selected model-structure paths such as media.adstock.l_max.",
        ),
    )
end

function _classify_prior_sensitivity_overrides(overrides::AbstractDict)
    isempty(overrides) && return "prior_sensitivity"
    classifications = Set(String(_classify_prior_sensitivity_override_path(path)) for path in keys(overrides))
    "model_structure_sensitivity" in classifications && return "model_structure_sensitivity"
    return "prior_sensitivity"
end

function _pipeline_stage_enabled(config::Union{Nothing, Dict{String, Any}})
    isnothing(config) && return false
    return Bool(config["enabled"])
end
