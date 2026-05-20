#!/usr/bin/env python3
"""Export Abacus parity fixtures as Julia literals."""

from __future__ import annotations

import argparse
import csv
import itertools
import json
from datetime import date, datetime, timedelta
from pathlib import Path
import shutil
import subprocess
import sys

import numpy as np
import yaml


def _build_convolution_cases():
    base = np.arange(1.0, 61.0, dtype=float).reshape(3, 4, 5) / 10.0
    weights = np.array([1.0, 0.5, 0.25], dtype=float)
    broadcast_x = np.linspace(0.0, 1.4, num=15, dtype=float).reshape(3, 1, 5)
    broadcast_w = np.arange(1.0, 9.0, dtype=float).reshape(1, 1, 4, 2) / 10.0

    cases = []
    for axis_python, axis_julia in ((0, 1), (1, 2), (2, 3)):
        for mode in ("After", "Before", "Overlap"):
            cases.append(
                {
                    "name": f"base_axis_{axis_julia}_{mode.lower()}",
                    "x": base,
                    "w": weights,
                    "axis_python": axis_python,
                    "axis_julia": axis_julia,
                    "mode": mode,
                }
            )

    cases.append(
        {
            "name": "broadcast_after_last_axis",
            "x": broadcast_x,
            "w": broadcast_w,
            "axis_python": -1,
            "axis_julia": -1,
            "mode": "After",
        }
    )
    return cases


def _build_geometric_adstock_cases():
    vector_x = np.linspace(0.1, 1.0, num=10, dtype=float)
    matrix_x = np.arange(1.0, 19.0, dtype=float).reshape(6, 3) / 10.0
    tensor_x = np.arange(1.0, 25.0, dtype=float).reshape(2, 3, 4) / 10.0

    cases = []
    for mode in ("After", "Before", "Overlap"):
        cases.append(
            {
                "name": f"scalar_{mode.lower()}",
                "x": vector_x,
                "alpha": 0.3,
                "l_max": 5,
                "normalize": False,
                "axis_python": 0,
                "axis_julia": 1,
                "mode": mode,
            }
        )

    cases.append(
        {
            "name": "scalar_after_normalized",
            "x": vector_x,
            "alpha": 0.9,
            "l_max": 8,
            "normalize": True,
            "axis_python": 0,
            "axis_julia": 1,
            "mode": "After",
        }
    )

    cases.append(
        {
            "name": "vectorized_after",
            "x": matrix_x,
            "alpha": np.array([0.1, 0.5, 0.9], dtype=float),
            "l_max": 4,
            "normalize": False,
            "axis_python": 0,
            "axis_julia": 1,
            "mode": "After",
        }
    )
    cases.append(
        {
            "name": "vectorized_overlap_normalized",
            "x": matrix_x,
            "alpha": np.array([0.2, 0.4, 0.8], dtype=float),
            "l_max": 4,
            "normalize": True,
            "axis_python": 0,
            "axis_julia": 1,
            "mode": "Overlap",
        }
    )
    cases.append(
        {
            "name": "singleton_broadcast_axis_2_before",
            "x": tensor_x,
            "alpha": np.array([[0.2], [0.7]], dtype=float),
            "l_max": 4,
            "normalize": False,
            "axis_python": 1,
            "axis_julia": 2,
            "mode": "Before",
        }
    )
    cases.append(
        {
            "name": "singleton_broadcast_negative_axis_overlap",
            "x": tensor_x,
            "alpha": np.array([[0.25, 0.5, 0.75]], dtype=float),
            "l_max": 3,
            "normalize": True,
            "axis_python": -1,
            "axis_julia": -1,
            "mode": "Overlap",
        }
    )
    return cases


def _build_binomial_adstock_cases():
    vector_x = np.linspace(0.1, 1.0, num=10, dtype=float)
    matrix_x = np.arange(1.0, 19.0, dtype=float).reshape(6, 3) / 10.0
    tensor_x = np.arange(1.0, 25.0, dtype=float).reshape(2, 3, 4) / 10.0

    cases = []
    for mode in ("After", "Before", "Overlap"):
        cases.append(
            {
                "name": f"scalar_{mode.lower()}",
                "x": vector_x,
                "alpha": 0.4,
                "l_max": 5,
                "normalize": False,
                "axis_python": 0,
                "axis_julia": 1,
                "mode": mode,
            }
        )

    cases.append(
        {
            "name": "scalar_after_normalized",
            "x": vector_x,
            "alpha": 0.8,
            "l_max": 7,
            "normalize": True,
            "axis_python": 0,
            "axis_julia": 1,
            "mode": "After",
        }
    )

    cases.append(
        {
            "name": "vectorized_after",
            "x": matrix_x,
            "alpha": np.array([0.2, 0.5, 1.0], dtype=float),
            "l_max": 4,
            "normalize": False,
            "axis_python": 0,
            "axis_julia": 1,
            "mode": "After",
        }
    )
    cases.append(
        {
            "name": "vectorized_overlap_normalized",
            "x": matrix_x,
            "alpha": np.array([0.3, 0.6, 0.9], dtype=float),
            "l_max": 4,
            "normalize": True,
            "axis_python": 0,
            "axis_julia": 1,
            "mode": "Overlap",
        }
    )
    cases.append(
        {
            "name": "singleton_broadcast_axis_2_before",
            "x": tensor_x,
            "alpha": np.array([[0.25], [0.8]], dtype=float),
            "l_max": 4,
            "normalize": False,
            "axis_python": 1,
            "axis_julia": 2,
            "mode": "Before",
        }
    )
    cases.append(
        {
            "name": "singleton_broadcast_negative_axis_overlap",
            "x": tensor_x,
            "alpha": np.array([[0.4, 0.7, 1.0]], dtype=float),
            "l_max": 3,
            "normalize": True,
            "axis_python": -1,
            "axis_julia": -1,
            "mode": "Overlap",
        }
    )
    return cases


def _build_delayed_adstock_cases():
    vector_x = np.linspace(0.1, 1.0, num=10, dtype=float)
    matrix_x = np.arange(1.0, 19.0, dtype=float).reshape(6, 3) / 10.0
    tensor_x = np.arange(1.0, 25.0, dtype=float).reshape(2, 3, 4) / 10.0

    cases = []
    for mode in ("After", "Before", "Overlap"):
        cases.append(
            {
                "name": f"scalar_{mode.lower()}",
                "x": vector_x,
                "alpha": 0.5,
                "theta": 2,
                "l_max": 6,
                "normalize": False,
                "axis_python": 0,
                "axis_julia": 1,
                "mode": mode,
            }
        )

    cases.append(
        {
            "name": "scalar_after_normalized",
            "x": vector_x,
            "alpha": 0.75,
            "theta": 3,
            "l_max": 7,
            "normalize": True,
            "axis_python": 0,
            "axis_julia": 1,
            "mode": "After",
        }
    )

    cases.append(
        {
            "name": "vectorized_after",
            "x": matrix_x,
            "alpha": np.array([0.9, 0.33, 0.5], dtype=float),
            "theta": np.array([0.0, 1.0, 2.0], dtype=float),
            "l_max": 5,
            "normalize": False,
            "axis_python": 0,
            "axis_julia": 1,
            "mode": "After",
        }
    )
    cases.append(
        {
            "name": "vectorized_overlap_normalized",
            "x": matrix_x,
            "alpha": np.array([0.4, 0.6, 0.8], dtype=float),
            "theta": np.array([1.0, 2.0, 3.0], dtype=float),
            "l_max": 5,
            "normalize": True,
            "axis_python": 0,
            "axis_julia": 1,
            "mode": "Overlap",
        }
    )
    cases.append(
        {
            "name": "singleton_broadcast_axis_2_before",
            "x": tensor_x,
            "alpha": np.array([[0.3], [0.6]], dtype=float),
            "theta": np.array([[0.0, 1.0, 2.0, 3.0]], dtype=float),
            "l_max": 4,
            "normalize": False,
            "axis_python": 1,
            "axis_julia": 2,
            "mode": "Before",
        }
    )
    cases.append(
        {
            "name": "singleton_broadcast_negative_axis_overlap",
            "x": tensor_x,
            "alpha": np.array([[0.5, 0.7, 0.9]], dtype=float),
            "theta": np.array([[0.0], [1.0]], dtype=float),
            "l_max": 3,
            "normalize": True,
            "axis_python": -1,
            "axis_julia": -1,
            "mode": "Overlap",
        }
    )
    return cases


