"""Measure the model on held-out data, and decide whether it may ship."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import mlflow
import skops.io as sio
from mlflow import MlflowClient
from mlflow.exceptions import MlflowException
from sklearn.metrics import accuracy_score, f1_score

from wine_model import config, data


def load_model(path: Path) -> Any:
    untrusted = sio.get_untrusted_types(file=path)
    unexpected = [t for t in untrusted if t not in config.TRUSTED_TYPES]
    if unexpected:
        raise ValueError(f"model file contains untrusted types: {unexpected}")
    return sio.load(path, trusted=untrusted)


def measure(model: Any, test_path: Path) -> dict[str, float]:
    frame = data.read(test_path)
    predicted = model.predict(frame[data.FEATURES])
    truth = frame[data.TARGET]
    return {
        "accuracy": round(float(accuracy_score(truth, predicted)), 4),
        "f1_macro": round(float(f1_score(truth, predicted, average="macro")), 4),
    }


def run(test_path: Path, model_path: Path = config.MODEL_PATH) -> dict[str, float]:
    metrics = measure(load_model(model_path), test_path)
    config.METRICS_PATH.write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    if config.RUN_FILE.exists():
        run_id = json.loads(config.RUN_FILE.read_text(encoding="utf-8"))["run_id"]
        mlflow.set_tracking_uri(config.tracking_uri())
        with mlflow.start_run(run_id=run_id):
            mlflow.log_metrics(metrics)
    return metrics


@dataclass(frozen=True)
class Verdict:
    passed: bool
    reasons: list[str]


def decide(
    metrics: dict[str, float], gate: dict[str, Any], champion: dict[str, float] | None
) -> Verdict:
    """The release gate: absolute floors first, then no regression against the champion."""
    reasons = []
    if metrics["accuracy"] < gate["min_accuracy"]:
        reasons.append(f"accuracy {metrics['accuracy']} is below {gate['min_accuracy']}")
    if metrics["f1_macro"] < gate["min_f1_macro"]:
        reasons.append(f"f1_macro {metrics['f1_macro']} is below {gate['min_f1_macro']}")
    if champion is not None:
        floor = round(champion["f1_macro"] - gate["max_regression"], 4)
        if metrics["f1_macro"] < floor:
            reasons.append(
                f"f1_macro {metrics['f1_macro']} regresses on the champion's "
                f"{champion['f1_macro']} by more than {gate['max_regression']}"
            )
    return Verdict(passed=not reasons, reasons=reasons)


def champion_metrics(
    client: MlflowClient, name: str = config.MODEL_NAME
) -> dict[str, float] | None:
    """Metrics of the run behind the model version aliased "champion", if there is one."""
    try:
        version = client.get_model_version_by_alias(name, "champion")
    except MlflowException:
        return None
    if version.run_id is None:
        return None
    logged = client.get_run(version.run_id).data.metrics
    if "f1_macro" not in logged:
        return None
    return {"accuracy": logged.get("accuracy", 0.0), "f1_macro": logged["f1_macro"]}
