"""
    PanelAxis

Ordered metadata for one flattened panel-cell axis.

`name` is the analyst-facing flat panel-cell column name, currently
`"panel_cell"`. `values` stores the flat panel-cell labels in model order, and
`coordinate_columns` stores declared panel-dimension coordinate columns in the
same order as `ModelCoordinateMetadata.panel_dims`.
"""
struct PanelAxis
    name::String
    values::Vector{String}
    coordinate_columns::Vector{Pair{String, Vector{String}}}
end

function Base.:(==)(lhs::PanelAxis, rhs::PanelAxis)
    return lhs.name == rhs.name &&
        lhs.values == rhs.values &&
        lhs.coordinate_columns == rhs.coordinate_columns
end

function PanelAxis(;
        name::AbstractString = "panel_cell",
        values,
        coordinate_columns = Pair{String, Vector{String}}[],
    )
    return PanelAxis(
        String(name),
        String[String(value) for value in values],
        Pair{String, Vector{String}}[
            String(column.first) => String[String(value) for value in column.second]
                for column in coordinate_columns
        ],
    )
end

"""
    ModelCoordinateMetadata

Serializable coordinate and named-dimension metadata resolved during typed model
building.
"""
struct ModelCoordinateMetadata
    observation_dim::String
    panel_dims::Tuple{Vararg{String}}
    coordinates::Dict{String, Vector{String}}
    named_dims::Dict{String, Tuple{Vararg{String}}}
    panel_axes::Vector{PanelAxis}
end

function ModelCoordinateMetadata(
        observation_dim::AbstractString,
        panel_dims,
        coordinates::AbstractDict,
        named_dims::AbstractDict,
    )
    panel_dims_tuple = Tuple(String(dim) for dim in panel_dims)
    coordinate_map = Dict{String, Vector{String}}(
        String(key) => String[String(value) for value in values]
            for (key, values) in coordinates
    )
    named_dim_map = Dict{String, Tuple{Vararg{String}}}(
        String(key) => Tuple(String(dim) for dim in dims)
            for (key, dims) in named_dims
    )
    return ModelCoordinateMetadata(
        String(observation_dim),
        panel_dims_tuple,
        coordinate_map,
        named_dim_map,
        _panel_axes_from_coordinates(panel_dims_tuple, coordinate_map),
    )
end

function Base.:(==)(lhs::ModelCoordinateMetadata, rhs::ModelCoordinateMetadata)
    return lhs.observation_dim == rhs.observation_dim &&
        lhs.panel_dims == rhs.panel_dims &&
        lhs.coordinates == rhs.coordinates &&
        lhs.named_dims == rhs.named_dims &&
        lhs.panel_axes == rhs.panel_axes
end

"""
    PanelCoordinate

Named coordinate mapping for one flattened panel-cell index.

`flat_index` is the one-based index used on Epsilon's internal flat `panel`
axis, `panel_name` is the corresponding flat panel label, and `values` stores
the declared panel-dimension coordinates as a `NamedTuple`, for example
`(geo = "UK", brand = "Alpha")`.
"""
struct PanelCoordinate
    flat_index::Int
    panel_name::String
    values::NamedTuple
end

function Base.:(==)(lhs::PanelCoordinate, rhs::PanelCoordinate)
    return lhs.flat_index == rhs.flat_index &&
        lhs.panel_name == rhs.panel_name &&
        lhs.values == rhs.values
end

"""
    panel_coordinates(metadata::ModelCoordinateMetadata)
    panel_coordinates(spec::MMMModelSpec)

Return the deterministic mapping from Epsilon's flat `panel_cell` axis to named
panel coordinates.

For one-dimensional and multi-dimensional panel models, Epsilon keeps
`panel_cell` as the explicit flat axis and stores the declared panel-dimension
coordinate columns in [`PanelAxis`](@ref) order.
"""
function panel_coordinates(metadata::ModelCoordinateMetadata)
    isempty(metadata.panel_dims) && return PanelCoordinate[]

    axis = panel_axis(metadata)
    length(axis.coordinate_columns) == length(metadata.panel_dims) ||
        throw(ArgumentError("panel axis coordinate columns do not match declared panel dimensions"))

    return [
        PanelCoordinate(
                index,
                axis.values[index],
                _panel_coordinate_named_tuple(
                    metadata.panel_dims,
                    Tuple(column.second[index] for column in axis.coordinate_columns),
                ),
            ) for index in eachindex(axis.values)
    ]
end

"""
    panel_axes(metadata_or_spec)

Return ordered flat panel-cell axis metadata. Non-panel metadata returns an
empty vector.
"""
panel_axes(metadata::ModelCoordinateMetadata) = copy(metadata.panel_axes)

"""
    panel_axis(metadata_or_spec)

Return the single ordered [`PanelAxis`](@ref) for a panel model.
"""
function panel_axis(metadata::ModelCoordinateMetadata)
    length(metadata.panel_axes) == 1 ||
        throw(ArgumentError("metadata does not contain exactly one panel axis"))
    return only(metadata.panel_axes)
end

