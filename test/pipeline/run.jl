using CSV
using CairoMakie
using Dates
using Epsilon
using JSON3
using Test
using YAML

if !isdefined(@__MODULE__, :ABACUS_TIMESERIES_CONFIG_DATA)
    include(joinpath(@__DIR__, "..", "fixtures", "abacus", "timeseries", "config_data.jl"))
end
if !isdefined(@__MODULE__, :ABACUS_GEO_PANEL_CONFIG_DATA)
    include(joinpath(@__DIR__, "..", "fixtures", "abacus", "geo_panel", "config_data.jl"))
end
if !isdefined(@__MODULE__, :ABACUS_GEO_BRAND_PANEL_CONFIG_DATA)
    include(joinpath(@__DIR__, "..", "fixtures", "abacus", "geo_brand_panel", "config_data.jl"))
end

const _PIPELINE_SUCCESS_SOLVER_STATUSES = Set(
    [
        :optimal,
        :locally_solved,
        :almost_optimal,
        :almost_locally_solved,
    ]
)
const _PIPELINE_SUPPORTED_ABACUS_STAGES = Set(
    [
        "metadata",
        "prior_sensitivity",
        "preflight",
        "fit",
        "assessment",
        "validation",
        "decomposition",
        "diagnostics",
        "curves",
        "optimisation",
    ]
)
const _PIPELINE_DEFERRED_ABACUS_STAGES = Set(["ai_advisor", "ai_diagnostics_advisor"])
const _PIPELINE_PENDING_ABACUS_STAGES = Set(String[])

_stage_record(result::PipelineRunResult, key::AbstractString) =
    only(filter(record -> record.key == key, result.stage_records))

function _duplicate_header_dataset(source_path::AbstractString, output_path::AbstractString)
    source_lines = readlines(source_path)
    header = split(first(source_lines), ",")
    duplicate_header = join([header[1], header[2], header[2], header[4:end]...], ",")
    write(output_path, join(vcat(duplicate_header, source_lines[2:end]), "\n") * "\n")
    return output_path
end

function _abacus_panel_pipeline_config(source_path::AbstractString, output_path::AbstractString)
    config = YAML.load_file(source_path)
    fixture_dir = dirname(source_path)
    config["data"]["dataset_path"] = joinpath(fixture_dir, "dataset.csv")
    config["holidays"]["path"] = joinpath(fixture_dir, "holidays.csv")
    YAML.write_file(output_path, config)
    return output_path
end

