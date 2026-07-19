#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
julia_bin="${JULIA:-julia}"
draws="${DRAWS:-8}"
tune="${TUNE:-8}"
prior_samples="${PRIOR_SAMPLES:-3}"
curve_points="${CURVE_POINTS:-8}"
seed="${SEED:-20260719}"
tmp_root="$(mktemp -d)"

cleanup() {
    if [[ "${KEEP_SMOKE_OUTPUTS:-0}" == "1" ]]; then
        echo "Keeping demo-config smoke outputs at $tmp_root"
    else
        rm -rf "$tmp_root"
    fi
}
trap cleanup EXIT

echo "Running Epsilon demo-config smoke in $tmp_root"

"$julia_bin" --project="$repo_root" --startup-file=no - \
    "$repo_root" "$tmp_root" "$draws" "$tune" "$prior_samples" "$curve_points" "$seed" <<'JULIA'
using Epsilon

repo_root, tmp_root = ARGS[1], ARGS[2]
draws = parse(Int, ARGS[3])
tune = parse(Int, ARGS[4])
prior_samples = parse(Int, ARGS[5])
curve_points = parse(Int, ARGS[6])
seed = parse(Int, ARGS[7])

function _assert(condition::Bool, message::AbstractString)
    condition || error(message)
    return nothing
end

function _stage_record(result::PipelineRunResult, key::AbstractString)
    index = findfirst(record -> record.key == key, result.stage_records)
    isnothing(index) && error("missing pipeline stage record: $key")
    return result.stage_records[index]
end

function _assert_nonempty(path::AbstractString)
    _assert(isfile(path), "missing smoke artifact: $path")
    _assert(filesize(path) > 0, "empty smoke artifact: $path")
    return nothing
end

function _assert_stage_artifacts(result::PipelineRunResult, key::AbstractString, required_keys)
    stage = _stage_record(result, key)
    _assert(stage.status == :completed, "stage $key did not complete; got $(stage.status)")
    for artifact_key in required_keys
        _assert(
            haskey(stage.artifact_paths, artifact_key),
            "stage $key missing artifact key $artifact_key",
        )
        _assert_nonempty(joinpath(result.run_dir, stage.artifact_paths[artifact_key]))
    end
    return stage
end

function _assert_plot_paths_backed(result::PipelineRunResult)
    saw_headless_warning = false
    for stage in result.stage_records
        saw_headless_warning |= any(contains(warning, "optional plotting support") for warning in stage.warnings)
        for (artifact_key, relative_path) in stage.artifact_paths
            if endswith(relative_path, ".png")
                _assert(
                    isfile(joinpath(result.run_dir, relative_path)),
                    "manifest advertises missing PNG artifact $artifact_key => $relative_path",
                )
            end
        end
    end
    _assert(
        Base.get_extension(Epsilon, :EpsilonCairoMakieExt) === nothing,
        "demo-config smoke unexpectedly loaded CairoMakie plotting extension",
    )
    _assert(
        saw_headless_warning,
        "headless demo-config smoke did not record omitted-plot warnings",
    )
    return nothing
end

function _run_timeseries_smoke()
    config_path = joinpath(repo_root, "data", "demo", "timeseries", "config.yml")
    result = run_pipeline(
        PipelineRunConfig(
            config_path = config_path,
            output_dir = joinpath(tmp_root, "timeseries"),
            run_name = "demo-timeseries-smoke",
            draws = draws,
            tune = tune,
            chains = 1,
            cores = 1,
            random_seed = seed,
            prior_samples = prior_samples,
            curve_points = curve_points,
        ),
    )

    _assert(result.status == :completed, "time-series demo pipeline did not complete")
    _assert_nonempty(result.manifest_path)
    _assert_stage_artifacts(
        result,
        "metadata",
        (
            "config_copy",
            "config_original",
            "config_resolved",
            "config_model",
            "dataset_metadata",
            "model_metadata",
            "spec_summary",
        ),
    )
    _assert_stage_artifacts(result, "preflight", ("prior_predictive", "prior_predictive_summary"))
    _assert_stage_artifacts(result, "fit", ("model", "inference_results", "posterior_summary"))
    _assert_stage_artifacts(
        result,
        "assessment",
        ("model_results", "observed", "fitted", "residuals", "predictive_summary"),
    )
    _assert_stage_artifacts(
        result,
        "validation",
        (
            "validation_metadata",
            "validation_results",
            "holdout_observed",
            "holdout_fitted",
            "holdout_residuals",
            "holdout_summary",
        ),
    )
    _assert_stage_artifacts(
        result,
        "decomposition",
        ("contribution_results", "decomposition_results", "contribution_summary"),
    )
    _assert_stage_artifacts(
        result,
        "diagnostics",
        ("convergence_report", "warnings_summary", "model_diagnostics", "sampler_diagnostics"),
    )
    _assert_stage_artifacts(
        result,
        "curves",
        ("forward_pass_contribution_curve", "metric_results", "metric_summary"),
    )
    _assert_plot_paths_backed(result)
    println("timeseries demo pipeline smoke verified: $(result.run_dir)")
    return nothing
end

function _verify_panel_config(label::AbstractString, expected_dims)
    config_path = joinpath(repo_root, "data", "demo", label, "config.yml")
    config = PipelineRunConfig(
        config_path = config_path,
        output_dir = joinpath(tmp_root, label),
        draws = 1,
        tune = 0,
        chains = 1,
        cores = 1,
        prior_samples = 2,
        curve_points = 4,
    )
    loaded = Epsilon._load_pipeline_configuration(config)
    context = Epsilon._pipeline_context(config, loaded)
    data = Epsilon._load_pipeline_panel_dataset(context)
    model = PanelMMM(loaded.model_config, loaded.sampler_config, data)
    spec = build_model(model)

    _assert(spec.dims == expected_dims, "$label dims mismatch: $(spec.dims)")
    _assert(spec.nchannels == 6, "$label expected six media channels")
    _assert(length(data.panel_names) == size(data.target, 2), "$label panel names mismatch")
    for dim in expected_dims
        _assert(
            haskey(data.panel_coordinates, dim),
            "$label missing panel coordinate metadata for $dim",
        )
    end
    println("$label panel config smoke verified: nobs=$(spec.nobs), dims=$(spec.dims)")
    return nothing
end

_run_timeseries_smoke()
_verify_panel_config("geo_panel", ("geo",))
_verify_panel_config("geo_brand_panel", ("geo", "brand"))
println("Demo-config smoke certification passed")
JULIA
