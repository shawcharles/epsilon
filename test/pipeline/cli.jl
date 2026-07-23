using CSV
using CairoMakie
using DataFrames
using Epsilon
using JSON3
using Test
using YAML

function _pipeline_test_config(
        fixture::AbstractString;
        validation_enabled::Bool = true,
        holdout_rows::Integer = 4,
        optimization_block = Dict("enabled" => false),
    )
    config = YAML.load_file(fixture)
    config["validation"] = Dict(
        "enabled" => validation_enabled,
        "holdout_rows" => Int(holdout_rows),
    )
    config["optimization"] = optimization_block
    return config
end

function _write_pipeline_test_config(path::AbstractString, config)
    YAML.write_file(path, config)
    return path
end

function _failing_curve_dataset(source_path::AbstractString, output_path::AbstractString)
    data = DataFrame(CSV.File(source_path))
    data.search .= 0.0
    CSV.write(output_path, data)
    return output_path
end

@testset "pipeline_main runs the bounded CLI surface successfully" begin
    fixture = joinpath(@__DIR__, "..", "fixtures", "pipeline_config.yml")
    dataset_fixture = joinpath(@__DIR__, "..", "fixtures", "pipeline_dataset.csv")

    mktempdir() do tmpdir
        status = pipeline_main(
            [
                "run",
                fixture,
                "--output-dir",
                joinpath(tmpdir, "results"),
                "--run-name",
                "cli_demo",
                "--dataset-path",
                dataset_fixture,
                "--prior-samples",
                "6",
                "--curve-points",
                "8",
                "--draws",
                "6",
                "--tune",
                "6",
                "--chains",
                "1",
                "--cores",
                "1",
                "--random-seed",
                "17",
            ]
        )

        @test status == 0

        run_dir = only(readdir(joinpath(tmpdir, "results"); join = true))
        manifest = JSON3.read(read(joinpath(run_dir, "run_manifest.json"), String))
        @test manifest["status"] == "completed"
        @test manifest["stages"]["validation"]["status"] == "completed"
        @test manifest["stages"]["optimisation"]["status"] == "skipped"
        @test isfile(joinpath(run_dir, "20_model_fit", "trace.png"))
        @test isfile(joinpath(run_dir, "30_model_assessment", "observed_fitted.png"))
    end
end

@testset "pipeline_main supports optimization and skipped optional stages" begin
    fixture = joinpath(@__DIR__, "..", "fixtures", "pipeline_config.yml")
    dataset_fixture = joinpath(@__DIR__, "..", "fixtures", "pipeline_dataset.csv")

    mktempdir() do tmpdir
        config_path = joinpath(tmpdir, "pipeline_opt.yml")
        _write_pipeline_test_config(
            config_path,
            _pipeline_test_config(
                fixture;
                validation_enabled = false,
                optimization_block = Dict("enabled" => true, "total_budget" => 31.5),
            ),
        )

        stdout_path = joinpath(tmpdir, "stdout.txt")
        status = open(stdout_path, "w") do stdout_io
            redirect_stdout(stdout_io) do
                Epsilon._with_pipeline_pretty_output() do
                    pipeline_main(
                        [
                            "run",
                            config_path,
                            "--output-dir",
                            joinpath(tmpdir, "results"),
                            "--run-name",
                            "cli_optimization",
                            "--dataset-path",
                            dataset_fixture,
                            "--prior-samples",
                            "6",
                            "--curve-points",
                            "8",
                            "--draws",
                            "6",
                            "--tune",
                            "6",
                            "--chains",
                            "1",
                            "--cores",
                            "1",
                            "--random-seed",
                            "19",
                        ]
                    )
                end
            end
        end

        @test status == 0
        @test occursin(Epsilon._pipeline_optimization_decision_warning(), read(stdout_path, String))

        run_dir = only(readdir(joinpath(tmpdir, "results"); join = true))
        manifest = JSON3.read(read(joinpath(run_dir, "run_manifest.json"), String))
        @test manifest["stages"]["validation"]["status"] == "skipped"
        @test manifest["stages"]["optimisation"]["status"] == "completed"
        @test Epsilon._pipeline_optimization_decision_warning() in
            String.(manifest["stages"]["optimisation"]["warnings"])
        @test isfile(joinpath(run_dir, "70_optimisation", "budget_optimization_result.jls"))
        @test isfile(joinpath(run_dir, "70_optimisation", "budget_optimization.png"))
    end
end

@testset "pipeline_main rejects unsupported pipeline contract shapes" begin
    dataset_fixture = joinpath(@__DIR__, "..", "fixtures", "pipeline_dataset.csv")

    mktempdir() do tmpdir
        split_path = joinpath(tmpdir, "split.yml")
        write(
            split_path,
            """
            data:
              date_column: date
              x_path: x.csv
            target:
              column: revenue
            media:
              channels: [tv]
            """,
        )

        vi_path = joinpath(tmpdir, "vi.yml")
        write(
            vi_path,
            """
            data:
              date_column: date
              dataset_path: data/input.csv
            target:
              column: revenue
            media:
              channels: [tv]
            fit:
              backend: vi
            """,
        )

        for path in (split_path, vi_path)
            status = pipeline_main(
                [
                    "run",
                    path,
                    "--output-dir",
                    joinpath(tmpdir, "results"),
                    "--dataset-path",
                    dataset_fixture,
                ]
            )
            @test status == 1
        end
    end
end

@testset "run_pipeline writes truthful failure manifest on stage exceptions" begin
    fixture = joinpath(@__DIR__, "..", "fixtures", "pipeline_config.yml")
    dataset_fixture = joinpath(@__DIR__, "..", "fixtures", "pipeline_dataset.csv")

    mktempdir() do tmpdir
        config_path = joinpath(tmpdir, "pipeline_failure.yml")
        _write_pipeline_test_config(
            config_path,
            _pipeline_test_config(
                fixture;
                validation_enabled = false,
                optimization_block = Dict("enabled" => true, "total_budget" => 31.5),
            ),
        )
        failure_dataset_path = _failing_curve_dataset(
            dataset_fixture,
            joinpath(tmpdir, "failure_dataset.csv"),
        )

        @test_throws ArgumentError run_pipeline(
            PipelineRunConfig(
                config_path = config_path,
                output_dir = joinpath(tmpdir, "results"),
                run_name = "cli_failure",
                dataset_path = failure_dataset_path,
                prior_samples = 6,
                curve_points = 8,
                draws = 6,
                tune = 6,
                chains = 1,
                cores = 1,
                random_seed = 23,
            ),
        )

        run_dir = only(readdir(joinpath(tmpdir, "results"); join = true))
        manifest = JSON3.read(read(joinpath(run_dir, "run_manifest.json"), String))

        @test manifest["status"] == "failed"
        @test manifest["stages"]["metadata"]["status"] == "failed"
        @test manifest["stages"]["fit"]["status"] == "not_reached"
        @test manifest["stages"]["curves"]["status"] == "not_reached"
        @test manifest["stages"]["optimisation"]["status"] == "not_reached"
        @test manifest["error"]["stage"] == "metadata"
        @test occursin("positive observed spend", String(manifest["error"]["message"]))
    end
end

@testset "bin/epsilon exposes the bounded CLI wrapper" begin
    cli_path = normpath(joinpath(@__DIR__, "..", "..", "bin", "epsilon"))
    help_text = read(Cmd([cli_path, "--help"]), String)
    @test occursin("epsilon run <config_path>", help_text)
    @test occursin("--output-dir", help_text)
end
