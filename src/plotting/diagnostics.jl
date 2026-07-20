using CairoMakie
using Statistics

"""
    trace_plot(results::InferenceResults; parameters=nothing, max_parameters=8)

Render a bounded posterior trace-plot figure for MCMC-backed grouped
`InferenceResults`.

This surface is supported only for Turing-backed MCMC artifacts.
"""
function trace_plot(
        results::InferenceResults;
        parameters = nothing,
        max_parameters::Integer = 8,
    )
    results.metadata.backend === :turing ||
        throw(
        ArgumentError(
            "trace_plot currently supports only MCMC-backed `InferenceResults`",
        ),
    )
    posterior = _require_plot_posterior(results, "trace_plot")
    selected = _select_plot_parameters(
        posterior;
        parameters,
        max_parameters,
        action = "trace_plot",
    )
    values = _parameter_cube(posterior, selected)
    ndraws = size(values, 1)
    nchains = size(values, 3)
    figure = nothing
    axes = Axis[]

    with_theme(epsilon_theme()) do
        figure, axes = _parameter_figure(
            length(selected);
            size = (1000, 280 * ceil(Int, length(selected) / min(2, max(1, length(selected))))),
        )
        for (index, parameter) in enumerate(selected)
            ax = axes[index]
            ax.title = string(parameter)
            ax.xlabel = "Draw"
            ax.ylabel = "Posterior value"
            for chain_index in 1:nchains
                lines!(
                    ax,
                    1:ndraws,
                    view(values, :, index, chain_index);
                    color = _EPSILON_CATEGORICAL_PALETTE[((chain_index - 1) % length(_EPSILON_CATEGORICAL_PALETTE)) + 1],
                    label = nchains > 1 ? "Chain $chain_index" : "Posterior",
                )
            end
            index == 1 && axislegend(ax; position = :rb)
        end
    end

    return figure
end

"""
    posterior_density_plot(results::InferenceResults; parameters=nothing, max_parameters=8)

Render a bounded posterior-density figure for grouped `InferenceResults`.

This surface requires grouped posterior draws on
`InferenceResults.posterior` from a Turing-backed MCMC artifact.
"""
function posterior_density_plot(
        results::InferenceResults;
        parameters = nothing,
        max_parameters::Integer = 8,
    )
    posterior = _require_plot_posterior(results, "posterior_density_plot")
    selected = _select_plot_parameters(
        posterior;
        parameters,
        max_parameters,
        action = "posterior_density_plot",
    )
    values = _parameter_cube(posterior, selected)
    figure = nothing
    axes = Axis[]

    with_theme(epsilon_theme()) do
        figure, axes = _parameter_figure(
            length(selected);
            size = (1000, 280 * ceil(Int, length(selected) / min(2, max(1, length(selected))))),
        )
        for (index, parameter) in enumerate(selected)
            ax = axes[index]
            draws = vec(view(values, :, index, :))
            ax.title = string(parameter)
            ax.xlabel = "Posterior value"
            ax.ylabel = "Density"
            density!(ax, draws; color = _EPSILON_NEUTRAL_COLOR)
            vlines!(ax, [mean(draws)]; color = _EPSILON_POSITIVE_COLOR, linestyle = :dash)
        end
    end

    return figure
end

"""
    prior_posterior_plot(results::InferenceResults; parameter)

Render a bounded prior-versus-posterior density overlay for one parameter from
grouped `InferenceResults`.

This surface requires both grouped posterior draws on
`InferenceResults.posterior` and grouped prior draws on `InferenceResults.prior`
for the requested parameter.
"""
function prior_posterior_plot(results::InferenceResults; parameter)
    posterior = _require_plot_posterior(results, "prior_posterior_plot")
    prior = _require_plot_prior(results, "prior_posterior_plot")
    selected_parameter = _normalize_single_plot_parameter(parameter, "prior_posterior_plot")
    posterior_draws = _parameter_draws(
        posterior,
        selected_parameter,
        "prior_posterior_plot requires posterior draws for the selected parameter",
    )
    prior_draws = _parameter_draws(
        prior,
        selected_parameter,
        "prior_posterior_plot requires prior draws for the selected parameter",
    )

    figure = nothing
    with_theme(epsilon_theme()) do
        figure = Figure(size = (860, 520))
        ax = Axis(
            figure[1, 1];
            title = "Prior vs posterior: $(selected_parameter)",
            xlabel = "Value",
            ylabel = "Density",
        )
        density!(ax, prior_draws; color = _EPSILON_NEGATIVE_COLOR, label = "Prior")
        density!(ax, posterior_draws; color = _EPSILON_POSITIVE_COLOR, label = "Posterior")
        axislegend(ax; position = :rb)
    end
    return figure
