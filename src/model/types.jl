"""
    AbstractModel

Base abstract type for typed Epsilon model objects.
"""
abstract type AbstractModel end

"""
    AbstractRegressionModel <: AbstractModel

Base abstract type for regression-style model objects.
"""
abstract type AbstractRegressionModel <: AbstractModel end

"""
    AbstractMMMModel <: AbstractRegressionModel

Base abstract type for marketing mix models in Epsilon.
"""
abstract type AbstractMMMModel <: AbstractRegressionModel end

const _SUPPORTED_TARGET_TYPES = Set(("revenue", "conversion"))
const _HSGP_MEDIA_SPEC_STATE_KEY = "_hsgp_media_spec_state"
const _HSGP_MEDIA_COVARIANCES = Set((:expquad, :matern32, :matern52))
const _HSGP_MEDIA_PRIOR_DISTRIBUTIONS = Set(("Exponential", "Gamma", "HalfNormal", "LogNormal"))

"""
    SamplerConfig(; draws=1000, tune=1000, chains=4, cores=chains, target_accept=0.8, random_seed=nothing, progressbar=true, compute_convergence_checks=true)

Typed sampler settings for model fitting.
"""
struct SamplerConfig
    draws::Int
    tune::Int
    chains::Int
    cores::Int
    target_accept::Float64
    random_seed::Union{Nothing, Int}
    progressbar::Bool
    compute_convergence_checks::Bool
end

function Base.:(==)(lhs::SamplerConfig, rhs::SamplerConfig)
    return lhs.draws == rhs.draws &&
        lhs.tune == rhs.tune &&
        lhs.chains == rhs.chains &&
        lhs.cores == rhs.cores &&
        lhs.target_accept == rhs.target_accept &&
        lhs.random_seed == rhs.random_seed &&
        lhs.progressbar == rhs.progressbar &&
        lhs.compute_convergence_checks == rhs.compute_convergence_checks
end

function SamplerConfig(;
        draws::Integer = 1000,
        tune::Integer = 1000,
        chains::Integer = 4,
        cores::Integer = chains,
        target_accept::Real = 0.8,
        random_seed = nothing,
        progressbar::Bool = true,
        compute_convergence_checks::Bool = true,
    )
    config = SamplerConfig(
        Int(draws),
        Int(tune),
        Int(chains),
        Int(cores),
        Float64(target_accept),
        isnothing(random_seed) ? nothing : Int(random_seed),
        progressbar,
        compute_convergence_checks,
    )
    _validate_sampler_config(config)
    return config
end

"""
    TimeVaryingMediaConfig(; m, L, time_resolution, covariance=:expquad, eta_prior, lengthscale_prior)

Programmatic-only configuration for the bounded time-series shared media HSGP
multiplier. `m`, `L`, and `lengthscale_prior` are measured in integer
cadence-index units, while `time_resolution` is measured in days. Only scalar,
dimensionless `Exponential`, `Gamma`, `HalfNormal`, and `LogNormal`
[`EpsilonPrior`](@ref) values are accepted for the positive HSGP priors.

This bounded configuration enables a shared, strictly positive, mean-one HSGP
multiplier for programmatic `TimeSeriesMMM` MCMC fitting and prediction only.
YAML/pipeline configuration, panels, VI, calibration, Michaelis-Menten,
channel-specific, intercept, multidimensional, periodic HSGP, TVP, and HSGP
postmodel calculation routes remain unsupported.
"""
struct TimeVaryingMediaConfig
    m::Int
    L::Float64
    time_resolution::Int
    covariance::Symbol
    eta_prior::EpsilonPrior
    lengthscale_prior::EpsilonPrior
end

function Base.:(==)(lhs::TimeVaryingMediaConfig, rhs::TimeVaryingMediaConfig)
    return lhs.m == rhs.m &&
        lhs.L == rhs.L &&
        lhs.time_resolution == rhs.time_resolution &&
        lhs.covariance == rhs.covariance &&
        lhs.eta_prior == rhs.eta_prior &&
        lhs.lengthscale_prior == rhs.lengthscale_prior
end

