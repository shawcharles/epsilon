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


def _build_hsgp_time_index_cases():
    daily_training_dates = [date(2022, 1, day) for day in range(1, 6)]
    weekly_training_dates = [date(2022, 1, day) for day in (1, 8, 15, 22, 29)]

    return [
        {
            "name": "daily_in_sample",
            "new_dates": daily_training_dates,
            "training_dates": daily_training_dates,
            "time_resolution": 1,
        },
        {
            "name": "daily_forward",
            "new_dates": [date(2022, 1, day) for day in range(6, 11)],
            "training_dates": daily_training_dates,
            "time_resolution": 1,
        },
        {
            "name": "daily_backward",
            "new_dates": [date(2021, 12, day) for day in range(27, 32)],
            "training_dates": daily_training_dates,
            "time_resolution": 1,
        },
        {
            "name": "weekly_in_sample",
            "new_dates": weekly_training_dates,
            "training_dates": weekly_training_dates,
            "time_resolution": 7,
        },
        {
            "name": "weekly_forward",
            "new_dates": [
                date(2022, 2, 5),
                date(2022, 2, 12),
                date(2022, 2, 19),
                date(2022, 2, 26),
                date(2022, 3, 5),
            ],
            "training_dates": weekly_training_dates,
            "time_resolution": 7,
        },
        {
            "name": "weekly_backward",
            "new_dates": [
                date(2021, 11, 27),
                date(2021, 12, 4),
                date(2021, 12, 11),
                date(2021, 12, 18),
                date(2021, 12, 25),
            ],
            "training_dates": weekly_training_dates,
            "time_resolution": 7,
        },
        {
            "name": "weekly_leap_boundary",
            "new_dates": [
                date(2024, 2, 17),
                date(2024, 2, 24),
                date(2024, 3, 2),
                date(2024, 3, 9),
            ],
            "training_dates": [date(2024, 2, 24), date(2024, 3, 2), date(2024, 3, 9)],
            "time_resolution": 7,
        },
        {
            "name": "weekly_off_cadence_forward",
            "new_dates": [date(2022, 1, 10)],
            "training_dates": [date(2022, 1, 1), date(2022, 1, 8)],
            "time_resolution": 7,
            "expected_error": "off_cadence",
        },
        {
            "name": "weekly_off_cadence_backward",
            "new_dates": [date(2021, 12, 30)],
            "training_dates": [date(2022, 1, 1), date(2022, 1, 8)],
            "time_resolution": 7,
            "expected_error": "off_cadence",
        },
    ]


def _build_hsgp_linearized_geometry_cases():
    return [
        {
            "name": "expquad_asymmetric_nonunit_eta",
            "x": np.array([0.0, 1.0, 10.0], dtype=float),
            "m": 4,
            "L": 12.0,
            "covariance": "expquad",
            "eta": 1.7,
            "lengthscale": 2.5,
            "drop_first": False,
            "demeaned_basis": False,
        },
        {
            "name": "matern32_drop_first",
            "x": np.array([-3.0, 0.0, 2.0, 7.0], dtype=float),
            "m": 5,
            "L": 10.0,
            "covariance": "matern32",
            "eta": 0.8,
            "lengthscale": 1.4,
            "drop_first": True,
            "demeaned_basis": False,
        },
        {
            "name": "matern52_drop_first_demeaned",
            "x": np.array([0.0, 1.0, 10.0], dtype=float),
            "m": 5,
            "L": 12.0,
            "covariance": "matern52",
            "eta": 1.2,
            "lengthscale": 3.1,
            "drop_first": True,
            "demeaned_basis": True,
        },
        {
            "name": "expquad_zero_retained_modes",
            "x": np.array([0.0, 1.0, 10.0], dtype=float),
            "m": 1,
            "L": 12.0,
            "covariance": "expquad",
            "eta": 1.0,
            "lengthscale": 2.5,
            "drop_first": True,
            "demeaned_basis": True,
        },
    ]


def _build_hsgp_recommendation_cases():
    return [
        {
            "name": "expquad_custom_bounds",
            "x": np.array([0.0, 1.0, 10.0], dtype=float),
            "x_center": 5.0,
            "x_mid": 5.0,
            "lengthscale_lower": 1.5,
            "lengthscale_upper": 7.0,
            "covariance": "expquad",
        },
        {
            "name": "matern52_custom_bounds",
            "x": np.array([1.0, 3.0, 9.0, 11.0], dtype=float),
            "x_center": 6.0,
            "x_mid": 6.0,
            "lengthscale_lower": 1.0,
            "lengthscale_upper": 8.0,
            "covariance": "matern52",
        },
        {
            "name": "matern32_default_upper",
            "x": np.array([1.0, 4.0, 8.0, 13.0], dtype=float),
            "x_center": 7.0,
            "x_mid": 7.0,
            "lengthscale_lower": 1.25,
            "lengthscale_upper": None,
            "covariance": "matern32",
        },
        {
            "name": "expquad_distinct_centre_and_mid",
            "x": np.array([0.0, 1.0, 10.0], dtype=float),
            "x_center": 2.0,
            "x_mid": 5.0,
            "lengthscale_lower": 1.5,
            "lengthscale_upper": 7.0,
            "covariance": "expquad",
        },
    ]


