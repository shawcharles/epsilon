# Golden fixture data for deterministic Epsilon tests.
const GOLDEN_LIFT_TEST_LIKELIHOOD_CASES = [
    (
        name = "logistic_saturation_two_rows",
        lam = 0.5,
        x = Float64[1.0, 2.0],
        delta_x = Float64[0.5, 1.0],
        delta_y = Float64[0.05, 0.08],
        sigma = Float64[0.01, 0.02],
        expected_mu = Float64[0.11343873594707682, 0.17303179512727757],
        expected_observed = Float64[0.05, 0.08],
        expected_logp = Float64[-28.953709270449565, -13.73587536588829],
    ),
    (
        name = "logistic_saturation_negative_delta",
        lam = 1.2,
        x = Float64[3.0, 0.5],
        delta_x = Float64[-1.0, 2.0],
        delta_y = Float64[-0.02, 0.15],
        sigma = Float64[0.005, 0.03],
        expected_mu = Float64[0.11315140583411287, 0.6138356411932756],
        expected_observed = Float64[0.02, 0.15],
        expected_logp = Float64[-459.79712470891377, -269.57993657254303],
    ),
]
