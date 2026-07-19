using CSV
using DataFrames
using Dates
using Serialization
using Statistics

const _PIPELINE_SERIALIZED_ARTIFACT_SCHEMA_VERSION = 1

function _alias_pipeline_artifact_path!(
        artifact_paths::Dict{String, String},
        alias_key::AbstractString,
        canonical_key::AbstractString,
    )
    haskey(artifact_paths, canonical_key) || return artifact_paths
    artifact_paths[String(alias_key)] = artifact_paths[String(canonical_key)]
    return artifact_paths
end

function _run_all_pipeline_stages!(context::PipelineContext)
    if !isempty(context.model_config.dims)
        _run_pipeline_stage!(context, "metadata", _run_panel_metadata_stage!)
        _pipeline_stage_enabled(context.prior_sensitivity_config) &&
            _run_pipeline_stage!(context, "prior_sensitivity", _run_prior_sensitivity_stage!)
        _run_pipeline_stage!(context, "fit", _run_fit_stage!)
        _run_pipeline_stage!(context, "assessment", _run_panel_assessment_stage!)
        _run_pipeline_stage!(context, "decomposition", _run_panel_decomposition_stage!)
        _run_pipeline_stage!(context, "diagnostics", _run_panel_diagnostics_stage!)
        _run_pipeline_stage!(context, "curves", _run_panel_curves_stage!)
        _pipeline_stage_enabled(context.optimization_config) &&
            _run_pipeline_stage!(context, "optimisation", _run_optimisation_stage!)
        _skip_panel_pipeline_stages!(context)
        return nothing
    end

    _run_pipeline_stage!(context, "metadata", _run_metadata_stage!)
    _pipeline_stage_enabled(context.prior_sensitivity_config) &&
        _run_pipeline_stage!(context, "prior_sensitivity", _run_prior_sensitivity_stage!)
    _run_pipeline_stage!(context, "preflight", _run_preflight_stage!)
    _run_pipeline_stage!(context, "fit", _run_fit_stage!)
    _run_pipeline_stage!(context, "assessment", _run_assessment_stage!)
    _pipeline_stage_enabled(context.validation_config) &&
        _run_pipeline_stage!(context, "validation", _run_validation_stage!)
    _run_pipeline_stage!(context, "decomposition", _run_decomposition_stage!)
    _run_pipeline_stage!(context, "diagnostics", _run_diagnostics_stage!)
    _run_pipeline_stage!(context, "curves", _run_curves_stage!)
    _pipeline_stage_enabled(context.optimization_config) &&
        _run_pipeline_stage!(context, "optimisation", _run_optimisation_stage!)
    return nothing
end

function _skip_panel_pipeline_stages!(context::PipelineContext)
    warning = "PanelMMM pipeline orchestration is bounded to metadata, prior sensitivity when explicitly enabled, fit, assessment, decomposition, diagnostics, and curves in the current Phase 14 surface, with optimisation when explicitly enabled; unsupported panel stages are skipped."
    _append_pipeline_warning!(context, warning)
    finished_at_utc = _pipeline_timestamp_utc()
    for record in context.stage_records
        record.key in ("metadata", "prior_sensitivity", "fit", "assessment", "decomposition", "diagnostics", "curves") && continue
        record.key == "optimisation" && record.status == :completed && continue
        record.status in (:pending, :running, :skipped) || continue
        if !haskey(record.artifact_paths, "skipped_marker")
            _write_skipped_stage_marker!(
                context,
                record.key;
                reason = warning,
                generated_at_utc = finished_at_utc,
            )
            record = context.stage_records[_stage_index(context, record.key)]
        end
        _set_stage_record!(
            context,
            record.key;
            status = :skipped,
            finished_at_utc,
            warnings = unique(vcat(record.warnings, [warning])),
        )
    end
    _write_pipeline_manifest!(context)
    return nothing
end

function _run_prior_sensitivity_stage!(context::PipelineContext)
    prior_sensitivity = context.prior_sensitivity_config
    isnothing(prior_sensitivity) && return (artifact_paths = Dict{String, String}(), warnings = String[])
    Bool(prior_sensitivity["enabled"]) ||
        return (artifact_paths = Dict{String, String}(), warnings = String[])

    stage_dir = _stage_directory_path(context, "prior_sensitivity")
    resolutions = _expand_prior_sensitivity_scenarios(
        context.resolved_config,
        prior_sensitivity,
    )
    mkpath(stage_dir)

    manifest = Dict{String, Any}(
        "reference" => prior_sensitivity["reference"],
        "scenario_policy" => prior_sensitivity["scenario_policy"],
        "scenarios" => Vector{Any}(),
    )
    llm_safe_manifest = Dict{String, Any}(
        "reference" => prior_sensitivity["reference"],
        "scenario_policy" => prior_sensitivity["scenario_policy"],
        "privacy_mode" => "anonymized_relative",
        "scenarios" => Vector{Any}(),
    )

    for resolution in resolutions
        scenario_dir = joinpath(stage_dir, resolution["name"])
        mkpath(scenario_dir)
        config_path = joinpath(scenario_dir, "config.resolved.yaml")
        _write_pipeline_yaml(config_path, resolution["config"])
        relative_config_path = joinpath(resolution["name"], "config.resolved.yaml")
        overrides = resolution["overrides"]
        override_paths = sort!(String[String(path) for path in keys(overrides)])
        push!(
            manifest["scenarios"],
            Dict{String, Any}(
                "name" => resolution["name"],
                "description" => resolution["description"],
                "reason" => resolution["reason"],
                "classification" => resolution["classification"],
                "config_path" => relative_config_path,
                "override_paths" => override_paths,
            ),
        )
        push!(
            llm_safe_manifest["scenarios"],
            Dict{String, Any}(
                "name" => resolution["name"],
                "classification" => resolution["classification"],
                "config_path" => relative_config_path,
                "override_path_aliases" => [
                    "override_path_$(lpad(index, 3, '0'))" for index in eachindex(override_paths)
                ],
                "has_local_description" => !isnothing(resolution["description"]),
                "has_local_reason" => !isnothing(resolution["reason"]),
            ),
        )
    end

    scenario_manifest_path = joinpath(stage_dir, "scenario_manifest.yaml")
    llm_safe_manifest_path = joinpath(stage_dir, "llm_safe_scenario_manifest.yaml")
    _write_pipeline_yaml(scenario_manifest_path, manifest)
    _write_pipeline_yaml(llm_safe_manifest_path, llm_safe_manifest)

    return (
        artifact_paths = Dict{String, String}(
            "scenario_manifest" => _pipeline_relative_stage_artifact(
                "prior_sensitivity",
                "scenario_manifest.yaml",
            ),
            "llm_safe_scenario_manifest" => _pipeline_relative_stage_artifact(
                "prior_sensitivity",
                "llm_safe_scenario_manifest.yaml",
            ),
        ),
        warnings = String[],
    )
end

function _expand_prior_sensitivity_scenarios(
        config::Dict{String, Any},
        prior_sensitivity::Dict{String, Any},
    )
    Bool(prior_sensitivity["enabled"]) || return Dict{String, Any}[]

    scenarios = _prior_sensitivity_scenario_declarations(config, prior_sensitivity)
    reference = String(prior_sensitivity["reference"])
    if !haskey(scenarios, reference)
        scenarios[reference] = Dict{String, Any}(
            "description" => "Reference model configuration.",
            "reason" => nothing,
            "overrides" => Dict{String, Any}(),
        )
    end

    _validate_prior_sensitivity_model_structure_overrides(
        scenarios;
        allow_model_structure_overrides = Bool(prior_sensitivity["allow_model_structure_overrides"]),
    )

    resolutions = Dict{String, Any}[]
    for name in sort!(collect(keys(scenarios)))
        scenario = scenarios[name]
        config = _resolve_prior_sensitivity_scenario_config(
            name = name,
            scenario = scenario,
            config = config,
        )
        push!(
            resolutions,
            Dict{String, Any}(
                "name" => name,
                "description" => scenario["description"],
                "reason" => scenario["reason"],
                "classification" => _classify_prior_sensitivity_overrides(scenario["overrides"]),
                "overrides" => scenario["overrides"],
                "config" => config,
            ),
        )
    end
    return resolutions
end

function _prior_sensitivity_scenario_declarations(
        config::Dict{String, Any},
        prior_sensitivity::Dict{String, Any},
    )
    declarations = Dict{String, Any}(
        String(name) => _normalize_config_value(scenario) for
            (name, scenario) in prior_sensitivity["scenarios"]
    )
    if prior_sensitivity["scenario_policy"] == "conservative_mmm"
        generated = _conservative_mmm_prior_sensitivity_scenarios(config)
        merge!(generated, declarations)
        return generated
    end
    return declarations
end

function _conservative_mmm_prior_sensitivity_scenarios(config::Dict{String, Any})
    scenarios = Dict{String, Any}(
        "reference" => Dict{String, Any}(
            "description" => "Reference model configuration.",
            "reason" => nothing,
            "overrides" => Dict{String, Any}(),
        ),
    )

    _add_prior_sensitivity_update_scenario!(
        scenarios,
        config,
        name = "shorter_memory",
        path = ("media", "adstock", "priors", "alpha"),
        distribution = "Beta",
        updates = Dict{String, Any}("alpha" => 1, "beta" => 5),
        description = "Faster adstock decay than the reference prior.",
        reason = "Tests whether attribution depends on slower carryover assumptions.",
    )
    _add_prior_sensitivity_update_scenario!(
        scenarios,
        config,
        name = "longer_memory",
        path = ("media", "adstock", "priors", "alpha"),
        distribution = "Beta",
        updates = Dict{String, Any}("alpha" => 2, "beta" => 2),
        description = "Slower adstock decay than the reference prior.",
        reason = "Tests whether attribution depends on longer carryover assumptions.",
    )
    _add_prior_sensitivity_update_scenario!(
        scenarios,
        config,
        name = "tighter_media_effect",
        path = ("media", "saturation", "priors", "beta"),
        distribution = "HalfNormal",
        updates = Dict{String, Any}("sigma" => 0.5),
        description = "More regularized media contribution amplitude.",
        reason = "Tests whether media contribution is inflated by weak amplitude regularization.",
    )
    _add_prior_sensitivity_update_scenario!(
        scenarios,
        config,
        name = "wider_media_effect",
        path = ("media", "saturation", "priors", "beta"),
        distribution = "HalfNormal",
        updates = Dict{String, Any}("sigma" => 2.0),
        description = "Less regularized media contribution amplitude.",
        reason = "Tests whether conclusions change under weaker media shrinkage.",
    )
    _add_prior_sensitivity_update_scenario!(
        scenarios,
        config,
        name = "earlier_saturation",
        path = ("media", "saturation", "priors", "lam"),
        distribution = "Gamma",
        updates = Dict{String, Any}("alpha" => 5, "beta" => 1),
        description = "Response curves bend earlier on the scaled spend axis.",
        reason = "Tests whether ROAS depends on faster diminishing returns.",
    )
    _add_prior_sensitivity_update_scenario!(
        scenarios,
        config,
        name = "later_saturation",
        path = ("media", "saturation", "priors", "lam"),
        distribution = "Gamma",
        updates = Dict{String, Any}("alpha" => 2, "beta" => 1),
        description = "Response curves bend later on the scaled spend axis.",
        reason = "Tests whether ROAS depends on slower diminishing returns.",
    )

    return scenarios
end

function _add_prior_sensitivity_update_scenario!(
        scenarios::Dict{String, Any},
        config::Dict{String, Any};
        name,
        path,
        distribution,
        updates,
        description,
        reason,
    )
    prior = _prior_sensitivity_path_value(config, path)
    prior isa AbstractDict || return scenarios
    get(prior, "distribution", nothing) == distribution || return scenarios

    updated_prior = _normalize_config_value(prior)
    merge!(updated_prior, updates)
    scenarios[String(name)] = Dict{String, Any}(
        "description" => String(description),
        "reason" => String(reason),
        "overrides" => Dict{String, Any}(join(path, ".") => updated_prior),
    )
    return scenarios
end

function _resolve_prior_sensitivity_scenario_config(;
        name::AbstractString,
        scenario::Dict{String, Any},
        config::Dict{String, Any},
    )
    resolved = _apply_prior_sensitivity_overrides(
        _prior_sensitivity_base_config(config),
        scenario["overrides"],
    )
    _validate_prior_sensitivity_scenario_config(name, resolved)
    return resolved
end

function _prior_sensitivity_base_config(config::Dict{String, Any})
    base = _normalize_config_value(config)
    for key in ("ai_advisor", "diagnostics", "prior_sensitivity", "validation", "optimization")
        delete!(base, key)
    end
    return base
end

function _apply_prior_sensitivity_overrides(
        config::Dict{String, Any},
        overrides::AbstractDict,
    )
    resolved = _normalize_config_value(config)
    for (path, value) in overrides
        _classify_prior_sensitivity_override_path(String(path))
        _set_prior_sensitivity_path!(
            resolved,
            _split_prior_sensitivity_override_path(String(path)),
            _normalize_config_value(value),
        )
    end
    return resolved
end

function _set_prior_sensitivity_path!(
        target::Dict{String, Any},
        parts::Vector{String},
        value,
    )
    cursor = target
    for part in parts[1:(end - 1)]
        existing = get(cursor, part, nothing)
        if isnothing(existing)
            existing = Dict{String, Any}()
            cursor[part] = existing
        end
        existing isa AbstractDict ||
            throw(
            ArgumentError(
                "Cannot apply override `$(join(parts, "."))`: segment `$part` is not a mapping",
            ),
        )
        normalized = _normalize_config_value(existing)
        cursor[part] = normalized
        cursor = normalized
    end
    cursor[last(parts)] = value
    return target
end

function _validate_prior_sensitivity_scenario_config(name::AbstractString, config::Dict{String, Any})
    try
        stripped = _strip_pipeline_runner_keys(config)
        model_config_from_dict(stripped)
        sampler_config_from_dict(stripped)
    catch err
        throw(
            ArgumentError(
                "prior_sensitivity scenario `$name` produced an invalid public YAML config: $(sprint(showerror, err))",
            ),
        )
    end
    return nothing
end

function _validate_prior_sensitivity_model_structure_overrides(
        scenarios::Dict{String, Any};
        allow_model_structure_overrides::Bool,
    )
    allow_model_structure_overrides && return nothing
    names = sort!(
        String[
            name for (name, scenario) in scenarios if
                _classify_prior_sensitivity_overrides(scenario["overrides"]) ==
                "model_structure_sensitivity"
        ],
    )
    isempty(names) ||
        throw(
        ArgumentError(
            "prior_sensitivity scenarios include model-structure overrides ($(join(names, ", "))); set allow_model_structure_overrides: true to run them explicitly",
        ),
    )
    return nothing
end

function _prior_sensitivity_path_value(config::Dict{String, Any}, path)
    cursor = config
    for part in path
        cursor isa AbstractDict || return nothing
        haskey(cursor, String(part)) || return nothing
        cursor = cursor[String(part)]
    end
    return cursor
end

function _run_pipeline_stage!(
        context::PipelineContext,
        key::AbstractString,
        execute!::Function,
    )
    current = context.stage_records[_stage_index(context, key)]
    started_at_utc = _pipeline_timestamp_utc()
    _set_stage_record!(
        context,
        key;
        status = :running,
        started_at_utc,
        finished_at_utc = nothing,
        warnings = String[],
        error = nothing,
    )
    _write_pipeline_manifest!(context)
    _pipeline_pretty_stage_started(context, key)

    try
        result = execute!(context)
        merged_artifacts = merge(current.artifact_paths, get(result, :artifact_paths, Dict{String, String}()))
        merged_warnings = vcat(current.warnings, get(result, :warnings, String[]))
        _set_stage_record!(
            context,
            key;
            status = :completed,
            finished_at_utc = _pipeline_timestamp_utc(),
            artifact_paths = merged_artifacts,
            warnings = merged_warnings,
            error = nothing,
        )
        _write_pipeline_manifest!(context)
        _pipeline_pretty_stage_completed(context, key)
        return nothing
    catch err
        payload = _pipeline_error_payload(err, key)
        _set_stage_record!(
            context,
            key;
            status = :failed,
            finished_at_utc = _pipeline_timestamp_utc(),
            error = payload,
        )
        _mark_pipeline_stages_not_reached!(context, key)
        context.status = :failed
        context.finished_at_utc = _pipeline_timestamp_utc()
        context.error = payload
        _write_pipeline_manifest!(context)
        _pipeline_pretty_stage_failed(context, key, err)
        rethrow()
    end
end

