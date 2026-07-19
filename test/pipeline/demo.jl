@testset "demo data and runner" begin
    repo_root = dirname(dirname(pathof(Epsilon)))
    script = joinpath(repo_root, "runme.jl")
    timeseries_config = joinpath(repo_root, "data", "demo", "timeseries", "config.yml")
    geo_panel_config = joinpath(repo_root, "data", "demo", "geo_panel", "config.yml")
    geo_brand_panel_config = joinpath(repo_root, "data", "demo", "geo_brand_panel", "config.yml")
    timeseries_dataset = joinpath(repo_root, "data", "demo", "timeseries", "dataset.csv")
    timeseries_holidays = joinpath(repo_root, "data", "demo", "timeseries", "holidays.csv")

    @test isfile(script)
    @test isfile(timeseries_config)
    @test isfile(geo_panel_config)
    @test isfile(geo_brand_panel_config)
    @test isfile(timeseries_dataset)
    @test isfile(timeseries_holidays)

    julia = Base.julia_cmd()

    help_output = read(`$julia --project=$repo_root $script --help`, String)
    @test occursin("julia --project=. runme.jl", help_output)
    @test occursin("data/demo/timeseries/config.yml", help_output)
    @test occursin("Bundle-local dataset.csv and holidays.csv paths are owned by the config", help_output)

    tmpdir = mktempdir()
    run_output = read(
        `$julia --project=$repo_root $script $timeseries_config --output-dir $tmpdir --run-name ci-demo --draws 10 --tune 10 --chains 1 --cores 1 --prior-samples 3 --curve-points 8 --no-plots`,
        String,
    )
    @test occursin("Status       : completed", run_output)
    @test occursin("Run name     : ci-demo", run_output)
    manifest_line = only(filter(line -> startswith(line, "Manifest     : "), split(run_output, '\n')))
    manifest_path = strip(split(manifest_line, ':'; limit = 2)[2])
    @test isfile(manifest_path)
    run_dir = dirname(manifest_path)
    @test isfile(joinpath(run_dir, "20_model_fit", "model.jls"))
    @test isfile(joinpath(run_dir, "40_decomposition", "contribution_summary.csv"))
end
