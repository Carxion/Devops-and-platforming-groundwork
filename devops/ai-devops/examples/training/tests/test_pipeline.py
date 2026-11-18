"""Tests for each stage. They need no network and no MLflow server: MLflow
writes to a SQLite file in a temporary directory."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from wine_model import config, data, evaluate, train
from wine_model.__main__ import main

TRAIN_PARAMS = {"model": "logistic_regression", "C": 1.0, "n_estimators": 10, "seed": 42}
GATE = {"min_accuracy": 0.9, "min_f1_macro": 0.9, "max_regression": 0.01}


@pytest.fixture
def workdir(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    """Run each test in an empty directory with its own params and MLflow store."""
    monkeypatch.chdir(tmp_path)
    monkeypatch.setenv("MLFLOW_TRACKING_URI", f"sqlite:///{tmp_path / 'mlflow.db'}")
    project = Path(__file__).resolve().parent.parent
    (tmp_path / "params.yaml").write_text(
        (project / "params.yaml").read_text(encoding="utf-8"), encoding="utf-8"
    )
    return tmp_path


@pytest.fixture
def splits(workdir: Path) -> tuple[Path, Path]:
    return data.prepare(test_size=0.25, seed=42, out_dir=workdir / "data")


def test_prepared_data_is_valid(splits: tuple[Path, Path]) -> None:
    for path in splits:
        assert data.validate(data.read(path)) == []


def test_validation_reports_each_problem(splits: tuple[Path, Path]) -> None:
    frame = data.read(splits[0])
    frame.loc[0, "alcohol"] = -1.0
    frame.loc[1, "target"] = 7
    frame["unexpected"] = 0
    problems = data.validate(frame)
    joined = "\n".join(problems)
    assert "alcohol" in joined
    assert "target" in joined
    assert "unexpected" in joined


def test_validation_catches_a_missing_class(splits: tuple[Path, Path]) -> None:
    frame = data.read(splits[0])
    only_two = frame[frame["target"] != 2]
    assert any("class is missing" in p for p in data.validate(only_two))


def test_split_is_reproducible(workdir: Path) -> None:
    first = data.prepare(0.25, 42, workdir / "a")
    second = data.prepare(0.25, 42, workdir / "b")
    assert first[0].read_bytes() == second[0].read_bytes()


def test_random_forest_round_trips(splits: tuple[Path, Path], workdir: Path) -> None:
    params = {**TRAIN_PARAMS, "model": "random_forest"}
    train.run(params, splits[0], workdir / "rf.skops")
    assert evaluate.measure(evaluate.load_model(workdir / "rf.skops"), splits[1])["accuracy"] > 0.9


def test_training_is_reproducible(splits: tuple[Path, Path]) -> None:
    a = train.fit(TRAIN_PARAMS, splits[0])
    b = train.fit(TRAIN_PARAMS, splits[0])
    assert evaluate.measure(a, splits[1]) == evaluate.measure(b, splits[1])


def test_unknown_model_is_a_configuration_error() -> None:
    with pytest.raises(ValueError, match="unknown model"):
        train.build({**TRAIN_PARAMS, "model": "xgboost"})


def test_train_and_evaluate_log_one_run(splits: tuple[Path, Path], workdir: Path) -> None:
    run_id = train.run(TRAIN_PARAMS, splits[0], workdir / "models" / "model.skops")
    metrics = evaluate.run(splits[1], workdir / "models" / "model.skops")
    assert metrics["accuracy"] >= 0.9
    assert json.loads(config.METRICS_PATH.read_text(encoding="utf-8")) == metrics
    import mlflow

    logged = mlflow.get_run(run_id).data
    assert logged.metrics["f1_macro"] == metrics["f1_macro"]
    assert logged.params["model"] == "logistic_regression"


@pytest.mark.parametrize(
    ("metrics", "champion", "passed"),
    [
        ({"accuracy": 0.95, "f1_macro": 0.95}, None, True),
        ({"accuracy": 0.85, "f1_macro": 0.95}, None, False),  # below the floor
        ({"accuracy": 0.95, "f1_macro": 0.95}, {"accuracy": 0.96, "f1_macro": 0.955}, True),
        ({"accuracy": 0.95, "f1_macro": 0.93}, {"accuracy": 0.96, "f1_macro": 0.96}, False),
    ],
)
def test_gate(metrics: dict[str, float], champion: dict[str, float] | None, passed: bool) -> None:
    verdict = evaluate.decide(metrics, GATE, champion)
    assert verdict.passed is passed
    assert bool(verdict.reasons) is not passed


def test_cli_end_to_end_with_registry(workdir: Path, capsys: pytest.CaptureFixture[str]) -> None:
    """prepare, validate, train, evaluate, gate, register, promote; then a worse
    candidate fails the gate against the champion."""
    assert main(["prepare"]) == 0
    assert main(["validate", "data/train.csv", "data/test.csv"]) == 0
    assert main(["train"]) == 0
    assert main(["evaluate"]) == 0
    assert main(["gate"]) == 0
    assert main(["register"]) == 0
    assert main(["promote"]) == 0
    assert "@champion -> version 1" in capsys.readouterr().out

    # A candidate whose metrics are worse than the champion's must not pass.
    config.METRICS_PATH.write_text(json.dumps({"accuracy": 0.91, "f1_macro": 0.91}))
    assert main(["gate"]) == 1
    assert "regresses on the champion" in capsys.readouterr().out


def test_cli_invalid_data_exits_1(splits: tuple[Path, Path]) -> None:
    bad = data.read(splits[0]).drop(columns=["proline"])
    bad.to_csv("bad.csv", index=False)
    assert main(["validate", "bad.csv"]) == 1


def test_cli_missing_input_exits_2(workdir: Path) -> None:
    assert main(["evaluate"]) == 2


def test_model_file_with_unexpected_types_is_refused(
    splits: tuple[Path, Path], workdir: Path
) -> None:
    import datetime

    import skops.io as sio

    path = workdir / "odd.skops"
    sio.dump({"odd": datetime.timedelta(days=1)}, path)
    with pytest.raises(ValueError, match="untrusted types"):
        evaluate.load_model(path)
