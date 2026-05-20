using CSV
using Dates

const _HOLIDAY_STATE_KEY = "__epsilon_state"

function _holiday_date(value, key::AbstractString)
    if value isa Dates.Date
        return value
    elseif value isa Dates.DateTime
        return Dates.Date(value)
    elseif value isa AbstractString
        raw = strip(String(value))
        for parser in (
                v -> Dates.Date(v),
                v -> Dates.Date(Dates.DateTime(v)),
                v -> Dates.Date(v, dateformat"dd/mm/yyyy"),
            )
            try
                return parser(raw)
            catch
            end
        end
        throw(ArgumentError("$key must be an ISO date string, datetime string, or dd/mm/yyyy date string"))
    end

    throw(ArgumentError("$key must be a date, datetime, or date string"))
end

function _holidays_mode(config::Dict{String, Any})
    isempty(config) && return :none
    raw = get(config, "mode", "none")
    raw isa AbstractString || throw(ArgumentError("holidays.mode must be a string"))
    normalized = lowercase(strip(String(raw)))
    return isempty(normalized) ? :none : Symbol(normalized)
end

function _holidays_path(config::Dict{String, Any})
    isempty(config) && return nothing
    path = get(config, "path", nothing)
    isnothing(path) && return nothing
    path isa AbstractString || throw(ArgumentError("holidays.path must be a string"))
    stripped = strip(String(path))
    isempty(stripped) && throw(ArgumentError("holidays.path must not be empty"))
    return stripped
end

function _holidays_countries(config::Dict{String, Any})
    isempty(config) && return String[]
    countries = get(config, "countries", Any[])
    if countries isa AbstractString
        return [String(countries)]
    elseif countries isa AbstractVector
        all(item -> item isa AbstractString, countries) ||
            throw(ArgumentError("holidays.countries must be a string or list of strings"))
        return [String(item) for item in countries]
    end
    throw(ArgumentError("holidays.countries must be a string or list of strings"))
end

function _holiday_rows(config::Dict{String, Any})
    _holidays_mode(config) === :none && return NamedTuple[]
    path = _holidays_path(config)
    isnothing(path) && throw(ArgumentError("holidays.path must be present when holidays are configured"))
    isfile(path) || throw(ArgumentError("holidays.path does not exist: $path"))

    rows = collect(CSV.File(path; normalizenames = false))
    required = Set(("ds", "holiday", "country", "year"))
    isempty(rows) && return NamedTuple[]
    fieldnames = Set(String(name) for name in propertynames(first(rows)))
    isempty(setdiff(required, fieldnames)) ||
        throw(
        ArgumentError(
            "holidays.path must contain columns ds, holiday, country, and year",
        ),
    )

    allowed_countries = Set(_holidays_countries(config))
    filtered = NamedTuple{(:date, :holiday, :country, :year), Tuple{Dates.Date, String, String, Int}}[]
    for (index, row) in enumerate(rows)
        country = String(getproperty(row, :country))
        !isempty(allowed_countries) && !(country in allowed_countries) && continue
        holiday_name = String(getproperty(row, :holiday))
        year_raw = getproperty(row, :year)
        year_raw isa Integer || throw(ArgumentError("holidays.path row $index year must be an integer"))
        date = _holiday_date(getproperty(row, :ds), "holidays.path row $index ds")
        push!(
            filtered,
            (; date, holiday = holiday_name, country, year = Int(year_raw)),
        )
    end
    return filtered
end

function _holidays_columns(config::Dict{String, Any})
    _holidays_mode(config) === :none && return String[]
    isempty(_holiday_rows(config)) && return String[]
    return ["holiday"]
end

function _holiday_unique_dates(config::Dict{String, Any})
    rows = _holiday_rows(config)
    isempty(rows) && return Dates.Date[]

    seen = Set{Dates.Date}()
    dates = Dates.Date[]
    for row in rows
        row.date in seen && continue
        push!(seen, row.date)
        push!(dates, row.date)
    end
    sort!(dates)
    return dates
end

