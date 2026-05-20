using MCMCChains

if !isdefined(@__MODULE__, :ABACUS_GEO_PANEL_CONFIG_DATA)
    include(joinpath(@__DIR__, "..", "fixtures", "abacus", "geo_panel", "config_data.jl"))
end

const _GEO_PANEL_REPLAY_FIXTURE_DIR =
    joinpath(@__DIR__, "..", "fixtures", "abacus", "geo_panel")

function _geo_panel_fixture_model_and_data()
    fixture = ABACUS_GEO_PANEL_CONFIG_DATA
    config_path = joinpath(_GEO_PANEL_REPLAY_FIXTURE_DIR, "config.yml")
    dataset_path = joinpath(_GEO_PANEL_REPLAY_FIXTURE_DIR, "dataset.csv")
    holidays_path = joinpath(_GEO_PANEL_REPLAY_FIXTURE_DIR, "holidays.csv")
    loaded = load_public_config(
        config_path;
        overrides = Dict("holidays" => Dict("path" => holidays_path)),
    )
    data = _load_validation_panel_dataset(dataset_path, loaded.model_config)
    model = PanelMMM(loaded.model_config, loaded.sampler_config, data)
    return fixture, model, data, build_model(model)
end

function _controlled_geo_panel_replay(fixture)
    nchannels = length(fixture.channel_columns)
    npanels = fixture.npanels
    nseasonality = 2 * fixture.yearly_fourier_order

    intercept = [0.12, 0.18, 0.24]
    beta_media = [
        0.08 + (0.01 * channel) + (0.015 * panel)
            for channel in 1:nchannels, panel in 1:npanels
    ]
    alpha = [
        0.12 + (0.015 * channel) + (0.02 * panel)
            for channel in 1:nchannels, panel in 1:npanels
    ]
    lam = [0.55 + (0.05 * channel) for channel in 1:nchannels]
    beta_holidays = [0.18]
    beta_seasonality = [
        (0.015 * feature) - (0.01 * panel)
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

function _controlled_geo_panel_results(spec, data, replay)
    values = reshape(Float64.(replay.parameter_values), 1, :, 1)
    chain = MCMCChains.Chains(values, Symbol.(replay.parameter_names))
    return InferenceResults(
        Epsilon._artifact_metadata("PanelMMM"; backend = :fixture, fit_status = :fit),
        spec;
        posterior = chain,
        observed_data = data,
    )
end

function _expected_geo_panel_component_values(spec, data, fixture, replay)
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

@testset "Abacus geo_panel controlled model/replay fixture" begin
    fixture, _, data, spec = _geo_panel_fixture_model_and_data()
    replay = _controlled_geo_panel_replay(fixture)
    grouped = _controlled_geo_panel_results(spec, data, replay)

    expected_component_names, expected_values =
        _expected_geo_panel_component_values(spec, data, fixture, replay)

    @test String.(names(grouped.posterior, :parameters)) == replay.parameter_names
    @test grouped.spec.model_kind == :panel_mmm
    @test grouped.spec.coordinate_metadata.named_dims["alpha"] == ("geo", "channel")
    @test grouped.spec.coordinate_metadata.named_dims["beta_media"] == ("geo", "channel")
    @test grouped.spec.coordinate_metadata.named_dims["beta_seasonality"] ==
        ("geo", "fourier_mode")
    @test grouped.spec.coordinate_metadata.named_dims["beta_holidays"] == ("holiday",)

    contributions = contribution_results(grouped)
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
    @test "geo" in names(contribution_table)
end
