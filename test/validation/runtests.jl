using Epsilon
using YAML

function _load_validation_fixture_config(config_path::AbstractString; holidays_path = nothing)
    raw = Epsilon._normalize_config_value(YAML.load_file(config_path))
    if !isnothing(holidays_path)
        holidays = get!(raw, "holidays", Dict{String, Any}())
        holidays isa AbstractDict ||
            throw(ArgumentError("fixture holidays block must be a mapping"))
        holidays["path"] = holidays_path
    end
    stripped = Epsilon._strip_pipeline_runner_keys(raw)
    return (
        model_config = model_config_from_dict(stripped; base_path = dirname(abspath(config_path))),
        sampler_config = sampler_config_from_dict(stripped),
    )
end

include("contracts.jl")
include("timeseries_config_data.jl")
include("timeseries_model_replay.jl")
include("geo_panel_config_data.jl")
include("geo_panel_model_replay.jl")
include("geo_brand_panel_config_data.jl")
include("geo_brand_panel_model_replay.jl")