function _default_holiday_period_days(dates::AbstractVector{Dates.Date})
    length(dates) <= 1 && return 1

    counts = Dict{Int, Int}()
    first_seen = Dict{Int, Int}()
    best_days = 1
    best_count = -1
    best_position = typemax(Int)

    for index in 1:(length(dates) - 1)
        delta_days = Int(Dates.value(dates[index + 1] - dates[index]))
        delta_days > 0 ||
            throw(ArgumentError("automatic holidays require strictly increasing Date/DateTime-like MMMData.dates"))

        counts[delta_days] = get(counts, delta_days, 0) + 1
        if !haskey(first_seen, delta_days)
            first_seen[delta_days] = index
        end

        if counts[delta_days] > best_count ||
                (counts[delta_days] == best_count && first_seen[delta_days] < best_position)
            best_days = delta_days
            best_count = counts[delta_days]
            best_position = first_seen[delta_days]
        end
    end

    return best_days
end

function _holiday_period_days(dates::AbstractVector{Dates.Date})
    isempty(dates) && return Int[]

    default_days = _default_holiday_period_days(dates)
    period_days = Vector{Int}(undef, length(dates))
    for index in 1:(length(dates) - 1)
        delta_days = Int(Dates.value(dates[index + 1] - dates[index]))
        delta_days > 0 ||
            throw(ArgumentError("automatic holidays require strictly increasing Date/DateTime-like MMMData.dates"))
        period_days[index] = delta_days
    end
    period_days[end] = default_days
    return period_days
end

function _holiday_state_from_dates(dates::AbstractVector)
    model_dates = _holiday_model_dates(dates)
    return Dict{String, Any}(
        "dates" => model_dates,
        "period_days" => _holiday_period_days(model_dates),
        "default_period_days" => _default_holiday_period_days(model_dates),
    )
end

function _holiday_spec_config(config::Dict{String, Any}, dates::AbstractVector)
    _holidays_mode(config) === :none && return copy(config)
    resolved = copy(config)
    resolved[_HOLIDAY_STATE_KEY] = _holiday_state_from_dates(dates)
    return resolved
end

function _holiday_state(config::Dict{String, Any})
    state = get(config, _HOLIDAY_STATE_KEY, nothing)
    isnothing(state) && return nothing
    state isa AbstractDict || throw(ArgumentError("holidays.$_HOLIDAY_STATE_KEY must be a mapping"))
    for key in ("dates", "period_days", "default_period_days")
        haskey(state, key) ||
            throw(ArgumentError("holidays.$_HOLIDAY_STATE_KEY.$key is missing"))
    end
    default_period_days = state["default_period_days"]
    default_period_days isa Integer ||
        throw(ArgumentError("holidays.$_HOLIDAY_STATE_KEY.default_period_days must be an integer"))
    Int(default_period_days) > 0 ||
        throw(ArgumentError("holidays.$_HOLIDAY_STATE_KEY.default_period_days must be positive"))
    return state
end

function _holiday_period_days(config::Dict{String, Any}, dates::AbstractVector{Dates.Date})
    state = _holiday_state(config)
    isnothing(state) && return _holiday_period_days(dates)

    state_dates = Dates.Date.(state["dates"])
    state_period_days = Int.(state["period_days"])
    if state_dates == dates
        length(state_period_days) == length(dates) ||
            throw(ArgumentError("holidays.$_HOLIDAY_STATE_KEY.period_days must match stored fitted dates"))
        return state_period_days
    end

    return fill(Int(state["default_period_days"]), length(dates))
end

function _pooled_holiday_exposure(config::Dict{String, Any}, dates::AbstractVector)
    model_dates = _holiday_model_dates(dates)
    holiday_dates = Set(_holiday_unique_dates(config))
    period_days = _holiday_period_days(config, model_dates)
    exposure = zeros(Float64, length(model_dates))

    for index in eachindex(model_dates)
        days_in_period = period_days[index]
        holiday_days = 0
        for offset in 0:(days_in_period - 1)
            holiday_days += (model_dates[index] + Dates.Day(offset)) in holiday_dates
        end
        exposure[index] = holiday_days / days_in_period
    end

    return exposure
end