function TimeVaryingMediaConfig(;
        m,
        L,
        time_resolution,
        covariance::Symbol = :expquad,
        eta_prior,
        lengthscale_prior,
    )
    mode_count = _hsgp_media_int(m, "m")
    resolution = _hsgp_media_int(time_resolution, "time_resolution")
    boundary = _hsgp_media_float64(L, "L"; positive = true)
    covariance in _HSGP_MEDIA_COVARIANCES ||
        throw(ArgumentError("covariance must be one of :expquad, :matern32, or :matern52"))
    _validate_hsgp_media_prior(eta_prior, "eta_prior")
    _validate_hsgp_media_prior(lengthscale_prior, "lengthscale_prior")

    return TimeVaryingMediaConfig(
        mode_count,
        boundary,
        resolution,
        covariance,
        eta_prior,
        lengthscale_prior,
    )
end

"""
    ModelConfig(; ...)

Typed MMM model configuration assembled from dict or YAML input.

`target_type` currently supports only `"revenue"` and `"conversion"`.
"""
struct ModelConfig
    date_column::String
    target_column::String
    target_type::String
    channel_columns::Vector{String}
    control_columns::Vector{String}
    dims::Tuple{Vararg{String}}
    adstock::Dict{String, Any}
    saturation::Dict{String, Any}
    seasonality::Dict{String, Any}
    trend::Dict{String, Any}
    events::Dict{String, Any}
    holidays::Dict{String, Any}
    controls::Dict{String, Any}
    priors::Dict{String, Any}
    extras::Dict{String, Any}
end

function Base.:(==)(lhs::ModelConfig, rhs::ModelConfig)
    return lhs.date_column == rhs.date_column &&
        lhs.target_column == rhs.target_column &&
        lhs.target_type == rhs.target_type &&
        lhs.channel_columns == rhs.channel_columns &&
        lhs.control_columns == rhs.control_columns &&
        lhs.dims == rhs.dims &&
        lhs.adstock == rhs.adstock &&
        lhs.saturation == rhs.saturation &&
        lhs.seasonality == rhs.seasonality &&
        lhs.trend == rhs.trend &&
        lhs.events == rhs.events &&
        lhs.holidays == rhs.holidays &&
        lhs.controls == rhs.controls &&
        lhs.priors == rhs.priors &&
        lhs.extras == rhs.extras
end

function ModelConfig(;
        date_column,
        target_column,
        target_type = "revenue",
        channel_columns,
        control_columns = String[],
        dims = (),
        adstock = Dict{String, Any}(),
        saturation = Dict{String, Any}(),
        seasonality = Dict{String, Any}(),
        trend = Dict{String, Any}(),
        events = Dict{String, Any}(),
        holidays = Dict{String, Any}(),
        controls = Dict{String, Any}(),
        priors = Dict{String, Any}(),
        extras = Dict{String, Any}(),
        time_varying_media::Union{Nothing, TimeVaryingMediaConfig} = nothing,
    )
    normalized_extras = _string_key_dict(extras)
    !isnothing(time_varying_media) && haskey(normalized_extras, "time_varying_media") &&
        throw(ArgumentError("time_varying_media cannot be supplied through both extras and the ModelConfig keyword"))
    if !isnothing(time_varying_media)
        normalized_extras["time_varying_media"] = time_varying_media
    end
    config = ModelConfig(
        String(date_column),
        String(target_column),
        _normalize_target_type(target_type),
        _string_vector(channel_columns),
        _string_vector(control_columns),
        _string_tuple(dims),
        _string_key_dict(adstock),
        _string_key_dict(saturation),
        _string_key_dict(seasonality),
        _string_key_dict(trend),
        _string_key_dict(events),
        _string_key_dict(holidays),
        _string_key_dict(controls),
        _string_key_dict(priors),
        normalized_extras,
    )
    _validate_model_config(config)
    return config
end

"""
    MMMData(; dates, target, channels, channel_names, controls=nothing, control_names=String[], events=nothing, event_names=String[])

Typed container for the arrays that define one MMM training dataset.

`target` and `channels` are stored in the caller's original measurement units.
Downstream spend-like arguments, including optimizer `total_budget` and bounds,
must use the same channel units and time aggregation level.
"""
struct MMMData{D <: AbstractVector, T <: AbstractVector, C <: AbstractMatrix, U, V}
    dates::D
    target::T
    channels::C
    controls::U
    events::V
    channel_names::Vector{String}
    control_names::Vector{String}
    event_names::Vector{String}
end

function Base.:(==)(lhs::MMMData, rhs::MMMData)
    return lhs.dates == rhs.dates &&
        lhs.target == rhs.target &&
        lhs.channels == rhs.channels &&
        lhs.controls == rhs.controls &&
        lhs.events == rhs.events &&
        lhs.channel_names == rhs.channel_names &&
        lhs.control_names == rhs.control_names &&
        lhs.event_names == rhs.event_names
