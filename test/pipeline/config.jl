using Epsilon
using Test

@testset "PipelineRunConfig validates bounded runtime overrides" begin
    config = PipelineRunConfig(config_path = "config.yml")
    @test config.output_dir == "results"
    @test config.prior_samples == 20
    @test config.curve_points == 100

    @test_throws ArgumentError PipelineRunConfig(config_path = "")
    @test_throws ArgumentError PipelineRunConfig(config_path = "config.yml", run_name = "bad/name")
    @test_throws ArgumentError PipelineRunConfig(config_path = "config.yml", prior_samples = 0)
    @test_throws ArgumentError PipelineRunConfig(config_path = "config.yml", curve_points = 1)
    @test_throws ArgumentError PipelineRunConfig(config_path = "config.yml", draws = 0)
    @test_throws ArgumentError PipelineRunConfig(config_path = "config.yml", tune = -1)
end

@testset "pipeline configuration rejects retired inference-shaped keys" begin
    mktempdir() do tmpdir
        for key in ("vi", "variational", "approximate_fit")
            config_path = joinpath(tmpdir, "$key.yml")
            write(
                config_path,
                """
                data:
                  date_column: date
                  dataset_path: data.csv
                target:
                  column: revenue
                media:
                  channels: [tv]
                $key: {}
                """,
            )
            @test_throws ArgumentError Epsilon._load_pipeline_configuration(
                PipelineRunConfig(config_path = config_path),
            )
        end
    end
end

@testset "_load_pipeline_configuration strips runner-only keys and merges overrides" begin
    fixture = joinpath(@__DIR__, "..", "fixtures", "pipeline_config.yml")
    loaded = Epsilon._load_pipeline_configuration(
        PipelineRunConfig(
            config_path = fixture,
            dataset_path = "/tmp/override.csv",
            draws = 250,
            tune = 75,
            chains = 3,
            cores = 1,
            random_seed = 99,
        ),
    )

    @test loaded.resolved_config["data"]["dataset_path"] == "/tmp/override.csv"
    @test loaded.dataset_path == "/tmp/override.csv"
    @test loaded.resolved_config["fit"]["draws"] == 250
    @test loaded.resolved_config["fit"]["tune"] == 75
    @test loaded.resolved_config["fit"]["chains"] == 3
    @test loaded.resolved_config["fit"]["cores"] == 1
    @test loaded.resolved_config["fit"]["random_seed"] == 99

    @test !haskey(loaded.model_config_dict, "validation")
    @test !haskey(loaded.model_config_dict, "prior_sensitivity")
    @test !haskey(loaded.model_config_dict, "optimization")
    @test !haskey(loaded.model_config_dict["data"], "dataset_path")

    @test loaded.model_config.date_column == "date"
    @test loaded.model_config.target_column == "revenue"
    @test loaded.model_config.channel_columns == ["tv", "search"]
    @test loaded.sampler_config.draws == 250
    @test loaded.validation_config["enabled"] == true
    @test loaded.validation_config["holdout_rows"] == 4
    @test loaded.validation_config["sampler_config"] == SamplerConfig(
        draws = 5,
        tune = 5,
        chains = 1,
        cores = 1,
        target_accept = loaded.sampler_config.target_accept,
        random_seed = 17,
        progressbar = loaded.sampler_config.progressbar,
        compute_convergence_checks = loaded.sampler_config.compute_convergence_checks,
    )
    @test loaded.prior_sensitivity_config["enabled"] == true
    @test loaded.prior_sensitivity_config["scenario_policy"] == "manual"
    @test loaded.prior_sensitivity_config["reference"] == "reference"
    @test haskey(loaded.prior_sensitivity_config["scenarios"], "tighter_intercept")
    @test loaded.optimization_config["enabled"] == false
end

@testset "_load_pipeline_configuration strips accepted runner-only keys before model parsing" begin
    mktempdir() do tmpdir
        config_path = joinpath(tmpdir, "runner_keys.yml")
        write(
            config_path,
            """
            data:
              date_column: date
              dataset_path: data.csv
            target:
              column: revenue
            media:
              channels: [tv]
            ai_advisor:
              enabled: false
            original_scale_vars:
              - revenue
              - tv
            validation:
              enabled: false
            prior_sensitivity:
              enabled: false
            optimization:
              enabled: false
            """,
        )

        loaded = Epsilon._load_pipeline_configuration(PipelineRunConfig(config_path = config_path))

        @test haskey(loaded.resolved_config, "ai_advisor")
        @test haskey(loaded.resolved_config, "original_scale_vars")
        @test !haskey(loaded.model_config_dict, "ai_advisor")
        @test !haskey(loaded.model_config_dict, "original_scale_vars")
        @test !haskey(loaded.model_config_dict, "validation")
        @test !haskey(loaded.model_config_dict, "prior_sensitivity")
        @test !haskey(loaded.model_config_dict, "optimization")
        @test loaded.validation_config["enabled"] == false
        @test loaded.prior_sensitivity_config["enabled"] == false
        @test loaded.optimization_config["enabled"] == false
        @test loaded.model_config.channel_columns == ["tv"]
    end
