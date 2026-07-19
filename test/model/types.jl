using Epsilon
using Test

const _SAMPLER_CONFIG_DEPRECATION =
    "Epsilon.validate_sampler_config is deprecated as a public API; use SamplerConfig construction or load_sampler_config instead. The function remains exported for this release and may be unexported before v1."
const _MODEL_CONFIG_DEPRECATION =
    "Epsilon.validate_model_config is deprecated as a public API; use ModelConfig construction or load_model_config instead. The function remains exported for this release and may be unexported before v1."
const _MMM_DATA_DEPRECATION =
    "Epsilon.validate_mmm_data is deprecated as a public API; use MMMData construction before building TimeSeriesMMM instead. The function remains exported for this release and may be unexported before v1."

function _deprecated_argument_error_message(warning::AbstractString, thunk::Function)
    err = @test_logs (:warn, warning) try
        thunk()
    catch caught
        caught
    end
    @test err isa ArgumentError
    return err.msg
end

function _types_argument_error_message(thunk::Function)
    try
        thunk()
    catch err
        err isa ArgumentError || rethrow()
        return err.msg
    end
    error("expected ArgumentError")
end

@testset "SamplerConfig" begin
    config = @test_logs SamplerConfig(; draws = 1500, tune = 500, chains = 2, cores = 1, target_accept = 0.9, random_seed = 42)
    @test config.draws == 1500
    @test config.random_seed == 42
    @test (@test_logs (:warn, _SAMPLER_CONFIG_DEPRECATION) validate_sampler_config(config)) === nothing

    invalid = SamplerConfig(0, 1000, 4, 4, 0.8, nothing, true, true)
    @test _deprecated_argument_error_message(
        _SAMPLER_CONFIG_DEPRECATION,
        () -> validate_sampler_config(invalid),
    ) == "draws must be positive"

    @test_throws ArgumentError SamplerConfig(; draws = 0)
    @test_throws ArgumentError SamplerConfig(; target_accept = 1.0)
end

@testset "ModelConfig" begin
    config = @test_logs ModelConfig(
        date_column = "date",
        target_column = "revenue",
        target_type = "revenue",
        channel_columns = ["tv", "search"],
        control_columns = ["price_index"],
        controls = Dict("transform" => "standardize"),
        events = Dict("columns" => ["promo", "holiday"]),
        dims = ("geo",),
        adstock = Dict("type" => "geometric", "l_max" => 8),
        saturation = Dict("type" => "logistic"),
        priors = Dict("intercept" => EpsilonPrior("Normal"; mu = 0.0, sigma = 1.0)),
        extras = Dict("validation" => Dict("enabled" => true)),
    )

    @test config.channel_columns == ["tv", "search"]
    @test config.dims == ("geo",)
    @test config.controls["transform"] == "standardize"
    @test config.events["columns"] == ["promo", "holiday"]
    @test haskey(config.extras, "validation")
    @test config.target_type == "revenue"
    @test (@test_logs (:warn, _MODEL_CONFIG_DEPRECATION) validate_model_config(config)) === nothing

    conversion = @test_logs ModelConfig(
        date_column = "date",
        target_column = "orders",
        target_type = "Conversion",
        channel_columns = ["tv"],
    )
    @test conversion.target_type == "conversion"

    invalid = ModelConfig(
        "",
        "revenue",
        "revenue",
        ["tv"],
        String[],
        (),
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
    )
    @test _deprecated_argument_error_message(
        _MODEL_CONFIG_DEPRECATION,
        () -> validate_model_config(invalid),
    ) == "date_column must not be empty"

    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv", "tv"],
    )
    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        control_columns = ["tv"],
    )
    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        control_columns = ["revenue"],
    )
    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        control_columns = ["date"],
    )
    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "orders",
        target_type = "conversions",
        channel_columns = ["tv"],
    )
    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = "tv",
    )
    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        dims = "geo",
    )
end

