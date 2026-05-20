using MCMCChains

if !isdefined(@__MODULE__, :ABACUS_GEO_BRAND_PANEL_CONFIG_DATA)
    include(joinpath(@__DIR__, "..", "fixtures", "abacus", "geo_brand_panel", "config_data.jl"))
end

const _GEO_BRAND_PANEL_REPLAY_FIXTURE_DIR =
    joinpath(@__DIR__, "..", "fixtures", "abacus", "geo_brand_panel")

function _geo_brand_panel_fixture_model_and_data()
    fixture = ABACUS_GEO_BRAND_PANEL_CONFIG_DATA
    config_path = joinpath(_GEO_BRAND_PANEL_REPLAY_FIXTURE_DIR, "config.yml")
    dataset_path = joinpath(_GEO_BRAND_PANEL_REPLAY_FIXTURE_DIR, "dataset.csv")
    holidays_path = joinpath(_GEO_BRAND_PANEL_REPLAY_FIXTURE_DIR, "holidays.csv")
    loaded = load_public_config(
        config_path;
        overrides = Dict("holidays" => Dict("path" => holidays_path)),
    )
    data = _load_validation_panel_dataset(dataset_path, loaded.model_config)
    model = PanelMMM(loaded.model_config, loaded.sampler_config, data)
    return fixture, model, data, build_model(model)
end

function _controlled_geo_brand_panel_replay(fixture)
    nchannels = length(fixture.channel_columns)
    npanels = fixture.npanels
    nseasonality = 2 * fixture.yearly_fourier_order

    intercept = [0.08 + (0.012 * panel) for panel in 1:npanels]
    beta_media = [
        0.045 + (0.008 * channel) + (0.006 * panel)
            for channel in 1:nchannels, panel in 1:npanels
    ]
    alpha = [
        0.1 + (0.01 * channel) + (0.008 * panel)
            for channel in 1:nchannels, panel in 1:npanels
    ]
    lam = [0.45 + (0.04 * channel) for channel in 1:nchannels]
    beta_holidays = [0.11]
    beta_seasonality = [
        (0.012 * feature) - (0.004 * panel)
            for feature in 1:nseasonality, panel in 1:npanels
    ]

    parameter_names = String[]
    parameter_values = Float64[]
    for (base, values) in (
            ("intercept", intercept),
            ("beta_media", vec(beta_media)),
            ("alpha", vec(alpha)),
            ("lam", lam),
            ("beta_holidays", beta_holidays),
            ("beta_seasonality", vec(beta_seasonality)),
        )
        for (index, value) in enumerate(values)
            push!(parameter_names, "$(base)[$(index)]")
            push!(parameter_values, Float64(value))
        end
    end

    return (;
        parameter_names,
        parameter_values,
        intercept,
        beta_media,
        alpha,
        lam,
        beta_holidays,
        beta_seasonality,
    )
end

function _controlled_geo_brand_panel_results(spec, data, replay)
    values = reshape(Float64.(replay.parameter_values), 1, :, 1)
    chain = MCMCChains.Chains(values, Symbol.(replay.parameter_names))
    return InferenceResults(
        Epsilon._artifact_metadata("PanelMMM"; backend = :fixture, fit_status = :fit),
        spec;
        posterior = chain,
        observed_data = data,
    )
end

function _expected_geo_brand_panel_component_values(spec, data, fixture, replay)
    scaled_channels = data.channels ./ reshape(
        spec.channel_scale,
        1,
        size(spec.channel_scale, 1),
        size(spec.channel_scale, 2),
    )
    adstocked = geometric_adstock(
        scaled_channels,
        replay.alpha,
        fixture.adstock_l_max;
        normalize = fixture.adstock_normalize,
        axis = 1,
        mode = After,
    )
    saturated = centered_logistic_saturation(adstocked, reshape(replay.lam, 1, :, 1))
    holiday_features = Epsilon._holiday_design_matrix(spec.holidays, data)
    fourier_features = Epsilon._seasonality_features(spec.seasonality, data.dates)

    component_names = [
        "intercept",
        ["media:$(name)" for name in fixture.channel_columns]...,
        "holiday",
        "seasonality",
    ]
    values = zeros(Float64, fixture.ntime, fixture.npanels, length(component_names))

    values[:, :, 1] .= reshape(replay.intercept, 1, :) .* reshape(spec.target_scale, 1, :)
    for channel in 1:length(fixture.channel_columns)
        component = channel + 1
        for panel in 1:fixture.npanels
            values[:, panel, component] .=
                saturated[:, channel, panel] .* replay.beta_media[channel, panel] .*
                spec.target_scale[panel]
        end
    end

    holiday_index = length(fixture.channel_columns) + 2
    for panel in 1:fixture.npanels
        for time in 1:fixture.ntime
            values[time, panel, holiday_index] =
                sum(
                holiday_features[time, holiday, panel] * replay.beta_holidays[holiday]
                    for holiday in axes(holiday_features, 2)
            ) * spec.target_scale[panel]
        end
    end

    seasonality_index = holiday_index + 1
    seasonality_effect = fourier_features * replay.beta_seasonality
    values[:, :, seasonality_index] .= seasonality_effect .* reshape(spec.target_scale, 1, :)

    return component_names, values
