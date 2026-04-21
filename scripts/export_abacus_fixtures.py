#!/usr/bin/env python3
"""Export Abacus parity fixtures as Julia literals."""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import sys

import numpy as np


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


def _julia_array_literal(array: np.ndarray) -> str:
    if array.ndim == 0:
        return repr(float(array))

    flat = ", ".join(repr(float(value)) for value in array.reshape(-1, order="F"))
    if array.ndim == 1:
        return f"Float64[{flat}]"

    dims = ", ".join(str(dimension) for dimension in array.shape)
    return f"reshape(Float64[{flat}], {dims})"


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


if __name__ == "__main__":
    main()
