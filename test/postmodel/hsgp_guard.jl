using Dates
using Epsilon
using Test

function _hsgp_guard_results()
    config = ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        time_varying_media = TimeVaryingMediaConfig(
            m = 2,
            L = 6.0,
            time_resolution = 7,
            eta_prior = EpsilonPrior("Exponential"; lam = 1.5),
            lengthscale_prior = EpsilonPrior("LogNormal"; mu = 0.0, sigma = 0.4),
        ),
    )
    data = MMMData(
        dates = Date[Date(2024, 1, 1), Date(2024, 1, 8)],
        target = [10.0, 11.0],
        channels = reshape([1.0, 2.0], :, 1),
        channel_names = ["tv"],
    )
    spec = build_model(TimeSeriesMMM(config, SamplerConfig(draws = 1, tune = 0, chains = 1, cores = 1), data))
    metadata = Epsilon._artifact_metadata("TimeSeriesMMM")
    results = InferenceResults(metadata, spec; posterior = :draws, observed_data = data)
    return metadata, spec, results
end

@testset "HSGP media postmodel calculation guard" begin
    metadata, spec, results = _hsgp_guard_results()
    for action in (
            () -> contribution_results(results),
            () -> decomposition_results(results),
            () -> response_curve_results(results; channel = "tv", grid = [0.0, 1.0]),
            () -> saturation_curve_results(results; channel = "tv", grid = [0.0, 1.0]),
            () -> adstock_curve_results(results; channel = "tv", grid = [0.0, 1.0]),
            () -> metric_results(results; channel = "tv", grid = [0.0, 1.0]),
        )
        error = try
            action()
            nothing
        catch err
            err
        end
        @test error isa ArgumentError
        @test occursin("HSGP media postmodel reporting is deferred", sprint(showerror, error))
    end

    curves = ResponseCurveResults(
        metadata,
        spec,
        spec.coordinate_metadata,
        "tv",
        [0.0, 1.0],
        nothing,
        1.0,
        reshape([0.0, 1.0], 1, :),
    )
    @test_throws ArgumentError metric_results(curves)
end