end

function MMMData(;
        dates,
        target,
        channels,
        channel_names,
        controls = nothing,
        control_names = String[],
        events = nothing,
        event_names = String[],
    )
    data = MMMData(
        dates,
        target,
        channels,
        controls,
        events,
        _string_vector(channel_names),
        _string_vector(control_names),
        _string_vector(event_names),
    )
    _validate_mmm_data(data)
    return data
end

"""
    PanelMMMData(; dates, target, channels, panel_names, channel_names, panel_coordinates=Dict())

Typed container for a bounded panel MMM dataset with a shared time axis.

`target` is stored as `(time, panel)` and `channels` as `(time, channel, panel)`.
For multi-dimensional panel configs, `panel` is the deterministic flattened
panel-cell axis and `panel_coordinates` can carry the original coordinate value
for each declared panel dimension. Use [`ntime`](@ref), [`npanels`](@ref), and
[`npanel_observations`](@ref) when code needs to distinguish the shared time
axis from flattened panel-cell observations.

`target` and `channels` are stored in the caller's original measurement units.
Downstream spend-like arguments, including optimizer `total_budget` and bounds,
must use the same channel units and time aggregation level.
"""
struct PanelMMMData{D <: AbstractVector, T <: AbstractMatrix, C <: AbstractArray}
    dates::D
    target::T
    channels::C
    panel_names::Vector{String}
    channel_names::Vector{String}
    panel_coordinates::Dict{String, Vector{String}}
end

function Base.:(==)(lhs::PanelMMMData, rhs::PanelMMMData)
    return lhs.dates == rhs.dates &&
        lhs.target == rhs.target &&
        lhs.channels == rhs.channels &&
        lhs.panel_names == rhs.panel_names &&
        lhs.channel_names == rhs.channel_names &&
        lhs.panel_coordinates == rhs.panel_coordinates
end

function PanelMMMData(;
        dates,
        target,
        channels,
        panel_names,
        channel_names,
        panel_coordinates = Dict{String, Vector{String}}(),
    )
    data = PanelMMMData(
        dates,
        target,
        channels,
        _string_vector(panel_names),
        _string_vector(channel_names),
        _string_vector_dict(panel_coordinates),
    )
    validate_panel_mmm_data(data)
    return data
end

"""
    nobs(data)

Return the number of observations in an MMM data container.

For `MMMData`, this is the number of time rows. For `PanelMMMData`, this
currently returns flattened panel-cell observations, `ntime(data) *
npanels(data)`, to preserve existing panel artifact and model-spec contracts.
Use [`ntime`](@ref) and [`npanels`](@ref) when those axes need to remain
separate.
"""
nobs(data::MMMData) = length(data.target)
nobs(data::PanelMMMData) = npanel_observations(data)

"""
    ntime(data)

Return the number of time rows in an MMM data container.
"""
ntime(data::MMMData) = length(data.target)
ntime(data::PanelMMMData) = size(data.target, 1)

"""
    npanels(data::PanelMMMData)

Return the number of flattened panel cells in a panel MMM data container.
"""
npanels(data::PanelMMMData) = size(data.target, 2)

"""
    npanel_observations(data::PanelMMMData)

Return the number of flattened panel-cell observations, `ntime(data) *
npanels(data)`.
"""
npanel_observations(data::PanelMMMData) = ntime(data) * npanels(data)

"""
    validate_sampler_config(config)

Deprecated public validation wrapper for one sampler configuration.

Use `SamplerConfig` construction or `load_sampler_config` instead. Direct
calls emit a deprecation warning, then validate sampler settings.
"""
function validate_sampler_config(config::SamplerConfig)
    Base.depwarn(
        "Epsilon.validate_sampler_config is deprecated as a public API; use SamplerConfig construction or load_sampler_config instead. The function remains exported for this release and may be unexported before v1.",
        :validate_sampler_config,
    )
    return _validate_sampler_config(config)
end

function _validate_sampler_config(config::SamplerConfig)
    config.draws > 0 || throw(ArgumentError("draws must be positive"))
    config.tune >= 0 || throw(ArgumentError("tune must be nonnegative"))
    config.chains > 0 || throw(ArgumentError("chains must be positive"))
    config.cores > 0 || throw(ArgumentError("cores must be positive"))
    0.0 < config.target_accept < 1.0 ||
        throw(ArgumentError("target_accept must lie in (0, 1)"))
    return nothing