"""
    panel_coordinate(metadata_or_spec, flat_index)

Return the [`PanelCoordinate`](@ref) for one one-based flat panel-cell index.
"""
function panel_coordinate(metadata::ModelCoordinateMetadata, flat_index::Integer)
    coordinates = panel_coordinates(metadata)
    1 <= flat_index <= length(coordinates) ||
        throw(BoundsError(coordinates, flat_index))
    return coordinates[Int(flat_index)]
end

function _flat_panel_dim_name(metadata::ModelCoordinateMetadata)
    isempty(metadata.panel_dims) && return "panel"
    return length(metadata.panel_dims) == 1 ? only(metadata.panel_dims) : "panel"
end

function _panel_axes_from_coordinates(
        panel_dims::Tuple{Vararg{String}},
        coordinates::Dict{String, Vector{String}},
    )
    isempty(panel_dims) && return PanelAxis[]
    legacy_panel_axis = length(panel_dims) == 1 ? only(panel_dims) : "panel"
    panel_values = get(
        coordinates,
        "panel_cell",
        get(coordinates, legacy_panel_axis, String[]),
    )
    isempty(panel_values) && return PanelAxis[]
    return [
        PanelAxis(
            name = "panel_cell",
            values = panel_values,
            coordinate_columns = _panel_axis_coordinate_columns(
                panel_dims,
                coordinates,
                panel_values,
            ),
        ),
    ]
end

function _panel_axis_coordinate_columns(
        panel_dims::Tuple{Vararg{String}},
        coordinates::Dict{String, Vector{String}},
        panel_values::Vector{String},
    )
    panel_count = length(panel_values)
    coordinate_axes = Vector{Vector{String}}()
    for dim in panel_dims
        values = get(coordinates, dim, String[])
        if length(values) == panel_count
            push!(coordinate_axes, copy(values))
            continue
        end
        isempty(values) && length(panel_dims) == 1 && push!(coordinate_axes, copy(panel_values))
        isempty(values) || push!(coordinate_axes, copy(values))
    end

    length(coordinate_axes) == length(panel_dims) ||
        return Pair{String, Vector{String}}[]

    all(axis -> length(axis) == panel_count, coordinate_axes) &&
        return Pair{String, Vector{String}}[
        panel_dims[index] => coordinate_axes[index] for index in eachindex(panel_dims)
    ]

    prod(length, coordinate_axes; init = 1) == panel_count ||
        return Pair{String, Vector{String}}[]

    keys = [()]
    for values in coordinate_axes
        keys = [(key..., value) for key in keys for value in values]
    end
    columns = [
        panel_dims[index] => Vector{String}(undef, panel_count)
            for index in eachindex(panel_dims)
    ]
    for (row, key) in enumerate(keys)
        for (dim_index, value) in enumerate(key)
            columns[dim_index].second[row] = value
        end
    end
    return columns
end

function _panel_coordinate_named_tuple(
        panel_dims::Tuple{Vararg{String}},
        values::Tuple,
    )
    names = Tuple(Symbol(dimension) for dimension in panel_dims)
    return NamedTuple{names}(values)
end

"""
    MMMModelSpec

Resolved model-building payload before a sampling backend is attached, including
coordinate metadata for the current typed model surface.

For time-series models `channel_scale` is a channel vector and `target_scale` is
a scalar. For panel models `channel_scale` is a channel-by-flattened-panel
matrix and `target_scale` is a flattened-panel vector. For panel specs, `nobs`
currently stores flattened panel-cell observations to preserve artifact
contracts; use `ntime(data)` and `npanels(data)` at the data boundary when the
shared time and flat panel axes must remain separate.
"""
struct MMMModelSpec
    model_kind::Symbol
    nobs::Int
    nchannels::Int
    ncontrols::Int
    dims::Tuple{Vararg{String}}
    coordinate_metadata::ModelCoordinateMetadata
    target_column::String
    target_type::String
    channel_columns::Vector{String}
    control_columns::Vector{String}
    channel_indices::Dict{String, Int}
    control_indices::Dict{String, Int}
    channel_scale::Union{Vector{Float64}, Matrix{Float64}}
    target_scale::Union{Float64, Vector{Float64}}
    adstock::Dict{String, Any}
    saturation::Dict{String, Any}
    seasonality::Dict{String, Any}
    trend::Dict{String, Any}
    events::Dict{String, Any}
    holidays::Dict{String, Any}
    controls::Dict{String, Any}
    priors::Dict{String, Any}
end

function Base.:(==)(lhs::MMMModelSpec, rhs::MMMModelSpec)
    return lhs.model_kind == rhs.model_kind &&
        lhs.nobs == rhs.nobs &&
        lhs.nchannels == rhs.nchannels &&
        lhs.ncontrols == rhs.ncontrols &&
        lhs.dims == rhs.dims &&
        lhs.coordinate_metadata == rhs.coordinate_metadata &&
        lhs.target_column == rhs.target_column &&
        lhs.target_type == rhs.target_type &&
        lhs.channel_columns == rhs.channel_columns &&
        lhs.control_columns == rhs.control_columns &&
        lhs.channel_indices == rhs.channel_indices &&
        lhs.control_indices == rhs.control_indices &&
        lhs.channel_scale == rhs.channel_scale &&
        lhs.target_scale == rhs.target_scale &&
        lhs.adstock == rhs.adstock &&
        lhs.saturation == rhs.saturation &&
        lhs.seasonality == rhs.seasonality &&
        lhs.trend == rhs.trend &&
        lhs.events == rhs.events &&
        lhs.holidays == rhs.holidays &&
        lhs.controls == rhs.controls &&
        lhs.priors == rhs.priors
