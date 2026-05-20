#!/usr/bin/env julia

import Pkg

Pkg.activate(@__DIR__; io = devnull)

const _ROOT_DIR = normpath(joinpath(@__DIR__, ".."))
_ROOT_DIR in LOAD_PATH || pushfirst!(LOAD_PATH, _ROOT_DIR)

using BenchmarkTools
using CSV
using DataFrames
using Dates
using JSON3
using Logging
using Statistics
using TOML

using Epsilon

const _MICRO_BENCHMARK_IDS = ["B-T1-CONV", "B-T2-GEOM", "B-T3-WEIBULL", "B-T4-HILL", "B-T5-SCALING"]
const _WORKFLOW_BENCHMARK_IDS = ["B-W1-FIT", "B-W2-GROUPED", "B-W3-POSTMODEL", "B-W4-PIPELINE"]
const _ALL_BENCHMARK_IDS = vcat(_MICRO_BENCHMARK_IDS, _WORKFLOW_BENCHMARK_IDS)
const _MICRO_PROTOCOL = Dict(
    "warmup_runs_discarded" => 1,
    "evals" => 1,
    "samples" => 50,
    "metrics" => ["median_time_ns", "memory_bytes", "allocations"],
)
const _WORKFLOW_PROTOCOL = Dict(
    "warmup_runs_discarded" => 1,
    "timed_repetitions" => 3,
    "random_seed" => 7,
    "chains" => 2,
    "draws" => 120,
    "tune" => 60,
    "target_accept" => 0.85,
    "metrics" => ["median_wall_time_sec", "median_peak_rss_kb", "median_bulk_ess_per_sec"],
)
const _WORKFLOW_OVERRIDES = Dict(
    "fit" => Dict(
        "draws" => _WORKFLOW_PROTOCOL["draws"],
        "tune" => _WORKFLOW_PROTOCOL["tune"],
        "chains" => _WORKFLOW_PROTOCOL["chains"],
        "target_accept" => _WORKFLOW_PROTOCOL["target_accept"],
        "random_seed" => _WORKFLOW_PROTOCOL["random_seed"],
        "progressbar" => false,
    ),
)
const _WORKFLOW_RESULTS_SCHEMA_VERSION = 1
const _WORKFLOW_GRID_POINTS = 51
const _TIME_MARKER = "__EPSILON_BENCH_TIME__"

function _workflow_settings(target_accept::Real)
    return Dict(
        "random_seed" => _WORKFLOW_PROTOCOL["random_seed"],
        "chains" => _WORKFLOW_PROTOCOL["chains"],
        "draws" => _WORKFLOW_PROTOCOL["draws"],
        "tune" => _WORKFLOW_PROTOCOL["tune"],
        "target_accept" => Float64(target_accept),
    )
end

function main(args::Vector{String} = copy(ARGS))
    parsed = _parse_args(args)
    if parsed["worker"]
        payload = _run_workflow_worker(parsed["worker_id"], parsed["prepared_dir"])
        println(JSON3.write(payload; allow_inf = true))
        return nothing
    end

    selected_ids = isempty(parsed["ids"]) ? copy(_ALL_BENCHMARK_IDS) : parsed["ids"]
    case_specs = TOML.parsefile(joinpath(@__DIR__, "inputs", "transform_cases.toml"))
    needs_workflow_inputs = any(id -> id in _WORKFLOW_BENCHMARK_IDS, selected_ids)
    prepared_dir = needs_workflow_inputs ? _prepare_workflow_inputs() : nothing

    try
        benchmarks = Any[]
        for benchmark_id in selected_ids
            push!(
                benchmarks,
                benchmark_id in _MICRO_BENCHMARK_IDS ?
                _run_micro_benchmark(benchmark_id, case_specs) :
                _run_workflow_benchmark(benchmark_id, prepared_dir),
            )
        end

        snapshot = Dict(
            "schema_version" => 1,
            "generated_at_utc" => Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ"),
            "machine" => _machine_metadata(),
            "environment" => _environment_metadata(),
            "protocol" => Dict(
                "micro" => _MICRO_PROTOCOL,
                "workflow" => _WORKFLOW_PROTOCOL,
            ),
            "benchmarks" => benchmarks,
        )

        _write_snapshot(parsed["json_path"], parsed["markdown_path"], snapshot)
    finally
        !isnothing(prepared_dir) && isdir(prepared_dir) && rm(prepared_dir; recursive = true, force = true)
    end

    return nothing