end

"""
    validate_model_config(config)

Deprecated public validation wrapper for one model configuration object.

Use `ModelConfig` construction or `load_model_config` instead. Direct calls
emit a deprecation warning, then validate the typed model configuration.
"""
function validate_model_config(config::ModelConfig)
    Base.depwarn(
        "Epsilon.validate_model_config is deprecated as a public API; use ModelConfig construction or load_model_config instead. The function remains exported for this release and may be unexported before v1.",
        :validate_model_config,
    )
    return _validate_model_config(config)
end

function _validate_model_config(config::ModelConfig)
    !isempty(config.date_column) || throw(ArgumentError("date_column must not be empty"))
    !isempty(config.target_column) || throw(ArgumentError("target_column must not be empty"))
    config.target_type in _SUPPORTED_TARGET_TYPES ||
        throw(
        ArgumentError(
            "target_type must be one of $(join(sort!(collect(_SUPPORTED_TARGET_TYPES)), ", "))",
        ),
    )
    !isempty(config.channel_columns) || throw(ArgumentError("channel_columns must not be empty"))
    _validate_unique_strings(config.channel_columns, "channel_columns")
    _validate_unique_strings(config.control_columns, "control_columns")
    _validate_unique_strings(collect(config.dims), "dims")

    overlap = intersect(config.channel_columns, config.control_columns)
    isempty(overlap) || throw(ArgumentError("channel_columns and control_columns must not overlap"))
    config.date_column != config.target_column ||
        throw(ArgumentError("date_column and target_column must be distinct"))
    config.target_column ∉ config.channel_columns ||
        throw(ArgumentError("target_column must not also be listed in channel_columns"))
    config.date_column ∉ config.channel_columns ||
        throw(ArgumentError("date_column must not also be listed in channel_columns"))
    config.target_column ∉ config.control_columns ||
        throw(ArgumentError("target_column must not also be listed in control_columns"))
    config.date_column ∉ config.control_columns ||
        throw(ArgumentError("date_column must not also be listed in control_columns"))
    !haskey(config.priors, "beta_controls") ||
        throw(
        ArgumentError(
            "top-level priors.beta_controls is not supported in the current model path; use controls.priors.beta instead",
        ),
    )
    !haskey(config.priors, "beta_control") ||
        throw(
        ArgumentError(
            "top-level priors.beta_control is not supported in the current model path; use controls.priors.beta instead",
        ),
    )
    !haskey(config.priors, _HSGP_MEDIA_SPEC_STATE_KEY) ||
        throw(ArgumentError("$(_HSGP_MEDIA_SPEC_STATE_KEY) is reserved for private model-spec state"))
    _validate_adstock_config(config.adstock)
    _validate_saturation_config(config.saturation)
    _validate_hsgp_media_config_compatibility(config)
    _validate_seasonality_config(config.seasonality)
    _validate_trend_config(config.trend)
    _validate_events_config(config.events)
    _validate_holidays_config(config.holidays)
    _validate_holiday_event_coexistence(config.events, config.holidays)
    _validate_controls_config(config.controls)
    !isempty(config.controls) && isempty(config.control_columns) &&
        throw(ArgumentError("controls block requires control columns via media.controls"))
    return nothing
end

function _validate_hsgp_media_prior(prior, name::AbstractString)
    prior isa EpsilonPrior || throw(ArgumentError("$name must be an EpsilonPrior"))
    prior.distribution in _HSGP_MEDIA_PRIOR_DISTRIBUTIONS || throw(
        ArgumentError("$name must use Exponential, Gamma, HalfNormal, or LogNormal"),
    )
    isnothing(prior.dims) || throw(ArgumentError("$name must be scalar and dimensionless"))
    prior.centered || throw(ArgumentError("$name must use the default centred prior representation"))
    isnothing(prior.transform) || throw(ArgumentError("$name must not define a transform"))

    expected = if prior.distribution == "Exponential"
        _hsgp_media_required_parameter_set(prior.parameters, name, (), (:lam, :lambda, :rate))
    elseif prior.distribution == "Gamma"
        _hsgp_media_required_parameter_set(prior.parameters, name, (:alpha,), (:beta, :rate))
    elseif prior.distribution == "HalfNormal"
        _hsgp_media_required_parameter_set(prior.parameters, name, (:sigma,))
    else
        _hsgp_media_required_parameter_set(prior.parameters, name, (:sigma,), (:mu,); optional = true)
    end

    for parameter in expected
        value = prior.parameters[parameter]
        value isa Real && !(value isa Bool) && isfinite(value) ||
            throw(ArgumentError("$name.$parameter must be a finite scalar real number"))
        _hsgp_media_float64(value, "$name.$parameter"; positive = parameter !== :mu)
    end
    return nothing