end

@testset "_load_pipeline_configuration accepts bounded calibration payloads" begin
    mktempdir() do tmpdir
        config_path = joinpath(tmpdir, "calibrated.yml")
        write(
            config_path,
            """
            data:
              date_column: date
              dataset_path: data.csv
            target:
              column: revenue
            media:
              channels: [tv, search]
              saturation:
                type: logistic
            fit:
              backend: mcmc
              draws: 8
              tune: 8
              chains: 1
              cores: 1
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

        loaded = Epsilon._load_pipeline_configuration(PipelineRunConfig(config_path = config_path))
        calibration = loaded.model_config.extras["calibration"]

        @test haskey(loaded.model_config_dict, "calibration")
        @test calibration isa TimeSeriesCalibrationInput
        @test loaded.sampler_config.draws == 8
        @test loaded.sampler_config.tune == 8
        @test [step.method for step in calibration.steps] == [
            "add_lift_test_measurements",
            "add_cost_per_target_calibration",
        ]
        @test calibration.lift_test == LiftTestCalibrationRows(
            channel = ["tv"],
            x = [1.0],
            delta_x = [0.5],
            delta_y = [0.3],
            sigma = [0.1],
        )
        @test calibration.cost_per_target == CostPerTargetCalibrationRows(
            gathered_cpt = [2.0],
            targets = [1.5],
            sigma = [0.2],
        )
    end
end

@testset "prior_sensitivity conservative_mmm expands bounded prior scenarios" begin
    mktempdir() do tmpdir
        config_path = joinpath(tmpdir, "prior_sensitivity.yml")
        write(
            config_path,
            """
            data:
              date_column: date
              dataset_path: data.csv
            target:
              column: revenue
            media:
              channels: [tv, search]
              adstock:
                type: geometric
                priors:
                  alpha:
                    distribution: Beta
                    alpha: 1
                    beta: 3
                    dims: [channel]
              saturation:
                type: logistic
                priors:
                  beta:
                    distribution: HalfNormal
                    sigma: 1.0
                    dims: [channel]
                  lam:
                    distribution: Gamma
                    alpha: 3
                    beta: 1
                    dims: [channel]
            prior_sensitivity:
              enabled: true
              scenario_policy: conservative_mmm
            """,
        )

        loaded = Epsilon._load_pipeline_configuration(PipelineRunConfig(config_path = config_path))
        scenarios = Epsilon._expand_prior_sensitivity_scenarios(
            loaded.resolved_config,
            loaded.prior_sensitivity_config,
        )
        names = Set(String(scenario["name"]) for scenario in scenarios)

        @test names == Set(
            [
                "reference",
                "shorter_memory",
                "longer_memory",
                "tighter_media_effect",
                "wider_media_effect",
                "earlier_saturation",
                "later_saturation",
            ],
        )
        shorter = only(filter(scenario -> scenario["name"] == "shorter_memory", scenarios))
        @test shorter["classification"] == "prior_sensitivity"
        @test shorter["config"]["media"]["adstock"]["priors"]["alpha"]["beta"] == 5
        tighter = only(filter(scenario -> scenario["name"] == "tighter_media_effect", scenarios))
        @test tighter["config"]["media"]["saturation"]["priors"]["beta"]["sigma"] == 0.5
        @test !haskey(tighter["config"], "prior_sensitivity")
    end
end

@testset "_load_pipeline_configuration requires a combined dataset path" begin
    mktempdir() do tmpdir
        missing_dataset_path = joinpath(tmpdir, "missing_dataset.yml")
        write(
            missing_dataset_path,
            """
            data:
              date_column: date
            target:
              column: revenue
            media:
              channels: [tv]
            """,
        )
        @test_throws ArgumentError Epsilon._load_pipeline_configuration(
            PipelineRunConfig(config_path = missing_dataset_path),
        )
    end
end

@testset "_load_pipeline_configuration rejects unsupported contract shapes" begin
    mktempdir() do tmpdir
        split_csv_path = joinpath(tmpdir, "split.yml")
        write(
            split_csv_path,
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
        @test_throws ArgumentError Epsilon._load_pipeline_configuration(
            PipelineRunConfig(config_path = split_csv_path),
        )

        panel_path = joinpath(tmpdir, "panel.yml")
        write(
            panel_path,
            """
            data:
              date_column: date
            target:
              column: revenue
            dimensions:
              panel: [geo]
            media:
              channels: [tv]
            """,
        )
        @test_throws ArgumentError Epsilon._load_pipeline_configuration(
            PipelineRunConfig(config_path = panel_path),
        )

        vi_path = joinpath(tmpdir, "vi.yml")
        write(
            vi_path,
            """
            data:
              date_column: date
            target:
              column: revenue
            media:
              channels: [tv]
            fit:
              backend: vi
            """,
        )
        @test_throws ArgumentError Epsilon._load_pipeline_configuration(
            PipelineRunConfig(config_path = vi_path),
        )

        typo_path = joinpath(tmpdir, "typo.yml")
        write(
            typo_path,
            """
            data:
              date_column: date
              dataset_path: data.csv
            target:
              column: revenue
            media:
              channels: [tv]
            validaton:
              enabled: true
              holdout_rows: 4
            """,
        )
        @test_throws ArgumentError Epsilon._load_pipeline_configuration(
            PipelineRunConfig(config_path = typo_path),
        )

        invalid_validation_sampler_path = joinpath(tmpdir, "invalid_validation_sampler.yml")
        write(
            invalid_validation_sampler_path,
            """
            data:
              date_column: date
              dataset_path: data.csv
            target:
              column: revenue
            media:
              channels: [tv]
            fit:
              draws: 10
              tune: 10
              chains: 2
              cores: 2
            validation:
              enabled: true
              holdout_rows: 4
              sampler: light
            """,
        )
        @test_throws ModelConfigError Epsilon._load_pipeline_configuration(
            PipelineRunConfig(config_path = invalid_validation_sampler_path),
        )

        invalid_validation_sampler_typo_path =
            joinpath(tmpdir, "invalid_validation_sampler_typo.yml")
        write(
            invalid_validation_sampler_typo_path,
            """
            data:
              date_column: date
              dataset_path: data.csv
            target:
              column: revenue
            media:
              channels: [tv]
            validation:
              enabled: true
              holdout_rows: 4
              sampler:
                draw: 3
            """,
        )
        @test_throws ArgumentError Epsilon._load_pipeline_configuration(
            PipelineRunConfig(config_path = invalid_validation_sampler_typo_path),
        )

        invalid_validation_sampler_key_path =
            joinpath(tmpdir, "invalid_validation_sampler_key.yml")
        write(
            invalid_validation_sampler_key_path,
            """
            data:
              date_column: date
              dataset_path: data.csv
            target:
              column: revenue
            media:
              channels: [tv]
            fit:
              draws: 10
              tune: 10
              chains: 2
              cores: 2
            validation:
              enabled: true
              holdout_rows: 4
              sampler:
                draws: 3
                backend: vi
            """,
        )
        @test_throws ArgumentError Epsilon._load_pipeline_configuration(
            PipelineRunConfig(config_path = invalid_validation_sampler_key_path),
        )

        unsupported_prior_path = joinpath(tmpdir, "unsupported_prior.yml")
        write(
            unsupported_prior_path,
            """
            data:
              date_column: date
              dataset_path: data.csv
            target:
              column: revenue
            media:
              channels: [tv]
            prior_sensitivity:
              enabled: true
              scenarios:
                bad:
                  overrides:
                    media.channels: [search]
            """,
        )
        @test_throws ArgumentError Epsilon._load_pipeline_configuration(
            PipelineRunConfig(config_path = unsupported_prior_path),
        )

        structure_prior_path = joinpath(tmpdir, "structure_prior.yml")
        write(
            structure_prior_path,
            """
            data:
              date_column: date
              dataset_path: data.csv
            target:
              column: revenue
            media:
              channels: [tv]
            prior_sensitivity:
              enabled: true
              scenarios:
                longer_kernel:
                  overrides:
                    media.adstock.l_max: 12
            """,
        )
        @test_throws ArgumentError Epsilon._load_pipeline_configuration(
            PipelineRunConfig(config_path = structure_prior_path),
        )

        panel_calibration_path = joinpath(tmpdir, "panel_calibration.yml")
        write(
            panel_calibration_path,
            """
            data:
              date_column: date
              dataset_path: data.csv
            target:
              column: revenue
            dimensions:
              panel: [geo]
            media:
              channels: [tv]
            calibration:
              steps:
                - method: add_lift_test_measurements
              lift_test:
                channel: [tv]
                x: [1.0]
                delta_x: [0.5]
                delta_y: [0.3]
                sigma: [0.1]
            """,
        )
        @test_throws ModelConfigError Epsilon._load_pipeline_configuration(
            PipelineRunConfig(config_path = panel_calibration_path),
        )

        calibrated_vi_path = joinpath(tmpdir, "calibrated_vi.yml")
        write(
            calibrated_vi_path,
            """
            data:
              date_column: date
              dataset_path: data.csv
            target:
              column: revenue
            media:
              channels: [tv]
            fit:
              backend: vi
            calibration:
              steps:
                - method: add_lift_test_measurements
              lift_test:
                channel: [tv]
                x: [1.0]
                delta_x: [0.5]
                delta_y: [0.3]
                sigma: [0.1]
            """,
        )
        @test_throws ArgumentError Epsilon._load_pipeline_configuration(
            PipelineRunConfig(config_path = calibrated_vi_path),
        )
    end
end