end

panel_coordinates(spec::MMMModelSpec) = panel_coordinates(spec.coordinate_metadata)

panel_coordinate(spec::MMMModelSpec, flat_index::Integer) =
    panel_coordinate(spec.coordinate_metadata, flat_index)

panel_axes(spec::MMMModelSpec) = panel_axes(spec.coordinate_metadata)

panel_axis(spec::MMMModelSpec) = panel_axis(spec.coordinate_metadata)

"""
    _compute_scales(data::MMMData)

Compute max scaling factors for channel and target data.
`channel_scale[j] = max(channels[:, j])` over the date dimension.
`target_scale   = max(target)` over the date dimension.
Zero or negative scales are replaced with 1.0 to avoid division by zero.
"""
function _compute_scales(data::MMMData)
    nchannels = size(data.channels, 2)
    channel_scale = Vector{Float64}(undef, nchannels)
    for j in 1:nchannels
        s = maximum(view(data.channels, :, j))
        channel_scale[j] = s > 0.0 ? Float64(s) : 1.0
    end
    t = maximum(data.target)
    target_scale = t > 0.0 ? Float64(t) : 1.0
    return channel_scale, target_scale
end

function _compute_scales(data::PanelMMMData)
    nchannels = size(data.channels, 2)
    panel_count = npanels(data)
    channel_scale = Matrix{Float64}(undef, nchannels, panel_count)
    for panel in 1:panel_count
        for channel in 1:nchannels
            scale = maximum(view(data.channels, :, channel, panel))
            channel_scale[channel, panel] = scale > 0.0 ? Float64(scale) : 1.0
        end
    end

    target_scale = Vector{Float64}(undef, panel_count)
    for panel in 1:panel_count
        scale = maximum(view(data.target, :, panel))
        target_scale[panel] = scale > 0.0 ? Float64(scale) : 1.0
    end
    return channel_scale, target_scale
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

function Base.:(==)(lhs::ModelFitState, rhs::ModelFitState)
    return lhs.status == rhs.status &&
        lhs.backend == rhs.backend &&
        lhs.artifact == rhs.artifact &&
        lhs.message == rhs.message
end

function ModelFitState(status::Symbol, backend::Symbol; artifact = nothing, message::AbstractString = "")
    _validate_backend_policy(backend; context = "ModelFitState")
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
    calibration::Union{Nothing, TimeSeriesCalibrationInput}
end

function TimeSeriesMMM(
        config::ModelConfig,
        sampler_config::SamplerConfig,
        data::MMMData;
        calibration_steps::Vector{CalibrationStepConfig} = CalibrationStepConfig[],
        lift_test_data::Union{Nothing, LiftTestCalibrationRows} = nothing,
        cost_per_target_data::Union{Nothing, CostPerTargetCalibrationRows} = nothing,
    )
    _validate_model_data_alignment(config, data)
    _validate_hsgp_media_training_data(config, data)
    calibration = _resolve_time_series_calibration_input(
        config,
        calibration_steps,
        lift_test_data,
        cost_per_target_data,
    )
    _reject_hsgp_media_calibration(config, calibration)
    _reject_unsupported_time_series_calibration(config, calibration)
    return TimeSeriesMMM(config, sampler_config, data, nothing, nothing, calibration)
end

function _reject_hsgp_media_calibration(
        config::ModelConfig,
        calibration::Union{Nothing, TimeSeriesCalibrationInput},
    )
    isnothing(_time_varying_media_config(config)) && return nothing
    isnothing(calibration) || throw(
        ArgumentError("time_varying_media does not support calibration"),
    )
    return nothing
end

function _validate_hsgp_media_saturation(config::ModelConfig)
    isnothing(_time_varying_media_config(config)) && return nothing
    _transform_type(config.saturation, :saturation) !== :michaelis_menten || throw(
        ArgumentError("time_varying_media does not support michaelis_menten saturation"),
    )
    return nothing
end

function _resolve_time_series_calibration_input(
        config::ModelConfig,
        calibration_steps::Vector{CalibrationStepConfig},
        lift_test_data::Union{Nothing, LiftTestCalibrationRows},
        cost_per_target_data::Union{Nothing, CostPerTargetCalibrationRows},
    )
    parsed_calibration = _calibration_input_from_config(config)
    has_constructor_calibration = !isempty(calibration_steps) ||
        !isnothing(lift_test_data) ||
        !isnothing(cost_per_target_data)

    if !isnothing(parsed_calibration) && has_constructor_calibration
        throw(
            ArgumentError(
                "calibration supplied both in ModelConfig.extras and TimeSeriesMMM constructor keywords",
            ),
        )
    end

    !isnothing(parsed_calibration) && return parsed_calibration
    return _build_calibration_input(calibration_steps, lift_test_data, cost_per_target_data)
end

