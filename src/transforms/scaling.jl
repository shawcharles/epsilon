"""
    MaxAbsScaler()

Scale each feature by its maximum absolute value.
"""
mutable struct MaxAbsScaler
    scale::Vector{Float64}
    fitted::Bool
    fitted_ndims::Int
    fitted_nfeatures::Int
end

MaxAbsScaler() = MaxAbsScaler(Float64[], false, 0, 0)

"""
    StandardScaler()

Standardize each feature to zero mean and unit variance.
"""
mutable struct StandardScaler
    mean::Vector{Float64}
    scale::Vector{Float64}
    fitted::Bool
    fitted_ndims::Int
    fitted_nfeatures::Int
end

StandardScaler() = StandardScaler(Float64[], Float64[], false, 0, 0)

"""
    MaxAbsScaleTarget()

Wrapper that stores the fitted target scaler.
"""
mutable struct MaxAbsScaleTarget
    target_transformer::MaxAbsScaler
end

MaxAbsScaleTarget() = MaxAbsScaleTarget(MaxAbsScaler())

"""
    MaxAbsScaleChannels(channel_columns)

Wrapper that stores the fitted channel scaler for selected columns.
"""
mutable struct MaxAbsScaleChannels
    channel_columns::Vector{Int}
    channel_transformer::MaxAbsScaler
end

MaxAbsScaleChannels(channel_columns) = MaxAbsScaleChannels(
    _normalize_column_indices(channel_columns, "channel_columns"),
    MaxAbsScaler(),
)

"""
    StandardizeControls(control_columns)

Wrapper that stores the fitted control scaler for selected columns.
"""
mutable struct StandardizeControls
    control_columns::Vector{Int}
    control_transformer::StandardScaler
end

StandardizeControls(control_columns) = StandardizeControls(
    _normalize_column_indices(control_columns, "control_columns"),
    StandardScaler(),
)

function fit!(scaler::MaxAbsScaler, data::AbstractVector)
    values = abs.(Float64.(data))
    _validate_nonempty(values, "data")
    scale = maximum(values)
    scaler.scale = [scale == 0 ? 1.0 : scale]
    scaler.fitted = true
    scaler.fitted_ndims = 1
    scaler.fitted_nfeatures = 1
    return scaler
end

function fit!(scaler::MaxAbsScaler, data::AbstractMatrix)
    _validate_nonempty(data, "data")
    scale = vec(maximum(abs.(Float64.(data)); dims = 1))
    scaler.scale = map(value -> value == 0 ? 1.0 : value, scale)
    scaler.fitted = true
    scaler.fitted_ndims = 2
    scaler.fitted_nfeatures = size(data, 2)
    return scaler
end

function fit!(scaler::StandardScaler, data::AbstractVector)
    values = Float64.(data)
    _validate_nonempty(values, "data")
    mu = sum(values) / length(values)
    scaler.mean = [mu]
    sigma = sqrt(sum((values .- mu) .^ 2) / length(values))
    scaler.scale = [sigma == 0 ? 1.0 : sigma]
    scaler.fitted = true
    scaler.fitted_ndims = 1
    scaler.fitted_nfeatures = 1
    return scaler
end

function fit!(scaler::StandardScaler, data::AbstractMatrix)
    values = Float64.(data)
    _validate_nonempty(values, "data")
    scaler.mean = vec(sum(values; dims = 1) ./ size(values, 1))
    centered = values .- reshape(scaler.mean, 1, :)
    sigma = vec(sqrt.(sum(centered .^ 2; dims = 1) ./ size(values, 1)))
    scaler.scale = map(value -> value == 0 ? 1.0 : value, sigma)
    scaler.fitted = true
    scaler.fitted_ndims = 2
    scaler.fitted_nfeatures = size(data, 2)
    return scaler
end

"""
    transform(scaler, data)

Apply a fitted scaler to vector or matrix data.
"""
function transform(scaler::MaxAbsScaler, data::AbstractVector)
    _require_fitted(scaler)
    _validate_scaler_shape(scaler, data)
    return Float64.(data) ./ scaler.scale[1]
end

function transform(scaler::MaxAbsScaler, data::AbstractMatrix)
    _require_fitted(scaler)
    _validate_scaler_shape(scaler, data)
    return Float64.(data) ./ reshape(scaler.scale, 1, :)
end

function transform(scaler::StandardScaler, data::AbstractVector)
    _require_fitted(scaler)
    _validate_scaler_shape(scaler, data)
    return (Float64.(data) .- scaler.mean[1]) ./ scaler.scale[1]
end

function transform(scaler::StandardScaler, data::AbstractMatrix)
    _require_fitted(scaler)
    _validate_scaler_shape(scaler, data)
    return (Float64.(data) .- reshape(scaler.mean, 1, :)) ./ reshape(scaler.scale, 1, :)
end

"""
    inverse_transform(scaler, data)

Undo a fitted scaling transform.
"""
function inverse_transform(scaler::MaxAbsScaler, data::AbstractVector)
    _require_fitted(scaler)
    _validate_scaler_shape(scaler, data)
    return Float64.(data) .* scaler.scale[1]
end