def _build_hsgp_positive_multiplier_cases():
    return [
        {
            "name": "expquad_vector",
            "x": np.array([0.0, 1.0, 10.0], dtype=float),
            "m": 4,
            "L": 12.0,
            "covariance": "expquad",
            "eta": 1.7,
            "lengthscale": 2.5,
            "drop_first": False,
            "z": np.array([-1.0, 0.25, 0.5, -0.75], dtype=float),
        },
        {
            "name": "matern32_matrix",
            "x": np.array([-3.0, 0.0, 2.0, 7.0], dtype=float),
            "m": 5,
            "L": 10.0,
            "covariance": "matern32",
            "eta": 0.8,
            "lengthscale": 1.4,
            "drop_first": True,
            "z": np.array(
                [[-0.75, 0.5], [0.25, -1.0], [0.5, 0.75], [-0.25, 0.125]],
                dtype=float,
            ),
        },
        {
            "name": "zero_retained_modes_matrix",
            "x": np.array([0.0, 1.0, 10.0], dtype=float),
            "m": 1,
            "L": 12.0,
            "covariance": "expquad",
            "eta": 1.0,
            "lengthscale": 2.5,
            "drop_first": True,
            "z": np.empty((0, 2), dtype=float),
        },
        {
            "name": "all_softplus_underflow",
            "phi": np.ones((3, 1), dtype=float),
            "sqrt_psd": np.ones(1, dtype=float),
            "z": np.array([-1000.0], dtype=float),
            "expected_error": "nonpositive_raw_mean",
        },
        {
            "name": "partial_softplus_underflow",
            "phi": np.array([[1.0], [0.0]], dtype=float),
            "sqrt_psd": np.ones(1, dtype=float),
            "z": np.array([-1000.0], dtype=float),
            "expected_error": "nonpositive_raw_entry",
        },
    ]


def _build_hsgp_softplus_cases():
    return [
        {
            "name": "pytensor_thresholds_and_open_intervals",
            "values": np.array([-38.0, -37.0, 0.0, 18.0, 20.0, 33.3, 40.0], dtype=float),
        },
    ]


def _build_calibration_alignment_cases():
    return [
        {
            "name": "matches_model_coords",
            "coords": {
                "channel": [1, 2, 3],
                "geo": ["A", "B", "C"],
            },
            "df": {
                "channel": [1, 2],
                "geo": ["A", "C"],
            },
        },
        {
            "name": "single_dim_channel_only",
            "coords": {"channel": [1, 2, 3]},
            "df": {"channel": [3, 1]},
        },
    ]


def _build_calibration_unaligned_cases():
    return [
        {
            "name": "reports_unaligned_rows",
            "coords": {
                "channel": [1, 2, 3],
                "geo": ["A", "B", "C"],
            },
            "df": {
                "channel": [1000, 2],
                "geo": ["A", "Z"],
            },
        },
    ]


def _build_calibration_monotonic_cases():
    return [
        {
            "name": "monotonic_increasing",
            "delta_x": [1.0, 2.0, 3.0],
            "delta_y": [0.5, 1.0, 1.5],
            "expect_error": False,
        },
        {
            "name": "monotonic_zero_delta_x",
            "delta_x": [0.0, 2.0],
            "delta_y": [0.0, 1.0],
            "expect_error": False,
        },
        {
            "name": "non_monotonic_conflicting_sign",
            "delta_x": [1.0, 2.0, 3.0],
            "delta_y": [1.0, -2.0, 3.0],
            "expect_error": True,
        },
    ]


def _build_calibration_channel_scaling_cases():
    return [
        {
            "name": "sparse_channel_rows",
            "channel_columns": ["organic", "paid", "social"],
            "scale": [1.0, 2.0, 3.0],
            "df": {
                "channel": ["organic", "organic", "social"],
                "x": [1.0, 2.0, 3.0],
                "delta_x": [1.0, 1.0, 1.0],
            },
        },
    ]


def _build_calibration_target_scaling_cases():
    return [
        {
            "name": "rescale_series",
            "target": [0.0, 3.0, 6.0, 9.0],
            "scale": 3.0,
        },
    ]


def _build_calibration_combined_scaling_cases():
    return [
        {
            "name": "combines_channel_target_and_sigma_scaling",
            "channel_columns": [0, 1, 2],
            "df": {
                "channel": [0, 1],
                "x": [100.0, 50.0],
                "delta_x": [50.0, 25.0],
                "delta_y": [10.0, 20.0],
                "sigma": [2.0, 4.0],
            },
            "channel_transform_scale": 2.0,
            "target_transform_scale": 2.0,
        },
    ]


def _build_lift_likelihood_cases():
    return [
        {
            "name": "logistic_saturation_two_rows",
            "lam": 0.5,
            "x": [1.0, 2.0],
            "delta_x": [0.5, 1.0],
            "delta_y": [0.05, 0.08],
            "sigma": [0.01, 0.02],
        },
        {
            "name": "logistic_saturation_negative_delta",
            "lam": 1.2,
            "x": [3.0, 0.5],
            "delta_x": [-1.0, 2.0],
            "delta_y": [-0.02, 0.15],
            "sigma": [0.005, 0.03],
        },
    ]


def _build_cost_per_target_cases():
    return [
        {
            "name": "two_channel_two_row",
            "gathered_cpt": [0.5, 1.2],
            "targets": [0.45, 1.5],
            "sigma": [0.1, 0.2],
        },
        {
            "name": "single_row_exact_match",
            "gathered_cpt": [0.8],
            "targets": [0.8],
            "sigma": [0.05],
        },
    ]