function _calibration_input_from_config(config::ModelConfig)
    haskey(config.extras, "calibration") || return nothing
    calibration = config.extras["calibration"]
    isnothing(calibration) && return nothing
    calibration isa TimeSeriesCalibrationInput ||
        throw(ArgumentError("ModelConfig.extras[\"calibration\"] must be a TimeSeriesCalibrationInput"))
    _validate_time_series_calibration_input(calibration)
    return calibration
end

function _reject_unsupported_time_series_calibration(
        config::ModelConfig,
        calibration::Union{Nothing, TimeSeriesCalibrationInput},
    )
    isnothing(calibration) && return nothing
    isnothing(calibration.lift_test) && return nothing
    _transform_type(config.saturation, :saturation) === :logistic ||
        throw(
        ArgumentError(
            "lift-test calibration is only supported for `logistic` saturation in the current model path",
        ),
    )
    return nothing
end

function _reject_panel_calibration_config(config::ModelConfig)
    isnothing(_calibration_input_from_config(config)) ||
        throw(ArgumentError("PanelMMM does not support calibration from ModelConfig.extras"))
    return nothing
end


"""
    PanelMMM(config, sampler_config, data)

Container for the bounded panel MMM path, with a shared time axis and one or
more declared panel dimensions represented internally by a flattened panel-cell
axis.
"""
mutable struct PanelMMM <: AbstractMMMModel
    config::ModelConfig
    sampler_config::SamplerConfig
    data::PanelMMMData
    built_model::Union{Nothing, MMMModelSpec}
    fit_state::Union{Nothing, ModelFitState}
end

function PanelMMM(config::ModelConfig, sampler_config::SamplerConfig, data::PanelMMMData)
    isnothing(_time_varying_media_config(config)) ||
        throw(ArgumentError("time_varying_media is supported only for TimeSeriesMMM"))
    _validate_model_data_alignment(config, data)
    _reject_panel_calibration_config(config)
    return PanelMMM(config, sampler_config, data, nothing, nothing)
end

"""
    build_model(model)

Resolve one typed MMM object into a backend-agnostic model specification that
the later Turing model layer can consume.
"""
function build_model(model::TimeSeriesMMM)
    _validate_hsgp_media_saturation(model.config)
    spec = _build_model_spec(model.config, model.data)
    model.built_model = spec
    return spec
end

function build_model(model::PanelMMM)
    spec = _build_model_spec(model.config, model.data)
    model.built_model = spec
    return spec
end

function _build_model_spec(
        config::ModelConfig,
        data::MMMData;
        control_transform_state = nothing,
    )
    _validate_model_data_alignment(config, data)
    _validate_hsgp_media_saturation(config)

    channel_columns = copy(config.channel_columns)
    control_columns = copy(config.control_columns)
    channel_scale, target_scale = _compute_scales(data)
    return MMMModelSpec(
        :time_series_mmm,
        nobs(data),
        length(channel_columns),
        length(control_columns),
        config.dims,
        _coordinate_metadata(config, data),
        config.target_column,
        config.target_type,
        channel_columns,
        control_columns,
        Dict(name => index for (index, name) in enumerate(channel_columns)),
        Dict(name => index for (index, name) in enumerate(control_columns)),
        channel_scale,
        target_scale,
        copy(config.adstock),
        copy(config.saturation),
        copy(config.seasonality),
        _trend_spec_config(config.trend, data.dates),
        copy(config.events),
        _holiday_spec_config(config.holidays, data.dates),
        _controls_spec_config(
            config.controls;
            control_transform_state,
        ),
        _model_spec_priors(config, data),
    )
end

function _model_spec_priors(config::ModelConfig, data::MMMData)
    priors = copy(config.priors)
    haskey(priors, _HSGP_MEDIA_SPEC_STATE_KEY) && throw(
        ArgumentError("$(_HSGP_MEDIA_SPEC_STATE_KEY) is reserved for private model-spec state"),
    )
    time_varying_media = _time_varying_media_config(config)
    isnothing(time_varying_media) ||
        (priors[_HSGP_MEDIA_SPEC_STATE_KEY] = _hsgp_media_spec_state(time_varying_media, data))
    return priors
end

function _build_model_spec(
        spec::MMMModelSpec,
        data::MMMData;
        control_transform_state = nothing,
    )
    _validate_model_data_alignment(spec, data)

    channel_columns = copy(spec.channel_columns)
    control_columns = copy(spec.control_columns)
    return MMMModelSpec(
        spec.model_kind,
        nobs(data),
        length(channel_columns),
        length(control_columns),
        spec.dims,
        _coordinate_metadata(spec, data),
        spec.target_column,
        spec.target_type,
        channel_columns,
        control_columns,
        Dict(name => index for (index, name) in enumerate(channel_columns)),
        Dict(name => index for (index, name) in enumerate(control_columns)),
        copy(spec.channel_scale),
        _copy_scale(spec.target_scale),
        copy(spec.adstock),
        copy(spec.saturation),
        copy(spec.seasonality),
        copy(spec.trend),
        copy(spec.events),
        copy(spec.holidays),
        _controls_spec_config(
            spec.controls;
            control_transform_state,
        ),
        copy(spec.priors),
    )
end

_copy_scale(scale::Float64) = scale
_copy_scale(scale::Vector{Float64}) = copy(scale)