end

function _parse_args(args::Vector{String})
    parsed = Dict{String, Any}(
        "json_path" => joinpath(_ROOT_DIR, "benchmark", "results", "reference_machine.json"),
        "markdown_path" => joinpath(_ROOT_DIR, "benchmark", "results", "reference_machine.md"),
        "ids" => String[],
        "worker" => false,
        "worker_id" => nothing,
        "prepared_dir" => nothing,
    )

    index = 1
    while index <= length(args)
        token = args[index]
        if token == "--reference-machine"
            parsed["json_path"] = joinpath(_ROOT_DIR, "benchmark", "results", "reference_machine.json")
            parsed["markdown_path"] = joinpath(_ROOT_DIR, "benchmark", "results", "reference_machine.md")
            index += 1
        elseif token == "--json-path"
            parsed["json_path"] = args[index + 1]
            index += 2
        elseif token == "--markdown-path"
            parsed["markdown_path"] = args[index + 1]
            index += 2
        elseif token == "--ids"
            parsed["ids"] = [strip(id) for id in split(args[index + 1], ',') if !isempty(strip(id))]
            index += 2
        elseif token == "--worker"
            parsed["worker"] = true
            parsed["worker_id"] = args[index + 1]
            index += 2
        elseif token == "--prepared-dir"
            parsed["prepared_dir"] = args[index + 1]
            index += 2
        else
            throw(ArgumentError("unknown benchmark argument `$token`"))
        end
    end

    selected_ids = parsed["ids"]
    all(id -> id in _ALL_BENCHMARK_IDS, selected_ids) ||
        throw(ArgumentError("benchmark IDs must belong to the frozen Phase 11 matrix"))

    if parsed["worker"]
        isnothing(parsed["worker_id"]) &&
            throw(ArgumentError("--worker requires a frozen benchmark ID"))
        parsed["worker_id"] in _WORKFLOW_BENCHMARK_IDS ||
            throw(ArgumentError("--worker supports only workflow benchmark IDs"))
        isnothing(parsed["prepared_dir"]) &&
            throw(ArgumentError("--worker requires --prepared-dir"))
    end

    return parsed
end

function _prepare_workflow_inputs()
    prepared_dir = mktempdir()
    model = _load_time_series_benchmark_model("ts00_mcmc")
    _quietly() do
        fit!(model)
    end
    grouped = _quietly() do
        inference_results(model)
    end

    model_path = joinpath(prepared_dir, "ts00_model.jls")
    grouped_path = joinpath(prepared_dir, "ts00_grouped.jls")
    metadata_path = joinpath(prepared_dir, "workflow_metadata.json")

    save_model(model_path, model)
    save_inference_results(grouped_path, grouped)

    channel = first(grouped.spec.channel_columns)
    observed_total_spend = sum(grouped.observed_data.channels[:, 1])
    grid = collect(range(0.25 * observed_total_spend, stop = 1.75 * observed_total_spend, length = _WORKFLOW_GRID_POINTS))
    metadata = Dict(
        "schema_version" => _WORKFLOW_RESULTS_SCHEMA_VERSION,
        "model_path" => model_path,
        "grouped_path" => grouped_path,
        "channel" => channel,
        "grid" => grid,
        "optimization_total_budget" => sum(grouped.observed_data.channels),
    )
    _write_json(metadata_path, metadata)
    return prepared_dir
end

function _workflow_metadata(prepared_dir::AbstractString)
    payload = JSON3.read(read(joinpath(prepared_dir, "workflow_metadata.json"), String))
    Dict(String(key) => _plain_json(value) for (key, value) in pairs(payload))
end