def _build_calibration_integration_cases():
    return [
        {
            "name": "timeseries_logistic_lift_and_cost_per_target",
            "channel_columns": ["tv", "search"],
            "channel_scale": [4.0, 3.0],
            "target_scale": 11.5,
            "lam": [0.6, 0.7],
            "lift": {
                "channel": ["tv", "search"],
                "x": [1.0, 0.5],
                "delta_x": [0.5, 0.25],
                "delta_y": [0.3, 0.15],
                "sigma": [0.1, 0.05],
            },
            "cost_per_target": {
                "gathered_cpt": [0.5, 0.8],
                "targets": [0.45, 0.7],
                "sigma": [0.1, 0.2],
            },
        },
    ]


def _julia_int_vector_literal(values) -> str:
    body = ", ".join(str(int(value)) for value in values)
    return f"[{body}]"


def _julia_date_literal(value: date) -> str:
    return f"Date({value.year}, {value.month}, {value.day})"


def _julia_date_vector_literal(values) -> str:
    return "Date[" + ", ".join(_julia_date_literal(value) for value in values) + "]"


def _julia_value_vector_literal(values) -> str:
    values = list(values)
    if all(isinstance(value, bool) for value in values):
        body = ", ".join("true" if value else "false" for value in values)
        return f"Bool[{body}]"
    if all(isinstance(value, (int, np.integer)) and not isinstance(value, bool) for value in values):
        return _julia_int_vector_literal(values)
    if all(isinstance(value, str) for value in values):
        return _julia_string_vector_literal(values)
    if all(isinstance(value, (int, float, np.integer, np.floating)) for value in values):
        return _julia_array_literal(np.asarray(values, dtype=float))
    raise TypeError(f"Unsupported value vector types: {values!r}")


def _julia_namedtuple_literal(mapping: dict) -> str:
    fields = ", ".join(
        f"{key} = {_julia_value_vector_literal(value)}" for key, value in mapping.items()
    )
    return f"(; {fields})"


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


def _hsgp_time_index_rows():
    rows: list[str] = []
    for case in _build_hsgp_time_index_cases():
        new_dates = pd.Series(case["new_dates"])
        training_dates = pd.Series(case["training_dates"])
        expected_error = case.get("expected_error")

        try:
            expected = infer_time_index(
                new_dates,
                training_dates,
                case["time_resolution"],
            )
        except ValueError as err:
            if expected_error != "off_cadence":
                raise
            error_message = str(err)
            if not error_message.startswith(
                "Prediction dates must align to the fitted cadence."
            ):
                raise RuntimeError(
                    f"Unexpected Abacus infer_time_index failure for {case['name']!r}: "
                    f"{error_message}"
                ) from err
            expected_literal = "nothing"
            error_literal = _julia_string_literal(error_message)
        else:
            if expected_error is not None:
                raise RuntimeError(
                    f"Expected Abacus infer_time_index to reject {case['name']!r}"
                )
            expected_literal = "Int[" + ", ".join(str(int(value)) for value in expected) + "]"
            error_literal = "nothing"

        rows.extend(
            [
                "    (",
                f'        name = "{case["name"]}",',
                f"        new_dates = {_julia_date_vector_literal(case['new_dates'])},",
                f"        training_dates = {_julia_date_vector_literal(case['training_dates'])},",
                f"        time_resolution = {case['time_resolution']},",
                f"        expected = {expected_literal},",
                f"        expected_error = {error_literal},",
                "    ),",
            ]
        )
    return rows