def _build_weibull_adstock_cases():
    vector_x = np.linspace(0.1, 1.0, num=10, dtype=float)
    matrix_x = np.arange(1.0, 19.0, dtype=float).reshape(6, 3) / 10.0
    tensor_x = np.arange(1.0, 25.0, dtype=float).reshape(2, 3, 4) / 10.0

    cases = []
    for type_name in ("PDF", "CDF"):
        for mode in ("After", "Before", "Overlap"):
            cases.append(
                {
                    "name": f"{type_name.lower()}_scalar_{mode.lower()}",
                    "type": type_name,
                    "x": vector_x,
                    "lam": 1.5,
                    "k": 0.8,
                    "l_max": 5,
                    "normalize": False,
                    "axis_python": 0,
                    "axis_julia": 1,
                    "mode": mode,
                }
            )

    cases.append(
        {
            "name": "pdf_scalar_after_normalized",
            "type": "PDF",
            "x": vector_x,
            "lam": 0.8,
            "k": 1.5,
            "l_max": 6,
            "normalize": True,
            "axis_python": 0,
            "axis_julia": 1,
            "mode": "After",
        }
    )
    cases.append(
        {
            "name": "cdf_scalar_after_normalized",
            "type": "CDF",
            "x": vector_x,
            "lam": 0.9,
            "k": 1.2,
            "l_max": 6,
            "normalize": True,
            "axis_python": 0,
            "axis_julia": 1,
            "mode": "After",
        }
    )
    cases.append(
        {
            "name": "pdf_vectorized_after",
            "type": "PDF",
            "x": matrix_x,
            "lam": np.array([0.9, 0.5, 1.0], dtype=float),
            "k": np.array([0.8, 0.6, 1.0], dtype=float),
            "l_max": 5,
            "normalize": False,
            "axis_python": 0,
            "axis_julia": 1,
            "mode": "After",
        }
    )
    cases.append(
        {
            "name": "cdf_vectorized_overlap_normalized",
            "type": "CDF",
            "x": matrix_x,
            "lam": np.array([0.7, 1.1, 1.4], dtype=float),
            "k": np.array([0.9, 1.2, 1.5], dtype=float),
            "l_max": 4,
            "normalize": True,
            "axis_python": 0,
            "axis_julia": 1,
            "mode": "Overlap",
        }
    )
    cases.append(
        {
            "name": "pdf_singleton_broadcast_axis_2_before",
            "type": "PDF",
            "x": tensor_x,
            "lam": np.array([[0.8], [1.3]], dtype=float),
            "k": np.array([[0.6, 1.1, 1.8, 0.9]], dtype=float),
            "l_max": 4,
            "normalize": False,
            "axis_python": 1,
            "axis_julia": 2,
            "mode": "Before",
        }
    )
    cases.append(
        {
            "name": "cdf_singleton_broadcast_negative_axis_overlap",
            "type": "CDF",
            "x": tensor_x,
            "lam": np.array([[0.9, 1.2, 1.5]], dtype=float),
            "k": np.array([[0.7], [1.4]], dtype=float),
            "l_max": 3,
            "normalize": True,
            "axis_python": -1,
            "axis_julia": -1,
            "mode": "Overlap",
        }
    )
    return cases


def _build_logistic_saturation_cases():
    vector_x = np.linspace(0.0, 2.0, num=9, dtype=float)
    matrix_x = np.arange(1.0, 13.0, dtype=float).reshape(4, 3) / 10.0
    tensor_x = np.arange(1.0, 25.0, dtype=float).reshape(2, 3, 4) / 10.0

    return [
        {
            "name": "scalar_lam",
            "x": vector_x,
            "lam": 0.5,
        },
        {
            "name": "zero_lam",
            "x": vector_x,
            "lam": 0.0,
        },
        {
            "name": "vectorized_column_lam",
            "x": matrix_x,
            "lam": np.array([0.2, 0.7, 1.4], dtype=float),
        },
        {
            "name": "singleton_broadcast_matrix_lam",
            "x": tensor_x,
            "lam": np.array([0.25, 0.9], dtype=float).reshape(2, 1, 1),
        },
        {
            "name": "singleton_broadcast_last_axis_lam",
            "x": tensor_x,
            "lam": np.array([0.3, 0.6, 1.2], dtype=float).reshape(1, 3, 1),
        },
    ]


def _build_tanh_saturation_cases():
    vector_x = np.linspace(-1.0, 2.0, num=10, dtype=float)
    matrix_x = np.arange(1.0, 13.0, dtype=float).reshape(4, 3) / 10.0
    tensor_x = np.arange(1.0, 25.0, dtype=float).reshape(2, 3, 4) / 10.0

    return [
        {
            "name": "scalar_params",
            "x": vector_x,
            "b": 0.75,
            "c": 1.5,
        },
        {
            "name": "negative_input_range",
            "x": np.linspace(-2.0, 1.0, num=12, dtype=float),
            "b": 1.0,
            "c": 0.5,
        },
        {
            "name": "vectorized_column_params",
            "x": matrix_x,
            "b": np.array([0.5, 1.0, 1.5], dtype=float),
            "c": np.array([0.25, 0.75, 1.25], dtype=float),
        },
        {
            "name": "singleton_broadcast_b",
            "x": tensor_x,
            "b": np.array([0.6, 1.2], dtype=float).reshape(2, 1, 1),
            "c": 0.8,
        },
        {
            "name": "singleton_broadcast_c",
            "x": tensor_x,
            "b": 0.9,
            "c": np.array([0.4, 0.9, 1.3], dtype=float).reshape(1, 3, 1),
        },
    ]


def _build_michaelis_menten_cases():
    vector_x = np.linspace(0.0, 20.0, num=9, dtype=float)
    matrix_x = np.arange(1.0, 13.0, dtype=float).reshape(4, 3)
    tensor_x = np.arange(1.0, 25.0, dtype=float).reshape(2, 3, 4)

    return [
        {
            "name": "scalar_params",
            "x": vector_x,
            "alpha": 100.0,
            "lam": 5.0,
        },
        {
            "name": "vectorized_column_params",
            "x": matrix_x,
            "alpha": np.array([50.0, 100.0, 150.0], dtype=float),
            "lam": np.array([2.0, 5.0, 8.0], dtype=float),
        },
        {
            "name": "singleton_broadcast_alpha",
            "x": tensor_x,
            "alpha": np.array([40.0, 120.0], dtype=float).reshape(2, 1, 1),
            "lam": 10.0,
        },
        {
            "name": "singleton_broadcast_lam",
            "x": tensor_x,
            "alpha": 80.0,
            "lam": np.array([3.0, 7.0, 11.0], dtype=float).reshape(1, 3, 1),
        },
        {
            "name": "scalar_examples",
            "x": np.array([10.0, 20.0], dtype=float),
            "alpha": 100.0,
            "lam": 5.0,
        },
    ]


def _build_hill_function_cases():
    vector_x = np.linspace(0.0, 10.0, num=11, dtype=float)
    matrix_x = np.arange(0.0, 12.0, dtype=float).reshape(4, 3)
    tensor_x = np.arange(0.0, 24.0, dtype=float).reshape(2, 3, 4)

    return [
        {
            "name": "scalar_params",
            "x": vector_x,
            "slope": 1.0,
            "kappa": 2.0,
        },
        {
            "name": "midpoint_vector",
            "x": np.array([0.5, 1.0, 2.0, 4.0], dtype=float),
            "slope": 2.0,
            "kappa": 2.0,
        },
        {
            "name": "vectorized_column_params",
            "x": matrix_x,
            "slope": np.array([1.0, 2.0, 3.0], dtype=float),
            "kappa": np.array([1.0, 2.0, 4.0], dtype=float),
        },
        {
            "name": "singleton_broadcast_slope",
            "x": tensor_x,
            "slope": np.array([1.0, 2.0], dtype=float).reshape(2, 1, 1),
            "kappa": 3.0,
        },
        {
            "name": "singleton_broadcast_kappa",
            "x": tensor_x,
            "slope": 1.5,
            "kappa": np.array([1.0, 2.0, 5.0], dtype=float).reshape(1, 3, 1),
        },
    ]


def _julia_float_literal(value: float) -> str:
    numeric = float(value)
    if np.isnan(numeric):
        return "NaN"
    if np.isposinf(numeric):
        return "Inf"
    if np.isneginf(numeric):
        return "-Inf"
    return repr(numeric)


def _julia_array_literal(array: np.ndarray) -> str:
    if array.ndim == 0:
        return _julia_float_literal(float(array))

    flat = ", ".join(_julia_float_literal(float(value)) for value in array.reshape(-1, order="F"))
    if array.ndim == 1:
        return f"Float64[{flat}]"

    dims = ", ".join(str(dimension) for dimension in array.shape)
    return f"reshape(Float64[{flat}], {dims})"


def _julia_string_literal(value: str) -> str:
    return json.dumps(str(value))


def _julia_string_vector_literal(values) -> str:
    return "String[" + ", ".join(_julia_string_literal(value) for value in values) + "]"