@testset "MMMData" begin
    data = @test_logs MMMData(
        dates = 1:3,
        target = [10.0, 12.0, 14.0],
        channels = [1.0 2.0; 3.0 4.0; 5.0 6.0],
        channel_names = ["tv", "search"],
        controls = [7.0; 8.0; 9.0][:, :],
        control_names = ["price_index"],
        events = [1.0 0.0; 0.0 1.0; 0.0 0.0],
        event_names = ["promo", "holiday"],
    )

    @test nobs(data) == 3
    @test ntime(data) == 3
    @test data.channel_names == ["tv", "search"]
    @test data.event_names == ["promo", "holiday"]
    @test (@test_logs (:warn, _MMM_DATA_DEPRECATION) validate_mmm_data(data)) === nothing

    invalid = MMMData(
        1:3,
        [1.0, 2.0],
        [1.0; 2.0; 3.0][:, :],
        nothing,
        nothing,
        ["tv"],
        String[],
        String[],
    )
    @test _deprecated_argument_error_message(
        _MMM_DATA_DEPRECATION,
        () -> validate_mmm_data(invalid),
    ) == "dates and target must have matching length"

    @test_throws ArgumentError MMMData(
        dates = 1:3,
        target = [1.0, 2.0],
        channels = [1.0; 2.0; 3.0][:, :],
        channel_names = ["tv"],
    )
    @test_throws ArgumentError MMMData(
        dates = 1:2,
        target = [1.0, 2.0],
        channels = [1.0 2.0; 3.0 4.0],
        channel_names = ["tv"],
    )
    @test_throws ArgumentError MMMData(
        dates = 1:2,
        target = ["bad", "data"],
        channels = [1.0; 2.0][:, :],
        channel_names = ["tv"],
    )
    @test_throws ArgumentError MMMData(
        dates = 1:2,
        target = [1.0, 2.0],
        channels = Any["bad" 1.0; "data" 2.0],
        channel_names = ["tv", "search"],
    )
    @test_throws ArgumentError MMMData(
        dates = 1:2,
        target = [1.0, 2.0],
        channels = [1.0; 2.0][:, :],
        channel_names = ["tv"],
        controls = Any["bad"; 2.0][:, :],
        control_names = ["price_index"],
    )
    @test_throws ArgumentError MMMData(
        dates = 1:2,
        target = [1.0, 2.0],
        channels = [1.0; 2.0][:, :],
        channel_names = ["tv"],
        events = [1.0; 0.0][:, :],
        event_names = ["promo", "promo"],
    )
    @test_throws ArgumentError MMMData(
        dates = 1:2,
        target = [1.0, 2.0],
        channels = [1.0; 2.0][:, :],
        channel_names = ["tv"],
        events = Any["bad"; 0.0][:, :],
        event_names = ["promo"],
    )
    @test_throws ArgumentError MMMData(
        dates = Int[],
        target = Float64[],
        channels = zeros(0, 1),
        channel_names = ["tv"],
    )
    @test_throws ArgumentError MMMData(
        dates = 1:2,
        target = [1.0, NaN],
        channels = [1.0; 2.0][:, :],
        channel_names = ["tv"],
    )
    @test_throws ArgumentError MMMData(
        dates = 1:2,
        target = [1.0, 2.0],
        channels = [1.0 Inf; 2.0 3.0],
        channel_names = ["tv", "search"],
    )
    @test _types_argument_error_message(
        () -> MMMData(
            dates = 1:2,
            target = [1.0, 2.0],
            channels = [1.0 -0.1; 2.0 3.0],
            channel_names = ["tv", "search"],
        ),
    ) == "channels must contain only nonnegative values"
    @test_throws ArgumentError MMMData(
        dates = 1:2,
        target = [1.0, 2.0],
        channels = [1.0; 2.0][:, :],
        channel_names = "tv",
    )
end

