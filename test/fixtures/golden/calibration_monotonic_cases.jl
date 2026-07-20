# Golden fixture data for deterministic Epsilon tests.
const GOLDEN_CALIBRATION_MONOTONIC_CASES = [
    (
        name = "monotonic_increasing",
        delta_x = Float64[1.0, 2.0, 3.0],
        delta_y = Float64[0.5, 1.0, 1.5],
        expect_error = false,
    ),
    (
        name = "monotonic_zero_delta_x",
        delta_x = Float64[0.0, 2.0],
        delta_y = Float64[0.0, 1.0],
        expect_error = false,
    ),
    (
        name = "non_monotonic_conflicting_sign",
        delta_x = Float64[1.0, 2.0, 3.0],
        delta_y = Float64[1.0, -2.0, 3.0],
        expect_error = true,
    ),
]