function _mark_pipeline_stages_not_reached!(context::PipelineContext, failed_key::AbstractString)
    failed_index = _stage_index(context, failed_key)
    for index in (failed_index + 1):length(context.stage_records)
        record = context.stage_records[index]
        record.status in (:pending, :running) || continue
        _set_stage_record!(context, record.key; status = :not_reached)
    end
    return nothing
end

function _run_metadata_stage!(context::PipelineContext)
    data = _load_pipeline_dataset(context)
    _validate_pipeline_validation_rows(data, context.validation_config)
    _validate_pipeline_positive_observed_channel_spend(data)
    model = TimeSeriesMMM(context.model_config, context.sampler_config, data)
    spec = build_model(model)

    context.data = data
    context.model = model
    context.data_manifest = _pipeline_data_manifest(data, context.model_config)

    metadata_dir = _stage_directory_path(context, "metadata")
    dataset_metadata_path = joinpath(metadata_dir, "dataset_metadata.json")
    model_metadata_path = joinpath(metadata_dir, "model_metadata.json")
    spec_summary_path = joinpath(metadata_dir, "spec_summary.csv")
    data_dictionary_path = joinpath(metadata_dir, "data_dictionary.csv")
    design_matrix_manifest_path = joinpath(metadata_dir, "design_matrix_manifest.csv")
    holiday_feature_manifest_path = joinpath(metadata_dir, "holiday_feature_manifest.csv")
    session_info_path = joinpath(metadata_dir, "session_info.txt")

    _write_pipeline_json(dataset_metadata_path, context.data_manifest)
    _write_pipeline_json(
        model_metadata_path,
        Dict{String, Any}(
            "model_type" => "TimeSeriesMMM",
            "backend" => "turing",
            "objective" => context.model_config.target_type,
            "nobs" => spec.nobs,
            "nchannels" => spec.nchannels,
            "nholidays" => length(_holidays_columns(spec.holidays)),
            "holidays_mode" => String(_holidays_mode(spec.holidays)),
            "channel_scale" => spec.channel_scale,
            "target_scale" => spec.target_scale,
        ),
    )
    _write_pipeline_csv(spec_summary_path, _spec_summary_table(spec))
    _write_pipeline_csv(data_dictionary_path, _data_dictionary_table(data, context.model_config))
    _write_pipeline_csv(design_matrix_manifest_path, _design_matrix_manifest_table(spec, data))
    _write_pipeline_csv(holiday_feature_manifest_path, _holiday_feature_manifest_table(spec))
    _write_pipeline_text(session_info_path, _pipeline_session_info(context, spec))

    return (
        artifact_paths = Dict{String, String}(
            "data_dictionary" => _pipeline_relative_stage_artifact("metadata", "data_dictionary.csv"),
            "dataset_metadata" => _pipeline_relative_stage_artifact("metadata", "dataset_metadata.json"),
            "design_matrix_manifest" => _pipeline_relative_stage_artifact("metadata", "design_matrix_manifest.csv"),
            "holiday_feature_manifest" => _pipeline_relative_stage_artifact("metadata", "holiday_feature_manifest.csv"),
            "model_metadata" => _pipeline_relative_stage_artifact("metadata", "model_metadata.json"),
            "session_info" => _pipeline_relative_stage_artifact("metadata", "session_info.txt"),
            "spec_summary" => _pipeline_relative_stage_artifact("metadata", "spec_summary.csv"),
        ),
        warnings = String[],
    )
end

function _run_panel_metadata_stage!(context::PipelineContext)
    data = _load_pipeline_panel_dataset(context)
    model = PanelMMM(context.model_config, context.sampler_config, data)
    spec = build_model(model)

    context.data = data
    context.model = model
    context.data_manifest = _pipeline_data_manifest(data, context.model_config)

    metadata_dir = _stage_directory_path(context, "metadata")
    dataset_metadata_path = joinpath(metadata_dir, "dataset_metadata.json")
    model_metadata_path = joinpath(metadata_dir, "model_metadata.json")
    spec_summary_path = joinpath(metadata_dir, "spec_summary.csv")
    data_dictionary_path = joinpath(metadata_dir, "data_dictionary.csv")
    design_matrix_manifest_path = joinpath(metadata_dir, "design_matrix_manifest.csv")
    holiday_feature_manifest_path = joinpath(metadata_dir, "holiday_feature_manifest.csv")
    session_info_path = joinpath(metadata_dir, "session_info.txt")

    _write_pipeline_json(dataset_metadata_path, context.data_manifest)
    _write_pipeline_json(
        model_metadata_path,
        Dict{String, Any}(
            "model_type" => "PanelMMM",
            "backend" => "turing",
            "objective" => context.model_config.target_type,
            "nobs" => spec.nobs,
            "n_time" => length(data.dates),
            "nchannels" => spec.nchannels,
            "npanels" => length(data.panel_names),
            "panel_dims" => collect(context.model_config.dims),
            "panel_names" => copy(data.panel_names),
            "nholidays" => length(_holidays_columns(spec.holidays)),
            "holidays_mode" => String(_holidays_mode(spec.holidays)),
            "channel_scale" => spec.channel_scale,
            "target_scale" => spec.target_scale,
        ),
    )
    _write_pipeline_csv(spec_summary_path, _spec_summary_table(spec))
    _write_pipeline_csv(data_dictionary_path, _data_dictionary_table(data, context.model_config))
    _write_pipeline_csv(design_matrix_manifest_path, _design_matrix_manifest_table(spec, data))
    _write_pipeline_csv(holiday_feature_manifest_path, _holiday_feature_manifest_table(spec))
    _write_pipeline_text(session_info_path, _pipeline_session_info(context, spec))

    return (
        artifact_paths = Dict{String, String}(
            "data_dictionary" => _pipeline_relative_stage_artifact("metadata", "data_dictionary.csv"),
            "dataset_metadata" => _pipeline_relative_stage_artifact("metadata", "dataset_metadata.json"),
            "design_matrix_manifest" => _pipeline_relative_stage_artifact("metadata", "design_matrix_manifest.csv"),
            "holiday_feature_manifest" => _pipeline_relative_stage_artifact("metadata", "holiday_feature_manifest.csv"),
            "model_metadata" => _pipeline_relative_stage_artifact("metadata", "model_metadata.json"),
            "session_info" => _pipeline_relative_stage_artifact("metadata", "session_info.txt"),
            "spec_summary" => _pipeline_relative_stage_artifact("metadata", "spec_summary.csv"),
        ),
        warnings = String[],
    )
end

function _run_validation_stage!(context::PipelineContext)
    data = _require_pipeline_data(context, "validation")
    holdout_rows = Int(context.validation_config["holdout_rows"])
    train_data, holdout_data = _split_validation_datasets(data, holdout_rows)
    validation_model = TimeSeriesMMM(context.model_config, context.sampler_config, train_data)
    state = fit!(validation_model)
    predictive = predict(validation_model, holdout_data)
    predictive_matrix = _target_draw_matrix(predictive, nobs(holdout_data))
    fitted_mean, fitted_lower, fitted_upper = _column_summary(predictive_matrix)
    observed = Float64.(collect(holdout_data.target))
    residuals = observed .- fitted_mean

    validation_result = PipelineValidationResult(
        holdout_rows = holdout_rows,
        train_date_start = string(first(train_data.dates)),
        train_date_end = string(last(train_data.dates)),
        holdout_date_start = string(first(holdout_data.dates)),
        holdout_date_end = string(last(holdout_data.dates)),
        observed = observed,
        fitted_mean = fitted_mean,
        residuals = residuals,
        metrics = Dict{String, Float64}(
            "mae" => mean(abs.(residuals)),
            "rmse" => sqrt(mean(residuals .^ 2)),
            "bias" => mean(residuals),
        ),
    )

    stage_dir = _stage_directory_path(context, "validation")
    metadata_path = joinpath(stage_dir, "validation_metadata.json")
    results_path = joinpath(stage_dir, "validation_results.jls")
    observed_path = joinpath(stage_dir, "holdout_observed.csv")
    fitted_path = joinpath(stage_dir, "holdout_fitted.csv")
    residuals_path = joinpath(stage_dir, "holdout_residuals.csv")
    predictive_path = joinpath(stage_dir, "holdout_posterior_predictive.jls")
    summary_path = joinpath(stage_dir, "holdout_predictive_summary.csv")
    report_path = joinpath(stage_dir, "holdout_predictive_report.json")
    residuals_acf_plot_path = joinpath(stage_dir, "holdout_residuals_acf.png")
    plot_path = joinpath(stage_dir, "holdout_timeseries.png")

    _write_pipeline_json(
        metadata_path,
        Dict{String, Any}(
            "holdout_rows" => holdout_rows,
            "train_rows" => nobs(train_data),
            "holdout_rows_observed" => nobs(holdout_data),
            "train_date_start" => validation_result.train_date_start,
            "train_date_end" => validation_result.train_date_end,
            "holdout_date_start" => validation_result.holdout_date_start,
            "holdout_date_end" => validation_result.holdout_date_end,
        ),
    )
    _write_pipeline_serialized(
        results_path,
        validation_result;
        artifact_kind = "PipelineValidationResult",
    )
    _write_pipeline_csv(observed_path, _observed_series_table(holdout_data.dates, observed))
    _write_pipeline_csv(
        fitted_path,
        _fitted_series_table(holdout_data.dates, fitted_mean, fitted_lower, fitted_upper),
    )
    _write_pipeline_csv(residuals_path, _residual_series_table(holdout_data.dates, residuals))
    _write_pipeline_serialized(
        predictive_path,
        predictive;
        artifact_kind = "HoldoutPosteriorPredictiveChain",
    )
    _write_pipeline_csv(summary_path, _metric_value_table(validation_result.metrics))
    _write_pipeline_json(
        report_path,
        _holdout_predictive_report_dict(validation_result, predictive_matrix),
    )
    artifact_paths = Dict{String, String}(
        "holdout_fitted" => _pipeline_relative_stage_artifact("validation", "holdout_fitted.csv"),
        "holdout_observed" => _pipeline_relative_stage_artifact("validation", "holdout_observed.csv"),
        "holdout_posterior_predictive" => _pipeline_relative_stage_artifact("validation", "holdout_posterior_predictive.jls"),
        "holdout_predictive_report" => _pipeline_relative_stage_artifact("validation", "holdout_predictive_report.json"),
        "holdout_predictive_summary" => _pipeline_relative_stage_artifact("validation", "holdout_predictive_summary.csv"),
        "holdout_residuals" => _pipeline_relative_stage_artifact("validation", "holdout_residuals.csv"),
        "validation_metadata" => _pipeline_relative_stage_artifact("validation", "validation_metadata.json"),
        "validation_results" => _pipeline_relative_stage_artifact("validation", "validation_results.jls"),
        "holdout_summary" => _pipeline_relative_stage_artifact("validation", "holdout_predictive_summary.csv"),
    )
    warnings = isempty(state.message) ? String[] : [state.message]
    _save_pipeline_plot!(
        artifact_paths,
        warnings,
        "validation",
        "holdout_residuals_acf_plot",
        residuals_acf_plot_path,
        _pipeline_relative_stage_artifact("validation", "holdout_residuals_acf.png"),
        :residuals_acf,
        residuals,
    )
    _save_pipeline_plot!(
        artifact_paths,
        warnings,
        "validation",
        "holdout_timeseries_plot",
        plot_path,
        _pipeline_relative_stage_artifact("validation", "holdout_timeseries.png"),
        :holdout_validation,
        holdout_data,
        fitted_mean,
        fitted_lower,
        fitted_upper,
        context.model_config.target_column,
    )

    return (
        artifact_paths = artifact_paths,
        warnings = warnings,
    )
end

function _run_decomposition_stage!(context::PipelineContext)
    grouped = _require_pipeline_grouped_results(context, "decomposition")
    contributions = contribution_results(grouped)
    decomposition = decomposition_results(grouped)
    stage_dir = _stage_directory_path(context, "decomposition")
    contributions_path = joinpath(stage_dir, "contribution_results.jls")
    decomposition_path = joinpath(stage_dir, "decomposition_results.jls")
    contribution_summary_path = joinpath(stage_dir, "contribution_summary.csv")
    decomposition_summary_path = joinpath(stage_dir, "decomposition_summary.csv")
    contributions_plot_path = joinpath(stage_dir, "contributions.png")
    contributions_area_plot_path = joinpath(stage_dir, "contributions_area.png")
    decomposition_plot_path = joinpath(stage_dir, "decomposition.png")
    baseline_contributions_path = joinpath(stage_dir, "baseline_contributions.csv")
    channel_contributions_path = joinpath(stage_dir, "channel_contributions.csv")

    _write_pipeline_serialized(
        contributions_path,
        contributions;
        artifact_kind = "ContributionResults",
    )
    _write_pipeline_serialized(
        decomposition_path,
        decomposition;
        artifact_kind = "DecompositionResults",
    )
    contribution_summary = summary_table(contributions)
    decomposition_summary = summary_table(decomposition)
    _write_pipeline_csv(contribution_summary_path, contribution_summary)
    _write_pipeline_csv(decomposition_summary_path, decomposition_summary)
    _write_pipeline_csv(baseline_contributions_path, _component_partition_table(contribution_summary, false))
    _write_pipeline_csv(channel_contributions_path, _component_partition_table(contribution_summary, true))
    artifact_paths = Dict{String, String}(
        "baseline_contributions" => _pipeline_relative_stage_artifact("decomposition", "baseline_contributions.csv"),
        "channel_contributions" => _pipeline_relative_stage_artifact("decomposition", "channel_contributions.csv"),
        "contribution_results" => _pipeline_relative_stage_artifact("decomposition", "contribution_results.jls"),
        "decomposition_results" => _pipeline_relative_stage_artifact("decomposition", "decomposition_results.jls"),
        "contribution_summary" => _pipeline_relative_stage_artifact("decomposition", "contribution_summary.csv"),
        "decomposition_summary" => _pipeline_relative_stage_artifact("decomposition", "decomposition_summary.csv"),
        "mean_contributions_over_time" => _pipeline_relative_stage_artifact("decomposition", "contribution_summary.csv"),
    )
    warnings = String[]
    _save_pipeline_plot!(
        artifact_paths,
        warnings,
        "decomposition",
        "contributions_plot",
        contributions_plot_path,
        _pipeline_relative_stage_artifact("decomposition", "contributions.png"),
        :contribution,
        contributions,
    )
    _save_pipeline_plot!(
        artifact_paths,
        warnings,
        "decomposition",
        "contributions_area_plot",
        contributions_area_plot_path,
        _pipeline_relative_stage_artifact("decomposition", "contributions_area.png"),
        :contribution_area,
        contributions,
    )
    _save_pipeline_plot!(
        artifact_paths,
        warnings,
        "decomposition",
        "decomposition_plot",
        decomposition_plot_path,
        _pipeline_relative_stage_artifact("decomposition", "decomposition.png"),
        :decomposition,
        decomposition,
    )
    _alias_pipeline_artifact_path!(artifact_paths, "waterfall_plot", "decomposition_plot")
    _alias_pipeline_artifact_path!(artifact_paths, "weekly_media_contribution_plot", "contributions_area_plot")

    return (
        artifact_paths = artifact_paths,
        warnings = warnings,
    )
end

