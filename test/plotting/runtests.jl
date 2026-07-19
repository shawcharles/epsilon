if !isdefined(@__MODULE__, :sample_time_series_model)
    include(joinpath(@__DIR__, "..", "model", "sample_models.jl"))
end

if !isdefined(@__MODULE__, :feature_matrix_time_series_model)
    function feature_matrix_time_series_model(;
            seasonality = Dict{String, Any}(),
            trend = Dict{String, Any}(),
            events = Dict{String, Any}(),
            holidays = Dict{String, Any}(),
            controls_config = Dict{String, Any}(),
            include_controls::Bool = false,
            event_values = nothing,
            dates = 1:6,
            random_seed::Int = 41,
        )
        control_columns = include_controls ? ["price_index"] : String[]
        config = ModelConfig(
            date_column = "date",
            target_column = "revenue",
            target_type = "revenue",
            channel_columns = ["tv", "search"],
            control_columns = control_columns,
            dims = ("geo",),
            adstock = Dict("type" => "geometric", "l_max" => 8),
            saturation = Dict("type" => "logistic"),
            seasonality = seasonality,
            trend = trend,
            events = events,
            holidays = holidays,
            controls = controls_config,
            priors = Dict("intercept" => EpsilonPrior("Normal"; mu = 0.0, sigma = 1.0)),
        )
        sampler = SamplerConfig(;
            draws = 10,
            tune = 10,
            chains = 1,
            cores = 1,
            target_accept = 0.8,
            random_seed = random_seed,
            progressbar = false,
            compute_convergence_checks = false,
        )
        data = MMMData(
            dates = dates,
            target = [5.0, 6.5, 7.5, 9.0, 10.0, 11.5],
            channels = [1.0 0.5; 2.0 1.0; 2.5 1.5; 3.0 2.0; 3.5 2.5; 4.0 3.0],
            channel_names = ["tv", "search"],
            controls = include_controls ? [0.2; 0.4; 0.3; 0.6; 0.5; 0.8][:, :] : nothing,
            control_names = include_controls ? ["price_index"] : String[],
            events = event_values,
            event_names = haskey(events, "columns") ? String.(events["columns"]) : String[],
        )
        return TimeSeriesMMM(config, sampler, data)
    end
end

function _grouped_results_for_postmodel(model)
    return inference_results(
        model;
        include_prior = false,
        include_posterior_predictive = false,
        include_prior_predictive = false,
    )
end

function _grouped_results_for_response_curves(model; new_data = model.data)
    return inference_results(
        model;
        new_data,
        include_prior = false,
        include_posterior_predictive = false,
        include_prior_predictive = false,
    )
end

function _grouped_results_for_optimization(model; new_data = model.data)
    return inference_results(
        model;
        new_data,
        include_prior = false,
        include_posterior_predictive = false,
        include_prior_predictive = false,
    )
end

include("diagnostics.jl")
include("postmodel.jl")
include("optimization.jl")
include("bundle.jl")