@testset "run_pipeline executes the bounded Stage 00-70 surface truthfully" begin
    fixture = joinpath(@__DIR__, "..", "fixtures", "pipeline_config.yml")
    dataset_fixture = joinpath(@__DIR__, "..", "fixtures", "pipeline_dataset.csv")

    mktempdir() do tmpdir
        result = run_pipeline(
            PipelineRunConfig(
                config_path = fixture,
                output_dir = joinpath(tmpdir, "results"),
                run_name = "demo",
                dataset_path = dataset_fixture,
                prior_samples = 12,
                curve_points = 15,
                draws = 12,
                tune = 12,
                chains = 1,
                cores = 1,
                random_seed = 7,
            ),
        )

        @test result isa PipelineRunResult
        @test result.status == :completed
        @test isdir(result.run_dir)
        @test isfile(result.manifest_path)
        @test isempty(result.warnings)

        metadata_record = _stage_record(result, "metadata")
        prior_sensitivity_record = _stage_record(result, "prior_sensitivity")
        preflight_record = _stage_record(result, "preflight")
        fit_record = _stage_record(result, "fit")
        assessment_record = _stage_record(result, "assessment")
        validation_record = _stage_record(result, "validation")
        decomposition_record = _stage_record(result, "decomposition")
        diagnostics_record = _stage_record(result, "diagnostics")
        curves_record = _stage_record(result, "curves")
        optimisation_record = _stage_record(result, "optimisation")
        @test metadata_record.status == :completed
        @test prior_sensitivity_record.status == :completed
        @test preflight_record.status == :completed
        @test fit_record.status == :completed
        @test assessment_record.status == :completed
        @test validation_record.status == :completed
        @test decomposition_record.status == :completed
        @test diagnostics_record.status == :completed
        @test curves_record.status == :completed
        @test optimisation_record.status == :skipped
        @test haskey(metadata_record.artifact_paths, "config_copy")
        @test haskey(metadata_record.artifact_paths, "config_original")
        @test haskey(metadata_record.artifact_paths, "data_dictionary")
        @test haskey(metadata_record.artifact_paths, "dataset_metadata")
        @test haskey(metadata_record.artifact_paths, "design_matrix_manifest")
        @test haskey(metadata_record.artifact_paths, "holiday_feature_manifest")
        @test haskey(metadata_record.artifact_paths, "session_info")
        @test haskey(prior_sensitivity_record.artifact_paths, "scenario_manifest")
        @test haskey(prior_sensitivity_record.artifact_paths, "llm_safe_scenario_manifest")
        @test haskey(fit_record.artifact_paths, "idata")
        @test haskey(assessment_record.artifact_paths, "posterior_predictive")
        @test haskey(assessment_record.artifact_paths, "posterior_predictive_summary")
        @test haskey(assessment_record.artifact_paths, "fit_timeseries_plot")
        @test haskey(assessment_record.artifact_paths, "fit_scatter_plot")
        @test haskey(assessment_record.artifact_paths, "residuals_hist_plot")
        @test haskey(assessment_record.artifact_paths, "residuals_timeseries_plot")
        @test haskey(assessment_record.artifact_paths, "residuals_vs_fitted_plot")
        @test haskey(validation_record.artifact_paths, "holdout_posterior_predictive")
        @test haskey(validation_record.artifact_paths, "holdout_predictive_report")
        @test haskey(validation_record.artifact_paths, "holdout_residuals_acf_plot")
        @test haskey(decomposition_record.artifact_paths, "channel_contributions")
        @test haskey(decomposition_record.artifact_paths, "baseline_contributions")
        @test haskey(decomposition_record.artifact_paths, "weekly_media_contribution_plot")
        @test haskey(diagnostics_record.artifact_paths, "mcmc_report")
        @test haskey(diagnostics_record.artifact_paths, "vif_report")
        @test haskey(diagnostics_record.artifact_paths, "residuals_acf_plot")
        @test haskey(curves_record.artifact_paths, "forward_pass_contribution_curve")
        @test haskey(curves_record.artifact_paths, "saturation_curve")
        @test haskey(curves_record.artifact_paths, "adstock_curve")
        @test any(contains("Turing NUTS path"), fit_record.warnings)

        config_copy_path = joinpath(result.run_dir, "00_run_metadata", "config.yml")
        original_path = joinpath(result.run_dir, "00_run_metadata", "config.original.yaml")
        resolved_path = joinpath(result.run_dir, "00_run_metadata", "config.resolved.yaml")
        model_path = joinpath(result.run_dir, "00_run_metadata", "config.model.yaml")
        data_dictionary_path = joinpath(result.run_dir, "00_run_metadata", "data_dictionary.csv")
        dataset_metadata_path = joinpath(result.run_dir, "00_run_metadata", "dataset_metadata.json")
        design_matrix_manifest_path = joinpath(result.run_dir, "00_run_metadata", "design_matrix_manifest.csv")
        holiday_feature_manifest_path = joinpath(result.run_dir, "00_run_metadata", "holiday_feature_manifest.csv")
        model_metadata_path = joinpath(result.run_dir, "00_run_metadata", "model_metadata.json")
        session_info_path = joinpath(result.run_dir, "00_run_metadata", "session_info.txt")
        spec_summary_path = joinpath(result.run_dir, "00_run_metadata", "spec_summary.csv")
        scenario_manifest_path = joinpath(result.run_dir, "05_prior_sensitivity", "scenario_manifest.yaml")
        llm_safe_scenario_manifest_path =
            joinpath(result.run_dir, "05_prior_sensitivity", "llm_safe_scenario_manifest.yaml")
        reference_scenario_path =
            joinpath(result.run_dir, "05_prior_sensitivity", "reference", "config.resolved.yaml")
        tighter_intercept_scenario_path =
            joinpath(result.run_dir, "05_prior_sensitivity", "tighter_intercept", "config.resolved.yaml")
        prior_predictive_path = joinpath(result.run_dir, "10_pre_diagnostics", "prior_predictive.jls")
        prior_summary_path = joinpath(result.run_dir, "10_pre_diagnostics", "prior_predictive_summary.csv")
        prior_predictive_plot_path = joinpath(result.run_dir, "10_pre_diagnostics", "prior_predictive.png")
        model_artifact_path = joinpath(result.run_dir, "20_model_fit", "model.jls")
        grouped_path = joinpath(result.run_dir, "20_model_fit", "inference_results.jls")
        posterior_summary_path = joinpath(result.run_dir, "20_model_fit", "posterior_summary.csv")
        trace_plot_path = joinpath(result.run_dir, "20_model_fit", "trace.png")
        results_path = joinpath(result.run_dir, "30_model_assessment", "model_results.jls")
        observed_path = joinpath(result.run_dir, "30_model_assessment", "observed.csv")
        fitted_path = joinpath(result.run_dir, "30_model_assessment", "fitted.csv")
        residuals_path = joinpath(result.run_dir, "30_model_assessment", "residuals.csv")
        predictive_summary_path = joinpath(result.run_dir, "30_model_assessment", "predictive_summary.csv")
        posterior_predictive_path = joinpath(result.run_dir, "30_model_assessment", "posterior_predictive.jls")
        posterior_predictive_summary_path = joinpath(result.run_dir, "30_model_assessment", "posterior_predictive_summary.csv")
        posterior_predictive_plot_path = joinpath(result.run_dir, "30_model_assessment", "posterior_predictive.png")
        fit_timeseries_plot_path = joinpath(result.run_dir, "30_model_assessment", "fit_timeseries.png")
        fit_scatter_plot_path = joinpath(result.run_dir, "30_model_assessment", "fit_scatter.png")
        residuals_hist_plot_path = joinpath(result.run_dir, "30_model_assessment", "residuals_hist.png")
        residuals_timeseries_plot_path = joinpath(result.run_dir, "30_model_assessment", "residuals_timeseries.png")
        residuals_vs_fitted_plot_path = joinpath(result.run_dir, "30_model_assessment", "residuals_vs_fitted.png")
        observed_fitted_plot_path = joinpath(result.run_dir, "30_model_assessment", "observed_fitted.png")
        residual_diagnostics_plot_path = joinpath(result.run_dir, "30_model_assessment", "residual_diagnostics.png")
        validation_metadata_path = joinpath(result.run_dir, "35_holdout_validation", "validation_metadata.json")
        validation_results_path = joinpath(result.run_dir, "35_holdout_validation", "validation_results.jls")
        holdout_observed_path = joinpath(result.run_dir, "35_holdout_validation", "holdout_observed.csv")
        holdout_fitted_path = joinpath(result.run_dir, "35_holdout_validation", "holdout_fitted.csv")
        holdout_residuals_path = joinpath(result.run_dir, "35_holdout_validation", "holdout_residuals.csv")
        holdout_posterior_predictive_path = joinpath(result.run_dir, "35_holdout_validation", "holdout_posterior_predictive.jls")
        holdout_predictive_summary_path = joinpath(result.run_dir, "35_holdout_validation", "holdout_predictive_summary.csv")
        holdout_predictive_report_path = joinpath(result.run_dir, "35_holdout_validation", "holdout_predictive_report.json")
        holdout_residuals_acf_path = joinpath(result.run_dir, "35_holdout_validation", "holdout_residuals_acf.png")
        holdout_summary_path = joinpath(result.run_dir, "35_holdout_validation", "holdout_summary.csv")
        holdout_plot_path = joinpath(result.run_dir, "35_holdout_validation", "holdout_timeseries.png")
        contribution_results_path = joinpath(result.run_dir, "40_decomposition", "contribution_results.jls")
        decomposition_results_path = joinpath(result.run_dir, "40_decomposition", "decomposition_results.jls")
        contribution_summary_path = joinpath(result.run_dir, "40_decomposition", "contribution_summary.csv")
        decomposition_summary_path = joinpath(result.run_dir, "40_decomposition", "decomposition_summary.csv")
        baseline_contributions_path = joinpath(result.run_dir, "40_decomposition", "baseline_contributions.csv")
        channel_contributions_path = joinpath(result.run_dir, "40_decomposition", "channel_contributions.csv")
        mean_contributions_path = joinpath(result.run_dir, "40_decomposition", "mean_contributions_over_time.csv")
        contribution_plot_path = joinpath(result.run_dir, "40_decomposition", "contributions.png")
        weekly_media_plot_path = joinpath(result.run_dir, "40_decomposition", "weekly_media_contribution.png")
        waterfall_plot_path = joinpath(result.run_dir, "40_decomposition", "waterfall_components_decomposition.png")
        model_diagnostics_path = joinpath(result.run_dir, "50_diagnostics", "model_diagnostics.jls")
        sampler_diagnostics_path = joinpath(result.run_dir, "50_diagnostics", "sampler_diagnostics.jls")
        convergence_report_path = joinpath(result.run_dir, "50_diagnostics", "convergence_report.json")
        warnings_summary_path = joinpath(result.run_dir, "50_diagnostics", "warnings_summary.json")
        posterior_density_plot_path = joinpath(result.run_dir, "50_diagnostics", "posterior_density.png")
        chain_diagnostics_path = joinpath(result.run_dir, "50_diagnostics", "chain_diagnostics.txt")
        design_report_path = joinpath(result.run_dir, "50_diagnostics", "design_report.json")
        design_summary_path = joinpath(result.run_dir, "50_diagnostics", "design_summary.csv")
        diagnostics_report_path = joinpath(result.run_dir, "50_diagnostics", "diagnostics_report.csv")
        diagnostics_summary_path = joinpath(result.run_dir, "50_diagnostics", "diagnostics_summary.txt")
        mcmc_report_path = joinpath(result.run_dir, "50_diagnostics", "mcmc_report.json")
        mcmc_summary_path = joinpath(result.run_dir, "50_diagnostics", "mcmc_summary.csv")
        diagnostics_predictive_report_path = joinpath(result.run_dir, "50_diagnostics", "predictive_report.json")
        diagnostics_predictive_summary_path = joinpath(result.run_dir, "50_diagnostics", "predictive_summary.csv")
        residual_diagnostics_path = joinpath(result.run_dir, "50_diagnostics", "residual_diagnostics.csv")
        residuals_acf_path = joinpath(result.run_dir, "50_diagnostics", "residuals_acf.png")
        vif_report_path = joinpath(result.run_dir, "50_diagnostics", "vif_report.csv")
        metric_results_path = joinpath(result.run_dir, "60_response_curves", "metric_results.jls")
        response_curve_results_path = joinpath(result.run_dir, "60_response_curves", "response_curve_tv.jls")
        saturation_curve_results_path = joinpath(result.run_dir, "60_response_curves", "saturation_curve_tv.jls")
        adstock_curve_results_path = joinpath(result.run_dir, "60_response_curves", "adstock_curve_tv.jls")
        response_curve_bundle_path = joinpath(result.run_dir, "60_response_curves", "response_curve.jls")
        saturation_curve_bundle_path = joinpath(result.run_dir, "60_response_curves", "saturation_curve.jls")
        adstock_curve_bundle_path = joinpath(result.run_dir, "60_response_curves", "adstock_curve.jls")
        curve_summary_path = joinpath(result.run_dir, "60_response_curves", "curve_summary.csv")
        metric_summary_path = joinpath(result.run_dir, "60_response_curves", "metric_summary.csv")
        response_curve_summary_path = joinpath(result.run_dir, "60_response_curves", "forward_pass_contribution_curve_summary.csv")
        saturation_curve_summary_path = joinpath(result.run_dir, "60_response_curves", "saturation_curve_summary.csv")
        adstock_curve_summary_path = joinpath(result.run_dir, "60_response_curves", "adstock_curve_summary.csv")
        response_curve_bundle_plot_path = joinpath(result.run_dir, "60_response_curves", "forward_pass_contribution_curve.png")
        saturation_curve_bundle_plot_path = joinpath(result.run_dir, "60_response_curves", "saturation_curve.png")
        adstock_curve_bundle_plot_path = joinpath(result.run_dir, "60_response_curves", "adstock_curve.png")
        response_curve_plot_path = joinpath(result.run_dir, "60_response_curves", "response_curve_tv.png")
        saturation_curve_plot_path = joinpath(result.run_dir, "60_response_curves", "saturation_curve_tv.png")
        adstock_curve_plot_path = joinpath(result.run_dir, "60_response_curves", "adstock_curve_tv.png")

        @test isfile(config_copy_path)
        @test isfile(original_path)
        @test isfile(resolved_path)
        @test isfile(model_path)
        @test isfile(data_dictionary_path)
        @test isfile(dataset_metadata_path)
        @test isfile(design_matrix_manifest_path)
        @test isfile(holiday_feature_manifest_path)
        @test isfile(model_metadata_path)
        @test isfile(session_info_path)
        @test isfile(spec_summary_path)
        @test isfile(scenario_manifest_path)
        @test isfile(llm_safe_scenario_manifest_path)
        @test isfile(reference_scenario_path)
        @test isfile(tighter_intercept_scenario_path)
        @test isfile(prior_predictive_path)
        @test isfile(prior_summary_path)
        @test isfile(prior_predictive_plot_path)
        @test isfile(model_artifact_path)
        @test isfile(grouped_path)
        @test isfile(posterior_summary_path)
        @test isfile(trace_plot_path)
        @test isfile(results_path)
        @test isfile(observed_path)
        @test isfile(fitted_path)
        @test isfile(residuals_path)
        @test isfile(predictive_summary_path)
        @test isfile(posterior_predictive_path)
        @test isfile(posterior_predictive_summary_path)
        @test isfile(posterior_predictive_plot_path)
        @test isfile(fit_timeseries_plot_path)
        @test isfile(fit_scatter_plot_path)
        @test isfile(residuals_hist_plot_path)
        @test isfile(residuals_timeseries_plot_path)
        @test isfile(residuals_vs_fitted_plot_path)
        @test isfile(observed_fitted_plot_path)
        @test isfile(residual_diagnostics_plot_path)
        @test isfile(validation_metadata_path)
        @test isfile(validation_results_path)
        @test isfile(holdout_observed_path)
        @test isfile(holdout_fitted_path)
        @test isfile(holdout_residuals_path)
        @test isfile(holdout_posterior_predictive_path)
        @test isfile(holdout_predictive_summary_path)
        @test isfile(holdout_predictive_report_path)
        @test isfile(holdout_residuals_acf_path)
        @test isfile(holdout_summary_path)
        @test isfile(holdout_plot_path)
        @test isfile(contribution_results_path)
        @test isfile(decomposition_results_path)
        @test isfile(contribution_summary_path)
        @test isfile(decomposition_summary_path)
        @test isfile(baseline_contributions_path)
        @test isfile(channel_contributions_path)
        @test isfile(mean_contributions_path)
        @test isfile(contribution_plot_path)
        @test isfile(weekly_media_plot_path)
        @test isfile(waterfall_plot_path)
        @test isfile(model_diagnostics_path)
        @test isfile(sampler_diagnostics_path)
        @test isfile(convergence_report_path)
        @test isfile(warnings_summary_path)
        @test isfile(posterior_density_plot_path)
        @test isfile(chain_diagnostics_path)
        @test isfile(design_report_path)
        @test isfile(design_summary_path)
        @test isfile(diagnostics_report_path)
        @test isfile(diagnostics_summary_path)
        @test isfile(mcmc_report_path)
        @test isfile(mcmc_summary_path)
        @test isfile(diagnostics_predictive_report_path)
        @test isfile(diagnostics_predictive_summary_path)
        @test isfile(residual_diagnostics_path)
        @test isfile(residuals_acf_path)
        @test isfile(vif_report_path)
        @test isfile(response_curve_results_path)
        @test isfile(saturation_curve_results_path)
        @test isfile(adstock_curve_results_path)
        @test isfile(response_curve_bundle_path)
        @test isfile(saturation_curve_bundle_path)
        @test isfile(adstock_curve_bundle_path)
        @test isfile(metric_results_path)
        @test isfile(curve_summary_path)
        @test isfile(metric_summary_path)
        @test isfile(response_curve_summary_path)
        @test isfile(saturation_curve_summary_path)
        @test isfile(adstock_curve_summary_path)
        @test isfile(response_curve_bundle_plot_path)
        @test isfile(saturation_curve_bundle_plot_path)
        @test isfile(adstock_curve_bundle_plot_path)
        @test isfile(response_curve_plot_path)
        @test isfile(saturation_curve_plot_path)
        @test isfile(adstock_curve_plot_path)

        @test occursin("dataset_path: data/input.csv", read(original_path, String))

        resolved = YAML.load_file(resolved_path)
        @test resolved["data"]["dataset_path"] == dataset_fixture
        @test resolved["fit"]["draws"] == 12
        @test resolved["fit"]["tune"] == 12
        @test resolved["fit"]["chains"] == 1
        @test resolved["validation"]["enabled"] == true
        @test resolved["optimization"]["enabled"] == false

        model_cfg = YAML.load_file(model_path)
        @test !haskey(model_cfg, "validation")
        @test !haskey(model_cfg, "prior_sensitivity")
        @test !haskey(model_cfg, "optimization")
        @test !haskey(model_cfg["data"], "dataset_path")
        scenario_manifest = YAML.load_file(scenario_manifest_path)
        @test scenario_manifest["reference"] == "reference"
        @test scenario_manifest["scenario_policy"] == "manual"
        @test length(scenario_manifest["scenarios"]) == 2
        @test Set(String.(getindex.(scenario_manifest["scenarios"], "name"))) ==
            Set(["reference", "tighter_intercept"])
        tighter_intercept = YAML.load_file(tighter_intercept_scenario_path)
        @test !haskey(tighter_intercept, "prior_sensitivity")
        @test tighter_intercept["priors"]["intercept"]["sigma"] == 0.5
        @test tighter_intercept["data"]["dataset_path"] == dataset_fixture
        llm_safe_manifest = YAML.load_file(llm_safe_scenario_manifest_path)
        @test llm_safe_manifest["privacy_mode"] == "anonymized_relative"
        @test all(!haskey(scenario, "description") for scenario in llm_safe_manifest["scenarios"])

        manifest = JSON3.read(read(result.manifest_path, String))
        abacus_contract = ABACUS_TIMESERIES_CONFIG_DATA.pipeline_contract
        @test Set(keys(ABACUS_TIMESERIES_CONFIG_DATA.stage_directories)) ==
            union(
            _PIPELINE_SUPPORTED_ABACUS_STAGES,
            _PIPELINE_DEFERRED_ABACUS_STAGES,
            _PIPELINE_PENDING_ABACUS_STAGES,
        )
        for record in result.stage_records
            @test record.directory == ABACUS_TIMESERIES_CONFIG_DATA.stage_directories[record.key]
        end
        @test Set(String.(keys(manifest["stages"]))) == _PIPELINE_SUPPORTED_ABACUS_STAGES
        @test Set(abacus_contract.manifest_stage_artifact_keys["metadata"]) ⊆
            Set(keys(metadata_record.artifact_paths))
        @test Set(abacus_contract.manifest_stage_artifact_keys["fit"]) ⊆
            Set(keys(fit_record.artifact_paths))
        @test Set(abacus_contract.manifest_stage_artifact_keys["assessment"]) ⊆
            Set(keys(assessment_record.artifact_paths))
        @test Set(abacus_contract.manifest_stage_artifact_keys["validation"]) ⊆
            Set(keys(validation_record.artifact_paths))
        @test Set(abacus_contract.manifest_stage_artifact_keys["decomposition"]) ⊆
            Set(keys(decomposition_record.artifact_paths))
        @test Set(abacus_contract.manifest_stage_artifact_keys["diagnostics"]) ⊆
            Set(keys(diagnostics_record.artifact_paths))
        @test Set(abacus_contract.manifest_stage_artifact_keys["curves"]) ⊆
            Set(keys(curves_record.artifact_paths))
        for filename in abacus_contract.artifact_files["metadata"]
            @test isfile(joinpath(result.run_dir, "00_run_metadata", filename))
        end
        for key in abacus_contract.manifest_stage_artifact_keys["fit"]
            @test isfile(joinpath(result.run_dir, fit_record.artifact_paths[key]))
        end
        for key in abacus_contract.manifest_stage_artifact_keys["assessment"]
            @test isfile(joinpath(result.run_dir, assessment_record.artifact_paths[key]))
        end
        for (record, stage) in (
                (validation_record, "validation"),
                (decomposition_record, "decomposition"),
                (diagnostics_record, "diagnostics"),
                (curves_record, "curves"),
            )
            for key in abacus_contract.manifest_stage_artifact_keys[stage]
                @test isfile(joinpath(result.run_dir, record.artifact_paths[key]))
            end
        end

        @test manifest["status"] == "completed"
        @test manifest["model_type"] == "TimeSeriesMMM"
        @test manifest["data"]["date_column"] == "date"
        @test manifest["data"]["n_rows"] == 6
        @test manifest["data"]["date_type"] == "Date"
        @test manifest["data"]["date_min"] == "2024-01-01"
        @test manifest["data"]["date_max"] == "2024-01-06"
        @test length(manifest["data"]["channel_columns"]) == 2
        @test manifest["stages"]["metadata"]["status"] == "completed"
        @test manifest["stages"]["prior_sensitivity"]["status"] == "completed"
        @test manifest["stages"]["preflight"]["status"] == "completed"
        @test manifest["stages"]["fit"]["status"] == "completed"
        @test manifest["stages"]["assessment"]["status"] == "completed"
        @test manifest["stages"]["validation"]["status"] == "completed"
        @test manifest["stages"]["decomposition"]["status"] == "completed"
        @test manifest["stages"]["diagnostics"]["status"] == "completed"
        @test manifest["stages"]["curves"]["status"] == "completed"
        @test manifest["stages"]["optimisation"]["status"] == "skipped"
        @test manifest["stages"]["metadata"]["artifact_paths"]["config_model"] ==
            "00_run_metadata/config.model.yaml"
        @test manifest["stages"]["curves"]["artifact_paths"]["metric_summary"] == "60_response_curves/metric_summary.csv"
        @test manifest["stages"]["fit"]["artifact_paths"]["trace_plot"] ==
            "20_model_fit/trace.png"
        @test manifest["stages"]["fit"]["artifact_paths"]["idata"] ==
            "20_model_fit/inference_results.jls"
        @test manifest["stages"]["assessment"]["artifact_paths"]["observed_fitted_plot"] ==
            "30_model_assessment/observed_fitted.png"
        @test manifest["stages"]["assessment"]["artifact_paths"]["posterior_predictive"] ==
            "30_model_assessment/posterior_predictive.jls"
        @test manifest["stages"]["assessment"]["artifact_paths"]["posterior_predictive_summary"] ==
            "30_model_assessment/posterior_predictive_summary.csv"
        @test manifest["stages"]["assessment"]["artifact_paths"]["fit_timeseries_plot"] ==
            "30_model_assessment/fit_timeseries.png"
        @test manifest["stages"]["assessment"]["artifact_paths"]["fit_scatter_plot"] ==
            "30_model_assessment/fit_scatter.png"
        @test manifest["stages"]["assessment"]["artifact_paths"]["residuals_hist_plot"] ==
            "30_model_assessment/residuals_hist.png"
        @test manifest["stages"]["assessment"]["artifact_paths"]["residuals_timeseries_plot"] ==
            "30_model_assessment/residuals_timeseries.png"
        @test manifest["stages"]["assessment"]["artifact_paths"]["residuals_vs_fitted_plot"] ==
            "30_model_assessment/residuals_vs_fitted.png"
        @test manifest["stages"]["curves"]["artifact_paths"]["response_curve_tv_plot"] ==
            "60_response_curves/response_curve_tv.png"
        @test manifest["stages"]["metadata"]["artifact_paths"]["config_copy"] ==
            "00_run_metadata/config.yml"
        @test manifest["stages"]["metadata"]["artifact_paths"]["data_dictionary"] ==
            "00_run_metadata/data_dictionary.csv"
        @test manifest["stages"]["metadata"]["artifact_paths"]["design_matrix_manifest"] ==
            "00_run_metadata/design_matrix_manifest.csv"
        @test manifest["stages"]["metadata"]["artifact_paths"]["holiday_feature_manifest"] ==
            "00_run_metadata/holiday_feature_manifest.csv"
        @test manifest["stages"]["metadata"]["artifact_paths"]["session_info"] ==
            "00_run_metadata/session_info.txt"
        @test manifest["stages"]["curves"]["artifact_paths"]["saturation_curve_tv_plot"] ==
            "60_response_curves/saturation_curve_tv.png"
        @test manifest["stages"]["curves"]["artifact_paths"]["adstock_curve_tv_plot"] ==
            "60_response_curves/adstock_curve_tv.png"

        @test read(config_copy_path, String) == read(original_path, String)

        data_dictionary = CSV.File(data_dictionary_path)
        @test collect(data_dictionary.column) == ["date", "revenue", "tv", "search"]
        @test collect(data_dictionary.role) == ["date", "target", "media", "media"]

        dataset_metadata = JSON3.read(read(dataset_metadata_path, String))
        @test dataset_metadata["n_rows"] == 6
        @test dataset_metadata["date_min"] == "2024-01-01"
        @test dataset_metadata["date_max"] == "2024-01-06"

        design_matrix_manifest = CSV.File(design_matrix_manifest_path)
        @test Set(design_matrix_manifest.feature_group) == Set(["target", "media"])
        @test Set(design_matrix_manifest.feature) == Set(["revenue", "tv", "search"])
        @test all(==(6), design_matrix_manifest.n_rows)

        holiday_feature_manifest = CSV.File(holiday_feature_manifest_path)
        @test isempty(collect(holiday_feature_manifest.feature))

        model_metadata = JSON3.read(read(model_metadata_path, String))
        @test model_metadata["model_type"] == "TimeSeriesMMM"
        @test model_metadata["backend"] == "turing"
        @test model_metadata["objective"] == "revenue"

        session_info = read(session_info_path, String)
        @test occursin("Epsilon.jl session information", session_info)
        @test occursin("model_type: TimeSeriesMMM", session_info)

        spec_summary = CSV.File(spec_summary_path)
        @test only(spec_summary.nobs) == 6
        @test only(spec_summary.nchannels) == 2

        prior_predictive = Epsilon._load_pipeline_serialized(
            prior_predictive_path;
            expected_kind = "PriorPredictiveChain",
        )
        @test size(prior_predictive, 1) == 12

        prior_summary = CSV.File(prior_summary_path)
        @test "overall_mean" in prior_summary.metric
        @test "observations" in prior_summary.metric

        loaded_model = load_model(model_artifact_path)
        @test loaded_model isa TimeSeriesMMM
        @test loaded_model.fit_state.status == :fit

        grouped = load_inference_results(grouped_path)
        @test grouped isa InferenceResults
        @test !isnothing(grouped.posterior)
        @test grouped.posterior_predictive === nothing
        @test grouped.observed_data == loaded_model.data

        posterior_summary = CSV.File(posterior_summary_path)
        @test :parameter in propertynames(posterior_summary)
        @test :mean in propertynames(posterior_summary)
        @test :rhat in propertynames(posterior_summary)

        loaded_results = load_results(results_path)
        @test loaded_results isa ModelResults
        @test !isnothing(loaded_results.posterior_predictive)

        observed = CSV.File(observed_path)
        fitted = CSV.File(fitted_path)
        residuals = CSV.File(residuals_path)
        predictive_summary = CSV.File(predictive_summary_path)
        posterior_predictive_summary = CSV.File(posterior_predictive_summary_path)

        @test collect(observed.date) == Date.(["2024-01-01", "2024-01-02", "2024-01-03", "2024-01-04", "2024-01-05", "2024-01-06"])
        @test length(observed.observed) == 6
        @test length(fitted.mean) == 6
        @test length(residuals.residual) == 6
        @test "mae" in predictive_summary.metric
        @test "rmse" in predictive_summary.metric
        @test length(posterior_predictive_summary.mean) == 6
        @test :draw_sd in propertynames(posterior_predictive_summary)

        posterior_predictive = Epsilon._load_pipeline_serialized(
            posterior_predictive_path;
            expected_kind = "PosteriorPredictiveChain",
        )
        @test size(posterior_predictive, 1) == 12

        validation_metadata = JSON3.read(read(validation_metadata_path, String))
        @test validation_metadata["holdout_rows"] == 4
        @test validation_metadata["train_rows"] == 2
        @test validation_metadata["holdout_rows_observed"] == 4
        @test validation_metadata["train_date_start"] == "2024-01-01"
        @test validation_metadata["train_date_end"] == "2024-01-02"
        @test validation_metadata["holdout_date_start"] == "2024-01-03"
        @test validation_metadata["holdout_date_end"] == "2024-01-06"

        validation_result = Epsilon._load_pipeline_serialized(
            validation_results_path;
            expected_kind = "PipelineValidationResult",
        )
        @test validation_result isa PipelineValidationResult
        @test validation_result.holdout_rows == 4
        @test length(validation_result.observed) == 4
        @test length(validation_result.fitted_mean) == 4
        @test length(validation_result.residuals) == 4
        @test validation_result.metrics["rmse"] >= 0.0

        holdout_summary = CSV.File(holdout_summary_path)
        @test "mae" in holdout_summary.metric
        @test "rmse" in holdout_summary.metric
        @test "bias" in holdout_summary.metric

        contributions = Epsilon._load_pipeline_serialized(
            contribution_results_path;
            expected_kind = "ContributionResults",
        )
        decomposition = Epsilon._load_pipeline_serialized(
            decomposition_results_path;
            expected_kind = "DecompositionResults",
        )
        @test contributions isa ContributionResults
        @test decomposition isa DecompositionResults
        @test size(contributions.values, 2) == 6
        @test "media:tv" in contributions.component_names
        @test "intercept" in decomposition.component_names

        contribution_summary = CSV.File(contribution_summary_path)
        decomposition_summary = CSV.File(decomposition_summary_path)
        @test :component in propertynames(contribution_summary)
        @test :mean in propertynames(contribution_summary)
        @test :component in propertynames(decomposition_summary)
        @test :share_mean in propertynames(decomposition_summary)

        model_diagnostics = Epsilon._load_pipeline_serialized(
            model_diagnostics_path;
            expected_kind = "ModelDiagnostics",
        )
        sampler_diagnostics = Epsilon._load_pipeline_serialized(
            sampler_diagnostics_path;
            expected_kind = "SamplerDiagnostics",
        )
        @test model_diagnostics isa ModelDiagnostics
        @test sampler_diagnostics isa SamplerDiagnostics

        convergence_report = JSON3.read(read(convergence_report_path, String))
        warnings_summary = JSON3.read(read(warnings_summary_path, String))
        @test haskey(convergence_report, "summary")
        @test haskey(convergence_report, "issues")
        @test haskey(warnings_summary, "sampler_warnings")
        @test haskey(warnings_summary, "convergence_warnings")
        @test haskey(warnings_summary, "summary")

        response_curve = Epsilon._load_pipeline_serialized(
            response_curve_results_path;
            expected_kind = "ResponseCurveResults",
        )
        saturation_curve = Epsilon._load_pipeline_serialized(
            saturation_curve_results_path;
            expected_kind = "SaturationCurveResults",
        )
        adstock_curve = Epsilon._load_pipeline_serialized(
            adstock_curve_results_path;
            expected_kind = "AdstockCurveResults",
        )
        metric_results = Epsilon._load_pipeline_serialized(
            metric_results_path;
            expected_kind = "MetricResultsByChannel",
        )
        @test response_curve isa ResponseCurveResults
        @test saturation_curve isa SaturationCurveResults
        @test adstock_curve isa AdstockCurveResults
        @test metric_results isa Dict{String, MetricResults}
        @test Set(keys(metric_results)) == Set(["tv", "search"])
        @test length(response_curve.spend_grid) == 15
        @test length(saturation_curve.spend_grid) == 15
        @test length(adstock_curve.spend_grid) == 15
        @test length(metric_results["search"].spend_grid) == 15

        curve_summary = CSV.File(curve_summary_path)
        metric_summary = CSV.File(metric_summary_path)
        @test length(curve_summary.channel) == 90
        @test length(metric_summary.channel) == 120
        @test Set(curve_summary.channel) == Set(["tv", "search"])
        @test Set(curve_summary.curve_family) == Set(["response", "saturation", "adstock"])
        @test Set(metric_summary.metric) == Set(["roas", "mroas", "cpa", "mcpa"])
    end
