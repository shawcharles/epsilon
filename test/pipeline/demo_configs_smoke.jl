using Epsilon
using JSON3
using Test

function _capture_streams(f::Function)
    stdout_path, stdout_handle = mktemp()
    stderr_path, stderr_handle = mktemp()
    close(stdout_handle)
    close(stderr_handle)
    try
        status = open(stdout_path, "w") do stdout_io
            open(stderr_path, "w") do stderr_io
                redirect_stdout(stdout_io) do
                    redirect_stderr(stderr_io) do
                        f()
                    end
                end
            end
        end
        output = read(stdout_path, String) * read(stderr_path, String)
        return (status = status, output = output)
    finally
        rm(stdout_path; force = true)
        rm(stderr_path; force = true)
    end
end

function _capture_runme(args::Vector{String})
    return _capture_streams() do
        runme_main(args)
    end
end

@testset "demo-config smoke harness contract" begin
    repo_root = dirname(dirname(pathof(Epsilon)))
    script = joinpath(repo_root, "scripts", "smoke_demo_configs.sh")
    makefile = joinpath(repo_root, "Makefile")
    runme = joinpath(repo_root, "runme.jl")
    header = joinpath(repo_root, "assets", "ascii.txt")

    @test isfile(script)
    @test success(`bash -n $script`)
    @test occursin("smoke-demo-configs:", read(makefile, String))
    @test occursin("scripts/smoke_demo_configs.sh", read(makefile, String))
    @test isfile(runme)
    @test isfile(header)
    @test occursin("run-demo-config:", read(makefile, String))
    @test occursin("runme.jl demo", read(makefile, String))
end

@testset "runme.jl translates config-driven runner commands" begin
    repo_root = dirname(dirname(pathof(Epsilon)))
    runme = joinpath(repo_root, "runme.jl")

    if !isdefined(@__MODULE__, :runme_main)
        include(runme)
    end

    config_args = _runme_pipeline_args(
        "config.yml",
        ["--quick", "--no-plots", "--output-dir=custom", "--draws=7", "--tune", "9"],
    )
    @test config_args[1:2] == ["run", "config.yml"]
    @test "--quick" ∉ config_args
    @test "--no-plots" ∉ config_args
    @test "--output-dir=custom" in config_args
    @test "--draws=7" in config_args
    @test "--tune" in config_args
    @test "9" in config_args
    @test "--chains" in config_args
    @test "--cores" in config_args
    @test "--prior-samples" in config_args
    @test "--curve-points" in config_args

    no_quick_args = _runme_pipeline_args("config.yml", ["--draws", "11"])
    @test no_quick_args == ["run", "config.yml", "--draws", "11"]

    @test _runme_pipeline_plan("config.yml", ["--quick"]).quick
    @test !_runme_pipeline_plan("config.yml", ["--no-plots"]).plots
    @test _runme_pipeline_plan("config.yml", ["--output-dir", "custom"]).output_dir == "custom"
    @test _runme_pipeline_plan("config.yml", ["--run-name=smoke"]).run_name == "smoke"
    @test_throws ArgumentError _runme_pipeline_plan("config.yml", ["--no-plots=yes"])
    @test Epsilon._pipeline_progress_bar(0, 4; width = 8) == "[--------]"
    @test Epsilon._pipeline_progress_bar(2, 4; width = 8) == "[####----]"
    @test Epsilon._pipeline_progress_bar(4, 4; width = 8) == "[########]"
    @test Epsilon._pipeline_progress_bar(1, 0; width = 8) == "[--------]"
    @test Epsilon._pipeline_stage_status_summary(
        Dict(:completed => 2, :skipped => 1, :failed => 0),
    ) == "completed=2, skipped=1"

    @eval Main using CairoMakie
    @test Epsilon._plotting_backend_loaded()
    @test Epsilon._pipeline_plots_enabled()

    disabled_artifacts = Dict{String, String}()
    disabled_warnings = String[]
    Epsilon._with_pipeline_plots_disabled() do
        @test !Epsilon._pipeline_plots_enabled()
        Epsilon._save_pipeline_plot!(
            disabled_artifacts,
            disabled_warnings,
            "fit",
            "trace_plot",
            "trace.png",
            "20_model_fit/trace.png",
            :trace,
        )
    end
    @test isempty(disabled_artifacts)
    @test disabled_warnings == [Epsilon._pipeline_plots_disabled_warning()]

    normal_pipeline_cli = _capture_streams() do
        pipeline_main(["run"])
    end
    @test normal_pipeline_cli.status != 0
    @test occursin("epsilon run <config_path>", normal_pipeline_cli.output)
    @test !occursin("███████", normal_pipeline_cli.output)
    @test !occursin("Status       : failed", normal_pipeline_cli.output)

    help_output = read(
        `$(Base.julia_cmd()) --project=$repo_root --startup-file=no $runme --help`,
        String,
    )
    @test occursin("███████", help_output)
    @test occursin("runme.jl [config_path]", help_output)
    @test occursin("dataset.csv and holidays.csv paths are owned by the config", help_output)

    bad_result = _capture_runme(["demo", "geo_panel"])
    bad_output = bad_result.output
    @test bad_result.status != 0
    @test occursin("███████", bad_output)
    @test occursin("Runner status : failed", bad_output)
    @test occursin("unsupported demo `geo_panel`", bad_output)
    @test !occursin("Stacktrace", bad_output)

    missing_config = joinpath(repo_root, "data", "demo", "timeseries", "missing.yml")
    missing_result = _capture_runme([missing_config])
    @test missing_result.status != 0
    @test occursin("███████", missing_result.output)
    @test occursin("Status       : failed", missing_result.output)
    @test occursin("Error", missing_result.output)
    @test !occursin("Stacktrace", missing_result.output)