function _plain_json(value)
    if value isa JSON3.Object
        return Dict(String(key) => _plain_json(item) for (key, item) in pairs(value))
    elseif value isa JSON3.Array
        return [_plain_json(item) for item in value]
    end
    return value
end

function _run_micro_benchmark(benchmark_id::AbstractString, case_specs::Dict{String, Any})
    if benchmark_id == "B-T1-CONV"
        spec = case_specs["conv_3d_overlap"]
        payload = _conv_case(spec)
        Epsilon.batched_convolution(payload["x"], payload["w"], payload["axis"], payload["mode"])
        bench = @benchmarkable Epsilon.batched_convolution(
            $(payload["x"]),
            $(payload["w"]),
            $(payload["axis"]),
            $(payload["mode"]),
        ) evals = 1 samples = 50
        input_identity = "benchmark/inputs/transform_cases.toml::conv_3d_overlap"
        workload = "batched_convolution representative 3D overlap/add case"
    elseif benchmark_id == "B-T2-GEOM"
        spec = case_specs["geometric_adstock_matrix"]
        payload = _matrix_adstock_case(spec)
        Epsilon.geometric_adstock(
            payload["x"],
            payload["alpha"],
            payload["l_max"];
            normalize = payload["normalize"],
            axis = payload["axis"],
            mode = payload["mode"],
        )
        bench = @benchmarkable Epsilon.geometric_adstock(
            $(payload["x"]),
            $(payload["alpha"]),
            $(payload["l_max"]);
            normalize = $(payload["normalize"]),
            axis = $(payload["axis"]),
            mode = $(payload["mode"]),
        ) evals = 1 samples = 50
        input_identity = "benchmark/inputs/transform_cases.toml::geometric_adstock_matrix"
        workload = "geometric adstock representative matrix case"
    elseif benchmark_id == "B-T3-WEIBULL"
        spec = case_specs["weibull_pdf_matrix"]
        payload = _weibull_case(spec)
        Epsilon.weibull_adstock(
            payload["x"],
            payload["lam"],
            payload["k"],
            payload["l_max"];
            normalize = payload["normalize"],
            axis = payload["axis"],
            mode = payload["mode"],
            type = payload["type"],
        )
        bench = @benchmarkable Epsilon.weibull_adstock(
            $(payload["x"]),
            $(payload["lam"]),
            $(payload["k"]),
            $(payload["l_max"]);
            normalize = $(payload["normalize"]),
            axis = $(payload["axis"]),
            mode = $(payload["mode"]),
            type = $(payload["type"]),
        ) evals = 1 samples = 50
        input_identity = "benchmark/inputs/transform_cases.toml::weibull_pdf_matrix"
        workload = "Weibull PDF adstock representative matrix case"
    elseif benchmark_id == "B-T4-HILL"
        spec = case_specs["hill_vector"]
        payload = _hill_case(spec)
        Epsilon.hill_function(payload["x"], payload["slope"], payload["kappa"])
        bench = @benchmarkable Epsilon.hill_function(
            $(payload["x"]),
            $(payload["slope"]),
            $(payload["kappa"]),
        ) evals = 1 samples = 50
        input_identity = "benchmark/inputs/transform_cases.toml::hill_vector"
        workload = "Hill saturation representative vector case"
    elseif benchmark_id == "B-T5-SCALING"
        spec = case_specs["standardize_controls_matrix"]
        payload = _scaling_case(spec)
        Epsilon.fit_transform!(Epsilon.StandardScaler(), payload["x"])
        bench = @benchmarkable Epsilon.fit_transform!(Epsilon.StandardScaler(), $(payload["x"])) evals = 1 samples = 50
        input_identity = "benchmark/inputs/transform_cases.toml::standardize_controls_matrix"
        workload = "standardization / scaling representative matrix case"
    else
        throw(ArgumentError("unknown micro benchmark ID `$benchmark_id`"))
    end

    trial = run(bench)
    estimate = median(trial)
    return Dict(
        "id" => String(benchmark_id),
        "kind" => "micro",
        "workload" => workload,
        "input_identity" => input_identity,
        "warmup_policy" => "one warmup invocation discarded",
        "metrics" => Dict(
            "median_time_ns" => round(Int, estimate.time),
            "memory_bytes" => round(Int, estimate.memory),
            "allocations" => round(Int, estimate.allocs),
        ),
    )
