using CSV
using DataFrames
using Dates
using Epsilon

const _CSV_MMM_REQUIRED_COLUMNS = ("date", "sales", "tv", "search")
const _CSV_MMM_DATE_FORMAT = DateFormat("yyyy-mm-dd")
const _CSV_MMM_DEFAULT_DRAWS = 32
const _CSV_MMM_DEFAULT_TUNE = 32
const _CSV_MMM_DEFAULT_SEED = 20260711
const _CSV_MMM_DEFAULT_DATA_PATH = normpath(joinpath(@__DIR__, "toy_timeseries.csv"))

function _require_csv_mmm_columns(table::DataFrame)
    available = Set(String.(names(table)))
    for column in _CSV_MMM_REQUIRED_COLUMNS
        column in available || throw(ArgumentError("CSV is missing required column $(repr(column))"))
    end
    unexpected_columns = sort!(collect(setdiff(available, Set(_CSV_MMM_REQUIRED_COLUMNS))))
    isempty(unexpected_columns) ||
        throw(ArgumentError("CSV has unexpected columns: $(join(unexpected_columns, ", "))"))
    return nothing
end

function _parse_csv_mmm_dates(values)
    dates = Date[]
    for (row, value) in enumerate(values)
        ismissing(value) && throw(ArgumentError("date column has a missing value at row $(row)"))
        raw = String(value)
        isempty(raw) && throw(ArgumentError("date column has a missing value at row $(row)"))
        parsed = tryparse(Date, raw, _CSV_MMM_DATE_FORMAT)
        if isnothing(parsed) || Dates.format(parsed, _CSV_MMM_DATE_FORMAT) != raw
            throw(ArgumentError("date column has malformed value $(repr(raw)) at row $(row)"))
        end
        push!(dates, parsed)
    end
    return dates
end

function _parse_csv_mmm_numeric_column(values, column::AbstractString; nonnegative::Bool = false)
    numeric_values = Float64[]
    for (row, value) in enumerate(values)
        ismissing(value) && throw(ArgumentError("$(column) column has a missing value at row $(row)"))
        value isa Bool &&
            throw(ArgumentError("$(column) column has a non-numeric Boolean value $(repr(value)) at row $(row)"))
        parsed = value isa Real ? Float64(value) : tryparse(Float64, String(value))
        isnothing(parsed) &&
            throw(ArgumentError("$(column) column has malformed numeric value $(repr(value)) at row $(row)"))
        isfinite(parsed) ||
            throw(ArgumentError("$(column) column has non-finite numeric value $(repr(value)) at row $(row)"))
        nonnegative && parsed < 0 &&
            throw(ArgumentError("$(column) column must be nonnegative at row $(row)"))
        push!(numeric_values, parsed)
    end
    return numeric_values
end

function _csv_mmm_row_order(dates::Vector{Date})
    isempty(dates) && throw(ArgumentError("CSV data has no rows"))
    order = sortperm(dates)
    for index in 2:length(order)
        dates[order[index]] == dates[order[index - 1]] &&
            throw(ArgumentError("date column has duplicate parsed date $(dates[order[index]])"))
    end
    return order
end

"""
    load_csv_mmm_data(path)

Load the exact `date,sales,tv,search` CSV schema used by this quickstart into
chronologically ordered `MMMData`.
"""
function load_csv_mmm_data(path::AbstractString)
    isfile(path) || throw(ArgumentError("CSV data path does not exist: $(repr(path))"))
    table = try
        CSV.read(path, DataFrame; normalizenames = false, strict = true, types = Dict("date" => String))
    catch err
        throw(ArgumentError("failed to parse CSV data at $(repr(path)): $(sprint(showerror, err))"))
    end
    _require_csv_mmm_columns(table)

    dates = _parse_csv_mmm_dates(table[!, "date"])
    target = _parse_csv_mmm_numeric_column(table[!, "sales"], "sales")
    tv = _parse_csv_mmm_numeric_column(table[!, "tv"], "tv"; nonnegative = true)
    search = _parse_csv_mmm_numeric_column(table[!, "search"], "search"; nonnegative = true)
    order = _csv_mmm_row_order(dates)

    return MMMData(
        dates = dates[order],
        target = target[order],
        channels = hcat(tv[order], search[order]),
        channel_names = ["tv", "search"],
    )