def _hsgp_linearized_fixture_body() -> str:
    geometry_rows: list[str] = []
    covariance_classes = {
        "expquad": pm.gp.cov.ExpQuad,
        "matern32": pm.gp.cov.Matern32,
        "matern52": pm.gp.cov.Matern52,
    }
    for case in _build_hsgp_linearized_geometry_cases():
        covariance = case["covariance"]
        # PyMC 5.28 fails while compiling the valid m=1/drop_first=true
        # zero-column graph. Obtain its one-mode primitive output and apply the
        # same post-construction first-mode slice to the concrete arrays.
        evaluate_drop_first = case["drop_first"] and case["m"] > 1
        covariance_function = case["eta"] ** 2 * covariance_classes[covariance](
            input_dim=1,
            ls=case["lengthscale"],
        )
        gp = pm.gp.HSGP(
            m=[case["m"]],
            L=[case["L"]],
            cov_func=covariance_function,
            drop_first=evaluate_drop_first,
        )
        phi, sqrt_psd = gp.prior_linearized(case["x"][:, None])
        phi_values = np.asarray(phi.eval(), dtype=float)
        sqrt_psd_values = np.asarray(sqrt_psd.eval(), dtype=float)
        if case["drop_first"] and not evaluate_drop_first:
            phi_values = phi_values[:, 1:]
            sqrt_psd_values = sqrt_psd_values[1:]
        if case["demeaned_basis"]:
            phi_values = phi_values - phi_values.mean(axis=0, keepdims=True)
        geometry_rows.extend(
            [
                "        (",
                f'            name = "{case["name"]}",',
                f"            x = {_julia_array_literal(case['x'])},",
                f"            m = {case['m']},",
                f"            L = {_julia_float_literal(case['L'])},",
                f"            covariance = :{covariance},",
                f"            eta = {_julia_float_literal(case['eta'])},",
                f"            lengthscale = {_julia_float_literal(case['lengthscale'])},",
                f"            drop_first = {'true' if case['drop_first'] else 'false'},",
                f"            demeaned_basis = {'true' if case['demeaned_basis'] else 'false'},",
                f"            expected_phi = {_julia_array_literal(phi_values)},",
                f"            expected_sqrt_psd = {_julia_array_literal(sqrt_psd_values)},",
                "        ),",
            ]
        )

    recommendation_rows: list[str] = []
    for case in _build_hsgp_recommendation_cases():
        resolved_upper = case["lengthscale_upper"]
        if resolved_upper is None:
            resolved_upper = 2 * case["x_mid"]
        approximation_m, approximation_c = approx_hsgp_hyperparams(
            case["x"],
            case["x_center"],
            lengthscale_range=(case["lengthscale_lower"], resolved_upper),
            cov_func=case["covariance"],
        )
        recommendation_m, recommendation_L = create_m_and_L_recommendations(
            case["x"],
            case["x_mid"],
            ls_lower=case["lengthscale_lower"],
            ls_upper=case["lengthscale_upper"],
            cov_func=CovFunc(case["covariance"]),
        )
        upper_literal = (
            "nothing"
            if case["lengthscale_upper"] is None
            else _julia_float_literal(case["lengthscale_upper"])
        )
        recommendation_rows.extend(
            [
                "        (",
                f'            name = "{case["name"]}",',
                f"            x = {_julia_array_literal(case['x'])},",
                f"            x_center = {_julia_float_literal(case['x_center'])},",
                f"            x_mid = {_julia_float_literal(case['x_mid'])},",
                f"            lengthscale_lower = {_julia_float_literal(case['lengthscale_lower'])},",
                f"            lengthscale_upper = {upper_literal},",
                f"            resolved_lengthscale_upper = {_julia_float_literal(resolved_upper)},",
                f"            covariance = :{case['covariance']},",
                f"            expected_approx_m = {int(approximation_m)},",
                f"            expected_approx_c = {_julia_float_literal(approximation_c)},",
                f"            expected_recommendation_m = {int(recommendation_m)},",
                f"            expected_recommendation_L = {_julia_float_literal(recommendation_L)},",
                "        ),",
            ]
        )

    lines = ["(", "    geometry_cases = ["]
    lines.extend(geometry_rows)
    lines.extend(["    ],", "    recommendation_cases = ["])
    lines.extend(recommendation_rows)
    lines.extend(["    ],", ")"])
    return "\n".join(lines)


def _hsgp_linearized_arrays(case, covariance_classes):
    covariance = case["covariance"]
    # PyMC 5.28 fails while compiling the valid m=1/drop_first=true
    # zero-column graph. Obtain its one-mode primitive output and apply the
    # same post-construction first-mode slice to the concrete arrays.
    evaluate_drop_first = case["drop_first"] and case["m"] > 1
    covariance_function = case["eta"] ** 2 * covariance_classes[covariance](
        input_dim=1,
        ls=case["lengthscale"],
    )
    gp = pm.gp.HSGP(
        m=[case["m"]],
        L=[case["L"]],
        cov_func=covariance_function,
        drop_first=evaluate_drop_first,
    )
    phi, sqrt_psd = gp.prior_linearized(case["x"][:, None])
    phi_values = np.asarray(phi.eval(), dtype=float)
    sqrt_psd_values = np.asarray(sqrt_psd.eval(), dtype=float)
    if case["drop_first"] and not evaluate_drop_first:
        phi_values = phi_values[:, 1:]
        sqrt_psd_values = sqrt_psd_values[1:]
    return phi_values, sqrt_psd_values