end

function _run_workflow_benchmark(
    benchmark_id::AbstractString,
    prepared_dir::AbstractString,
)
    _run_workflow_process(benchmark_id, prepared_dir)
    timed_runs = [_run_workflow_process(benchmark_id, prepared_dir) for _ in 1:Int(_WORKFLOW_PROTOCOL["timed_repetitions"])]

    wall_times = [run["wall_time_sec"] for run in timed_runs]
    rss_values = [run["peak_rss_kb"] for run in timed_runs if run["peak_rss_kb"] !== nothing]
    ess_values = [
        run["payload"]["bulk_ess"] for run in timed_runs
        if haskey(run["payload"], "bulk_ess") && run["payload"]["bulk_ess"] !== nothing
    ]
    ess_per_sec_values = isempty(ess_values) ? Float64[] :
        [
            run["payload"]["bulk_ess"] / run["wall_time_sec"] for run in timed_runs
            if haskey(run["payload"], "bulk_ess") && run["payload"]["bulk_ess"] !== nothing
        ]

    first_payload = timed_runs[1]["payload"]
    metrics = Dict{String, Any}(
        "median_wall_time_sec" => median(wall_times),
        "median_peak_rss_kb" => isempty(rss_values) ? nothing : round(Int, median(rss_values)),
        "median_bulk_ess_per_sec" => isempty(ess_per_sec_values) ? nothing : median(ess_per_sec_values),
    )
    !isempty(ess_values) && (metrics["median_bulk_ess"] = median(ess_values))

    return Dict(
        "id" => String(benchmark_id),
        "kind" => "workflow",
        "workload" => first_payload["workload"],
        "input_identity" => first_payload["input_identity"],
        "warmup_policy" => "one warmup run discarded",
        "workflow_settings" => get(
            first_payload,
            "workflow_settings",
            _workflow_settings(_WORKFLOW_PROTOCOL["target_accept"]),
        ),
        "metrics" => metrics,
        "timed_runs" => [
            Dict(
                "wall_time_sec" => run["wall_time_sec"],
                "peak_rss_kb" => run["peak_rss_kb"],
                "bulk_ess" => get(run["payload"], "bulk_ess", nothing),
            ) for run in timed_runs
        ],
        "notes" => get(first_payload, "notes", String[]),
    )
end

function _run_workflow_process(benchmark_id::AbstractString, prepared_dir::AbstractString)
    benchmark_dir = @__DIR__
    worker_script = joinpath(benchmark_dir, "run_benchmarks.jl")
    julia_cmd = Base.julia_cmd()
    worker_cmd = `$julia_cmd --project=$benchmark_dir $worker_script --worker $benchmark_id --prepared-dir $prepared_dir`

    time_binary = "/usr/bin/time"
    if isfile(time_binary)
        wrapped = `$time_binary -f "$(_TIME_MARKER) %e %M" $worker_cmd`
        stdout_text, stderr_text, success = _capture_command(wrapped)
        success ||
            error(
                "workflow benchmark `$benchmark_id` worker failed\nstdout:\n$stdout_text\nstderr:\n$stderr_text",
            )
        wall_time_sec, peak_rss_kb = _parse_time_output(stderr_text)
    else
        started = time()
        stdout_text, stderr_text, success = _capture_command(worker_cmd)
        success ||
            error(
                "workflow benchmark `$benchmark_id` worker failed\nstdout:\n$stdout_text\nstderr:\n$stderr_text",
            )
        wall_time_sec = time() - started
        peak_rss_kb = nothing
    end

    payload = _plain_json(JSON3.read(stdout_text))
    return Dict(
        "wall_time_sec" => wall_time_sec,
        "peak_rss_kb" => peak_rss_kb,
        "payload" => payload,
    )