@testset "Config loaders do not warn for replacement workflows" begin
    mktempdir() do dir
        path = joinpath(dir, "config.yml")
        write(
            path,
            """
            data:
              date_column: date
            target:
              column: revenue
              type: revenue
            media:
              channels:
                - tv
                - search
            fit:
              draws: 1500
              tune: 500
              chains: 2
              cores: 1
              target_accept: 0.9
              random_seed: 42
            """,
        )

        @test (@test_logs load_model_config(path)) isa ModelConfig
        @test (@test_logs load_sampler_config(path)) isa SamplerConfig
    end
end

@testset "PanelMMMData" begin
    channels = Array{Float64}(undef, 3, 2, 2)
    channels[:, :, 1] = [1.0 0.5; 2.0 1.0; 3.0 1.5]
    channels[:, :, 2] = [0.8 0.4; 1.6 0.8; 2.4 1.2]
    data = PanelMMMData(
        dates = 1:3,
        target = [10.0 8.0; 12.0 9.0; 14.0 11.0],
        channels = channels,
        panel_names = ["north", "south"],
        channel_names = ["tv", "search"],
    )

    @test nobs(data) == 6
    @test ntime(data) == 3
    @test npanels(data) == 2
    @test npanel_observations(data) == 6
    @test data.panel_names == ["north", "south"]
    @test data.channel_names == ["tv", "search"]

    @test_throws ArgumentError PanelMMMData(
        dates = 1:2,
        target = [1.0 2.0; 3.0 4.0; 5.0 6.0],
        channels = channels,
        panel_names = ["north", "south"],
        channel_names = ["tv", "search"],
    )
    @test_throws ArgumentError PanelMMMData(
        dates = 1:3,
        target = [1.0 2.0; 3.0 4.0; 5.0 6.0],
        channels = [1.0 2.0; 3.0 4.0; 5.0 6.0],
        panel_names = ["north", "south"],
        channel_names = ["tv", "search"],
    )
    @test_throws ArgumentError PanelMMMData(
        dates = 1:3,
        target = Any["bad" 2.0; 3.0 4.0; 5.0 6.0],
        channels = channels,
        panel_names = ["north", "south"],
        channel_names = ["tv", "search"],
    )
    @test_throws ArgumentError PanelMMMData(
        dates = 1:3,
        target = [1.0 2.0; 3.0 4.0; 5.0 6.0],
        channels = channels,
        panel_names = ["north", "north"],
        channel_names = ["tv", "search"],
    )
    @test_throws ArgumentError PanelMMMData(
        dates = Int[],
        target = zeros(0, 2),
        channels = zeros(0, 1, 2),
        panel_names = ["north", "south"],
        channel_names = ["tv"],
    )
    @test_throws ArgumentError PanelMMMData(
        dates = 1:3,
        target = [1.0 2.0; 3.0 NaN; 5.0 6.0],
        channels = channels,
        panel_names = ["north", "south"],
        channel_names = ["tv", "search"],
    )
    @test_throws ArgumentError PanelMMMData(
        dates = 1:3,
        target = [1.0 2.0; 3.0 4.0; 5.0 6.0],
        channels = fill(Inf, 3, 2, 2),
        panel_names = ["north", "south"],
        channel_names = ["tv", "search"],
    )
    negative_channels = copy(channels)
    negative_channels[1, 1, 1] = -0.1
    @test _types_argument_error_message(
        () -> PanelMMMData(
            dates = 1:3,
            target = [1.0 2.0; 3.0 4.0; 5.0 6.0],
            channels = negative_channels,
            panel_names = ["north", "south"],
            channel_names = ["tv", "search"],
        ),
    ) == "channels must contain only nonnegative values"
    @test_throws ArgumentError PanelMMMData(
        dates = 1:3,
        target = [1.0 2.0; 3.0 4.0; 5.0 6.0],
        channels = channels,
        panel_names = "north",
        channel_names = ["tv", "search"],
    )
end