def _hsgp_positive_multiplier_fixture_body() -> str:
    covariance_classes = {
        "expquad": pm.gp.cov.ExpQuad,
        "matern32": pm.gp.cov.Matern32,
        "matern52": pm.gp.cov.Matern52,
    }
    projection_rows: list[str] = []
    for case in _build_hsgp_positive_multiplier_cases():
        if "phi" in case:
            phi_values = np.asarray(case["phi"], dtype=float)
            sqrt_psd_values = np.asarray(case["sqrt_psd"], dtype=float)
        else:
            phi_values, sqrt_psd_values = _hsgp_linearized_arrays(
                case,
                covariance_classes,
            )
        z_values = np.asarray(case["z"], dtype=float)
        if z_values.ndim == 1:
            latent_values = phi_values @ (sqrt_psd_values * z_values)
            raw_values = np.asarray(pt.softplus(latent_values).eval(), dtype=float)
            raw_mean = raw_values.mean()
        else:
            latent_values = phi_values @ (sqrt_psd_values[:, None] * z_values)
            raw_values = np.asarray(pt.softplus(latent_values).eval(), dtype=float)
            raw_mean = raw_values.mean(axis=0, keepdims=True)

        expected_error = case.get("expected_error")
        if expected_error is None:
            multiplier_literal = _julia_array_literal(raw_values / raw_mean)
            error_literal = "nothing"
        else:
            if expected_error == "nonpositive_raw_mean" and not np.all(raw_values == 0.0):
                raise RuntimeError(
                    f"Expected all PyTensor softplus values to underflow for {case['name']!r}"
                )
            if expected_error == "nonpositive_raw_entry" and not (
                np.any(raw_values == 0.0) and np.any(raw_values > 0.0)
            ):
                raise RuntimeError(
                    f"Expected partial PyTensor softplus underflow for {case['name']!r}"
                )
            multiplier_literal = "nothing"
            error_literal = f":{expected_error}"

        projection_rows.extend(
            [
                "        (",
                f'            name = "{case["name"]}",',
                f"            phi = {_julia_array_literal(phi_values)},",
                f"            sqrt_psd = {_julia_array_literal(sqrt_psd_values)},",
                f"            z = {_julia_array_literal(z_values)},",
                f"            expected_latent = {_julia_array_literal(latent_values)},",
                f"            expected_softplus = {_julia_array_literal(raw_values)},",
                f"            expected_multiplier = {multiplier_literal},",
                f"            expected_error = {error_literal},",
                "        ),",
            ]
        )

    softplus_rows: list[str] = []
    for case in _build_hsgp_softplus_cases():
        values = np.asarray(case["values"], dtype=float)
        expected = np.asarray(pt.softplus(values).eval(), dtype=float)
        softplus_rows.extend(
            [
                "        (",
                f'            name = "{case["name"]}",',
                f"            values = {_julia_array_literal(values)},",
                f"            expected = {_julia_array_literal(expected)},",
                "        ),",
            ]
        )

    lines = ["(", "    projection_cases = ["]
    lines.extend(projection_rows)
    lines.extend(["    ],", "    softplus_cases = ["])
    lines.extend(softplus_rows)
    lines.extend(["    ],", ")"])
    return "\n".join(lines)


def _calibration_alignment_rows():
    rows: list[str] = []
    for case in _build_calibration_alignment_cases():
        coords = {key: np.array(value) for key, value in case["coords"].items()}
        model = pm.Model(coords=coords)
        df = pd.DataFrame(case["df"])
        indices = exact_row_indices(df, model)
        indices_literal = "Dict{String, Vector{Int}}(" + ", ".join(
            f'{_julia_string_literal(key)} => {_julia_int_vector_literal((np.asarray(value) + 1).tolist())}'
            for key, value in indices.items()
        ) + ")"
        rows.extend(
            [
                "    (",
                f'        name = "{case["name"]}",',
                f"        coords = {_julia_namedtuple_literal(case['coords'])},",
                f"        df = {_julia_namedtuple_literal(case['df'])},",
                f"        expected_indices_1based = {indices_literal},",
                "    ),",
            ]
        )
    return rows


def _calibration_unaligned_rows():
    rows: list[str] = []
    for case in _build_calibration_unaligned_cases():
        coords = {key: np.array(value) for key, value in case["coords"].items()}
        model = pm.Model(coords=coords)
        df = pd.DataFrame(case["df"])
        try:
            exact_row_indices(df, model)
            unaligned = {}
        except UnalignedValuesError as err:
            unaligned = err.unaligned_values
        unaligned_literal = "Dict{String, Vector{Int}}(" + ", ".join(
            f'{_julia_string_literal(key)} => {_julia_int_vector_literal((np.asarray(value) + 1).tolist())}'
            for key, value in unaligned.items()
        ) + ")"
        rows.extend(
            [
                "    (",
                f'        name = "{case["name"]}",',
                f"        coords = {_julia_namedtuple_literal(case['coords'])},",
                f"        df = {_julia_namedtuple_literal(case['df'])},",
                f"        expected_unaligned_1based = {unaligned_literal},",
                "    ),",
            ]
        )
    return rows


def _calibration_monotonic_rows():
    rows: list[str] = []
    for case in _build_calibration_monotonic_cases():
        rows.extend(
            [
                "    (",
                f'        name = "{case["name"]}",',
                f"        delta_x = {_julia_array_literal(np.asarray(case['delta_x'], dtype=float))},",
                f"        delta_y = {_julia_array_literal(np.asarray(case['delta_y'], dtype=float))},",
                f"        expect_error = {'true' if case['expect_error'] else 'false'},",
                "    ),",
            ]
        )
    return rows


def _calibration_channel_scaling_rows():
    rows: list[str] = []
    for case in _build_calibration_channel_scaling_cases():
        df = pd.DataFrame(case["df"])
        scale = np.asarray(case["scale"], dtype=float)
        channel_columns = case["channel_columns"]
        scale_lookup = dict(zip(channel_columns, scale))

        def transform(matrix: np.ndarray) -> np.ndarray:
            return matrix * scale

        result = scale_channel_lift_measurements(
            df_lift_test=df,
            channel_col="channel",
            channel_columns=channel_columns,
            transform=transform,
        )
        rows.extend(
            [
                "    (",
                f'        name = "{case["name"]}",',
                f"        channel_columns = {_julia_string_vector_literal(channel_columns)},",
                f"        scale = {_julia_array_literal(scale)},",
                f"        df = {_julia_namedtuple_literal(case['df'])},",
                f"        expected = {_julia_namedtuple_literal({'channel': result['channel'].tolist(), 'x': result['x'].tolist(), 'delta_x': result['delta_x'].tolist()})},",
                "    ),",
            ]
        )
    return rows