function _build_model_spec(config::ModelConfig, data::PanelMMMData)
    _validate_model_data_alignment(config, data)

    channel_columns = copy(config.channel_columns)
    control_columns = copy(config.control_columns)
    channel_scale, target_scale = _compute_scales(data)
    return MMMModelSpec(
        :panel_mmm,
        nobs(data),
        length(channel_columns),
        length(control_columns),
        config.dims,
        _coordinate_metadata(config, data),
        config.target_column,
        config.target_type,
        channel_columns,
        control_columns,
        Dict(name => index for (index, name) in enumerate(channel_columns)),
        Dict(name => index for (index, name) in enumerate(control_columns)),
        channel_scale,
        target_scale,
        copy(config.adstock),
        copy(config.saturation),
        copy(config.seasonality),
        copy(config.trend),
        copy(config.events),
        _holiday_spec_config(config.holidays, data.dates),
        copy(config.controls),
        copy(config.priors),
    )
end

function _build_model_spec(spec::MMMModelSpec, data::PanelMMMData)
    _validate_model_data_alignment(spec, data)

    channel_columns = copy(spec.channel_columns)
    control_columns = copy(spec.control_columns)
    return MMMModelSpec(
        spec.model_kind,
        nobs(data),
        length(channel_columns),
        length(control_columns),
        spec.dims,
        _coordinate_metadata(spec, data),
        spec.target_column,
        spec.target_type,
        channel_columns,
        control_columns,
        Dict(name => index for (index, name) in enumerate(channel_columns)),
        Dict(name => index for (index, name) in enumerate(control_columns)),
        copy(spec.channel_scale),
        _copy_scale(spec.target_scale),
        copy(spec.adstock),
        copy(spec.saturation),
        copy(spec.seasonality),
        copy(spec.trend),
        copy(spec.events),
        copy(spec.holidays),
        copy(spec.controls),
        copy(spec.priors),
    )
end

function _coordinate_metadata(config::ModelConfig, data::MMMData)
    observation_dim = "observation"
    coordinates = Dict{String, Vector{String}}(
        observation_dim => string.(collect(1:nobs(data))),
        "channel" => copy(config.channel_columns),
    )
    named_dims = Dict{String, Tuple{Vararg{String}}}(
        "target" => (observation_dim,),
        "channels" => (observation_dim, "channel"),
        "intercept" => (),
        "beta_media" => ("channel",),
    )

    if !isempty(config.control_columns)
        coordinates["control"] = copy(config.control_columns)
        named_dims["controls"] = (observation_dim, "control")
        named_dims["beta_controls"] = ("control",)
    end

    event_columns = _events_columns(config.events)
    if !isempty(event_columns)
        coordinates["event"] = event_columns
        named_dims["events"] = (observation_dim, "event")
        named_dims["beta_events"] = ("event",)
    end

    holiday_columns = _holidays_columns(config.holidays)
    if !isempty(holiday_columns)
        coordinates["holiday"] = holiday_columns
        named_dims["holidays"] = (observation_dim, "holiday")
        named_dims["beta_holidays"] = ("holiday",)
    end

    if _seasonality_type(config.seasonality) === :fourier
        n_order = Int(config.seasonality["n_order"])
        coordinates["fourier_mode"] = _fourier_mode_names(n_order)
        named_dims["seasonality_features"] = (observation_dim, "fourier_mode")
        named_dims["beta_seasonality"] = ("fourier_mode",)
    end

    trend_type = _trend_type(config.trend)
    if trend_type === :linear || trend_type === :changepoint
        coordinates["trend_term"] = _trend_term_names(config.trend)
        named_dims["trend_features"] = (observation_dim, "trend_term")
        if trend_type === :linear
            named_dims["beta_trend"] = ("trend_term",)
        else
            named_dims["delta_trend"] = ("trend_term",)
        end
    end

    return ModelCoordinateMetadata(
        observation_dim,
        config.dims,
        coordinates,
        named_dims,
    )
end

function _coordinate_metadata(spec::MMMModelSpec, data::MMMData)
    observation_dim = "observation"
    coordinates = Dict{String, Vector{String}}(
        observation_dim => string.(collect(1:nobs(data))),
        "channel" => copy(spec.channel_columns),
    )
    named_dims = Dict{String, Tuple{Vararg{String}}}(
        "target" => (observation_dim,),
        "channels" => (observation_dim, "channel"),
        "intercept" => (),
        "beta_media" => ("channel",),
    )

    if !isempty(spec.control_columns)
        coordinates["control"] = copy(spec.control_columns)
        named_dims["controls"] = (observation_dim, "control")
        named_dims["beta_controls"] = ("control",)
    end

    event_columns = _events_columns(spec.events)
    if !isempty(event_columns)
        coordinates["event"] = event_columns
        named_dims["events"] = (observation_dim, "event")
        named_dims["beta_events"] = ("event",)
    end

    holiday_columns = _holidays_columns(spec.holidays)
    if !isempty(holiday_columns)
        coordinates["holiday"] = holiday_columns
        named_dims["holidays"] = (observation_dim, "holiday")
        named_dims["beta_holidays"] = ("holiday",)
    end

    if _seasonality_type(spec.seasonality) === :fourier
        n_order = Int(spec.seasonality["n_order"])
        coordinates["fourier_mode"] = _fourier_mode_names(n_order)
        named_dims["seasonality_features"] = (observation_dim, "fourier_mode")
        named_dims["beta_seasonality"] = ("fourier_mode",)
    end

    trend_type = _trend_type(spec.trend)
    if trend_type === :linear || trend_type === :changepoint
        coordinates["trend_term"] = _trend_term_names(spec.trend)
        named_dims["trend_features"] = (observation_dim, "trend_term")
        if trend_type === :linear
            named_dims["beta_trend"] = ("trend_term",)
        else
            named_dims["delta_trend"] = ("trend_term",)
        end
    end

    return ModelCoordinateMetadata(
        observation_dim,
        spec.dims,
        coordinates,
        named_dims,
    )