end

@testset "run_pipeline executes geo_panel Stage 00/20/30/40/50/60 panel parity" begin
    fixture = ABACUS_GEO_PANEL_CONFIG_DATA
    source_config = joinpath(@__DIR__, "..", "fixtures", "abacus", "geo_panel", "config.yml")

    mktempdir() do tmpdir
        config_path = _abacus_panel_pipeline_config(source_config, joinpath(tmpdir, "geo_panel.yml"))
        result = run_pipeline(
            PipelineRunConfig(
                config_path = config_path,
                output_dir = joinpath(tmpdir, "results"),
                run_name = "geo_panel_pipeline_curves",
                prior_samples = 6,
                curve_points = 8,
                draws = 6,
                tune = 6,
                chains = 1,
                cores = 1,
                random_seed = 31,
            ),
        )

        @test result.status == :completed
        @test !isempty(result.warnings)

        metadata_record = _stage_record(result, "metadata")
        fit_record = _stage_record(result, "fit")
        assessment_record = _stage_record(result, "assessment")
        decomposition_record = _stage_record(result, "decomposition")
        diagnostics_record = _stage_record(result, "diagnostics")
        curves_record = _stage_record(result, "curves")
        @test metadata_record.status == :completed
        @test fit_record.status == :completed
        @test assessment_record.status == :completed
        @test decomposition_record.status == :completed
        @test diagnostics_record.status == :completed
        @test curves_record.status == :completed
        for record in result.stage_records
            @test record.directory == fixture.stage_directories[record.key]
            record.key in ("metadata", "fit", "assessment", "decomposition", "diagnostics", "curves") && continue
            if record.key == "prior_sensitivity"
                @test record.status == :skipped
                @test isempty(record.warnings)
                continue
            end
            @test record.status == :skipped
            @test any(contains("metadata, prior sensitivity when explicitly enabled, fit"), record.warnings)
        end

        manifest = JSON3.read(read(result.manifest_path, String))
        abacus_contract = fixture.pipeline_contract
        @test manifest["status"] == "completed"
        @test manifest["model_type"] == "PanelMMM"
        @test manifest["data"]["n_rows"] == fixture.nobs
        @test manifest["data"]["n_time"] == fixture.ntime
        @test manifest["data"]["n_panels"] == fixture.npanels
        @test String.(manifest["data"]["panel_dims"]) == fixture.panel_dims
        @test String.(manifest["data"]["panel_names"]) == fixture.panel_names
        @test Set(abacus_contract.manifest_stage_artifact_keys["metadata"]) ⊆
            Set(keys(metadata_record.artifact_paths))
        @test Set(abacus_contract.manifest_stage_artifact_keys["fit"]) ⊆
            Set(keys(fit_record.artifact_paths))
        @test Set(abacus_contract.manifest_stage_artifact_keys["assessment"]) ⊆
            Set(keys(assessment_record.artifact_paths))
        @test Set(abacus_contract.manifest_stage_artifact_keys["decomposition"]) ⊆
            Set(keys(decomposition_record.artifact_paths))
        @test Set(abacus_contract.manifest_stage_artifact_keys["diagnostics"]) ⊆
            Set(keys(diagnostics_record.artifact_paths))
        @test Set(abacus_contract.manifest_stage_artifact_keys["curves"]) ⊆
            Set(keys(curves_record.artifact_paths))
        for filename in abacus_contract.artifact_files["metadata"]
            @test isfile(joinpath(result.run_dir, "00_run_metadata", filename))
        end
        for key in abacus_contract.manifest_stage_artifact_keys["fit"]
            @test isfile(joinpath(result.run_dir, fit_record.artifact_paths[key]))
        end
        for key in abacus_contract.manifest_stage_artifact_keys["assessment"]
            @test isfile(joinpath(result.run_dir, assessment_record.artifact_paths[key]))
        end
        for key in abacus_contract.manifest_stage_artifact_keys["decomposition"]
            @test isfile(joinpath(result.run_dir, decomposition_record.artifact_paths[key]))
        end
        for key in abacus_contract.manifest_stage_artifact_keys["diagnostics"]
            @test isfile(joinpath(result.run_dir, diagnostics_record.artifact_paths[key]))
        end
        for key in abacus_contract.manifest_stage_artifact_keys["curves"]
            @test isfile(joinpath(result.run_dir, curves_record.artifact_paths[key]))
        end

        metadata_dir = joinpath(result.run_dir, "00_run_metadata")
        fit_dir = joinpath(result.run_dir, "20_model_fit")
        assessment_dir = joinpath(result.run_dir, "30_model_assessment")
        decomposition_dir = joinpath(result.run_dir, "40_decomposition")
        diagnostics_dir = joinpath(result.run_dir, "50_diagnostics")
        curves_dir = joinpath(result.run_dir, "60_response_curves")
        dataset_metadata_path = joinpath(metadata_dir, "dataset_metadata.json")
        model_metadata_path = joinpath(metadata_dir, "model_metadata.json")
        data_dictionary_path = joinpath(metadata_dir, "data_dictionary.csv")
        design_matrix_manifest_path = joinpath(metadata_dir, "design_matrix_manifest.csv")
        session_info_path = joinpath(metadata_dir, "session_info.txt")
        spec_summary_path = joinpath(metadata_dir, "spec_summary.csv")
        model_artifact_path = joinpath(fit_dir, "model.jls")
        grouped_path = joinpath(fit_dir, "inference_results.jls")
        posterior_summary_path = joinpath(fit_dir, "posterior_summary.csv")
        trace_plot_path = joinpath(fit_dir, "trace.png")
        model_results_path = joinpath(assessment_dir, "model_results.jls")
        observed_path = joinpath(assessment_dir, "observed.csv")
        fitted_path = joinpath(assessment_dir, "fitted.csv")
        residuals_path = joinpath(assessment_dir, "residuals.csv")
        predictive_summary_path = joinpath(assessment_dir, "predictive_summary.csv")
        posterior_predictive_path = joinpath(assessment_dir, "posterior_predictive.jls")
        posterior_predictive_summary_path = joinpath(assessment_dir, "posterior_predictive_summary.csv")
        contribution_results_path = joinpath(decomposition_dir, "contribution_results.jls")
        decomposition_results_path = joinpath(decomposition_dir, "decomposition_results.jls")
        contribution_summary_path = joinpath(decomposition_dir, "contribution_summary.csv")
        decomposition_summary_path = joinpath(decomposition_dir, "decomposition_summary.csv")
        baseline_contributions_path = joinpath(decomposition_dir, "baseline_contributions.csv")
        channel_contributions_path = joinpath(decomposition_dir, "channel_contributions.csv")
        mean_contributions_path = joinpath(decomposition_dir, "mean_contributions_over_time.csv")
        waterfall_plot_path = joinpath(decomposition_dir, "waterfall_components_decomposition.png")
        weekly_media_plot_path = joinpath(decomposition_dir, "weekly_media_contribution.png")
        model_diagnostics_path = joinpath(diagnostics_dir, "model_diagnostics.jls")
        sampler_diagnostics_path = joinpath(diagnostics_dir, "sampler_diagnostics.jls")
        design_report_path = joinpath(diagnostics_dir, "design_report.json")
        design_summary_path = joinpath(diagnostics_dir, "design_summary.csv")
        diagnostics_report_path = joinpath(diagnostics_dir, "diagnostics_report.csv")
        diagnostics_summary_path = joinpath(diagnostics_dir, "diagnostics_summary.txt")
        mcmc_report_path = joinpath(diagnostics_dir, "mcmc_report.json")
        mcmc_summary_path = joinpath(diagnostics_dir, "mcmc_summary.csv")
        diagnostics_predictive_report_path = joinpath(diagnostics_dir, "predictive_report.json")
        diagnostics_predictive_summary_path = joinpath(diagnostics_dir, "predictive_summary.csv")
        residual_diagnostics_path = joinpath(diagnostics_dir, "residual_diagnostics.csv")
        residuals_acf_path = joinpath(diagnostics_dir, "residuals_acf.png")
        vif_report_path = joinpath(diagnostics_dir, "vif_report.csv")
        first_channel = first(fixture.channel_columns)
        response_curve_results_path = joinpath(curves_dir, "response_curve_$(first_channel).jls")
        saturation_curve_results_path = joinpath(curves_dir, "saturation_curve_$(first_channel).jls")
        adstock_curve_results_path = joinpath(curves_dir, "adstock_curve_$(first_channel).jls")
        response_curve_bundle_path = joinpath(curves_dir, "response_curve.jls")
        saturation_curve_bundle_path = joinpath(curves_dir, "saturation_curve.jls")
        adstock_curve_bundle_path = joinpath(curves_dir, "adstock_curve.jls")
        metric_results_path = joinpath(curves_dir, "metric_results.jls")
        curve_summary_path = joinpath(curves_dir, "curve_summary.csv")
        metric_summary_path = joinpath(curves_dir, "metric_summary.csv")
        response_curve_summary_path = joinpath(curves_dir, "forward_pass_contribution_curve_summary.csv")
        saturation_curve_summary_path = joinpath(curves_dir, "saturation_curve_summary.csv")
        adstock_curve_summary_path = joinpath(curves_dir, "adstock_curve_summary.csv")
        response_curve_bundle_plot_path = joinpath(curves_dir, "forward_pass_contribution_curve.png")
        saturation_curve_bundle_plot_path = joinpath(curves_dir, "saturation_curve.png")
        adstock_curve_bundle_plot_path = joinpath(curves_dir, "adstock_curve.png")

        dataset_metadata = JSON3.read(read(dataset_metadata_path, String))
        @test dataset_metadata["date_min"] == first(fixture.dates)
        @test dataset_metadata["date_max"] == last(fixture.dates)
        @test dataset_metadata["n_rows"] == fixture.nobs
        @test dataset_metadata["n_time"] == fixture.ntime
        @test dataset_metadata["n_panels"] == fixture.npanels
        @test String.(dataset_metadata["panel_dims"]) == fixture.panel_dims
        @test String.(dataset_metadata["panel_names"]) == fixture.panel_names

        model_metadata = JSON3.read(read(model_metadata_path, String))
        @test model_metadata["model_type"] == "PanelMMM"
        @test model_metadata["backend"] == "turing"
        @test model_metadata["nobs"] == fixture.nobs
        @test model_metadata["n_time"] == fixture.ntime
        @test model_metadata["npanels"] == fixture.npanels
        @test String.(model_metadata["panel_dims"]) == fixture.panel_dims

        data_dictionary = CSV.File(data_dictionary_path)
        @test collect(data_dictionary.column)[1:3] == ["date", "geo", "revenue"]
        @test collect(data_dictionary.role)[1:3] == ["date", "panel", "target"]
        @test count(==("media"), collect(data_dictionary.role)) == length(fixture.channel_columns)

        design_matrix_manifest = CSV.File(design_matrix_manifest_path)
        @test "panel" in collect(design_matrix_manifest.feature_group)
        @test Set(fixture.channel_columns) ⊆ Set(String.(design_matrix_manifest.feature))
        @test all(==(fixture.nobs), design_matrix_manifest.n_rows)

        session_info = read(session_info_path, String)
        @test occursin("model_type: PanelMMM", session_info)
        @test occursin("panel_dims: geo", session_info)

        spec_summary = CSV.File(spec_summary_path)
        @test only(spec_summary.model_kind) == "panel_mmm"
        @test only(spec_summary.nobs) == fixture.nobs
        @test only(spec_summary.nchannels) == length(fixture.channel_columns)

        @test isfile(model_artifact_path)
        @test isfile(grouped_path)
        @test isfile(posterior_summary_path)
        @test isfile(trace_plot_path)
        loaded_model = load_model(model_artifact_path)
        @test loaded_model isa PanelMMM
        @test loaded_model.fit_state.status == :fit

        grouped = load_inference_results(grouped_path)
        @test grouped isa InferenceResults
        @test grouped.metadata.model_type == "PanelMMM"
        @test grouped.observed_data isa PanelMMMData
        @test grouped.observed_data.panel_names == fixture.panel_names

        posterior_summary = CSV.File(posterior_summary_path)
        @test :parameter in propertynames(posterior_summary)
        @test :mean in propertynames(posterior_summary)
        @test :rhat in propertynames(posterior_summary)

        loaded_results = load_results(model_results_path)
        @test loaded_results isa ModelResults
        @test !isnothing(loaded_results.posterior_predictive)

        observed = CSV.File(observed_path)
        fitted = CSV.File(fitted_path)
        residuals = CSV.File(residuals_path)
        predictive_summary = CSV.File(predictive_summary_path)
        posterior_predictive_summary = CSV.File(posterior_predictive_summary_path)
        @test length(observed.observed) == fixture.nobs
        @test length(fitted.mean) == fixture.nobs
        @test length(residuals.residual) == fixture.nobs
        @test collect(observed.date)[1:fixture.ntime] == Date.(fixture.dates)
        @test collect(observed.geo)[1:fixture.ntime] == fill(first(fixture.panel_names), fixture.ntime)
        @test "mae" in predictive_summary.metric
        @test "panels" in predictive_summary.metric
        @test length(posterior_predictive_summary.mean) == fixture.nobs
        @test :draw_sd in propertynames(posterior_predictive_summary)

        posterior_predictive = Epsilon._load_pipeline_serialized(
            posterior_predictive_path;
            expected_kind = "PosteriorPredictiveChain",
        )
        @test length(names(posterior_predictive, :parameters)) == fixture.nobs

        contributions = Epsilon._load_pipeline_serialized(
            contribution_results_path;
            expected_kind = "ContributionResults",
        )
        decomposition = Epsilon._load_pipeline_serialized(
            decomposition_results_path;
            expected_kind = "DecompositionResults",
        )
        @test contributions isa ContributionResults
        @test ndims(contributions.values) == 4
        @test size(contributions.values, 2) == fixture.ntime
        @test size(contributions.values, 3) == fixture.npanels
        @test decomposition isa DecompositionResults
        @test "intercept" in decomposition.component_names
        @test any(startswith(name, "media:") for name in contributions.component_names)

        contribution_summary = CSV.File(contribution_summary_path)
        decomposition_summary = CSV.File(decomposition_summary_path)
        baseline_contributions = CSV.File(baseline_contributions_path)
        channel_contributions = CSV.File(channel_contributions_path)
        mean_contributions = CSV.File(mean_contributions_path)
        @test :panel_cell in propertynames(contribution_summary)
        @test :geo in propertynames(contribution_summary)
        @test :component in propertynames(contribution_summary)
        @test :mean in propertynames(contribution_summary)
        @test length(contribution_summary.mean) == fixture.ntime * fixture.npanels * length(contributions.component_names)
        @test length(mean_contributions.mean) == length(contribution_summary.mean)
        @test all(startswith.(String.(channel_contributions.component), "media:"))
        @test all(!startswith(String(component), "media:") for component in baseline_contributions.component)
        @test Set(decomposition_summary.component) == Set(decomposition.component_names)
        @test isfile(waterfall_plot_path)
        @test isfile(weekly_media_plot_path)

        model_diagnostics = Epsilon._load_pipeline_serialized(
            model_diagnostics_path;
            expected_kind = "ModelDiagnostics",
        )
        sampler_diagnostics = Epsilon._load_pipeline_serialized(
            sampler_diagnostics_path;
            expected_kind = "SamplerDiagnostics",
        )
        @test model_diagnostics isa ModelDiagnostics
        @test sampler_diagnostics isa SamplerDiagnostics
        design_report = JSON3.read(read(design_report_path, String))
        @test design_report["model_type"] == "PanelMMM"
        @test design_report["n_time"] == fixture.ntime
        @test design_report["n_panels"] == fixture.npanels
        @test String.(design_report["panel_dims"]) == fixture.panel_dims
        diagnostics_design_summary = CSV.File(design_summary_path)
        @test "panel" in collect(diagnostics_design_summary.feature_group)
        @test Set(fixture.channel_columns) ⊆ Set(String.(diagnostics_design_summary.feature))
        @test isfile(diagnostics_report_path)
        @test occursin("Epsilon.jl diagnostics summary", read(diagnostics_summary_path, String))
        @test JSON3.read(read(mcmc_report_path, String))["sampler"]["numerical_error_count"] >= 0
        @test :metric in propertynames(CSV.File(mcmc_summary_path))
        diagnostics_predictive_report = JSON3.read(read(diagnostics_predictive_report_path, String))
        @test diagnostics_predictive_report["available"] == true
        @test diagnostics_predictive_report["n_panels"] == fixture.npanels
        diagnostics_predictive_summary = CSV.File(diagnostics_predictive_summary_path)
        @test Set(["draws", "observations", "panels", "mae", "rmse", "bias"]) ⊆
            Set(String.(diagnostics_predictive_summary.metric))
        residual_diagnostics = CSV.File(residual_diagnostics_path)
        @test "panel_mean_abs_residual" in String.(residual_diagnostics.metric)
        @test isfile(residuals_acf_path)
        vif_report = CSV.File(vif_report_path)
        @test Set(fixture.channel_columns) == Set(String.(vif_report.feature))

        response_curve = Epsilon._load_pipeline_serialized(
            response_curve_results_path;
            expected_kind = "ResponseCurveResults",
        )
        saturation_curve = Epsilon._load_pipeline_serialized(
            saturation_curve_results_path;
            expected_kind = "SaturationCurveResults",
        )
        adstock_curve = Epsilon._load_pipeline_serialized(
            adstock_curve_results_path;
            expected_kind = "AdstockCurveResults",
        )
        @test response_curve isa ResponseCurveResults
        @test saturation_curve isa SaturationCurveResults
        @test adstock_curve isa AdstockCurveResults
        @test size(response_curve.values) == (6, fixture.npanels, 8)
        @test response_curve.spend_share_grid == collect(range(0.0, stop = 2.0, length = 8))
        @test size(response_curve.spend_grid) == (fixture.npanels, 8)
        @test isfile(response_curve_bundle_path)
        @test isfile(saturation_curve_bundle_path)
        @test isfile(adstock_curve_bundle_path)
        @test isfile(metric_results_path)
        curve_summary = CSV.File(curve_summary_path)
        metric_summary = CSV.File(metric_summary_path)
        response_summary = CSV.File(response_curve_summary_path)
        saturation_summary = CSV.File(saturation_curve_summary_path)
        adstock_summary = CSV.File(adstock_curve_summary_path)
        @test :panel_cell in propertynames(response_summary)
        @test :geo in propertynames(response_summary)
        @test :delta in propertynames(response_summary)
        @test :spend in propertynames(response_summary)
        @test :curve_family in propertynames(curve_summary)
        @test Set(String.(curve_summary.curve_family)) == Set(["response", "saturation", "adstock"])
        @test length(response_summary.mean) == fixture.npanels * 8 * length(fixture.channel_columns)
        @test length(saturation_summary.mean) == length(response_summary.mean)
        @test length(adstock_summary.mean) == length(response_summary.mean)
        @test Set(["roas", "mroas", "cpa", "mcpa"]) ⊆ Set(String.(metric_summary.metric))
        @test isfile(response_curve_bundle_plot_path)
        @test isfile(saturation_curve_bundle_plot_path)
        @test isfile(adstock_curve_bundle_plot_path)
    end