function _run_panel_decomposition_stage!(context::PipelineContext)
    grouped = _require_pipeline_grouped_results(context, "decomposition")
    contributions = contribution_results(grouped)
    decomposition = decomposition_results(grouped)
    stage_dir = _stage_directory_path(context, "decomposition")
    contributions_path = joinpath(stage_dir, "contribution_results.jls")
    decomposition_path = joinpath(stage_dir, "decomposition_results.jls")
    contribution_summary_path = joinpath(stage_dir, "contribution_summary.csv")
    decomposition_summary_path = joinpath(stage_dir, "decomposition_summary.csv")
    contributions_plot_path = joinpath(stage_dir, "contributions.png")
    contributions_area_plot_path = joinpath(stage_dir, "contributions_area.png")
    decomposition_plot_path = joinpath(stage_dir, "decomposition.png")
    baseline_contributions_path = joinpath(stage_dir, "baseline_contributions.csv")
    channel_contributions_path = joinpath(stage_dir, "channel_contributions.csv")

    _write_pipeline_serialized(
        contributions_path,
        contributions;
        artifact_kind = "ContributionResults",
    )
    _write_pipeline_serialized(
        decomposition_path,
        decomposition;
        artifact_kind = "DecompositionResults",
    )
    contribution_summary = summary_table(contributions)
    decomposition_summary = summary_table(decomposition)
    _write_pipeline_csv(contribution_summary_path, contribution_summary)
    _write_pipeline_csv(decomposition_summary_path, decomposition_summary)
    _write_pipeline_csv(baseline_contributions_path, _component_partition_table(contribution_summary, false))
    _write_pipeline_csv(channel_contributions_path, _component_partition_table(contribution_summary, true))
    artifact_paths = Dict{String, String}(
        "baseline_contributions" => _pipeline_relative_stage_artifact("decomposition", "baseline_contributions.csv"),
        "channel_contributions" => _pipeline_relative_stage_artifact("decomposition", "channel_contributions.csv"),
        "contribution_results" => _pipeline_relative_stage_artifact("decomposition", "contribution_results.jls"),
        "decomposition_results" => _pipeline_relative_stage_artifact("decomposition", "decomposition_results.jls"),
        "contribution_summary" => _pipeline_relative_stage_artifact("decomposition", "contribution_summary.csv"),
        "decomposition_summary" => _pipeline_relative_stage_artifact("decomposition", "decomposition_summary.csv"),
        "mean_contributions_over_time" => _pipeline_relative_stage_artifact("decomposition", "contribution_summary.csv"),
    )
    warnings = String[]
    _save_pipeline_plot!(
        artifact_paths,
        warnings,
        "decomposition",
        "contributions_plot",
        contributions_plot_path,
        _pipeline_relative_stage_artifact("decomposition", "contributions.png"),
        :panel_contribution,
        contributions,
    )
    _save_pipeline_plot!(
        artifact_paths,
        warnings,
        "decomposition",
        "contributions_area_plot",
        contributions_area_plot_path,
        _pipeline_relative_stage_artifact("decomposition", "contributions_area.png"),
        :panel_contribution_area,
        contributions,
    )
    _save_pipeline_plot!(
        artifact_paths,
        warnings,
        "decomposition",
        "decomposition_plot",
        decomposition_plot_path,
        _pipeline_relative_stage_artifact("decomposition", "decomposition.png"),
        :panel_decomposition,
        decomposition,
    )
    _alias_pipeline_artifact_path!(artifact_paths, "waterfall_plot", "decomposition_plot")
    _alias_pipeline_artifact_path!(artifact_paths, "weekly_media_contribution_plot", "contributions_area_plot")

    return (
        artifact_paths = artifact_paths,
        warnings = warnings,
    )
end

function _run_diagnostics_stage!(context::PipelineContext)
    model = _require_pipeline_model(context, "diagnostics")
    grouped = inference_results(
        model;
        include_prior = true,
        include_posterior_predictive = false,
        include_prior_predictive = false,
    )
    diagnostics = model_diagnostics(model)
    sampler = sampler_diagnostics(model)
    report = convergence_report(model)
    sampler_warning_bundle = sampler_warnings(sampler)
    convergence_warning_bundle = convergence_warnings(report)

    stage_dir = _stage_directory_path(context, "diagnostics")
    diagnostics_path = joinpath(stage_dir, "model_diagnostics.jls")
    sampler_path = joinpath(stage_dir, "sampler_diagnostics.jls")
    report_path = joinpath(stage_dir, "convergence_report.json")
    warnings_path = joinpath(stage_dir, "warnings_summary.json")
    posterior_density_path = joinpath(stage_dir, "posterior_density.png")
    chain_diagnostics_path = joinpath(stage_dir, "chain_diagnostics.txt")
    design_report_path = joinpath(stage_dir, "design_report.json")
    diagnostics_report_path = joinpath(stage_dir, "diagnostics_report.csv")
    diagnostics_summary_path = joinpath(stage_dir, "diagnostics_summary.txt")
    mcmc_report_path = joinpath(stage_dir, "mcmc_report.json")
    mcmc_summary_path = joinpath(stage_dir, "mcmc_summary.csv")
    predictive_report_path = joinpath(stage_dir, "predictive_report.json")
    predictive_summary_path = joinpath(stage_dir, "predictive_summary.csv")
    residual_diagnostics_path = joinpath(stage_dir, "residual_diagnostics.csv")
    residuals_acf_plot_path = joinpath(stage_dir, "residuals_acf.png")
    vif_report_path = joinpath(stage_dir, "vif_report.csv")

    _write_pipeline_serialized(
        diagnostics_path,
        diagnostics;
        artifact_kind = "ModelDiagnostics",
    )
    _write_pipeline_serialized(
        sampler_path,
        sampler;
        artifact_kind = "SamplerDiagnostics",
    )
    _write_pipeline_json(report_path, _convergence_report_dict(report))
    _write_pipeline_json(
        warnings_path,
        Dict{String, Any}(
            "sampler_warnings" => _sampler_warnings_dict(sampler_warning_bundle),
            "convergence_warnings" => _convergence_warnings_dict(convergence_warning_bundle),
            "summary" => Dict{String, Any}(
                "sampler_warning_count" => sampler_warning_bundle.summary.nwarnings,
                "convergence_warning_count" => convergence_warning_bundle.summary.nwarnings,
                "has_numerical_errors" => has_numerical_errors(sampler),
                "has_sampler_warnings" => has_sampler_warnings(sampler_warning_bundle),
                "has_convergence_issues" => has_convergence_issues(report),
                "has_convergence_warnings" => has_convergence_warnings(convergence_warning_bundle),
            ),
        ),
    )
    _write_pipeline_text(
        chain_diagnostics_path,
        _chain_diagnostics_text(diagnostics, sampler, report),
    )
    _write_pipeline_json(design_report_path, _design_report_dict(model))
    _write_pipeline_csv(diagnostics_report_path, _diagnostics_report_table(diagnostics))
    _write_pipeline_text(
        diagnostics_summary_path,
        _diagnostics_summary_text(sampler_warning_bundle, convergence_warning_bundle),
    )
    _write_pipeline_json(mcmc_report_path, _mcmc_report_dict(sampler, report))
    _write_pipeline_csv(mcmc_summary_path, _sampler_summary_table(sampler))
    _write_pipeline_json(predictive_report_path, _predictive_report_dict(context.flat_results, model.data))
    _write_pipeline_csv(predictive_summary_path, _pipeline_predictive_summary_table(context.flat_results, model.data))
    _write_pipeline_csv(residual_diagnostics_path, _pipeline_residual_diagnostics_table(context.flat_results, model.data))
    _write_pipeline_csv(vif_report_path, _vif_report_table(model.data))

    artifact_paths = Dict{String, String}(
        "chain_diagnostics" => _pipeline_relative_stage_artifact("diagnostics", "chain_diagnostics.txt"),
        "design_report" => _pipeline_relative_stage_artifact("diagnostics", "design_report.json"),
        "design_summary" => _pipeline_relative_stage_artifact("metadata", "design_matrix_manifest.csv"),
        "diagnostics_report" => _pipeline_relative_stage_artifact("diagnostics", "diagnostics_report.csv"),
        "diagnostics_summary" => _pipeline_relative_stage_artifact("diagnostics", "diagnostics_summary.txt"),
        "model_diagnostics" => _pipeline_relative_stage_artifact("diagnostics", "model_diagnostics.jls"),
        "sampler_diagnostics" => _pipeline_relative_stage_artifact("diagnostics", "sampler_diagnostics.jls"),
        "mcmc_report" => _pipeline_relative_stage_artifact("diagnostics", "mcmc_report.json"),
        "mcmc_summary" => _pipeline_relative_stage_artifact("diagnostics", "mcmc_summary.csv"),
        "predictive_report" => _pipeline_relative_stage_artifact("diagnostics", "predictive_report.json"),
        "predictive_summary" => _pipeline_relative_stage_artifact("diagnostics", "predictive_summary.csv"),
        "residual_diagnostics" => _pipeline_relative_stage_artifact("diagnostics", "residual_diagnostics.csv"),
        "vif_report" => _pipeline_relative_stage_artifact("diagnostics", "vif_report.csv"),
        "convergence_report" => _pipeline_relative_stage_artifact("diagnostics", "convergence_report.json"),
        "warnings_summary" => _pipeline_relative_stage_artifact("diagnostics", "warnings_summary.json"),
    )
    warnings = String[]
    _save_pipeline_plot!(
        artifact_paths,
        warnings,
        "diagnostics",
        "residuals_acf_plot",
        residuals_acf_plot_path,
        _pipeline_relative_stage_artifact("diagnostics", "residuals_acf.png"),
        :residuals_acf,
        _pipeline_residual_vector(context.flat_results, model.data),
    )
    _save_pipeline_plot!(
        artifact_paths,
        warnings,
        "diagnostics",
        "posterior_density_plot",
        posterior_density_path,
        _pipeline_relative_stage_artifact("diagnostics", "posterior_density.png"),
        :posterior_density,
        grouped,
    )

    if _pipeline_plots_enabled()
        extension = Base.get_extension(@__MODULE__, _PLOTTING_EXTENSION_NAME)
        posterior = Base.invokelatest(
            extension._require_plot_posterior,
            grouped,
            "_run_diagnostics_stage!",
        )
        selected = Base.invokelatest(
            extension._select_plot_parameters,
            posterior;
            parameters = nothing,
            max_parameters = 8,
            action = "_run_diagnostics_stage!",
        )
        prior_available = isnothing(grouped.prior) ? Set{Symbol}() :
            Set(Symbol.(names(grouped.prior, :parameters)))
        for parameter in selected
            parameter in prior_available || continue
            slug = Base.invokelatest(extension._plot_parameter_slug, parameter)
            filename = "prior_posterior_$(slug).png"
            _save_pipeline_plot!(
                artifact_paths,
                warnings,
                "diagnostics",
                "$(splitext(filename)[1])_plot",
                joinpath(stage_dir, filename),
                _pipeline_relative_stage_artifact("diagnostics", filename),
                :prior_posterior,
                grouped;
                parameter,
            )
        end
    end

    return (
        artifact_paths = artifact_paths,
        warnings = warnings,
    )
end

function _run_panel_diagnostics_stage!(context::PipelineContext)
    model = _require_pipeline_model(context, "diagnostics")
    model isa PanelMMM ||
        throw(ArgumentError("panel diagnostics requires a PanelMMM model"))
    grouped = _require_pipeline_grouped_results(context, "diagnostics")
    diagnostics = model_diagnostics(model)
    sampler = sampler_diagnostics(model)
    report = convergence_report(model)
    sampler_warning_bundle = sampler_warnings(sampler)
    convergence_warning_bundle = convergence_warnings(report)

    stage_dir = _stage_directory_path(context, "diagnostics")
    diagnostics_path = joinpath(stage_dir, "model_diagnostics.jls")
    sampler_path = joinpath(stage_dir, "sampler_diagnostics.jls")
    report_path = joinpath(stage_dir, "convergence_report.json")
    warnings_path = joinpath(stage_dir, "warnings_summary.json")
    posterior_density_path = joinpath(stage_dir, "posterior_density.png")
    chain_diagnostics_path = joinpath(stage_dir, "chain_diagnostics.txt")
    design_report_path = joinpath(stage_dir, "design_report.json")
    diagnostics_report_path = joinpath(stage_dir, "diagnostics_report.csv")
    diagnostics_summary_path = joinpath(stage_dir, "diagnostics_summary.txt")
    mcmc_report_path = joinpath(stage_dir, "mcmc_report.json")
    mcmc_summary_path = joinpath(stage_dir, "mcmc_summary.csv")
    predictive_report_path = joinpath(stage_dir, "predictive_report.json")
    predictive_summary_path = joinpath(stage_dir, "predictive_summary.csv")
    residual_diagnostics_path = joinpath(stage_dir, "residual_diagnostics.csv")
    residuals_acf_plot_path = joinpath(stage_dir, "residuals_acf.png")
    vif_report_path = joinpath(stage_dir, "vif_report.csv")

    _write_pipeline_serialized(
        diagnostics_path,
        diagnostics;
        artifact_kind = "ModelDiagnostics",
    )
    _write_pipeline_serialized(
        sampler_path,
        sampler;
        artifact_kind = "SamplerDiagnostics",
    )
    _write_pipeline_json(report_path, _convergence_report_dict(report))
    _write_pipeline_json(
        warnings_path,
        Dict{String, Any}(
            "sampler_warnings" => _sampler_warnings_dict(sampler_warning_bundle),
            "convergence_warnings" => _convergence_warnings_dict(convergence_warning_bundle),
            "summary" => Dict{String, Any}(
                "sampler_warning_count" => sampler_warning_bundle.summary.nwarnings,
                "convergence_warning_count" => convergence_warning_bundle.summary.nwarnings,
                "has_numerical_errors" => has_numerical_errors(sampler),
                "has_sampler_warnings" => has_sampler_warnings(sampler_warning_bundle),
                "has_convergence_issues" => has_convergence_issues(report),
                "has_convergence_warnings" => has_convergence_warnings(convergence_warning_bundle),
            ),
        ),
    )
    _write_pipeline_text(
        chain_diagnostics_path,
        _chain_diagnostics_text(diagnostics, sampler, report),
    )
    _write_pipeline_json(design_report_path, _design_report_dict(model))
    _write_pipeline_csv(diagnostics_report_path, _diagnostics_report_table(diagnostics))
    _write_pipeline_text(
        diagnostics_summary_path,
        _diagnostics_summary_text(sampler_warning_bundle, convergence_warning_bundle),
    )
    _write_pipeline_json(mcmc_report_path, _mcmc_report_dict(sampler, report))
    _write_pipeline_csv(mcmc_summary_path, _sampler_summary_table(sampler))
    _write_pipeline_json(predictive_report_path, _predictive_report_dict(context.flat_results, model.data))
    _write_pipeline_csv(predictive_summary_path, _pipeline_predictive_summary_table(context.flat_results, model.data))
    _write_pipeline_csv(residual_diagnostics_path, _pipeline_residual_diagnostics_table(context.flat_results, model.data))
    _write_pipeline_csv(vif_report_path, _vif_report_table(model.data))

    artifact_paths = Dict{String, String}(
        "chain_diagnostics" => _pipeline_relative_stage_artifact("diagnostics", "chain_diagnostics.txt"),
        "design_report" => _pipeline_relative_stage_artifact("diagnostics", "design_report.json"),
        "design_summary" => _pipeline_relative_stage_artifact("metadata", "design_matrix_manifest.csv"),
        "diagnostics_report" => _pipeline_relative_stage_artifact("diagnostics", "diagnostics_report.csv"),
        "diagnostics_summary" => _pipeline_relative_stage_artifact("diagnostics", "diagnostics_summary.txt"),
        "model_diagnostics" => _pipeline_relative_stage_artifact("diagnostics", "model_diagnostics.jls"),
        "sampler_diagnostics" => _pipeline_relative_stage_artifact("diagnostics", "sampler_diagnostics.jls"),
        "mcmc_report" => _pipeline_relative_stage_artifact("diagnostics", "mcmc_report.json"),
        "mcmc_summary" => _pipeline_relative_stage_artifact("diagnostics", "mcmc_summary.csv"),
        "predictive_report" => _pipeline_relative_stage_artifact("diagnostics", "predictive_report.json"),
        "predictive_summary" => _pipeline_relative_stage_artifact("diagnostics", "predictive_summary.csv"),
        "residual_diagnostics" => _pipeline_relative_stage_artifact("diagnostics", "residual_diagnostics.csv"),
        "vif_report" => _pipeline_relative_stage_artifact("diagnostics", "vif_report.csv"),
        "convergence_report" => _pipeline_relative_stage_artifact("diagnostics", "convergence_report.json"),
        "warnings_summary" => _pipeline_relative_stage_artifact("diagnostics", "warnings_summary.json"),
    )
    warnings = String[]
    _save_pipeline_plot!(
        artifact_paths,
        warnings,
        "diagnostics",
        "residuals_acf_plot",
        residuals_acf_plot_path,
        _pipeline_relative_stage_artifact("diagnostics", "residuals_acf.png"),
        :residuals_acf,
        _pipeline_residual_vector(context.flat_results, model.data),
    )
    _save_pipeline_plot!(
        artifact_paths,
        warnings,
        "diagnostics",
        "posterior_density_plot",
        posterior_density_path,
        _pipeline_relative_stage_artifact("diagnostics", "posterior_density.png"),
        :posterior_density,
        grouped,
    )

    return (
        artifact_paths = artifact_paths,
        warnings = warnings,
    )
end