def _calibration_target_scaling_rows():
    rows: list[str] = []
    for case in _build_calibration_target_scaling_cases():
        target = pd.Series(case["target"], dtype=float)
        scale = float(case["scale"])
        result = scale_target_for_lift_measurements(
            target=target,
            transform=lambda matrix: matrix / scale,
        )
        rows.extend(
            [
                "    (",
                f'        name = "{case["name"]}",',
                f"        target = {_julia_array_literal(np.asarray(case['target'], dtype=float))},",
                f"        scale = {_julia_float_literal(scale)},",
                f"        expected = {_julia_array_literal(np.asarray(result.to_numpy(), dtype=float))},",
                "    ),",
            ]
        )
    return rows


def _calibration_combined_scaling_rows():
    rows: list[str] = []
    for case in _build_calibration_combined_scaling_cases():
        df = pd.DataFrame(case["df"])
        channel_scale = float(case["channel_transform_scale"])
        target_scale = float(case["target_transform_scale"])
        result = scale_lift_measurements(
            df_lift_test=df,
            channel_col="channel",
            channel_columns=case["channel_columns"],
            channel_transform=lambda matrix: matrix * channel_scale,
            target_transform=lambda matrix: matrix / target_scale,
        )
        rows.extend(
            [
                "    (",
                f'        name = "{case["name"]}",',
                f"        channel_columns = {_julia_int_vector_literal(case['channel_columns'])},",
                f"        df = {_julia_namedtuple_literal(case['df'])},",
                f"        channel_transform_scale = {_julia_float_literal(channel_scale)},",
                f"        target_transform_scale = {_julia_float_literal(target_scale)},",
                f"        expected = {_julia_namedtuple_literal({'channel': result['channel'].tolist(), 'x': result['x'].tolist(), 'delta_x': result['delta_x'].tolist(), 'delta_y': result['delta_y'].tolist(), 'sigma': result['sigma'].tolist()})},",
                "    ),",
            ]
        )
    return rows


def _lift_likelihood_rows():
    rows: list[str] = []
    for case in _build_lift_likelihood_cases():
        x = np.asarray(case["x"], dtype=float)
        delta_x = np.asarray(case["delta_x"], dtype=float)
        delta_y = np.asarray(case["delta_y"], dtype=float)
        sigma = np.asarray(case["sigma"], dtype=float)
        lam = float(case["lam"])
        x_after = x + delta_x
        model_estimated_lift = (
            logistic_saturation(x_after, lam=lam).eval()
            - logistic_saturation(x, lam=lam).eval()
        )
        mu = np.abs(model_estimated_lift)
        observed = np.abs(delta_y)
        logp = pm.logp(pm.Gamma.dist(mu=mu, sigma=sigma), observed).eval()
        rows.extend(
            [
                "    (",
                f'        name = "{case["name"]}",',
                f"        lam = {_julia_float_literal(lam)},",
                f"        x = {_julia_array_literal(x)},",
                f"        delta_x = {_julia_array_literal(delta_x)},",
                f"        delta_y = {_julia_array_literal(delta_y)},",
                f"        sigma = {_julia_array_literal(sigma)},",
                f"        expected_mu = {_julia_array_literal(np.asarray(mu, dtype=float))},",
                f"        expected_observed = {_julia_array_literal(np.asarray(observed, dtype=float))},",
                f"        expected_logp = {_julia_array_literal(np.asarray(logp, dtype=float))},",
                "    ),",
            ]
        )
    return rows


def _cost_per_target_rows():
    rows: list[str] = []
    for case in _build_cost_per_target_cases():
        gathered_cpt = np.asarray(case["gathered_cpt"], dtype=float)
        targets = np.asarray(case["targets"], dtype=float)
        sigma = np.asarray(case["sigma"], dtype=float)
        deviation = np.abs(gathered_cpt - targets)
        penalties = -(deviation**2) / (2.0 * (sigma**2))
        total_penalty = float(np.sum(penalties))
        rows.extend(
            [
                "    (",
                f'        name = "{case["name"]}",',
                f"        gathered_cpt = {_julia_array_literal(gathered_cpt)},",
                f"        targets = {_julia_array_literal(targets)},",
                f"        sigma = {_julia_array_literal(sigma)},",
                f"        expected_penalties = {_julia_array_literal(np.asarray(penalties, dtype=float))},",
                f"        expected_total_penalty = {_julia_float_literal(total_penalty)},",
                "    ),",
            ]
        )
    return rows


def _abacus_lift_log_density(scaled_lift: "pd.DataFrame", channel_columns, lam: np.ndarray) -> float:
    with pm.Model(coords={"channel": list(channel_columns)}) as model:
        pm.Data("lam", lam, dims="channel")
        add_saturation_observations(
            scaled_lift,
            {"lam": "lam"},
            lambda x, lam: logistic_saturation(x, lam=lam),
            model=model,
        )
        return float(model.compile_logp(sum=True)(model.initial_point()))


def _abacus_cost_per_target_log_density(
    scaled_cost_per_target: dict[str, np.ndarray],
    channel_columns,
) -> float:
    gathered = np.asarray(scaled_cost_per_target["gathered_cpt"], dtype=float)
    channel_data = np.repeat(gathered.reshape(1, -1), repeats=3, axis=0)
    calibration_df = pd.DataFrame(
        {
            "channel": list(channel_columns),
            "cost_per_target": np.asarray(scaled_cost_per_target["targets"], dtype=float),
            "sigma": np.asarray(scaled_cost_per_target["sigma"], dtype=float),
        }
    )
    with pm.Model(coords={"date": [1, 2, 3], "channel": list(channel_columns)}) as model:
        cpt_value = pm.Data("channel_data", channel_data, dims=("date", "channel"))
        add_cost_per_target_potentials(
            calibration_df,
            model=model,
            cpt_value=cpt_value,
        )
        return float(model.compile_logp(sum=True)(model.initial_point()))


