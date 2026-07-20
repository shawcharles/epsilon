# Golden fixture data for deterministic Epsilon tests.
const GOLDEN_CALIBRATION_ALIGNMENT_CASES = [
    (
        name = "matches_model_coords",
        coords = (; channel = [1, 2, 3], geo = String["A", "B", "C"]),
        df = (; channel = [1, 2], geo = String["A", "C"]),
        expected_indices_1based = Dict{String, Vector{Int}}("channel" => [1, 2], "geo" => [1, 3]),
    ),
    (
        name = "single_dim_channel_only",
        coords = (; channel = [1, 2, 3]),
        df = (; channel = [3, 1]),
        expected_indices_1based = Dict{String, Vector{Int}}("channel" => [3, 1]),
    ),
]