function inverse_transform(scaler::MaxAbsScaler, data::AbstractMatrix)
    _require_fitted(scaler)
    _validate_scaler_shape(scaler, data)
    return Float64.(data) .* reshape(scaler.scale, 1, :)
end

function inverse_transform(scaler::StandardScaler, data::AbstractVector)
    _require_fitted(scaler)
    _validate_scaler_shape(scaler, data)
    return Float64.(data) .* scaler.scale[1] .+ scaler.mean[1]
end

function inverse_transform(scaler::StandardScaler, data::AbstractMatrix)
    _require_fitted(scaler)
    _validate_scaler_shape(scaler, data)
    return Float64.(data) .* reshape(scaler.scale, 1, :) .+ reshape(scaler.mean, 1, :)
end

"""
    fit_transform!(scaler, data)

Fit a scaler and immediately transform the same data.
"""
function fit_transform!(scaler::Union{MaxAbsScaler, StandardScaler}, data)
    fit!(scaler, data)
    return transform(scaler, data)
end

"""
    max_abs_scale_target_data(wrapper, data)

Fit and apply max-absolute scaling to target data.
"""
function max_abs_scale_target_data(wrapper::MaxAbsScaleTarget, data::AbstractVector)
    return fit_transform!(wrapper.target_transformer, data)
end

"""
    max_abs_scale_channel_data(wrapper, data)

Fit and apply max-absolute scaling to selected channel columns.
"""
function max_abs_scale_channel_data(wrapper::MaxAbsScaleChannels, data::AbstractMatrix)
    validate_column_indices(size(data, 2), wrapper.channel_columns, "channel_columns")
    validate_channel_values(data, wrapper.channel_columns)
    output = Float64.(copy(data))
    channel_data = output[:, wrapper.channel_columns]
    fit!(wrapper.channel_transformer, channel_data)
    output[:, wrapper.channel_columns] = transform(wrapper.channel_transformer, channel_data)
    return output
end

"""
    standardize_control_data(wrapper, data)

Fit and apply standardization to selected control columns.
"""
function standardize_control_data(wrapper::StandardizeControls, data::AbstractMatrix)
    validate_column_indices(size(data, 2), wrapper.control_columns, "control_columns")
    output = Float64.(copy(data))
    control_data = output[:, wrapper.control_columns]
    fit!(wrapper.control_transformer, control_data)
    output[:, wrapper.control_columns] = transform(wrapper.control_transformer, control_data)
    return output
end

"""
    normalize_channel_columns(data, channel_columns)

Return channel-scaled data and the fitted `MaxAbsScaleChannels` wrapper.
"""
function normalize_channel_columns(data::AbstractMatrix, channel_columns)
    wrapper = MaxAbsScaleChannels(channel_columns)
    return max_abs_scale_channel_data(wrapper, data), wrapper
end

"""
    validate_target_data(data)

Require target data to have at least one element.
"""
function validate_target_data(data::AbstractVector)
    _validate_nonempty(data, "y")
    return nothing
end

"""
    validate_column_indices(ncols, columns, name)

Validate a column-selection vector for matrix data.
"""
function validate_column_indices(ncols::Integer, columns, name::AbstractString)
    column_list = _normalize_column_indices(columns, name)
    isempty(column_list) && throw(ArgumentError("$name must not be empty"))
    length(unique(column_list)) == length(column_list) ||
        throw(ArgumentError("$name contains duplicates"))
    all(1 .<= column_list .<= ncols) ||
        throw(ArgumentError("$name must reference columns within 1:$ncols"))
    return nothing
end

"""
    validate_channel_values(data, channel_columns)

Warn when selected channel columns contain negative values.
"""
function validate_channel_values(data::AbstractMatrix, channel_columns)
    validate_column_indices(size(data, 2), channel_columns, "channel_columns")
    if any(data[:, channel_columns] .< 0)
        @warn "channel_columns contain negative values"
    end
    return nothing
end

function _require_fitted(scaler)
    scaler.fitted || throw(ArgumentError("scaler has not been fitted"))
    return nothing
end

function _validate_scaler_shape(scaler, data::AbstractVector)
    scaler.fitted_ndims == 1 ||
        throw(
            ArgumentError(
                "scaler was fitted on matrix data and cannot be applied to vector data",
            ),
        )
    return nothing
end

function _validate_scaler_shape(scaler, data::AbstractMatrix)
    scaler.fitted_ndims == 2 ||
        throw(
            ArgumentError(
                "scaler was fitted on vector data and cannot be applied to matrix data",
            ),
        )
    size(data, 2) == scaler.fitted_nfeatures ||
        throw(
            ArgumentError(
                "matrix data must have $(scaler.fitted_nfeatures) feature columns to match the fitted scaler",
            ),
        )
    return nothing
end

function _validate_nonempty(data, name::AbstractString)
    length(data) > 0 || throw(ArgumentError("$name must have at least one element"))
    return nothing
end

function _normalize_column_indices(columns, name::AbstractString)
    column_list = collect(columns)
    all(column -> column isa Integer, column_list) ||
        throw(ArgumentError("$name must contain only integer indices"))
    return Int.(column_list)
end
