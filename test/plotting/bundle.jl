using Epsilon
using Test
using YAML

function _plotting_pipeline_test_config(
    fixture::AbstractString;
    validation_enabled::Bool = false,
    optimization_block = Dict("enabled" => false),
)
    config = YAML.load_file(fixture)
    config["validation"] = Dict(
        "enabled" => validation_enabled,
        "holdout_rows" => 4,
    )
    config["optimization"] = optimization_block
    return config
end

function _write_plotting_pipeline_config(path::AbstractString, config)
    YAML.write_file(path, config)
    return path
end

@testset "write_plot_bundle exports deterministic png tree without optimization" begin
    fixture = joinpath(@__DIR__, "..", "fixtures", "pipeline_config.yml")
    dataset_fixture = joinpath(@__DIR__, "..", "fixtures", "pipeline_dataset.csv")

    mktempdir() do tmpdir
        config_path = joinpath(tmpdir, "pipeline_bundle.yml")
        _write_plotting_pipeline_config(
            config_path,
            _plotting_pipeline_test_config(fixture; validation_enabled = false),
        )

        run = run_pipeline(
            PipelineRunConfig(
                config_path = config_path,
                output_dir = joinpath(tmpdir, "results"),
                run_name = "bundle_demo",
                dataset_path = dataset_fixture,
                prior_samples = 6,
                curve_points = 8,
                draws = 6,
                tune = 6,
                chains = 1,
                cores = 1,
                random_seed = 41,
            ),
        )

        bundle_dir = write_plot_bundle(run; output_dir = joinpath(tmpdir, "plots"))

        diagnostics_dir = joinpath(bundle_dir, "diagnostics")
        postmodel_dir = joinpath(bundle_dir, "postmodel")
        optimization_dir = joinpath(bundle_dir, "optimization")

        @test bundle_dir == joinpath(tmpdir, "plots")
        @test isfile(joinpath(diagnostics_dir, "trace.png"))
        @test isfile(joinpath(diagnostics_dir, "posterior_density.png"))
        @test isfile(joinpath(diagnostics_dir, "observed_fitted.png"))
        @test isfile(joinpath(diagnostics_dir, "residual_diagnostics.png"))
        @test isfile(joinpath(postmodel_dir, "contributions.png"))
        @test isfile(joinpath(postmodel_dir, "contributions_area.png"))
        @test isfile(joinpath(postmodel_dir, "decomposition.png"))
        @test isfile(joinpath(postmodel_dir, "response_curve_tv.png"))
        @test isfile(joinpath(postmodel_dir, "response_curve_search.png"))
        @test isfile(joinpath(postmodel_dir, "saturation_curve_tv.png"))
        @test isfile(joinpath(postmodel_dir, "saturation_curve_search.png"))
        @test isfile(joinpath(postmodel_dir, "adstock_curve_tv.png"))
        @test isfile(joinpath(postmodel_dir, "adstock_curve_search.png"))
        @test !ispath(joinpath(optimization_dir, "budget_optimization.png"))

        model = load_model(joinpath(run.run_dir, "20_model_fit", "model.jls"))
        grouped = inference_results(
            model;
            include_prior = true,
            include_posterior_predictive = true,
            include_prior_predictive = false,
        )
        selected = Epsilon._select_plot_parameters(
            grouped.posterior;
            parameters = nothing,
            max_parameters = 8,
            action = "test",
        )
        prior_parameters = Set(Symbol.(names(grouped.prior, :parameters)))
        expected_prior_posteriors = sort([
            "prior_posterior_$(Epsilon._plot_parameter_slug(parameter)).png" for
            parameter in selected if parameter in prior_parameters
        ])
        actual_prior_posteriors = sort(filter(name -> startswith(name, "prior_posterior_"), readdir(diagnostics_dir)))

        @test actual_prior_posteriors == expected_prior_posteriors
        for path in [
            joinpath(diagnostics_dir, name) for name in readdir(diagnostics_dir)
        ]
            @test filesize(path) > 0
        end
        for path in [
            joinpath(postmodel_dir, name) for name in readdir(postmodel_dir)
        ]
            @test filesize(path) > 0
        end
    end
end

@testset "write_plot_bundle includes optimization plot when present" begin
    fixture = joinpath(@__DIR__, "..", "fixtures", "pipeline_config.yml")
    dataset_fixture = joinpath(@__DIR__, "..", "fixtures", "pipeline_dataset.csv")

    mktempdir() do tmpdir
        config_path = joinpath(tmpdir, "pipeline_bundle_opt.yml")
        _write_plotting_pipeline_config(
            config_path,
            _plotting_pipeline_test_config(
                fixture;
                validation_enabled = false,
                optimization_block = Dict("enabled" => true, "total_budget" => 31.5),
            ),
        )

        run = run_pipeline(
            PipelineRunConfig(
                config_path = config_path,
                output_dir = joinpath(tmpdir, "results"),
                run_name = "bundle_optimization",
                dataset_path = dataset_fixture,
                prior_samples = 6,
                curve_points = 8,
                draws = 6,
                tune = 6,
                chains = 1,
                cores = 1,
                random_seed = 43,
            ),
        )

        bundle_dir = write_plot_bundle(run; output_dir = joinpath(tmpdir, "plots"))

        @test isfile(joinpath(bundle_dir, "optimization", "budget_optimization.png"))
        @test filesize(joinpath(bundle_dir, "optimization", "budget_optimization.png")) > 0
    end
end

@testset "write_plot_bundle rejects unsuccessful pipeline runs honestly" begin
    run = PipelineRunResult(
        "bundle_failure",
        "/tmp/bundle_failure",
        "/tmp/bundle_failure/run_manifest.json";
        status = :pending,
        config_path = "/tmp/bundle_failure/config.yml",
        started_at_utc = "2026-04-23T00:00:00Z",
    )

    @test_throws ArgumentError write_plot_bundle(run)
end
