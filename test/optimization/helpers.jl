isdefined(@__MODULE__, :sample_time_series_model) || include("../model/sample_models.jl")

if !isdefined(@__MODULE__, :_grouped_results_for_optimization)
    function _grouped_results_for_optimization(model; new_data = model.data)
        return inference_results(
            model;
            new_data,
            include_prior = false,
            include_posterior_predictive = false,
            include_prior_predictive = false,
        )
    end

    function _observed_channel_total(model::TimeSeriesMMM, channel::AbstractString)
        index = findfirst(==(String(channel)), model.data.channel_names)
        isnothing(index) && error("missing channel $(channel)")
        return sum(model.data.channels[:, index])
    end

    function _observed_channel_total(model::PanelMMM, channel::AbstractString)
        index = findfirst(==(String(channel)), model.data.channel_names)
        isnothing(index) && error("missing channel $(channel)")
        return sum(model.data.channels[:, index, :])
    end
end