end

function _coordinate_metadata(config::ModelConfig, data::PanelMMMData)
    observation_dim = "time"
    panel_dim = _flat_panel_dim_name(config)
    coordinates = Dict{String, Vector{String}}(
        observation_dim => string.(collect(1:ntime(data))),
        "panel_cell" => copy(data.panel_names),
        panel_dim => copy(data.panel_names),
        "channel" => copy(config.channel_columns),
    )
    _add_panel_coordinates!(coordinates, config.dims, data)
    named_dims = Dict{String, Tuple{Vararg{String}}}(
        "target" => (observation_dim, panel_dim),
        "channels" => (observation_dim, "channel", panel_dim),
        "intercept" => _prior_dims(config.priors, "intercept", ()),
        "sigma" => _sigma_prior_dims(config.priors, ()),
        "beta_media" => _prior_dims(config.priors, "beta_media", ("channel",)),
        "panel_intercept_offset" => (panel_dim,),
    )
    _add_panel_transform_prior_dims!(named_dims, config.adstock, "alpha", ("channel",))
    _add_panel_transform_prior_dims!(named_dims, config.adstock, "theta", ("channel",))
    _add_panel_transform_prior_dims!(named_dims, config.adstock, "lam_adstock", "lam", ("channel",))
    _add_panel_transform_prior_dims!(named_dims, config.adstock, "k_adstock", "k", ("channel",))
    _add_panel_transform_prior_dims!(named_dims, config.saturation, "lam", ("channel",))
    _add_panel_transform_prior_dims!(named_dims, config.saturation, "alpha_saturation", "alpha", ("channel",))
    _add_panel_transform_prior_dims!(named_dims, config.saturation, "b", ("channel",))
    _add_panel_transform_prior_dims!(named_dims, config.saturation, "c", ("channel",))
    _add_panel_transform_prior_dims!(named_dims, config.saturation, "slope", ("channel",))
    _add_panel_transform_prior_dims!(named_dims, config.saturation, "kappa", ("channel",))

    if _seasonality_type(config.seasonality) === :fourier
        n_order = Int(config.seasonality["n_order"])
        coordinates["fourier_mode"] = _fourier_mode_names(n_order)
        named_dims["seasonality_features"] = (observation_dim, "fourier_mode")
        named_dims["beta_seasonality"] = _prior_dims(
            _mapping_value(config.seasonality, "priors"),
            "beta",
            (config.dims..., "fourier_mode"),
        )
    end

    holiday_columns = _holidays_columns(config.holidays)
    if !isempty(holiday_columns)
        coordinates["holiday"] = holiday_columns
        named_dims["holidays"] = (observation_dim, "holiday", panel_dim)
        named_dims["beta_holidays"] = _prior_dims(
            _mapping_value(config.holidays, "priors"),
            "beta",
            ("holiday",),
        )
    end

    return ModelCoordinateMetadata(
        observation_dim,
        config.dims,
        coordinates,
        named_dims,
    )
end