end

@testset "run_pipeline executes geo_panel Stage 70 historical-share optimization" begin
    fixture = ABACUS_GEO_PANEL_CONFIG_DATA
    source_config = joinpath(@__DIR__, "..", "fixtures", "abacus", "geo_panel", "config.yml")

    mktempdir() do tmpdir
        config_path = _abacus_panel_pipeline_config(source_config, joinpath(tmpdir, "geo_panel_optimization.yml"))
        config = YAML.load_file(config_path)
        optimized_channel = first(fixture.channel_columns)
        channel_index = findfirst(==(optimized_channel), fixture.channel_columns)
        total_budget = sum(fixture.raw_channels[:, channel_index, :])
        config["optimization"] = Dict(
            "enabled" => true,
            "total_budget" => total_budget,
            "channels" => [optimized_channel],
            "panel_allocation_mode" => "historical_shares",
        )
        YAML.write_file(config_path, config)

        result = run_pipeline(
            PipelineRunConfig(
                config_path = config_path,
                output_dir = joinpath(tmpdir, "results"),
                run_name = "geo_panel_pipeline_optimization",
                prior_samples = 4,
                curve_points = 5,
                draws = 4,
                tune = 4,
                chains = 1,
                cores = 1,
                random_seed = 41,
            ),
        )

        @test result.status == :completed
        optimisation_record = _stage_record(result, "optimisation")
        @test optimisation_record.status == :completed

        abacus_contract = fixture.pipeline_contract
        @test Set(abacus_contract.manifest_stage_artifact_keys["optimisation"]) ⊆
            Set(keys(optimisation_record.artifact_paths))
        @test Set(
            [
                "panel_coordinates",
                "channel_panel_allocation",
                "panel_response_summary",
                "channel_delta_audit",
            ],
        ) ⊆ Set(keys(optimisation_record.artifact_paths))
        for key in keys(optimisation_record.artifact_paths)
            @test isfile(joinpath(result.run_dir, optimisation_record.artifact_paths[key]))
        end

        optimization_result_path = joinpath(result.run_dir, "70_optimisation", "budget_optimization_result.jls")
        optimization_result = Epsilon._load_pipeline_serialized(
            optimization_result_path;
            expected_kind = "PanelBudgetOptimizationResult",
        )
        @test optimization_result isa PanelBudgetOptimizationResult
        @test optimization_result.panel_allocation_mode == :historical_shares
        @test optimization_result.optimized_channels == [optimized_channel]
        @test optimization_result.solver_status in _PIPELINE_SUCCESS_SOLVER_STATUSES
        @test optimization_result.constraint_audit.total_budget ≈ total_budget

        channel_panel_allocation = CSV.File(
            joinpath(result.run_dir, "70_optimisation", "channel_panel_allocation.csv"),
        )
        channel_delta_audit = CSV.File(joinpath(result.run_dir, "70_optimisation", "channel_delta_audit.csv"))
        @test :panel_cell in propertynames(channel_panel_allocation)
        optimized_rows = filter(row -> row.channel == optimized_channel, collect(channel_panel_allocation))
        @test length(optimized_rows) == fixture.npanels
        @test sum(row.optimized_spend for row in optimized_rows) ≈
            optimization_result.optimized_spend[optimized_channel]
        @test only(filter(row -> row.channel == optimized_channel, collect(channel_delta_audit))).panel_allocation_mode ==
            "historical_shares"
    end
