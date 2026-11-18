"""Paths and parameters shared by every stage."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

import yaml

DATA_DIR = Path("data")
MODEL_PATH = Path("models/model.skops")
RUN_FILE = Path("models/run.json")
METRICS_PATH = Path("metrics.json")
PARAMS_PATH = Path("params.yaml")

MODEL_NAME = os.environ.get("MODEL_NAME", "wine-classifier")
EXPERIMENT = os.environ.get("MLFLOW_EXPERIMENT_NAME", "wine-classifier")

# skops loads only types it knows are safe. These are the others this
# project's models may contain (a random forest's trees). Loading trusts these
# and nothing else, never whatever a file asks for.
TRUSTED_TYPES = ["sklearn.tree._tree.Tree"]


def tracking_uri() -> str:
    """MLflow server from the environment, or a local SQLite store for offline runs."""
    return os.environ.get("MLFLOW_TRACKING_URI", "sqlite:///mlflow.db")


def params(section: str) -> dict[str, Any]:
    loaded = yaml.safe_load(PARAMS_PATH.read_text(encoding="utf-8"))
    value: dict[str, Any] = loaded[section]
    return value