function _run_curves_stage!(context::PipelineContext)
    grouped = _require_pipeline_grouped_results(context, "curves")
    response_results = Dict{String, ResponseCurveResults}()
    saturation_results = Dict{String, SaturationCurveResults}()
    adstock_results = Dict{String, AdstockCurveResults}()
    metric_results_by_channel = Dict{String, MetricResults}()
    curve_tables = DataFrame[]
    metric_tables = DataFrame[]
    artifact_paths = Dict{String, String}()
    warnings = String[]
    stage_dir = _stage_directory_path(context, "curves")

    for channel in grouped.spec.channel_columns
        grid = _pipeline_curve_grid(grouped, channel, context.config.curve_points)
        response = response_curve_results(grouped; channel, grid)
        saturation = saturation_curve_results(grouped; channel, grid)
        adstock = adstock_curve_results(grouped; channel, grid)
        metrics = metric_results(response)
        response_results[channel] = response
        saturation_results[channel] = saturation
        adstock_results[channel] = adstock
        metric_results_by_channel[channel] = metrics
        push!(curve_tables, _curve_family_summary_table(response, "response"))
        push!(curve_tables, _curve_family_summary_table(saturation, "saturation"))
        push!(curve_tables, _curve_family_summary_table(adstock, "adstock"))
        push!(metric_tables, summary_table(metrics))

        response_filename = "response_curve_$(channel).jls"
        saturation_filename = "saturation_curve_$(channel).jls"
        adstock_filename = "adstock_curve_$(channel).jls"
        _write_pipeline_serialized(
            joinpath(stage_dir, response_filename),
            response;
            artifact_kind = "ResponseCurveResults",
        )
        _write_pipeline_serialized(
            joinpath(stage_dir, saturation_filename),
            saturation;
            artifact_kind = "SaturationCurveResults",
        )
        _write_pipeline_serialized(
            joinpath(stage_dir, adstock_filename),
            adstock;
            artifact_kind = "AdstockCurveResults",
        )

        artifact_paths["response_curve_$(channel)"] =
            _pipeline_relative_stage_artifact("curves", response_filename)
        artifact_paths["saturation_curve_$(channel)"] =
            _pipeline_relative_stage_artifact("curves", saturation_filename)
        artifact_paths["adstock_curve_$(channel)"] =
            _pipeline_relative_stage_artifact("curves", adstock_filename)

        response_plot = "response_curve_$(channel).png"
        saturation_plot = "saturation_curve_$(channel).png"
        adstock_plot = "adstock_curve_$(channel).png"
        _save_pipeline_plot!(
            artifact_paths,
            warnings,
            "curves",
            "response_curve_$(channel)_plot",
            joinpath(stage_dir, response_plot),
            _pipeline_relative_stage_artifact("curves", response_plot),
            :response_curve,
            response,
        )
        _save_pipeline_plot!(
            artifact_paths,
            warnings,
            "curves",
            "saturation_curve_$(channel)_plot",
            joinpath(stage_dir, saturation_plot),
            _pipeline_relative_stage_artifact("curves", saturation_plot),
            :saturation_curve,
            saturation,
        )
        _save_pipeline_plot!(
            artifact_paths,
            warnings,
            "curves",
            "adstock_curve_$(channel)_plot",
            joinpath(stage_dir, adstock_plot),
            _pipeline_relative_stage_artifact("curves", adstock_plot),
            :adstock_curve,
            adstock,
        )
    end

    metrics_path = joinpath(stage_dir, "metric_results.jls")
    curves_summary_path = joinpath(stage_dir, "curve_summary.csv")
    metrics_summary_path = joinpath(stage_dir, "metric_summary.csv")
    response_bundle_path = joinpath(stage_dir, "response_curve.jls")
    saturation_bundle_path = joinpath(stage_dir, "saturation_curve.jls")
    adstock_bundle_path = joinpath(stage_dir, "adstock_curve.jls")
    response_summary_path = joinpath(stage_dir, "forward_pass_contribution_curve_summary.csv")
    saturation_summary_path = joinpath(stage_dir, "saturation_curve_summary.csv")
    adstock_summary_path = joinpath(stage_dir, "adstock_curve_summary.csv")

    _write_pipeline_serialized(
        metrics_path,
        metric_results_by_channel;
        artifact_kind = "MetricResultsByChannel",
    )
    _write_pipeline_serialized(
        response_bundle_path,
        response_results;
        artifact_kind = "ResponseCurveResultsByChannel",
    )
    _write_pipeline_serialized(
        saturation_bundle_path,
        saturation_results;
        artifact_kind = "SaturationCurveResultsByChannel",
    )
    _write_pipeline_serialized(
        adstock_bundle_path,
        adstock_results;
        artifact_kind = "AdstockCurveResultsByChannel",
    )
    _write_pipeline_csv(curves_summary_path, reduce(vcat, curve_tables))
    _write_pipeline_csv(metrics_summary_path, reduce(vcat, metric_tables))
    _write_pipeline_csv(response_summary_path, _curve_bundle_summary_table(response_results, "response"))
    _write_pipeline_csv(saturation_summary_path, _curve_bundle_summary_table(saturation_results, "saturation"))
    _write_pipeline_csv(adstock_summary_path, _curve_bundle_summary_table(adstock_results, "adstock"))
    first_channel = first(grouped.spec.channel_columns)
    _alias_pipeline_artifact_path!(
        artifact_paths,
        "forward_pass_contribution_curve_plot",
        "response_curve_$(first_channel)_plot",
    )
    _alias_pipeline_artifact_path!(
        artifact_paths,
        "saturation_curve_plot",
        "saturation_curve_$(first_channel)_plot",
    )
    _alias_pipeline_artifact_path!(
        artifact_paths,
        "adstock_curve_plot",
        "adstock_curve_$(first_channel)_plot",
    )

    artifact_paths["adstock_curve"] =
        _pipeline_relative_stage_artifact("curves", "adstock_curve.jls")
    artifact_paths["adstock_curve_summary"] =
        _pipeline_relative_stage_artifact("curves", "adstock_curve_summary.csv")
    artifact_paths["forward_pass_contribution_curve"] =
        _pipeline_relative_stage_artifact("curves", "response_curve.jls")
    artifact_paths["forward_pass_contribution_curve_summary"] =
        _pipeline_relative_stage_artifact("curves", "forward_pass_contribution_curve_summary.csv")
    artifact_paths["metric_results"] =
        _pipeline_relative_stage_artifact("curves", "metric_results.jls")
    artifact_paths["curve_summary"] =
        _pipeline_relative_stage_artifact("curves", "curve_summary.csv")
    artifact_paths["metric_summary"] =
        _pipeline_relative_stage_artifact("curves", "metric_summary.csv")
    artifact_paths["saturation_curve"] =
        _pipeline_relative_stage_artifact("curves", "saturation_curve.jls")
    artifact_paths["saturation_curve_summary"] =
        _pipeline_relative_stage_artifact("curves", "saturation_curve_summary.csv")

    return (
        artifact_paths = artifact_paths,
        warnings = warnings,
    )
end

function _run_panel_curves_stage!(context::PipelineContext)
    grouped = _require_pipeline_grouped_results(context, "curves")
    grouped.observed_data isa PanelMMMData ||
        throw(ArgumentError("panel curves require grouped PanelMMMData"))

    response_results = Dict{String, ResponseCurveResults}()
    saturation_results = Dict{String, SaturationCurveResults}()
    adstock_results = Dict{String, AdstockCurveResults}()
    metric_results_by_channel = Dict{String, MetricResults}()
    curve_tables = DataFrame[]
    metric_tables = DataFrame[]
    artifact_paths = Dict{String, String}()
    warnings = String[]
    stage_dir = _stage_directory_path(context, "curves")
    delta_grid = _pipeline_panel_delta_grid(context.config.curve_points)

    for channel in grouped.spec.channel_columns
        response = response_curve_results(grouped; channel, delta_grid)
        saturation = saturation_curve_results(grouped; channel, delta_grid)
        adstock = adstock_curve_results(grouped; channel, delta_grid)
        metrics = metric_results(response)
        response_results[channel] = response
        saturation_results[channel] = saturation
        adstock_results[channel] = adstock
        metric_results_by_channel[channel] = metrics
        push!(curve_tables, _curve_family_summary_table(response, "response"))
        push!(curve_tables, _curve_family_summary_table(saturation, "saturation"))
        push!(curve_tables, _curve_family_summary_table(adstock, "adstock"))
        push!(metric_tables, summary_table(metrics))

        response_filename = "response_curve_$(channel).jls"
        saturation_filename = "saturation_curve_$(channel).jls"
        adstock_filename = "adstock_curve_$(channel).jls"
        _write_pipeline_serialized(
            joinpath(stage_dir, response_filename),
            response;
            artifact_kind = "ResponseCurveResults",
        )
        _write_pipeline_serialized(
            joinpath(stage_dir, saturation_filename),
            saturation;
            artifact_kind = "SaturationCurveResults",
        )
        _write_pipeline_serialized(
            joinpath(stage_dir, adstock_filename),
            adstock;
            artifact_kind = "AdstockCurveResults",
        )

        artifact_paths["response_curve_$(channel)"] =
            _pipeline_relative_stage_artifact("curves", response_filename)
        artifact_paths["saturation_curve_$(channel)"] =
            _pipeline_relative_stage_artifact("curves", saturation_filename)
        artifact_paths["adstock_curve_$(channel)"] =
            _pipeline_relative_stage_artifact("curves", adstock_filename)

        response_plot = "response_curve_$(channel).png"
        saturation_plot = "saturation_curve_$(channel).png"
        adstock_plot = "adstock_curve_$(channel).png"
        _save_pipeline_plot!(
            artifact_paths,
            warnings,
            "curves",
            "response_curve_$(channel)_plot",
            joinpath(stage_dir, response_plot),
            _pipeline_relative_stage_artifact("curves", response_plot),
            :panel_curve,
            response,
            "Panel response curve",
        )
        _save_pipeline_plot!(
            artifact_paths,
            warnings,
            "curves",
            "saturation_curve_$(channel)_plot",
            joinpath(stage_dir, saturation_plot),
            _pipeline_relative_stage_artifact("curves", saturation_plot),
            :panel_curve,
            saturation,
            "Panel saturation curve",
        )
        _save_pipeline_plot!(
            artifact_paths,
            warnings,
            "curves",
            "adstock_curve_$(channel)_plot",
            joinpath(stage_dir, adstock_plot),
            _pipeline_relative_stage_artifact("curves", adstock_plot),
            :panel_curve,
            adstock,
            "Panel adstock curve",
        )
    end

    metrics_path = joinpath(stage_dir, "metric_results.jls")
    curves_summary_path = joinpath(stage_dir, "curve_summary.csv")
    metrics_summary_path = joinpath(stage_dir, "metric_summary.csv")
    response_bundle_path = joinpath(stage_dir, "response_curve.jls")
    saturation_bundle_path = joinpath(stage_dir, "saturation_curve.jls")
    adstock_bundle_path = joinpath(stage_dir, "adstock_curve.jls")
    response_summary_path = joinpath(stage_dir, "forward_pass_contribution_curve_summary.csv")
    saturation_summary_path = joinpath(stage_dir, "saturation_curve_summary.csv")
    adstock_summary_path = joinpath(stage_dir, "adstock_curve_summary.csv")

    _write_pipeline_serialized(
        metrics_path,
        metric_results_by_channel;
        artifact_kind = "MetricResultsByChannel",
    )
    _write_pipeline_serialized(
        response_bundle_path,
        response_results;
        artifact_kind = "ResponseCurveResultsByChannel",
    )
    _write_pipeline_serialized(
        saturation_bundle_path,
        saturation_results;
        artifact_kind = "SaturationCurveResultsByChannel",
    )
    _write_pipeline_serialized(
        adstock_bundle_path,
        adstock_results;
        artifact_kind = "AdstockCurveResultsByChannel",
    )
    _write_pipeline_csv(curves_summary_path, reduce(vcat, curve_tables))
    _write_pipeline_csv(metrics_summary_path, reduce(vcat, metric_tables))
    _write_pipeline_csv(response_summary_path, _curve_bundle_summary_table(response_results, "response"))
    _write_pipeline_csv(saturation_summary_path, _curve_bundle_summary_table(saturation_results, "saturation"))
    _write_pipeline_csv(adstock_summary_path, _curve_bundle_summary_table(adstock_results, "adstock"))
    first_channel = first(grouped.spec.channel_columns)
    _alias_pipeline_artifact_path!(
        artifact_paths,
        "forward_pass_contribution_curve_plot",
        "response_curve_$(first_channel)_plot",
    )
    _alias_pipeline_artifact_path!(
        artifact_paths,
        "saturation_curve_plot",
        "saturation_curve_$(first_channel)_plot",
    )
    _alias_pipeline_artifact_path!(
        artifact_paths,
        "adstock_curve_plot",
        "adstock_curve_$(first_channel)_plot",
    )

    artifact_paths["adstock_curve"] =
        _pipeline_relative_stage_artifact("curves", "adstock_curve.jls")
    artifact_paths["adstock_curve_summary"] =
        _pipeline_relative_stage_artifact("curves", "adstock_curve_summary.csv")
    artifact_paths["forward_pass_contribution_curve"] =
        _pipeline_relative_stage_artifact("curves", "response_curve.jls")
    artifact_paths["forward_pass_contribution_curve_summary"] =
        _pipeline_relative_stage_artifact("curves", "forward_pass_contribution_curve_summary.csv")
    artifact_paths["metric_results"] =
        _pipeline_relative_stage_artifact("curves", "metric_results.jls")
    artifact_paths["curve_summary"] =
        _pipeline_relative_stage_artifact("curves", "curve_summary.csv")
    artifact_paths["metric_summary"] =
        _pipeline_relative_stage_artifact("curves", "metric_summary.csv")
    artifact_paths["saturation_curve"] =
        _pipeline_relative_stage_artifact("curves", "saturation_curve.jls")
    artifact_paths["saturation_curve_summary"] =
        _pipeline_relative_stage_artifact("curves", "saturation_curve_summary.csv")

    return (
        artifact_paths = artifact_paths,
        warnings = warnings,
    )
end

function _curve_family_summary_table(results, family::AbstractString)
    table = summary_table(results)
    insertcols!(
        table,
        1,
        :curve_family => fill(String(family), nrow(table)),
    )
    rename!(
        table,
        :lower_5 => :lower,
        :upper_95 => :upper,
    )
    return table
end

