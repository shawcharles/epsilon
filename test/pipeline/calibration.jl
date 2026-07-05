using Epsilon
using Test

@testset "pipeline fit stage threads bounded calibration YAML" begin
    mktempdir() do tmpdir
        dataset_path = joinpath(tmpdir, "dataset.csv")
        write(
            dataset_path,
            """
            date,revenue,tv,search
            2024-01-01,10.0,1.0,0.5
            2024-01-02,11.0,2.0,1.0
            2024-01-03,12.0,3.0,1.5
            2024-01-04,13.0,4.0,2.0
            2024-01-05,14.0,5.0,2.5
            2024-01-06,15.0,6.0,3.0
            """,
        )

        config_path = joinpath(tmpdir, "calibrated_pipeline.yml")
        write(
            config_path,
            """
            data:
              date_column: date
              dataset_path: $(dataset_path)
            target:
              column: revenue
            media:
              channels: [tv, search]
              adstock:
                type: geometric
                l_max: 4
              saturation:
                type: logistic
            fit:
              backend: mcmc
              draws: 12
              tune: 12
              chains: 1
              cores: 1
              random_seed: 17
              progressbar: false
              compute_convergence_checks: false
            calibration:
              steps:
                - method: add_lift_test_measurements
                - method: add_cost_per_target_calibration
              lift_test:
                channel: [tv]
                x: [1.0]
                delta_x: [0.5]
                delta_y: [0.3]
                sigma: [0.1]
              cost_per_target:
                gathered_cpt: [2.0]
                targets: [1.5]
                sigma: [0.2]
            """,
        )

        run_config = PipelineRunConfig(
            config_path = config_path,
            output_dir = joinpath(tmpdir, "results"),
            run_name = "calibrated_pipeline",
        )
        loaded = Epsilon._load_pipeline_configuration(run_config)
        context = Epsilon._pipeline_context(run_config, loaded)

        Epsilon._create_pipeline_scaffold!(context)
        Epsilon._run_metadata_stage!(context)
        fit_result = Epsilon._run_fit_stage!(context)

        model = context.model
        fit_artifact = model.fit_state.artifact
        model_path = joinpath(context.run_dir, "20_model_fit", "model.jls")
        saved_model = load_model(model_path)

        @test model isa TimeSeriesMMM
        @test model.calibration === loaded.model_config.extras["calibration"]
        @test fit_artifact.calibration isa MMMCalibrationSpec
        @test fit_artifact.calibration.lift_test isa LiftTestCalibrationPayload
        @test fit_artifact.calibration.cost_per_target isa CostPerTargetCalibrationPayload
        @test saved_model.fit_state.artifact.calibration == fit_artifact.calibration
        @test haskey(fit_result.artifact_paths, "model")
        @test haskey(fit_result.artifact_paths, "inference_results")
    end
end
