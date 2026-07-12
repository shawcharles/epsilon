function _safe_metric_ratio(numerator::Real, denominator::Real)
    isapprox(denominator, 0.0; atol = sqrt(eps(Float64))) && return NaN
    return Float64(numerator) / Float64(denominator)
end

function _finite_difference_slopes(spend_grid::AbstractVector, response_values::AbstractVector)
    length(spend_grid) == length(response_values) ||
        throw(ArgumentError("spend_grid and response_values must have matching length"))
    length(spend_grid) >= 2 ||
        throw(ArgumentError("marginal metrics require at least two spend points"))

    slopes = zeros(Float64, length(spend_grid))
    slopes[1] = _safe_metric_ratio(
        response_values[2] - response_values[1],
        spend_grid[2] - spend_grid[1],
    )

    for index in 2:(length(spend_grid) - 1)
        slopes[index] = _safe_metric_ratio(
            response_values[index + 1] - response_values[index - 1],
            spend_grid[index + 1] - spend_grid[index - 1],
        )
    end

    slopes[end] = _safe_metric_ratio(
        response_values[end] - response_values[end - 1],
        spend_grid[end] - spend_grid[end - 1],
    )
    return slopes
end

function _default_metric_name(spec::MMMModelSpec)
    return lowercase(spec.target_type) == "conversion" ? :cpa : :roas
end

"""
    metric_results(results::InferenceResults; channel, grid=nothing, delta_grid=nothing)

Compute draw-level ROAS, mROAS, CPA, and mCPA for one supported media channel
from grouped `InferenceResults`.

Metrics are derived from the same bounded response-curve surface returned by
`response_curve_results(results; channel, grid, delta_grid)` rather than a
separate formula path. Panel metrics therefore inherit the explicit
`delta_grid` historical-scaling semantics of panel response curves.
"""
function metric_results(
        results::InferenceResults;
        channel,
        grid = nothing,
        delta_grid = nothing,
    )
    return metric_results(response_curve_results(results; channel, grid, delta_grid))
end

"""
    metric_results(curves::ResponseCurveResults)

Compute draw-level ROAS, mROAS, CPA, and mCPA from a canonical
`ResponseCurveResults` surface.
"""
function metric_results(curves::ResponseCurveResults)
    _reject_hsgp_media_postmodel_reporting(curves.spec, "metric_results")
    _validate_postmodel_axes(curves)
    metric_names = ["roas", "mroas", "cpa", "mcpa"]

    if ndims(curves.values) == 3
        ndraws, npanels, npoints = size(curves.values)
        npoints >= 2 ||
            throw(ArgumentError("metric_results requires at least two spend points"))
        spend_grid = Matrix{Float64}(curves.spend_grid)
        size(spend_grid) == (npanels, npoints) ||
            throw(ArgumentError("panel response curves must carry a panel-by-spend-point spend grid"))
        values = fill(NaN, ndraws, npanels, npoints, length(metric_names))

        for draw in 1:ndraws
            for panel in 1:npanels
                responses = vec(curves.values[draw, panel, :])
                panel_spend = vec(spend_grid[panel, :])
                marginal_response = _finite_difference_slopes(panel_spend, responses)

                for point in 1:npoints
                    spend = panel_spend[point]
                    response = responses[point]
                    values[draw, panel, point, 1] = _safe_metric_ratio(response, spend)
                    values[draw, panel, point, 2] = marginal_response[point]
                    values[draw, panel, point, 3] = _safe_metric_ratio(spend, response)
                    values[draw, panel, point, 4] = _safe_metric_ratio(1.0, marginal_response[point])
                end
            end
        end

        return MetricResults(
            curves.metadata,
            curves.spec,
            curves.coordinate_metadata,
            curves.channel,
            spend_grid,
            metric_names,
            _default_metric_name(curves.spec),
            values,
        )
    end

    spend_grid = _validated_spend_grid(
        curves.spend_grid,
        "metric_results";
        require_multiple_points = true,
    )
    ndraws = size(curves.values, 1)
    npoints = length(spend_grid)
    values = fill(NaN, ndraws, npoints, length(metric_names))

    for draw in 1:ndraws
        responses = vec(curves.values[draw, :])
        marginal_response = _finite_difference_slopes(spend_grid, responses)

        for point in 1:npoints
            spend = spend_grid[point]
            response = responses[point]
            values[draw, point, 1] = _safe_metric_ratio(response, spend)
            values[draw, point, 2] = marginal_response[point]
            values[draw, point, 3] = _safe_metric_ratio(spend, response)
            values[draw, point, 4] = _safe_metric_ratio(1.0, marginal_response[point])
        end
    end

    return MetricResults(
        curves.metadata,
        curves.spec,
        curves.coordinate_metadata,
        curves.channel,
        spend_grid,
        metric_names,
        _default_metric_name(curves.spec),
        values,
    )
end