end

@testset "run_pipeline executes geo_brand_panel Stage 00/20/30/40/50/60 panel parity" begin
    fixture = ABACUS_GEO_BRAND_PANEL_CONFIG_DATA
    source_config = joinpath(@__DIR__, "..", "fixtures", "abacus", "geo_brand_panel", "config.yml")

    mktempdir() do tmpdir
        config_path = _abacus_panel_pipeline_config(source_config, joinpath(tmpdir, "geo_brand_panel.yml"))
        result = run_pipeline(
            PipelineRunConfig(
                config_path = config_path,
                output_dir = joinpath(tmpdir, "results"),
                run_name = "geo_brand_panel_pipeline_curves",
                prior_samples = 6,
                curve_points = 8,
                draws = 6,
                tune = 6,
                chains = 1,
                cores = 1,
                random_seed = 37,
            ),
        )

        @test result.status == :completed
        @test !isempty(result.warnings)

        metadata_record = _stage_record(result, "metadata")
        fit_record = _stage_record(result, "fit")
        assessment_record = _stage_record(result, "assessment")
        decomposition_record = _stage_record(result, "decomposition")
        diagnostics_record = _stage_record(result, "diagnostics")
        curves_record = _stage_record(result, "curves")
        @test metadata_record.status == :completed
        @test fit_record.status == :completed
        @test assessment_record.status == :completed
        @test decomposition_record.status == :completed
        @test diagnostics_record.status == :completed
        @test curves_record.status == :completed
        for record in result.stage_records
            @test record.directory == fixture.stage_directories[record.key]
            record.key in ("metadata", "fit", "assessment", "decomposition", "diagnostics", "curves") && continue
            if record.key == "prior_sensitivity"
                @test record.status == :skipped
                @test isempty(record.warnings)
                continue
            end
            @test record.status == :skipped
            @test any(contains("metadata, prior sensitivity when explicitly enabled, fit"), record.warnings)
        end

        manifest = JSON3.read(read(result.manifest_path, String))
        abacus_contract = fixture.pipeline_contract
        @test manifest["status"] == "completed"
        @test manifest["model_type"] == "PanelMMM"
        @test manifest["data"]["n_rows"] == fixture.nobs
        @test manifest["data"]["n_time"] == fixture.ntime
        @test manifest["data"]["n_panels"] == fixture.npanels
        @test String.(manifest["data"]["panel_dims"]) == fixture.panel_dims
        @test String.(manifest["data"]["panel_names"]) == fixture.panel_names
        @test Set(abacus_contract.manifest_stage_artifact_keys["metadata"]) ⊆
            Set(keys(metadata_record.artifact_paths))
        @test Set(abacus_contract.manifest_stage_artifact_keys["fit"]) ⊆
            Set(keys(fit_record.artifact_paths))
        @test Set(abacus_contract.manifest_stage_artifact_keys["assessment"]) ⊆
            Set(keys(assessment_record.artifact_paths))
        @test Set(abacus_contract.manifest_stage_artifact_keys["decomposition"]) ⊆
            Set(keys(decomposition_record.artifact_paths))
        @test Set(abacus_contract.manifest_stage_artifact_keys["diagnostics"]) ⊆
            Set(keys(diagnostics_record.artifact_paths))
        @test Set(abacus_contract.manifest_stage_artifact_keys["curves"]) ⊆
            Set(keys(curves_record.artifact_paths))
        for filename in abacus_contract.artifact_files["metadata"]
            @test isfile(joinpath(result.run_dir, "00_run_metadata", filename))
        end
        for key in abacus_contract.manifest_stage_artifact_keys["fit"]
            @test isfile(joinpath(result.run_dir, fit_record.artifact_paths[key]))
        end
        for key in abacus_contract.manifest_stage_artifact_keys["assessment"]
            @test isfile(joinpath(result.run_dir, assessment_record.artifact_paths[key]))
        end
        for key in abacus_contract.manifest_stage_artifact_keys["decomposition"]
            @test isfile(joinpath(result.run_dir, decomposition_record.artifact_paths[key]))
        end
        for key in abacus_contract.manifest_stage_artifact_keys["diagnostics"]
            @test isfile(joinpath(result.run_dir, diagnostics_record.artifact_paths[key]))
        end
        for key in abacus_contract.manifest_stage_artifact_keys["curves"]
            @test isfile(joinpath(result.run_dir, curves_record.artifact_paths[key]))
        end

        metadata_dir = joinpath(result.run_dir, "00_run_metadata")
        fit_dir = joinpath(result.run_dir, "20_model_fit")
        assessment_dir = joinpath(result.run_dir, "30_model_assessment")
        decomposition_dir = joinpath(result.run_dir, "40_decomposition")
        diagnostics_dir = joinpath(result.run_dir, "50_diagnostics")
        curves_dir = joinpath(result.run_dir, "60_response_curves")
        dataset_metadata = JSON3.read(read(joinpath(metadata_dir, "dataset_metadata.json"), String))
        @test dataset_metadata["date_min"] == first(fixture.dates)
        @test dataset_metadata["date_max"] == last(fixture.dates)
        @test dataset_metadata["n_rows"] == fixture.nobs
        @test dataset_metadata["n_time"] == fixture.ntime
        @test dataset_metadata["n_panels"] == fixture.npanels
        @test String.(dataset_metadata["panel_dims"]) == fixture.panel_dims
        @test String.(dataset_metadata["panel_names"]) == fixture.panel_names

        model_metadata = JSON3.read(read(joinpath(metadata_dir, "model_metadata.json"), String))
        @test model_metadata["model_type"] == "PanelMMM"
        @test model_metadata["backend"] == "turing"
        @test model_metadata["nobs"] == fixture.nobs
        @test model_metadata["n_time"] == fixture.ntime
        @test model_metadata["npanels"] == fixture.npanels
        @test String.(model_metadata["panel_dims"]) == fixture.panel_dims

        data_dictionary = CSV.File(joinpath(metadata_dir, "data_dictionary.csv"))
        @test collect(data_dictionary.column)[1:4] == ["date", "geo", "brand", "revenue"]
        @test collect(data_dictionary.role)[1:4] == ["date", "panel", "panel", "target"]
        @test count(==("media"), collect(data_dictionary.role)) == length(fixture.channel_columns)

        design_matrix_manifest = CSV.File(joinpath(metadata_dir, "design_matrix_manifest.csv"))
        @test Set(fixture.panel_dims) ⊆ Set(String.(design_matrix_manifest.feature))
        @test Set(fixture.channel_columns) ⊆ Set(String.(design_matrix_manifest.feature))
        @test all(==(fixture.nobs), design_matrix_manifest.n_rows)

        session_info = read(joinpath(metadata_dir, "session_info.txt"), String)
        @test occursin("model_type: PanelMMM", session_info)
        @test occursin("panel_dims: geo,brand", session_info)

        spec_summary = CSV.File(joinpath(metadata_dir, "spec_summary.csv"))
        @test only(spec_summary.model_kind) == "panel_mmm"
        @test only(spec_summary.nobs) == fixture.nobs
        @test only(spec_summary.nchannels) == length(fixture.channel_columns)

        model_artifact_path = joinpath(fit_dir, "model.jls")
        grouped_path = joinpath(fit_dir, "inference_results.jls")
        posterior_summary_path = joinpath(fit_dir, "posterior_summary.csv")
        trace_plot_path = joinpath(fit_dir, "trace.png")
        @test isfile(model_artifact_path)
        @test isfile(grouped_path)
        @test isfile(posterior_summary_path)
        @test isfile(trace_plot_path)
        loaded_model = load_model(model_artifact_path)
        @test loaded_model isa PanelMMM
        @test loaded_model.fit_state.status == :fit

        grouped = load_inference_results(grouped_path)
        @test grouped isa InferenceResults
        @test grouped.metadata.model_type == "PanelMMM"
        @test grouped.observed_data isa PanelMMMData
        @test grouped.observed_data.panel_names == fixture.panel_names
        @test grouped.observed_data.panel_coordinates == fixture.panel_coordinate_columns

        posterior_summary = CSV.File(posterior_summary_path)
        @test :parameter in propertynames(posterior_summary)
        @test :mean in propertynames(posterior_summary)
        @test :rhat in propertynames(posterior_summary)

        model_results_path = joinpath(assessment_dir, "model_results.jls")
        observed_path = joinpath(assessment_dir, "observed.csv")
        fitted_path = joinpath(assessment_dir, "fitted.csv")
        residuals_path = joinpath(assessment_dir, "residuals.csv")
        predictive_summary_path = joinpath(assessment_dir, "predictive_summary.csv")
        posterior_predictive_path = joinpath(assessment_dir, "posterior_predictive.jls")
        posterior_predictive_summary_path = joinpath(assessment_dir, "posterior_predictive_summary.csv")
        contribution_results_path = joinpath(decomposition_dir, "contribution_results.jls")
        decomposition_results_path = joinpath(decomposition_dir, "decomposition_results.jls")
        contribution_summary_path = joinpath(decomposition_dir, "contribution_summary.csv")
        decomposition_summary_path = joinpath(decomposition_dir, "decomposition_summary.csv")
        baseline_contributions_path = joinpath(decomposition_dir, "baseline_contributions.csv")
        channel_contributions_path = joinpath(decomposition_dir, "channel_contributions.csv")
        mean_contributions_path = joinpath(decomposition_dir, "mean_contributions_over_time.csv")
        waterfall_plot_path = joinpath(decomposition_dir, "waterfall_components_decomposition.png")
        weekly_media_plot_path = joinpath(decomposition_dir, "weekly_media_contribution.png")
        model_diagnostics_path = joinpath(diagnostics_dir, "model_diagnostics.jls")
        sampler_diagnostics_path = joinpath(diagnostics_dir, "sampler_diagnostics.jls")
        design_report_path = joinpath(diagnostics_dir, "design_report.json")
        design_summary_path = joinpath(diagnostics_dir, "design_summary.csv")
        diagnostics_report_path = joinpath(diagnostics_dir, "diagnostics_report.csv")
        diagnostics_summary_path = joinpath(diagnostics_dir, "diagnostics_summary.txt")
        mcmc_report_path = joinpath(diagnostics_dir, "mcmc_report.json")
        mcmc_summary_path = joinpath(diagnostics_dir, "mcmc_summary.csv")
        diagnostics_predictive_report_path = joinpath(diagnostics_dir, "predictive_report.json")
        diagnostics_predictive_summary_path = joinpath(diagnostics_dir, "predictive_summary.csv")
        residual_diagnostics_path = joinpath(diagnostics_dir, "residual_diagnostics.csv")
        residuals_acf_path = joinpath(diagnostics_dir, "residuals_acf.png")
        vif_report_path = joinpath(diagnostics_dir, "vif_report.csv")
        first_channel = first(fixture.channel_columns)
        response_curve_results_path = joinpath(curves_dir, "response_curve_$(first_channel).jls")
        saturation_curve_results_path = joinpath(curves_dir, "saturation_curve_$(first_channel).jls")
        adstock_curve_results_path = joinpath(curves_dir, "adstock_curve_$(first_channel).jls")
        response_curve_bundle_path = joinpath(curves_dir, "response_curve.jls")
        saturation_curve_bundle_path = joinpath(curves_dir, "saturation_curve.jls")
        adstock_curve_bundle_path = joinpath(curves_dir, "adstock_curve.jls")
        metric_results_path = joinpath(curves_dir, "metric_results.jls")
        curve_summary_path = joinpath(curves_dir, "curve_summary.csv")
        metric_summary_path = joinpath(curves_dir, "metric_summary.csv")
        response_curve_summary_path = joinpath(curves_dir, "forward_pass_contribution_curve_summary.csv")
        saturation_curve_summary_path = joinpath(curves_dir, "saturation_curve_summary.csv")
        adstock_curve_summary_path = joinpath(curves_dir, "adstock_curve_summary.csv")
        response_curve_bundle_plot_path = joinpath(curves_dir, "forward_pass_contribution_curve.png")
        saturation_curve_bundle_plot_path = joinpath(curves_dir, "saturation_curve.png")
        adstock_curve_bundle_plot_path = joinpath(curves_dir, "adstock_curve.png")

        loaded_results = load_results(model_results_path)
        @test loaded_results isa ModelResults
        @test !isnothing(loaded_results.posterior_predictive)

        observed = CSV.File(observed_path)
        fitted = CSV.File(fitted_path)
        residuals = CSV.File(residuals_path)
        predictive_summary = CSV.File(predictive_summary_path)
        posterior_predictive_summary = CSV.File(posterior_predictive_summary_path)
        @test length(observed.observed) == fixture.nobs
        @test length(fitted.mean) == fixture.nobs
        @test length(residuals.residual) == fixture.nobs
        @test collect(observed.date)[1:fixture.ntime] == Date.(fixture.dates)
        @test collect(observed.panel)[1:fixture.ntime] == fill(first(fixture.panel_names), fixture.ntime)
        @test collect(observed.geo)[1:fixture.ntime] == fill(first(fixture.panel_coordinate_columns["geo"]), fixture.ntime)
        @test collect(observed.brand)[1:fixture.ntime] == fill(first(fixture.panel_coordinate_columns["brand"]), fixture.ntime)
        @test "mae" in predictive_summary.metric
        @test "panels" in predictive_summary.metric
        @test length(posterior_predictive_summary.mean) == fixture.nobs
        @test :draw_sd in propertynames(posterior_predictive_summary)

        posterior_predictive = Epsilon._load_pipeline_serialized(
            posterior_predictive_path;
            expected_kind = "PosteriorPredictiveChain",
        )
        @test length(names(posterior_predictive, :parameters)) == fixture.nobs

        contributions = Epsilon._load_pipeline_serialized(
            contribution_results_path;
            expected_kind = "ContributionResults",
        )
        decomposition = Epsilon._load_pipeline_serialized(
            decomposition_results_path;
            expected_kind = "DecompositionResults",
        )
        @test contributions isa ContributionResults
        @test ndims(contributions.values) == 4
        @test size(contributions.values, 2) == fixture.ntime
        @test size(contributions.values, 3) == fixture.npanels
        @test decomposition isa DecompositionResults
        @test "intercept" in decomposition.component_names
        @test any(startswith(name, "media:") for name in contributions.component_names)

        contribution_summary = CSV.File(contribution_summary_path)
        decomposition_summary = CSV.File(decomposition_summary_path)
        baseline_contributions = CSV.File(baseline_contributions_path)
        channel_contributions = CSV.File(channel_contributions_path)
        mean_contributions = CSV.File(mean_contributions_path)
        @test :panel_cell in propertynames(contribution_summary)
        @test :panel in propertynames(contribution_summary)
        @test :geo in propertynames(contribution_summary)
        @test :brand in propertynames(contribution_summary)
        @test :component in propertynames(contribution_summary)
        @test :mean in propertynames(contribution_summary)
        @test length(contribution_summary.mean) == fixture.ntime * fixture.npanels * length(contributions.component_names)
        @test length(mean_contributions.mean) == length(contribution_summary.mean)
        @test all(startswith.(String.(channel_contributions.component), "media:"))
        @test all(!startswith(String(component), "media:") for component in baseline_contributions.component)
        @test Set(decomposition_summary.component) == Set(decomposition.component_names)
        @test isfile(waterfall_plot_path)
        @test isfile(weekly_media_plot_path)

        model_diagnostics = Epsilon._load_pipeline_serialized(
            model_diagnostics_path;
            expected_kind = "ModelDiagnostics",
        )
        sampler_diagnostics = Epsilon._load_pipeline_serialized(
            sampler_diagnostics_path;
            expected_kind = "SamplerDiagnostics",
        )
        @test model_diagnostics isa ModelDiagnostics
        @test sampler_diagnostics isa SamplerDiagnostics
        design_report = JSON3.read(read(design_report_path, String))
        @test design_report["model_type"] == "PanelMMM"
        @test design_report["n_time"] == fixture.ntime
        @test design_report["n_panels"] == fixture.npanels
        @test String.(design_report["panel_dims"]) == fixture.panel_dims
        diagnostics_design_summary = CSV.File(design_summary_path)
        @test Set(fixture.panel_dims) ⊆ Set(String.(diagnostics_design_summary.feature))
        @test Set(fixture.channel_columns) ⊆ Set(String.(diagnostics_design_summary.feature))
        @test isfile(diagnostics_report_path)
        @test occursin("Epsilon.jl diagnostics summary", read(diagnostics_summary_path, String))
        @test JSON3.read(read(mcmc_report_path, String))["sampler"]["numerical_error_count"] >= 0
        @test :metric in propertynames(CSV.File(mcmc_summary_path))
        diagnostics_predictive_report = JSON3.read(read(diagnostics_predictive_report_path, String))
        @test diagnostics_predictive_report["available"] == true
        @test diagnostics_predictive_report["n_panels"] == fixture.npanels
        diagnostics_predictive_summary = CSV.File(diagnostics_predictive_summary_path)
        @test Set(["draws", "observations", "panels", "mae", "rmse", "bias"]) ⊆
            Set(String.(diagnostics_predictive_summary.metric))
        residual_diagnostics = CSV.File(residual_diagnostics_path)
        @test "panel_mean_abs_residual" in String.(residual_diagnostics.metric)
        @test isfile(residuals_acf_path)
        vif_report = CSV.File(vif_report_path)
        @test Set(fixture.channel_columns) == Set(String.(vif_report.feature))

        response_curve = Epsilon._load_pipeline_serialized(
            response_curve_results_path;
            expected_kind = "ResponseCurveResults",
        )
        saturation_curve = Epsilon._load_pipeline_serialized(
            saturation_curve_results_path;
            expected_kind = "SaturationCurveResults",
        )
        adstock_curve = Epsilon._load_pipeline_serialized(
            adstock_curve_results_path;
            expected_kind = "AdstockCurveResults",
        )
        @test response_curve isa ResponseCurveResults
        @test saturation_curve isa SaturationCurveResults
        @test adstock_curve isa AdstockCurveResults
        @test size(response_curve.values) == (6, fixture.npanels, 8)
        @test response_curve.spend_share_grid == collect(range(0.0, stop = 2.0, length = 8))
        @test size(response_curve.spend_grid) == (fixture.npanels, 8)
        @test isfile(response_curve_bundle_path)
        @test isfile(saturation_curve_bundle_path)
        @test isfile(adstock_curve_bundle_path)
        @test isfile(metric_results_path)
        curve_summary = CSV.File(curve_summary_path)
        metric_summary = CSV.File(metric_summary_path)
        response_summary = CSV.File(response_curve_summary_path)
        saturation_summary = CSV.File(saturation_curve_summary_path)
        adstock_summary = CSV.File(adstock_curve_summary_path)
        @test :panel_cell in propertynames(response_summary)
        @test :panel in propertynames(response_summary)
        @test :geo in propertynames(response_summary)
        @test :brand in propertynames(response_summary)
        @test :delta in propertynames(response_summary)
        @test :spend in propertynames(response_summary)
        @test :curve_family in propertynames(curve_summary)
        @test Set(String.(curve_summary.curve_family)) == Set(["response", "saturation", "adstock"])
        @test length(response_summary.mean) == fixture.npanels * 8 * length(fixture.channel_columns)
        @test length(saturation_summary.mean) == length(response_summary.mean)
        @test length(adstock_summary.mean) == length(response_summary.mean)
        @test Set(["roas", "mroas", "cpa", "mcpa"]) ⊆ Set(String.(metric_summary.metric))
        @test isfile(response_curve_bundle_plot_path)
        @test isfile(saturation_curve_bundle_plot_path)
        @test isfile(adstock_curve_bundle_plot_path)
    end