function _run_optimisation_stage!(context::PipelineContext)
    grouped = _require_pipeline_grouped_results(context, "optimisation")
    config = context.optimization_config
    kwargs = Dict{Symbol, Any}(:total_budget => config["total_budget"])
    for key in ("channels", "budget_bounds", "relative_bounds", "grid", "panel_allocation_mode")
        haskey(config, key) || continue
        kwargs[Symbol(key)] = config[key]
    end
    if haskey(config, "objective")
        kwargs[:objective] = Symbol(config["objective"])
    end

    result = optimize_budget(grouped; kwargs...)

    stage_dir = _stage_directory_path(context, "optimisation")
    result_path = joinpath(stage_dir, "budget_optimization_result.jls")
    impact_path = joinpath(stage_dir, "budget_impact.csv")
    audit_path = joinpath(stage_dir, "budget_bounds_audit.csv")
    plot_path = joinpath(stage_dir, "budget_optimization.png")
    budget_optimisation_path = joinpath(stage_dir, "budget_optimisation.json")
    optimize_result_path = joinpath(stage_dir, "optimize_result.json")
    optimized_allocation_path = joinpath(stage_dir, "optimized_allocation.jls")
    optimized_allocation_csv_path = joinpath(stage_dir, "optimized_allocation.csv")
    budget_summary_path = joinpath(stage_dir, "budget_summary.csv")
    budget_mroi_path = joinpath(stage_dir, "budget_mroi.csv")
    budget_roi_cpa_path = joinpath(stage_dir, "budget_roi_cpa.csv")
    budget_response_curves_path = joinpath(stage_dir, "budget_response_curves.csv")
    budget_response_points_path = joinpath(stage_dir, "budget_response_points.csv")
    response_distribution_path = joinpath(stage_dir, "response_distribution.jls")
    bounds_audit_plot_path = joinpath(stage_dir, "budget_bounds_audit.png")
    impact_plot_path = joinpath(stage_dir, "budget_impact.png")
    allocation_plot_path = joinpath(stage_dir, "budget_allocation.png")
    allocated_contribution_plot_path = joinpath(stage_dir, "allocated_contribution_by_channel_over_time.png")
    budget_mroi_plot_path = joinpath(stage_dir, "budget_roi_cpa.png")
    budget_response_curves_plot_path = joinpath(stage_dir, "budget_response_curves.png")
    panel_coordinates_path = joinpath(stage_dir, "panel_coordinates.csv")
    channel_panel_allocation_path = joinpath(stage_dir, "channel_panel_allocation.csv")
    panel_response_summary_path = joinpath(stage_dir, "panel_response_summary.csv")
    channel_delta_audit_path = joinpath(stage_dir, "channel_delta_audit.csv")

    _write_pipeline_serialized(
        result_path,
        result;
        artifact_kind = result isa PanelBudgetOptimizationResult ? "PanelBudgetOptimizationResult" : "BudgetOptimizationResult",
    )
    _write_pipeline_serialized(
        optimized_allocation_path,
        result.optimized_spend;
        artifact_kind = "OptimizedAllocation",
    )
    _write_pipeline_serialized(
        response_distribution_path,
        result;
        artifact_kind = "BudgetResponseDistribution",
    )
    impact_table = budget_impact_table(result)
    audit_table = budget_audit_table(result)
    response_points = _budget_response_points_table(result)
    _write_pipeline_csv(impact_path, impact_table)
    _write_pipeline_csv(audit_path, audit_table)
    _write_pipeline_csv(optimized_allocation_csv_path, _optimized_allocation_table(result))
    _write_pipeline_csv(budget_summary_path, _budget_summary_table(result))
    _write_pipeline_csv(budget_mroi_path, _budget_mroi_table(result))
    _write_pipeline_csv(budget_roi_cpa_path, _budget_mroi_table(result))
    _write_pipeline_csv(budget_response_curves_path, response_points)
    _write_pipeline_csv(budget_response_points_path, response_points)
    _write_pipeline_json(budget_optimisation_path, _budget_optimization_report_dict(result))
    _write_pipeline_json(optimize_result_path, _budget_optimization_report_dict(result))
    if result isa PanelBudgetOptimizationResult
        _write_pipeline_csv(panel_coordinates_path, panel_budget_coordinates_table(result))
        _write_pipeline_csv(channel_panel_allocation_path, panel_budget_allocation_table(result))
        _write_pipeline_csv(panel_response_summary_path, panel_budget_response_table(result))
        _write_pipeline_csv(channel_delta_audit_path, panel_budget_delta_audit_table(result))
    end
    artifact_paths = Dict{String, String}(
        "budget_optimization_result" => _pipeline_relative_stage_artifact("optimisation", "budget_optimization_result.jls"),
        "budget_optimisation" => _pipeline_relative_stage_artifact("optimisation", "budget_optimisation.json"),
        "budget_impact" => _pipeline_relative_stage_artifact("optimisation", "budget_impact.csv"),
        "budget_bounds_audit" => _pipeline_relative_stage_artifact("optimisation", "budget_bounds_audit.csv"),
        "budget_mroi" => _pipeline_relative_stage_artifact("optimisation", "budget_mroi.csv"),
        "budget_response_curves" => _pipeline_relative_stage_artifact("optimisation", "budget_response_curves.csv"),
        "budget_response_points" => _pipeline_relative_stage_artifact("optimisation", "budget_response_points.csv"),
        "budget_roi_cpa" => _pipeline_relative_stage_artifact("optimisation", "budget_roi_cpa.csv"),
        "budget_summary" => _pipeline_relative_stage_artifact("optimisation", "budget_summary.csv"),
        "optimize_result" => _pipeline_relative_stage_artifact("optimisation", "optimize_result.json"),
        "optimized_allocation" => _pipeline_relative_stage_artifact("optimisation", "optimized_allocation.jls"),
        "optimized_allocation_csv" => _pipeline_relative_stage_artifact("optimisation", "optimized_allocation.csv"),
        "response_distribution" => _pipeline_relative_stage_artifact("optimisation", "response_distribution.jls"),
    )
    warnings = String[]
    for (artifact_key, absolute_path, filename) in (
            ("budget_optimization_plot", plot_path, "budget_optimization.png"),
            ("budget_bounds_audit_plot", bounds_audit_plot_path, "budget_bounds_audit.png"),
            ("budget_impact_plot", impact_plot_path, "budget_impact.png"),
            ("budget_allocation_plot", allocation_plot_path, "budget_allocation.png"),
            ("allocated_contribution_plot", allocated_contribution_plot_path, "allocated_contribution_by_channel_over_time.png"),
            ("budget_roi_cpa_plot", budget_mroi_plot_path, "budget_roi_cpa.png"),
            ("budget_response_curves_plot", budget_response_curves_plot_path, "budget_response_curves.png"),
        )
        _save_pipeline_plot!(
            artifact_paths,
            warnings,
            "optimisation",
            artifact_key,
            absolute_path,
            _pipeline_relative_stage_artifact("optimisation", filename),
            :budget_optimization,
            result,
        )
    end
    if result isa PanelBudgetOptimizationResult
        merge!(
            artifact_paths,
            Dict{String, String}(
                "panel_coordinates" => _pipeline_relative_stage_artifact("optimisation", "panel_coordinates.csv"),
                "channel_panel_allocation" => _pipeline_relative_stage_artifact("optimisation", "channel_panel_allocation.csv"),
                "panel_response_summary" => _pipeline_relative_stage_artifact("optimisation", "panel_response_summary.csv"),
                "channel_delta_audit" => _pipeline_relative_stage_artifact("optimisation", "channel_delta_audit.csv"),
            ),
        )
    end

    return (
        artifact_paths = artifact_paths,
        warnings = warnings,
    )
end

function _run_preflight_stage!(context::PipelineContext)
    model = _require_pipeline_model(context, "preflight")
    data = _require_pipeline_data(context, "preflight")
    stage_dir = _stage_directory_path(context, "preflight")
    prior_predictive = _prior_predict_time_series_mmm(
        model,
        model.data;
        draws_override = context.config.prior_samples,
        chains_override = 1,
        cores_override = 1,
    )

    predictive_path = joinpath(stage_dir, "prior_predictive.jls")
    summary_path = joinpath(stage_dir, "prior_predictive_summary.csv")
    plot_path = joinpath(stage_dir, "prior_predictive.png")
    _write_pipeline_serialized(
        predictive_path,
        prior_predictive;
        artifact_kind = "PriorPredictiveChain",
    )
    _write_pipeline_csv(summary_path, _predictive_summary_table(prior_predictive))
    artifact_paths = Dict{String, String}(
        "prior_predictive" => _pipeline_relative_stage_artifact("preflight", "prior_predictive.jls"),
        "prior_predictive_summary" => _pipeline_relative_stage_artifact("preflight", "prior_predictive_summary.csv"),
    )
    warnings = String[]
    _save_pipeline_plot!(
        artifact_paths,
        warnings,
        "preflight",
        "prior_predictive_plot",
        plot_path,
        _pipeline_relative_stage_artifact("preflight", "prior_predictive.png"),
        :prior_predictive,
        prior_predictive,
        data,
        context.model_config.target_column,
    )

    return (
        artifact_paths = artifact_paths,
        warnings = warnings,
    )
end

function _run_fit_stage!(context::PipelineContext)
    model = _require_pipeline_model(context, "fit")
    stage_dir = _stage_directory_path(context, "fit")
    state = fit!(model)
    grouped = inference_results(
        model;
        include_prior = false,
        include_posterior_predictive = false,
        include_prior_predictive = false,
    )

    context.grouped_results = grouped

    model_path = joinpath(stage_dir, "model.jls")
    grouped_path = joinpath(stage_dir, "inference_results.jls")
    posterior_summary_path = joinpath(stage_dir, "posterior_summary.csv")
    trace_plot_path = joinpath(stage_dir, "trace.png")

    save_model(model_path, model)
    save_inference_results(grouped_path, grouped)
    _write_pipeline_csv(
        posterior_summary_path,
        _posterior_summary_table(model.fit_state.artifact.chain, grouped.metadata, grouped.spec),
    )
    artifact_paths = Dict{String, String}(
        "idata" => _pipeline_relative_stage_artifact("fit", "inference_results.jls"),
        "model" => _pipeline_relative_stage_artifact("fit", "model.jls"),
        "inference_results" => _pipeline_relative_stage_artifact("fit", "inference_results.jls"),
        "posterior_summary" => _pipeline_relative_stage_artifact("fit", "posterior_summary.csv"),
    )
    warnings = isempty(state.message) ? String[] : [state.message]
    _save_pipeline_plot!(
        artifact_paths,
        warnings,
        "fit",
        "trace_plot",
        trace_plot_path,
        _pipeline_relative_stage_artifact("fit", "trace.png"),
        :trace,
        grouped,
    )

    return (
        artifact_paths = artifact_paths,
        warnings = warnings,
    )
end

function _run_assessment_stage!(context::PipelineContext)
    model = _require_pipeline_model(context, "assessment")
    grouped = inference_results(
        model;
        include_prior = false,
        include_posterior_predictive = true,
        include_prior_predictive = false,
    )
    stage_dir = _stage_directory_path(context, "assessment")
    results = model_results(model)
    context.flat_results = results

    model_results_path = joinpath(stage_dir, "model_results.jls")
    observed_path = joinpath(stage_dir, "observed.csv")
    fitted_path = joinpath(stage_dir, "fitted.csv")
    residuals_path = joinpath(stage_dir, "residuals.csv")
    predictive_summary_path = joinpath(stage_dir, "predictive_summary.csv")
    posterior_predictive_path = joinpath(stage_dir, "posterior_predictive.jls")
    posterior_predictive_summary_path = joinpath(stage_dir, "posterior_predictive_summary.csv")
    posterior_predictive_plot_path = joinpath(stage_dir, "posterior_predictive.png")
    fit_timeseries_plot_path = joinpath(stage_dir, "fit_timeseries.png")
    fit_scatter_plot_path = joinpath(stage_dir, "fit_scatter.png")
    residuals_hist_plot_path = joinpath(stage_dir, "residuals_hist.png")
    residuals_timeseries_plot_path = joinpath(stage_dir, "residuals_timeseries.png")
    residuals_vs_fitted_plot_path = joinpath(stage_dir, "residuals_vs_fitted.png")
    observed_fitted_plot_path = joinpath(stage_dir, "observed_fitted.png")
    residual_diagnostics_plot_path = joinpath(stage_dir, "residual_diagnostics.png")

    save_results(model_results_path, results)

    predictive_matrix = _target_draw_matrix(results.posterior_predictive, results.spec.nobs)
    fitted_mean, fitted_lower, fitted_upper = _column_summary(predictive_matrix)
    observed = Float64.(collect(model.data.target))
    residuals = observed .- fitted_mean

    _write_pipeline_csv(observed_path, _observed_series_table(model.data.dates, observed))
    _write_pipeline_csv(
        fitted_path,
        _fitted_series_table(model.data.dates, fitted_mean, fitted_lower, fitted_upper),
    )
    _write_pipeline_csv(residuals_path, _residual_series_table(model.data.dates, residuals))
    _write_pipeline_serialized(
        posterior_predictive_path,
        results.posterior_predictive;
        artifact_kind = "PosteriorPredictiveChain",
    )
    _write_pipeline_csv(
        posterior_predictive_summary_path,
        _posterior_predictive_summary_table(
            model.data.dates,
            predictive_matrix,
            fitted_mean,
            fitted_lower,
            fitted_upper,
        ),
    )
    _write_pipeline_csv(
        predictive_summary_path,
        _metric_value_table(
            Dict{String, Float64}(
                "mae" => mean(abs.(residuals)),
                "rmse" => sqrt(mean(residuals .^ 2)),
                "bias" => mean(residuals),
                "mean_observed" => mean(observed),
                "mean_fitted" => mean(fitted_mean),
            ),
        ),
    )
    artifact_paths = Dict{String, String}(
        "model_results" => _pipeline_relative_stage_artifact("assessment", "model_results.jls"),
        "observed" => _pipeline_relative_stage_artifact("assessment", "observed.csv"),
        "fitted" => _pipeline_relative_stage_artifact("assessment", "fitted.csv"),
        "posterior_predictive" => _pipeline_relative_stage_artifact("assessment", "posterior_predictive.jls"),
        "posterior_predictive_summary" => _pipeline_relative_stage_artifact("assessment", "posterior_predictive_summary.csv"),
        "residuals" => _pipeline_relative_stage_artifact("assessment", "residuals.csv"),
        "predictive_summary" => _pipeline_relative_stage_artifact("assessment", "predictive_summary.csv"),
    )
    warnings = String[]
    for (artifact_key, absolute_path, filename, plot_kind) in (
            ("observed_fitted_plot", observed_fitted_plot_path, "observed_fitted.png", :observed_fitted),
            ("fit_timeseries_plot", fit_timeseries_plot_path, "fit_timeseries.png", :fit_timeseries),
            ("posterior_predictive_plot", posterior_predictive_plot_path, "posterior_predictive.png", :posterior_predictive),
        )
        _save_pipeline_plot!(
            artifact_paths,
            warnings,
            "assessment",
            artifact_key,
            absolute_path,
            _pipeline_relative_stage_artifact("assessment", filename),
            plot_kind,
            grouped,
        )
    end
    _save_pipeline_plot!(
        artifact_paths,
        warnings,
        "assessment",
        "fit_scatter_plot",
        fit_scatter_plot_path,
        _pipeline_relative_stage_artifact("assessment", "fit_scatter.png"),
        :fit_scatter,
        observed,
        fitted_mean,
        context.model_config.target_column,
    )
    _save_pipeline_plot!(
        artifact_paths,
        warnings,
        "assessment",
        "residual_diagnostics_plot",
        residual_diagnostics_plot_path,
        _pipeline_relative_stage_artifact("assessment", "residual_diagnostics.png"),
        :residual_diagnostics,
        grouped,
    )
    _save_pipeline_plot!(
        artifact_paths,
        warnings,
        "assessment",
        "residuals_hist_plot",
        residuals_hist_plot_path,
        _pipeline_relative_stage_artifact("assessment", "residuals_hist.png"),
        :residuals_hist,
        residuals,
    )
    _save_pipeline_plot!(
        artifact_paths,
        warnings,
        "assessment",
        "residuals_timeseries_plot",
        residuals_timeseries_plot_path,
        _pipeline_relative_stage_artifact("assessment", "residuals_timeseries.png"),
        :residuals_timeseries,
        model.data.dates,
        residuals,
    )
    _save_pipeline_plot!(
        artifact_paths,
        warnings,
        "assessment",
        "residuals_vs_fitted_plot",
        residuals_vs_fitted_plot_path,
        _pipeline_relative_stage_artifact("assessment", "residuals_vs_fitted.png"),
        :residuals_vs_fitted,
        fitted_mean,
        residuals,
    )

    return (
        artifact_paths = artifact_paths,
        warnings = warnings,
    )
end

