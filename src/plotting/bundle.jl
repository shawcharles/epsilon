"""
    write_plot_bundle(run::PipelineRunResult; output_dir=nothing) -> String

Write the bounded static plot bundle for a successful pipeline run.

The bundle is a deterministic `png`-only export helper over the run schema. The
pipeline itself already writes stage-local plot artifacts into the relevant
stage directories; `write_plot_bundle` is the optional post-hoc curated export
that reads typed artifacts from the run directory, writes a separate plot
directory, and never mutates pipeline stage artifacts or the run manifest.
"""
function write_plot_bundle(run::PipelineRunResult; output_dir = nothing)
    _require_completed_plot_bundle_run(run)
    bundle_dir = _prepare_plot_bundle_directory(run, output_dir)

    diagnostics_dir = joinpath(bundle_dir, "diagnostics")
    postmodel_dir = joinpath(bundle_dir, "postmodel")

    grouped = _bundle_grouped_results(run)
    diagnostics_paths = _write_diagnostic_plot_bundle!(grouped, diagnostics_dir)
    postmodel_paths = _write_postmodel_plot_bundle!(run, grouped, postmodel_dir)
    optimization_paths = _write_optimization_plot_bundle!(run, bundle_dir)

    isempty(diagnostics_paths) &&
        throw(ErrorException("write_plot_bundle did not emit any diagnostic plots"))
    isempty(postmodel_paths) &&
        throw(ErrorException("write_plot_bundle did not emit any post-model plots"))
    for path in vcat(diagnostics_paths, postmodel_paths, optimization_paths)
        isfile(path) && filesize(path) > 0 ||
            throw(ErrorException("write_plot_bundle failed to write plot artifact: $path"))
    end

    return bundle_dir
end

function _require_completed_plot_bundle_run(run::PipelineRunResult)
    run.status == :completed ||
        throw(
        ArgumentError(
            "write_plot_bundle requires a successful PipelineRunResult with status `:completed`",
        ),
    )
    return run
end

function _prepare_plot_bundle_directory(run::PipelineRunResult, output_dir)
    bundle_dir = isnothing(output_dir) ? "$(run.run_dir)_plots" : abspath(String(output_dir))
    mkpath(bundle_dir)
    for name in ("diagnostics", "postmodel", "optimization")
        rm(joinpath(bundle_dir, name); recursive = true, force = true)
    end
    return bundle_dir
end

function _bundle_grouped_results(run::PipelineRunResult)
    model_path = _bundle_stage_artifact_path(run, "fit", "model")
    model = load_model(model_path)
    return inference_results(
        model;
        include_prior = true,
        include_posterior_predictive = true,
        include_prior_predictive = false,
    )
end

function _write_diagnostic_plot_bundle!(grouped::InferenceResults, output_dir::AbstractString)
    mkpath(output_dir)
    posterior = _require_plot_posterior(grouped, "write_plot_bundle")
    selected = _select_plot_parameters(
        posterior;
        parameters = nothing,
        max_parameters = 8,
        action = "write_plot_bundle",
    )

    written = String[]
    push!(
        written,
        _save_bundle_figure(joinpath(output_dir, "trace.png"), trace_plot(grouped; parameters = selected)),
    )
    push!(
        written,
        _save_bundle_figure(
            joinpath(output_dir, "posterior_density.png"),
            posterior_density_plot(grouped; parameters = selected),
        ),
    )
    push!(
        written,
        _save_bundle_figure(joinpath(output_dir, "observed_fitted.png"), observed_fitted_plot(grouped)),
    )
    push!(
        written,
        _save_bundle_figure(
            joinpath(output_dir, "residual_diagnostics.png"),
            residual_diagnostics_plot(grouped),
        ),
    )

    prior_available = isnothing(grouped.prior) ? Set{Symbol}() :
        Set(Symbol.(names(grouped.prior, :parameters)))
    for parameter in selected
        parameter in prior_available || continue
        filename = "prior_posterior_$(_plot_parameter_slug(parameter)).png"
        push!(
            written,
            _save_bundle_figure(
                joinpath(output_dir, filename),
                prior_posterior_plot(grouped; parameter),
            ),
        )
    end

    return written
end