end

function _expected_geo_brand_panel_curve_values(spec, data, fixture, replay, channel_index, delta_grid, family)
    scaled_channels = data.channels ./ reshape(
        spec.channel_scale,
        1,
        size(spec.channel_scale, 1),
        size(spec.channel_scale, 2),
    )
    values = zeros(Float64, fixture.npanels, length(delta_grid))

    for (point, delta) in enumerate(delta_grid)
        scenario = zero(scaled_channels)
        scenario[:, channel_index, :] .= scaled_channels[:, channel_index, :] .* delta
        transformed = if family === :response
            adstocked = geometric_adstock(
                scenario,
                replay.alpha,
                fixture.adstock_l_max;
                normalize = fixture.adstock_normalize,
                axis = 1,
                mode = After,
            )
            centered_logistic_saturation(adstocked, reshape(replay.lam, 1, :, 1))
        elseif family === :saturation
            centered_logistic_saturation(scenario, reshape(replay.lam, 1, :, 1))
        elseif family === :adstock
            geometric_adstock(
                scenario,
                replay.alpha,
                fixture.adstock_l_max;
                normalize = fixture.adstock_normalize,
                axis = 1,
                mode = After,
            )
        else
            error("unsupported family")
        end

        for panel in 1:fixture.npanels
            values[panel, point] = if family === :adstock
                sum(transformed[:, channel_index, panel]) * spec.channel_scale[channel_index, panel]
            else
                sum(transformed[:, channel_index, panel]) *
                    replay.beta_media[channel_index, panel] *
                    spec.target_scale[panel]
            end
        end
    end

    return values
end

