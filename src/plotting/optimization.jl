"""
    budget_optimization_plot(result::Union{BudgetOptimizationResult, PanelBudgetOptimizationResult})

Render a bounded current-versus-optimized budget comparison figure from
`BudgetOptimizationResult` or `PanelBudgetOptimizationResult`.

This surface compares channel-level spend allocations plus the total response
outcome in one static Makie figure.
"""
function budget_optimization_plot(result::_BudgetOptimizationResultLike)
    channel_names = result.spec.channel_columns
    x_positions = collect(1:length(channel_names))
    current_spend = Float64[result.current_spend[channel] for channel in channel_names]
    optimized_spend = Float64[result.optimized_spend[channel] for channel in channel_names]
    response_values = [result.current_response, result.optimized_response]
    efficiency_label = result.spec.target_type == "conversion" ? "CPA" : "ROAS"
    figure = nothing

    with_theme(epsilon_theme()) do
        figure = Figure(size = (1100, 760))

        ax_spend = Axis(
            figure[1, 1];
            title = "Channel spend comparison",
            xlabel = "Channel",
            ylabel = "Spend",
        )
        barplot!(
            ax_spend,
            x_positions .- 0.18,
            current_spend;
            width = 0.32,
            color = _EPSILON_NEUTRAL_COLOR,
            label = "Current",
        )
        barplot!(
            ax_spend,
            x_positions .+ 0.18,
            optimized_spend;
            width = 0.32,
            color = _EPSILON_POSITIVE_COLOR,
            label = "Optimized",
        )
        ax_spend.xticks = (x_positions, channel_names)
        axislegend(ax_spend; position = :rt)

        ax_response = Axis(
            figure[2, 1];
            title = "Total response comparison",
            xlabel = "Scenario",
            ylabel = "Response",
        )
        barplot!(
            ax_response,
            1:2,
            response_values;
            color = [_EPSILON_NEUTRAL_COLOR, _EPSILON_POSITIVE_COLOR],
        )
        ax_response.xticks = (1:2, ["Current", "Optimized"])

        summary = join(
            [
                "Solver: $(result.solver_status)",
                "Objective: $(round(result.objective_value; sigdigits = 5))",
                "Current $efficiency_label: $(round(result.current_default_efficiency; sigdigits = 5))",
                "Optimized $efficiency_label: $(round(result.optimized_default_efficiency; sigdigits = 5))",
            ],
            "  |  ",
        )
        Label(
            figure[3, 1],
            summary;
            tellwidth = false,
            justification = :left,
            halign = :left,
            fontsize = 12,
        )
    end

    return figure
end