function _write_postmodel_plot_bundle!(
        run::PipelineRunResult,
        grouped::InferenceResults,
        output_dir::AbstractString,
    )
    mkpath(output_dir)
    contributions = _load_pipeline_serialized(
        _bundle_stage_artifact_path(run, "decomposition", "contribution_results");
        expected_kind = "ContributionResults",
    )
    decomposition = _load_pipeline_serialized(
        _bundle_stage_artifact_path(run, "decomposition", "decomposition_results");
        expected_kind = "DecompositionResults",
    )

    written = String[
        _save_bundle_figure(joinpath(output_dir, "contributions.png"), contribution_plot(contributions)),
        _save_bundle_figure(
            joinpath(output_dir, "contributions_area.png"),
            contribution_area_plot(contributions),
        ),
        _save_bundle_figure(joinpath(output_dir, "decomposition.png"), decomposition_plot(decomposition)),
    ]

    for channel in grouped.spec.channel_columns
        response = _load_pipeline_serialized(
            _bundle_stage_artifact_path(run, "curves", "response_curve_$(channel)");
            expected_kind = "ResponseCurveResults",
        )
        saturation = _load_pipeline_serialized(
            _bundle_stage_artifact_path(run, "curves", "saturation_curve_$(channel)");
            expected_kind = "SaturationCurveResults",
        )
        adstock = _load_pipeline_serialized(
            _bundle_stage_artifact_path(run, "curves", "adstock_curve_$(channel)");
            expected_kind = "AdstockCurveResults",
        )
        push!(
            written,
            _save_bundle_figure(
                joinpath(output_dir, "response_curve_$(channel).png"),
                response_curve_plot(response),
            ),
        )
        push!(
            written,
            _save_bundle_figure(
                joinpath(output_dir, "saturation_curve_$(channel).png"),
                saturation_curve_plot(saturation),
            ),
        )
        push!(
            written,
            _save_bundle_figure(
                joinpath(output_dir, "adstock_curve_$(channel).png"),
                adstock_curve_plot(adstock),
            ),
        )
    end

    return written
end

function _write_optimization_plot_bundle!(run::PipelineRunResult, bundle_dir::AbstractString)
    stage = _bundle_stage_record(run, "optimisation")
    stage.status == :skipped && return String[]
    stage.status == :completed ||
        throw(
        ArgumentError(
            "write_plot_bundle requires the optimisation stage to be completed or skipped; got `$(stage.status)`",
        ),
    )

    result = _load_pipeline_serialized(
        _bundle_stage_artifact_path(run, "optimisation", "budget_optimization_result"),
    )
    result isa _BudgetOptimizationResultLike ||
        throw(ArgumentError("write_plot_bundle requires a budget optimization result artifact"))
    output_dir = joinpath(bundle_dir, "optimization")
    mkpath(output_dir)
    return String[
        _save_bundle_figure(
            joinpath(output_dir, "budget_optimization.png"),
            budget_optimization_plot(result),
        ),
    ]
end

function _bundle_stage_record(run::PipelineRunResult, key::AbstractString)
    record = findfirst(stage -> stage.key == key, run.stage_records)
    isnothing(record) &&
        throw(ArgumentError("write_plot_bundle could not find pipeline stage `$key`"))
    return run.stage_records[record]
end

function _bundle_stage_artifact_path(
        run::PipelineRunResult,
        key::AbstractString,
        artifact_name::AbstractString,
    )
    stage = _bundle_stage_record(run, key)
    stage.status == :completed ||
        throw(
        ArgumentError(
            "write_plot_bundle requires stage `$key` to be completed before loading `$artifact_name`",
        ),
    )
    relative_path = get(stage.artifact_paths, String(artifact_name), nothing)
    isnothing(relative_path) &&
        throw(
        ErrorException(
            "write_plot_bundle requires stage `$key` artifact `$artifact_name` to be present in the run manifest",
        ),
    )
    artifact_path = joinpath(run.run_dir, relative_path)
    isfile(artifact_path) ||
        throw(
        ErrorException(
            "write_plot_bundle requires stage `$key` artifact `$artifact_name` to exist on disk: $artifact_path",
        ),
    )
    return artifact_path
end

function _save_bundle_figure(path::AbstractString, figure::Figure)
    mkpath(dirname(path))
    save(path, figure)
    return path
end

function _plot_parameter_slug(parameter)
    slug = replace(lowercase(String(parameter)), r"[^a-z0-9]+" => "_")
    slug = replace(slug, r"^_+" => "")
    slug = replace(slug, r"_+$" => "")
    return isempty(slug) ? "parameter" : slug
end
