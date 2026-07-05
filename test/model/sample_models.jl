using Dates
using Epsilon

if !isdefined(@__MODULE__, :sample_time_series_model)
    function sample_time_series_model(;
            adstock_type = "geometric",
            saturation_type = "logistic",
            target_type = "revenue",
            seasonality = Dict{String, Any}(),
            trend = Dict{String, Any}(),
            events = Dict{String, Any}(),
            holidays = Dict{String, Any}(),
            controls_config = Dict{String, Any}(),
            event_values = nothing,
            dates = 1:6,
        )
        config = ModelConfig(
            date_column = "date",
            target_column = "revenue",
            target_type = target_type,
            channel_columns = ["tv", "search"],
            control_columns = ["price_index"],
            dims = ("geo",),
            adstock = Dict("type" => adstock_type, "l_max" => 8),
            saturation = Dict("type" => saturation_type),
            seasonality = seasonality,
            trend = trend,
            controls = controls_config,
            priors = Dict("intercept" => EpsilonPrior("Normal"; mu = 0.0, sigma = 1.0)),
            events = events,
            holidays = holidays,
        )
        sampler = SamplerConfig(;
            draws = 20,
            tune = 20,
            chains = 1,
            cores = 1,
            target_accept = 0.8,
            random_seed = 7,
            progressbar = false,
            compute_convergence_checks = false,
        )
        data = MMMData(
            dates = dates,
            target = [5.0, 6.5, 7.5, 9.0, 10.0, 11.5],
            channels = [1.0 0.5; 2.0 1.0; 2.5 1.5; 3.0 2.0; 3.5 2.5; 4.0 3.0],
            channel_names = ["tv", "search"],
            controls = [0.2; 0.4; 0.3; 0.6; 0.5; 0.8][:, :],
            control_names = ["price_index"],
            events = event_values,
            event_names = haskey(events, "columns") ? String.(events["columns"]) : String[],
        )
        return TimeSeriesMMM(config, sampler, data)
    end
end

if !isdefined(@__MODULE__, :_write_test_holidays_csv)
    function _write_test_holidays_csv()
        path = tempname() * ".csv"
        write(
            path,
            "ds,holiday,country,year\n" *
                "01/01/2024,New Year,UK,2024\n" *
                "15/01/2024,Promo Day,UK,2024\n" *
                "29/01/2024,Promo Day,UK,2024\n",
        )
        return path
    end
end

if !isdefined(@__MODULE__, :sample_multichain_time_series_model)
    function sample_multichain_time_series_model(; cores = 2, compute_convergence_checks = false)
        config = ModelConfig(
            date_column = "date",
            target_column = "revenue",
            target_type = "revenue",
            channel_columns = ["tv", "search"],
            control_columns = ["price_index"],
            dims = ("geo",),
            adstock = Dict("type" => "geometric", "l_max" => 8),
            saturation = Dict("type" => "logistic"),
            priors = Dict("intercept" => EpsilonPrior("Normal"; mu = 0.0, sigma = 1.0)),
        )
        sampler = SamplerConfig(;
            draws = 15,
            tune = 15,
            chains = 2,
            cores = cores,
            target_accept = 0.8,
            random_seed = 11,
            progressbar = false,
            compute_convergence_checks = compute_convergence_checks,
        )
        data = MMMData(
            dates = 1:6,
            target = [5.0, 6.5, 7.5, 9.0, 10.0, 11.5],
            channels = [1.0 0.5; 2.0 1.0; 2.5 1.5; 3.0 2.0; 3.5 2.5; 4.0 3.0],
            channel_names = ["tv", "search"],
            controls = [0.2; 0.4; 0.3; 0.6; 0.5; 0.8][:, :],
            control_names = ["price_index"],
        )
        return TimeSeriesMMM(config, sampler, data)
    end
end

if !isdefined(@__MODULE__, :sample_panel_model)
    function sample_panel_model(; adstock_type = "geometric", saturation_type = "logistic")
        config = ModelConfig(
            date_column = "date",
            target_column = "revenue",
            target_type = "revenue",
            channel_columns = ["tv", "search"],
            dims = ("geo",),
            adstock = Dict("type" => adstock_type, "l_max" => 8),
            saturation = Dict("type" => saturation_type),
            priors = Dict(
                "intercept" => EpsilonPrior("Normal"; mu = 0.0, sigma = 1.0),
                "panel_intercept_scale" => EpsilonPrior("HalfNormal"; sigma = 0.4),
            ),
        )
        sampler = SamplerConfig(;
            draws = 20,
            tune = 20,
            chains = 1,
            cores = 1,
            target_accept = 0.8,
            random_seed = 17,
            progressbar = false,
            compute_convergence_checks = false,
        )
        channels = Array{Float64}(undef, 6, 2, 2)
        channels[:, :, 1] = [1.0 0.5; 2.0 1.0; 2.5 1.5; 3.0 2.0; 3.5 2.5; 4.0 3.0]
        channels[:, :, 2] = [0.7 0.4; 1.4 0.8; 1.8 1.1; 2.3 1.5; 2.7 1.8; 3.1 2.1]
        data = PanelMMMData(
            dates = 1:6,
            target = [5.0 4.0; 6.5 4.8; 7.5 5.5; 9.0 6.3; 10.0 7.1; 11.5 8.0],
            channels = channels,
            panel_names = ["north", "south"],
            channel_names = ["tv", "search"],
        )
        return PanelMMM(config, sampler, data)
    end
end