function _run_panel_assessment_stage!(context::PipelineContext)
    model = _require_pipeline_model(context, "assessment")
    model isa PanelMMM ||
        throw(ArgumentError("panel assessment requires a PanelMMM model"))

    stage_dir = _stage_directory_path(context, "assessment")
    results = model_results(model)
    context.flat_results = results

    model_results_path = joinpath(stage_dir, "model_results.jls")
    observed_path = joinpath(stage_dir, "observed.csv")
    fitted_path = joinpath(stage_dir, "fitted.csv")
    residuals_path = joinpath(stage_dir, "residuals.csv")
    predictive_summary_path = joinpath(stage_dir, "predictive_summary.csv")
    posterior_predictive_path = joinpath(stage_dir, "posterior_predictive.jls")
    posterior_predictive_summary_path = joinpath(stage_dir, "posterior_predictive_summary.csv")
    posterior_predictive_plot_path = joinpath(stage_dir, "posterior_predictive.png")
    fit_timeseries_plot_path = joinpath(stage_dir, "fit_timeseries.png")
    fit_scatter_plot_path = joinpath(stage_dir, "fit_scatter.png")
    residuals_hist_plot_path = joinpath(stage_dir, "residuals_hist.png")
    residuals_timeseries_plot_path = joinpath(stage_dir, "residuals_timeseries.png")
    residuals_vs_fitted_plot_path = joinpath(stage_dir, "residuals_vs_fitted.png")
    observed_fitted_plot_path = joinpath(stage_dir, "observed_fitted.png")
    residual_diagnostics_plot_path = joinpath(stage_dir, "residual_diagnostics.png")

    save_results(model_results_path, results)

    predictive_matrix = _panel_target_draw_matrix(results.posterior_predictive, model.data)
    fitted_mean, fitted_lower, fitted_upper = _column_summary(predictive_matrix)
    observed = Float64.(vec(model.data.target))
    residuals = observed .- fitted_mean
    panel_dims = collect(results.spec.dims)

    _write_pipeline_csv(observed_path, _panel_observed_table(model.data, panel_dims, observed))
    _write_pipeline_csv(
        fitted_path,
        _panel_fitted_table(model.data, panel_dims, fitted_mean, fitted_lower, fitted_upper),
    )
    _write_pipeline_csv(residuals_path, _panel_residual_table(model.data, panel_dims, residuals))
    _write_pipeline_serialized(
        posterior_predictive_path,
        results.posterior_predictive;
        artifact_kind = "PosteriorPredictiveChain",
    )
    _write_pipeline_csv(
        posterior_predictive_summary_path,
        _panel_posterior_predictive_summary_table(
            model.data,
            panel_dims,
            predictive_matrix,
            fitted_mean,
            fitted_lower,
            fitted_upper,
        ),
    )
    _write_pipeline_csv(
        predictive_summary_path,
        _metric_value_table(
            Dict{String, Float64}(
                "mae" => mean(abs.(residuals)),
                "rmse" => sqrt(mean(residuals .^ 2)),
                "bias" => mean(residuals),
                "mean_observed" => mean(observed),
                "mean_fitted" => mean(fitted_mean),
                "draws" => size(predictive_matrix, 1),
                "observations" => size(predictive_matrix, 2),
                "panels" => length(model.data.panel_names),
            ),
        ),
    )

    artifact_paths = Dict{String, String}(
        "model_results" => _pipeline_relative_stage_artifact("assessment", "model_results.jls"),
        "observed" => _pipeline_relative_stage_artifact("assessment", "observed.csv"),
        "fitted" => _pipeline_relative_stage_artifact("assessment", "fitted.csv"),
        "posterior_predictive" => _pipeline_relative_stage_artifact("assessment", "posterior_predictive.jls"),
        "posterior_predictive_summary" => _pipeline_relative_stage_artifact("assessment", "posterior_predictive_summary.csv"),
        "residuals" => _pipeline_relative_stage_artifact("assessment", "residuals.csv"),
        "predictive_summary" => _pipeline_relative_stage_artifact("assessment", "predictive_summary.csv"),
    )
    warnings = String[]
    for (artifact_key, absolute_path, filename, plot_kind) in (
            ("observed_fitted_plot", observed_fitted_plot_path, "observed_fitted.png", :panel_observed_fitted),
            ("fit_timeseries_plot", fit_timeseries_plot_path, "fit_timeseries.png", :panel_fit_timeseries),
            ("posterior_predictive_plot", posterior_predictive_plot_path, "posterior_predictive.png", :panel_posterior_predictive),
        )
        _save_pipeline_plot!(
            artifact_paths,
            warnings,
            "assessment",
            artifact_key,
            absolute_path,
            _pipeline_relative_stage_artifact("assessment", filename),
            plot_kind,
            model.data,
            observed,
            fitted_mean,
            fitted_lower,
            fitted_upper,
            context.model_config.target_column,
        )
    end
    _save_pipeline_plot!(
        artifact_paths,
        warnings,
        "assessment",
        "fit_scatter_plot",
        fit_scatter_plot_path,
        _pipeline_relative_stage_artifact("assessment", "fit_scatter.png"),
        :fit_scatter,
        observed,
        fitted_mean,
        context.model_config.target_column,
    )
    _save_pipeline_plot!(
        artifact_paths,
        warnings,
        "assessment",
        "residual_diagnostics_plot",
        residual_diagnostics_plot_path,
        _pipeline_relative_stage_artifact("assessment", "residual_diagnostics.png"),
        :panel_residual_diagnostics,
        model.data,
        residuals,
        fitted_mean,
    )
    _save_pipeline_plot!(
        artifact_paths,
        warnings,
        "assessment",
        "residuals_hist_plot",
        residuals_hist_plot_path,
        _pipeline_relative_stage_artifact("assessment", "residuals_hist.png"),
        :residuals_hist,
        residuals,
    )
    _save_pipeline_plot!(
        artifact_paths,
        warnings,
        "assessment",
        "residuals_timeseries_plot",
        residuals_timeseries_plot_path,
        _pipeline_relative_stage_artifact("assessment", "residuals_timeseries.png"),
        :panel_residuals_timeseries,
        model.data,
        residuals,
    )
    _save_pipeline_plot!(
        artifact_paths,
        warnings,
        "assessment",
        "residuals_vs_fitted_plot",
        residuals_vs_fitted_plot_path,
        _pipeline_relative_stage_artifact("assessment", "residuals_vs_fitted.png"),
        :residuals_vs_fitted,
        fitted_mean,
        residuals,
    )

    return (
        artifact_paths = artifact_paths,
        warnings = warnings,
    )
end

function _load_pipeline_dataset(context::PipelineContext)
    dataset_path = _resolved_pipeline_dataset_path(context)
    isfile(dataset_path) ||
        throw(ArgumentError("run_pipeline dataset path does not exist: $dataset_path"))
    _validate_pipeline_header_names(dataset_path)

    date_column = context.model_config.date_column
    data_frame = try
        CSV.read(
            dataset_path,
            DataFrame;
            types = Dict(date_column => String),
            normalizenames = false,
        )
    catch err
        rethrow(err)
    end

    required_columns = _pipeline_required_columns(context.model_config)
    available_columns = Set(String(name) for name in names(data_frame))
    missing_columns = [name for name in required_columns if !(name in available_columns)]
    isempty(missing_columns) ||
        throw(
        ArgumentError(
            "combined CSV dataset is missing required columns: $(join(missing_columns, ", "))",
        ),
    )

    parsed_dates = _pipeline_dates(data_frame[!, date_column], date_column)
    order = sortperm(parsed_dates)
    sorted_dates = parsed_dates[order]
    length(unique(sorted_dates)) == length(sorted_dates) ||
        throw(ArgumentError("combined CSV dataset must not contain duplicate parsed dates"))

    controls = isempty(context.model_config.control_columns) ? nothing :
        _ordered_numeric_matrix(data_frame, context.model_config.control_columns, order)

    manual_event_columns = _pipeline_manual_event_columns(context.model_config)
    events = isempty(manual_event_columns) ? nothing :
        _ordered_numeric_matrix(data_frame, manual_event_columns, order)

    return MMMData(
        dates = sorted_dates,
        target = _ordered_numeric_vector(data_frame, context.model_config.target_column, order),
        channels = _ordered_numeric_matrix(data_frame, context.model_config.channel_columns, order),
        channel_names = context.model_config.channel_columns,
        controls = controls,
        control_names = context.model_config.control_columns,
        events = events,
        event_names = manual_event_columns,
    )
end

function _load_pipeline_panel_dataset(context::PipelineContext)
    dataset_path = _resolved_pipeline_dataset_path(context)
    isfile(dataset_path) ||
        throw(ArgumentError("run_pipeline dataset path does not exist: $dataset_path"))
    _validate_pipeline_header_names(dataset_path)

    date_column = context.model_config.date_column
    data_frame = CSV.read(
        dataset_path,
        DataFrame;
        types = Dict(date_column => String),
        normalizenames = false,
    )

    panel_columns = collect(context.model_config.dims)
    isempty(panel_columns) &&
        throw(ArgumentError("panel pipeline metadata requires dimensions.panel entries"))
    required_columns = _pipeline_required_columns(context.model_config)
    append!(required_columns, panel_columns)
    available_columns = Set(String(name) for name in names(data_frame))
    missing_columns = [name for name in required_columns if !(name in available_columns)]
    isempty(missing_columns) ||
        throw(
        ArgumentError(
            "combined panel CSV dataset is missing required columns: $(join(missing_columns, ", "))",
        ),
    )

    for column in panel_columns
        any(ismissing, data_frame[!, column]) &&
            throw(ArgumentError("combined panel CSV column `$column` must not contain missing values"))
    end

    parsed_dates = _pipeline_dates(data_frame[!, date_column], date_column)
    panel_coordinates = Dict{String, Vector{String}}(
        column => unique(String.(data_frame[!, column])) for column in panel_columns
    )
    panel_keys = _pipeline_panel_key_product(panel_coordinates, panel_columns)
    panel_names = [join(Tuple(key), "|") for key in panel_keys]
    date_values = sort(unique(parsed_dates))
    ntime = length(date_values)
    npanels = length(panel_names)
    nchannels = length(context.model_config.channel_columns)

    target = Matrix{Float64}(undef, ntime, npanels)
    channels = Array{Float64}(undef, ntime, nchannels, npanels)
    panel_coordinate_columns = Dict{String, Vector{String}}(
        column => String[] for column in panel_columns
    )

    for (panel_index, panel_key) in enumerate(panel_keys)
        panel_mask = trues(nrow(data_frame))
        for (column, value) in zip(panel_columns, Tuple(panel_key))
            panel_mask .&= String.(data_frame[!, column]) .== String(value)
            push!(panel_coordinate_columns[column], String(value))
        end

        panel_frame = data_frame[panel_mask, :]
        panel_dates = _pipeline_dates(panel_frame[!, date_column], date_column)
        order = sortperm(panel_dates)
        sorted_dates = panel_dates[order]
        sorted_dates == date_values ||
            throw(
            ArgumentError(
                "combined panel CSV dataset must contain identical sorted dates for each panel cell",
            ),
        )

        target[:, panel_index] = _ordered_numeric_vector(
            panel_frame,
            context.model_config.target_column,
            order,
        )
        channels[:, :, panel_index] = _ordered_numeric_matrix(
            panel_frame,
            context.model_config.channel_columns,
            order,
        )
    end

    return PanelMMMData(
        dates = date_values,
        target = target,
        channels = channels,
        panel_names = panel_names,
        channel_names = context.model_config.channel_columns,
        panel_coordinates = panel_coordinate_columns,
    )
end

function _pipeline_panel_key_product(
        panel_coordinates::Dict{String, Vector{String}},
        panel_columns,
    )
    keys = [()]
    for column in panel_columns
        keys = [(key..., value) for key in keys for value in panel_coordinates[column]]
    end
    return keys
end

function _validate_pipeline_header_names(dataset_path::AbstractString)
    header_names = _pipeline_header_names(dataset_path)
    duplicates = _duplicate_pipeline_header_names(header_names)
    isempty(duplicates) ||
        throw(
        ArgumentError(
            "combined CSV dataset must not contain duplicate header names: $(join(duplicates, ", "))",
        ),
    )
    return nothing
end

function _pipeline_header_names(dataset_path::AbstractString)
    header_frame = DataFrame(
        CSV.File(
            dataset_path;
            header = false,
            limit = 1,
            types = String,
            normalizenames = false,
        ),
    )
    nrow(header_frame) == 1 ||
        throw(ArgumentError("combined CSV dataset must contain a header row"))
    return String[String(value) for value in collect(header_frame[1, :])]
end

function _duplicate_pipeline_header_names(header_names::Vector{String})
    counts = Dict{String, Int}()
    duplicates = String[]
    for name in header_names
        counts[name] = get(counts, name, 0) + 1
        counts[name] == 2 && push!(duplicates, name)
    end
    return duplicates
end

function _validate_pipeline_validation_rows(
        data::MMMData,
        validation_config::Union{Nothing, Dict{String, Any}},
    )
    _pipeline_stage_enabled(validation_config) || return nothing
    holdout_rows = Int(validation_config["holdout_rows"])
    nobs(data) > holdout_rows ||
        throw(
        ArgumentError(
            "combined CSV dataset must contain at least holdout_rows + 1 observations when validation is enabled",
        ),
    )
    return nothing
end

function _validate_pipeline_positive_observed_channel_spend(data::MMMData)
    for (index, channel) in enumerate(data.channel_names)
        observed_total = sum(Float64.(data.channels[:, index]))
        observed_total > 0.0 ||
            throw(
            ArgumentError(
                "run_pipeline requires positive observed spend for every media channel to support Stage 60 response curves; channel `$channel` has zero observed spend",
            ),
        )
    end
    return nothing
end

function _split_validation_datasets(data::MMMData, holdout_rows::Integer)
    split_index = nobs(data) - Int(holdout_rows)
    train_slice = 1:split_index
    holdout_slice = (split_index + 1):nobs(data)
    return _mmm_data_slice(data, train_slice), _mmm_data_slice(data, holdout_slice)
end

function _mmm_data_slice(data::MMMData, rows)
    controls = isnothing(data.controls) ? nothing : data.controls[rows, :]
    events = isnothing(data.events) ? nothing : data.events[rows, :]
    return MMMData(
        dates = data.dates[rows],
        target = data.target[rows],
        channels = data.channels[rows, :],
        channel_names = data.channel_names,
        controls = controls,
        control_names = data.control_names,
        events = events,
        event_names = data.event_names,
    )
end

function _pipeline_required_columns(model_config::ModelConfig)
    required = String[
        model_config.date_column,
        model_config.target_column,
        model_config.channel_columns...,
        model_config.control_columns...,
    ]
    append!(required, _pipeline_manual_event_columns(model_config))
    return required
end

function _pipeline_manual_event_columns(model_config::ModelConfig)
    isempty(_events_windows(model_config.events)) || return String[]
    return _events_columns(model_config.events)
end

function _pipeline_dates(values, column_name::AbstractString)
    isempty(values) && throw(ArgumentError("combined CSV dataset must contain at least one row"))
    parsed = Any[_pipeline_date_value(value, column_name) for value in values]
    all(value -> value isa Date, parsed) && return Date[value for value in parsed]
    all(value -> value isa DateTime, parsed) && return DateTime[value for value in parsed]
    throw(
        ArgumentError(
            "combined CSV date column `$column_name` must parse uniformly as Date or DateTime",
        ),
    )
end

function _pipeline_date_value(value, column_name::AbstractString)
    value isa Missing &&
        throw(ArgumentError("combined CSV date column `$column_name` must not contain missing values"))
    if value isa Date || value isa DateTime
        return value
    end
    value isa AbstractString ||
        throw(
        ArgumentError(
            "combined CSV date column `$column_name` must contain ISO date or datetime strings",
        ),
    )
    string_value = strip(String(value))
    isempty(string_value) &&
        throw(ArgumentError("combined CSV date column `$column_name` must not contain empty values"))
    try
        return Date(string_value)
    catch
        try
            return DateTime(string_value)
        catch
            throw(
                ArgumentError(
                    "combined CSV date column `$column_name` must contain ISO date or datetime strings",
                ),
            )
        end
    end
end

function _ordered_numeric_vector(data_frame::DataFrame, column::AbstractString, order)
    values = data_frame[!, column]
    any(ismissing, values) &&
        throw(ArgumentError("combined CSV column `$column` must not contain missing values"))
    all(value -> value isa Real && isfinite(Float64(value)), values) ||
        throw(
        ArgumentError(
            "combined CSV column `$column` must contain finite numeric values only",
        ),
    )
    numeric = Float64.(values)
    return numeric[order]
end

function _ordered_numeric_matrix(data_frame::DataFrame, columns::Vector{String}, order)
    matrix = Matrix{Float64}(undef, nrow(data_frame), length(columns))
    for (index, column) in enumerate(columns)
        matrix[:, index] = _ordered_numeric_vector(data_frame, column, 1:nrow(data_frame))
    end
    return matrix[order, :]
end

function _pipeline_data_manifest(data::MMMData, model_config::ModelConfig)
    manifest = _pipeline_data_manifest(model_config)
    manifest["n_rows"] = nobs(data)
    manifest["date_type"] = string(nameof(eltype(data.dates)))
    manifest["date_min"] = string(first(data.dates))
    manifest["date_max"] = string(last(data.dates))
    return manifest
end

function _pipeline_data_manifest(data::PanelMMMData, model_config::ModelConfig)
    manifest = _pipeline_data_manifest(model_config)
    manifest["n_rows"] = nobs(data)
    manifest["n_time"] = length(data.dates)
    manifest["n_panels"] = length(data.panel_names)
    manifest["panel_names"] = copy(data.panel_names)
    manifest["panel_coordinates"] = deepcopy(data.panel_coordinates)
    manifest["date_type"] = string(nameof(eltype(data.dates)))
    manifest["date_min"] = string(first(data.dates))
    manifest["date_max"] = string(last(data.dates))
    return manifest
end

function _resolved_pipeline_dataset_path(context::PipelineContext)
    dataset_path = context.dataset_path
    isabspath(dataset_path) && return dataset_path
    return normpath(joinpath(dirname(abspath(context.config.config_path)), dataset_path))
end

function _require_pipeline_data(context::PipelineContext, stage::AbstractString)
    isnothing(context.data) &&
        throw(ArgumentError("pipeline stage `$stage` requires loaded MMMData"))
    return context.data
end

function _require_pipeline_model(context::PipelineContext, stage::AbstractString)
    isnothing(context.model) &&
        throw(ArgumentError("pipeline stage `$stage` requires a loaded TimeSeriesMMM model"))
    return context.model