end

function _capture_command(cmd::Cmd)
    stdout_buffer = IOBuffer()
    stderr_buffer = IOBuffer()
    process = run(pipeline(ignorestatus(cmd); stdout = stdout_buffer, stderr = stderr_buffer); wait = false)
    wait(process)
    return String(take!(stdout_buffer)), String(take!(stderr_buffer)), success(process)
end

function _parse_time_output(stderr_text::AbstractString)
    for line in reverse(split(stderr_text, '\n'))
        startswith(line, _TIME_MARKER) || continue
        parts = split(line)
        length(parts) == 3 || break
        return parse(Float64, parts[2]), parse(Int, parts[3])
    end
    return nothing, nothing
end

function _run_workflow_worker(
    benchmark_id::AbstractString,
    prepared_dir::AbstractString,
)
    metadata = _workflow_metadata(prepared_dir)
    if benchmark_id == "B-W1-FIT"
        model = _load_time_series_benchmark_model("ts00_mcmc")
        _quietly() do
            fit!(model)
        end
        diagnostics = model_diagnostics(model)
        return Dict(
            "workload" => "time-series MCMC fit wall-clock",
            "input_identity" => "VAL-TS-00-MCMC",
            "bulk_ess" => _median_bulk_ess(diagnostics),
            "workflow_settings" => _workflow_settings(model.sampler_config.target_accept),
        )
    elseif benchmark_id == "B-W2-GROUPED"
        model = load_model(metadata["model_path"])
        grouped = _quietly() do
            inference_results(model)
        end
        diagnostics = model_diagnostics(model)
        return Dict(
            "workload" => "inference_results materialization",
            "input_identity" => "fitted artifact from B-W1-FIT",
            "bulk_ess" => _median_bulk_ess(diagnostics),
            "posterior_parameter_count" => grouped.posterior === nothing ? 0 : length(names(grouped.posterior, :parameters)),
            "workflow_settings" => _workflow_settings(model.sampler_config.target_accept),
        )
    elseif benchmark_id == "B-W3-POSTMODEL"
        grouped = load_inference_results(metadata["grouped_path"])
        channel = metadata["channel"]
        grid = Float64.(metadata["grid"])
        curves = response_curve_results(grouped; channel, grid)
        metrics = metric_results(curves)
        optimization = _silence_stdout() do
            optimize_budget(grouped; total_budget = metadata["optimization_total_budget"])
        end
        curve_table = summary_table(curves)
        metric_table = summary_table(metrics)
        impact_table = budget_impact_table(optimization)
        audit_table = budget_audit_table(optimization)
        return Dict(
            "workload" => "response / metric / optimization representative path",
            "input_identity" => "grouped artifact from B-W1-FIT",
            "channel" => channel,
            "grid_points" => length(grid),
            "curve_rows" => nrow(curve_table),
            "metric_rows" => nrow(metric_table),
            "impact_rows" => nrow(impact_table),
            "audit_rows" => nrow(audit_table),
            "notes" => [
                "Uses the first modeled channel and a fixed 51-point spend grid spanning 25%-175% of observed total channel spend.",
                "Optimization uses the default Phase 8 objective with the observed total spend as the fixed budget.",
            ],
            "workflow_settings" => _workflow_settings(_WORKFLOW_PROTOCOL["target_accept"]),
        )
    elseif benchmark_id == "B-W4-PIPELINE"
        case_dir = joinpath(_ROOT_DIR, "test", "fixtures", "abacus", "validation", "pipeline_ts00_mcmc")
        output_dir = mktempdir()
        try
            result = _silence_stdout() do
                _quietly() do
                    run_pipeline(
                        PipelineRunConfig(
                            config_path = joinpath(case_dir, "config.yml"),
                            output_dir = output_dir,
                            run_name = "benchmark_pipeline",
                            draws = Int(_WORKFLOW_PROTOCOL["draws"]),
                            tune = Int(_WORKFLOW_PROTOCOL["tune"]),
                            chains = Int(_WORKFLOW_PROTOCOL["chains"]),
                            random_seed = Int(_WORKFLOW_PROTOCOL["random_seed"]),
                        ),
                    )
                end
            end
            model_path = joinpath(result.run_dir, "20_model_fit", "model.jls")
            model = load_model(model_path)
            diagnostics = model_diagnostics(model)
            return Dict(
                "workload" => "full pipeline wall-clock",
                "input_identity" => "VAL-PIPE-TS-00-MCMC",
                "bulk_ess" => _median_bulk_ess(diagnostics),
                "run_status" => String(result.status),
                "completed_stage_count" => count(record -> record.status == :completed, result.stage_records),
                "workflow_settings" => _workflow_settings(model.sampler_config.target_accept),
                "notes" => [
                    "This pipeline row inherits sampler settings from the frozen pipeline fixture YAML.",
                    "The bounded pipeline API does not expose a target_accept override, so this row currently runs with target_accept = $(model.sampler_config.target_accept).",
                ],
            )
        finally
            rm(output_dir; recursive = true, force = true)
        end
    end

    throw(ArgumentError("unknown workflow benchmark ID `$benchmark_id`"))