def _julia_string_dict_vector_literal(values: dict[str, list[str]]) -> str:
    rows = [
        f"{_julia_string_literal(key)} => {_julia_string_vector_literal(value)}"
        for key, value in values.items()
    ]
    return "Dict{String, Vector{String}}(" + ", ".join(rows) + ")"


def _julia_stage_directories_literal(stage_directories: dict[str, str]) -> str:
    rows = [
        f"{_julia_string_literal(key)} => {_julia_string_literal(value)}"
        for key, value in sorted(stage_directories.items())
    ]
    return "Dict{String, String}(" + ", ".join(rows) + ")"


def _latest_abacus_result_dir(abacus_root: Path, demo_name: str) -> Path:
    results_root = abacus_root / "results"
    candidates = sorted(
        path
        for path in results_root.glob(f"{demo_name}_*")
        if path.is_dir() and (path / "run_manifest.json").is_file()
    )
    if not candidates:
        raise FileNotFoundError(
            f"No Abacus result directory with run_manifest.json found for {demo_name!r} under {results_root}"
        )
    return candidates[-1]


def _abacus_pipeline_contract(abacus_root: Path, demo_name: str) -> dict[str, object]:
    result_dir = _latest_abacus_result_dir(abacus_root, demo_name)
    manifest = json.loads((result_dir / "run_manifest.json").read_text(encoding="utf-8"))
    stages = manifest.get("stages", {})

    artifact_files: dict[str, list[str]] = {}
    stage_artifact_keys: dict[str, list[str]] = {}
    for stage_key, stage_record in stages.items():
        artifact_map = stage_record.get("artifacts", {}) or {}
        stage_artifact_keys[str(stage_key)] = sorted(str(key) for key in artifact_map.keys())

        directory = stage_record.get("directory")
        if not directory:
            artifact_files[str(stage_key)] = []
            continue
        stage_dir = result_dir / str(directory)
        if not stage_dir.is_dir():
            artifact_files[str(stage_key)] = []
            continue
        artifact_files[str(stage_key)] = sorted(
            path.relative_to(stage_dir).as_posix()
            for path in stage_dir.rglob("*")
            if path.is_file()
        )

    stage_record_keys = sorted(
        {
            str(key)
            for stage_record in stages.values()
            for key in stage_record.keys()
        }
    )

    return {
        "result_dir": str(result_dir),
        "manifest_top_keys": sorted(str(key) for key in manifest.keys()),
        "manifest_stage_record_keys": stage_record_keys,
        "manifest_stage_artifact_keys": dict(sorted(stage_artifact_keys.items())),
        "artifact_files": dict(sorted(artifact_files.items())),
    }


def _describe_abacus_revision(abacus_root: Path) -> str:
    try:
        revision = subprocess.run(
            ["git", "-C", str(abacus_root), "rev-parse", "HEAD"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        dirty = subprocess.run(
            ["git", "-C", str(abacus_root), "status", "--short"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    except (FileNotFoundError, subprocess.CalledProcessError):
        return "unknown"

    return f"{revision} (dirty)" if dirty else revision


def _write_fixture_file(
    const_name: str,
    rows: list[str],
    destination: Path,
    *,
    abacus_root: Path,
    abacus_revision: str,
) -> None:
    lines = [
        "# This file is generated by scripts/export_abacus_fixtures.py.",
        f"# Abacus root: {abacus_root}",
        f"# Abacus revision: {abacus_revision}",
        f"const {const_name} = [",
    ]
    lines.extend(rows)
    lines.append("]")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _write_single_fixture_file(
    const_name: str,
    body: str,
    destination: Path,
    *,
    abacus_root: Path,
    abacus_revision: str,
) -> None:
    lines = [
        "# This file is generated by scripts/export_abacus_fixtures.py.",
        f"# Abacus root: {abacus_root}",
        f"# Abacus revision: {abacus_revision}",
        f"const {const_name} = {body}",
    ]
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _read_demo_dataset(dataset_path: Path, channels: list[str], target_column: str):
    with dataset_path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))

    dates = [row["date"] for row in rows]
    channel_matrix = np.array(
        [[float(row[channel]) for channel in channels] for row in rows],
        dtype=float,
    )
    target = np.array([float(row[target_column]) for row in rows], dtype=float)
    return dates, channel_matrix, target


def _read_panel_demo_dataset(
    dataset_path: Path,
    *,
    date_column: str,
    panel_column: str,
    channels: list[str],
    target_column: str,
):
    with dataset_path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))

    panel_names = list(dict.fromkeys(str(row[panel_column]) for row in rows))
    date_values = sorted({row[date_column] for row in rows}, key=_parse_demo_date)
    date_index = {value: index for index, value in enumerate(date_values)}
    panel_index = {value: index for index, value in enumerate(panel_names)}

    raw_channels = np.empty((len(date_values), len(channels), len(panel_names)), dtype=float)
    raw_target = np.empty((len(date_values), len(panel_names)), dtype=float)
    seen = set()

    for row in rows:
        current_date = row[date_column]
        panel_name = str(row[panel_column])
        t_index = date_index[current_date]
        p_index = panel_index[panel_name]
        key = (t_index, p_index)
        if key in seen:
            raise ValueError(f"duplicate panel observation for {current_date} / {panel_name}")
        seen.add(key)
        raw_target[t_index, p_index] = float(row[target_column])
        raw_channels[t_index, :, p_index] = [float(row[channel]) for channel in channels]

    expected_observations = len(date_values) * len(panel_names)
    if len(seen) != expected_observations:
        raise ValueError(
            f"panel dataset has {len(seen)} observations, expected {expected_observations}"
        )

    return date_values, panel_names, raw_channels, raw_target


def _read_multi_panel_demo_dataset(
    dataset_path: Path,
    *,
    date_column: str,
    panel_dims: list[str],
    channels: list[str],
    target_column: str,
):
    with dataset_path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))

    date_values = sorted({row[date_column] for row in rows}, key=_parse_demo_date)
    date_index = {value: index for index, value in enumerate(date_values)}
    panel_coordinates = {
        dim: list(dict.fromkeys(str(row[dim]) for row in rows))
        for dim in panel_dims
    }
    panel_keys = list(itertools.product(*(panel_coordinates[dim] for dim in panel_dims)))
    panel_names = ["|".join(key) for key in panel_keys]
    panel_index = {key: index for index, key in enumerate(panel_keys)}

    raw_channels = np.empty((len(date_values), len(channels), len(panel_keys)), dtype=float)
    raw_target = np.empty((len(date_values), len(panel_keys)), dtype=float)
    seen = set()

    for row in rows:
        current_date = row[date_column]
        panel_key = tuple(str(row[dim]) for dim in panel_dims)
        t_index = date_index[current_date]
        p_index = panel_index[panel_key]
        key = (t_index, p_index)
        if key in seen:
            raise ValueError(f"duplicate panel observation for {current_date} / {panel_key}")
        seen.add(key)
        raw_target[t_index, p_index] = float(row[target_column])
        raw_channels[t_index, :, p_index] = [float(row[channel]) for channel in channels]

    expected_observations = len(date_values) * len(panel_keys)
    if len(seen) != expected_observations:
        raise ValueError(
            f"panel dataset has {len(seen)} observations, expected {expected_observations}"
        )

    panel_coordinate_columns = {
        dim: [key[index] for key in panel_keys]
        for index, dim in enumerate(panel_dims)
    }

    return (
        date_values,
        panel_coordinates,
        panel_coordinate_columns,
        panel_keys,
        panel_names,
        raw_channels,
        raw_target,
    )


def _parse_demo_date(value: str) -> date:
    raw = str(value).strip()
    for fmt in ("%Y-%m-%d", "%d/%m/%Y"):
        try:
            return datetime.strptime(raw, fmt).date()
        except ValueError:
            pass
    return date.fromisoformat(raw)


def _yearly_fourier_features(date_strings: list[str], n_order: int) -> np.ndarray:
    days = np.array([_parse_demo_date(value).timetuple().tm_yday for value in date_strings], dtype=float)
    values = 2.0 * np.pi * days[:, None] * np.arange(1, n_order + 1, dtype=float)[None, :] / 365.25
    return np.concatenate([np.sin(values), np.cos(values)], axis=1)


def _demo_holiday_dates(holidays_path: Path, countries: list[str]) -> set[date]:
    allowed = set(countries)
    dates: set[date] = set()
    with holidays_path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            if allowed and row["country"] not in allowed:
                continue
            dates.add(_parse_demo_date(row["ds"]))
    return dates