end

function _hsgp_media_int(value, name::AbstractString)
    value isa Integer && !(value isa Bool) && value >= 1 ||
        throw(ArgumentError("$name must be a positive integer"))
    value <= typemax(Int) || throw(ArgumentError("$name must be representable as Int"))
    return Int(value)
end

function _hsgp_media_float64(value, name::AbstractString; positive::Bool)
    value isa Real && !(value isa Bool) && isfinite(value) ||
        throw(ArgumentError("$name must be a finite scalar real number"))
    !positive || value > zero(value) || throw(ArgumentError("$name must be positive"))
    converted = Float64(value)
    isfinite(converted) || throw(ArgumentError("$name must be representable as a finite Float64"))
    return converted
end

function _hsgp_media_required_parameter_set(
        parameters::Dict{Symbol, Any},
        name::AbstractString,
        required::Tuple,
        alternatives::Tuple = (),
        ;
        optional::Bool = false,
    )
    parameter_keys = Set(keys(parameters))
    expected = Set{Symbol}(required)
    if !isempty(alternatives)
        present = intersect(parameter_keys, Set(alternatives))
        optional || length(present) == 1 || throw(
            ArgumentError("$name must define exactly one of $(join(string.(alternatives), ", "))"),
        )
        length(present) <= 1 || throw(
            ArgumentError("$name must define at most one of $(join(string.(alternatives), ", "))"),
        )
        union!(expected, present)
    end
    parameter_keys == expected || throw(
        ArgumentError("$name has unsupported or missing prior parameters"),
    )
    return Tuple(sort!(collect(expected); by = String))
end

function _time_varying_media_config(config::ModelConfig)
    value = get(config.extras, "time_varying_media", nothing)
    isnothing(value) && return nothing
    value isa TimeVaryingMediaConfig ||
        throw(ArgumentError("ModelConfig.extras[\"time_varying_media\"] must be a TimeVaryingMediaConfig"))
    return value
end

function _validate_hsgp_media_config_compatibility(config::ModelConfig)
    time_varying_media = _time_varying_media_config(config)
    isnothing(time_varying_media) && return nothing
    _validate_hsgp_media_prior(time_varying_media.eta_prior, "eta_prior")
    _validate_hsgp_media_prior(time_varying_media.lengthscale_prior, "lengthscale_prior")
    saturation_type = get(config.saturation, "type", "none")
    saturation_type isa AbstractString || return nothing
    lowercase(strip(saturation_type)) == "michaelis_menten" && throw(
        ArgumentError("time_varying_media does not support Michaelis-Menten saturation"),
    )
    return nothing
end

"""
    validate_mmm_data(data)

Deprecated public validation wrapper for an `MMMData` container.

Use `MMMData` construction before building `TimeSeriesMMM` instead. Direct
calls emit a deprecation warning, then validate the typed data container.
"""
function validate_mmm_data(data::MMMData)
    Base.depwarn(
        "Epsilon.validate_mmm_data is deprecated as a public API; use MMMData construction before building TimeSeriesMMM instead. The function remains exported for this release and may be unexported before v1.",
        :validate_mmm_data,
    )
    return _validate_mmm_data(data)
end

function _validate_mmm_data(data::MMMData)
    n = length(data.target)
    n > 0 || throw(ArgumentError("target must contain at least one observation"))
    length(data.dates) == n || throw(ArgumentError("dates and target must have matching length"))
    size(data.channels, 1) == n || throw(ArgumentError("channels row count must match target length"))
    size(data.channels, 2) > 0 ||
        throw(ArgumentError("channels must contain at least one media column"))
    size(data.channels, 2) == length(data.channel_names) ||
        throw(ArgumentError("channel_names length must match the number of channel columns"))
    _validate_numeric_values(data.target, "target")
    _validate_numeric_values(data.channels, "channels")
    _validate_nonnegative_values(data.channels, "channels")
    _validate_unique_strings(data.channel_names, "channel_names")

    if isnothing(data.controls)
        isempty(data.control_names) ||
            throw(ArgumentError("control_names must be empty when controls are not provided"))
    else
        size(data.controls, 1) == n ||
            throw(ArgumentError("controls row count must match target length"))
        size(data.controls, 2) == length(data.control_names) ||
            throw(ArgumentError("control_names length must match the number of control columns"))
        _validate_numeric_values(data.controls, "controls")
        _validate_unique_strings(data.control_names, "control_names")
    end

    if isnothing(data.events)
        isempty(data.event_names) ||
            throw(ArgumentError("event_names must be empty when events are not provided"))
    else
        size(data.events, 1) == n ||
            throw(ArgumentError("events row count must match target length"))
        size(data.events, 2) == length(data.event_names) ||
            throw(ArgumentError("event_names length must match the number of event columns"))
        _validate_numeric_values(data.events, "events")
        _validate_unique_strings(data.event_names, "event_names")
    end

    return nothing
