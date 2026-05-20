using Dates
using Epsilon
using Test

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

function assert_feature_matrix_bundle(
    model::TimeSeriesMMM;
    target_symbol::Symbol = Symbol("target[1]"),
    parameter_symbols::Vector{Symbol} = Symbol[],
)
    state = fit!(model)
    @test state isa ModelFitState
    @test state.backend == :turing
    @test hasproperty(state.artifact, :chain)
    predictive = Epsilon.predict(model)
    @test size(predictive, 1) == model.sampler_config.draws
    @test target_symbol in predictive.name_map.parameters
    for parameter_symbol in parameter_symbols
        @test parameter_symbol in names(state.artifact.chain)
    end
end

function assert_feature_matrix_bundle(
    model::PanelMMM;
    target_symbol::Symbol = Symbol("target[1, 1]"),
    parameter_symbols::Vector{Symbol} = Symbol[],
)
    state = fit!(model)
    @test state isa ModelFitState
    @test state.backend == :turing
    @test hasproperty(state.artifact, :chain)
    predictive = Epsilon.predict(model)
    @test size(predictive, 1) == model.sampler_config.draws
    @test target_symbol in predictive.name_map.parameters
    for parameter_symbol in parameter_symbols
        @test parameter_symbol in names(state.artifact.chain)
    end
end

@testset "Phase 5 Supported Feature Matrix" begin
    @testset "TS-00 media only" begin
        model = feature_matrix_time_series_model(; random_seed = 101)
        assert_feature_matrix_bundle(model)
    end

    @testset "TS-01 fourier seasonality" begin
        model = feature_matrix_time_series_model(;
            seasonality = Dict("type" => "fourier", "n_order" => 2),
            dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
            random_seed = 102,
        )
        assert_feature_matrix_bundle(
            model;
            parameter_symbols = [Symbol("beta_seasonality[1]")],
        )
    end

    @testset "TS-02 fourier plus linear trend" begin
        model = feature_matrix_time_series_model(;
            seasonality = Dict("type" => "fourier", "n_order" => 2),
            trend = Dict("type" => "linear"),
            dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
            random_seed = 103,
        )
        assert_feature_matrix_bundle(
            model;
            parameter_symbols = [Symbol("beta_seasonality[1]"), Symbol("beta_trend[1]")],
        )
    end

    @testset "TS-03 fourier plus linear trend plus manual events" begin
        model = feature_matrix_time_series_model(;
            seasonality = Dict("type" => "fourier", "n_order" => 2),
            trend = Dict("type" => "linear"),
            events = Dict("columns" => ["promo", "holiday"]),
            event_values = [1.0 0.0; 0.0 1.0; 0.0 0.0; 1.0 0.0; 0.0 0.0; 0.0 1.0],
            dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
            random_seed = 104,
        )
        assert_feature_matrix_bundle(
            model;
            parameter_symbols = [
                Symbol("beta_seasonality[1]"),
                Symbol("beta_trend[1]"),
                Symbol("beta_events[1]"),
            ],
        )
    end

    @testset "TS-04 fourier plus changepoint plus generated events" begin
        model = feature_matrix_time_series_model(;
            seasonality = Dict("type" => "fourier", "n_order" => 2),
            trend = Dict("type" => "changepoint", "n_changepoints" => 3),
            events = Dict(
                "windows" => [
                    Dict("name" => "promo", "start_date" => "2024-01-08", "end_date" => "2024-01-15"),
                    Dict("name" => "holiday", "start_date" => "2024-01-29"),
                ],
            ),
            dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
            random_seed = 105,
        )
        assert_feature_matrix_bundle(
            model;
            parameter_symbols = [
                Symbol("beta_seasonality[1]"),
                Symbol("delta_trend[1]"),
                Symbol("beta_events[1]"),
            ],
        )
    end

    @testset "TS-05 fourier plus standardized controls" begin
        model = feature_matrix_time_series_model(;
            seasonality = Dict("type" => "fourier", "n_order" => 2),
            controls_config = Dict("transform" => "standardize"),
            include_controls = true,
            dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
            random_seed = 106,
        )
        assert_feature_matrix_bundle(
            model;
            parameter_symbols = [Symbol("beta_seasonality[1]"), Symbol("beta_controls[1]")],
        )
    end

    @testset "P-00 bounded panel hierarchical media path" begin
        model = sample_panel_model(; adstock_type = "geometric", saturation_type = "logistic")
        assert_feature_matrix_bundle(
            model;
            parameter_symbols = [Symbol("panel_intercept_offset[1]"), Symbol("beta_media[1]")],
        )
    end
end
