#!/usr/bin/env julia

using Dates
using Epsilon
using JSON3
using Profile

const _DEFAULT_CONFIG = joinpath(@__DIR__, "..", "data", "demo", "timeseries", "config.yml")

function _usage()
    return """
    Usage:
      julia --project=. scripts/profile_fit.jl [config.yml] [options]

    Options:
      --output-dir DIR       Output directory root. Default: results/performance
      --run-name NAME        Run directory name. Default: profile_fit_<timestamp>
      --draws N              Posterior draws for the profiled fit. Default: config value
      --tune N               Warmup/adaptation iterations. Default: config value
      --chains N             Number of chains. Default: 1
      --cores N              Requested cores. Default: 1
      --random-seed N        Random seed. Default: config value or 20260720
      --warmup-draws N       Compile warmup draws. Default: 1
      --warmup-tune N        Compile warmup tune. Default: 1
      --no-profile           Time the direct fit without writing a Profile tree
      --help                 Show this help text
    """
end

function _parse_optional_int(value, name::AbstractString)
    isnothing(value) && return nothing
    try
        parsed = parse(Int, String(value))
        parsed > 0 || throw(ArgumentError("$name must be positive"))
        return parsed
    catch err
        err isa ArgumentError && rethrow()
        throw(ArgumentError("$name must be an integer"))
    end
end

function _parse_args(args::Vector{String})
    options = Dict{String, Any}(
        "config_path" => _DEFAULT_CONFIG,
        "output_dir" => joinpath("results", "performance"),
        "run_name" => nothing,
        "draws" => nothing,
        "tune" => nothing,
        "chains" => 1,
        "cores" => 1,
        "random_seed" => nothing,
        "warmup_draws" => 1,
        "warmup_tune" => 1,
        "profile" => true,
    )
    positionals = String[]
    index = 1
    while index <= length(args)
        arg = args[index]
        if arg == "--help"
            println(_usage())
            exit(0)
        elseif arg == "--no-profile"
            options["profile"] = false
            index += 1
        elseif arg in (
                "--output-dir",
                "--run-name",
                "--draws",
                "--tune",
                "--chains",
                "--cores",
                "--random-seed",
                "--warmup-draws",
                "--warmup-tune",
            )
            index < length(args) || throw(ArgumentError("$arg requires a value"))
            key = replace(arg[3:end], "-" => "_")
            options[key] = args[index + 1]
            index += 2
        elseif startswith(arg, "--")
            throw(ArgumentError("unknown option: $arg"))
        else
            push!(positionals, arg)
            index += 1
        end
    end
    length(positionals) <= 1 || throw(ArgumentError("expected at most one config path"))
    isempty(positionals) || (options["config_path"] = only(positionals))

    for key in ("draws", "tune", "chains", "cores", "random_seed", "warmup_draws", "warmup_tune")
        options[key] = _parse_optional_int(options[key], "--" * replace(key, "_" => "-"))
    end
    return options
end

function _sampler_config(base::SamplerConfig, options::Dict{String, Any})
    return SamplerConfig(
        draws = something(options["draws"], base.draws),
        tune = something(options["tune"], base.tune),
        chains = something(options["chains"], base.chains),
        cores = something(options["cores"], base.cores),
        target_accept = base.target_accept,
        random_seed = something(options["random_seed"], something(base.random_seed, 20260720)),
        progressbar = false,
        compute_convergence_checks = false,
    )
end

function _warmup_sampler_config(base::SamplerConfig, options::Dict{String, Any})
    return SamplerConfig(
        draws = options["warmup_draws"],
        tune = options["warmup_tune"],
        chains = 1,
        cores = 1,
        target_accept = base.target_accept,
        random_seed = 99,
        progressbar = false,
        compute_convergence_checks = false,
    )
end

function _load_direct_model(config_path::AbstractString, sampler_config::SamplerConfig)
    temp_output_dir = mktempdir()
    run_config = PipelineRunConfig(
        config_path = config_path,
        output_dir = temp_output_dir,
        run_name = "profile-fit-load",
        draws = sampler_config.draws,
        tune = sampler_config.tune,
        chains = sampler_config.chains,
        cores = sampler_config.cores,
        random_seed = sampler_config.random_seed,
    )
    try
        loaded = Epsilon._load_pipeline_configuration(run_config)
        context = Epsilon._pipeline_context(run_config, loaded)
        data = Epsilon._load_pipeline_dataset(context)
        return TimeSeriesMMM(loaded.model_config, sampler_config, data)
    finally
        rm(temp_output_dir; recursive = true, force = true)
    end
end

function _write_profile_artifacts(outdir::AbstractString, model::TimeSeriesMMM, elapsed::Float64)
    mkpath(outdir)
    summary = Dict{String, Any}(
        "elapsed_seconds" => elapsed,
        "draws" => model.sampler_config.draws,
        "tune" => model.sampler_config.tune,
        "chains" => model.sampler_config.chains,
        "cores" => model.sampler_config.cores,
        "threads" => Threads.nthreads(),
        "fit_message" => model.fit_state.message,
        "generated_at_utc" => string(now(UTC)),
    )
    open(joinpath(outdir, "summary.json"), "w") do io
        JSON3.pretty(io, summary)
        println(io)
    end
    open(joinpath(outdir, "summary.csv"), "w") do io
        println(io, "metric,value")
        for key in sort!(collect(keys(summary)))
            println(io, key, ",", _csv_cell(summary[key]))
        end
    end
    return summary
end

function _csv_cell(value)
    text = string(value)
    escaped = replace(text, "\"" => "\"\"")
    return occursin(r"[,\n\"]", escaped) ? "\"$escaped\"" : escaped
end

function main(args = ARGS)
    options = _parse_args(args)
    config_path = abspath(options["config_path"])
    isfile(config_path) || throw(ArgumentError("config file does not exist: $config_path"))

    timestamp = Dates.format(now(), dateformat"yyyymmdd_HHMMSS")
    run_name = isnothing(options["run_name"]) ? "profile_fit_$timestamp" : String(options["run_name"])
    outdir = abspath(joinpath(String(options["output_dir"]), run_name))
    mkpath(outdir)

    loaded = Epsilon._load_pipeline_configuration(PipelineRunConfig(config_path = config_path))
    sampler_config = _sampler_config(loaded.sampler_config, options)
    warmup_config = _warmup_sampler_config(loaded.sampler_config, options)

    println("Epsilon direct fit profile")
    println("config: ", config_path)
    println("output: ", outdir)
    println("threads: ", Threads.nthreads())
    println("draws/tune/chains/cores: ", sampler_config.draws, "/", sampler_config.tune, "/", sampler_config.chains, "/", sampler_config.cores)

    warmup_model = _load_direct_model(config_path, warmup_config)
    fit!(warmup_model)

    model = _load_direct_model(config_path, sampler_config)
    elapsed = if options["profile"]
        Profile.clear()
        timed = @elapsed @profile fit!(model)
        open(joinpath(outdir, "profile_tree.txt"), "w") do io
            Profile.print(io; maxdepth = 30, mincount = 2)
        end
        timed
    else
        @elapsed fit!(model)
    end

    summary = _write_profile_artifacts(outdir, model, elapsed)
    println("elapsed_seconds: ", summary["elapsed_seconds"])
    println("summary: ", joinpath(outdir, "summary.json"))
    options["profile"] && println("profile: ", joinpath(outdir, "profile_tree.txt"))
    return nothing
end

if abspath(PROGRAM_FILE) == @__FILE__
    try
        main()
    catch err
        showerror(stderr, err)
        println(stderr)
        exit(1)
    end
end
