"""
    run_pipeline(config::PipelineRunConfig)

Execute the bounded Phase 9 pipeline runner across the current supported stage
surface.

The closed Phase 9 surface validates the supported pipeline contract, loads the
combined CSV dataset, executes the bounded time-series MCMC stage sequence,
persists stage-owned artifacts, and returns a truthful completed
`PipelineRunResult` when all enabled stages succeed.
"""
function run_pipeline(config::PipelineRunConfig)
    loaded = _load_pipeline_configuration(config)
    context = _pipeline_context(config, loaded)

    try
        _create_pipeline_scaffold!(context)
        context.status = :running
        _write_pipeline_manifest!(context)
        _run_all_pipeline_stages!(context)
        context.status = :completed
        context.finished_at_utc = _pipeline_timestamp_utc()
        _write_pipeline_manifest!(context)
        return _pipeline_run_result(context)
    catch err
        if isdir(context.run_dir) && context.status != :failed
            context.status = :failed
            context.finished_at_utc = _pipeline_timestamp_utc()
            context.error = _pipeline_error_payload(err, nothing)
            _write_pipeline_manifest!(context)
        end
        rethrow()
    end
end

function _create_pipeline_scaffold!(context::PipelineContext)
    mkpath(context.run_dir)
    for spec in _PIPELINE_STAGE_SPECS
        mkpath(joinpath(context.run_dir, spec.directory))
    end

    metadata_dir = _stage_directory_path(context, "metadata")
    config_original_path = joinpath(metadata_dir, "config.original.yaml")
    config_resolved_path = joinpath(metadata_dir, "config.resolved.yaml")
    config_model_path = joinpath(metadata_dir, "config.model.yaml")
    config_copy_path = joinpath(metadata_dir, "config.yml")

    _write_pipeline_text(config_original_path, context.source_yaml)
    _write_pipeline_text(config_copy_path, context.source_yaml)
    _write_pipeline_yaml(config_resolved_path, context.resolved_config)
    _write_pipeline_yaml(config_model_path, context.model_config_dict)

    _set_stage_record!(
        context,
        "metadata";
        artifact_paths = Dict{String, String}(
            "config_copy" => _pipeline_relative_stage_artifact("metadata", "config.yml"),
            "config_original" => _pipeline_relative_stage_artifact("metadata", "config.original.yaml"),
            "config_resolved" => _pipeline_relative_stage_artifact("metadata", "config.resolved.yaml"),
            "config_model" => _pipeline_relative_stage_artifact("metadata", "config.model.yaml"),
        ),
    )
    return nothing
end
