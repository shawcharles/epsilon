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
    validate_sampler_config(config)
    return config
end

"""
    ModelConfig(; ...)

Typed MMM model configuration assembled from dict or YAML input.
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
    priors::Dict{String, Any}
    extras::Dict{String, Any}
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
    priors = Dict{String, Any}(),
    extras = Dict{String, Any}(),
)
    config = ModelConfig(
        String(date_column),
        String(target_column),
        String(target_type),
        _string_vector(channel_columns),
        _string_vector(control_columns),
        _string_tuple(dims),
        _string_key_dict(adstock),
        _string_key_dict(saturation),
        _string_key_dict(priors),
        _string_key_dict(extras),
    )
    validate_model_config(config)
    return config
end

"""
    MMMData(; dates, target, channels, channel_names, controls=nothing, control_names=String[])

Typed container for the arrays that define one MMM training dataset.
"""
struct MMMData{D <: AbstractVector, T <: AbstractVector, C <: AbstractMatrix, U}
    dates::D
    target::T
    channels::C
    controls::U
    channel_names::Vector{String}
    control_names::Vector{String}
end

function MMMData(;
    dates,
    target,
    channels,
    channel_names,
    controls = nothing,
    control_names = String[],
)
    data = MMMData(
        dates,
        target,
        channels,
        controls,
        _string_vector(channel_names),
        _string_vector(control_names),
    )
    validate_mmm_data(data)
    return data
end

"""
    nobs(data)

Return the number of observations in an `MMMData` container.
"""
nobs(data::MMMData) = length(data.target)

"""
    validate_sampler_config(config)

Validate one sampler configuration.
"""
function validate_sampler_config(config::SamplerConfig)
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

Validate one model configuration object.
"""
function validate_model_config(config::ModelConfig)
    !isempty(config.date_column) || throw(ArgumentError("date_column must not be empty"))
    !isempty(config.target_column) || throw(ArgumentError("target_column must not be empty"))
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
    return nothing
end

"""
    validate_mmm_data(data)

Validate an `MMMData` container.
"""
function validate_mmm_data(data::MMMData)
    n = length(data.target)
    length(data.dates) == n || throw(ArgumentError("dates and target must have matching length"))
    size(data.channels, 1) == n || throw(ArgumentError("channels row count must match target length"))
    size(data.channels, 2) == length(data.channel_names) ||
        throw(ArgumentError("channel_names length must match the number of channel columns"))
    _validate_unique_strings(data.channel_names, "channel_names")

    if isnothing(data.controls)
        isempty(data.control_names) ||
            throw(ArgumentError("control_names must be empty when controls are not provided"))
    else
        size(data.controls, 1) == n ||
            throw(ArgumentError("controls row count must match target length"))
        size(data.controls, 2) == length(data.control_names) ||
            throw(ArgumentError("control_names length must match the number of control columns"))
        _validate_unique_strings(data.control_names, "control_names")
    end

    return nothing
end

function _string_vector(values)
    return String[String(value) for value in values]
end

function _string_tuple(values)
    return Tuple(String(value) for value in values)
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
