using Dates

function _infer_hsgp_time_index(
        new_dates::AbstractVector{<:Date},
        training_dates::AbstractVector{<:Date};
        time_resolution::Integer,
    )::Vector{Int}
    isempty(training_dates) && throw(ArgumentError("training_dates must not be empty"))
    time_resolution > 0 || throw(ArgumentError("time_resolution must be a positive integer"))
    isempty(new_dates) && return Int[]

    origin = first(training_dates)
    time_index = Vector{Int}(undef, length(new_dates))
    for (index, new_date) in pairs(new_dates)
        day_offset = Dates.value(new_date - origin)
        rem(day_offset, time_resolution) == 0 || throw(
            ArgumentError("new_dates must align to the fitted cadence"),
        )
        time_index[index] = div(day_offset, time_resolution)
    end

    return time_index
end
