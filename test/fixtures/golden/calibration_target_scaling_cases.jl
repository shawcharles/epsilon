# Golden fixture data for deterministic Epsilon tests.
const GOLDEN_CALIBRATION_TARGET_SCALING_CASES = [
    (
        name = "rescale_series",
        target = Float64[0.0, 3.0, 6.0, 9.0],
        scale = 3.0,
        expected = Float64[0.0, 1.0, 2.0, 3.0],
    ),
]
