using Epsilon
using JSON3
using Test
using YAML

@testset "Pipeline typed contract surfaces validate and compare cleanly" begin
    record = PipelineStageRecord(
        "metadata",
        "00_run_metadata";
        artifact_paths = Dict("config_original" => "00_run_metadata/config.original.yaml"),
    )
    same_record = PipelineStageRecord(
        "metadata",
        "00_run_metadata";
        artifact_paths = Dict("config_original" => "00_run_metadata/config.original.yaml"),
    )
    @test record == same_record
    @test_throws ArgumentError PipelineStageRecord("metadata", "00_run_metadata"; status = :unknown)

    result = PipelineRunResult(
        "demo",
        "/tmp/demo",
        "/tmp/demo/run_manifest.json";
        config_path = "/tmp/config.yml",
        started_at_utc = "2026-04-23T12:00:00Z",
        stage_records = [record],
    )
    @test result.status == :pending
    @test result.stage_records == [record]

    validation = PipelineValidationResult(
        holdout_rows = 2,
        train_date_start = "2026-01-01",
        train_date_end = "2026-01-10",
        holdout_date_start = "2026-01-11",
        holdout_date_end = "2026-01-12",
        observed = [1.0, 2.0],
        fitted_mean = [1.5, 1.5],
        residuals = [-0.5, 0.5],
        metrics = Dict("mae" => 0.5, "rmse" => 0.5, "bias" => 0.0),
    )
    @test validation.holdout_rows == 2
    @test validation.metrics["mae"] == 0.5
    @test_throws ArgumentError PipelineValidationResult(
        holdout_rows = 1,
        train_date_start = "2026-01-01",
        train_date_end = "2026-01-01",
        holdout_date_start = "2026-01-02",
        holdout_date_end = "2026-01-02",
        observed = [1.0],
        fitted_mean = [1.0],
        residuals = [0.0],
        metrics = Dict("mae" => 0.0),
    )
end

@testset "_create_pipeline_run_directory avoids same-second collisions" begin
    mktempdir() do tmpdir
        first_dir = Epsilon._create_pipeline_run_directory(
            tmpdir,
            "demo";
            run_stamp = "20260423_120000",
        )
        second_dir = Epsilon._create_pipeline_run_directory(
            tmpdir,
            "demo";
            run_stamp = "20260423_120000",
        )

        @test basename(first_dir) == "demo_20260423_120000"
        @test basename(second_dir) == "demo_20260423_120000_2"
        @test isdir(first_dir)
        @test isdir(second_dir)
    end
end

@testset "_create_pipeline_scaffold writes skipped stage markers" begin
    fixture = joinpath(@__DIR__, "..", "fixtures", "pipeline_config.yml")
    dataset_fixture = joinpath(@__DIR__, "..", "fixtures", "pipeline_dataset.csv")

    mktempdir() do tmpdir
        config = YAML.load_file(fixture)
        delete!(config, "prior_sensitivity")
        config["validation"] = Dict("enabled" => false)
        config["optimization"] = Dict("enabled" => false)
        config_path = joinpath(tmpdir, "skipped_markers.yml")
        YAML.write_file(config_path, config)

        run_config = PipelineRunConfig(
            config_path = config_path,
            output_dir = joinpath(tmpdir, "results"),
            run_name = "skipped_markers",
            dataset_path = dataset_fixture,
        )
        loaded = Epsilon._load_pipeline_configuration(run_config)
        context = Epsilon._pipeline_context(run_config, loaded)

        Epsilon._create_pipeline_scaffold!(context)
        Epsilon._write_pipeline_manifest!(context)

        expected = (
            ("prior_sensitivity", "05_prior_sensitivity", "prior_sensitivity is not configured"),
            ("validation", "35_holdout_validation", "validation.enabled is false"),
            ("optimisation", "70_optimisation", "optimization.enabled is false"),
        )
        for (stage, directory, reason) in expected
            record = context.stage_records[Epsilon._stage_index(context, stage)]
            marker_relative_path = joinpath(directory, "SKIPPED.json")
            marker_path = joinpath(context.run_dir, marker_relative_path)
            marker = JSON3.read(read(marker_path, String))

            @test record.status == :skipped
            @test record.artifact_paths["skipped_marker"] == marker_relative_path
            @test marker["schema_version"] == 1
            @test marker["stage"] == stage
            @test marker["directory"] == directory
            @test marker["status"] == "skipped"
            @test marker["reason"] == reason
            @test marker["optional"] == true
            @test occursin(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$", marker["generated_at_utc"])
        end

        manifest = JSON3.read(read(context.manifest_path, String))
        @test manifest["stages"]["optimisation"]["artifact_paths"]["skipped_marker"] ==
            joinpath("70_optimisation", "SKIPPED.json")
    end
end

@testset "_load_pipeline_serialized validates schema metadata and kind" begin
    mktempdir() do tmpdir
        artifact_path = joinpath(tmpdir, "artifact.jls")
        Epsilon._write_pipeline_serialized(
            artifact_path,
            Dict("value" => 1);
            artifact_kind = "TestArtifact",
        )

        artifact = Epsilon._load_pipeline_serialized(
            artifact_path;
            expected_kind = "TestArtifact",
        )
        @test artifact == Dict("value" => 1)
        @test_throws ArgumentError Epsilon._load_pipeline_serialized(
            artifact_path;
            expected_kind = "OtherArtifact",
        )
    end
end
