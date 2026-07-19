@testset "demo data and runner" begin
    repo_root = dirname(dirname(pathof(Epsilon)))
    demo_root = joinpath(repo_root, "examples", "demo")
    script = joinpath(demo_root, "run_demo.jl")
    timeseries_dataset = joinpath(
        demo_root,
        "reference",
        "abacus",
        "timeseries",
        "dataset.csv",
    )
    geo_panel_dataset = joinpath(
        demo_root,
        "reference",
        "abacus",
        "geo_panel",
        "dataset.csv",
    )
    geo_brand_panel_dataset = joinpath(
        demo_root,
        "reference",
        "abacus",
        "geo_brand_panel",
        "dataset.csv",
    )
    holidays = joinpath(demo_root, "reference", "abacus", "holidays.csv")
    epsilon_config = joinpath(demo_root, "epsilon", "timeseries", "config.yml")

    @test isfile(script)
    @test isfile(timeseries_dataset)
    @test isfile(geo_panel_dataset)
    @test isfile(geo_brand_panel_dataset)
    @test isfile(holidays)
    @test isfile(epsilon_config)

    julia = Base.julia_cmd()

    list_output = read(
        `$julia --project=$repo_root $script list`,
        String,
    )
    @test occursin("timeseries\trunnable", list_output)
    @test occursin("geo_panel\treference-only", list_output)
    @test occursin("geo_brand_panel\treference-only", list_output)
    @test occursin("use data/demo for current config-driven demos", list_output)

    paths_output = read(
        `$julia --project=$repo_root $script paths timeseries`,
        String,
    )
    @test occursin("dataset=$(timeseries_dataset)", paths_output)
    @test occursin("holidays=$(holidays)", paths_output)
    @test occursin("epsilon_config=$(epsilon_config)", paths_output)

    tmpdir = mktempdir()
    run_output = read(
        `$julia --project=$repo_root $script run timeseries --output-dir $tmpdir --run-name ci-demo --draws 10 --tune 10 --chains 1 --cores 1 --prior-samples 3 --curve-points 8`,
        String,
    )
    @test occursin("Pipeline run completed.", run_output)
    @test occursin("run_name=ci-demo", run_output)
    manifest_line = only(filter(line -> startswith(line, "manifest="), split(run_output, '\n')))
    manifest_path = split(manifest_line, '='; limit = 2)[2]
    @test isfile(manifest_path)
    run_dir = dirname(manifest_path)
    @test isfile(joinpath(run_dir, "20_model_fit", "model.jls"))
    @test isfile(joinpath(run_dir, "40_decomposition", "contribution_summary.csv"))
end
