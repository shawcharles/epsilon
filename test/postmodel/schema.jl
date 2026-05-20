using Epsilon
using Test

function _postmodel_schema_metadata(model_type::AbstractString)
    return ModelArtifactMetadata(
        1,
        epsilon_version(),
        VERSION,
        "2026-05-19T00:00:00Z",
        String(model_type),
        :turing,
        :fit,
    )
end

function _postmodel_schema_spec(kind::Symbol, coordinate_metadata::ModelCoordinateMetadata)
    is_panel = kind === :panel_mmm
    return MMMModelSpec(
        kind,
        is_panel ? 8 : 2,
        1,
        0,
        coordinate_metadata.panel_dims,
        coordinate_metadata,
        "revenue",
        "revenue",
        ["tv"],
        String[],
        Dict("tv" => 1),
        Dict{String, Int}(),
        is_panel ? ones(1, 4) : [1.0],
        is_panel ? ones(4) : 1.0,
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
        Dict{String, Any}(),
    )
end

@testset "post-model artifact axis contracts" begin
    ts_coordinates = ModelCoordinateMetadata(
        "time",
        (),
        Dict("time" => ["1", "2"]),
        Dict("target" => ("time",)),
    )
    ts_spec = _postmodel_schema_spec(:time_series_mmm, ts_coordinates)
    ts_metadata = _postmodel_schema_metadata("TimeSeriesMMM")

    valid_ts_contributions = ContributionResults(
        ts_metadata,
        ts_spec,
        ts_coordinates,
        1:2,
        [1.0, 2.0],
        ["intercept", "media:tv"],
        [:intercept, :media],
        ones(2, 2, 2),
    )
    @test names(summary_table(valid_ts_contributions)) ==
        ["observation", "component", "mean", "lower_5", "upper_95"]

    invalid_ts_contributions = ContributionResults(
        ts_metadata,
        ts_spec,
        ts_coordinates,
        1:2,
        [1.0, 2.0],
        ["intercept"],
        [:intercept],
        ones(2, 2),
    )
    @test_throws ArgumentError summary_table(invalid_ts_contributions)

    panel_coordinates = ModelCoordinateMetadata(
        "time",
        ("geo", "brand"),
        Dict(
            "time" => ["1", "2"],
            "panel_cell" => ["north__alpha", "north__beta", "south__alpha", "south__beta"],
            "geo" => ["north", "north", "south", "south"],
            "brand" => ["alpha", "beta", "alpha", "beta"],
        ),
        Dict("target" => ("time", "panel_cell")),
    )
    panel_spec = _postmodel_schema_spec(:panel_mmm, panel_coordinates)
    panel_metadata = _postmodel_schema_metadata("PanelMMM")
    panel_spend_grid = [
        0.0 10.0
        0.0 20.0
        0.0 30.0
        0.0 40.0
    ]

    valid_panel_response = ResponseCurveResults(
        panel_metadata,
        panel_spec,
        panel_coordinates,
        "tv",
        panel_spend_grid,
        [0.0, 1.0],
        [10.0, 20.0, 30.0, 40.0],
        ones(2, 4, 2),
    )
    panel_response_table = summary_table(valid_panel_response)
    @test names(panel_response_table) == [
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
    @test panel_response_table.panel_cell[1:2] == ["north__alpha", "north__alpha"]
    @test panel_response_table.geo[1:2] == ["north", "north"]
    @test panel_response_table.brand[1:2] == ["alpha", "alpha"]

    invalid_panel_response = ResponseCurveResults(
        panel_metadata,
        panel_spec,
        panel_coordinates,
        "tv",
        [0.0, 1.0],
        [0.0, 1.0],
        [10.0, 20.0, 30.0, 40.0],
        ones(2, 4, 2),
    )
    @test_throws ArgumentError summary_table(invalid_panel_response)

    valid_panel_metrics = MetricResults(
        panel_metadata,
        panel_spec,
        panel_coordinates,
        "tv",
        panel_spend_grid,
        ["roas", "mroas"],
        :roas,
        ones(2, 4, 2, 2),
    )
    @test names(summary_table(valid_panel_metrics)) == [
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

    invalid_panel_metrics = MetricResults(
        panel_metadata,
        panel_spec,
        panel_coordinates,
        "tv",
        panel_spend_grid,
        ["roas"],
        :roas,
        ones(2, 4, 2, 2),
    )
    @test_throws ArgumentError summary_table(invalid_panel_metrics)
end