function _coordinate_metadata(spec::MMMModelSpec, data::PanelMMMData)
    observation_dim = "time"
    panel_dim = _flat_panel_dim_name(spec)
    coordinates = Dict{String, Vector{String}}(
        observation_dim => string.(collect(1:ntime(data))),
        "panel_cell" => copy(data.panel_names),
        panel_dim => copy(data.panel_names),
        "channel" => copy(spec.channel_columns),
    )
    _add_panel_coordinates!(coordinates, spec.dims, data)
    named_dims = Dict{String, Tuple{Vararg{String}}}(
        "target" => (observation_dim, panel_dim),
        "channels" => (observation_dim, "channel", panel_dim),
        "intercept" => _prior_dims(spec.priors, "intercept", ()),
        "sigma" => _sigma_prior_dims(spec.priors, ()),
        "beta_media" => _prior_dims(spec.priors, "beta_media", ("channel",)),
        "panel_intercept_offset" => (panel_dim,),
    )
    _add_panel_transform_prior_dims!(named_dims, spec.adstock, "alpha", ("channel",))
    _add_panel_transform_prior_dims!(named_dims, spec.adstock, "theta", ("channel",))
    _add_panel_transform_prior_dims!(named_dims, spec.adstock, "lam_adstock", "lam", ("channel",))
    _add_panel_transform_prior_dims!(named_dims, spec.adstock, "k_adstock", "k", ("channel",))
    _add_panel_transform_prior_dims!(named_dims, spec.saturation, "lam", ("channel",))
    _add_panel_transform_prior_dims!(named_dims, spec.saturation, "alpha_saturation", "alpha", ("channel",))
    _add_panel_transform_prior_dims!(named_dims, spec.saturation, "b", ("channel",))
    _add_panel_transform_prior_dims!(named_dims, spec.saturation, "c", ("channel",))
    _add_panel_transform_prior_dims!(named_dims, spec.saturation, "slope", ("channel",))
    _add_panel_transform_prior_dims!(named_dims, spec.saturation, "kappa", ("channel",))

    if _seasonality_type(spec.seasonality) === :fourier
        n_order = Int(spec.seasonality["n_order"])
        coordinates["fourier_mode"] = _fourier_mode_names(n_order)
        named_dims["seasonality_features"] = (observation_dim, "fourier_mode")
        named_dims["beta_seasonality"] = _prior_dims(
            _mapping_value(spec.seasonality, "priors"),
            "beta",
            (spec.dims..., "fourier_mode"),
        )
    end

    holiday_columns = _holidays_columns(spec.holidays)
    if !isempty(holiday_columns)
        coordinates["holiday"] = holiday_columns
        named_dims["holidays"] = (observation_dim, "holiday", panel_dim)
        named_dims["beta_holidays"] = _prior_dims(
            _mapping_value(spec.holidays, "priors"),
            "beta",
            ("holiday",),
        )
    end

    return ModelCoordinateMetadata(
        observation_dim,
        spec.dims,
        coordinates,
        named_dims,
    )
end

function _prior_dims(priors::Dict{String, Any}, key::AbstractString, default)
    prior = get(priors, key, nothing)
    prior isa EpsilonPrior && !isnothing(prior.dims) && return prior.dims
    return default
end

function _sigma_prior_dims(priors::Dict{String, Any}, default)
    sigma_prior = get(priors, "sigma", nothing)
    sigma_prior isa EpsilonPrior && !isnothing(sigma_prior.dims) && return sigma_prior.dims

    likelihood_prior = get(priors, "likelihood", nothing)
    if likelihood_prior isa EpsilonPrior
        nested_sigma = get(likelihood_prior.parameters, :sigma, nothing)
        nested_sigma isa EpsilonPrior && !isnothing(nested_sigma.dims) && return nested_sigma.dims
    end
    return default
end

function _add_panel_transform_prior_dims!(
        named_dims::Dict{String, Tuple{Vararg{String}}},
        transform_config::Dict{String, Any},
        parameter_name::AbstractString,
        default,
    )
    return _add_panel_transform_prior_dims!(
        named_dims,
        transform_config,
        parameter_name,
        parameter_name,
        default,
    )
end

function _add_panel_transform_prior_dims!(
        named_dims::Dict{String, Tuple{Vararg{String}}},
        transform_config::Dict{String, Any},
        output_name::AbstractString,
        prior_name::AbstractString,
        default,
    )
    priors = get(transform_config, "priors", nothing)
    priors isa AbstractDict || return named_dims
    haskey(priors, prior_name) || return named_dims
    prior = priors[prior_name]
    named_dims[output_name] = prior isa EpsilonPrior && !isnothing(prior.dims) ? prior.dims : default
    return named_dims
end

function fit!(model::TimeSeriesMMM)
    _validate_hsgp_media_saturation(model.config)
    _reject_hsgp_media_calibration(model.config, model.calibration)
    return _fit_time_series_mmm!(model)
end

function fit!(model::PanelMMM)
    return _fit_panel_mmm!(model)
end

"""
    predict(model, new_data=model.data)

Generate posterior predictive samples from the latest successful fitted MMM
artifact.
"""
function predict(model::TimeSeriesMMM, new_data::MMMData = model.data)
    return _predict_time_series_mmm(model, new_data)
end

function predict(model::PanelMMM, new_data::PanelMMMData = model.data)
    return _predict_panel_mmm(model, new_data)
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

    event_columns = _events_columns(config.events)
    generated_events = !isempty(_events_windows(config.events))
    if isnothing(data.events)
        isempty(event_columns) || generated_events ||
            throw(ArgumentError("config.events.columns require events in MMMData"))
    elseif generated_events
        throw(
            ArgumentError(
                "config.events.windows generate the event design matrix; MMMData.events must be omitted",
            ),
        )
    else
        event_columns == data.event_names ||
            throw(ArgumentError("config.events.columns must match data.event_names in order"))
    end

    if generated_events
        isempty(data.event_names) ||
            throw(
            ArgumentError(
                "config.events.windows generate event names from config; MMMData.event_names must be empty",
            ),
        )
    else
        isnothing(data.events) || isempty(event_columns) || event_columns == data.event_names ||
            throw(ArgumentError("config.events.columns must match data.event_names in order"))
    end

    return nothing
end

