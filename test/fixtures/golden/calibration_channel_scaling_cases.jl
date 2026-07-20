# Golden fixture data for deterministic Epsilon tests.
const GOLDEN_CALIBRATION_CHANNEL_SCALING_CASES = [
    (
        name = "sparse_channel_rows",
        channel_columns = String["organic", "paid", "social"],
        scale = Float64[1.0, 2.0, 3.0],
        df = (; channel = String["organic", "organic", "social"], x = Float64[1.0, 2.0, 3.0], delta_x = Float64[1.0, 1.0, 1.0]),
        expected = (; channel = String["organic", "organic", "social"], x = Float64[1.0, 2.0, 9.0], delta_x = Float64[1.0, 1.0, 3.0]),
    ),
]
