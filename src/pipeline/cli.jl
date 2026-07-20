const _PIPELINE_MAIN_USAGE = """
Usage:
  epsilon run <config_path> [--output-dir <dir>] [--run-name <name>] [--dataset-path <path>]
              [--prior-samples <n>] [--curve-points <n>] [--draws <n>] [--tune <n>]
              [--chains <n>] [--cores <n>] [--random-seed <n>]
  epsilon --help

Commands:
  run      Execute the pipeline on one YAML config.

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

const _PIPELINE_CLI_INTEGER_KEYS = Set(
    (
        :prior_samples,
        :curve_points,
        :draws,
        :tune,
        :chains,
        :cores,
        :random_seed,
    )
)

const _PIPELINE_PRETTY_OUTPUT = Ref(false)

function _with_pipeline_pretty_output(f::Function)
    previous = _PIPELINE_PRETTY_OUTPUT[]
    _PIPELINE_PRETTY_OUTPUT[] = true
    try
        return f()
    finally
        _PIPELINE_PRETTY_OUTPUT[] = previous
    end
end

_pipeline_pretty_output_enabled() = _PIPELINE_PRETTY_OUTPUT[]

"""
    pipeline_main(args = ARGS)

Run the Epsilon pipeline CLI.

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
        if _pipeline_pretty_output_enabled()
            _print_pipeline_run_failure(stderr, err)
        else
            println(stderr, "Error: $(sprint(showerror, err))")
        end
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
    if _pipeline_pretty_output_enabled()
        _print_pipeline_pretty_success(io, result)
        return nothing
    end

    println(io, "Pipeline run completed.")
    println(io, "run_name=$(result.run_name)")
    println(io, "run_dir=$(result.run_dir)")
    println(io, "manifest=$(result.manifest_path)")
    return nothing
end

function _print_pipeline_run_failure(io::IO, err)
    println(io, "")
    _pipeline_pretty_rule(io)
    _pipeline_pretty_label_value(io, "Status", "failed")
    _pipeline_pretty_label_value(io, "Error", sprint(showerror, err))
    _pipeline_pretty_rule(io)
    return nothing
end

function _print_pipeline_pretty_success(io::IO, result::PipelineRunResult)
    counts = _pipeline_stage_status_counts(result.stage_records)
    println(io, "")
    _pipeline_pretty_rule(io)
    _pipeline_pretty_label_value(io, "Status", String(result.status))
    _pipeline_pretty_label_value(io, "Run name", result.run_name)
    _pipeline_pretty_label_value(io, "Run dir", result.run_dir)
    _pipeline_pretty_label_value(io, "Manifest", result.manifest_path)
    _pipeline_pretty_label_value(io, "Stages", _pipeline_stage_status_summary(counts))
    _pipeline_pretty_rule(io)
    return nothing
end

function _pipeline_stage_status_counts(records)
    counts = Dict{Symbol, Int}()
    for record in records
        counts[record.status] = get(counts, record.status, 0) + 1
    end
    return counts
end

function _pipeline_stage_status_summary(counts::Dict{Symbol, Int})
    order = (:completed, :skipped, :failed, :not_reached, :pending, :running)
    parts = String[]
    for status in order
        value = get(counts, status, 0)
        value == 0 && continue
        push!(parts, "$(status)=$(value)")
    end
    return isempty(parts) ? "none" : join(parts, ", ")
end

function _pipeline_pretty_rule(io::IO)
    println(io, repeat("-", 72))
    return nothing
end

function _pipeline_pretty_label_value(io::IO, label::AbstractString, value)
    print(io, rpad(String(label), 12))
    print(io, " : ")
    println(io, value)
    return nothing
end

function _pipeline_pretty_stage_started(context::PipelineContext, key::AbstractString)
    _pipeline_pretty_output_enabled() || return nothing
    try
        index = _stage_index(context, key)
        total = length(context.stage_records)
        record = context.stage_records[index]
        position = _pipeline_stage_position(index, total)
        println(
            stdout,
            "$(_pipeline_progress_bar(index - 1, total)) $position RUNNING   $(rpad(record.key, 18)) $(record.directory)",
        )
    catch
        return nothing
    end
    return nothing
end

function _pipeline_pretty_stage_completed(context::PipelineContext, key::AbstractString)
    _pipeline_pretty_output_enabled() || return nothing
    try
        index = _stage_index(context, key)
        total = length(context.stage_records)
        record = context.stage_records[index]
        artifacts = length(record.artifact_paths)
        warnings = length(record.warnings)
        position = _pipeline_stage_position(index, total)
        suffix = warnings == 0 ?
            "$(artifacts) artifact(s)" : "$(artifacts) artifact(s), $(warnings) warning(s)"
        println(
            stdout,
            "$(_pipeline_progress_bar(index, total)) $position DONE      $(rpad(record.key, 18)) $(suffix)",
        )
    catch
        return nothing
    end
    return nothing
end

function _pipeline_pretty_stage_failed(context::PipelineContext, key::AbstractString, err)
    _pipeline_pretty_output_enabled() || return nothing
    try
        index = _stage_index(context, key)
        total = length(context.stage_records)
        record = context.stage_records[index]
        position = _pipeline_stage_position(index, total)
        println(
            stderr,
            "$(_pipeline_progress_bar(index, total)) $position FAILED    $(rpad(record.key, 18)) $(sprint(showerror, err))",
        )
    catch
        return nothing
    end
    return nothing
end

function _pipeline_stage_position(index::Integer, total::Integer)
    width = max(length(string(index)), length(string(total)), 2)
    return "$(lpad(string(index), width))/$(lpad(string(total), width))"
end

function _pipeline_progress_bar(done::Integer, total::Integer; width::Integer = 18)
    total > 0 || return "[" * repeat("-", width) * "]"
    clamped_done = clamp(Int(done), 0, Int(total))
    filled = floor(Int, width * clamped_done / Int(total))
    return "[" * repeat("#", filled) * repeat("-", width - filled) * "]"
end