def _calibration_integration_rows():
    rows: list[str] = []
    for case in _build_calibration_integration_cases():
        channel_columns = list(case["channel_columns"])
        channel_scale = np.asarray(case["channel_scale"], dtype=float)
        target_scale = float(case["target_scale"])
        lam = np.asarray(case["lam"], dtype=float)

        lift_df = pd.DataFrame(case["lift"])
        scaled_lift = scale_lift_measurements(
            df_lift_test=lift_df,
            channel_col="channel",
            channel_columns=channel_columns,
            channel_transform=lambda matrix: matrix / channel_scale,
            target_transform=lambda matrix: matrix / target_scale,
        )
        lift_log_density = _abacus_lift_log_density(scaled_lift, channel_columns, lam)

        cost_case = case["cost_per_target"]
        scaled_cost_per_target = {
            key: scale_target_for_lift_measurements(
                target=pd.Series(value, dtype=float),
                transform=lambda matrix: matrix / target_scale,
            ).to_numpy(dtype=float)
            for key, value in cost_case.items()
        }
        cost_per_target_log_density = _abacus_cost_per_target_log_density(
            scaled_cost_per_target,
            channel_columns,
        )
        total_log_density = lift_log_density + cost_per_target_log_density

        channel_index = [
            channel_columns.index(channel) + 1
            for channel in scaled_lift["channel"].tolist()
        ]
        rows.extend(
            [
                "    (",
                f'        name = "{case["name"]}",',
                f"        channel_columns = {_julia_string_vector_literal(channel_columns)},",
                f"        channel_scale = {_julia_array_literal(channel_scale)},",
                f"        target_scale = {_julia_float_literal(target_scale)},",
                f"        lam = {_julia_array_literal(lam)},",
                f"        lift = {_julia_namedtuple_literal(case['lift'])},",
                f"        cost_per_target = {_julia_namedtuple_literal(cost_case)},",
                "        expected_lift_payload = (",
                f"            channel_index = {_julia_int_vector_literal(channel_index)},",
                f"            x = {_julia_array_literal(np.asarray(scaled_lift['x'].to_numpy(), dtype=float))},",
                f"            delta_x = {_julia_array_literal(np.asarray(scaled_lift['delta_x'].to_numpy(), dtype=float))},",
                f"            delta_y = {_julia_array_literal(np.asarray(scaled_lift['delta_y'].to_numpy(), dtype=float))},",
                f"            sigma = {_julia_array_literal(np.asarray(scaled_lift['sigma'].to_numpy(), dtype=float))},",
                "        ),",
                "        expected_cost_per_target_payload = (",
                f"            gathered_cpt = {_julia_array_literal(scaled_cost_per_target['gathered_cpt'])},",
                f"            targets = {_julia_array_literal(scaled_cost_per_target['targets'])},",
                f"            sigma = {_julia_array_literal(scaled_cost_per_target['sigma'])},",
                "        ),",
                f"        expected_lift_log_density = {_julia_float_literal(lift_log_density)},",
                f"        expected_cost_per_target_log_density = {_julia_float_literal(cost_per_target_log_density)},",
                f"        expected_total_log_density = {_julia_float_literal(total_log_density)},",
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
        "--hsgp-time-index-output",
        default="test/fixtures/abacus/hsgp_time_index_cases.jl",
        help="Destination Julia HSGP time-index fixture file.",
    )
    parser.add_argument(
        "--hsgp-linearized-output",
        default="test/fixtures/abacus/hsgp_linearized_cases.jl",
        help="Destination Julia HSGP linearised-geometry fixture file.",
    )
    parser.add_argument(
        "--hsgp-positive-multiplier-output",
        default="test/fixtures/abacus/hsgp_positive_multiplier_cases.jl",
        help="Destination Julia HSGP positive-multiplier fixture file.",
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
    parser.add_argument(
        "--calibration-alignment-output",
        default="test/fixtures/abacus/calibration_alignment_cases.jl",
        help="Destination Julia calibration alignment fixture file.",
    )
    parser.add_argument(
        "--calibration-unaligned-output",
        default="test/fixtures/abacus/calibration_unaligned_cases.jl",
        help="Destination Julia calibration unaligned-rows fixture file.",
    )
    parser.add_argument(
        "--calibration-monotonic-output",
        default="test/fixtures/abacus/calibration_monotonic_cases.jl",
        help="Destination Julia calibration monotonicity fixture file.",
    )
    parser.add_argument(
        "--calibration-channel-scaling-output",
        default="test/fixtures/abacus/calibration_channel_scaling_cases.jl",
        help="Destination Julia calibration channel-scaling fixture file.",
    )
    parser.add_argument(
        "--calibration-target-scaling-output",
        default="test/fixtures/abacus/calibration_target_scaling_cases.jl",
        help="Destination Julia calibration target-scaling fixture file.",
    )
    parser.add_argument(
        "--calibration-combined-scaling-output",
        default="test/fixtures/abacus/calibration_combined_scaling_cases.jl",
        help="Destination Julia calibration combined-scaling fixture file.",
    )
    parser.add_argument(
        "--lift-likelihood-output",
        default="test/fixtures/abacus/lift_test_likelihood_cases.jl",
        help="Destination Julia lift-test likelihood fixture file.",
    )
    parser.add_argument(
        "--cost-per-target-output",
        default="test/fixtures/abacus/cost_per_target_cases.jl",
        help="Destination Julia cost-per-target penalty fixture file.",
    )
    parser.add_argument(
        "--calibration-integration-output",
        default="test/fixtures/abacus/calibration_integration_cases.jl",
        help="Destination Julia calibration model-integration fixture file.",
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
    global CovFunc
    global approx_hsgp_hyperparams
    global create_m_and_L_recommendations
    global infer_time_index
    global pt
    global tanh_saturation
    global weibull_adstock
    global pm
    global pd
    global exact_row_indices
    global UnalignedValuesError
    global scale_channel_lift_measurements
    global scale_target_for_lift_measurements
    global scale_lift_measurements
    global add_saturation_observations
    global add_cost_per_target_potentials
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
    from abacus.mmm.tvp import infer_time_index
    from abacus.mmm.hsgp import (
        CovFunc,
        approx_hsgp_hyperparams,
        create_m_and_L_recommendations,
    )
    import pymc as pm
    import pandas as pd
    import pytensor.tensor as pt
    from abacus.mmm.calibration.alignment import exact_row_indices, UnalignedValuesError
    from abacus.mmm.calibration.scaling import (
        scale_channel_lift_measurements,
        scale_target_for_lift_measurements,
        scale_lift_measurements,
    )
    from abacus.mmm.calibration.graph import (
        add_saturation_observations,
        add_cost_per_target_potentials,
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
    _write_fixture_file(
        "ABACUS_HSGP_TIME_INDEX_CASES",
        _hsgp_time_index_rows(),
        Path(args.hsgp_time_index_output),
        abacus_root=abacus_root,
        abacus_revision=abacus_revision,
    )
    _write_single_fixture_file(
        "ABACUS_HSGP_LINEARIZED_FIXTURES",
        _hsgp_linearized_fixture_body(),
        Path(args.hsgp_linearized_output),
        abacus_root=abacus_root,
        abacus_revision=abacus_revision,
    )
    _write_single_fixture_file(
        "ABACUS_HSGP_POSITIVE_MULTIPLIER_FIXTURES",
        _hsgp_positive_multiplier_fixture_body(),
        Path(args.hsgp_positive_multiplier_output),
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
    _write_fixture_file(
        "ABACUS_CALIBRATION_ALIGNMENT_CASES",
        _calibration_alignment_rows(),
        Path(args.calibration_alignment_output),
        abacus_root=abacus_root,
        abacus_revision=abacus_revision,
    )
    _write_fixture_file(
        "ABACUS_CALIBRATION_UNALIGNED_CASES",
        _calibration_unaligned_rows(),
        Path(args.calibration_unaligned_output),
        abacus_root=abacus_root,
        abacus_revision=abacus_revision,
    )
    _write_fixture_file(
        "ABACUS_CALIBRATION_MONOTONIC_CASES",
        _calibration_monotonic_rows(),
        Path(args.calibration_monotonic_output),
        abacus_root=abacus_root,
        abacus_revision=abacus_revision,
    )
    _write_fixture_file(
        "ABACUS_CALIBRATION_CHANNEL_SCALING_CASES",
        _calibration_channel_scaling_rows(),
        Path(args.calibration_channel_scaling_output),
        abacus_root=abacus_root,
        abacus_revision=abacus_revision,
    )
    _write_fixture_file(
        "ABACUS_CALIBRATION_TARGET_SCALING_CASES",
        _calibration_target_scaling_rows(),
        Path(args.calibration_target_scaling_output),
        abacus_root=abacus_root,
        abacus_revision=abacus_revision,
    )
    _write_fixture_file(
        "ABACUS_CALIBRATION_COMBINED_SCALING_CASES",
        _calibration_combined_scaling_rows(),
        Path(args.calibration_combined_scaling_output),
        abacus_root=abacus_root,
        abacus_revision=abacus_revision,
    )
    _write_fixture_file(
        "ABACUS_LIFT_TEST_LIKELIHOOD_CASES",
        _lift_likelihood_rows(),
        Path(args.lift_likelihood_output),
        abacus_root=abacus_root,
        abacus_revision=abacus_revision,
    )
    _write_fixture_file(
        "ABACUS_COST_PER_TARGET_CASES",
        _cost_per_target_rows(),
        Path(args.cost_per_target_output),
        abacus_root=abacus_root,
        abacus_revision=abacus_revision,
    )
    _write_fixture_file(
        "ABACUS_CALIBRATION_INTEGRATION_CASES",
        _calibration_integration_rows(),
        Path(args.calibration_integration_output),
        abacus_root=abacus_root,
        abacus_revision=abacus_revision,
    )

    _copy_demo_files(abacus_root, Path(args.demo_fixture_root), "timeseries")
    _copy_demo_files(abacus_root, Path(args.demo_fixture_root), "geo_panel")
    _copy_demo_files(abacus_root, Path(args.demo_fixture_root), "geo_brand_panel")



if __name__ == "__main__":
    main()