end

function _csv_mmm_model_config()
    return ModelConfig(
        date_column = "date",
        target_column = "sales",
        target_type = "revenue",
        channel_columns = ["tv", "search"],
        adstock = Dict("type" => "geometric", "l_max" => 2),
        saturation = Dict("type" => "logistic"),
        priors = Dict("intercept" => EpsilonPrior("Normal"; mu = 0.0, sigma = 1.0)),
    )
end

function _csv_mmm_sampler_config(; draws::Integer, tune::Integer, seed::Integer)
    return SamplerConfig(;
        draws = draws,
        tune = tune,
        chains = 1,
        cores = 1,
        target_accept = 0.8,
        random_seed = seed,
        progressbar = false,
        compute_convergence_checks = false,
    )
end

function _write_csv_mmm_outputs(output_dir::AbstractString, contribution_table, metric_table, summary_lines)
    mkpath(output_dir)
    contribution_path = joinpath(output_dir, "contribution_summary.csv")
    metric_path = joinpath(output_dir, "metric_summary.csv")
    run_summary_path = joinpath(output_dir, "run_summary.txt")

    CSV.write(contribution_path, contribution_table)
    CSV.write(metric_path, metric_table)
    write(run_summary_path, join(summary_lines, "\n") * "\n")

    return (
        contribution_summary = contribution_path,
        metric_summary = metric_path,
        run_summary = run_summary_path,
    )
end

function _csv_mmm_summary_lines(; state, data_path, draws, tune, seed, contribution_rows, metric_rows, observed_total)
    return [
        "Epsilon CSV MMM MCMC quickstart",
        "status=$(state.status)",
        "backend=$(state.backend)",
        "data_path=$(data_path)",
        "draws=$(draws)",
        "tune=$(tune)",
        "seed=$(seed)",
        "channel=tv",
        "observed_total_tv=$(observed_total)",
        "contribution_rows=$(contribution_rows)",
        "metric_rows=$(metric_rows)",
    ]
end

"""
    run_csv_mmm(; data_path=_CSV_MMM_DEFAULT_DATA_PATH, draws=32, tune=32,
                seed=20260711, output_dir=nothing, verbose=true)

Run the bundled four-column CSV quickstart through the supported Turing/NUTS
path and return its loaded data, fit state, grouped results, summaries, and any
written output paths.
"""
function run_csv_mmm(;
        data_path::AbstractString = _CSV_MMM_DEFAULT_DATA_PATH,
        draws::Integer = _CSV_MMM_DEFAULT_DRAWS,
        tune::Integer = _CSV_MMM_DEFAULT_TUNE,
        seed::Integer = _CSV_MMM_DEFAULT_SEED,
        output_dir = nothing,
        verbose::Bool = true,
    )
    data = load_csv_mmm_data(data_path)
    config = _csv_mmm_model_config()
    sampler = _csv_mmm_sampler_config(; draws, tune, seed)
    model = TimeSeriesMMM(config, sampler, data)
    state = fit!(model)
    grouped = inference_results(
        model;
        include_prior = false,
        include_posterior_predictive = false,
        include_prior_predictive = false,
    )

    contribution_table = summary_table(contribution_results(grouped))
    observed_total = sum(data.channels[:, 1])
    metric_table = summary_table(
        metric_results(
            grouped;
            channel = "tv",
            grid = [0.0, observed_total / 2, observed_total],
        ),
    )
    summary_lines = _csv_mmm_summary_lines(;
        state,
        data_path,
        draws,
        tune,
        seed,
        contribution_rows = nrow(contribution_table),
        metric_rows = nrow(metric_table),
        observed_total,
    )
    written_paths = isnothing(output_dir) ?
        NamedTuple() :
        _write_csv_mmm_outputs(String(output_dir), contribution_table, metric_table, summary_lines)

    if verbose
        println(join(summary_lines, "\n"))
        !isempty(pairs(written_paths)) && println("output_dir=$(String(output_dir))")
    end

    return (
        data = data,
        model = model,
        state = state,
        grouped = grouped,
        contribution_table = contribution_table,
        metric_table = metric_table,
        written_paths = written_paths,
    )
