"""Register a run's model and move the champion and challenger aliases."""

from __future__ import annotations

import json

import mlflow
from mlflow import MlflowClient

from wine_model import config


def client() -> MlflowClient:
    mlflow.set_tracking_uri(config.tracking_uri())
    return MlflowClient()


def register(alias: str = "challenger") -> str:
    """Register the model from the last training run and point `alias` at it."""
    model_uri = json.loads(config.RUN_FILE.read_text(encoding="utf-8"))["model_uri"]
    c = client()
    version = mlflow.register_model(model_uri, config.MODEL_NAME)
    c.set_registered_model_alias(config.MODEL_NAME, alias, version.version)
    return str(version.version)


def promote(from_alias: str = "challenger", to_alias: str = "champion") -> str:
    """Point `to_alias` at whatever `from_alias` points to. Rolling back is the same move."""
    c = client()
    version = c.get_model_version_by_alias(config.MODEL_NAME, from_alias)
    c.set_registered_model_alias(config.MODEL_NAME, to_alias, version.version)
    return str(version.version)