@testset "Abacus geo_brand_panel controlled model/replay fixture" begin
    fixture, _, data, spec = _geo_brand_panel_fixture_model_and_data()
    replay = _controlled_geo_brand_panel_replay(fixture)
    grouped = _controlled_geo_brand_panel_results(spec, data, replay)

    expected_component_names, expected_values =
        _expected_geo_brand_panel_component_values(spec, data, fixture, replay)

    @test String.(names(grouped.posterior, :parameters)) == replay.parameter_names
    @test grouped.spec.model_kind == :panel_mmm
    @test grouped.spec.coordinate_metadata.panel_dims == ("geo", "brand")
    @test grouped.spec.coordinate_metadata.coordinates["panel"] == fixture.panel_names
    @test grouped.spec.coordinate_metadata.named_dims["alpha"] == ("geo", "brand", "channel")
    @test grouped.spec.coordinate_metadata.named_dims["beta_media"] == ("geo", "brand", "channel")
    @test grouped.spec.coordinate_metadata.named_dims["beta_seasonality"] ==
        ("geo", "brand", "fourier_mode")
    @test grouped.spec.coordinate_metadata.named_dims["beta_holidays"] == ("holiday",)
    coordinates = panel_coordinates(grouped)
    @test [coordinate.panel_name for coordinate in coordinates] == fixture.panel_names
    @test [coordinate.values.geo for coordinate in coordinates] == fixture.panel_coordinate_columns["geo"]
    @test [coordinate.values.brand for coordinate in coordinates] == fixture.panel_coordinate_columns["brand"]

    contributions = contribution_results(grouped)
    @test panel_coordinates(contributions) == coordinates
    @test panel_coordinate(contributions, 9) ==
        PanelCoordinate(9, "DE|Gamma", (geo = "DE", brand = "Gamma"))
    @test contributions.component_names == expected_component_names
    @test contributions.component_kinds == [
        :intercept,
        fill(:media, length(fixture.channel_columns))...,
        :holiday,
        :seasonality,
    ]
    @test size(contributions.values) ==
        (1, fixture.ntime, fixture.npanels, length(expected_component_names))
    @test contributions.values[1, :, :, :] ≈ expected_values

    prediction_mean = dropdims(sum(contributions.values[1, :, :, :]; dims = 3); dims = 3)
    @test size(prediction_mean) == size(data.target)
    @test prediction_mean ≈ dropdims(sum(expected_values; dims = 3); dims = 3)

    decomposition = decomposition_results(grouped)
    expected_totals = vec(sum(expected_values; dims = (1, 2)))
    expected_shares = expected_totals ./ sum(expected_totals)
    @test decomposition.component_names == expected_component_names
    @test decomposition.totals[1, :] ≈ expected_totals
    @test decomposition.shares[1, :] ≈ expected_shares

    contribution_table = summary_table(contributions)
    @test nrow(contribution_table) ==
        fixture.ntime * fixture.npanels * length(expected_component_names)
    @test names(contribution_table) == [
        "observation",
        "date",
        "panel_cell",
        "panel",
        "geo",
        "brand",
        "component",
        "mean",
        "lower_5",
        "upper_95",
    ]

    first_observation_intercepts =
        contribution_table[
        (contribution_table.observation .== 1) .&
            (contribution_table.component .== "intercept"),
        :,
    ]
    @test first_observation_intercepts.panel_cell == fixture.panel_names
    @test first_observation_intercepts.panel == fixture.panel_names
    @test first_observation_intercepts.geo == fixture.panel_coordinate_columns["geo"]
    @test first_observation_intercepts.brand == fixture.panel_coordinate_columns["brand"]
    @test first_observation_intercepts.mean ≈ expected_values[1, :, 1]

    decomposition_table = summary_table(decomposition)
    @test names(decomposition_table) == [
        "component",
        "total_mean",
        "total_lower_5",
        "total_upper_95",
        "share_mean",
        "share_lower_5",
        "share_upper_95",
    ]
    @test decomposition_table.component == expected_component_names
    @test decomposition_table.total_mean ≈ expected_totals
    @test decomposition_table.share_mean ≈ expected_shares

    delta_grid = [0.0, 0.5, 1.0, 2.0]
    channel_name = fixture.channel_columns[1]
    response_curves = response_curve_results(grouped; channel = channel_name, delta_grid)
    saturation_curves = saturation_curve_results(grouped; channel = channel_name, delta_grid)
    adstock_curves = adstock_curve_results(grouped; channel = channel_name, delta_grid)
    expected_response = _expected_geo_brand_panel_curve_values(
        spec,
        data,
        fixture,
        replay,
        1,
        delta_grid,
        :response,
    )
    expected_saturation = _expected_geo_brand_panel_curve_values(
        spec,
        data,
        fixture,
        replay,
        1,
        delta_grid,
        :saturation,
    )
    expected_adstock = _expected_geo_brand_panel_curve_values(
        spec,
        data,
        fixture,
        replay,
        1,
        delta_grid,
        :adstock,
    )

    expected_spend_grid = vec(sum(data.channels[:, 1, :]; dims = 1)) * transpose(delta_grid)
    @test response_curves.spend_share_grid == delta_grid
    @test response_curves.spend_grid ≈ expected_spend_grid
    @test response_curves.observed_total_spend ≈ vec(sum(data.channels[:, 1, :]; dims = 1))
    @test size(response_curves.values) == (1, fixture.npanels, length(delta_grid))
    @test response_curves.values[1, :, :] ≈ expected_response
    @test saturation_curves.values[1, :, :] ≈ expected_saturation
    @test adstock_curves.values[1, :, :] ≈ expected_adstock

    response_table = summary_table(response_curves)
    @test names(response_table) == [
        "panel_cell",
        "panel",
        "geo",
        "brand",
        "channel",
        "delta",
        "spend",
        "observed_total_spend",
        "mean",
        "lower_5",
        "upper_95",
    ]
    @test nrow(response_table) == fixture.npanels * length(delta_grid)
    first_delta_rows = response_table[response_table.delta .== first(delta_grid), :]
    @test first_delta_rows.panel_cell == fixture.panel_names
    @test first_delta_rows.panel == fixture.panel_names
    @test first_delta_rows.geo == fixture.panel_coordinate_columns["geo"]
    @test first_delta_rows.brand == fixture.panel_coordinate_columns["brand"]
    @test first_delta_rows.mean ≈ expected_response[:, 1]

    metrics = metric_results(response_curves)
    @test size(metrics.values) == (1, fixture.npanels, length(delta_grid), 4)
    for panel in 1:fixture.npanels
        @test isnan(metrics.values[1, panel, 1, 1])
        @test metrics.values[1, panel, 3, 1] ≈
            expected_response[panel, 3] / expected_spend_grid[panel, 3]
    end
    metric_table = summary_table(metrics)
    @test names(metric_table) == [
        "panel_cell",
        "panel",
        "geo",
        "brand",
        "channel",
        "spend",
        "metric",
        "mean",
        "lower_5",
        "upper_95",
    ]
    @test nrow(metric_table) == fixture.npanels * length(delta_grid) * 4
    roas_rows = metric_table[
        (metric_table.metric .== "roas") .&
            (metric_table.spend .> 0.0),
        :,
    ]
    @test all(isfinite, roas_rows.mean)
end
