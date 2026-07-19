using Epsilon
using Test

@testset "demo-config smoke harness contract" begin
    repo_root = dirname(dirname(pathof(Epsilon)))
    script = joinpath(repo_root, "scripts", "smoke_demo_configs.sh")
    makefile = joinpath(repo_root, "Makefile")

    @test isfile(script)
    @test success(`bash -n $script`)
    @test occursin("smoke-demo-configs:", read(makefile, String))
    @test occursin("scripts/smoke_demo_configs.sh", read(makefile, String))
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