end

@testset "run_pipeline executes geo_brand_panel Stage 70 historical-share optimization" begin
    fixture = ABACUS_GEO_BRAND_PANEL_CONFIG_DATA
    source_config = joinpath(@__DIR__, "..", "fixtures", "abacus", "geo_brand_panel", "config.yml")

    mktempdir() do tmpdir
        config_path = _abacus_panel_pipeline_config(
            source_config,
            joinpath(tmpdir, "geo_brand_panel_optimization.yml"),
        )
        config = YAML.load_file(config_path)
        optimized_channel = first(fixture.channel_columns)
        channel_index = findfirst(==(optimized_channel), fixture.channel_columns)
        total_budget = sum(fixture.raw_channels[:, channel_index, :])
        config["optimization"] = Dict(
            "enabled" => true,
            "total_budget" => total_budget,
            "channels" => [optimized_channel],
            "panel_allocation_mode" => "historical_shares",
        )
        YAML.write_file(config_path, config)

        result = run_pipeline(
            PipelineRunConfig(
                config_path = config_path,
                output_dir = joinpath(tmpdir, "results"),
                run_name = "geo_brand_panel_pipeline_optimization",
                prior_samples = 4,
                curve_points = 5,
                draws = 4,
                tune = 4,
                chains = 1,
                cores = 1,
                random_seed = 43,
            ),
        )

        @test result.status == :completed
        optimisation_record = _stage_record(result, "optimisation")
        @test optimisation_record.status == :completed

        abacus_contract = fixture.pipeline_contract
        @test Set(abacus_contract.manifest_stage_artifact_keys["optimisation"]) ⊆
            Set(keys(optimisation_record.artifact_paths))
        @test Set(
            [
                "panel_coordinates",
                "channel_panel_allocation",
                "panel_response_summary",
                "channel_delta_audit",
            ],
        ) ⊆ Set(keys(optimisation_record.artifact_paths))
        for key in keys(optimisation_record.artifact_paths)
            @test isfile(joinpath(result.run_dir, optimisation_record.artifact_paths[key]))
        end

        optimization_result_path = joinpath(result.run_dir, "70_optimisation", "budget_optimization_result.jls")
        optimization_result = Epsilon._load_pipeline_serialized(
            optimization_result_path;
            expected_kind = "PanelBudgetOptimizationResult",
        )
        @test optimization_result isa PanelBudgetOptimizationResult
        @test optimization_result.panel_allocation_mode == :historical_shares
        @test optimization_result.optimized_channels == [optimized_channel]
        @test optimization_result.solver_status in _PIPELINE_SUCCESS_SOLVER_STATUSES
        @test optimization_result.constraint_audit.total_budget ≈ total_budget
        @test optimization_result.panel_names == fixture.panel_names

        channel_panel_allocation = CSV.File(
            joinpath(result.run_dir, "70_optimisation", "channel_panel_allocation.csv"),
        )
        channel_delta_audit = CSV.File(joinpath(result.run_dir, "70_optimisation", "channel_delta_audit.csv"))
        @test :panel_cell in propertynames(channel_panel_allocation)
        @test :geo in propertynames(channel_panel_allocation)
        @test :brand in propertynames(channel_panel_allocation)
        @test Set(String.(getproperty(channel_panel_allocation, :geo))) ⊇
            Set(fixture.panel_coordinates["geo"])
        @test Set(String.(getproperty(channel_panel_allocation, :brand))) ⊇
            Set(fixture.panel_coordinates["brand"])

        optimized_rows = filter(row -> row.channel == optimized_channel, collect(channel_panel_allocation))
        @test length(optimized_rows) == fixture.npanels
        @test sum(row.optimized_spend for row in optimized_rows) ≈
            optimization_result.optimized_spend[optimized_channel]
        @test only(filter(row -> row.channel == optimized_channel, collect(channel_delta_audit))).panel_allocation_mode ==
            "historical_shares"
    end