def _pooled_holiday_exposure(
    date_strings: list[str],
    holidays_path: Path,
    countries: list[str],
) -> np.ndarray:
    dates = [_parse_demo_date(value) for value in date_strings]
    holiday_dates = _demo_holiday_dates(holidays_path, countries)
    period_days = []
    for index, current_date in enumerate(dates):
        if index < len(dates) - 1:
            period_days.append((dates[index + 1] - current_date).days)
        else:
            period_days.append(period_days[-1] if period_days else 1)

    exposure = np.zeros(len(dates), dtype=float)
    for index, current_date in enumerate(dates):
        days = period_days[index]
        matches = sum((current_date + timedelta(days=offset)) in holiday_dates for offset in range(days))
        exposure[index] = matches / days
    return exposure


def _timeseries_controlled_replay_fixture(
    *,
    channels: list[str],
    raw_channels: np.ndarray,
    target_scale: float,
    channel_scale: np.ndarray,
    saturated_media: np.ndarray,
    dates: list[str],
    yearly_fourier_order: int,
    holidays_path: Path,
    countries: list[str],
    alpha: np.ndarray,
    lam: np.ndarray,
    l_max: int,
    normalize: bool,
) -> dict[str, object]:
    beta_media = np.linspace(0.7, 0.2, num=raw_channels.shape[1], dtype=float)
    beta_seasonality = np.array([0.03, -0.02, 0.01, -0.015], dtype=float)
    if beta_seasonality.size != 2 * yearly_fourier_order:
        beta_seasonality = np.linspace(0.03, -0.015, num=2 * yearly_fourier_order, dtype=float)

    intercept = 0.08
    sigma = 0.04
    beta_holidays = np.array([0.025], dtype=float)
    fourier = _yearly_fourier_features(dates, yearly_fourier_order)
    holiday_exposure = _pooled_holiday_exposure(dates, holidays_path, countries)

    component_names = ["intercept"]
    component_names.extend(f"media:{name}" for name in channels)
    component_names.extend(["holiday", "seasonality"])

    component_values = np.zeros((raw_channels.shape[0], len(component_names)), dtype=float)
    component_values[:, 0] = intercept * target_scale
    for channel_index in range(raw_channels.shape[1]):
        component_values[:, channel_index + 1] = (
            saturated_media[:, channel_index] * beta_media[channel_index] * target_scale
        )
    component_values[:, -2] = holiday_exposure * beta_holidays[0] * target_scale
    component_values[:, -1] = (fourier @ beta_seasonality) * target_scale

    prediction_mean = component_values.sum(axis=1)
    decomposition_totals = component_values.sum(axis=0)
    decomposition_shares = decomposition_totals / decomposition_totals.sum()

    parameter_names = ["intercept", "sigma"]
    parameter_values = [intercept, sigma]
    for index, value in enumerate(beta_media, start=1):
        parameter_names.append(f"beta_media[{index}]")
        parameter_values.append(float(value))
    for index, value in enumerate(alpha, start=1):
        parameter_names.append(f"alpha[{index}]")
        parameter_values.append(float(value))
    for index, value in enumerate(lam, start=1):
        parameter_names.append(f"lam[{index}]")
        parameter_values.append(float(value))
    parameter_names.append("beta_holidays[1]")
    parameter_values.append(float(beta_holidays[0]))
    for index, value in enumerate(beta_seasonality, start=1):
        parameter_names.append(f"beta_seasonality[{index}]")
        parameter_values.append(float(value))

    observed_channel = raw_channels[:, 0]
    observed_total_spend = float(observed_channel.sum())
    spend_grid = np.array([0.0, observed_total_spend / 2.0, observed_total_spend], dtype=float)
    response_values = np.zeros(spend_grid.shape, dtype=float)
    saturation_values = np.zeros(spend_grid.shape, dtype=float)
    adstock_values = np.zeros(spend_grid.shape, dtype=float)

    for index, spend in enumerate(spend_grid):
        scaled_channel = observed_channel * (spend / observed_total_spend) / channel_scale[0]
        adstocked = geometric_adstock(
            scaled_channel,
            alpha=float(alpha[0]),
            l_max=l_max,
            normalize=normalize,
            axis=0,
            mode=ConvMode.After,
        ).eval()
        saturated = logistic_saturation(adstocked, lam=float(lam[0])).eval()
        saturation_only = logistic_saturation(scaled_channel, lam=float(lam[0])).eval()
        response_values[index] = saturated.sum() * beta_media[0] * target_scale
        saturation_values[index] = saturation_only.sum() * beta_media[0] * target_scale
        adstock_values[index] = adstocked.sum() * channel_scale[0]

    marginal_response = np.zeros_like(response_values)
    marginal_response[0] = (response_values[1] - response_values[0]) / (spend_grid[1] - spend_grid[0])
    for index in range(1, len(spend_grid) - 1):
        marginal_response[index] = (
            (response_values[index + 1] - response_values[index - 1])
            / (spend_grid[index + 1] - spend_grid[index - 1])
        )
    marginal_response[-1] = (response_values[-1] - response_values[-2]) / (
        spend_grid[-1] - spend_grid[-2]
    )
    metric_values = np.empty((len(spend_grid), 4), dtype=float)
    metric_values[:, 0] = np.divide(
        response_values,
        spend_grid,
        out=np.full_like(response_values, np.nan),
        where=spend_grid != 0.0,
    )
    metric_values[:, 1] = marginal_response
    metric_values[:, 2] = np.divide(
        spend_grid,
        response_values,
        out=np.full_like(response_values, np.nan),
        where=response_values != 0.0,
    )
    metric_values[:, 3] = np.divide(
        1.0,
        marginal_response,
        out=np.full_like(marginal_response, np.nan),
        where=marginal_response != 0.0,
    )

    return {
        "parameter_names": parameter_names,
        "parameter_values": np.asarray(parameter_values, dtype=float),
        "component_names": component_names,
        "component_values": component_values,
        "prediction_mean": prediction_mean,
        "decomposition_totals": decomposition_totals,
        "decomposition_shares": decomposition_shares,
        "holiday_exposure": holiday_exposure,
        "fourier_features": fourier,
        "curve_channel": "channel_1",
        "curve_spend_grid": spend_grid,
        "curve_spend_share_grid": spend_grid / observed_total_spend,
        "curve_observed_total_spend": observed_total_spend,
        "response_curve_values": response_values,
        "saturation_curve_values": saturation_values,
        "adstock_curve_values": adstock_values,
        "metric_names": ["roas", "mroas", "cpa", "mcpa"],
        "metric_values": metric_values,
        "holiday_contract": "epsilon_native_pooled_auto",
    }


