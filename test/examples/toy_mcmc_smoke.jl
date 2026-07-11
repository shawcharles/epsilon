using Test

include(joinpath(@__DIR__, "..", "..", "examples", "toy_mmm", "run_toy_mmm.jl"))

function _argument_error_message(f)
    try
        f()
    catch err
        @test err isa ArgumentError
        return sprint(showerror, err)
    end
    error("expected ArgumentError")
end

@testset "toy MMM CLI parsing" begin
    default_options = _parse_toy_cli(String[])
    @test default_options["draws"] == _TOY_DEFAULT_DRAWS
    @test default_options["tune"] == _TOY_DEFAULT_TUNE
    @test default_options["seed"] == _TOY_DEFAULT_SEED
    @test isnothing(default_options["output_dir"])
    @test get(default_options, "help", false) == false

    parsed_options = _parse_toy_cli(
        [
            "--draws",
            "11",
            "--tune",
            "12",
            "--seed",
            "13",
            "--output-dir",
            "toy-output",
        ]
    )
    @test parsed_options["draws"] == 11
    @test parsed_options["tune"] == 12
    @test parsed_options["seed"] == 13
    @test parsed_options["output_dir"] == "toy-output"

    help_options = _parse_toy_cli(["--help"])
    @test help_options["help"] == true
    short_help_options = _parse_toy_cli(["-h"])
    @test short_help_options["help"] == true

    for option in ("--draws", "--tune", "--seed", "--output-dir")
        message = _argument_error_message(() -> _parse_toy_cli([option]))
        @test occursin(option, message)
        @test occursin("requires a value", message)
    end

    for option in ("--draws", "--tune", "--seed")
        message = _argument_error_message(() -> _parse_toy_cli([option, "not-an-int"]))
        @test occursin(option, message)
        @test occursin("not-an-int", message)
        @test occursin("integer", message)

        overflow_value = "999999999999999999999999999999999999999"
        overflow_message = _argument_error_message(() -> _parse_toy_cli([option, overflow_value]))
        @test occursin(option, overflow_message)
        @test occursin(overflow_value, overflow_message)
        @test occursin("integer", overflow_message)
    end

    unknown_message = _argument_error_message(() -> _parse_toy_cli(["--bad-option"]))
    @test occursin("unknown argument", unknown_message)
    @test occursin("--bad-option", unknown_message)
end

@testset "toy MMM help and include safety do not run MCMC" begin
    repo_root = normpath(joinpath(@__DIR__, "..", ".."))
    script_path = joinpath(repo_root, "examples", "toy_mmm", "run_toy_mmm.jl")

    help_output = read(
        `$(Base.julia_cmd()) --project=$(repo_root) $(script_path) --help`,
        String,
    )
    @test occursin("Usage:", help_output)
    @test occursin("--draws", help_output)
    @test !occursin("status=", help_output)
    @test !occursin("backend=", help_output)

    mktemp() do _, stderr_io
        overflow_value = "999999999999999999999999999999999999999"
        command = `$(Base.julia_cmd()) --project=$(repo_root) $(script_path) --draws $(overflow_value)`
        process = run(pipeline(ignorestatus(command), stdout = devnull, stderr = stderr_io))
        flush(stderr_io)
        seekstart(stderr_io)
        stderr_output = read(stderr_io, String)

        @test !success(process)
        @test occursin("ArgumentError", stderr_output)
        @test occursin("--draws", stderr_output)
        @test occursin(overflow_value, stderr_output)
        @test !occursin("OverflowError", stderr_output)
    end

    mktempdir() do workdir
        include_check = """
        cd($(repr(workdir)))
        include($(repr(script_path)))
        @assert isdefined(Main, :run_toy_mmm)
        @assert !isfile("contribution_summary.csv")
        @assert !isfile("metric_summary.csv")
        @assert !isfile("run_summary.txt")
        print("include-safe")
        """
        output = read(`$(Base.julia_cmd()) --project=$(repo_root) -e $(include_check)`, String)
        @test output == "include-safe"
        @test !occursin("status=", output)
        @test !occursin("backend=", output)
        @test !isfile(joinpath(workdir, "contribution_summary.csv"))
        @test !isfile(joinpath(workdir, "metric_summary.csv"))
        @test !isfile(joinpath(workdir, "run_summary.txt"))
    end
end

@testset "toy MMM MCMC smoke demo" begin
    mktempdir() do output_dir
        result = run_toy_mmm(;
            draws = 8,
            tune = 8,
            seed = 20260706,
            output_dir = output_dir,
            verbose = false,
        )

        @test result.state.status == :fit
        @test result.state.backend == :turing
        @test result.model.sampler_config.draws == 8
        @test result.model.sampler_config.tune == 8
        @test result.model.sampler_config.chains == 1
        @test result.model.sampler_config.cores == 1
        @test result.model.sampler_config.progressbar == false
        @test result.model.sampler_config.compute_convergence_checks == false
        @test !isnothing(result.grouped.posterior)
        @test isnothing(result.grouped.prior)
        @test isnothing(result.grouped.posterior_predictive)
        @test isnothing(result.grouped.prior_predictive)
        @test result.grouped.observed_data === result.model.data
        @test size(result.grouped.posterior, 1) == 8
        @test :intercept in result.grouped.posterior.name_map.parameters
        @test Symbol("beta_media[1]") in result.grouped.posterior.name_map.parameters
        @test size(result.contribution_table, 1) > 0
        @test size(result.metric_table, 1) > 0
        @test haskey(result.written_paths, :contribution_summary)
        @test haskey(result.written_paths, :metric_summary)
        @test haskey(result.written_paths, :run_summary)

        for path in values(result.written_paths)
            @test isfile(path)
            @test filesize(path) > 0
        end
    end
end