end

function _load_time_series_benchmark_model(slug::AbstractString)
    case_dir = joinpath(_ROOT_DIR, "test", "fixtures", "abacus", "validation", slug)
    loaded = load_public_config(joinpath(case_dir, "config.yml"); overrides = _WORKFLOW_OVERRIDES)
    dataset_path = joinpath(case_dir, "dataset.csv")
    frame = CSV.read(dataset_path, DataFrame; normalizenames = false)
    parsed_dates = _parse_case_dates(frame[!, loaded.model_config.date_column])
    order = sortperm(parsed_dates)

    controls = isempty(loaded.model_config.control_columns) ? nothing :
               Matrix{Float64}(frame[order, loaded.model_config.control_columns])
    event_columns = get(loaded.model_config.events, "columns", String[])
    events = isempty(event_columns) ? nothing : Matrix{Float64}(frame[order, event_columns])

    data = MMMData(
        dates = parsed_dates[order],
        target = Float64.(frame[order, loaded.model_config.target_column]),
        channels = Matrix{Float64}(frame[order, loaded.model_config.channel_columns]),
        channel_names = copy(loaded.model_config.channel_columns),
        controls = controls,
        control_names = copy(loaded.model_config.control_columns),
        events = events,
        event_names = copy(event_columns),
    )

    return TimeSeriesMMM(loaded.model_config, loaded.sampler_config, data)
end

function _parse_case_dates(values)
    parsed = Union{Date, DateTime}[]
    for value in values
        if value isa Date || value isa DateTime
            push!(parsed, value)
            continue
        end

        string_value = String(value)
        parsed_date = tryparse(Date, string_value)
        if !isnothing(parsed_date)
            push!(parsed, parsed_date)
            continue
        end

        parsed_datetime = tryparse(DateTime, string_value)
        isnothing(parsed_datetime) &&
            throw(ArgumentError("could not parse benchmark date value `$string_value`"))
        push!(parsed, parsed_datetime)
    end
    return parsed
end

function _median_bulk_ess(diagnostics::Epsilon.ModelDiagnostics)
    ess_values = Float64[]
    for parameter in values(diagnostics.parameter_diagnostics)
        ismissing(parameter.ess_bulk) && continue
        push!(ess_values, Float64(parameter.ess_bulk))
    end
    isempty(ess_values) && return nothing
    return median(ess_values)
end

