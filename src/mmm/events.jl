function _event_date(value, key::AbstractString)
    if value isa Dates.Date
        return value
    elseif value isa Dates.DateTime
        return Dates.Date(value)
    elseif value isa AbstractString
        try
            return Dates.Date(String(value))
        catch
            try
                return Dates.Date(Dates.DateTime(String(value)))
            catch
                throw(ArgumentError("$key must be an ISO date or datetime string"))
            end
        end
    end

    throw(ArgumentError("$key must be a date, datetime, or ISO date string"))
end

function _events_windows(config::Dict{String, Any})
    windows = get(config, "windows", Any[])
    windows isa AbstractVector ||
        throw(ArgumentError("events.windows must be a list of mappings"))

    parsed = NamedTuple{(:name, :start_date, :end_date), Tuple{String, Dates.Date, Dates.Date}}[]
    for (index, window) in enumerate(windows)
        window isa AbstractDict ||
            throw(ArgumentError("events.windows[$index] must be a mapping"))

        name = get(window, "name", nothing)
        name isa AbstractString ||
            throw(ArgumentError("events.windows[$index].name must be a string"))

        start_raw = get(window, "start_date", nothing)
        isnothing(start_raw) &&
            throw(ArgumentError("events.windows[$index].start_date must be present"))
        start_date = _event_date(start_raw, "events.windows[$index].start_date")

        end_raw = get(window, "end_date", start_raw)
        end_date = _event_date(end_raw, "events.windows[$index].end_date")
        start_date <= end_date ||
            throw(ArgumentError("events.windows[$index] must satisfy start_date <= end_date"))

        push!(parsed, (; name = String(name), start_date, end_date))
    end

    return parsed
end

function _events_columns(config::Dict{String, Any})
    isempty(config) && return String[]

    columns = get(config, "columns", Any[])
    columns isa AbstractVector ||
        throw(ArgumentError("events.columns must be a list of strings"))
    all(item -> item isa AbstractString, columns) ||
        throw(ArgumentError("events.columns must be a list of strings"))

    windows = _events_windows(config)
    isempty(columns) || isempty(windows) ||
        throw(ArgumentError("events must define either events.columns or events.windows, not both"))

    return isempty(windows) ? [String(item) for item in columns] : [window.name for window in windows]
end

function _validate_events_config(config::Dict{String, Any})
    keys_set = Set(String(key) for key in keys(config))
    allowed_keys = Set(["columns", "windows", "priors"])
    isempty(setdiff(keys_set, allowed_keys)) ||
        throw(ArgumentError("events supports only `columns`, `windows`, and `priors` in the current model path"))

    columns = _events_columns(config)
    windows = _events_windows(config)
    isempty(config) && return nothing
    isempty(columns) &&
        throw(ArgumentError("events must define a non-empty `columns` or `windows` path when configured"))
    _validate_unique_strings(columns, isempty(windows) ? "events.columns" : "events.windows")
    return nothing
end

function _event_model_dates(dates::AbstractVector)
    if all(value -> value isa Union{Dates.Date, Dates.DateTime}, dates)
        return Dates.Date.(dates)
    end

    throw(
        ArgumentError(
            "generated event windows require `MMMData.dates` to be Date/DateTime-like",
        ),
    )
end

function _generated_event_design_matrix(config::Dict{String, Any}, dates::AbstractVector)
    windows = _events_windows(config)
    isempty(windows) && return nothing

    model_dates = _event_model_dates(dates)
    matrix = zeros(Float64, length(model_dates), length(windows))
    for (index, window) in enumerate(windows)
        matrix[:, index] .= Float64.(
            (model_dates .>= window.start_date) .& (model_dates .<= window.end_date),
        )
    end
    return matrix
end

function _event_design_matrix(config::Dict{String, Any}, data::MMMData)
    generated = _generated_event_design_matrix(config, data.dates)
    !isnothing(generated) && return generated
    return data.events
end
