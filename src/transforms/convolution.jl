"""
    ConvMode

Boundary handling modes for [`batched_convolution`](@ref).
"""
@enum ConvMode After Before Overlap

@doc "Trailing carryover mode for [`batched_convolution`](@ref)." After
@doc "Leading carryover mode for [`batched_convolution`](@ref)." Before
@doc "Parity-preserving overlap mode for [`batched_convolution`](@ref)." Overlap

"""
    batched_convolution(x, w, axis=1, mode=After)

Apply a 1D convolution across `axis` while broadcasting any leading batch
dimensions in `w` against the non-convolved dimensions of `x`.

`mode` controls boundary handling:

- `After`: trailing carryover
- `Before`: leading carryover
- `Overlap`: parity-preserving overlap orientation. With source index
  `t + ((lag_length - 1) ÷ 2) - lag + 1`, an impulse at index 3 with weights
  `[10, 20, 30]` returns `[0, 10, 20, 30, 0]`; with weights
  `[10, 20, 30, 40]` it returns `[0, 10, 20, 30, 40]`. The even-length case
  preserves Epsilon's reference-locked orientation, not the opposite
  half-sample shift.
"""
function batched_convolution(
        x::AbstractArray,
        w::AbstractArray,
        axis::Integer = 1,
        mode::Union{ConvMode, AbstractString, Symbol} = After,
    )
    parsed_mode = _parse_conv_mode(mode)
    normalized_axis = _normalize_axis(axis, ndims(x))
    x_moved = _move_axis_to_last(x, normalized_axis)

    x_batch_shape = Base.front(size(x_moved))
    w_batch_shape = Base.front(size(w))
    out_batch_shape = _broadcast_batch_shape(x_batch_shape, w_batch_shape)

    time_length = size(x_moved, ndims(x_moved))
    lag_length = size(w, ndims(w))
    out_type = promote_type(eltype(x), eltype(w))
    result = Array{out_type}(undef, out_batch_shape..., time_length)

    for out_index in CartesianIndices(out_batch_shape)
        x_index = _broadcast_batch_index(x_batch_shape, out_index, length(out_batch_shape))
        w_index = _broadcast_batch_index(w_batch_shape, out_index, length(out_batch_shape))
        x_slice = @view x_moved[x_index..., :]
        w_slice = @view w[w_index..., :]
        y_slice = @view result[out_index, :]

        for t in eachindex(y_slice)
            acc = zero(out_type)
            for lag in eachindex(w_slice)
                x_t = _source_index(t, lag, lag_length, parsed_mode)
                if 1 <= x_t <= time_length
                    acc += w_slice[lag] * x_slice[x_t]
                end
            end
            y_slice[t] = acc
        end
    end

    target_axis = normalized_axis + ndims(result) - ndims(x)
    return _move_last_axis_to(result, target_axis)
end

function _parse_conv_mode(mode::ConvMode)
    return mode
end

function _parse_conv_mode(mode::Symbol)
    return _parse_conv_mode(String(mode))
end

function _parse_conv_mode(mode::AbstractString)
    normalized = lowercase(mode)
    normalized == "after" && return After
    normalized == "before" && return Before
    normalized == "overlap" && return Overlap
    throw(ArgumentError("invalid convolution mode `$mode`"))
end

function _normalize_axis(axis::Integer, rank::Integer)
    axis == 0 && throw(ArgumentError("axis must not be zero"))
    normalized = axis < 0 ? axis + rank + 1 : axis
    1 <= normalized <= rank || throw(ArgumentError("axis $axis out of bounds for rank $rank"))
    return normalized
end

function _broadcast_batch_shape(left::Tuple, right::Tuple)
    ndim = max(length(left), length(right))
    shape = Vector{Int}(undef, ndim)

    for i in 1:ndim
        left_dim = i <= ndim - length(left) ? 1 : left[i - (ndim - length(left))]
        right_dim = i <= ndim - length(right) ? 1 : right[i - (ndim - length(right))]

        if left_dim == right_dim || left_dim == 1 || right_dim == 1
            shape[i] = max(left_dim, right_dim)
        else
            throw(DimensionMismatch("cannot broadcast batch shapes $left and $right"))
        end
    end

    return Tuple(shape)
end

function _broadcast_batch_index(batch_shape::Tuple, out_index::CartesianIndex, out_ndims::Integer)
    offset = out_ndims - length(batch_shape)
    return ntuple(length(batch_shape)) do i
        batch_shape[i] == 1 ? 1 : out_index[offset + i]
    end
end

function _source_index(
        t::Integer,
        lag::Integer,
        lag_length::Integer,
        mode::ConvMode,
    )
    if mode === After
        return t - lag + 1
    elseif mode === Before
        return t + lag_length - lag
    else
        # PyTensor's convolve1d orientation makes Abacus's lags ÷ 2 left
        # padding equivalent to this source-index shift for even kernels.
        return t + ((lag_length - 1) ÷ 2) - lag + 1
    end
end

function _move_axis_to_last(array::AbstractArray, axis::Integer)
    ndims(array) == 1 && return array
    axis == ndims(array) && return array
    order = collect(1:ndims(array))
    push!(order, splice!(order, axis))
    return PermutedDimsArray(array, Tuple(order))
end

function _move_last_axis_to(array::AbstractArray, axis::Integer)
    ndims(array) == 1 && return array
    axis == ndims(array) && return array
    order = collect(1:(ndims(array) - 1))
    insert!(order, axis, ndims(array))
    return PermutedDimsArray(array, Tuple(order))
end