def _timeseries_config_data_body(abacus_root: Path) -> str:
    demo_dir = abacus_root / "data" / "demo" / "timeseries"
    config_path = demo_dir / "config.yml"
    dataset_path = demo_dir / "dataset.csv"
    holidays_path = demo_dir / "holidays.csv"

    config = yaml.safe_load(config_path.read_text(encoding="utf-8"))
    channels = [str(channel) for channel in config["media"]["channels"]]
    target_column = str(config["target"]["column"])
    date_column = str(config["data"]["date_column"])
    dates, raw_channels, raw_target = _read_demo_dataset(dataset_path, channels, target_column)

    channel_scale = np.maximum(raw_channels.max(axis=0), 1.0)
    target_scale = max(float(raw_target.max()), 1.0)
    scaled_channels = raw_channels / channel_scale

    alpha = np.linspace(0.2, 0.7, num=len(channels), dtype=float)
    lam = np.linspace(0.4, 1.4, num=len(channels), dtype=float)
    l_max = int(config["media"]["adstock"]["l_max"])
    normalize = bool(config["media"]["adstock"].get("normalize", False))
    adstocked_media = geometric_adstock(
        scaled_channels,
        alpha=alpha,
        l_max=l_max,
        normalize=normalize,
        axis=0,
        mode=ConvMode.After,
    ).eval()
    saturated_media = logistic_saturation(adstocked_media, lam=lam).eval()

    effects = config.get("effects", [])
    effect_types = [str(effect.get("type", "")) for effect in effects]
    effect_orders = [
        int(effect.get("order", 0)) for effect in effects if str(effect.get("type", "")) == "yearly_fourier"
    ]
    yearly_fourier_order = effect_orders[0] if effect_orders else 0
    holidays_countries = [str(config.get("holidays", {}).get("countries", ""))]
    controlled_replay = _timeseries_controlled_replay_fixture(
        raw_channels=raw_channels,
        channels=channels,
        target_scale=target_scale,
        channel_scale=channel_scale,
        saturated_media=saturated_media,
        dates=dates,
        yearly_fourier_order=yearly_fourier_order,
        holidays_path=holidays_path,
        countries=holidays_countries,
        alpha=alpha,
        lam=lam,
        l_max=l_max,
        normalize=normalize,
    )
    pipeline_contract = _abacus_pipeline_contract(abacus_root, "timeseries")

    from abacus.pipeline.artifacts import STAGE_DIRECTORIES

    return "\n".join(
        [
            "(",
            f"    demo_name = {_julia_string_literal('timeseries')},",
            f"    source_config = {_julia_string_literal(str(config_path))},",
            f"    source_dataset = {_julia_string_literal(str(dataset_path))},",
            f"    source_holidays = {_julia_string_literal(str(holidays_path))},",
            f"    date_column = {_julia_string_literal(date_column)},",
            f"    target_column = {_julia_string_literal(target_column)},",
            f"    target_type = {_julia_string_literal(str(config['target'].get('type', 'revenue')))},",
            f"    channel_columns = {_julia_string_vector_literal(channels)},",
            "    control_columns = String[],",
            "    panel_dims = String[],",
            f"    adstock_type = {_julia_string_literal(str(config['media']['adstock']['type']))},",
            f"    adstock_l_max = {l_max},",
            f"    adstock_normalize = {'true' if normalize else 'false'},",
            f"    saturation_type = {_julia_string_literal(str(config['media']['saturation']['type']))},",
            f"    saturation_prior_keys = {_julia_string_vector_literal(config['media']['saturation']['priors'].keys())},",
            f"    top_level_prior_keys = {_julia_string_vector_literal(config.get('priors', {}).keys())},",
            f"    effect_types = {_julia_string_vector_literal(effect_types)},",
            f"    yearly_fourier_order = {yearly_fourier_order},",
            f"    holidays_mode = {_julia_string_literal(str(config.get('holidays', {}).get('mode', 'none')))},",
            f"    holidays_countries = {_julia_string_vector_literal(holidays_countries)},",
            f"    validation_enabled = {'true' if bool(config.get('validation', {}).get('enabled', False)) else 'false'},",
            f"    validation_holdout_observations = {int(config.get('validation', {}).get('holdout_observations', 0))},",
            f"    fit_draws = {int(config['fit']['draws'])},",
            f"    fit_tune = {int(config['fit']['tune'])},",
            f"    fit_chains = {int(config['fit']['chains'])},",
            f"    fit_cores = {int(config['fit']['cores'])},",
            f"    fit_random_seed = {int(config['fit']['random_seed'])},",
            f"    fit_target_accept = {float(config['fit']['target_accept'])},",
            f"    nobs = {len(dates)},",
            f"    dates = {_julia_string_vector_literal(dates)},",
            f"    raw_channels = {_julia_array_literal(raw_channels)},",
            f"    raw_target = {_julia_array_literal(raw_target)},",
            f"    channel_scale = {_julia_array_literal(channel_scale)},",
            f"    target_scale = {repr(float(target_scale))},",
            f"    scaled_channels = {_julia_array_literal(scaled_channels)},",
            f"    transform_alpha = {_julia_array_literal(alpha)},",
            f"    transform_lam = {_julia_array_literal(lam)},",
            f"    adstocked_media = {_julia_array_literal(np.asarray(adstocked_media, dtype=float))},",
            f"    saturated_media = {_julia_array_literal(np.asarray(saturated_media, dtype=float))},",
            "    controlled_replay = (",
            f"        parameter_names = {_julia_string_vector_literal(controlled_replay['parameter_names'])},",
            f"        parameter_values = {_julia_array_literal(controlled_replay['parameter_values'])},",
            f"        component_names = {_julia_string_vector_literal(controlled_replay['component_names'])},",
            f"        component_values = {_julia_array_literal(controlled_replay['component_values'])},",
            f"        prediction_mean = {_julia_array_literal(controlled_replay['prediction_mean'])},",
            f"        decomposition_totals = {_julia_array_literal(controlled_replay['decomposition_totals'])},",
            f"        decomposition_shares = {_julia_array_literal(controlled_replay['decomposition_shares'])},",
            f"        holiday_exposure = {_julia_array_literal(controlled_replay['holiday_exposure'])},",
            f"        fourier_features = {_julia_array_literal(controlled_replay['fourier_features'])},",
            f"        curve_channel = {_julia_string_literal(controlled_replay['curve_channel'])},",
            f"        curve_spend_grid = {_julia_array_literal(controlled_replay['curve_spend_grid'])},",
            f"        curve_spend_share_grid = {_julia_array_literal(controlled_replay['curve_spend_share_grid'])},",
            f"        curve_observed_total_spend = {repr(float(controlled_replay['curve_observed_total_spend']))},",
            f"        response_curve_values = {_julia_array_literal(controlled_replay['response_curve_values'])},",
            f"        saturation_curve_values = {_julia_array_literal(controlled_replay['saturation_curve_values'])},",
            f"        adstock_curve_values = {_julia_array_literal(controlled_replay['adstock_curve_values'])},",
            f"        metric_names = {_julia_string_vector_literal(controlled_replay['metric_names'])},",
            f"        metric_values = {_julia_array_literal(controlled_replay['metric_values'])},",
            f"        holiday_contract = {_julia_string_literal(controlled_replay['holiday_contract'])},",
            "    ),",
            f"    stage_directories = {_julia_stage_directories_literal(dict(STAGE_DIRECTORIES))},",
            "    pipeline_contract = (",
            f"        result_dir = {_julia_string_literal(pipeline_contract['result_dir'])},",
            f"        manifest_top_keys = {_julia_string_vector_literal(pipeline_contract['manifest_top_keys'])},",
            f"        manifest_stage_record_keys = {_julia_string_vector_literal(pipeline_contract['manifest_stage_record_keys'])},",
            f"        manifest_stage_artifact_keys = {_julia_string_dict_vector_literal(pipeline_contract['manifest_stage_artifact_keys'])},",
            f"        artifact_files = {_julia_string_dict_vector_literal(pipeline_contract['artifact_files'])},",
            "    ),",
            ")",
        ]
    )