function _conv_case(spec::AbstractDict)
    time = Int(spec["time"])
    channels = Int(spec["channels"])
    panels = Int(spec["panels"])
    lags = Int(spec["lags"])

    x = Array{Float64}(undef, time, channels, panels)
    for t in 1:time, channel in 1:channels, panel in 1:panels
        x[t, channel, panel] = Float64(spec["x_base"]) +
                               Float64(spec["x_time_step"]) * t +
                               Float64(spec["x_channel_step"]) * channel +
                               Float64(spec["x_panel_step"]) * panel
    end

    w = Array{Float64}(undef, channels, panels, lags)
    for channel in 1:channels, panel in 1:panels, lag in 1:lags
        w[channel, panel, lag] = (
            Float64(spec["w_base"]) +
            Float64(spec["w_channel_step"]) * channel +
            Float64(spec["w_panel_step"]) * panel
        ) * exp(-Float64(spec["w_decay"]) * (lag - 1))
    end

    return Dict(
        "x" => x,
        "w" => w,
        "axis" => Int(spec["axis"]),
        "mode" => String(spec["mode"]),
    )
end

function _matrix_case(rows::Integer, cols::Integer, base::Real, row_step::Real, col_step::Real)
    x = Array{Float64}(undef, rows, cols)
    for row in 1:rows, col in 1:cols
        x[row, col] = Float64(base) + Float64(row_step) * row + Float64(col_step) * col
    end
    return x
end

function _matrix_adstock_case(spec::AbstractDict)
    rows = Int(spec["rows"])
    cols = Int(spec["cols"])
    return Dict(
        "x" => _matrix_case(rows, cols, spec["x_base"], spec["x_row_step"], spec["x_col_step"]),
        "alpha" => Float64.(spec["alpha"]),
        "l_max" => Int(spec["l_max"]),
        "normalize" => Bool(spec["normalize"]),
        "axis" => Int(spec["axis"]),
        "mode" => String(spec["mode"]),
    )
end

function _weibull_case(spec::AbstractDict)
    rows = Int(spec["rows"])
    cols = Int(spec["cols"])
    return Dict(
        "x" => _matrix_case(rows, cols, spec["x_base"], spec["x_row_step"], spec["x_col_step"]),
        "lam" => Float64.(spec["lam"]),
        "k" => Float64.(spec["k"]),
        "l_max" => Int(spec["l_max"]),
        "normalize" => Bool(spec["normalize"]),
        "axis" => Int(spec["axis"]),
        "mode" => String(spec["mode"]),
        "type" => String(spec["type"]),
    )
end

function _hill_case(spec::AbstractDict)
    values = Float64[Float64(spec["x_base"]) + Float64(spec["x_step"]) * index for index in 1:Int(spec["length"])]
    return Dict(
        "x" => values,
        "slope" => Float64(spec["slope"]),
        "kappa" => Float64(spec["kappa"]),
    )
end

function _scaling_case(spec::AbstractDict)
    rows = Int(spec["rows"])
    cols = Int(spec["cols"])
    x = Array{Float64}(undef, rows, cols)
    for row in 1:rows, col in 1:cols
        x[row, col] = Float64(spec["x_base"]) +
                      Float64(spec["x_row_step"]) * row +
                      Float64(spec["x_col_step"]) * col +
                      Float64(spec["x_interaction_step"]) * row * col
    end
    return Dict("x" => x)
end

function _environment_metadata()
    return Dict(
        "julia_version" => string(VERSION),
        "epsilon_version" => string(Epsilon.epsilon_version()),
        "git_commit" => _git_output(["rev-parse", "HEAD"]),
        "git_dirty" => !_isempty_git_status(),
        "benchmark_project" => joinpath(_ROOT_DIR, "benchmark", "Project.toml"),
        "root_project" => joinpath(_ROOT_DIR, "Project.toml"),
    )
end

function _machine_metadata()
    return Dict(
        "hostname" => _hostname(),
        "kernel" => string(Sys.KERNEL),
        "arch" => string(Sys.ARCH),
        "cpu_threads" => Sys.CPU_THREADS,
        "julia_threads" => Threads.nthreads(),
        "cpu_name" => Sys.CPU_NAME,
        "total_memory_bytes" => Sys.total_memory(),
    )
end

function _hostname()
    try
        return readchomp(`hostname`)
    catch
        return "unknown"
    end
end

function _git_output(args::Vector{String})
    try
        return readchomp(Cmd(vcat(["git", "-C", _ROOT_DIR], args)))
    catch
        return "unknown"
    end
end

