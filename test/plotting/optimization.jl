using Epsilon
using Test

@testset "budget_optimization_plot renders current-versus-optimized comparisons" begin
    model = sample_time_series_model()
    fit!(model)
    grouped = _grouped_results_for_optimization(model)
    result = optimize_budget(grouped; total_budget = sum(model.data.channels))

    figure = budget_optimization_plot(result)
    axes = _plot_axes(figure)

    @test figure isa Figure
    @test length(axes) == 2
    @test axes[1].title[] == "Channel spend comparison"
    @test axes[2].title[] == "Total response comparison"
    _assert_plot_saves(figure, "budget_optimization")
end
