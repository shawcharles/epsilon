using Dates

include(joinpath(@__DIR__, "..", "fixtures", "abacus", "geo_brand_panel", "config_data.jl"))

const _GEO_BRAND_PANEL_FIXTURE_DIR = joinpath(@__DIR__, "..", "fixtures", "abacus", "geo_brand_panel")

@testset "Abacus geo_brand_panel config/data fixture spine" begin
    fixture = ABACUS_GEO_BRAND_PANEL_CONFIG_DATA
    config_path = joinpath(_GEO_BRAND_PANEL_FIXTURE_DIR, "config.yml")
    dataset_path = joinpath(_GEO_BRAND_PANEL_FIXTURE_DIR, "dataset.csv")
    holidays_path = joinpath(_GEO_BRAND_PANEL_FIXTURE_DIR, "holidays.csv")

    loaded = load_public_config(
        config_path;
        overrides = Dict("holidays" => Dict("path" => holidays_path)),
    )
    config = loaded.model_config
    sampler = loaded.sampler_config

    @test config.date_column == fixture.date_column
    @test config.target_column == fixture.target_column
    @test config.target_type == fixture.target_type
    @test config.channel_columns == fixture.channel_columns
    @test config.control_columns == fixture.control_columns
    @test collect(config.dims) == fixture.panel_dims

    @test config.adstock["type"] == fixture.adstock_type
    @test config.adstock["l_max"] == fixture.adstock_l_max
    @test get(config.adstock, "normalize", false) == fixture.adstock_normalize
    @test sort!(collect(keys(config.adstock["priors"]))) == ["alpha"]
    @test config.adstock["priors"]["alpha"] ==
        EpsilonPrior("Beta"; alpha = 1, beta = 3, dims = ("geo", "brand", "channel"))

    @test config.saturation["type"] == fixture.saturation_type
    @test sort!(collect(keys(config.saturation["priors"]))) == ["lam"]
    @test config.saturation["priors"]["lam"] ==
        EpsilonPrior("Gamma"; alpha = 3, beta = 1, dims = ("channel",))
    @test haskey(config.priors, "beta_media")
    @test config.priors["beta_media"] ==
        EpsilonPrior("HalfNormal"; sigma = 1, dims = ("geo", "brand", "channel"))
    @test config.priors["intercept"] ==
        EpsilonPrior("Normal"; mu = 0, sigma = 2, dims = ("geo", "brand"))
    @test config.priors["likelihood"].distribution == "Normal"
    @test config.priors["likelihood"].dims == ("date", "geo", "brand")
    @test config.priors["likelihood"].parameters[:sigma] ==
        EpsilonPrior("HalfNormal"; sigma = 2, dims = ("geo", "brand"))

    @test config.seasonality["type"] == "fourier"
    @test config.seasonality["n_order"] == fixture.yearly_fourier_order
    @test fixture.effect_types == ["yearly_fourier"]

    @test fixture.holidays_mode == "prophet_component"
    @test config.holidays["mode"] == "auto"
    @test config.holidays["countries"] == fixture.holidays_countries
    @test config.holidays["path"] == holidays_path

    @test sampler.draws == fixture.fit_draws
    @test sampler.tune == fixture.fit_tune
    @test sampler.chains == fixture.fit_chains
    @test sampler.cores == fixture.fit_cores
    @test sampler.random_seed == fixture.fit_random_seed
    @test sampler.target_accept == fixture.fit_target_accept
    @test sampler.progressbar == false
    @test sampler.compute_convergence_checks == false

    data = _load_validation_panel_dataset(dataset_path, config)
    @test nobs(data) == fixture.nobs
    @test ntime(data) == fixture.ntime
    @test npanels(data) == fixture.npanels
    @test npanel_observations(data) == fixture.nobs
    @test length(data.dates) == fixture.ntime
    @test string.(data.dates) == fixture.dates
    @test data.panel_names == fixture.panel_names
    @test data.panel_coordinates == fixture.panel_coordinate_columns
    @test data.channel_names == fixture.channel_columns
    @test data.channels ≈ fixture.raw_channels
    @test data.target ≈ fixture.raw_target

    scaled_target = data.target ./ reshape(fixture.target_scale, 1, :)
    scaled_channels = data.channels ./ reshape(
        fixture.channel_scale,
        1,
        size(fixture.channel_scale, 1),
        size(fixture.channel_scale, 2),
    )
    @test scaled_target ≈ fixture.scaled_target
    @test scaled_channels ≈ fixture.scaled_channels
    @test fixture.transform_alpha_by_panel_channel ≈ permutedims(fixture.transform_alpha)

    adstocked = geometric_adstock(
        scaled_channels,
        fixture.transform_alpha,
        fixture.adstock_l_max;
        normalize = fixture.adstock_normalize,
        axis = 1,
        mode = After,
    )
    @test adstocked ≈ fixture.adstocked_media

    saturated = centered_logistic_saturation(adstocked, reshape(fixture.transform_lam, 1, :, 1))
    @test saturated ≈ fixture.saturated_media

    panel_model = PanelMMM(config, sampler, data)
    panel_spec = build_model(panel_model)
    panel_runtime = Epsilon._panel_turing_runtime(panel_spec, data)

    @test isempty(fixture.unsupported_epsilon_features)
    @test fixture.expected_epsilon_rejection == ""
    @test panel_spec.channel_scale ≈ fixture.channel_scale
    @test panel_spec.target_scale ≈ fixture.target_scale
    @test panel_spec.coordinate_metadata.panel_dims == ("geo", "brand")
    @test panel_spec.coordinate_metadata.coordinates["panel_cell"] == fixture.panel_names
    @test panel_spec.coordinate_metadata.coordinates["panel"] == fixture.panel_names
    @test panel_spec.coordinate_metadata.coordinates["geo"] == fixture.panel_coordinates["geo"]
    @test panel_spec.coordinate_metadata.coordinates["brand"] == fixture.panel_coordinates["brand"]
    axis = panel_axis(panel_spec)
    @test axis.name == "panel_cell"
    @test axis.values == fixture.panel_names
    @test axis.coordinate_columns == [
        "geo" => fixture.panel_coordinate_columns["geo"],
        "brand" => fixture.panel_coordinate_columns["brand"],
    ]
    @test panel_axes(panel_spec) == [axis]
    coordinates = panel_coordinates(panel_spec)
    @test length(coordinates) == fixture.npanels
    @test [coordinate.flat_index for coordinate in coordinates] == collect(1:fixture.npanels)
    @test [coordinate.panel_name for coordinate in coordinates] == fixture.panel_names
    @test [coordinate.values.geo for coordinate in coordinates] == fixture.panel_coordinate_columns["geo"]
    @test [coordinate.values.brand for coordinate in coordinates] == fixture.panel_coordinate_columns["brand"]
    @test panel_coordinates(panel_spec.coordinate_metadata) == coordinates
    @test panel_coordinate(panel_spec, 5) == PanelCoordinate(5, "FR|Beta", (geo = "FR", brand = "Beta"))
    @test panel_spec.coordinate_metadata.coordinates["fourier_mode"] ==
        ["sin_1", "sin_2", "cos_1", "cos_2"]
    @test panel_spec.coordinate_metadata.coordinates["holiday"] == ["holiday"]
    @test panel_spec.coordinate_metadata.named_dims["target"] == ("time", "panel")
    @test panel_spec.coordinate_metadata.named_dims["channels"] == ("time", "channel", "panel")
    @test panel_spec.coordinate_metadata.named_dims["intercept"] == ("geo", "brand")
    @test panel_spec.coordinate_metadata.named_dims["sigma"] == ("geo", "brand")
    @test panel_spec.coordinate_metadata.named_dims["alpha"] == ("geo", "brand", "channel")
    @test panel_spec.coordinate_metadata.named_dims["beta_media"] == ("geo", "brand", "channel")
    @test panel_spec.coordinate_metadata.named_dims["seasonality_features"] ==
        ("time", "fourier_mode")
    @test panel_spec.coordinate_metadata.named_dims["beta_seasonality"] ==
        ("geo", "brand", "fourier_mode")
    @test panel_spec.coordinate_metadata.named_dims["holidays"] == ("time", "holiday", "panel")

    @test panel_runtime.intercept_shape == :panel
    @test panel_runtime.sigma_shape == :panel
    @test panel_runtime.alpha_shape == :channel_panel
    @test panel_runtime.media_beta_shape == :channel_panel
    @test panel_runtime.seasonality_type == :fourier
    @test panel_runtime.seasonality_beta_shape == :feature_panel
    @test panel_runtime.npanels == fixture.npanels
    @test panel_runtime.nchannels == length(fixture.channel_columns)
    @test panel_runtime.nintercepts == fixture.npanels
    @test panel_runtime.nsigmas == fixture.npanels
    @test panel_runtime.nalpha == fixture.npanels * length(fixture.channel_columns)
    @test panel_runtime.nmedia_beta == fixture.npanels * length(fixture.channel_columns)
    @test panel_runtime.nseasonality_terms == 2 * fixture.yearly_fourier_order
    @test panel_runtime.nseasonality_beta == fixture.npanels * 2 * fixture.yearly_fourier_order
    @test panel_runtime.nholidays == 1
    @test panel_runtime.nholiday_beta == 1
    @test size(panel_runtime.holiday_features) == (fixture.ntime, 1, fixture.npanels)
    @test panel_runtime.holiday_features[:, 1, 1] == panel_runtime.holiday_features[:, 1, 2]
    @test panel_runtime.holiday_features[:, 1, 1] == panel_runtime.holiday_features[:, 1, 3]
    @test any(panel_runtime.holiday_features[:, 1, 1] .> 0)
    @test any(panel_runtime.holiday_features[:, 1, 4] .> 0)
    @test any(panel_runtime.holiday_features[:, 1, 7] .> 0)

    @test haskey(fixture.stage_directories, "metadata")
    @test fixture.stage_directories["metadata"] == "00_run_metadata"
    @test haskey(fixture.stage_directories, "optimisation")
end
