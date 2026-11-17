"""Command line for each pipeline stage.

Exit codes: 0 fine, 1 a finding (invalid data, a failed gate), 2 usage or
configuration error.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from wine_model import config, data, evaluate, registry, train


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="wine-model", description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("prepare", help="write data/train.csv and data/test.csv")
    p_validate = sub.add_parser("validate", help="check CSV files against the schema")
    p_validate.add_argument("paths", nargs="+", type=Path)
    sub.add_parser("train", help="train, save models/model.skops, log an MLflow run")
    sub.add_parser("evaluate", help="write metrics.json and log it to the run")
    sub.add_parser("gate", help="fail unless metrics.json passes the release gate")
    p_register = sub.add_parser("register", help="register the run's model under an alias")
    p_register.add_argument("--alias", default="challenger")
    p_promote = sub.add_parser("promote", help="move one alias to another's version")
    p_promote.add_argument("--from", dest="from_alias", default="challenger")
    p_promote.add_argument("--to", dest="to_alias", default="champion")
    args = parser.parse_args(argv)

    try:
        return _dispatch(args)
    except (FileNotFoundError, KeyError, ValueError) as err:
        print(f"error: {err}", file=sys.stderr)
        return 2


def _dispatch(args: argparse.Namespace) -> int:
    if args.command == "prepare":
        p = config.params("prepare")
        for path in data.prepare(p["test_size"], p["seed"]):
            print(f"wrote {path}")
        return 0
    if args.command == "validate":
        status = 0
        for path in args.paths:
            problems = data.validate(data.read(path))
            for problem in problems:
                print(f"{path}: {problem}")
            status = 1 if problems else status
            print(f"{path}: {'invalid' if problems else 'valid'}")
        return status
    if args.command == "train":
        print(f"run {train.run(config.params('train'), config.DATA_DIR / 'train.csv')}")
        return 0
    if args.command == "evaluate":
        print(json.dumps(evaluate.run(config.DATA_DIR / "test.csv")))
        return 0
    if args.command == "gate":
        metrics = json.loads(config.METRICS_PATH.read_text(encoding="utf-8"))
        champion = evaluate.champion_metrics(registry.client())
        verdict = evaluate.decide(metrics, config.params("gate"), champion)
        print(f"candidate {metrics}; champion {champion or 'none'}")
        for reason in verdict.reasons:
            print(f"gate: {reason}")
        print("gate: passed" if verdict.passed else "gate: failed")
        return 0 if verdict.passed else 1
    if args.command == "register":
        print(f"{config.MODEL_NAME} version {registry.register(args.alias)} is @{args.alias}")
        return 0
    if args.command == "promote":
        version = registry.promote(args.from_alias, args.to_alias)
        print(f"{config.MODEL_NAME} @{args.to_alias} -> version {version}")
        return 0
    return 2


if __name__ == "__main__":
    sys.exit(main())
