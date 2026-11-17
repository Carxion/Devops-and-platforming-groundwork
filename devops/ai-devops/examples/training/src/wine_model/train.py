"""Train the model, save it in a safe format, and record the run in MLflow."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

import mlflow
import skops.io as sio
from mlflow.models import infer_signature
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline, make_pipeline
from sklearn.preprocessing import StandardScaler

from wine_model import config, data


def build(params: dict[str, Any]) -> Pipeline:
    kind = params["model"]
    if kind == "logistic_regression":
        # float(): YAML 1.1 (PyYAML) reads 1e-05 as a string; it needs 1.0e-05.
        estimator: Any = LogisticRegression(
            C=float(params["C"]), max_iter=1000, random_state=params["seed"]
        )
    elif kind == "random_forest":
        estimator = RandomForestClassifier(
            n_estimators=int(params["n_estimators"]), random_state=params["seed"]
        )
    else:
        raise ValueError(f"unknown model {kind!r}: use logistic_regression or random_forest")
    return make_pipeline(StandardScaler(), estimator)


def fit(params: dict[str, Any], train_path: Path) -> Pipeline:
    frame = data.read(train_path)
    model = build(params)
    model.fit(frame[data.FEATURES], frame[data.TARGET])
    return model


def run(params: dict[str, Any], train_path: Path, model_path: Path = config.MODEL_PATH) -> str:
    """Train, save, and log; returns the MLflow run ID."""
    model = fit(params, train_path)
    model_path.parent.mkdir(parents=True, exist_ok=True)
    # skops, not pickle: loading a pickle runs whatever code it contains.
    sio.dump(model, model_path)

    frame = data.read(train_path)
    sample = frame[data.FEATURES].head(5)
    mlflow.set_tracking_uri(config.tracking_uri())
    mlflow.set_experiment(config.EXPERIMENT)
    with mlflow.start_run() as active:
        mlflow.log_params(params)
        mlflow.set_tags(_provenance())
        info = mlflow.sklearn.log_model(
            model,
            name="model",
            serialization_format="skops",
            skops_trusted_types=config.TRUSTED_TYPES,
            signature=infer_signature(sample, model.predict(sample)),
            input_example=sample,
        )
        run_id: str = active.info.run_id
    config.RUN_FILE.parent.mkdir(parents=True, exist_ok=True)
    # MLflow 3 stores the model as its own entity (models:/m-...), linked to the run.
    record = {"run_id": run_id, "model_uri": info.model_uri}
    config.RUN_FILE.write_text(json.dumps(record) + "\n", encoding="utf-8")
    return run_id


def _provenance() -> dict[str, str]:
    """Tie the run to the commit and pipeline that produced it (set by GitLab CI)."""
    keys = {"CI_COMMIT_SHA": "git_commit", "CI_PIPELINE_URL": "pipeline_url", "CI_JOB_ID": "job_id"}
    return {tag: os.environ[env] for env, tag in keys.items() if os.environ.get(env)}
