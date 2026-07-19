using Epsilon
using JSON3
using Test

function _read_combined_output(cmd)
    path, io = mktemp()
    close(io)
    try
        run(pipeline(ignorestatus(cmd); stdout = path, stderr = path))
        return read(path, String)
    finally
        rm(path; force = true)
    end
end

@testset "demo-config smoke harness contract" begin
    repo_root = dirname(dirname(pathof(Epsilon)))
    script = joinpath(repo_root, "scripts", "smoke_demo_configs.sh")
    makefile = joinpath(repo_root, "Makefile")
    runme = joinpath(repo_root, "runme.jl")

    @test isfile(script)
    @test success(`bash -n $script`)
    @test occursin("smoke-demo-configs:", read(makefile, String))
    @test occursin("scripts/smoke_demo_configs.sh", read(makefile, String))
    @test isfile(runme)
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
        ["--quick", "--output-dir=custom", "--draws=7", "--tune", "9"],
    )
    @test config_args[1:2] == ["run", "config.yml"]
    @test "--quick" ∉ config_args
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

    help_output = read(
        `$(Base.julia_cmd()) --project=$repo_root --startup-file=no $runme --help`,
        String,
    )
    @test occursin("runme.jl [config_path]", help_output)
    @test occursin("dataset.csv and holidays.csv paths are owned by the config", help_output)

    bad_output = _read_combined_output(
        `$(Base.julia_cmd()) --project=$repo_root --startup-file=no $runme demo geo_panel`,
    )
    @test occursin("unsupported demo `geo_panel`", bad_output)
    @test !occursin("Stacktrace", bad_output)

    missing_config = joinpath(repo_root, "data", "demo", "timeseries", "missing.yml")
    missing_cmd = `$(Base.julia_cmd()) --project=$repo_root --startup-file=no $runme $missing_config`
    missing_process = run(pipeline(ignorestatus(missing_cmd); stdout = devnull, stderr = devnull))
    @test !success(missing_process)
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

        @test occursin("Pipeline run completed.", output)
        @test occursin("run_name=runme-smoke", output)

        run_dirs = readdir(tmpdir; join = true)
        @test length(run_dirs) == 1
        run_dir = only(run_dirs)
        manifest_path = joinpath(run_dir, "run_manifest.json")
        @test isfile(manifest_path)

        manifest = JSON3.read(read(manifest_path, String))
        @test manifest["status"] == "completed"
        @test manifest["stages"]["fit"]["status"] == "completed"
        @test manifest["stages"]["validation"]["status"] == "completed"
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