function _validate_holiday_event_coexistence(
        events_config::Dict{String, Any},
        holidays_config::Dict{String, Any},
    )
    _holidays_mode(holidays_config) === :none && return nothing

    event_windows = _events_windows(events_config)
    isempty(event_windows) && return nothing

    duplicate_holiday_windows = Set(
        (lowercase(strip(row.holiday)), row.date) for row in _holiday_rows(holidays_config)
    )

    for window in event_windows
        window.start_date == window.end_date || continue
        key = (lowercase(strip(window.name)), window.start_date)
        key in duplicate_holiday_windows || continue
        throw(
            ArgumentError(
                "events.windows contains `$(window.name)` on $(window.start_date), which duplicates an automatic holiday definition",
            ),
        )
    end

    return nothing
end

function _validate_holidays_config(config::Dict{String, Any})
    keys_set = Set(String(key) for key in keys(config))
    allowed_keys = Set(["mode", "path", "countries", "priors"])
    isempty(setdiff(keys_set, allowed_keys)) ||
        throw(
        ArgumentError(
            "holidays supports only `mode`, `path`, `countries`, and `priors` in the current model path",
        ),
    )

    mode = _holidays_mode(config)
    mode in (:none, :auto) ||
        throw(
        ArgumentError(
            "holidays.mode must be `none` or `auto` in the current Phase 12 surface",
        ),
    )
    mode === :none && return nothing

    _holidays_path(config)
    countries = _holidays_countries(config)
    isempty(countries) && throw(ArgumentError("holidays.countries must not be empty when holidays are configured"))
    _validate_unique_strings(countries, "holidays.countries")

    priors = get(config, "priors", Dict{String, Any}())
    priors isa AbstractDict || throw(ArgumentError("holidays.priors must be a mapping"))
    prior_keys = Set(String(key) for key in keys(priors))
    isempty(setdiff(prior_keys, Set(["beta"]))) ||
        throw(
        ArgumentError(
            "holidays.priors supports only `beta` in the current model path",
        ),
    )

    columns = _holidays_columns(config)
    isempty(columns) &&
        throw(
        ArgumentError(
            "holidays configuration did not resolve any holiday rows from the configured CSV and countries",
        ),
    )
    _validate_unique_strings(columns, "holiday columns")
    return nothing
end

function _holiday_model_dates(dates::AbstractVector)
    if all(value -> value isa Union{Dates.Date, Dates.DateTime}, dates)
        return Dates.Date.(dates)
    end
    throw(
        ArgumentError(
            "generated holiday indicators require `MMMData.dates` to be Date/DateTime-like",
        ),
    )
end

function _holiday_design_matrix(config::Dict{String, Any}, data::MMMData)
    _holidays_mode(config) === :none && return nothing
    columns = _holidays_columns(config)
    isempty(columns) && return nothing
    exposure = _pooled_holiday_exposure(config, data.dates)
    return reshape(exposure, :, 1)
end

function _holiday_design_matrix(config::Dict{String, Any}, data::PanelMMMData)
    _holidays_mode(config) === :none && return nothing
    columns = _holidays_columns(config)
    isempty(columns) && return nothing

    features = Array{Float64}(undef, length(data.dates), length(columns), length(data.panel_names))
    for (panel_index, panel_name) in enumerate(data.panel_names)
        panel_config = _panel_holiday_config(config, panel_name)
        features[:, 1, panel_index] .= _pooled_holiday_exposure(panel_config, data.dates)
    end
    return features
end

function _panel_holiday_config(config::Dict{String, Any}, panel_name::AbstractString)
    configured = Set(_holidays_countries(config))
    candidate_countries = _holiday_country_aliases(panel_name)
    selected = if isempty(configured) || !isempty(intersect(configured, Set(candidate_countries)))
        candidate_countries
    else
        String[]
    end
    isempty(selected) && (selected = candidate_countries)

    panel_config = copy(config)
    panel_config["countries"] = selected
    return panel_config
end

function _holiday_country_aliases(country::AbstractString)
    value = String(country)
    occursin("|", value) && (value = first(split(value, "|"; limit = 2)))
    value == "UK" && return ["UK", "GB"]
    value == "GB" && return ["GB", "UK"]
    return [value]
end