end

function _require_pipeline_grouped_results(context::PipelineContext, stage::AbstractString)
    isnothing(context.grouped_results) &&
        throw(ArgumentError("pipeline stage `$stage` requires grouped InferenceResults"))
    return context.grouped_results
end

function _write_pipeline_csv(path::AbstractString, table)
    mkpath(dirname(path))
    CSV.write(path, table)
    return path
end

function _pipeline_serialized_artifact_payload(value; artifact_kind::AbstractString)
    return (
        schema_version = _PIPELINE_SERIALIZED_ARTIFACT_SCHEMA_VERSION,
        artifact_kind = String(artifact_kind),
        metadata = Dict{String, Any}(
            "epsilon_version" => string(pkgversion(@__MODULE__)),
            "julia_version" => string(VERSION),
            "created_at_utc" => _pipeline_timestamp_utc(),
        ),
        artifact = value,
    )
end

function _write_pipeline_serialized(path::AbstractString, value; artifact_kind::AbstractString)
    mkpath(dirname(path))
    open(path, "w") do io
        serialize(io, _pipeline_serialized_artifact_payload(value; artifact_kind))
    end
    return path
end

function _load_pipeline_serialized(
        path::AbstractString;
        expected_kind::Union{Nothing, AbstractString} = nothing,
    )
    payload = open(deserialize, path)
    payload isa NamedTuple ||
        throw(ArgumentError("serialized pipeline artifact payload must be a named tuple"))
    get(payload, :schema_version, nothing) == _PIPELINE_SERIALIZED_ARTIFACT_SCHEMA_VERSION ||
        throw(ArgumentError("unsupported pipeline artifact schema version"))

    artifact_kind = get(payload, :artifact_kind, nothing)
    artifact_kind isa AbstractString ||
        throw(ArgumentError("serialized pipeline artifact payload must include artifact_kind"))
    if !isnothing(expected_kind) && artifact_kind != String(expected_kind)
        throw(
            ArgumentError(
                "serialized pipeline artifact kind `$artifact_kind` does not match expected `$(String(expected_kind))`",
            ),
        )
    end

    metadata = get(payload, :metadata, nothing)
    metadata isa AbstractDict ||
        throw(ArgumentError("serialized pipeline artifact payload must include metadata"))
    for key in ("epsilon_version", "julia_version", "created_at_utc")
        haskey(metadata, key) ||
            throw(
            ArgumentError(
                "serialized pipeline artifact metadata must include $key",
            ),
        )
    end
    hasproperty(payload, :artifact) ||
        throw(ArgumentError("serialized pipeline artifact payload must include artifact"))
    return payload.artifact
end

function _spec_summary_table(spec::MMMModelSpec)
    return DataFrame(;
        model_kind = [String(spec.model_kind)],
        nobs = [spec.nobs],
        nchannels = [spec.nchannels],
        ncontrols = [spec.ncontrols],
        target_column = [spec.target_column],
        target_type = [spec.target_type],
        observation_dim = [spec.coordinate_metadata.observation_dim],
    )
end

function _push_data_dictionary_row!(
        columns::Vector{String},
        roles::Vector{String},
        dtypes::Vector{String},
        sources::Vector{String},
        column::AbstractString,
        role::AbstractString,
        dtype,
    )
    push!(columns, String(column))
    push!(roles, String(role))
    push!(dtypes, string(dtype))
    push!(sources, "input_csv")
    return nothing
end

function _data_dictionary_table(data::MMMData, config::ModelConfig)
    columns = String[]
    roles = String[]
    dtypes = String[]
    sources = String[]

    _push_data_dictionary_row!(
        columns,
        roles,
        dtypes,
        sources,
        config.date_column,
        "date",
        eltype(data.dates),
    )
    _push_data_dictionary_row!(
        columns,
        roles,
        dtypes,
        sources,
        config.target_column,
        "target",
        eltype(data.target),
    )
    for channel in config.channel_columns
        _push_data_dictionary_row!(
            columns,
            roles,
            dtypes,
            sources,
            channel,
            "media",
            eltype(data.channels),
        )
    end
    for control in config.control_columns
        _push_data_dictionary_row!(
            columns,
            roles,
            dtypes,
            sources,
            control,
            "control",
            isnothing(data.controls) ? Float64 : eltype(data.controls),
        )
    end
    for event in data.event_names
        _push_data_dictionary_row!(
            columns,
            roles,
            dtypes,
            sources,
            event,
            "event",
            isnothing(data.events) ? Float64 : eltype(data.events),
        )
    end

    return DataFrame(;
        column = columns,
        role = roles,
        dtype = dtypes,
        source = sources,
    )
end

function _data_dictionary_table(data::PanelMMMData, config::ModelConfig)
    columns = String[]
    roles = String[]
    dtypes = String[]
    sources = String[]

    _push_data_dictionary_row!(
        columns,
        roles,
        dtypes,
        sources,
        config.date_column,
        "date",
        eltype(data.dates),
    )
    for dim in config.dims
        _push_data_dictionary_row!(
            columns,
            roles,
            dtypes,
            sources,
            dim,
            "panel",
            String,
        )
    end
    _push_data_dictionary_row!(
        columns,
        roles,
        dtypes,
        sources,
        config.target_column,
        "target",
        eltype(data.target),
    )
    for channel in config.channel_columns
        _push_data_dictionary_row!(
            columns,
            roles,
            dtypes,
            sources,
            channel,
            "media",
            eltype(data.channels),
        )
    end

    return DataFrame(;
        column = columns,
        role = roles,
        dtype = dtypes,
        source = sources,
    )
end

function _design_matrix_manifest_table(spec::MMMModelSpec, data::MMMData)
    rows = NamedTuple[]
    push!(
        rows,
        (
            feature_group = "target",
            feature = spec.target_column,
            source = "input_csv",
            n_rows = spec.nobs,
            n_columns = 1,
        ),
    )
    for channel in spec.channel_columns
        push!(
            rows,
            (
                feature_group = "media",
                feature = channel,
                source = "input_csv",
                n_rows = spec.nobs,
                n_columns = 1,
            ),
        )
    end
    for control in spec.control_columns
        push!(
            rows,
            (
                feature_group = "control",
                feature = control,
                source = "input_csv",
                n_rows = spec.nobs,
                n_columns = 1,
            ),
        )
    end
    for event in data.event_names
        push!(
            rows,
            (
                feature_group = "event",
                feature = event,
                source = "input_csv",
                n_rows = spec.nobs,
                n_columns = 1,
            ),
        )
    end
    holiday_columns = _holidays_columns(spec.holidays)
    for holiday_column in holiday_columns
        push!(
            rows,
            (
                feature_group = "holiday",
                feature = holiday_column,
                source = "holidays",
                n_rows = spec.nobs,
                n_columns = 1,
            ),
        )
    end
    if _seasonality_type(spec.seasonality) === :fourier
        n_order = Int(spec.seasonality["n_order"])
        push!(
            rows,
            (
                feature_group = "seasonality",
                feature = "yearly_fourier",
                source = "date",
                n_rows = spec.nobs,
                n_columns = 2 * n_order,
            ),
        )
    end

    return DataFrame(rows)
end

function _design_matrix_manifest_table(spec::MMMModelSpec, data::PanelMMMData)
    rows = NamedTuple[]
    push!(
        rows,
        (
            feature_group = "target",
            feature = spec.target_column,
            source = "input_csv",
            n_rows = spec.nobs,
            n_columns = 1,
        ),
    )
    for dim in spec.dims
        push!(
            rows,
            (
                feature_group = "panel",
                feature = dim,
                source = "input_csv",
                n_rows = spec.nobs,
                n_columns = 1,
            ),
        )
    end
    for channel in spec.channel_columns
        push!(
            rows,
            (
                feature_group = "media",
                feature = channel,
                source = "input_csv",
                n_rows = spec.nobs,
                n_columns = 1,
            ),
        )
    end
    holiday_columns = _holidays_columns(spec.holidays)
    for holiday_column in holiday_columns
        push!(
            rows,
            (
                feature_group = "holiday",
                feature = holiday_column,
                source = "holidays",
                n_rows = spec.nobs,
                n_columns = 1,
            ),
        )
    end
    if _seasonality_type(spec.seasonality) === :fourier
        n_order = Int(spec.seasonality["n_order"])
        push!(
            rows,
            (
                feature_group = "seasonality",
                feature = "yearly_fourier",
                source = "date",
                n_rows = spec.nobs,
                n_columns = 2 * n_order,
            ),
        )
    end

    return DataFrame(rows)
end

function _holiday_feature_manifest_table(spec::MMMModelSpec)
    dates = String[]
    holidays = String[]
    countries = String[]
    years = Int[]
    features = String[]
    modes = String[]
    for row in _holiday_rows(spec.holidays)
        push!(dates, string(row.date))
        push!(holidays, row.holiday)
        push!(countries, row.country)
        push!(years, row.year)
        push!(features, "holiday")
        push!(modes, String(_holidays_mode(spec.holidays)))
    end
    return DataFrame(;
        feature = features,
        mode = modes,
        holiday = holidays,
        country = countries,
        date = dates,
        year = years,
    )
end

function _pipeline_session_info(context::PipelineContext, spec::MMMModelSpec)
    lines = String[
        "Epsilon.jl session information",
        "epsilon_version: $(pkgversion(@__MODULE__))",
        "julia_version: $(VERSION)",
        "run_name: $(context.run_name)",
        "model_type: $(_pipeline_model_type(context.model_config))",
        "target_type: $(spec.target_type)",
        "nobs: $(spec.nobs)",
        "nchannels: $(spec.nchannels)",
        "created_at_utc: $(_pipeline_timestamp_utc())",
    ]
    if !isempty(spec.dims)
        push!(lines, "panel_dims: $(join(spec.dims, ","))")
    end
    return join(lines, "\n") * "\n"
end

function _posterior_summary_table(chain, metadata::ModelArtifactMetadata, spec::MMMModelSpec)
    diagnostics = try
        model_diagnostics(
            ModelResults(
                metadata,
                spec,
                chain;
                posterior_predictive = nothing,
                prior_predictive = nothing,
            ),
        )
    catch
        nothing
    end

    parameter_names = Symbol.(names(chain, :parameters))
    rows = NamedTuple[]
    for name in parameter_names
        draws = _flatten_chain_values(chain[name])
        diag = isnothing(diagnostics) ? nothing : get(diagnostics.parameter_diagnostics, String(name), nothing)
        push!(
            rows,
            (
                parameter = String(name),
                mean = mean(draws),
                sd = std(draws),
                median = median(draws),
                q05 = quantile(draws, 0.05),
                q95 = quantile(draws, 0.95),
                rhat = isnothing(diag) ? missing : diag.rhat,
                ess_bulk = isnothing(diag) ? missing : diag.ess_bulk,
                ess_tail = isnothing(diag) ? missing : diag.ess_tail,
            ),
        )
    end
    return DataFrame(rows)
end

function _predictive_summary_table(chain)
    target_names = filter(
        name -> startswith(String(name), "target["),
        Symbol.(names(chain, :parameters)),
    )
    isempty(target_names) && (target_names = Symbol.(names(chain, :parameters)))
    matrix = _chain_matrix(chain[target_names], length(target_names))
    return _metric_value_table(
        Dict{String, Float64}(
            "draws" => size(matrix, 1),
            "observations" => size(matrix, 2),
            "overall_mean" => mean(matrix),
            "overall_sd" => std(vec(matrix)),
        ),
    )
end

function _observed_series_table(dates, observed::AbstractVector)
    return DataFrame(; observation = collect(eachindex(observed)), date = collect(dates), observed)
end

function _fitted_series_table(dates, mean_values, lower_values, upper_values)
    return DataFrame(;
        observation = collect(eachindex(mean_values)),
        date = collect(dates),
        mean = mean_values,
        lower_5 = lower_values,
        upper_95 = upper_values,
    )
end

function _residual_series_table(dates, residuals)
    return DataFrame(;
        observation = collect(eachindex(residuals)),
        date = collect(dates),
        residual = residuals,
    )
end

function _posterior_predictive_summary_table(
        dates,
        predictive_matrix::AbstractMatrix,
        mean_values,
        lower_values,
        upper_values,
    )
    return DataFrame(;
        observation = axes(predictive_matrix, 2),
        date = collect(dates),
        mean = mean_values,
        lower_5 = lower_values,
        upper_95 = upper_values,
        draw_sd = vec(std(predictive_matrix; dims = 1)),
    )
end

function _panel_base_observation_table(data::PanelMMMData, panel_dims::AbstractVector{<:AbstractString})
    ntime, npanels = size(data.target)
    table = DataFrame(;
        observation = collect(1:(ntime * npanels)),
        date = repeat(collect(data.dates), npanels),
        panel = repeat(data.panel_names, inner = ntime),
    )
    for dim in panel_dims
        coordinates = get(data.panel_coordinates, String(dim), data.panel_names)
        table[!, Symbol(dim)] = repeat(coordinates, inner = ntime)
    end
    return table
end

function _panel_observed_table(
        data::PanelMMMData,
        panel_dims::AbstractVector{<:AbstractString},
        observed::AbstractVector,
    )
    table = _panel_base_observation_table(data, panel_dims)
    table.observed = observed
    return table
end

function _panel_fitted_table(
        data::PanelMMMData,
        panel_dims::AbstractVector{<:AbstractString},
        mean_values::AbstractVector,
        lower_values::AbstractVector,
        upper_values::AbstractVector,
    )
    table = _panel_base_observation_table(data, panel_dims)
    table.mean = mean_values
    table.lower_5 = lower_values
    table.upper_95 = upper_values
    return table
end

function _panel_residual_table(
        data::PanelMMMData,
        panel_dims::AbstractVector{<:AbstractString},
        residuals::AbstractVector,
    )
    table = _panel_base_observation_table(data, panel_dims)
    table.residual = residuals
    return table
end

function _panel_posterior_predictive_summary_table(
        data::PanelMMMData,
        panel_dims::AbstractVector{<:AbstractString},
        predictive_matrix::AbstractMatrix,
        mean_values::AbstractVector,
        lower_values::AbstractVector,
        upper_values::AbstractVector,
    )
    table = _panel_base_observation_table(data, panel_dims)
    table.mean = mean_values
    table.lower_5 = lower_values
    table.upper_95 = upper_values
    table.draw_sd = vec(std(predictive_matrix; dims = 1))
    return table
end

function _metric_value_table(metrics::Dict{String, Float64})
    ordered = sort(collect(metrics); by = first)
    return DataFrame(; metric = first.(ordered), value = last.(ordered))
end

function _holdout_predictive_report_dict(
        validation::PipelineValidationResult,
        predictive_matrix::AbstractMatrix,
    )
    return Dict{String, Any}(
        "holdout_rows" => validation.holdout_rows,
        "train_date_start" => validation.train_date_start,
        "train_date_end" => validation.train_date_end,
        "holdout_date_start" => validation.holdout_date_start,
        "holdout_date_end" => validation.holdout_date_end,
        "metrics" => validation.metrics,
        "draws" => size(predictive_matrix, 1),
        "observations" => size(predictive_matrix, 2),
    )
end

function _component_partition_table(table::DataFrame, media::Bool)
    mask = [startswith(String(component), "media:") for component in table.component]
    return table[media ? mask : .!mask, :]
end

function _curve_bundle_summary_table(results::Dict{String, T}, family::AbstractString) where {T}
    ordered_channels = sort(collect(keys(results)))
    return reduce(vcat, [_curve_family_summary_table(results[channel], family) for channel in ordered_channels])
end

function _diagnostics_report_table(diagnostics::ModelDiagnostics)
    rows = NamedTuple[]
    for parameter in sort(collect(keys(diagnostics.parameter_diagnostics)))
        values = diagnostics.parameter_diagnostics[parameter]
        push!(
            rows,
            (
                parameter = parameter,
                rhat = values.rhat,
                ess_bulk = values.ess_bulk,
                ess_tail = values.ess_tail,
                mcse_mean = values.mcse_mean,
            ),
        )
    end
    return DataFrame(rows)
end

