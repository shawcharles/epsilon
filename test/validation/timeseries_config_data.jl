using Dates

include(joinpath(@__DIR__, "..", "fixtures", "golden", "timeseries", "config_data.jl"))

const _TIMESERIES_FIXTURE_DIR = joinpath(@__DIR__, "..", "fixtures", "golden", "timeseries")

@testset "timeseries golden fixture config/data spine" begin
    fixture = GOLDEN_TIMESERIES_CONFIG_DATA
    config_path = joinpath(_TIMESERIES_FIXTURE_DIR, "config.yml")
    dataset_path = joinpath(_TIMESERIES_FIXTURE_DIR, "dataset.csv")
    holidays_path = joinpath(_TIMESERIES_FIXTURE_DIR, "holidays.csv")

    loaded = _load_validation_fixture_config(config_path; holidays_path)
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
    @test config.saturation["type"] == fixture.saturation_type
    @test sort!(collect(keys(config.saturation["priors"]))) == ["lam"]
    @test haskey(config.priors, "beta_media")
    @test config.priors["beta_media"] == EpsilonPrior("HalfNormal"; sigma = 1, dims = ("channel",))

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

    data = _load_validation_time_series_dataset(dataset_path, config)
    @test nobs(data) == fixture.nobs
    @test string.(data.dates) == fixture.dates
    @test data.channel_names == fixture.channel_columns
    @test data.channels ≈ fixture.raw_channels
    @test data.target ≈ fixture.raw_target
    @test isnothing(data.controls)
    @test isnothing(data.events)

    model = TimeSeriesMMM(config, sampler, data)
    spec = build_model(model)
    @test spec.model_kind == :time_series_mmm
    @test spec.nobs == fixture.nobs
    @test spec.nchannels == length(fixture.channel_columns)
    @test spec.ncontrols == 0
    @test spec.channel_scale ≈ fixture.channel_scale
    @test spec.target_scale ≈ fixture.target_scale
    @test spec.coordinate_metadata.coordinates["channel"] == fixture.channel_columns
    @test spec.coordinate_metadata.coordinates["fourier_mode"] ==
        ["sin_1", "sin_2", "cos_1", "cos_2"]
    @test spec.coordinate_metadata.coordinates["holiday"] == ["holiday"]
    @test spec.coordinate_metadata.named_dims["beta_media"] == ("channel",)
    @test spec.coordinate_metadata.named_dims["seasonality_features"] ==
        ("observation", "fourier_mode")

    scaled_channels = data.channels ./ reshape(spec.channel_scale, 1, :)
    @test scaled_channels ≈ fixture.scaled_channels

    adstocked = geometric_adstock(
        scaled_channels,
        fixture.transform_alpha,
        fixture.adstock_l_max;
        normalize = fixture.adstock_normalize,
        axis = 1,
        mode = :after,
    )
    @test adstocked ≈ fixture.adstocked_media

    saturated = centered_logistic_saturation(adstocked, fixture.transform_lam)
    @test saturated ≈ fixture.saturated_media

    @test haskey(fixture.stage_directories, "metadata")
    @test fixture.stage_directories["metadata"] == "00_run_metadata"
    @test haskey(fixture.stage_directories, "optimisation")
end
