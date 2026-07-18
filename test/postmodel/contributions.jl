using Dates
using Epsilon
using Test

function _grouped_results_for_postmodel(model)
    return inference_results(
        model;
        include_prior = false,
        include_posterior_predictive = false,
        include_prior_predictive = false,
    )
end

function _component_index(results::ContributionResults, name::AbstractString)
    index = findfirst(==(String(name)), results.component_names)
    isnothing(index) && error("missing contribution component $(name)")
    return index
end

function _write_postmodel_holidays_csv()
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

@testset "contribution_results supports TS-00 media-only grouped artifacts" begin
    model = feature_matrix_time_series_model(; random_seed = 201)
    fit!(model)
    grouped = _grouped_results_for_postmodel(model)
    results = contribution_results(grouped)

    @test results isa ContributionResults
    @test results.component_names == ["intercept", "media:tv", "media:search"]
    @test results.component_kinds == [:intercept, :media, :media]
    @test size(results.values) == (model.sampler_config.draws, nobs(model.data), 3)
    @test all(isfinite, results.values)
end

@testset "contribution_results supports TS-03 and TS-04 additive bundles" begin
    manual_model = feature_matrix_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        trend = Dict("type" => "linear"),
        events = Dict("columns" => ["promo", "holiday"]),
        event_values = [1.0 0.0; 0.0 1.0; 0.0 0.0; 1.0 0.0; 0.0 0.0; 0.0 1.0],
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
        random_seed = 202,
    )
    fit!(manual_model)
    manual_results = contribution_results(_grouped_results_for_postmodel(manual_model))

    @test manual_results.component_names == [
        "intercept",
        "media:tv",
        "media:search",
        "event:promo",
        "event:holiday",
        "seasonality",
        "trend",
    ]
    @test size(manual_results.values, 3) == 7

    changepoint_model = feature_matrix_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        trend = Dict("type" => "changepoint", "n_changepoints" => 3),
        events = Dict(
            "windows" => [
                Dict("name" => "promo", "start_date" => "2024-01-08", "end_date" => "2024-01-15"),
                Dict("name" => "holiday", "start_date" => "2024-01-29"),
            ],
        ),
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
        random_seed = 203,
    )
    fit!(changepoint_model)
    changepoint_results = contribution_results(_grouped_results_for_postmodel(changepoint_model))

    @test changepoint_results.component_names == [
        "intercept",
        "media:tv",
        "media:search",
        "event:promo",
        "event:holiday",
        "seasonality",
        "trend",
    ]
    @test size(changepoint_results.values, 3) == 7
end

@testset "contribution_results includes pooled holiday components in original target units" begin
    holidays_path = _write_postmodel_holidays_csv()
    model = feature_matrix_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        events = Dict("columns" => ["promo"]),
        event_values = [0.0; 1.0; 0.0; 1.0; 0.0; 0.0][:, :],
        holidays = Dict(
            "mode" => "auto",
            "path" => holidays_path,
            "countries" => ["UK"],
        ),
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
        random_seed = 219,
    )
    fit!(model)
    results = contribution_results(_grouped_results_for_postmodel(model))

    @test results.component_names == [
        "intercept",
        "media:tv",
        "media:search",
        "event:promo",
        "holiday",
        "seasonality",
    ]
    @test results.component_kinds == [
        :intercept,
        :media,
        :media,
        :event,
        :holiday,
        :seasonality,
    ]
    @test all(isfinite, results.values)
end

@testset "contribution_results replays standardized controls from grouped spec state" begin
    model = feature_matrix_time_series_model(;
        seasonality = Dict("type" => "fourier", "n_order" => 2),
        controls_config = Dict("transform" => "standardize"),
        include_controls = true,
        dates = Date(2024, 1, 1):Day(7):Date(2024, 2, 5),
        random_seed = 204,
    )
    fit!(model)

    new_data = MMMData(
        dates = Date(2024, 2, 12):Day(7):Date(2024, 3, 4),
        target = [4.5, 5.5, 6.5, 7.5],
        channels = [1.0 0.75; 1.5 1.0; 2.0 1.25; 2.5 1.5],
        channel_names = ["tv", "search"],
        controls = [0.1; 0.2; 0.3; 0.4][:, :],
        control_names = ["price_index"],
    )

    grouped = inference_results(
        model;
        new_data,
        include_prior = false,
        include_posterior_predictive = false,
        include_prior_predictive = false,
    )
    results = contribution_results(grouped)
    control_index = _component_index(results, "control:price_index")
    resolved_state = model.fit_state.artifact.runtime.control_transform_state

    @test haskey(grouped.spec.controls, "_resolved_transform_state")
    @test grouped.spec.controls["_resolved_transform_state"]["mean"] ≈ resolved_state.mean
    @test grouped.spec.controls["_resolved_transform_state"]["scale"] ≈ resolved_state.scale

    beta_draws = vec(Float64.(Array(grouped.posterior[Symbol("beta_controls[1]")])))
    expected = ((Float64.(new_data.controls[:, 1]) .- resolved_state.mean[1]) ./ resolved_state.scale[1]) .*
        beta_draws[1] .* grouped.spec.target_scale
    @test results.component_names == [
        "intercept",
        "media:tv",
        "media:search",
        "control:price_index",
        "seasonality",
    ]
    @test results.values[1, :, control_index] ≈ expected
end

@testset "contribution_results flattens multichain grouped posterior draws" begin
    model = sample_multichain_time_series_model()
    fit!(model)
    grouped = _grouped_results_for_postmodel(model)
    results = contribution_results(grouped)

    @test size(results.values, 1) == model.sampler_config.draws * model.sampler_config.chains
end

@testset "contribution_results rejects grouped artifacts missing beta_media outside Michaelis-Menten" begin
    model = feature_matrix_time_series_model(; random_seed = 218)
    fit!(model)
    grouped = _grouped_results_for_postmodel(model)
    keep = filter(!=(Symbol("beta_media[1]")), names(grouped.posterior, :parameters))
    bad_grouped = InferenceResults(
        grouped.metadata,
        grouped.spec;
        posterior = grouped.posterior[keep],
        prior = grouped.prior,
        posterior_predictive = grouped.posterior_predictive,
        prior_predictive = grouped.prior_predictive,
        sample_stats = grouped.sample_stats,
        observed_data = grouped.observed_data,
    )

    @test_throws ArgumentError contribution_results(bad_grouped)
end

@testset "contribution_results supports bounded panel grouped artifacts" begin
    model = sample_panel_model()
    fit!(model)
    grouped = _grouped_results_for_postmodel(model)

    results = contribution_results(grouped)
    decomposition = decomposition_results(grouped)

    @test results.component_names == ["intercept", "media:tv", "media:search"]
    @test results.component_kinds == [:intercept, :media, :media]
    @test size(results.values) == (
        model.sampler_config.draws,
        length(model.data.dates),
        length(model.data.panel_names),
        3,
    )
    @test all(isfinite, results.values)
    @test size(decomposition.totals) ==
        (model.sampler_config.draws, length(results.component_names))
end
