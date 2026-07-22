#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
julia_bin="${JULIA:-julia}"
output_dir="${OUTPUT_DIR:-$repo_root/results}"
run_name="${RUN_NAME:-reviewer_quick_demo}"
config_path="$repo_root/data/demo/timeseries/config.yml"
marker="$(mktemp)"

cleanup() {
    rm -f "$marker"
}
trap cleanup EXIT

mkdir -p "$output_dir"
touch "$marker"

echo "Running Epsilon reviewer demo"
echo "  config    : $config_path"
echo "  output dir: $output_dir"
echo "  run name  : $run_name"
echo

"$julia_bin" --project="$repo_root" "$repo_root/runme.jl" "$config_path" \
    --output-dir "$output_dir" \
    --run-name "$run_name" \
    --quick \
    "$@"

run_dir="$(
    find "$output_dir" -maxdepth 1 -type d -name "${run_name}_*" -newer "$marker" \
        -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-
)"

if [[ -z "$run_dir" ]]; then
    echo "Reviewer demo completed, but no new output directory was found." >&2
    exit 1
fi

manifest="$run_dir/run_manifest.json"
if [[ ! -s "$manifest" ]]; then
    echo "Reviewer demo output is missing a non-empty run_manifest.json: $manifest" >&2
    exit 1
fi

"$julia_bin" --project="$repo_root" - "$manifest" <<'JULIA'
using JSON3

manifest_path = only(ARGS)
manifest = JSON3.read(read(manifest_path, String))
stages = collect(values(manifest.stages))

status = String(manifest.status)
completed = count(stage -> String(stage.status) == "completed", stages)
skipped = count(stage -> String(stage.status) == "skipped", stages)
failed = count(stage -> String(stage.status) == "failed", stages)

status == "completed" || error("reviewer demo did not complete; manifest status=$status")
failed == 0 || error("reviewer demo recorded failed stages")

println()
println("Reviewer demo verified")
println("  manifest : $manifest_path")
println("  status   : $status")
println("  stages   : completed=$completed, skipped=$skipped, failed=$failed")
JULIA

echo "  run dir  : $run_dir"