def _geo_panel_config_data_body(abacus_root: Path) -> str:
    demo_name = "geo_panel"
    demo_dir = abacus_root / "data" / "demo" / demo_name
    config_path = demo_dir / "config.yml"
    dataset_path = demo_dir / "dataset.csv"
    holidays_path = demo_dir / "holidays.csv"

    config = yaml.safe_load(config_path.read_text(encoding="utf-8"))
    channels = [str(channel) for channel in config["media"]["channels"]]
    target_column = str(config["target"]["column"])
    date_column = str(config["data"]["date_column"])
    panel_dims = [str(dim) for dim in config["dimensions"]["panel"]]
    if len(panel_dims) != 1:
        raise ValueError("geo_panel fixture exporter expects exactly one panel dimension")
    panel_column = panel_dims[0]
    dates, panel_names, raw_channels, raw_target = _read_panel_demo_dataset(
        dataset_path,
        date_column=date_column,
        panel_column=panel_column,
        channels=channels,
        target_column=target_column,
    )

    channel_scale = np.maximum(raw_channels.max(axis=0), 1.0)
    target_scale = np.maximum(raw_target.max(axis=0), 1.0)
    scaled_channels = raw_channels / channel_scale.reshape(1, len(channels), len(panel_names))
    scaled_target = raw_target / target_scale.reshape(1, len(panel_names))

    alpha_by_panel_channel = np.linspace(
        0.2,
        0.75,
        num=len(panel_names) * len(channels),
        dtype=float,
    ).reshape(len(panel_names), len(channels))
    alpha_for_tensor = alpha_by_panel_channel.T
    lam = np.linspace(0.4, 1.4, num=len(channels), dtype=float)
    l_max = int(config["media"]["adstock"]["l_max"])
    normalize = bool(config["media"]["adstock"].get("normalize", False))
    adstocked_media = geometric_adstock(
        scaled_channels,
        alpha=alpha_for_tensor,
        l_max=l_max,
        normalize=normalize,
        axis=0,
        mode=ConvMode.After,
    ).eval()
    saturated_media = logistic_saturation(
        adstocked_media,
        lam=lam.reshape(1, len(channels), 1),
    ).eval()

    effects = config.get("effects", [])
    effect_types = [str(effect.get("type", "")) for effect in effects]
    effect_orders = [
        int(effect.get("order", 0)) for effect in effects if str(effect.get("type", "")) == "yearly_fourier"
    ]
    yearly_fourier_order = effect_orders[0] if effect_orders else 0
    holidays_countries = [str(country) for country in config.get("holidays", {}).get("countries", [])]

    from abacus.pipeline.artifacts import STAGE_DIRECTORIES

    pipeline_contract = _abacus_pipeline_contract(abacus_root, demo_name)

    return "\n".join(
        [
            "(",
            f"    demo_name = {_julia_string_literal(demo_name)},",
            f"    source_config = {_julia_string_literal(str(config_path))},",
            f"    source_dataset = {_julia_string_literal(str(dataset_path))},",
            f"    source_holidays = {_julia_string_literal(str(holidays_path))},",
            f"    date_column = {_julia_string_literal(date_column)},",
            f"    target_column = {_julia_string_literal(target_column)},",
            f"    target_type = {_julia_string_literal(str(config['target'].get('type', 'revenue')))},",
            f"    panel_dims = {_julia_string_vector_literal(panel_dims)},",
            f"    panel_dim = {_julia_string_literal(panel_column)},",
            f"    panel_names = {_julia_string_vector_literal(panel_names)},",
            f"    channel_columns = {_julia_string_vector_literal(channels)},",
            "    control_columns = String[],",
            f"    adstock_type = {_julia_string_literal(str(config['media']['adstock']['type']))},",
            f"    adstock_l_max = {l_max},",
            f"    adstock_normalize = {'true' if normalize else 'false'},",
            f"    adstock_prior_keys = {_julia_string_vector_literal(config['media']['adstock'].get('priors', {}).keys())},",
            f"    saturation_type = {_julia_string_literal(str(config['media']['saturation']['type']))},",
            f"    saturation_prior_keys = {_julia_string_vector_literal(config['media']['saturation']['priors'].keys())},",
            f"    top_level_prior_keys = {_julia_string_vector_literal(config.get('priors', {}).keys())},",
            f"    effect_types = {_julia_string_vector_literal(effect_types)},",
            f"    yearly_fourier_order = {yearly_fourier_order},",
            f"    holidays_mode = {_julia_string_literal(str(config.get('holidays', {}).get('mode', 'none')))},",
            f"    holidays_countries = {_julia_string_vector_literal(holidays_countries)},",
            f"    validation_enabled = {'true' if bool(config.get('validation', {}).get('enabled', False)) else 'false'},",
            f"    validation_holdout_observations = {int(config.get('validation', {}).get('holdout_observations', 0))},",
            f"    fit_draws = {int(config['fit']['draws'])},",
            f"    fit_tune = {int(config['fit']['tune'])},",
            f"    fit_chains = {int(config['fit']['chains'])},",
            f"    fit_cores = {int(config['fit']['cores'])},",
            f"    fit_random_seed = {int(config['fit']['random_seed'])},",
            f"    fit_target_accept = {float(config['fit']['target_accept'])},",
            f"    ntime = {len(dates)},",
            f"    npanels = {len(panel_names)},",
            f"    nobs = {raw_target.size},",
            f"    dates = {_julia_string_vector_literal(dates)},",
            f"    raw_channels = {_julia_array_literal(raw_channels)},",
            f"    raw_target = {_julia_array_literal(raw_target)},",
            f"    channel_scale = {_julia_array_literal(channel_scale)},",
            f"    target_scale = {_julia_array_literal(target_scale)},",
            f"    scaled_channels = {_julia_array_literal(scaled_channels)},",
            f"    scaled_target = {_julia_array_literal(scaled_target)},",
            f"    transform_alpha_by_panel_channel = {_julia_array_literal(alpha_by_panel_channel)},",
            f"    transform_alpha = {_julia_array_literal(alpha_for_tensor)},",
            f"    transform_lam = {_julia_array_literal(lam)},",
            f"    adstocked_media = {_julia_array_literal(np.asarray(adstocked_media, dtype=float))},",
            f"    saturated_media = {_julia_array_literal(np.asarray(saturated_media, dtype=float))},",
            "    unsupported_epsilon_features = String[],",
            f"    expected_epsilon_rejection = {_julia_string_literal('')},",
            f"    stage_directories = {_julia_stage_directories_literal(dict(STAGE_DIRECTORIES))},",
            "    pipeline_contract = (",
            f"        result_dir = {_julia_string_literal(pipeline_contract['result_dir'])},",
            f"        manifest_top_keys = {_julia_string_vector_literal(pipeline_contract['manifest_top_keys'])},",
            f"        manifest_stage_record_keys = {_julia_string_vector_literal(pipeline_contract['manifest_stage_record_keys'])},",
            f"        manifest_stage_artifact_keys = {_julia_string_dict_vector_literal(pipeline_contract['manifest_stage_artifact_keys'])},",
            f"        artifact_files = {_julia_string_dict_vector_literal(pipeline_contract['artifact_files'])},",
            "    ),",
            ")",
        ]
    )


def _geo_brand_panel_config_data_body(abacus_root: Path) -> str:
    demo_name = "geo_brand_panel"
    demo_dir = abacus_root / "data" / "demo" / demo_name
    config_path = demo_dir / "config.yml"
    dataset_path = demo_dir / "dataset.csv"
    holidays_path = demo_dir / "holidays.csv"

    config = yaml.safe_load(config_path.read_text(encoding="utf-8"))
    channels = [str(channel) for channel in config["media"]["channels"]]
    target_column = str(config["target"]["column"])
    date_column = str(config["data"]["date_column"])
    panel_dims = [str(dim) for dim in config["dimensions"]["panel"]]
    (
        dates,
        panel_coordinates,
        panel_coordinate_columns,
        panel_keys,
        panel_names,
        raw_channels,
        raw_target,
    ) = _read_multi_panel_demo_dataset(
        dataset_path,
        date_column=date_column,
        panel_dims=panel_dims,
        channels=channels,
        target_column=target_column,
    )

    channel_scale = np.maximum(raw_channels.max(axis=0), 1.0)
    target_scale = np.maximum(raw_target.max(axis=0), 1.0)
    scaled_channels = raw_channels / channel_scale.reshape(1, len(channels), len(panel_names))
    scaled_target = raw_target / target_scale.reshape(1, len(panel_names))

    alpha_by_panel_channel = np.linspace(
        0.2,
        0.75,
        num=len(panel_names) * len(channels),
        dtype=float,
    ).reshape(len(panel_names), len(channels))
    alpha_for_tensor = alpha_by_panel_channel.T
    lam = np.linspace(0.4, 1.4, num=len(channels), dtype=float)
    l_max = int(config["media"]["adstock"]["l_max"])
    normalize = bool(config["media"]["adstock"].get("normalize", False))
    adstocked_media = geometric_adstock(
        scaled_channels,
        alpha=alpha_for_tensor,
        l_max=l_max,
        normalize=normalize,
        axis=0,
        mode=ConvMode.After,
    ).eval()
    saturated_media = logistic_saturation(
        adstocked_media,
        lam=lam.reshape(1, len(channels), 1),
    ).eval()

    effects = config.get("effects", [])
    effect_types = [str(effect.get("type", "")) for effect in effects]
    effect_orders = [
        int(effect.get("order", 0)) for effect in effects if str(effect.get("type", "")) == "yearly_fourier"
    ]
    yearly_fourier_order = effect_orders[0] if effect_orders else 0
    holidays_countries = [str(country) for country in config.get("holidays", {}).get("countries", [])]

    from abacus.pipeline.artifacts import STAGE_DIRECTORIES

    pipeline_contract = _abacus_pipeline_contract(abacus_root, demo_name)
    panel_key_rows = ["|".join(key) for key in panel_keys]
    return "\n".join(
        [
            "(",
            f"    demo_name = {_julia_string_literal(demo_name)},",
            f"    source_config = {_julia_string_literal(str(config_path))},",
            f"    source_dataset = {_julia_string_literal(str(dataset_path))},",
            f"    source_holidays = {_julia_string_literal(str(holidays_path))},",
            f"    date_column = {_julia_string_literal(date_column)},",
            f"    target_column = {_julia_string_literal(target_column)},",
            f"    target_type = {_julia_string_literal(str(config['target'].get('type', 'revenue')))},",
            f"    panel_dims = {_julia_string_vector_literal(panel_dims)},",
            f"    panel_coordinates = {_julia_string_dict_vector_literal(panel_coordinates)},",
            f"    panel_coordinate_columns = {_julia_string_dict_vector_literal(panel_coordinate_columns)},",
            f"    panel_key_separator = {_julia_string_literal('|')},",
            f"    panel_keys = {_julia_string_vector_literal(panel_key_rows)},",
            f"    panel_names = {_julia_string_vector_literal(panel_names)},",
            f"    channel_columns = {_julia_string_vector_literal(channels)},",
            "    control_columns = String[],",
            f"    adstock_type = {_julia_string_literal(str(config['media']['adstock']['type']))},",
            f"    adstock_l_max = {l_max},",
            f"    adstock_normalize = {'true' if normalize else 'false'},",
            f"    adstock_prior_keys = {_julia_string_vector_literal(config['media']['adstock'].get('priors', {}).keys())},",
            f"    saturation_type = {_julia_string_literal(str(config['media']['saturation']['type']))},",
            f"    saturation_prior_keys = {_julia_string_vector_literal(config['media']['saturation']['priors'].keys())},",
            f"    top_level_prior_keys = {_julia_string_vector_literal(config.get('priors', {}).keys())},",
            f"    effect_types = {_julia_string_vector_literal(effect_types)},",
            f"    yearly_fourier_order = {yearly_fourier_order},",
            f"    holidays_mode = {_julia_string_literal(str(config.get('holidays', {}).get('mode', 'none')))},",
            f"    holidays_countries = {_julia_string_vector_literal(holidays_countries)},",
            f"    validation_enabled = {'true' if bool(config.get('validation', {}).get('enabled', False)) else 'false'},",
            f"    validation_holdout_observations = {int(config.get('validation', {}).get('holdout_observations', 0))},",
            f"    fit_draws = {int(config['fit']['draws'])},",
            f"    fit_tune = {int(config['fit']['tune'])},",
            f"    fit_chains = {int(config['fit']['chains'])},",
            f"    fit_cores = {int(config['fit']['cores'])},",
            f"    fit_random_seed = {int(config['fit']['random_seed'])},",
            f"    fit_target_accept = {float(config['fit']['target_accept'])},",
            f"    ntime = {len(dates)},",
            f"    npanels = {len(panel_names)},",
            f"    nobs = {raw_target.size},",
            f"    dates = {_julia_string_vector_literal(dates)},",
            f"    raw_channels = {_julia_array_literal(raw_channels)},",
            f"    raw_target = {_julia_array_literal(raw_target)},",
            f"    channel_scale = {_julia_array_literal(channel_scale)},",
            f"    target_scale = {_julia_array_literal(target_scale)},",
            f"    scaled_channels = {_julia_array_literal(scaled_channels)},",
            f"    scaled_target = {_julia_array_literal(scaled_target)},",
            f"    transform_alpha_by_panel_channel = {_julia_array_literal(alpha_by_panel_channel)},",
            f"    transform_alpha = {_julia_array_literal(alpha_for_tensor)},",
            f"    transform_lam = {_julia_array_literal(lam)},",
            f"    adstocked_media = {_julia_array_literal(np.asarray(adstocked_media, dtype=float))},",
            f"    saturated_media = {_julia_array_literal(np.asarray(saturated_media, dtype=float))},",
            "    unsupported_epsilon_features = String[],",
            f"    expected_epsilon_rejection = {_julia_string_literal('')},",
            f"    stage_directories = {_julia_stage_directories_literal(dict(STAGE_DIRECTORIES))},",
            "    pipeline_contract = (",
            f"        result_dir = {_julia_string_literal(pipeline_contract['result_dir'])},",
            f"        manifest_top_keys = {_julia_string_vector_literal(pipeline_contract['manifest_top_keys'])},",
            f"        manifest_stage_record_keys = {_julia_string_vector_literal(pipeline_contract['manifest_stage_record_keys'])},",
            f"        manifest_stage_artifact_keys = {_julia_string_dict_vector_literal(pipeline_contract['manifest_stage_artifact_keys'])},",
            f"        artifact_files = {_julia_string_dict_vector_literal(pipeline_contract['artifact_files'])},",
            "    ),",
            ")",
        ]
    )


