using MCMCChains

if !isdefined(@__MODULE__, :GOLDEN_TIMESERIES_CONFIG_DATA)
    include(joinpath(@__DIR__, "..", "fixtures", "golden", "timeseries", "config_data.jl"))
end

const _TIMESERIES_REPLAY_FIXTURE_DIR =
    joinpath(@__DIR__, "..", "fixtures", "golden", "timeseries")

function _timeseries_fixture_model_and_data()
    fixture = GOLDEN_TIMESERIES_CONFIG_DATA
    config_path = joinpath(_TIMESERIES_REPLAY_FIXTURE_DIR, "config.yml")
    dataset_path = joinpath(_TIMESERIES_REPLAY_FIXTURE_DIR, "dataset.csv")
    holidays_path = joinpath(_TIMESERIES_REPLAY_FIXTURE_DIR, "holidays.csv")
    loaded = _load_validation_fixture_config(config_path; holidays_path)
    data = _load_validation_time_series_dataset(dataset_path, loaded.model_config)
    model = TimeSeriesMMM(loaded.model_config, loaded.sampler_config, data)
    return fixture, model, data, build_model(model)
end

function _controlled_timeseries_results(spec, data, replay)
    values = reshape(Float64.(replay.parameter_values), 1, :, 1)
    chain = MCMCChains.Chains(values, Symbol.(replay.parameter_names))
    return InferenceResults(
        Epsilon._artifact_metadata("TimeSeriesMMM"; backend = :fixture, fit_status = :fit),
        spec;
        posterior = chain,
        observed_data = data,
    )
end

@testset "timeseries golden fixture controlled model/replay" begin
    fixture, _, data, spec = _timeseries_fixture_model_and_data()
    replay = fixture.controlled_replay
    grouped = _controlled_timeseries_results(spec, data, replay)

    @test String.(names(grouped.posterior, :parameters)) == replay.parameter_names
    @test grouped.spec.priors["beta_media"] == EpsilonPrior("HalfNormal"; sigma = 1, dims = ("channel",))
    @test grouped.spec.saturation["type"] == fixture.saturation_type
    @test grouped.spec.adstock["type"] == fixture.adstock_type
    @test grouped.spec.holidays["mode"] == "auto"
    @test replay.holiday_contract == "epsilon_native_pooled_auto"

    holiday_design = Epsilon._holiday_design_matrix(spec.holidays, data)
    @test vec(holiday_design[:, 1]) ≈ replay.holiday_exposure
    @test Epsilon._seasonality_features(spec.seasonality, data.dates) ≈ replay.fourier_features

    contributions = contribution_results(grouped)
    @test contributions.component_names == replay.component_names
    @test contributions.component_kinds == [
        :intercept,
        fill(:media, length(fixture.channel_columns))...,
        :holiday,
        :seasonality,
    ]
    @test size(contributions.values) == (1, fixture.nobs, length(replay.component_names))
    @test contributions.values[1, :, :] ≈ replay.component_values

    prediction_mean = vec(sum(contributions.values[1, :, :]; dims = 2))
    @test prediction_mean ≈ replay.prediction_mean

    decomposition = decomposition_results(grouped)
    @test decomposition.component_names == replay.component_names
    @test decomposition.totals[1, :] ≈ replay.decomposition_totals
    @test decomposition.shares[1, :] ≈ replay.decomposition_shares

    response = response_curve_results(
        grouped;
        channel = replay.curve_channel,
        grid = replay.curve_spend_grid,
    )
    saturation = saturation_curve_results(
        grouped;
        channel = replay.curve_channel,
        grid = replay.curve_spend_grid,
    )
    adstock = adstock_curve_results(
        grouped;
        channel = replay.curve_channel,
        grid = replay.curve_spend_grid,
    )

    @test response.spend_grid ≈ replay.curve_spend_grid
    @test response.spend_share_grid ≈ replay.curve_spend_share_grid
    @test response.observed_total_spend ≈ replay.curve_observed_total_spend
    @test response.values[1, :] ≈ replay.response_curve_values
    @test saturation.values[1, :] ≈ replay.saturation_curve_values
    @test adstock.values[1, :] ≈ replay.adstock_curve_values

    metrics = metric_results(
        grouped;
        channel = replay.curve_channel,
        grid = replay.curve_spend_grid,
    )
    @test metrics.metric_names == replay.metric_names
    @test metrics.default_metric == :roas
    @test isapprox(metrics.values[1, :, :], replay.metric_values; nans = true)
end