end

"""
    validate_panel_mmm_data(data)

Validate a `PanelMMMData` container.
"""
function validate_panel_mmm_data(data::PanelMMMData)
    time_count = ntime(data)
    panel_count = npanels(data)

    time_count > 0 || throw(ArgumentError("target must contain at least one time observation"))
    panel_count > 0 || throw(ArgumentError("target must contain at least one panel column"))
    length(data.dates) == time_count ||
        throw(ArgumentError("dates and target time axis must have matching length"))
    size(data.channels, 1) == time_count ||
        throw(ArgumentError("channels time axis must match target"))
    size(data.channels, 2) > 0 ||
        throw(ArgumentError("channels must contain at least one media column"))
    size(data.channels, 2) == length(data.channel_names) ||
        throw(ArgumentError("channel_names length must match the number of channel columns"))
    ndims(data.channels) == 3 ||
        throw(ArgumentError("channels must be a 3-dimensional array with axes (time, channel, panel)"))
    size(data.channels, 3) == panel_count ||
        throw(ArgumentError("channels panel axis must match target"))
    length(data.panel_names) == panel_count ||
        throw(ArgumentError("panel_names length must match the number of panel columns"))
    for (dimension, values) in data.panel_coordinates
        isempty(dimension) &&
            throw(ArgumentError("panel coordinate dimension names must not be empty"))
        length(values) == panel_count ||
            throw(
            ArgumentError(
                "panel coordinate dimension `$dimension` length must match the number of panel columns",
            ),
        )
    end
    _validate_numeric_values(data.target, "target")
    _validate_numeric_values(data.channels, "channels")
    _validate_nonnegative_values(data.channels, "channels")
    _validate_unique_strings(data.panel_names, "panel_names")
    _validate_unique_strings(data.channel_names, "channel_names")
    return nothing
end

function _string_vector(values)
    values isa AbstractString &&
        throw(ArgumentError("expected a collection of strings, not a single string"))
    return String[String(value) for value in values]
end

function _string_tuple(values)
    values isa AbstractString &&
        throw(ArgumentError("expected a collection of strings, not a single string"))
    return Tuple(String(value) for value in values)
end

function _string_vector_dict(values)
    values isa AbstractDict || return Dict{String, Vector{String}}()
    return Dict{String, Vector{String}}(
        String(key) => _string_vector(item) for (key, item) in values
    )
end

function _normalize_target_type(target_type)
    normalized = lowercase(strip(String(target_type)))
    normalized in _SUPPORTED_TARGET_TYPES ||
        throw(
        ArgumentError(
            "target_type must be one of $(join(sort!(collect(_SUPPORTED_TARGET_TYPES)), ", "))",
        ),
    )
    return normalized
end

function _string_key_dict(value)
    if value isa Dict{String, Any}
        return copy(value)
    end

    if value isa AbstractDict
        return Dict{String, Any}(String(key) => item for (key, item) in value)
    end

    throw(ArgumentError("expected a mapping"))
end

function _validate_unique_strings(values, name::AbstractString)
    string_values = String[String(value) for value in values]
    length(unique(string_values)) == length(string_values) ||
        throw(ArgumentError("$name must not contain duplicates"))
    return nothing
end

function _validate_numeric_values(values, name::AbstractString)
    all(value -> value isa Real && isfinite(value), values) ||
        throw(ArgumentError("$name must contain only finite numeric values"))
    return nothing
end

function _validate_nonnegative_values(values, name::AbstractString)
    all(value -> value isa Real && value >= zero(value), values) ||
        throw(ArgumentError("$name must contain only nonnegative values"))
    return nothing
end
