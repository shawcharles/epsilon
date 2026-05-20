using Test
using Epsilon

@testset "version" begin
    @test Epsilon.epsilon_version() isa VersionNumber
end

@testset "public API surface exports and documents key symbols" begin
    documented_exports = [
        :predict,
        :ModelCoordinateMetadata,
        :PanelAxis,
        :PanelCoordinate,
        :After,
        :Before,
        :Overlap,
        :PipelineRunConfig,
        :PipelineRunResult,
        :PipelineStageRecord,
        :PipelineValidationResult,
        :epsilon_theme,
        :observed_fitted_plot,
        :posterior_density_plot,
        :prior_posterior_plot,
        :saturation_curve_plot,
        :adstock_curve_plot,
        :budget_audit_table,
        :budget_impact_table,
        :budget_optimization_plot,
        :centered_logistic_saturation,
        :panel_axis,
        :panel_axes,
        :panel_coordinate,
        :panel_coordinates,
        :pipeline_main,
        :npanel_observations,
        :npanels,
        :ntime,
        :run_pipeline,
        :saturation_curve_results,
        :adstock_curve_results,
        :SaturationCurveResults,
        :AdstockCurveResults,
        :summary_table,
        :trace_plot,
        :write_plot_bundle,
    ]

    for symbol in documented_exports
        @test symbol in names(Epsilon)
        @test !isnothing(Base.Docs.doc(getfield(Epsilon, symbol)))
    end
end
