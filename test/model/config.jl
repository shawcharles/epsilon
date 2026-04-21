using Epsilon
using Test

@testset "model_config_from_dict" begin
    raw = Dict(
        "data" => Dict("date_column" => "date"),
        "target" => Dict("column" => "revenue", "type" => "revenue"),
        "dimensions" => Dict("panel" => ["geo"]),
        "media" => Dict(
            "channels" => ["tv", "search"],
            "controls" => ["price_index"],
            "adstock" => Dict(
                "type" => "geometric",
                "l_max" => 8,
                "priors" => Dict(
                    "alpha" => Dict(
                        "distribution" => "Beta",
                        "alpha" => 1,
                        "beta" => 3,
                        "dims" => ["channel"],
                    ),
                ),
            ),
            "saturation" => Dict(
                "type" => "logistic",
                "priors" => Dict(
                    "lam" => Dict(
                        "special_prior" => "LogNormalPrior",
                        "kwargs" => Dict("mu" => 1.0, "sigma" => 0.5),
                        "dims" => ["channel"],
                    ),
                ),
            ),
        ),
        "priors" => Dict(
            "intercept" => Dict("distribution" => "Normal", "mu" => 0.0, "sigma" => 2.0),
        ),
        "fit" => Dict("draws" => 1500, "tune" => 750, "chains" => 2, "target_accept" => 0.9),
        "validation" => Dict("enabled" => true),
    )

    model = model_config_from_dict(raw)
    sampler = sampler_config_from_dict(raw)

    @test model.date_column == "date"
    @test model.channel_columns == ["tv", "search"]
    @test model.dims == ("geo",)
    @test model.priors["intercept"] == EpsilonPrior("Normal"; mu = 0.0, sigma = 2.0)
    @test model.adstock["priors"]["alpha"] == EpsilonPrior("Beta"; alpha = 1, beta = 3, dims = ("channel",))
    @test model.saturation["priors"]["lam"] == LogNormalPrior(; mean = 1.0, std = 0.5, dims = ("channel",))
    @test haskey(model.extras, "validation")

    @test sampler.draws == 1500
    @test sampler.tune == 750
    @test sampler.chains == 2
    @test sampler.target_accept == 0.9
end

@testset "load_public_config" begin
    loaded = load_public_config(joinpath(@__DIR__, "..", "fixtures", "public_config.yml"))
    @test loaded.model_config.target_column == "revenue"
    @test loaded.model_config.channel_columns == ["tv", "search"]
    @test loaded.sampler_config.draws == 1200
    @test loaded.model_config.saturation["priors"]["lam"] == LogNormalPrior(; mean = 1.2, std = 0.4, dims = ("channel",))
end

@testset "config validation errors" begin
    @test_throws ModelConfigError model_config_from_dict(
        Dict(
            "data" => Dict("date_column" => "date"),
            "target" => Dict("column" => "revenue"),
            "media" => Dict("channels" => "tv"),
        ),
    )

    @test_throws ModelConfigError sampler_config_from_dict(Dict("fit" => Dict("draws" => "many")))
end