def _copy_demo_files(abacus_root: Path, fixture_root: Path, demo_name: str) -> None:
    source_dir = abacus_root / "data" / "demo" / demo_name
    destination = fixture_root / demo_name
    destination.mkdir(parents=True, exist_ok=True)
    for filename in ("config.yml", "dataset.csv", "holidays.csv"):
        shutil.copyfile(source_dir / filename, destination / filename)


def _convolution_rows():
    rows: list[str] = []
    for case in _build_convolution_cases():
        expected = batched_convolution(
            case["x"],
            case["w"],
            axis=case["axis_python"],
            mode=getattr(ConvMode, case["mode"]),
        ).eval()
        rows.extend(
            [
                "    (",
                f'        name = "{case["name"]}",',
                f'        mode = "{case["mode"]}",',
                f'        axis = {case["axis_julia"]},',
                f'        x = {_julia_array_literal(case["x"])},',
                f'        w = {_julia_array_literal(case["w"])},',
                f'        expected = {_julia_array_literal(expected)},',
                "    ),",
            ]
        )
    return rows


def _geometric_adstock_rows():
    rows: list[str] = []
    for case in _build_geometric_adstock_cases():
        expected = geometric_adstock(
            case["x"],
            alpha=case["alpha"],
            l_max=case["l_max"],
            normalize=case["normalize"],
            axis=case["axis_python"],
            mode=getattr(ConvMode, case["mode"]),
        ).eval()
        rows.extend(
            [
                "    (",
                f'        name = "{case["name"]}",',
                f'        mode = "{case["mode"]}",',
                f'        axis = {case["axis_julia"]},',
                f'        l_max = {case["l_max"]},',
                f'        normalize = {"true" if case["normalize"] else "false"},',
                f'        x = {_julia_array_literal(case["x"])},',
                f'        alpha = {_julia_array_literal(np.asarray(case["alpha"], dtype=float))},',
                f'        expected = {_julia_array_literal(expected)},',
                "    ),",
            ]
        )
    return rows


def _binomial_adstock_rows():
    rows: list[str] = []
    for case in _build_binomial_adstock_cases():
        expected = binomial_adstock(
            case["x"],
            alpha=case["alpha"],
            l_max=case["l_max"],
            normalize=case["normalize"],
            axis=case["axis_python"],
            mode=getattr(ConvMode, case["mode"]),
        ).eval()
        rows.extend(
            [
                "    (",
                f'        name = "{case["name"]}",',
                f'        mode = "{case["mode"]}",',
                f'        axis = {case["axis_julia"]},',
                f'        l_max = {case["l_max"]},',
                f'        normalize = {"true" if case["normalize"] else "false"},',
                f'        x = {_julia_array_literal(case["x"])},',
                f'        alpha = {_julia_array_literal(np.asarray(case["alpha"], dtype=float))},',
                f'        expected = {_julia_array_literal(expected)},',
                "    ),",
            ]
        )
    return rows


def _delayed_adstock_rows():
    rows: list[str] = []
    for case in _build_delayed_adstock_cases():
        expected = delayed_adstock(
            case["x"],
            alpha=case["alpha"],
            theta=case["theta"],
            l_max=case["l_max"],
            normalize=case["normalize"],
            axis=case["axis_python"],
            mode=getattr(ConvMode, case["mode"]),
        ).eval()
        rows.extend(
            [
                "    (",
                f'        name = "{case["name"]}",',
                f'        mode = "{case["mode"]}",',
                f'        axis = {case["axis_julia"]},',
                f'        l_max = {case["l_max"]},',
                f'        normalize = {"true" if case["normalize"] else "false"},',
                f'        x = {_julia_array_literal(case["x"])},',
                f'        alpha = {_julia_array_literal(np.asarray(case["alpha"], dtype=float))},',
                f'        theta = {_julia_array_literal(np.asarray(case["theta"], dtype=float))},',
                f'        expected = {_julia_array_literal(expected)},',
                "    ),",
            ]
        )
    return rows


def _weibull_adstock_rows():
    rows: list[str] = []
    for case in _build_weibull_adstock_cases():
        expected = weibull_adstock(
            case["x"],
            lam=case["lam"],
            k=case["k"],
            l_max=case["l_max"],
            axis=case["axis_python"],
            mode=getattr(ConvMode, case["mode"]),
            type=getattr(WeibullType, case["type"]),
            normalize=case["normalize"],
        ).eval()
        rows.extend(
            [
                "    (",
                f'        name = "{case["name"]}",',
                f'        type = "{case["type"]}",',
                f'        mode = "{case["mode"]}",',
                f'        axis = {case["axis_julia"]},',
                f'        l_max = {case["l_max"]},',
                f'        normalize = {"true" if case["normalize"] else "false"},',
                f'        x = {_julia_array_literal(case["x"])},',
                f'        lam = {_julia_array_literal(np.asarray(case["lam"], dtype=float))},',
                f'        k = {_julia_array_literal(np.asarray(case["k"], dtype=float))},',
                f'        expected = {_julia_array_literal(expected)},',
                "    ),",
            ]
        )
    return rows


def _logistic_saturation_rows():
    rows: list[str] = []
    for case in _build_logistic_saturation_cases():
        expected = logistic_saturation(case["x"], lam=case["lam"]).eval()
        rows.extend(
            [
                "    (",
                f'        name = "{case["name"]}",',
                f'        x = {_julia_array_literal(case["x"])},',
                f'        lam = {_julia_array_literal(np.asarray(case["lam"], dtype=float))},',
                f'        expected = {_julia_array_literal(expected)},',
                "    ),",
            ]
        )
    return rows