end

@testset "runme.jl executes the canonical time-series config with tiny overrides" begin
    repo_root = dirname(dirname(pathof(Epsilon)))
    runme = joinpath(repo_root, "runme.jl")
    config_path = joinpath(repo_root, "data", "demo", "timeseries", "config.yml")

    mktempdir() do tmpdir
        output = read(
            `$(Base.julia_cmd()) --project=$repo_root --startup-file=no $runme $config_path --output-dir $tmpdir --run-name runme-smoke --quick --draws 10 --tune 10 --random-seed 721`,
            String,
        )

        @test occursin("███████", output)
        @test occursin("Config", output)
        @test occursin("Output root", output)
        @test occursin("Quick mode", output)
        @test occursin("Plots        : enabled (PNG)", output)
        @test occursin("RUNNING", output)
        @test occursin("DONE", output)
        @test occursin("Status      ", output)
        @test occursin("completed", output)
        @test occursin("Run name     : runme-smoke", output)
        @test occursin("Manifest", output)

        run_dirs = readdir(tmpdir; join = true)
        @test length(run_dirs) == 1
        run_dir = only(run_dirs)
        manifest_path = joinpath(run_dir, "run_manifest.json")
        @test isfile(manifest_path)
        @test isfile(joinpath(run_dir, "20_model_fit", "trace.png"))
        @test isfile(joinpath(run_dir, "30_model_assessment", "observed_fitted.png"))

        manifest = JSON3.read(read(manifest_path, String))
        @test manifest["status"] == "completed"
        @test manifest["stages"]["fit"]["status"] == "completed"
        @test manifest["stages"]["fit"]["artifact_paths"]["trace_plot"] == "20_model_fit/trace.png"
        @test manifest["stages"]["validation"]["status"] == "completed"
    end
end

@testset "runme.jl --no-plots suppresses artifacts with a loaded plotting backend" begin
    repo_root = dirname(dirname(pathof(Epsilon)))
    runme = joinpath(repo_root, "runme.jl")
    config_path = joinpath(repo_root, "data", "demo", "timeseries", "config.yml")

    if !isdefined(@__MODULE__, :runme_main)
        include(runme)
    end

    @eval Main using CairoMakie
    @test Epsilon._plotting_backend_loaded()

    mktempdir() do tmpdir
        result = _capture_runme(
            [
                config_path,
                "--output-dir",
                tmpdir,
                "--run-name",
                "runme-no-plots-smoke",
                "--quick",
                "--no-plots",
                "--draws",
                "10",
                "--tune",
                "10",
                "--random-seed",
                "722",
            ],
        )
        output = result.output

        @test result.status == 0
        @test occursin("Plots        : disabled (--no-plots)", output)
        @test occursin("completed", output)

        run_dir = only(readdir(tmpdir; join = true))
        manifest_path = joinpath(run_dir, "run_manifest.json")
        @test isfile(manifest_path)
        @test !isfile(joinpath(run_dir, "20_model_fit", "trace.png"))
        @test !isfile(joinpath(run_dir, "30_model_assessment", "observed_fitted.png"))
        @test !isfile(joinpath(run_dir, "50_diagnostics", "posterior_density.png"))

        manifest = JSON3.read(read(manifest_path, String))
        @test manifest["status"] == "completed"
        @test !haskey(manifest["stages"]["fit"]["artifact_paths"], "trace_plot")
        @test !haskey(manifest["stages"]["assessment"]["artifact_paths"], "observed_fitted_plot")
        @test !haskey(manifest["stages"]["diagnostics"]["artifact_paths"], "posterior_density_plot")
        @test Epsilon._pipeline_plots_disabled_warning() in
            String.(manifest["stages"]["fit"]["warnings"])
        @test Epsilon._pipeline_plots_disabled_warning() in
            String.(manifest["stages"]["diagnostics"]["warnings"])
    end
end

@testset "data demo configs build supported model specs without MCMC" begin
    repo_root = dirname(dirname(pathof(Epsilon)))
    configs = (
        (
            path = joinpath(repo_root, "data", "demo", "timeseries", "config.yml"),
            model_type = TimeSeriesMMM,
            dims = (),
        ),
        (
            path = joinpath(repo_root, "data", "demo", "geo_panel", "config.yml"),
            model_type = PanelMMM,
            dims = ("geo",),
        ),
        (
            path = joinpath(repo_root, "data", "demo", "geo_brand_panel", "config.yml"),
            model_type = PanelMMM,
            dims = ("geo", "brand"),
        ),
    )

    mktempdir() do tmpdir
        for entry in configs
            config = PipelineRunConfig(
                config_path = entry.path,
                output_dir = tmpdir,
                draws = 1,
                tune = 0,
                chains = 1,
                cores = 1,
                prior_samples = 2,
                curve_points = 4,
            )
            loaded = Epsilon._load_pipeline_configuration(config)
            context = Epsilon._pipeline_context(config, loaded)
            data = isempty(loaded.model_config.dims) ?
                Epsilon._load_pipeline_dataset(context) :
                Epsilon._load_pipeline_panel_dataset(context)
            model = isempty(loaded.model_config.dims) ?
                TimeSeriesMMM(loaded.model_config, loaded.sampler_config, data) :
                PanelMMM(loaded.model_config, loaded.sampler_config, data)
            spec = build_model(model)

            @test model isa entry.model_type
            @test spec.dims == entry.dims
            @test spec.nchannels == 6
            @test spec.nobs > 0
            if data isa PanelMMMData
                @test Set(keys(data.panel_coordinates)) == Set(entry.dims)
            end
        end
    end
end