function _isempty_git_status()
    try
        return isempty(readchomp(`git -C $_ROOT_DIR status --short`))
    catch
        return false
    end
end

function _write_snapshot(
    json_path::AbstractString,
    markdown_path::AbstractString,
    snapshot::Dict{String, Any},
)
    mkpath(dirname(json_path))
    mkpath(dirname(markdown_path))
    _write_json(json_path, snapshot)
    write(markdown_path, _benchmark_markdown(snapshot))
    return nothing
end

function _write_json(path::AbstractString, payload)
    open(path, "w") do io
        write(io, JSON3.write(payload; allow_inf = true))
    end
    return path
end

function _quietly(f::Function)
    return Logging.with_logger(Logging.SimpleLogger(devnull, Logging.Error)) do
        f()
    end
end

function _silence_stdout(f::Function)
    return redirect_stdout(devnull) do
        f()
    end
end

function _benchmark_markdown(snapshot::Dict{String, Any})
    machine = snapshot["machine"]
    env = snapshot["environment"]
    micro_rows = String[]
    workflow_rows = String[]
    note_lines = String[
        "- Workflow timings use one discarded warmup run and three timed repetitions in separate Julia processes.",
        "- Peak RSS is reported only when `/usr/bin/time` is available on the reference machine.",
        "- This snapshot publishes measured Epsilon performance for the frozen v1 workload matrix. It does not make a blanket faster-than-Abacus claim.",
    ]

    for benchmark in snapshot["benchmarks"]
        if benchmark["kind"] == "micro"
            metrics = benchmark["metrics"]
            push!(
                micro_rows,
                "| `$(benchmark["id"])` | $(benchmark["workload"]) | `$(benchmark["input_identity"])` | $(metrics["median_time_ns"]) | $(metrics["memory_bytes"]) | $(metrics["allocations"]) |",
            )
        else
            metrics = benchmark["metrics"]
            peak_rss = isnothing(metrics["median_peak_rss_kb"]) ? "n/a" : string(metrics["median_peak_rss_kb"])
            ess_per_sec = isnothing(metrics["median_bulk_ess_per_sec"]) ? "n/a" : string(round(metrics["median_bulk_ess_per_sec"]; digits = 3))
            push!(
                workflow_rows,
                "| `$(benchmark["id"])` | $(benchmark["workload"]) | `$(benchmark["input_identity"])` | $(round(metrics["median_wall_time_sec"]; digits = 3)) | $peak_rss | $ess_per_sec |",
            )
            for note in get(benchmark, "notes", Any[])
                push!(note_lines, "- `$(benchmark["id"])`: $(note)")
            end
        end
    end

    env["git_dirty"] && push!(
        note_lines,
        "- This committed snapshot was captured from a dirty worktree; rerun the benchmark suite from a clean tagged worktree for the final release artifact.",
    )

    return """
# Reference Machine Benchmark Snapshot

Generated at `$(snapshot["generated_at_utc"])`.

## Machine

- Hostname: `$(machine["hostname"])`
- OS / arch: `$(machine["kernel"]) / $(machine["arch"])`
- CPU: `$(machine["cpu_name"])`
- CPU threads: `$(machine["cpu_threads"])`
- Julia threads: `$(machine["julia_threads"])`
- Total memory bytes: `$(machine["total_memory_bytes"])`

## Environment

- Julia: `$(env["julia_version"])`
- Epsilon: `$(env["epsilon_version"])`
- Git commit: `$(env["git_commit"])`
- Dirty worktree: `$(env["git_dirty"])`

## Micro Benchmarks

| ID | Workload | Input | Median Time (ns) | Memory (bytes) | Allocations |
|---|---|---|---:|---:|---:|
$(join(micro_rows, "\n"))

## Workflow Benchmarks

| ID | Workload | Input | Median Wall Time (s) | Median Peak RSS (KB) | Median Bulk ESS/sec |
|---|---|---|---:|---:|---:|
$(join(workflow_rows, "\n"))

## Notes

$(join(note_lines, "\n"))
"""
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    main()
end
