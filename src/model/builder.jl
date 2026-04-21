"""
    MMMModelSpec

Resolved model-building payload for a time-series MMM before a sampling backend
is attached.
"""
struct MMMModelSpec
    model_kind::Symbol
    nobs::Int
    nchannels::Int
    ncontrols::Int
    dims::Tuple{Vararg{String}}
    target_column::String
    target_type::String
    channel_columns::Vector{String}
    control_columns::Vector{String}
    channel_indices::Dict{String, Int}
    control_indices::Dict{String, Int}
    adstock::Dict{String, Any}
    saturation::Dict{String, Any}
    priors::Dict{String, Any}
end

"""
    ModelFitState(status, backend; artifact=nothing, message="")

Track the current fit lifecycle state for a model object.
"""
struct ModelFitState
    status::Symbol
    backend::Symbol
    artifact
    message::String
end

function ModelFitState(status::Symbol, backend::Symbol; artifact = nothing, message::AbstractString = "")
    return ModelFitState(status, backend, artifact, String(message))
end

"""
    TimeSeriesMMM(config, sampler_config, data)

Container that ties together typed config, sampler settings, and one MMM dataset
for the base time-series model path.
"""
mutable struct TimeSeriesMMM <: AbstractMMMModel
    config::ModelConfig
    sampler_config::SamplerConfig
    data::MMMData
    built_model::Union{Nothing, MMMModelSpec}
    fit_state::Union{Nothing, ModelFitState}
end

function TimeSeriesMMM(config::ModelConfig, sampler_config::SamplerConfig, data::MMMData)
    _validate_model_data_alignment(config, data)
    return TimeSeriesMMM(config, sampler_config, data, nothing, nothing)
end

"""
    build_model(model)

Resolve one typed MMM object into a backend-agnostic model specification that
the later Turing model layer can consume.
"""
function build_model(model::TimeSeriesMMM)
    _validate_model_data_alignment(model.config, model.data)

    channel_columns = copy(model.config.channel_columns)
    control_columns = copy(model.config.control_columns)
    spec = MMMModelSpec(
        :time_series_mmm,
        nobs(model.data),
        length(channel_columns),
        length(control_columns),
        model.config.dims,
        model.config.target_column,
        model.config.target_type,
        channel_columns,
        control_columns,
        Dict(name => index for (index, name) in enumerate(channel_columns)),
        Dict(name => index for (index, name) in enumerate(control_columns)),
        copy(model.config.adstock),
        copy(model.config.saturation),
        copy(model.config.priors),
    )
    model.built_model = spec
    return spec
end

"""
    fit!(model)

Prepare a fit request for one typed MMM object and record the current fit state.
Sampling itself is added in the later Turing model phase.
"""
function fit!(model::TimeSeriesMMM)
    spec = isnothing(model.built_model) ? build_model(model) : model.built_model
    state = ModelFitState(
        :deferred,
        :unimplemented;
        artifact = spec,
        message = "Sampling backend is not implemented yet; the model has only been prepared.",
    )
    model.fit_state = state
    return state
end

"""
    predict(model, new_data=model.data)

Validate one prediction dataset against the typed MMM shell. Prediction is added
after the sampling backend exists.
"""
function predict(model::TimeSeriesMMM, new_data::MMMData = model.data)
    _validate_model_data_alignment(model.config, new_data)
    throw(
        ErrorException(
            "predict is not implemented yet for TimeSeriesMMM; the sampling backend lands in a later Phase 4 sprint.",
        ),
    )
end

function _validate_model_data_alignment(config::ModelConfig, data::MMMData)
    config.channel_columns == data.channel_names ||
        throw(ArgumentError("config.channel_columns must match data.channel_names in order"))

    if isnothing(data.controls)
        isempty(config.control_columns) ||
            throw(ArgumentError("config.control_columns require controls in MMMData"))
    else
        config.control_columns == data.control_names ||
            throw(ArgumentError("config.control_columns must match data.control_names in order"))
    end

    return nothing
end
