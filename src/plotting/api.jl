const _PLOTTING_BACKEND_NAME = "CairoMakie"
const _PLOTTING_EXTENSION_NAME = :EpsilonCairoMakieExt
const _PIPELINE_PLOTS_DISABLED = Ref(false)

function _plotting_backend_message(action::AbstractString)
    return string(
        action,
        " requires optional plotting support; load CairoMakie before calling ",
        "plotting APIs, for example `using Epsilon, CairoMakie`.",
    )
end

function _plotting_backend_error(action::AbstractString)
    return ArgumentError(_plotting_backend_message(action))
end

function _plotting_backend_warning()
    return string(
        "optional plotting support is unavailable; load CairoMakie before ",
        "running plotted pipeline stages, for example `using Epsilon, CairoMakie`. ",
        "Non-plot artifacts were written and plot artifact paths were omitted.",
    )
end

function _pipeline_plots_disabled_warning()
    return "pipeline plot artifact generation is disabled for this run; non-plot artifacts were written and plot artifact paths were omitted."
end

function _plotting_backend_loaded()
    return Base.get_extension(@__MODULE__, _PLOTTING_EXTENSION_NAME) !== nothing
end

function _pipeline_plots_enabled()
    return !_PIPELINE_PLOTS_DISABLED[] && _plotting_backend_loaded()
end

function _with_pipeline_plots_disabled(f::Function)
    previous = _PIPELINE_PLOTS_DISABLED[]
    _PIPELINE_PLOTS_DISABLED[] = true
    try
        return f()
    finally
        _PIPELINE_PLOTS_DISABLED[] = previous
    end
end

function _push_plotting_backend_warning!(warnings::Vector{String})
    warning = _plotting_backend_warning()
    warning in warnings || push!(warnings, warning)
    return warnings
end

function _push_pipeline_plots_disabled_warning!(warnings::Vector{String})
    warning = _pipeline_plots_disabled_warning()
    warning in warnings || push!(warnings, warning)
    return warnings
end

function _save_pipeline_plot!(
        artifact_paths::Dict{String, String},
        warnings::Vector{String},
        stage::AbstractString,
        artifact_key::AbstractString,
        absolute_path::AbstractString,
        relative_path::AbstractString,
        plot_kind::Symbol,
        args...;
        kwargs...,
    )
    if _PIPELINE_PLOTS_DISABLED[]
        _push_pipeline_plots_disabled_warning!(warnings)
        return artifact_paths
    end

    extension = _plotting_extension()
    if !isnothing(extension)
        return Base.invokelatest(
            extension._save_pipeline_plot_impl!,
            artifact_paths,
            warnings,
            stage,
            artifact_key,
            absolute_path,
            relative_path,
            plot_kind,
            args...;
            kwargs...,
        )
    end

    _push_plotting_backend_warning!(warnings)
    return artifact_paths
end

function _plotting_extension()
    return Base.get_extension(@__MODULE__, _PLOTTING_EXTENSION_NAME)
end

"""
    epsilon_theme()

Return the optional CairoMakie-backed Epsilon plotting theme.

Plotting is an optional extension. Load `CairoMakie` alongside `Epsilon` before
calling plotting APIs:

```julia
using Epsilon, CairoMakie
```
"""
function epsilon_theme()
    extension = _plotting_extension()
    isnothing(extension) && throw(_plotting_backend_error("epsilon_theme"))
    return extension._epsilon_theme_impl()
end

"""
    trace_plot(results::InferenceResults; parameters=nothing, max_parameters=8)

Render a bounded posterior trace-plot figure for MCMC-backed grouped
`InferenceResults`.

Requires optional plotting support. Load `CairoMakie` before calling.
"""
trace_plot(args...; kwargs...) = throw(_plotting_backend_error("trace_plot"))

