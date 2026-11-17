"""Prepare the dataset and validate it before anything trains on it."""

from __future__ import annotations

from pathlib import Path

import pandas as pd
import pandera.pandas as pa
from sklearn.datasets import load_wine
from sklearn.model_selection import train_test_split

from wine_model.config import DATA_DIR

TARGET = "target"
CLASSES = [0, 1, 2]


def _feature_name(raw: str) -> str:
    return raw.replace("/", "_")


FEATURES = [_feature_name(n) for n in load_wine().feature_names]

# The contract the training code relies on. A data change that breaks it
# fails the pipeline here, with a readable report, instead of producing a
# quietly worse model three stages later.
SCHEMA = pa.DataFrameSchema(
    {
        **{name: pa.Column(float, pa.Check.ge(0), nullable=False) for name in FEATURES},
        TARGET: pa.Column(int, pa.Check.isin(CLASSES), nullable=False),
    },
    checks=[
        pa.Check(lambda df: len(df) >= 30, error="fewer than 30 rows"),
        # Every class must be present, or the model can't learn it.
        pa.Check(lambda df: set(df[TARGET]) == set(CLASSES), error="a class is missing"),
    ],
    strict=True,  # unexpected columns fail too
    coerce=False,
)


def load_source() -> pd.DataFrame:
    """The raw dataset (bundled with scikit-learn, so this needs no network)."""
    bunch = load_wine(as_frame=True)
    frame: pd.DataFrame = bunch.frame
    return frame.rename(columns=_feature_name)


def prepare(test_size: float, seed: int, out_dir: Path = DATA_DIR) -> tuple[Path, Path]:
    frame = load_source()
    train, test = train_test_split(
        frame, test_size=test_size, random_state=seed, stratify=frame[TARGET]
    )
    out_dir.mkdir(parents=True, exist_ok=True)
    train_path, test_path = out_dir / "train.csv", out_dir / "test.csv"
    train.to_csv(train_path, index=False)
    test.to_csv(test_path, index=False)
    return train_path, test_path


def read(path: Path) -> pd.DataFrame:
    return pd.read_csv(path)


def validate(frame: pd.DataFrame) -> list[str]:
    """Every schema violation as a readable line; empty when the data is valid."""
    try:
        SCHEMA.validate(frame, lazy=True)
    except pa.errors.SchemaErrors as err:
        cases = err.failure_cases
        return [
            f"{row.column}: {row.check} (value {row.failure_case!r})" for row in cases.itertuples()
        ]
    return []
