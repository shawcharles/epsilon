#!/usr/bin/env julia

using Epsilon

const _RUNME_DEFAULT_CONFIG = joinpath(@__DIR__, "data", "demo", "timeseries", "config.yml")

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
  julia --project=. runme.jl [config_path] [pipeline flags...] [--quick]
  julia --project=. runme.jl demo timeseries [pipeline flags...] [--quick]
  julia --project=. runme.jl --help

Examples:
  julia --project=. runme.jl
  julia --project=. runme.jl data/demo/timeseries/config.yml --quick
  julia --project=. runme.jl demo timeseries --output-dir results --quick

Notes:
  - With no config path, the runner uses data/demo/timeseries/config.yml and
    quick local settings.
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
        println(stderr, "Error: $(sprint(showerror, err))")
        println(stderr, _RUNME_USAGE)
        return 1
    end
end

function _runme_run_config(config_path::AbstractString, args::Vector{String})
    forwarded = _runme_pipeline_args(config_path, args)
    return pipeline_main(forwarded)
end

function _runme_pipeline_args(config_path::AbstractString, args::Vector{String})
    quick, forwarded = _runme_remove_quick(args)
    if quick
        _runme_apply_quick_defaults!(forwarded)
    end
    return vcat(["run", String(config_path)], forwarded)
end

function _runme_remove_quick(args::Vector{String})
    forwarded = String[]
    quick = false
    for arg in args
        if arg == "--quick"
            quick = true
        elseif startswith(arg, "--quick=")
            throw(ArgumentError("runner flag `--quick` does not accept a value"))
        else
            push!(forwarded, arg)
        end
    end
    return quick, forwarded
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

if abspath(PROGRAM_FILE) == @__FILE__
    exit(runme_main())
end
