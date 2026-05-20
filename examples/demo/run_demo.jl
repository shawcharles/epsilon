#!/usr/bin/env julia

using Epsilon

const _DEMO_ROOT = @__DIR__
const _DEFAULT_RESULTS_DIR = joinpath(_DEMO_ROOT, "results")

const _DEMO_SPECS = Dict(
    "timeseries" => (
        mode = :runnable,
        description = "Abacus-aligned time-series demo with an Epsilon-native runnable config",
        dataset = joinpath(_DEMO_ROOT, "reference", "abacus", "timeseries", "dataset.csv"),
        holidays = joinpath(_DEMO_ROOT, "reference", "abacus", "holidays.csv"),
        abacus_config = joinpath(_DEMO_ROOT, "reference", "abacus", "timeseries", "config.yml"),
        epsilon_config = joinpath(_DEMO_ROOT, "epsilon", "timeseries", "config.yml"),
    ),
    "geo_panel" => (
        mode = :reference_only,
        description = "Reference-only Abacus geo panel demo bundle",
        dataset = joinpath(_DEMO_ROOT, "reference", "abacus", "geo_panel", "dataset.csv"),
        holidays = joinpath(_DEMO_ROOT, "reference", "abacus", "holidays.csv"),
        abacus_config = joinpath(_DEMO_ROOT, "reference", "abacus", "geo_panel", "config.yml"),
        epsilon_config = nothing,
    ),
    "geo_brand_panel" => (
        mode = :reference_only,
        description = "Reference-only Abacus geo-brand panel demo bundle",
        dataset = joinpath(_DEMO_ROOT, "reference", "abacus", "geo_brand_panel", "dataset.csv"),
        holidays = joinpath(_DEMO_ROOT, "reference", "abacus", "holidays.csv"),
        abacus_config = joinpath(_DEMO_ROOT, "reference", "abacus", "geo_brand_panel", "config.yml"),
        epsilon_config = nothing,
    ),
)

const _DEMO_USAGE = """
Usage:
  julia --project=. examples/demo/run_demo.jl list
  julia --project=. examples/demo/run_demo.jl paths <demo>
  julia --project=. examples/demo/run_demo.jl run <demo> [pipeline flags...]
  julia --project=. examples/demo/run_demo.jl --help

Demo IDs:
  timeseries
  geo_panel
  geo_brand_panel

Notes:
  - `run` is supported only for `timeseries` in the bounded Epsilon v1 surface.
  - `paths` is useful when comparing the same reference data/configs across Epsilon,
    Abacus, Meridian, or PyMC-Marketing.
  - All extra flags after `run <demo>` are forwarded to `epsilon run ...`.
"""

function main(args = ARGS)
    argv = String[String(value) for value in args]

    if isempty(argv) || argv[1] in ("-h", "--help")
        println(stdout, _DEMO_USAGE)
        return 0
    end

    command = argv[1]
    if command == "list"
        _print_demo_list(stdout)
        return 0
    elseif command == "paths"
        length(argv) == 2 || throw(ArgumentError("`paths` requires exactly one <demo> argument"))
        _print_demo_paths(stdout, argv[2])
        return 0
    elseif command == "run"
        length(argv) >= 2 || throw(ArgumentError("`run` requires a <demo> argument"))
        return _run_demo(argv[2], argv[3:end])
    end

    throw(ArgumentError("unknown demo command `$command`"))
end

function _print_demo_list(io::IO)
    for demo in sort!(collect(keys(_DEMO_SPECS)))
        spec = _DEMO_SPECS[demo]
        mode = spec.mode === :runnable ? "runnable" : "reference-only"
        println(io, "$(demo)\t$(mode)\t$(spec.description)")
    end
    return nothing
end

function _print_demo_paths(io::IO, demo::AbstractString)
    spec = _demo_spec(demo)
    epsilon_config = isnothing(spec.epsilon_config) ? "unsupported" : spec.epsilon_config
    println(io, "demo=$(demo)")
    println(io, "mode=$(spec.mode)")
    println(io, "dataset=$(spec.dataset)")
    println(io, "holidays=$(spec.holidays)")
    println(io, "abacus_config=$(spec.abacus_config)")
    println(io, "epsilon_config=$(epsilon_config)")
    return nothing
end

function _run_demo(demo::AbstractString, extra_args::Vector{String})
    spec = _demo_spec(demo)
    spec.mode === :runnable || throw(
        ArgumentError(
            "demo `$demo` is reference-only. The shipped Epsilon pipeline is time-series-first, so only `timeseries` is runnable through run_demo.jl",
        ),
    )

    epsilon_config = spec.epsilon_config
    isnothing(epsilon_config) && throw(ArgumentError("demo `$demo` has no runnable Epsilon config"))

    forwarded = copy(extra_args)
    if !_has_cli_option(forwarded, "--output-dir")
        append!(forwarded, ["--output-dir", _DEFAULT_RESULTS_DIR])
    end
    if !_has_cli_option(forwarded, "--run-name")
        append!(forwarded, ["--run-name", "demo-$(demo)"])
    end

    return pipeline_main(vcat(["run", epsilon_config], forwarded))
end

function _has_cli_option(args::Vector{String}, option::AbstractString)
    for arg in args
        (arg == option || startswith(arg, option * "=")) && return true
    end
    return false
end

function _demo_spec(demo::AbstractString)
    haskey(_DEMO_SPECS, demo) || throw(
        ArgumentError(
            "unknown demo `$demo`; expected one of: $(join(sort!(collect(keys(_DEMO_SPECS))), ", "))",
        ),
    )
    return _DEMO_SPECS[demo]
end

try
    exit(main())
catch err
    println(stderr, "Error: $(sprint(showerror, err))")
    println(stderr, _DEMO_USAGE)
    exit(1)
end
