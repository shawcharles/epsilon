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
        dims = ("geo",),
        adstock = Dict("type" => "geometric", "l_max" => 8),
        saturation = Dict("type" => "logistic"),
        priors = Dict("intercept" => EpsilonPrior("Normal"; mu = 0.0, sigma = 1.0)),
        extras = Dict("validation" => Dict("enabled" => true)),
    )

    @test config.channel_columns == ["tv", "search"]
    @test config.dims == ("geo",)
    @test haskey(config.extras, "validation")

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
end

@testset "MMMData" begin
    data = MMMData(
        dates = 1:3,
        target = [10.0, 12.0, 14.0],
        channels = [1.0 2.0; 3.0 4.0; 5.0 6.0],
        channel_names = ["tv", "search"],
        controls = [7.0; 8.0; 9.0][:, :],
        control_names = ["price_index"],
    )

    @test nobs(data) == 3
    @test data.channel_names == ["tv", "search"]

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
end