def _tanh_saturation_rows():
    rows: list[str] = []
    for case in _build_tanh_saturation_cases():
        expected = tanh_saturation(case["x"], b=case["b"], c=case["c"]).eval()
        rows.extend(
            [
                "    (",
                f'        name = "{case["name"]}",',
                f'        x = {_julia_array_literal(case["x"])},',
                f'        b = {_julia_array_literal(np.asarray(case["b"], dtype=float))},',
                f'        c = {_julia_array_literal(np.asarray(case["c"], dtype=float))},',
                f'        expected = {_julia_array_literal(expected)},',
                "    ),",
            ]
        )
    return rows


def _michaelis_menten_rows():
    rows: list[str] = []
    for case in _build_michaelis_menten_cases():
        expected = michaelis_menten(case["x"], case["alpha"], case["lam"])
        expected = np.asarray(expected, dtype=float)
        rows.extend(
            [
                "    (",
                f'        name = "{case["name"]}",',
                f'        x = {_julia_array_literal(np.asarray(case["x"], dtype=float))},',
                f'        alpha = {_julia_array_literal(np.asarray(case["alpha"], dtype=float))},',
                f'        lam = {_julia_array_literal(np.asarray(case["lam"], dtype=float))},',
                f'        expected = {_julia_array_literal(expected)},',
                "    ),",
            ]
        )
    return rows


def _hill_function_rows():
    rows: list[str] = []
    for case in _build_hill_function_cases():
        expected = hill_function(case["x"], case["slope"], case["kappa"]).eval()
        expected = np.asarray(expected, dtype=float)
        rows.extend(
            [
                "    (",
                f'        name = "{case["name"]}",',
                f'        x = {_julia_array_literal(np.asarray(case["x"], dtype=float))},',
                f'        slope = {_julia_array_literal(np.asarray(case["slope"], dtype=float))},',
                f'        kappa = {_julia_array_literal(np.asarray(case["kappa"], dtype=float))},',
                f'        expected = {_julia_array_literal(expected)},',
                "    ),",
            ]
        )
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--abacus-root",
        default="/home/user/Documents/GITHUB/tandpds/abacus",
        help="Path to the Abacus repository root.",
    )
    parser.add_argument(
        "--output",
        default="test/fixtures/abacus/batched_convolution_cases.jl",
        help="Destination Julia convolution fixture file.",
    )
    parser.add_argument(
        "--adstock-output",
        default="test/fixtures/abacus/geometric_adstock_cases.jl",
        help="Destination Julia geometric adstock fixture file.",
    )
    parser.add_argument(
        "--binomial-output",
        default="test/fixtures/abacus/binomial_adstock_cases.jl",
        help="Destination Julia binomial adstock fixture file.",
    )
    parser.add_argument(
        "--delayed-output",
        default="test/fixtures/abacus/delayed_adstock_cases.jl",
        help="Destination Julia delayed adstock fixture file.",
    )
    parser.add_argument(
        "--weibull-output",
        default="test/fixtures/abacus/weibull_adstock_cases.jl",
        help="Destination Julia Weibull adstock fixture file.",
    )
    parser.add_argument(
        "--logistic-output",
        default="test/fixtures/abacus/logistic_saturation_cases.jl",
        help="Destination Julia logistic saturation fixture file.",
    )
    parser.add_argument(
        "--tanh-output",
        default="test/fixtures/abacus/tanh_saturation_cases.jl",
        help="Destination Julia tanh saturation fixture file.",
    )
    parser.add_argument(
        "--michaelis-output",
        default="test/fixtures/abacus/michaelis_menten_cases.jl",
        help="Destination Julia Michaelis-Menten fixture file.",
    )
    parser.add_argument(
        "--hill-output",
        default="test/fixtures/abacus/hill_function_cases.jl",
        help="Destination Julia Hill-function fixture file.",
    )
    parser.add_argument(
        "--timeseries-output",
        default="test/fixtures/abacus/timeseries/config_data.jl",
        help="Destination Julia Abacus timeseries config/data fixture file.",
    )
    parser.add_argument(
        "--geo-panel-output",
        default="test/fixtures/abacus/geo_panel/config_data.jl",
        help="Destination Julia Abacus geo_panel config/data fixture file.",
    )
    parser.add_argument(
        "--geo-brand-panel-output",
        default="test/fixtures/abacus/geo_brand_panel/config_data.jl",
        help="Destination Julia Abacus geo_brand_panel config/data fixture file.",
    )
    parser.add_argument(
        "--demo-fixture-root",
        default="test/fixtures/abacus",
        help="Destination root for copied Abacus demo config/data files.",
    )
    args = parser.parse_args()
    abacus_root = Path(args.abacus_root).resolve()

    sys.path.insert(0, str(abacus_root))

    global ConvMode
    global WeibullType
    global batched_convolution
    global binomial_adstock
    global delayed_adstock
    global geometric_adstock
    global logistic_saturation
    global michaelis_menten
    global hill_function
    global tanh_saturation
    global weibull_adstock
    from abacus.mmm.transforms.convolution import ConvMode, batched_convolution
    from abacus.mmm.transforms.adstock import (
        WeibullType,
        binomial_adstock,
        delayed_adstock,
        geometric_adstock,
        weibull_adstock,
    )
    from abacus.mmm.transforms.saturation import (
        hill_function,
        logistic_saturation,
        michaelis_menten,
        tanh_saturation,
    )
    abacus_revision = _describe_abacus_revision(abacus_root)

    _write_fixture_file(
        "ABACUS_BATCHED_CONVOLUTION_CASES",
        _convolution_rows(),
        Path(args.output),
        abacus_root=abacus_root,
        abacus_revision=abacus_revision,
    )
    _write_fixture_file(
        "ABACUS_GEOMETRIC_ADSTOCK_CASES",
        _geometric_adstock_rows(),
        Path(args.adstock_output),
        abacus_root=abacus_root,
        abacus_revision=abacus_revision,
    )
    _write_fixture_file(
        "ABACUS_BINOMIAL_ADSTOCK_CASES",
        _binomial_adstock_rows(),
        Path(args.binomial_output),
        abacus_root=abacus_root,
        abacus_revision=abacus_revision,
    )
    _write_fixture_file(
        "ABACUS_DELAYED_ADSTOCK_CASES",
        _delayed_adstock_rows(),
        Path(args.delayed_output),
        abacus_root=abacus_root,
        abacus_revision=abacus_revision,
    )
    _write_fixture_file(
        "ABACUS_WEIBULL_ADSTOCK_CASES",
        _weibull_adstock_rows(),
        Path(args.weibull_output),
        abacus_root=abacus_root,
        abacus_revision=abacus_revision,
    )
    _write_fixture_file(
        "ABACUS_LOGISTIC_SATURATION_CASES",
        _logistic_saturation_rows(),
        Path(args.logistic_output),
        abacus_root=abacus_root,
        abacus_revision=abacus_revision,
    )
    _write_fixture_file(
        "ABACUS_TANH_SATURATION_CASES",
        _tanh_saturation_rows(),
        Path(args.tanh_output),
        abacus_root=abacus_root,
        abacus_revision=abacus_revision,
    )
    _write_fixture_file(
        "ABACUS_MICHAELIS_MENTEN_CASES",
        _michaelis_menten_rows(),
        Path(args.michaelis_output),
        abacus_root=abacus_root,
        abacus_revision=abacus_revision,
    )
    _write_fixture_file(
        "ABACUS_HILL_FUNCTION_CASES",
        _hill_function_rows(),
        Path(args.hill_output),
        abacus_root=abacus_root,
        abacus_revision=abacus_revision,
    )
    _write_single_fixture_file(
        "ABACUS_TIMESERIES_CONFIG_DATA",
        _timeseries_config_data_body(abacus_root),
        Path(args.timeseries_output),
        abacus_root=abacus_root,
        abacus_revision=abacus_revision,
    )
    _write_single_fixture_file(
        "ABACUS_GEO_PANEL_CONFIG_DATA",
        _geo_panel_config_data_body(abacus_root),
        Path(args.geo_panel_output),
        abacus_root=abacus_root,
        abacus_revision=abacus_revision,
    )
    _write_single_fixture_file(
        "ABACUS_GEO_BRAND_PANEL_CONFIG_DATA",
        _geo_brand_panel_config_data_body(abacus_root),
        Path(args.geo_brand_panel_output),
        abacus_root=abacus_root,
        abacus_revision=abacus_revision,
    )
    _copy_demo_files(abacus_root, Path(args.demo_fixture_root), "timeseries")
    _copy_demo_files(abacus_root, Path(args.demo_fixture_root), "geo_panel")
    _copy_demo_files(abacus_root, Path(args.demo_fixture_root), "geo_brand_panel")


if __name__ == "__main__":
    main()