"""
    posterior_density_plot(results::InferenceResults; parameters=nothing, max_parameters=8)

Render a bounded posterior-density figure for grouped `InferenceResults`.

Requires optional plotting support. Load `CairoMakie` before calling.
"""
posterior_density_plot(args...; kwargs...) =
    throw(_plotting_backend_error("posterior_density_plot"))

"""
    prior_posterior_plot(results::InferenceResults; parameter)

Render a bounded prior-versus-posterior density overlay for one parameter from
grouped `InferenceResults`.

Requires optional plotting support. Load `CairoMakie` before calling.
"""
prior_posterior_plot(args...; kwargs...) =
    throw(_plotting_backend_error("prior_posterior_plot"))

"""
    observed_fitted_plot(results::InferenceResults)

Render the bounded observed-versus-fitted time-series diagnostic for grouped
`InferenceResults`.

Requires optional plotting support. Load `CairoMakie` before calling.
"""
observed_fitted_plot(args...; kwargs...) =
    throw(_plotting_backend_error("observed_fitted_plot"))

"""
    residual_diagnostics_plot(results::InferenceResults)

Render the bounded residual-diagnostics figure for grouped `InferenceResults`.

Requires optional plotting support. Load `CairoMakie` before calling.
"""
residual_diagnostics_plot(args...; kwargs...) =
    throw(_plotting_backend_error("residual_diagnostics_plot"))

"""
    contribution_plot(results::ContributionResults; channels=nothing)

Render HDI-aware time-series media contribution plots from a bounded
`ContributionResults` surface.

Requires optional plotting support. Load `CairoMakie` before calling.
"""
contribution_plot(args...; kwargs...) =
    throw(_plotting_backend_error("contribution_plot"))

"""
    contribution_area_plot(results::ContributionResults; channels=nothing)

Render a stacked additive contribution breakdown through time from
`ContributionResults`.

Requires optional plotting support. Load `CairoMakie` before calling.
"""
contribution_area_plot(args...; kwargs...) =
    throw(_plotting_backend_error("contribution_area_plot"))

"""
    decomposition_plot(results::DecompositionResults)

Render a bounded decomposition figure in observed target units from
`DecompositionResults`.

Requires optional plotting support. Load `CairoMakie` before calling.
"""
decomposition_plot(args...; kwargs...) =
    throw(_plotting_backend_error("decomposition_plot"))

"""
    response_curve_plot(results::ResponseCurveResults)

Render the bounded response-curve surface from `ResponseCurveResults`.

Requires optional plotting support. Load `CairoMakie` before calling.
"""
response_curve_plot(args...; kwargs...) =
    throw(_plotting_backend_error("response_curve_plot"))

"""
    saturation_curve_plot(results::SaturationCurveResults)

Render the bounded saturation-only curve surface from `SaturationCurveResults`.

Requires optional plotting support. Load `CairoMakie` before calling.
"""
saturation_curve_plot(args...; kwargs...) =
    throw(_plotting_backend_error("saturation_curve_plot"))

"""
    adstock_curve_plot(results::AdstockCurveResults)

Render the bounded adstock-only curve surface from `AdstockCurveResults`.

Requires optional plotting support. Load `CairoMakie` before calling.
"""
adstock_curve_plot(args...; kwargs...) =
    throw(_plotting_backend_error("adstock_curve_plot"))

"""
    budget_optimization_plot(result)

Render a bounded current-versus-optimized budget comparison figure from a
budget optimization result.

Requires optional plotting support. Load `CairoMakie` before calling.
"""
budget_optimization_plot(args...; kwargs...) =
    throw(_plotting_backend_error("budget_optimization_plot"))

"""
    write_plot_bundle(run::PipelineRunResult; output_dir=nothing) -> String

Write the bounded static plot bundle for a successful pipeline run.

Requires optional plotting support. Load `CairoMakie` before calling.
"""
write_plot_bundle(args...; kwargs...) =
    throw(_plotting_backend_error("write_plot_bundle"))
