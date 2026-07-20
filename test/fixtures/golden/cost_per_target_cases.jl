# Golden fixture data for deterministic Epsilon tests.
const GOLDEN_COST_PER_TARGET_CASES = [
    (
        name = "two_channel_two_row",
        gathered_cpt = Float64[0.5, 1.2],
        targets = Float64[0.45, 1.5],
        sigma = Float64[0.1, 0.2],
        expected_penalties = Float64[-0.12499999999999992, -1.125],
        expected_total_penalty = -1.25,
    ),
    (
        name = "single_row_exact_match",
        gathered_cpt = Float64[0.8],
        targets = Float64[0.8],
        sigma = Float64[0.05],
        expected_penalties = Float64[-0.0],
        expected_total_penalty = 0.0,
    ),
]
