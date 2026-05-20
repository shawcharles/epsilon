function _component_share_matrix(totals::AbstractMatrix)
    shares = zeros(Float64, size(totals))
    grand_totals = vec(sum(totals; dims = 2))
    for draw in axes(totals, 1)
        total = grand_totals[draw]
        isapprox(total, 0.0; atol = sqrt(eps(Float64))) && continue
        shares[draw, :] .= totals[draw, :] ./ total
    end
    return shares
end

function _component_total_matrix(values)
    ndims(values) == 3 && return dropdims(sum(values; dims = 2); dims = 2)
    ndims(values) == 4 && return dropdims(sum(values; dims = (2, 3)); dims = (2, 3))
    throw(ArgumentError("contribution values must have dimensions (draw, time, component) or (draw, time, panel, component)"))
end

"""
    decomposition_results(results::InferenceResults)

Aggregate time-indexed additive contributions into draw-level component totals
and shares.

The returned `DecompositionResults` surface preserves canonical draw-level
component totals and shares with dimensions `(draw, component)` for bounded
time-series and panel contribution surfaces.
"""
function decomposition_results(results::InferenceResults)
    contributions = contribution_results(results)
    totals = _component_total_matrix(contributions.values)
    shares = _component_share_matrix(totals)
    return DecompositionResults(
        contributions.metadata,
        contributions.spec,
        contributions.coordinate_metadata,
        contributions.component_names,
        contributions.component_kinds,
        totals,
        shares,
    )
end
