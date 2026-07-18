#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
julia_bin="${JULIA:-julia}"
draws="${DRAWS:-8}"
tune="${TUNE:-8}"
toy_seed="${TOY_SEED:-${SEED:-20260706}}"
csv_seed="${CSV_SEED:-${SEED:-20260711}}"
tmp_root="$(mktemp -d)"

cleanup() {
    rm -rf "$tmp_root"
}
trap cleanup EXIT

assert_nonempty_file() {
    local path="$1"
    if [[ ! -s "$path" ]]; then
        echo "missing or empty smoke output: $path" >&2
        exit 1
    fi
}

assert_file_contains() {
    local path="$1"
    local pattern="$2"
    if ! grep -Fq "$pattern" "$path"; then
        echo "smoke output $path does not contain expected text: $pattern" >&2
        exit 1
    fi
}

verify_smoke_outputs() {
    local label="$1"
    local output_dir="$2"
    local summary_path="$output_dir/run_summary.txt"

    assert_nonempty_file "$output_dir/contribution_summary.csv"
    assert_nonempty_file "$output_dir/metric_summary.csv"
    assert_nonempty_file "$summary_path"
    assert_file_contains "$summary_path" "status=fit"
    assert_file_contains "$summary_path" "backend=turing"
    assert_file_contains "$summary_path" "contribution_rows="
    assert_file_contains "$summary_path" "metric_rows="

    echo "$label smoke outputs verified"
}

run_smoke() {
    local label="$1"
    local script_path="$2"
    local seed="$3"
    local output_dir="$tmp_root/$label"

    echo "Running $label supported-path smoke"
    "$julia_bin" --project="$repo_root" "$script_path" \
        --draws "$draws" \
        --tune "$tune" \
        --seed "$seed" \
        --output-dir "$output_dir"
    verify_smoke_outputs "$label" "$output_dir"
}

cd "$repo_root"

run_smoke "toy_mmm" "$repo_root/examples/toy_mmm/run_toy_mmm.jl" "$toy_seed"
run_smoke "csv_mmm" "$repo_root/examples/csv_mmm/run_csv_mmm.jl" "$csv_seed"

echo "Supported-path smoke certification passed"