end

"""
    observed_fitted_plot(results::InferenceResults)

Render the bounded observed-versus-fitted time-series diagnostic for grouped
`InferenceResults`.

This surface requires time-series grouped artifacts with
`InferenceResults.observed_data::MMMData` and posterior predictive draws on
`InferenceResults.posterior_predictive`.
"""
function observed_fitted_plot(results::InferenceResults)
    data = _require_time_series_plot_results(results, "observed_fitted_plot")
    fitted_mean, fitted_lower, fitted_upper = _predictive_summary(
        results.posterior_predictive,
        nobs(data),
    )
    observed = Float64.(collect(data.target))
    x_values = collect(1:nobs(data))
    figure = nothing

    with_theme(epsilon_theme()) do
        figure = Figure(size = (1020, 520))
        ax = Axis(
            figure[1, 1];
            title = "Observed vs fitted",
            xlabel = "Observation",
            ylabel = results.spec.target_column,
        )
        band!(
            ax,
            x_values,
            fitted_lower,
            fitted_upper;
            color = RGBAf(_EPSILON_NEUTRAL_COLOR.r, _EPSILON_NEUTRAL_COLOR.g, _EPSILON_NEUTRAL_COLOR.b, 0.18),
            label = "90% posterior interval",
        )
        lines!(ax, x_values, fitted_mean; color = _EPSILON_NEUTRAL_COLOR, label = "Fitted mean")
        scatter!(ax, x_values, observed; color = _EPSILON_POSITIVE_COLOR, label = "Observed")
        _apply_time_axis_ticks!(ax, data.dates)
        axislegend(ax; position = :rb)
    end

    return figure
end

function _fit_timeseries_plot(results::InferenceResults)
    data = _require_time_series_plot_results(results, "_fit_timeseries_plot")
    fitted_mean, fitted_lower, fitted_upper = _predictive_summary(
        results.posterior_predictive,
        nobs(data),
    )
    observed = Float64.(collect(data.target))
    x_values = collect(1:nobs(data))
    figure = nothing

    with_theme(epsilon_theme()) do
        figure = Figure(size = (1020, 520))
        ax = Axis(
            figure[1, 1];
            title = "Fit over time",
            xlabel = "Observation",
            ylabel = results.spec.target_column,
        )
        band!(
            ax,
            x_values,
            fitted_lower,
            fitted_upper;
            color = RGBAf(_EPSILON_NEUTRAL_COLOR.r, _EPSILON_NEUTRAL_COLOR.g, _EPSILON_NEUTRAL_COLOR.b, 0.16),
            label = "90% fitted interval",
        )
        lines!(ax, x_values, observed; color = _EPSILON_POSITIVE_COLOR, label = "Observed")
        lines!(ax, x_values, fitted_mean; color = _EPSILON_NEUTRAL_COLOR, label = "Fitted mean")
        _apply_time_axis_ticks!(ax, data.dates)
        axislegend(ax; position = :rb)
    end

    return figure
end

function _posterior_predictive_plot(results::InferenceResults)
    data = _require_time_series_plot_results(results, "_posterior_predictive_plot")
    predictive_matrix = _predictive_matrix(results.posterior_predictive, nobs(data))
    predictive_mean, lower_90, upper_90 = _column_mean_interval(predictive_matrix)
    _, lower_50, upper_50 = _column_mean_interval(predictive_matrix; lower = 0.25, upper = 0.75)
    observed = Float64.(collect(data.target))
    x_values = collect(1:nobs(data))
    figure = nothing

    with_theme(epsilon_theme()) do
        figure = Figure(size = (1020, 520))
        ax = Axis(
            figure[1, 1];
            title = "Posterior predictive check",
            xlabel = "Observation",
            ylabel = results.spec.target_column,
        )
        band!(
            ax,
            x_values,
            lower_90,
            upper_90;
            color = RGBAf(_EPSILON_NEUTRAL_COLOR.r, _EPSILON_NEUTRAL_COLOR.g, _EPSILON_NEUTRAL_COLOR.b, 0.14),
            label = "90% predictive interval",
        )
        band!(
            ax,
            x_values,
            lower_50,
            upper_50;
            color = RGBAf(_EPSILON_NEUTRAL_COLOR.r, _EPSILON_NEUTRAL_COLOR.g, _EPSILON_NEUTRAL_COLOR.b, 0.24),
            label = "50% predictive interval",
        )
        lines!(ax, x_values, predictive_mean; color = _EPSILON_NEUTRAL_COLOR, label = "Predictive mean")
        scatter!(ax, x_values, observed; color = _EPSILON_POSITIVE_COLOR, label = "Observed")
        _apply_time_axis_ticks!(ax, data.dates)
        axislegend(ax; position = :rb)
    end

    return figure