function _validate_model_data_alignment(spec::MMMModelSpec, data::MMMData)
    spec.channel_columns == data.channel_names ||
        throw(ArgumentError("fitted channel columns must match MMMData.channel_names in order"))

    if isnothing(data.controls)
        isempty(spec.control_columns) ||
            throw(ArgumentError("fitted control columns require controls in MMMData"))
    else
        spec.control_columns == data.control_names ||
            throw(ArgumentError("fitted control columns must match MMMData.control_names in order"))
    end

    event_columns = _events_columns(spec.events)
    generated_events = !isempty(_events_windows(spec.events))
    if isnothing(data.events)
        isempty(event_columns) || generated_events ||
            throw(ArgumentError("fitted events.columns require events in MMMData"))
    elseif generated_events
        throw(
            ArgumentError(
                "fitted events.windows generate the event design matrix; MMMData.events must be omitted",
            ),
        )
    else
        event_columns == data.event_names ||
            throw(ArgumentError("fitted events.columns must match MMMData.event_names in order"))
    end

    if generated_events
        isempty(data.event_names) ||
            throw(
            ArgumentError(
                "fitted events.windows generate event names from the stored fit spec; MMMData.event_names must be empty",
            ),
        )
    else
        isnothing(data.events) || isempty(event_columns) || event_columns == data.event_names ||
            throw(ArgumentError("fitted events.columns must match MMMData.event_names in order"))
    end

    return nothing
end

function _validate_model_data_alignment(config::ModelConfig, data::PanelMMMData)
    !isempty(config.dims) ||
        throw(ArgumentError("PanelMMM requires at least one dimensions.panel entry"))
    _validate_panel_coordinate_alignment(config.dims, data)
    config.channel_columns == data.channel_names ||
        throw(ArgumentError("config.channel_columns must match data.channel_names in order"))
    isempty(config.control_columns) ||
        throw(ArgumentError("PanelMMM does not yet support media.controls"))
    isempty(config.controls) ||
        throw(ArgumentError("PanelMMM does not yet support a controls block"))
    _seasonality_type(config.seasonality) in (:none, :fourier) ||
        throw(ArgumentError("PanelMMM supports only `fourier` seasonality"))
    _trend_type(config.trend) === :none ||
        throw(ArgumentError("PanelMMM does not yet support trend"))
    isempty(_events_columns(config.events)) && isempty(_events_windows(config.events)) ||
        throw(ArgumentError("PanelMMM does not yet support events"))
    _holidays_mode(config.holidays) in (:none, :auto) ||
        throw(ArgumentError("PanelMMM supports only automatic pooled holidays"))
    return nothing
end

function _validate_model_data_alignment(spec::MMMModelSpec, data::PanelMMMData)
    !isempty(spec.dims) ||
        throw(ArgumentError("PanelMMM requires at least one stored panel dimension"))
    _validate_panel_coordinate_alignment(spec.dims, data)
    spec.channel_columns == data.channel_names ||
        throw(ArgumentError("fitted channel columns must match PanelMMMData.channel_names in order"))
    isempty(spec.control_columns) ||
        throw(ArgumentError("PanelMMM does not yet support media.controls"))
    isempty(spec.controls) ||
        throw(ArgumentError("PanelMMM does not yet support a controls block"))
    _seasonality_type(spec.seasonality) in (:none, :fourier) ||
        throw(ArgumentError("PanelMMM supports only `fourier` seasonality"))
    _trend_type(spec.trend) === :none ||
        throw(ArgumentError("PanelMMM does not yet support trend"))
    isempty(_events_columns(spec.events)) && isempty(_events_windows(spec.events)) ||
        throw(ArgumentError("PanelMMM does not yet support events"))
    _holidays_mode(spec.holidays) in (:none, :auto) ||
        throw(ArgumentError("PanelMMM supports only automatic pooled holidays"))
    return nothing
end

_panel_dim_names(config::ModelConfig) = config.dims
_panel_dim_names(spec::MMMModelSpec) = spec.dims
_flat_panel_dim_name(config::ModelConfig) = length(config.dims) == 1 ? only(config.dims) : "panel"
_flat_panel_dim_name(spec::MMMModelSpec) = length(spec.dims) == 1 ? only(spec.dims) : "panel"

function _add_panel_coordinates!(
        coordinates::Dict{String, Vector{String}},
        panel_dims::Tuple{Vararg{String}},
        data::PanelMMMData,
    )
    for dim in panel_dims
        values = get(data.panel_coordinates, dim, nothing)
        if isnothing(values)
            length(panel_dims) == 1 && continue
            throw(ArgumentError("PanelMMMData.panel_coordinates must include `$dim` for multidimensional panel configs"))
        end
        coordinates[dim] = _unique_in_order(values)
    end
    return coordinates
end

function _unique_in_order(values::AbstractVector{<:AbstractString})
    seen = Set{String}()
    ordered = String[]
    for value in values
        string_value = String(value)
        string_value in seen && continue
        push!(seen, string_value)
        push!(ordered, string_value)
    end
    return ordered
end

function _validate_panel_coordinate_alignment(
        panel_dims::Tuple{Vararg{String}},
        data::PanelMMMData,
    )
    length(panel_dims) == 1 && !haskey(data.panel_coordinates, only(panel_dims)) && return nothing
    for dim in panel_dims
        haskey(data.panel_coordinates, dim) ||
            throw(ArgumentError("PanelMMMData.panel_coordinates must include `$dim`"))
    end
    return nothing
end