end

@testset "run_pipeline executes Stage 70 optimization and skips disabled validation honestly" begin
    fixture = joinpath(@__DIR__, "..", "fixtures", "pipeline_config.yml")
    dataset_fixture = joinpath(@__DIR__, "..", "fixtures", "pipeline_dataset.csv")

    mktempdir() do tmpdir
        config_dict = YAML.load_file(fixture)
        config_dict["validation"] = Dict("enabled" => false)
        config_dict["optimization"] = Dict(
            "enabled" => true,
            "total_budget" => 31.5,
        )

        config_path = joinpath(tmpdir, "pipeline_with_optimization.yml")
        YAML.write_file(config_path, config_dict)

        result = run_pipeline(
            PipelineRunConfig(
                config_path = config_path,
                output_dir = joinpath(tmpdir, "results"),
                run_name = "demo_optimization",
                dataset_path = dataset_fixture,
                prior_samples = 8,
                curve_points = 10,
                draws = 8,
                tune = 8,
                chains = 1,
                cores = 1,
                random_seed = 11,
            ),
        )

        @test result.status == :completed
        @test _stage_record(result, "validation").status == :skipped
        @test _stage_record(result, "optimisation").status == :completed

        manifest = JSON3.read(read(result.manifest_path, String))
        @test manifest["stages"]["validation"]["status"] == "skipped"
        @test manifest["stages"]["optimisation"]["status"] == "completed"
        abacus_contract = ABACUS_TIMESERIES_CONFIG_DATA.pipeline_contract
        optimisation_record = _stage_record(result, "optimisation")
        @test Set(abacus_contract.manifest_stage_artifact_keys["optimisation"]) ⊆
            Set(keys(optimisation_record.artifact_paths))

        optimization_result_path = joinpath(result.run_dir, "70_optimisation", "budget_optimization_result.jls")
        impact_path = joinpath(result.run_dir, "70_optimisation", "budget_impact.csv")
        audit_path = joinpath(result.run_dir, "70_optimisation", "budget_bounds_audit.csv")
        optimization_plot_path = joinpath(result.run_dir, "70_optimisation", "budget_optimization.png")
        budget_optimisation_path = joinpath(result.run_dir, "70_optimisation", "budget_optimisation.json")
        optimize_result_path = joinpath(result.run_dir, "70_optimisation", "optimize_result.json")
        optimized_allocation_path = joinpath(result.run_dir, "70_optimisation", "optimized_allocation.jls")
        optimized_allocation_csv_path = joinpath(result.run_dir, "70_optimisation", "optimized_allocation.csv")
        response_distribution_path = joinpath(result.run_dir, "70_optimisation", "response_distribution.jls")

        @test isfile(optimization_result_path)
        @test isfile(impact_path)
        @test isfile(audit_path)
        @test isfile(optimization_plot_path)
        @test isfile(budget_optimisation_path)
        @test isfile(optimize_result_path)
        @test isfile(optimized_allocation_path)
        @test isfile(optimized_allocation_csv_path)
        @test isfile(response_distribution_path)
        for key in abacus_contract.manifest_stage_artifact_keys["optimisation"]
            @test isfile(joinpath(result.run_dir, optimisation_record.artifact_paths[key]))
        end

        optimization_result = Epsilon._load_pipeline_serialized(
            optimization_result_path;
            expected_kind = "BudgetOptimizationResult",
        )
        @test optimization_result isa BudgetOptimizationResult
        @test optimization_result.solver_status in _PIPELINE_SUCCESS_SOLVER_STATUSES
        @test optimization_result.constraint_audit.total_budget ≈ 31.5

        impact = CSV.File(impact_path)
        audit = CSV.File(audit_path)
        optimized_allocation = CSV.File(optimized_allocation_csv_path)
        @test Set(impact.channel) == Set(["tv", "search"])
        @test Set(audit.channel) == Set(["tv", "search"])
        @test Set(optimized_allocation.channel) == Set(["tv", "search"])
        @test all(audit.optimized_within_bounds)
    end
end

@testset "run_pipeline rejects duplicate combined CSV header names" begin
    fixture = joinpath(@__DIR__, "..", "fixtures", "pipeline_config.yml")
    dataset_fixture = joinpath(@__DIR__, "..", "fixtures", "pipeline_dataset.csv")

    mktempdir() do tmpdir
        duplicate_dataset_path = _duplicate_header_dataset(
            dataset_fixture,
            joinpath(tmpdir, "duplicate_headers.csv"),
        )

        @test_throws ArgumentError run_pipeline(
            PipelineRunConfig(
                config_path = fixture,
                output_dir = joinpath(tmpdir, "results"),
                run_name = "duplicate_headers",
                dataset_path = duplicate_dataset_path,
                prior_samples = 6,
                curve_points = 8,
                draws = 6,
                tune = 6,
                chains = 1,
                cores = 1,
                random_seed = 29,
            ),
        )

        run_dir = only(readdir(joinpath(tmpdir, "results"); join = true))
        manifest = JSON3.read(read(joinpath(run_dir, "run_manifest.json"), String))
        @test manifest["status"] == "failed"
        @test manifest["stages"]["metadata"]["status"] == "failed"
        @test occursin("duplicate header names", String(manifest["error"]["message"]))
    end
end
