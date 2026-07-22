#!/usr/bin/env julia

using Epsilon

const _RUNME_DEFAULT_CONFIG = joinpath(@__DIR__, "data", "demo", "timeseries", "config.yml")
const _RUNME_HEADER_PATH = joinpath(@__DIR__, "assets", "ascii.txt")

const _RUNME_QUICK_DEFAULTS = (
    "--draws" => "20",
    "--tune" => "20",
    "--chains" => "1",
    "--cores" => "1",
    "--prior-samples" => "5",
    "--curve-points" => "12",
)

const _RUNME_USAGE = """
Usage:
  julia --project=. runme.jl [config_path] [pipeline flags...] [--quick] [--no-plots]
  julia --project=. runme.jl demo timeseries [pipeline flags...] [--quick] [--no-plots]
  julia --project=. runme.jl --help

Examples:
  julia --project=. runme.jl
  julia --project=. runme.jl data/demo/timeseries/config.yml --quick
  julia --project=. runme.jl demo timeseries --output-dir results --quick

Notes:
  - With no config path, the runner uses data/demo/timeseries/config.yml and
    quick local settings.
  - The runner attempts to load optional CairoMakie plotting support and writes
    PNG plot artifacts when that package is available in the active environment;
    use --no-plots to suppress plot artifact generation.
  - Bundle-local dataset.csv and holidays.csv paths are owned by the config.
  - All pipeline flags are delegated to Epsilon.pipeline_main.
"""

"""
    runme_main(args = ARGS) -> Int

Run the repo-local Epsilon pipeline runner.

This is a thin convenience wrapper over `pipeline_main`. It translates the
repo-level `runme.jl` command shape into `epsilon run <config_path> ...` and
returns the delegated process status code.
"""
function runme_main(args = ARGS)
    argv = String[String(value) for value in args]

    try
        if isempty(argv)
            return _runme_run_config(_RUNME_DEFAULT_CONFIG, ["--quick"])
        end

        if argv[1] in ("-h", "--help")
            _runme_print_header(stdout)
            println(stdout, _RUNME_USAGE)
            return 0
        end

        if argv[1] == "demo"
            length(argv) >= 2 ||
                throw(ArgumentError("`demo` requires a demo name; supported: timeseries"))
            demo = argv[2]
            demo == "timeseries" ||
                throw(ArgumentError("unsupported demo `$demo`; supported: timeseries"))
            return _runme_run_config(_RUNME_DEFAULT_CONFIG, argv[3:end])
        end

        if startswith(argv[1], "-")
            return _runme_run_config(_RUNME_DEFAULT_CONFIG, argv)
        end

        return _runme_run_config(argv[1], argv[2:end])
    catch err
        _runme_print_header(stderr)
        _runme_print_runner_failure(stderr, err)
        println(stderr, _RUNME_USAGE)
        return 1
    end
end

function _runme_run_config(config_path::AbstractString, args::Vector{String})
    plan = _runme_pipeline_plan(config_path, args)
    plot_status = _runme_resolve_plot_status(plan.plots)
    _runme_print_header(stdout)
    _runme_print_context(stdout, config_path, plan, plot_status)
    execute = () -> Epsilon._with_pipeline_pretty_output() do
        pipeline_main(plan.args)
    end
    return plan.plots ? execute() : Epsilon._with_pipeline_plots_disabled(execute)
end

function _runme_pipeline_args(config_path::AbstractString, args::Vector{String})
    return _runme_pipeline_plan(config_path, args).args
end

function _runme_pipeline_plan(config_path::AbstractString, args::Vector{String})
    runner_options, forwarded = _runme_remove_runner_options(args)
    quick = runner_options.quick
    if quick
        _runme_apply_quick_defaults!(forwarded)
    end
    return (
        args = vcat(["run", String(config_path)], forwarded),
        quick = quick,
        plots = runner_options.plots,
        output_dir = _runme_cli_option_value(forwarded, "--output-dir", "results"),
        run_name = _runme_cli_option_value(forwarded, "--run-name", "(derived from config)"),
    )
end

function _runme_remove_quick(args::Vector{String})
    runner_options, forwarded = _runme_remove_runner_options(args)
    return runner_options.quick, forwarded
end

function _runme_remove_runner_options(args::Vector{String})
    forwarded = String[]
    quick = false
    plots = true
    for arg in args
        if arg == "--quick"
            quick = true
        elseif startswith(arg, "--quick=")
            throw(ArgumentError("runner flag `--quick` does not accept a value"))
        elseif arg == "--no-plots"
            plots = false
        elseif startswith(arg, "--no-plots=")
            throw(ArgumentError("runner flag `--no-plots` does not accept a value"))
        else
            push!(forwarded, arg)
        end
    end
    return (; quick, plots), forwarded
end

function _runme_apply_quick_defaults!(args::Vector{String})
    for (flag, value) in _RUNME_QUICK_DEFAULTS
        if !_runme_has_cli_option(args, flag)
            push!(args, flag)
            push!(args, value)
        end
    end
    return args
end

function _runme_has_cli_option(args::Vector{String}, option::AbstractString)
    for arg in args
        (arg == option || startswith(arg, option * "=")) && return true
    end
    return false
end

function _runme_cli_option_value(
        args::Vector{String},
        option::AbstractString,
        fallback::AbstractString,
    )
    for index in eachindex(args)
        arg = args[index]
        if startswith(arg, option * "=")
            return split(arg, '='; limit = 2)[2]
        end
        if arg == option && index < lastindex(args)
            return args[index + 1]
        end
    end
    return String(fallback)
end

function _runme_print_header(io::IO)
    println(io)
    if isfile(_RUNME_HEADER_PATH)
        try
            text = read(_RUNME_HEADER_PATH, String)
            print(io, chomp(text))
            println(io)
        catch
            println(io, "EPSILON")
        end
    else
        println(io, "EPSILON")
    end
    println(io, repeat("=", 72))
    return nothing
end

function _runme_resolve_plot_status(enabled::Bool)
    enabled || return "disabled (--no-plots)"
    try
        @eval Main using CairoMakie
    catch err
        return "unavailable ($(sprint(showerror, err)))"
    end
    Epsilon._pipeline_plots_enabled() && return "enabled (PNG)"
    return "unavailable (plotting extension did not activate)"
end

function _runme_print_context(io::IO, config_path::AbstractString, plan, plot_status::AbstractString)
    println(io, "Config       : $(config_path)")
    println(io, "Output root  : $(plan.output_dir)")
    println(io, "Run name     : $(plan.run_name)")
    println(io, "Quick mode   : $(plan.quick ? "yes" : "no")")
    println(io, "Julia threads: $(Base.Threads.nthreads())")
    println(io, "Plots        : $(plot_status)")
    println(io, "Data bundle  : dataset.csv and holidays.csv are resolved from the config")
    println(io, repeat("=", 72))
    return nothing
end

function _runme_print_runner_failure(io::IO, err)
    println(io, "Runner status : failed")
    println(io, "Error         : $(sprint(showerror, err))")
    println(io, repeat("=", 72))
    return nothing
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(runme_main())
end
