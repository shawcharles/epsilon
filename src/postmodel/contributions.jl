"""
    contribution_results(results::InferenceResults)

Compute draw-level additive contributions from grouped `InferenceResults`.

The returned `ContributionResults` surface preserves canonical draw-level
values. Time-series results use dimensions `(draw, observation, component)`;
bounded panel results use `(draw, time, panel, component)`, where
multidimensional panels are represented on the deterministic flat panel-cell
axis carried by the model spec.
"""
function contribution_results(results::InferenceResults)
    replayed = _replayed_contribution_values(results)
    return ContributionResults(
        results.metadata,
        results.spec,
        results.coordinate_metadata,
        replayed.data.dates,
        replayed.data.target,
        replayed.component_names,
        replayed.component_kinds,
        replayed.values,
    )
end
