const _PIPELINE_MAIN_USAGE = """
Usage:
  epsilon run <config_path> [--output-dir <dir>] [--run-name <name>] [--dataset-path <path>]
              [--prior-samples <n>] [--curve-points <n>] [--draws <n>] [--tune <n>]
              [--chains <n>] [--cores <n>] [--random-seed <n>]
  epsilon --help

Commands:
  run      Execute the bounded Phase 9 pipeline on one YAML config.

Flags:
  --output-dir <dir>
  --run-name <name>
  --dataset-path <path>
  --prior-samples <n>
  --curve-points <n>
  --draws <n>
  --tune <n>
  --chains <n>
  --cores <n>
  --random-seed <n>
  -h, --help
"""

const _PIPELINE_RUN_USAGE = """
Usage:
  epsilon run <config_path> [--output-dir <dir>] [--run-name <name>] [--dataset-path <path>]
              [--prior-samples <n>] [--curve-points <n>] [--draws <n>] [--tune <n>]
              [--chains <n>] [--cores <n>] [--random-seed <n>]
"""

const _PIPELINE_CLI_OPTION_KEYS = Dict(
    "--output-dir" => :output_dir,
    "--run-name" => :run_name,
    "--dataset-path" => :dataset_path,
    "--prior-samples" => :prior_samples,
    "--curve-points" => :curve_points,
    "--draws" => :draws,
    "--tune" => :tune,
    "--chains" => :chains,
    "--cores" => :cores,
    "--random-seed" => :random_seed,
)

const _PIPELINE_CLI_INTEGER_KEYS = Set((
    :prior_samples,
    :curve_points,
    :draws,
    :tune,
    :chains,
    :cores,
    :random_seed,
))

"""
    pipeline_main(args = ARGS)

Run the bounded Phase 9 pipeline CLI.

The current supported CLI surface is one thin command:

- `epsilon run <config_path>`

All supported flags map one-to-one onto `PipelineRunConfig` and route through
the same `run_pipeline(config)` implementation.
"""
function pipeline_main(args = ARGS)
    argv = String[String(value) for value in args]

    if isempty(argv) || argv[1] in ("-h", "--help")
        println(stdout, _PIPELINE_MAIN_USAGE)
        return 0
    end

    command = argv[1]
    if command != "run"
        println(stderr, "Error: unknown command `$command`")
        println(stderr, _PIPELINE_MAIN_USAGE)
        return 1
    end

    return _pipeline_run_cli(argv[2:end])
end

function _pipeline_run_cli(args::Vector{String})
    if isempty(args) || any(arg -> arg in ("-h", "--help"), args)
        println(stdout, _PIPELINE_RUN_USAGE)
        return isempty(args) ? 1 : 0
    end

    try
        config = _pipeline_run_config_from_cli(args)
        result = run_pipeline(config)
        _print_pipeline_run_success(stdout, result)
        return 0
    catch err
        println(stderr, "Error: $(sprint(showerror, err))")
        return 1
    end
end

function _pipeline_run_config_from_cli(args::Vector{String})
    config_path = nothing
    kwargs = Dict{Symbol, Any}()
    index = 1

    while index <= length(args)
        token = args[index]
        if startswith(token, "--")
            option, value, next_index = _pipeline_cli_option(args, index)
            haskey(_PIPELINE_CLI_OPTION_KEYS, option) ||
                throw(ArgumentError("unsupported CLI flag `$option`"))
            key = _PIPELINE_CLI_OPTION_KEYS[option]
            kwargs[key] = key in _PIPELINE_CLI_INTEGER_KEYS ?
                _parse_pipeline_cli_integer(value, option) : value
            index = next_index
        elseif startswith(token, "-")
            throw(ArgumentError("unsupported CLI flag `$token`"))
        else
            isnothing(config_path) ||
                throw(ArgumentError("epsilon run accepts exactly one <config_path> positional argument"))
            config_path = token
            index += 1
        end
    end

    isnothing(config_path) &&
        throw(ArgumentError("epsilon run requires a <config_path> positional argument"))

    return PipelineRunConfig(; config_path, kwargs...)
end

function _pipeline_cli_option(args::Vector{String}, index::Int)
    token = args[index]
    if occursin('=', token)
        option, value = split(token, '='; limit = 2)
        isempty(value) && throw(ArgumentError("CLI flag `$option` requires a value"))
        return option, value, index + 1
    end

    index < length(args) || throw(ArgumentError("CLI flag `$token` requires a value"))
    value = args[index + 1]
    startswith(value, "-") && throw(ArgumentError("CLI flag `$token` requires a value"))
    return token, value, index + 2
end

function _parse_pipeline_cli_integer(value::AbstractString, option::AbstractString)
    try
        return parse(Int, value)
    catch
        throw(ArgumentError("CLI flag `$option` requires an integer value"))
    end
end

function _print_pipeline_run_success(io::IO, result::PipelineRunResult)
    println(io, "Pipeline run completed.")
    println(io, "run_name=$(result.run_name)")
    println(io, "run_dir=$(result.run_dir)")
    println(io, "manifest=$(result.manifest_path)")
    return nothing
end