end

"""
    residual_diagnostics_plot(results::InferenceResults)

Render the bounded residual-diagnostics figure for grouped `InferenceResults`.

This surface requires the same time-series observed-data and posterior
predictive contract as `observed_fitted_plot`.
"""
function residual_diagnostics_plot(results::InferenceResults)
    data = _require_time_series_plot_results(results, "residual_diagnostics_plot")
    fitted_mean, _, _ = _predictive_summary(results.posterior_predictive, nobs(data))
    observed = Float64.(collect(data.target))
    residuals = observed .- fitted_mean
    x_values = collect(1:nobs(data))

    figure = nothing
    with_theme(epsilon_theme()) do
        figure = Figure(size = (1180, 700))
        ax_time = Axis(
            figure[1, 1];
            title = "Residual through time",
            xlabel = "Observation",
            ylabel = "Residual",
        )
        lines!(ax_time, x_values, residuals; color = _EPSILON_NEUTRAL_COLOR)
        scatter!(ax_time, x_values, residuals; color = _EPSILON_NEUTRAL_COLOR)
        hlines!(ax_time, [0.0]; color = _EPSILON_NEGATIVE_COLOR, linestyle = :dash)
        _apply_time_axis_ticks!(ax_time, data.dates)

        ax_fitted = Axis(
            figure[1, 2];
            title = "Residual vs fitted",
            xlabel = "Fitted mean",
            ylabel = "Residual",
        )
        scatter!(ax_fitted, fitted_mean, residuals; color = _EPSILON_POSITIVE_COLOR)
        hlines!(ax_fitted, [0.0]; color = _EPSILON_NEGATIVE_COLOR, linestyle = :dash)

        ax_hist = Axis(
            figure[2, 1:2];
            title = "Residual histogram",
            xlabel = "Residual",
            ylabel = "Count",
        )
        hist!(ax_hist, residuals; bins = max(5, min(20, length(residuals))))
        vlines!(ax_hist, [0.0]; color = _EPSILON_NEGATIVE_COLOR, linestyle = :dash)
    end

    return figure
end

function _require_plot_posterior(results::InferenceResults, action::AbstractString)
    isnothing(results.posterior) &&
        throw(
        ArgumentError(
            "$action requires grouped posterior draws on `InferenceResults.posterior`",
        ),
    )
    return results.posterior
end

function _require_plot_prior(results::InferenceResults, action::AbstractString)
    isnothing(results.prior) &&
        throw(
        ArgumentError(
            "$action requires grouped prior draws on `InferenceResults.prior`",
        ),
    )
    return results.prior
end

function _require_time_series_plot_results(
        results::InferenceResults,
        action::AbstractString,
    )
    results.spec.model_kind === :time_series_mmm ||
        throw(
        ArgumentError(
            "$action currently supports only time-series grouped inference artifacts; panel plotting is not supported in the bounded plotting surface",
        ),
    )
    results.observed_data isa MMMData ||
        throw(
        ArgumentError(
            "$action requires `InferenceResults.observed_data` to carry MMMData",
        ),
    )
    isnothing(results.posterior_predictive) &&
        throw(
        ArgumentError(
            "$action requires posterior predictive draws on `InferenceResults.posterior_predictive`",
        ),
    )
    return results.observed_data
end

