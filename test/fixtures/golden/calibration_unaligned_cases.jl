# Golden fixture data for deterministic Epsilon tests.
const GOLDEN_CALIBRATION_UNALIGNED_CASES = [
    (
        name = "reports_unaligned_rows",
        coords = (; channel = [1, 2, 3], geo = String["A", "B", "C"]),
        df = (; channel = [1000, 2], geo = String["A", "Z"]),
        expected_unaligned_1based = Dict{String, Vector{Int}}("channel" => [1], "geo" => [2]),
    ),
]
