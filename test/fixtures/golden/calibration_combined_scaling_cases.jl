# Golden fixture data for deterministic Epsilon tests.
const GOLDEN_CALIBRATION_COMBINED_SCALING_CASES = [
    (
        name = "combines_channel_target_and_sigma_scaling",
        channel_columns = [0, 1, 2],
        df = (; channel = [0, 1], x = Float64[100.0, 50.0], delta_x = Float64[50.0, 25.0], delta_y = Float64[10.0, 20.0], sigma = Float64[2.0, 4.0]),
        channel_transform_scale = 2.0,
        target_transform_scale = 2.0,
        expected = (; channel = [0, 1], x = Float64[200.0, 100.0], delta_x = Float64[100.0, 50.0], delta_y = Float64[5.0, 10.0], sigma = Float64[1.0, 2.0]),
    ),
]