function _select_plot_parameters(
        chain;
        parameters,
        max_parameters::Integer,
        action::AbstractString,
    )
    Int(max_parameters) > 0 ||
        throw(ArgumentError("$action requires `max_parameters` to be positive"))
    available = Symbol.(names(chain, :parameters))
    isempty(available) &&
        throw(ArgumentError("$action requires at least one posterior parameter"))
    if isnothing(parameters)
        sorted_names = sort(String.(available))
        return Symbol.(sorted_names[1:min(Int(max_parameters), length(sorted_names))])
    end

    selected = _normalize_plot_parameter_collection(parameters, action)
    for parameter in selected
        parameter in available ||
            throw(
            ArgumentError(
                "$action requested parameter `$(parameter)` but it is not present in the grouped chain",
            ),
        )
    end
    return selected
end

function _normalize_single_plot_parameter(parameter, action::AbstractString)
    normalized = _normalize_plot_parameter_collection((parameter,), action)
    length(normalized) == 1 ||
        throw(ArgumentError("$action requires exactly one parameter"))
    return only(normalized)
end

function _normalize_plot_parameter_collection(parameters, action::AbstractString)
    collection = if parameters isa Symbol || parameters isa AbstractString
        (parameters,)
    elseif parameters isa AbstractVector || parameters isa Tuple
        parameters
    else
        throw(
            ArgumentError(
                "$action expects `parameters` to be `nothing`, one parameter name, or a vector/tuple of parameter names",
            ),
        )
    end
    normalized = Symbol[
        parameter isa Symbol ? parameter : Symbol(String(parameter)) for parameter in collection
    ]
    isempty(normalized) &&
        throw(ArgumentError("$action requires at least one parameter"))
    return _unique_plot_parameters(normalized)
end

function _unique_plot_parameters(parameters::Vector{Symbol})
    seen = Set{Symbol}()
    unique_parameters = Symbol[]
    for parameter in parameters
        parameter in seen && continue
        push!(seen, parameter)
        push!(unique_parameters, parameter)
    end
    return unique_parameters
end

function _parameter_cube(chain, parameters::Vector{Symbol})
    selected = chain[parameters]
    values = selected.value.data
    ndims(values) == 3 ||
        throw(ArgumentError("grouped chain data must materialize to a 3D draw cube"))
    return Float64.(values)
end

function _parameter_draws(chain, parameter::Symbol, error_prefix::AbstractString)
    available = Set(Symbol.(names(chain, :parameters)))
    parameter in available ||
        throw(ArgumentError("$error_prefix: `$(parameter)` is not available"))
    values = _parameter_cube(chain, [parameter])
    return vec(view(values, :, 1, :))
end

function _predictive_matrix(chain, nobs::Integer)
    parameter_names = [Symbol("target[$index]") for index in 1:Int(nobs)]
    values = _parameter_cube(chain, parameter_names)
    return reshape(
        permutedims(values, (1, 3, 2)),
        size(values, 1) * size(values, 3),
        size(values, 2),
    )
end

function _predictive_summary(chain, nobs::Integer)
    flattened = _predictive_matrix(chain, nobs)
    return _column_mean_interval(flattened)
end

function _column_mean_interval(matrix::AbstractMatrix; lower = 0.05, upper = 0.95)
    means = Vector{Float64}(undef, size(matrix, 2))
    lowers = similar(means)
    uppers = similar(means)
    for column in axes(matrix, 2)
        values = view(matrix, :, column)
        means[column] = mean(values)
        lowers[column] = quantile(values, lower)
        uppers[column] = quantile(values, upper)
    end
    return means, lowers, uppers
end

function _apply_time_axis_ticks!(ax::Axis, dates)
    tick_positions, tick_labels = _time_axis_ticks(dates)
    isempty(tick_positions) && return ax
    ax.xticks = (tick_positions, tick_labels)
    return ax
end

function _time_axis_ticks(dates)
    isempty(dates) && return Int[], String[]
    nticks = min(length(dates), 8)
    positions = unique(round.(Int, collect(range(1, length(dates); length = nticks))))
    return positions, string.(collect(dates)[positions])
end

function _parameter_figure(
        nparameters::Integer;
        size = (1000, 560),
    )
    nparameters > 0 || throw(ArgumentError("plot requires at least one parameter"))
    ncols = min(2, Int(nparameters))
    nrows = ceil(Int, Int(nparameters) / ncols)
    figure = Figure(size = size)
    axes = Axis[]
    for index in 1:Int(nparameters)
        row = ceil(Int, index / ncols)
        col = ((index - 1) % ncols) + 1
        push!(axes, Axis(figure[row, col]))
    end
    return figure, axes
end