function _sampler_summary_table(sampler::SamplerDiagnostics)
    return _metric_value_table(
        Dict{String, Float64}(
            "numerical_error_count" => sampler.numerical_error_count,
            "numerical_error_rate" => sampler.numerical_error_rate,
            "mean_abs_hamiltonian_energy_error" => sampler.mean_abs_hamiltonian_energy_error,
            "max_abs_hamiltonian_energy_error" => sampler.max_abs_hamiltonian_energy_error,
            "max_abs_max_hamiltonian_energy_error" => sampler.max_abs_max_hamiltonian_energy_error,
            "max_tree_depth" => sampler.max_tree_depth,
            "mean_tree_depth" => sampler.mean_tree_depth,
            "max_n_steps" => sampler.max_n_steps,
            "mean_n_steps" => sampler.mean_n_steps,
            "mean_acceptance_rate" => sampler.mean_acceptance_rate,
            "mean_step_size" => sampler.mean_step_size,
        ),
    )
end

function _chain_diagnostics_text(
        diagnostics::ModelDiagnostics,
        sampler::SamplerDiagnostics,
        report::ConvergenceReport,
    )
    lines = String[
        "Epsilon.jl chain diagnostics",
        "parameters: $(length(diagnostics.parameter_diagnostics))",
        "convergence_issues: $(length(report.issues))",
        "numerical_error_count: $(sampler.numerical_error_count)",
        "numerical_error_rate: $(sampler.numerical_error_rate)",
        "max_tree_depth: $(sampler.max_tree_depth)",
        "mean_acceptance_rate: $(sampler.mean_acceptance_rate)",
    ]
    return join(lines, "\n") * "\n"
end

function _diagnostics_summary_text(
        sampler_warnings::SamplerWarnings,
        convergence_warnings::ConvergenceWarnings,
    )
    lines = String[
        "Epsilon.jl diagnostics summary",
        "sampler_warning_count: $(sampler_warnings.summary.nwarnings)",
        "convergence_warning_count: $(convergence_warnings.summary.nwarnings)",
        "has_sampler_warnings: $(has_sampler_warnings(sampler_warnings))",
        "has_convergence_warnings: $(has_convergence_warnings(convergence_warnings))",
    ]
    return join(lines, "\n") * "\n"
end

function _design_report_dict(model::TimeSeriesMMM)
    spec = build_model(model)
    return Dict{String, Any}(
        "model_type" => "TimeSeriesMMM",
        "nobs" => spec.nobs,
        "nchannels" => spec.nchannels,
        "ncontrols" => spec.ncontrols,
        "target_column" => spec.target_column,
        "channel_columns" => spec.channel_columns,
        "control_columns" => spec.control_columns,
        "target_scale" => spec.target_scale,
        "channel_scale" => spec.channel_scale,
    )
end

function _design_report_dict(model::PanelMMM)
    spec = build_model(model)
    ntime, npanels = size(model.data.target)
    return Dict{String, Any}(
        "model_type" => "PanelMMM",
        "nobs" => spec.nobs,
        "n_time" => ntime,
        "n_panels" => npanels,
        "panel_dims" => spec.dims,
        "panel_names" => model.data.panel_names,
        "nchannels" => spec.nchannels,
        "ncontrols" => spec.ncontrols,
        "target_column" => spec.target_column,
        "channel_columns" => spec.channel_columns,
        "control_columns" => spec.control_columns,
        "target_scale" => spec.target_scale,
        "channel_scale" => spec.channel_scale,
    )
end

function _design_summary_table(model::TimeSeriesMMM)
    return _design_matrix_manifest_table(build_model(model), model.data)
end

function _design_summary_table(model::PanelMMM)
    return _design_matrix_manifest_table(build_model(model), model.data)
end

function _mcmc_report_dict(sampler::SamplerDiagnostics, report::ConvergenceReport)
    return Dict{String, Any}(
        "sampler" => Dict{String, Any}(
            "numerical_error_count" => sampler.numerical_error_count,
            "numerical_error_rate" => sampler.numerical_error_rate,
            "max_tree_depth" => sampler.max_tree_depth,
            "mean_acceptance_rate" => sampler.mean_acceptance_rate,
            "mean_step_size" => sampler.mean_step_size,
        ),
        "convergence" => _convergence_report_dict(report),
    )
end

function _pipeline_residual_vector(results::Union{Nothing, ModelResults}, data::MMMData)
    isnothing(results) && return Float64[]
    predictive_matrix = _target_draw_matrix(results.posterior_predictive, results.spec.nobs)
    fitted_mean, _, _ = _column_summary(predictive_matrix)
    return Float64.(collect(data.target)) .- fitted_mean
end

function _pipeline_residual_vector(results::Union{Nothing, ModelResults}, data::PanelMMMData)
    isnothing(results) && return Float64[]
    predictive_matrix = _panel_target_draw_matrix(results.posterior_predictive, data)
    fitted_mean, _, _ = _column_summary(predictive_matrix)
    return Float64.(vec(data.target)) .- fitted_mean
end

function _pipeline_predictive_summary_table(results::Union{Nothing, ModelResults}, data::MMMData)
    isnothing(results) && return _metric_value_table(Dict{String, Float64}())
    predictive_matrix = _target_draw_matrix(results.posterior_predictive, results.spec.nobs)
    residuals = _pipeline_residual_vector(results, data)
    return _metric_value_table(
        Dict{String, Float64}(
            "draws" => size(predictive_matrix, 1),
            "observations" => size(predictive_matrix, 2),
            "mae" => mean(abs.(residuals)),
            "rmse" => sqrt(mean(residuals .^ 2)),
            "bias" => mean(residuals),
        ),
    )
end

function _pipeline_predictive_summary_table(results::Union{Nothing, ModelResults}, data::PanelMMMData)
    isnothing(results) && return _metric_value_table(Dict{String, Float64}())
    predictive_matrix = _panel_target_draw_matrix(results.posterior_predictive, data)
    residuals = _pipeline_residual_vector(results, data)
    return _metric_value_table(
        Dict{String, Float64}(
            "draws" => size(predictive_matrix, 1),
            "observations" => size(predictive_matrix, 2),
            "panels" => length(data.panel_names),
            "mae" => mean(abs.(residuals)),
            "rmse" => sqrt(mean(residuals .^ 2)),
            "bias" => mean(residuals),
        ),
    )
end

function _predictive_report_dict(results::Union{Nothing, ModelResults}, data::MMMData)
    if isnothing(results)
        return Dict{String, Any}("available" => false)
    end
    predictive_matrix = _target_draw_matrix(results.posterior_predictive, results.spec.nobs)
    residuals = _pipeline_residual_vector(results, data)
    return Dict{String, Any}(
        "available" => true,
        "draws" => size(predictive_matrix, 1),
        "observations" => size(predictive_matrix, 2),
        "metrics" => Dict{String, Float64}(
            "mae" => mean(abs.(residuals)),
            "rmse" => sqrt(mean(residuals .^ 2)),
            "bias" => mean(residuals),
        ),
    )
end

function _predictive_report_dict(results::Union{Nothing, ModelResults}, data::PanelMMMData)
    if isnothing(results)
        return Dict{String, Any}("available" => false)
    end
    predictive_matrix = _panel_target_draw_matrix(results.posterior_predictive, data)
    residuals = _pipeline_residual_vector(results, data)
    ntime, npanels = size(data.target)
    return Dict{String, Any}(
        "available" => true,
        "draws" => size(predictive_matrix, 1),
        "observations" => size(predictive_matrix, 2),
        "n_time" => ntime,
        "n_panels" => npanels,
        "panel_names" => data.panel_names,
        "metrics" => Dict{String, Float64}(
            "mae" => mean(abs.(residuals)),
            "rmse" => sqrt(mean(residuals .^ 2)),
            "bias" => mean(residuals),
        ),
    )
end

function _pipeline_residual_diagnostics_table(results::Union{Nothing, ModelResults}, data::MMMData)
    residuals = _pipeline_residual_vector(results, data)
    isempty(residuals) && return _metric_value_table(Dict{String, Float64}())
    return _metric_value_table(
        Dict{String, Float64}(
            "mean" => mean(residuals),
            "sd" => std(residuals),
            "min" => minimum(residuals),
            "max" => maximum(residuals),
            "lag1_acf" => _lag_autocorrelation(residuals, 1),
        ),
    )
end

function _pipeline_residual_diagnostics_table(results::Union{Nothing, ModelResults}, data::PanelMMMData)
    residuals = _pipeline_residual_vector(results, data)
    isempty(residuals) && return _metric_value_table(Dict{String, Float64}())
    ntime, npanels = size(data.target)
    panel_means = [
        mean(view(residuals, ((panel - 1) * ntime + 1):(panel * ntime))) for panel in 1:npanels
    ]
    return _metric_value_table(
        Dict{String, Float64}(
            "mean" => mean(residuals),
            "sd" => std(residuals),
            "min" => minimum(residuals),
            "max" => maximum(residuals),
            "lag1_acf" => _lag_autocorrelation(residuals, 1),
            "panel_mean_abs_residual" => mean(abs.(panel_means)),
            "panels" => npanels,
            "time_periods" => ntime,
        ),
    )
end

function _vif_report_table(data::MMMData)
    feature_names = vcat(data.channel_names, data.control_names)
    return DataFrame(;
        feature = feature_names,
        vif = fill(1.0, length(feature_names)),
        note = fill("not_estimated_for_bounded_pipeline", length(feature_names)),
    )
end

function _vif_report_table(data::PanelMMMData)
    feature_names = data.channel_names
    return DataFrame(;
        feature = feature_names,
        vif = fill(1.0, length(feature_names)),
        note = fill("not_estimated_for_bounded_panel_pipeline", length(feature_names)),
    )
end

function _lag_autocorrelation(values::AbstractVector, lag::Integer)
    n = length(values)
    lag_value = Int(lag)
    n > lag_value || return NaN
    centered = Float64.(values) .- mean(values)
    denominator = sum(abs2, centered)
    isapprox(denominator, 0.0; atol = sqrt(eps(Float64))) && return NaN
    numerator = sum(centered[(lag_value + 1):end] .* centered[1:(end - lag_value)])
    return numerator / denominator
end

function _optimized_allocation_table(result::_BudgetOptimizationResultLike)
    return DataFrame(;
        channel = result.spec.channel_columns,
        current_spend = [result.current_spend[channel] for channel in result.spec.channel_columns],
        optimized_spend = [result.optimized_spend[channel] for channel in result.spec.channel_columns],
    )
end

function _budget_summary_table(result::_BudgetOptimizationResultLike)
    return _metric_value_table(
        Dict{String, Float64}(
            "current_response" => result.current_response,
            "optimized_response" => result.optimized_response,
            "response_delta" => result.optimized_response - result.current_response,
            "current_total_spend" => sum(values(result.current_spend)),
            "optimized_total_spend" => sum(values(result.optimized_spend)),
            "current_default_efficiency" => result.current_default_efficiency,
            "optimized_default_efficiency" => result.optimized_default_efficiency,
        ),
    )
end

function _budget_mroi_table(result::_BudgetOptimizationResultLike)
    impact = budget_impact_table(result)
    response_delta = result.optimized_response - result.current_response
    total_delta = sum(abs, impact.spend_delta)
    mroi = _safe_metric_ratio(response_delta, total_delta)
    return DataFrame(;
        channel = impact.channel,
        spend_delta = impact.spend_delta,
        response_delta = fill(response_delta, length(impact.channel)),
        mroi = fill(mroi, length(impact.channel)),
        roi = fill(result.optimized_default_efficiency, length(impact.channel)),
        cpa = fill(_safe_metric_ratio(sum(values(result.optimized_spend)), result.optimized_response), length(impact.channel)),
    )
end

function _budget_response_points_table(result::_BudgetOptimizationResultLike)
    return DataFrame(;
        scenario = ["current", "optimized"],
        total_spend = [sum(values(result.current_spend)), sum(values(result.optimized_spend))],
        response = [result.current_response, result.optimized_response],
        default_efficiency = [result.current_default_efficiency, result.optimized_default_efficiency],
    )
end

function _budget_optimization_report_dict(result::_BudgetOptimizationResultLike)
    report = Dict{String, Any}(
        "objective" => String(result.objective),
        "solver_status" => String(result.solver_status),
        "objective_value" => result.objective_value,
        "current_response" => result.current_response,
        "optimized_response" => result.optimized_response,
        "current_spend" => result.current_spend,
        "optimized_spend" => result.optimized_spend,
        "optimized_channels" => result.optimized_channels,
        "fixed_channels" => result.fixed_channels,
        "convergence_metadata" => result.convergence_metadata,
    )
    if result isa PanelBudgetOptimizationResult
        report["panel_allocation_mode"] = String(result.panel_allocation_mode)
        report["channel_delta"] = result.channel_delta
    end
    return report
end

function _pipeline_curve_grid(
        grouped::InferenceResults,
        channel::AbstractString,
        npoints::Integer,
    )
    data = _require_postmodel_time_series_results(grouped, "run_pipeline Stage 60")
    index = grouped.spec.channel_indices[String(channel)]
    observed_total = sum(Float64.(data.channels[:, index]))
    observed_total > 0.0 ||
        throw(
        ArgumentError(
            "run_pipeline Stage 60 requires positive observed spend for channel `$channel`",
        ),
    )
    return collect(range(0.0, stop = observed_total, length = Int(npoints)))
end

function _pipeline_panel_delta_grid(npoints::Integer)
    return collect(range(0.0, stop = 2.0, length = Int(npoints)))
end

function _convergence_report_dict(report::ConvergenceReport)
    return Dict{String, Any}(
        "summary" => Dict{String, Any}(string(key) => value for (key, value) in pairs(report.summary)),
        "issues" => [
            Dict{String, Any}(
                    "parameter" => issue.parameter,
                    "metric" => String(issue.metric),
                    "value" => issue.value,
                    "threshold" => issue.threshold,
                ) for issue in report.issues
        ],
    )
end

function _sampler_warnings_dict(bundle::SamplerWarnings)
    return Dict{String, Any}(
        "summary" => Dict{String, Any}(string(key) => value for (key, value) in pairs(bundle.summary)),
        "warnings" => [
            Dict{String, Any}(
                    "metric" => String(warning.metric),
                    "severity" => String(warning.severity),
                    "value" => warning.value,
                    "threshold" => warning.threshold,
                    "message" => warning.message,
                ) for warning in bundle.warnings
        ],
    )
end

function _convergence_warnings_dict(bundle::ConvergenceWarnings)
    return Dict{String, Any}(
        "summary" => Dict{String, Any}(string(key) => value for (key, value) in pairs(bundle.summary)),
        "warnings" => [
            Dict{String, Any}(
                    "parameter" => warning.parameter,
                    "metric" => String(warning.metric),
                    "severity" => String(warning.severity),
                    "message" => warning.message,
                ) for warning in bundle.warnings
        ],
    )
end

function _target_draw_matrix(chain, nobs::Integer)
    parameter_names = [Symbol("target[$index]") for index in 1:nobs]
    return _chain_matrix(chain[parameter_names], nobs)
end

function _panel_target_draw_matrix(chain, data::PanelMMMData)
    ntime, npanels = size(data.target)
    parameter_names = collect(names(chain, :parameters))
    indexed_names = Tuple{Int, Symbol}[]
    for name in parameter_names
        captures = match(r"^target\[(\d+),\s*(\d+)\]$", String(name))
        isnothing(captures) && continue
        time_index = parse(Int, captures.captures[1])
        panel_index = parse(Int, captures.captures[2])
        1 <= time_index <= ntime && 1 <= panel_index <= npanels || continue
        linear_index = LinearIndices((ntime, npanels))[time_index, panel_index]
        push!(indexed_names, (linear_index, Symbol(name)))
    end
    length(indexed_names) == ntime * npanels ||
        throw(
        ArgumentError(
            "panel posterior predictive chain must contain target[time,panel] draws for every panel observation",
        ),
    )
    ordered_names = last.(sort(indexed_names; by = first))
    return _chain_matrix(chain[ordered_names], ntime * npanels)
end

function _chain_matrix(chain, ncolumns::Integer)
    values = Array(chain)
    if ndims(values) == 1
        return reshape(Float64.(values), :, 1)
    elseif ndims(values) == 2
        return Float64.(values)
    elseif ndims(values) == 3
        return reshape(Float64.(values), size(values, 1) * size(values, 3), ncolumns)
    end
    throw(ArgumentError("unsupported chain array rank $(ndims(values))"))
end

function _flatten_chain_values(chain)
    return vec(_chain_matrix(chain, 1))
end

function _column_summary(matrix::AbstractMatrix)
    mean_values = Vector{Float64}(undef, size(matrix, 2))
    lower_values = similar(mean_values)
    upper_values = similar(mean_values)
    for column in axes(matrix, 2)
        values = view(matrix, :, column)
        mean_values[column] = mean(values)
        lower_values[column] = quantile(values, 0.05)
        upper_values[column] = quantile(values, 0.95)
    end
    return mean_values, lower_values, upper_values
end
