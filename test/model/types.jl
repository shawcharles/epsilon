using Epsilon
using Test

@testset "SamplerConfig" begin
    config = SamplerConfig(; draws = 1500, tune = 500, chains = 2, cores = 1, target_accept = 0.9, random_seed = 42)
    @test config.draws == 1500
    @test config.random_seed == 42

    @test_throws ArgumentError SamplerConfig(; draws = 0)
    @test_throws ArgumentError SamplerConfig(; target_accept = 1.0)
end

@testset "ModelConfig" begin
    config = ModelConfig(
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

    conversion = ModelConfig(
        date_column = "date",
        target_column = "orders",
        target_type = "Conversion",
        channel_columns = ["tv"],
    )
    @test conversion.target_type == "conversion"

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
    data = MMMData(
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
    @test_throws ArgumentError MMMData(
        dates = 1:2,
        target = [1.0, 2.0],
        channels = [1.0 -0.1; 2.0 3.0],
        channel_names = ["tv", "search"],
    )
    @test_throws ArgumentError MMMData(
        dates = 1:2,
        target = [1.0, 2.0],
        channels = [1.0; 2.0][:, :],
        channel_names = "tv",
    )
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
    @test_throws ArgumentError PanelMMMData(
        dates = 1:3,
        target = [1.0 2.0; 3.0 4.0; 5.0 6.0],
        channels = negative_channels,
        panel_names = ["north", "south"],
        channel_names = ["tv", "search"],
    )
    @test_throws ArgumentError PanelMMMData(
        dates = 1:3,
        target = [1.0 2.0; 3.0 4.0; 5.0 6.0],
        channels = channels,
        panel_names = "north",
        channel_names = ["tv", "search"],
    )
end
