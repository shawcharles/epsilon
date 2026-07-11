using CSV
using DataFrames
using Dates
using Epsilon

const _TOY_DEFAULT_DRAWS = 32
const _TOY_DEFAULT_TUNE = 32
const _TOY_DEFAULT_SEED = 20260706

function _toy_mmm_data()
    dates = collect(Date(2026, 1, 5):Week(1):Date(2026, 3, 9))
    channels = [
        12.0 4.0
        14.0 5.0
        13.0 5.5
        16.0 6.0
        18.0 6.5
        19.0 7.0
        17.0 6.8
        20.0 7.5
        22.0 8.0
        21.0 7.8
    ]
    target = [
        82.0,
        86.0,
        87.0,
        91.0,
        95.0,
        98.0,
        96.0,
        101.0,
        105.0,
        104.0,
    ]

    return MMMData(
        dates = dates,
        target = target,
        channels = channels,
        channel_names = ["tv", "search"],
    )
end

function _toy_model_config()
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

function _toy_sampler_config(; draws::Integer, tune::Integer, seed::Integer)
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

function _write_toy_outputs(output_dir::AbstractString, contribution_table, metric_table, summary_lines)
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

function _toy_summary_lines(; state, draws, tune, seed, contribution_rows, metric_rows, observed_total)
    return [
        "Epsilon toy MMM MCMC smoke demo",
        "status=$(state.status)",
        "backend=$(state.backend)",
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
    run_toy_mmm(; draws=32, tune=32, seed=20260706, output_dir=nothing, verbose=true)

Run a tiny synthetic `TimeSeriesMMM` through the supported MCMC path and return
a named result contract for examples and tests.
"""
function run_toy_mmm(;
        draws::Integer = _TOY_DEFAULT_DRAWS,
        tune::Integer = _TOY_DEFAULT_TUNE,
        seed::Integer = _TOY_DEFAULT_SEED,
        output_dir = nothing,
        verbose::Bool = true,
    )
    config = _toy_model_config()
    sampler = _toy_sampler_config(; draws, tune, seed)
    data = _toy_mmm_data()
    model = TimeSeriesMMM(config, sampler, data)
    state = fit!(model)
    grouped = inference_results(
        model;
        include_prior = false,
        include_posterior_predictive = false,
        include_prior_predictive = false,
    )

    contributions = contribution_results(grouped)
    contribution_table = summary_table(contributions)
    observed_total = sum(data.channels[:, 1])
    metric_table = summary_table(
        metric_results(
            grouped;
            channel = "tv",
            grid = [0.0, observed_total / 2, observed_total],
        ),
    )
    summary_lines = _toy_summary_lines(;
        state,
        draws,
        tune,
        seed,
        contribution_rows = nrow(contribution_table),
        metric_rows = nrow(metric_table),
        observed_total,
    )
    written_paths = isnothing(output_dir) ?
        NamedTuple() :
        _write_toy_outputs(String(output_dir), contribution_table, metric_table, summary_lines)

    if verbose
        println(join(summary_lines, "\n"))
        if !isempty(pairs(written_paths))
            println("output_dir=$(String(output_dir))")
        end
    end

    return (
        model = model,
        state = state,
        grouped = grouped,
        contribution_table = contribution_table,
        metric_table = metric_table,
        written_paths = written_paths,
    )
end

function _parse_toy_integer_option(option::AbstractString, value::AbstractString)
    parsed = tryparse(Int, value)
    isnothing(parsed) && throw(ArgumentError("$(option) requires an integer value, got $(repr(value))"))
    return parsed
end

function _parse_toy_cli(args::Vector{String})
    options = Dict{String, Any}(
        "draws" => _TOY_DEFAULT_DRAWS,
        "tune" => _TOY_DEFAULT_TUNE,
        "seed" => _TOY_DEFAULT_SEED,
        "output_dir" => nothing,
    )

    index = firstindex(args)
    while index <= lastindex(args)
        arg = args[index]
        if arg == "--draws"
            index += 1
            index <= lastindex(args) || throw(ArgumentError("--draws requires a value"))
            options["draws"] = _parse_toy_integer_option("--draws", args[index])
        elseif arg == "--tune"
            index += 1
            index <= lastindex(args) || throw(ArgumentError("--tune requires a value"))
            options["tune"] = _parse_toy_integer_option("--tune", args[index])
        elseif arg == "--seed"
            index += 1
            index <= lastindex(args) || throw(ArgumentError("--seed requires a value"))
            options["seed"] = _parse_toy_integer_option("--seed", args[index])
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

function _print_toy_help()
    return println(
        """
        Usage: julia --project=. examples/toy_mmm/run_toy_mmm.jl [options]

        Options:
          --draws N        Posterior draws for one MCMC chain. Default: $(_TOY_DEFAULT_DRAWS)
          --tune N         Tuning iterations for one MCMC chain. Default: $(_TOY_DEFAULT_TUNE)
          --seed N         Random seed. Default: $(_TOY_DEFAULT_SEED)
          --output-dir DIR Write compact CSV/text summaries to DIR.
          -h, --help       Show this help.
        """,
    )
end

function main(args = ARGS)
    options = _parse_toy_cli(String.(args))
    if get(options, "help", false)
        _print_toy_help()
        return nothing
    end

    return run_toy_mmm(;
        draws = options["draws"],
        tune = options["tune"],
        seed = options["seed"],
        output_dir = options["output_dir"],
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