end

function _parse_csv_mmm_integer_option(option::AbstractString, value::AbstractString)
    parsed = tryparse(Int, value)
    isnothing(parsed) && throw(ArgumentError("$(option) requires an integer value, got $(repr(value))"))
    return parsed
end

function _parse_csv_mmm_positive_integer_option(option::AbstractString, value::AbstractString)
    parsed = _parse_csv_mmm_integer_option(option, value)
    parsed > 0 || throw(ArgumentError("$(option) requires a positive integer value, got $(repr(value))"))
    return parsed
end

function _parse_csv_mmm_cli(args::Vector{String})
    options = Dict{String, Any}(
        "data" => _CSV_MMM_DEFAULT_DATA_PATH,
        "draws" => _CSV_MMM_DEFAULT_DRAWS,
        "tune" => _CSV_MMM_DEFAULT_TUNE,
        "seed" => _CSV_MMM_DEFAULT_SEED,
        "output_dir" => nothing,
    )

    index = firstindex(args)
    while index <= lastindex(args)
        arg = args[index]
        if arg == "--data"
            index += 1
            index <= lastindex(args) || throw(ArgumentError("--data requires a value"))
            options["data"] = args[index]
        elseif arg == "--draws"
            index += 1
            index <= lastindex(args) || throw(ArgumentError("--draws requires a value"))
            options["draws"] = _parse_csv_mmm_positive_integer_option("--draws", args[index])
        elseif arg == "--tune"
            index += 1
            index <= lastindex(args) || throw(ArgumentError("--tune requires a value"))
            options["tune"] = _parse_csv_mmm_positive_integer_option("--tune", args[index])
        elseif arg == "--seed"
            index += 1
            index <= lastindex(args) || throw(ArgumentError("--seed requires a value"))
            options["seed"] = _parse_csv_mmm_integer_option("--seed", args[index])
        elseif arg == "--output-dir"
            index += 1
            index <= lastindex(args) || throw(ArgumentError("--output-dir requires a value"))
            options["output_dir"] = args[index]
        elseif arg == "--help" || arg == "-h"
            options["help"] = true
        else
            throw(ArgumentError("unknown argument: $(arg)"))
        end
        index += 1
    end
    return options
end

function _print_csv_mmm_help()
    return println(
        """
        Usage: julia --project=. examples/csv_mmm/run_csv_mmm.jl [options]

        Options:
          --data PATH     CSV with exact columns: date,sales,tv,search.
                          Default: $(_CSV_MMM_DEFAULT_DATA_PATH)
          --draws N       Posterior draws for one MCMC chain. Default: $(_CSV_MMM_DEFAULT_DRAWS)
          --tune N        Tuning iterations for one MCMC chain. Default: $(_CSV_MMM_DEFAULT_TUNE)
          --seed N        Random seed. Default: $(_CSV_MMM_DEFAULT_SEED)
          --output-dir DIR Write compact CSV/text summaries to DIR.
          -h, --help      Show this help.
        """,
    )
end

function main(args = ARGS)
    options = _parse_csv_mmm_cli(String.(args))
    if get(options, "help", false)
        _print_csv_mmm_help()
        return nothing
    end

    return run_csv_mmm(;
        data_path = options["data"],
        draws = options["draws"],
        tune = options["tune"],
        seed = options["seed"],
        output_dir = options["output_dir"],
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
