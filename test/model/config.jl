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
                "type" => "delayed",
                "l_max" => 8,
                "priors" => Dict(
                    "alpha" => Dict(
                        "distribution" => "Beta",
                        "alpha" => 1,
                        "beta" => 3,
                        "dims" => ["channel"],
                    ),
                    "theta" => Dict(
                        "distribution" => "HalfNormal",
                        "sigma" => 1.0,
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
        "seasonality" => Dict(
            "type" => "fourier",
            "n_order" => 2,
            "priors" => Dict(
                "beta" => Dict(
                    "distribution" => "Laplace",
                    "mu" => 0.0,
                    "b" => 0.25,
                    "dims" => ["fourier_mode"],
                ),
            ),
        ),
        "trend" => Dict(
            "type" => "linear",
            "priors" => Dict(
                "beta" => Dict(
                    "distribution" => "Normal",
                    "mu" => 0.0,
                    "sigma" => 0.25,
                    "dims" => ["trend_term"],
                ),
            ),
        ),
        "events" => Dict(
            "columns" => ["promo", "holiday"],
            "priors" => Dict(
                "beta" => Dict(
                    "distribution" => "Normal",
                    "mu" => 0.0,
                    "sigma" => 0.5,
                    "dims" => ["event"],
                ),
            ),
        ),
        "controls" => Dict(
            "transform" => "standardize",
            "priors" => Dict(
                "beta" => Dict(
                    "distribution" => "Normal",
                    "mu" => 0.0,
                    "sigma" => 0.75,
                    "dims" => ["control"],
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
    @test model.adstock["priors"]["theta"] == EpsilonPrior("HalfNormal"; sigma = 1.0, dims = ("channel",))
    @test model.saturation["priors"]["lam"] == LogNormalPrior(; mean = 1.0, std = 0.5, dims = ("channel",))
    @test model.seasonality["type"] == "fourier"
    @test model.seasonality["n_order"] == 2
    @test model.seasonality["priors"]["beta"] ==
        EpsilonPrior("Laplace"; mu = 0.0, b = 0.25, dims = ("fourier_mode",))
    @test model.trend["type"] == "linear"
    @test model.trend["priors"]["beta"] ==
        EpsilonPrior("Normal"; mu = 0.0, sigma = 0.25, dims = ("trend_term",))
    @test model.events["columns"] == ["promo", "holiday"]
    @test model.events["priors"]["beta"] ==
        EpsilonPrior("Normal"; mu = 0.0, sigma = 0.5, dims = ("event",))
    @test model.controls["transform"] == "standardize"
    @test model.controls["priors"]["beta"] ==
        EpsilonPrior("Normal"; mu = 0.0, sigma = 0.75, dims = ("control",))
    @test haskey(model.extras, "validation")

    @test sampler.draws == 1500
    @test sampler.tune == 750
    @test sampler.chains == 2
    @test sampler.target_accept == 0.9
end

@testset "holidays config and relative path resolution" begin
    mktempdir() do tmpdir
        holidays_path = joinpath(tmpdir, "holidays.csv")
        write(
            holidays_path,
            "ds,holiday,country,year\n" *
                "01/01/2024,New Year,UK,2024\n" *
                "15/01/2024,Promo Day,UK,2024\n" *
                "29/01/2024,Promo Day,UK,2024\n",
        )

        raw = Dict(
            "data" => Dict("date_column" => "date"),
            "target" => Dict("column" => "revenue"),
            "media" => Dict("channels" => ["tv"]),
            "holidays" => Dict(
                "mode" => "auto",
                "path" => holidays_path,
                "countries" => "UK",
                "priors" => Dict(
                    "beta" => Dict(
                        "distribution" => "Normal",
                        "mu" => 0.0,
                        "sigma" => 0.5,
                        "dims" => ["holiday"],
                    ),
                ),
            ),
        )

        model = model_config_from_dict(raw)
        @test model.holidays["mode"] == "auto"
        @test model.holidays["path"] == holidays_path
        @test model.holidays["countries"] == ["UK"]
        @test model.holidays["priors"]["beta"] ==
            EpsilonPrior("Normal"; mu = 0.0, sigma = 0.5, dims = ("holiday",))

        config_path = joinpath(tmpdir, "holiday_config.yml")
        write(
            config_path,
            """
            data:
              date_column: date

            target:
              column: revenue

            media:
              channels: [tv]

            holidays:
              mode: auto
              path: holidays.csv
              countries: UK
            """,
        )

        loaded = load_public_config(config_path)
        @test loaded.model_config.holidays["path"] == holidays_path
        @test loaded.raw["holidays"]["path"] == holidays_path

        coexisting = model_config_from_dict(
            Dict(
                "data" => Dict("date_column" => "date"),
                "target" => Dict("column" => "revenue"),
                "media" => Dict("channels" => ["tv"]),
                "events" => Dict("columns" => ["promo"]),
                "holidays" => Dict(
                    "mode" => "auto",
                    "path" => holidays_path,
                    "countries" => ["UK"],
                ),
            ),
        )
        @test coexisting.events["columns"] == ["promo"]
        @test coexisting.holidays["mode"] == "auto"

        @test_throws ModelConfigError model_config_from_dict(
            Dict(
                "data" => Dict("date_column" => "date"),
                "target" => Dict("column" => "revenue"),
                "media" => Dict("channels" => ["tv"]),
                "events" => Dict(
                    "windows" => [Dict("name" => "Promo Day", "start_date" => "2024-01-15")],
                ),
                "holidays" => Dict(
                    "mode" => "auto",
                    "path" => holidays_path,
                    "countries" => ["UK"],
                ),
            ),
        )
    end
end

@testset "load_public_config" begin
    loaded = load_public_config(joinpath(@__DIR__, "..", "fixtures", "public_config.yml"))
    @test loaded.model_config.target_column == "revenue"
    @test loaded.model_config.channel_columns == ["tv", "search"]
    @test loaded.model_config.controls["transform"] == "standardize"
    @test loaded.model_config.controls["priors"]["beta"] ==
        EpsilonPrior("Normal"; mu = 0.0, sigma = 0.75, dims = ("control",))
    @test loaded.sampler_config.draws == 1200
    @test loaded.model_config.saturation["priors"]["lam"] == LogNormalPrior(; mean = 1.2, std = 0.4, dims = ("channel",))
end

@testset "config merging precedence and semantics" begin
    raw = Dict(
        "data" => Dict("date_column" => "date"),
        "target" => Dict("column" => "sales"),
        "media" => Dict(
            "channels" => ["tv", "search"],
            "adstock" => Dict("type" => "geometric"),
        ),
        "fit" => Dict("draws" => 1200),
    )
    defaults = Dict(
        "target" => Dict("type" => "revenue"),
        "media" => Dict(
            "controls" => ["price_index"],
            "adstock" => Dict("l_max" => 6, "priors" => Dict("alpha" => Dict("distribution" => "Beta", "alpha" => 1, "beta" => 3))),
            "saturation" => Dict("type" => "logistic"),
        ),
        "fit" => Dict("chains" => 4, "target_accept" => 0.8),
    )
    overrides = Dict(
        "media" => Dict(
            "controls" => ["promo_flag"],
            "adstock" => Dict("l_max" => 12),
        ),
        "fit" => Dict("target_accept" => 0.95),
        "dimensions" => Dict("panel" => ["geo"]),
    )

    model = model_config_from_dict(raw; defaults, overrides)
    sampler = sampler_config_from_dict(raw; defaults, overrides)
    loaded = load_public_config(joinpath(@__DIR__, "..", "fixtures", "public_config.yml"); defaults, overrides)

    @test model.target_type == "revenue"
    @test model.control_columns == ["promo_flag"]
    @test model.adstock["type"] == "geometric"
    @test model.adstock["l_max"] == 12
    @test model.adstock["priors"]["alpha"] == EpsilonPrior("Beta"; alpha = 1, beta = 3)
    @test model.saturation["type"] == "logistic"
    @test model.dims == ("geo",)

    @test sampler.draws == 1200
    @test sampler.chains == 4
    @test sampler.target_accept == 0.95

    @test loaded.raw["fit"]["target_accept"] == 0.95
    @test loaded.raw["media"]["controls"] == ["promo_flag"]
end

@testset "config validation errors" begin
    @test_throws ModelConfigError model_config_from_dict(
        Dict(
            "data" => Dict("date_column" => "date"),
            "target" => Dict("column" => "orders", "type" => "conversions"),
            "media" => Dict("channels" => ["tv"]),
        ),
    )

    @test_throws ModelConfigError model_config_from_dict(
        Dict(
            "data" => Dict("date_column" => "date"),
            "target" => Dict("column" => "revenue"),
            "media" => Dict("channels" => "tv"),
        ),
    )

    @test_throws ModelConfigError model_config_from_dict(
        Dict(
            "data" => Dict("date_column" => "date"),
            "target" => Dict("column" => "revenue"),
            "media" => Dict("channels" => [1]),
        ),
    )

    @test_throws ModelConfigError model_config_from_dict(
        Dict(
            "data" => Dict("date_column" => "date"),
            "target" => Dict("column" => "revenue"),
            "media" => Dict(
                "channels" => ["tv"],
                "adstock" => Dict("type" => "unsupported"),
            ),
        ),
    )

    @test_throws ModelConfigError model_config_from_dict(
        Dict(
            "data" => Dict("date_column" => "date"),
            "target" => Dict("column" => "revenue"),
            "media" => Dict(
                "channels" => ["tv"],
                "adstock" => Dict("type" => "geometric", "l_max" => "12"),
            ),
        ),
    )

    @test_throws ModelConfigError model_config_from_dict(
        Dict(
            "data" => Dict("date_column" => "date"),
            "target" => Dict("column" => "revenue"),
            "media" => Dict(
                "channels" => ["tv"],
                "adstock" => Dict("type" => "geometric", "normalize" => 1),
            ),
        ),
    )

    @test_throws ModelConfigError model_config_from_dict(
        Dict(
            "data" => Dict("date_column" => "date"),
            "target" => Dict("column" => "revenue"),
            "media" => Dict(
                "channels" => ["tv"],
                "saturation" => Dict("type" => "unsupported"),
            ),
        ),
    )

    @test_throws ModelConfigError model_config_from_dict(
        Dict(
            "data" => Dict("date_column" => "date"),
            "target" => Dict("column" => "revenue"),
            "media" => Dict(
                "channels" => ["tv"],
                "saturation" => Dict(
                    "type" => "logistic",
                    "priors" => Dict(
                        "alpha" => Dict("distribution" => "HalfNormal", "sigma" => 1.0),
                    ),
                ),
            ),
        ),
    )

    @test_throws ModelConfigError model_config_from_dict(
        Dict(
            "data" => Dict("date_column" => "date"),
            "target" => Dict("column" => "revenue"),
            "media" => Dict("channels" => ["tv"]),
            "seasonality" => Dict("type" => "fourier"),
        ),
    )

    @test_throws ModelConfigError model_config_from_dict(
        Dict(
            "data" => Dict("date_column" => "date"),
            "target" => Dict("column" => "revenue"),
            "media" => Dict("channels" => ["tv"]),
            "events" => Dict("columns" => []),
        ),
    )

    @test_throws ModelConfigError model_config_from_dict(
        Dict(
            "data" => Dict("date_column" => "date"),
            "target" => Dict("column" => "revenue"),
            "media" => Dict("channels" => ["tv"]),
            "controls" => Dict("transform" => "standardize"),
        ),
    )

    @test_throws ModelConfigError model_config_from_dict(
        Dict(
            "data" => Dict("date_column" => "date"),
            "target" => Dict("column" => "revenue"),
            "media" => Dict("channels" => ["tv"]),
            "seasonality" => Dict("type" => "fourier", "n_order" => 2, "priors" => []),
        ),
    )

    @test_throws ModelConfigError model_config_from_dict(
        Dict(
            "data" => Dict("date_column" => "date"),
            "target" => Dict("column" => "revenue"),
            "media" => Dict("channels" => ["tv"], "controls" => ["price_index"]),
            "controls" => Dict("transform" => "standardize", "priors" => []),
        ),
    )

    @test_throws ModelConfigError model_config_from_dict(
        Dict(
            "data" => Dict("date_column" => "date"),
            "target" => Dict("column" => "revenue"),
            "media" => Dict("channels" => ["tv"], "controls" => ["price_index"]),
            "priors" => Dict(
                "beta_controls" => Dict("distribution" => "Normal", "mu" => 0.0, "sigma" => 1.0),
            ),
        ),
    )

    @test_throws ModelConfigError sampler_config_from_dict(Dict("fit" => Dict("draws" => "many")))
end

@testset "generated events window config" begin
    raw = Dict(
        "data" => Dict("date_column" => "date"),
        "target" => Dict("column" => "revenue"),
        "media" => Dict("channels" => ["tv"]),
        "events" => Dict(
            "windows" => [
                Dict("name" => "promo", "start_date" => "2024-01-08", "end_date" => "2024-01-15"),
                Dict("name" => "holiday", "start_date" => "2024-01-29"),
            ],
            "priors" => Dict(
                "beta" => Dict(
                    "distribution" => "Normal",
                    "mu" => 0.0,
                    "sigma" => 0.5,
                    "dims" => ["event"],
                ),
            ),
        ),
    )

    model = model_config_from_dict(raw)
    @test haskey(model.events, "windows")
    @test model.events["windows"][1]["name"] == "promo"
    @test model.events["windows"][2]["start_date"] == "2024-01-29"
    @test model.events["priors"]["beta"] ==
        EpsilonPrior("Normal"; mu = 0.0, sigma = 0.5, dims = ("event",))

    @test_throws ModelConfigError model_config_from_dict(
        Dict(
            "data" => Dict("date_column" => "date"),
            "target" => Dict("column" => "revenue"),
            "media" => Dict("channels" => ["tv"]),
            "events" => Dict(
                "columns" => ["promo"],
                "windows" => [Dict("name" => "holiday", "start_date" => "2024-01-01")],
            ),
        ),
    )

    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "orders",
        target_type = "conversions",
        channel_columns = ["tv"],
    )
end

@testset "changepoint trend config" begin
    raw = Dict(
        "data" => Dict("date_column" => "date"),
        "target" => Dict("column" => "revenue"),
        "media" => Dict("channels" => ["tv"]),
        "trend" => Dict(
            "type" => "changepoint",
            "n_changepoints" => 4,
            "priors" => Dict(
                "delta" => Dict(
                    "distribution" => "Laplace",
                    "mu" => 0.0,
                    "b" => 0.15,
                    "dims" => ["trend_term"],
                ),
            ),
        ),
    )

    model = model_config_from_dict(raw)
    @test model.trend["type"] == "changepoint"
    @test model.trend["n_changepoints"] == 4
    @test model.trend["priors"]["delta"] ==
        EpsilonPrior("Laplace"; mu = 0.0, b = 0.15, dims = ("trend_term",))

    @test_throws ModelConfigError model_config_from_dict(
        Dict(
            "data" => Dict("date_column" => "date"),
            "target" => Dict("column" => "revenue"),
            "media" => Dict("channels" => ["tv"]),
            "trend" => Dict("type" => "changepoint"),
        ),
    )

    @test_throws ModelConfigError model_config_from_dict(
        Dict(
            "data" => Dict("date_column" => "date"),
            "target" => Dict("column" => "revenue"),
            "media" => Dict("channels" => ["tv"]),
            "trend" => Dict("type" => "changepoint", "n_changepoints" => 0),
        ),
    )

    @test_throws ModelConfigError model_config_from_dict(
        Dict(
            "data" => Dict("date_column" => "date"),
            "target" => Dict("column" => "revenue"),
            "media" => Dict("channels" => ["tv"]),
            "trend" => Dict("type" => "linear", "include_intercept" => true),
        ),
    )
end

@testset "calibration config parses bounded YAML payloads" begin
    raw = Dict(
        "data" => Dict("date_column" => "date"),
        "target" => Dict("column" => "revenue"),
        "media" => Dict(
            "channels" => ["tv", "search"],
            "saturation" => Dict("type" => "logistic"),
        ),
        "calibration" => Dict(
            "steps" => [
                Dict("method" => "add_lift_test_measurements"),
                Dict("method" => "add_cost_per_target_calibration"),
            ],
            "lift_test" => Dict(
                "channel" => ["tv", "search"],
                "x" => [100.0, 50.0],
                "delta_x" => [20.0, -10.0],
                "delta_y" => [12.0, -5.0],
                "sigma" => [3.0, 2.0],
            ),
            "cost_per_target" => Dict(
                "gathered_cpt" => [2.0],
                "targets" => [1.5],
                "sigma" => [0.25],
            ),
        ),
    )

    model = model_config_from_dict(raw)
    calibration = model.extras["calibration"]
    @test calibration isa TimeSeriesCalibrationInput
    @test [step.method for step in calibration.steps] == [
        "add_lift_test_measurements",
        "add_cost_per_target_calibration",
    ]
    @test calibration.lift_test == LiftTestCalibrationRows(
        channel = ["tv", "search"],
        x = [100.0, 50.0],
        delta_x = [20.0, -10.0],
        delta_y = [12.0, -5.0],
        sigma = [3.0, 2.0],
    )
    @test calibration.cost_per_target == CostPerTargetCalibrationRows(
        gathered_cpt = [2.0],
        targets = [1.5],
        sigma = [0.25],
    )

    mktempdir() do tmpdir
        config_path = joinpath(tmpdir, "calibrated.yml")
        write(
            config_path,
            """
            data:
              date_column: date
            target:
              column: revenue
            media:
              channels: [tv]
              saturation:
                type: logistic
            fit:
              backend: mcmc
            calibration:
              steps:
                - method: add_lift_test_measurements
              lift_test:
                channel: [tv]
                x: [100.0]
                delta_x: [20.0]
                delta_y: [12.0]
                sigma: [3.0]
            """,
        )

        loaded = load_public_config(config_path)
        loaded_calibration = loaded.model_config.extras["calibration"]
        @test loaded_calibration isa TimeSeriesCalibrationInput
        @test loaded_calibration.lift_test == LiftTestCalibrationRows(
            channel = ["tv"],
            x = [100.0],
            delta_x = [20.0],
            delta_y = [12.0],
            sigma = [3.0],
        )
    end

    uncalibrated = model_config_from_dict(
        Dict(
            "data" => Dict("date_column" => "date"),
            "target" => Dict("column" => "revenue"),
            "media" => Dict("channels" => ["tv"]),
        ),
    )
    @test !haskey(uncalibrated.extras, "calibration")
end

@testset "calibration config rejects unsupported or malformed payloads" begin
    base = Dict(
        "data" => Dict("date_column" => "date"),
        "target" => Dict("column" => "revenue"),
        "media" => Dict("channels" => ["tv"], "saturation" => Dict("type" => "logistic")),
    )
    lift_rows = Dict(
        "channel" => ["tv"],
        "x" => [100.0],
        "delta_x" => [20.0],
        "delta_y" => [12.0],
        "sigma" => [3.0],
    )

    @test_throws ModelConfigError model_config_from_dict(
        merge(
            copy(base),
            Dict(
                "dimensions" => Dict("panel" => ["geo"]),
                "calibration" => Dict(
                    "steps" => [Dict("method" => "add_lift_test_measurements")],
                    "lift_test" => lift_rows,
                ),
            ),
        ),
    )
    @test_throws ModelConfigError model_config_from_dict(
        merge(
            copy(base),
            Dict(
                "fit" => Dict("backend" => "vi"),
                "calibration" => Dict(
                    "steps" => [Dict("method" => "add_lift_test_measurements")],
                    "lift_test" => lift_rows,
                ),
            ),
        ),
    )
    @test_throws ModelConfigError model_config_from_dict(
        merge(
            copy(base),
            Dict(
                "calibration" => Dict(
                    "steps" => [
                        Dict(
                            "method" => "add_lift_test_measurements",
                            "params" => Dict("dist" => "Gamma"),
                        ),
                    ],
                    "lift_test" => lift_rows,
                ),
            ),
        ),
    )
    @test_throws ModelConfigError model_config_from_dict(
        merge(
            copy(base),
            Dict(
                "calibration" => Dict(
                    "steps" => [
                        Dict("method" => "add_lift_test_measurements"),
                        Dict("method" => "add_lift_test_measurements"),
                    ],
                    "lift_test" => lift_rows,
                ),
            ),
        ),
    )
    @test_throws ModelConfigError model_config_from_dict(
        merge(copy(base), Dict("calibration" => Dict("steps" => [Dict("method" => "add_lift_test_measurements")]))),
    )
    @test_throws ModelConfigError model_config_from_dict(
        merge(
            copy(base),
            Dict(
                "calibration" => Dict(
                    "steps" => [Dict("method" => "add_lift_test_measurements")],
                    "lift_test" => merge(copy(lift_rows), Dict("sigma" => [0.0])),
                ),
            ),
        ),
    )
    @test_throws ModelConfigError model_config_from_dict(
        merge(copy(base), Dict("calibration" => Dict("steps" => []))),
    )
    @test_throws ModelConfigError model_config_from_dict(
        merge(
            copy(base),
            Dict(
                "calibration" => Dict(
                    "steps" => [Dict("method" => "add_lift_test_measurements")],
                    "lift_test" => merge(copy(lift_rows), Dict("x" => ["100.0"])),
                ),
            ),
        ),
    )
    @test_throws ModelConfigError model_config_from_dict(
        merge(
            copy(base),
            Dict(
                "calibration" => Dict(
                    "steps" => [Dict("method" => "add_lift_test_measurements")],
                    "lift_test" => merge(copy(lift_rows), Dict("unexpected" => [1.0])),
                ),
            ),
        ),
    )
end

@testset "time-varying media configuration remains programmatic-only" begin
    time_varying_media = TimeVaryingMediaConfig(
        m = 3,
        L = 6.0,
        time_resolution = 7,
        eta_prior = EpsilonPrior("Exponential"; lam = 1.0),
        lengthscale_prior = EpsilonPrior("HalfNormal"; sigma = 2.0),
    )
    typed_extras = Dict{String, Any}("time_varying_media" => time_varying_media)
    config = ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        extras = typed_extras,
    )
    @test config.extras["time_varying_media"] === time_varying_media
    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        extras = typed_extras,
        time_varying_media = time_varying_media,
    )

    base = Dict(
        "data" => Dict("date_column" => "date"),
        "target" => Dict("column" => "revenue"),
        "media" => Dict("channels" => ["tv"]),
    )
    @test_throws ModelConfigError model_config_from_dict(
        merge(copy(base), Dict("time_varying_media" => Dict("m" => 3))),
    )
    @test_throws ModelConfigError model_config_from_dict(
        merge(copy(base), Dict("media" => Dict("channels" => ["tv"], "time_varying_media" => Dict("m" => 3)))),
    )
    @test_throws ModelConfigError model_config_from_dict(
        base;
        defaults = Dict("time_varying_media" => Dict("m" => 3)),
    )
    @test_throws ModelConfigError model_config_from_dict(
        base;
        overrides = Dict("media" => Dict("time_varying_media" => Dict("m" => 3))),
    )
end
