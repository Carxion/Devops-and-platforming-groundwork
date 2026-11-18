"""The evaluation gate: run the prompt over a labelled dataset and fail below a threshold.

  python -m ticket_triage.experiment --label staging --min-accuracy 0.8

Each run is recorded in Langfuse as an experiment, so you can compare prompt
versions and models side by side. Exit codes: 0 passed, 1 below the threshold.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any, cast

from langfuse import Evaluation, get_client
from langfuse.experiment import LocalExperimentItem

from ticket_triage.app import client, get_prompt, triage

DATASET = Path(__file__).resolve().parents[2] / "evals" / "dataset.jsonl"


def load(path: Path = DATASET) -> list[LocalExperimentItem]:
    rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line]
    return [LocalExperimentItem(input=r["input"], expected_output=r["expected"]) for r in rows]


def exact_match(*, output: str, expected_output: str, **_: Any) -> Evaluation:
    return Evaluation(name="correct", value=1.0 if output == expected_output else 0.0)


def accuracy(item_results: list[Any]) -> float:
    scores = [e.value for r in item_results for e in r.evaluations if e.name == "correct"]
    return sum(scores) / len(scores) if scores else 0.0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", default="production", help="prompt label to evaluate")
    parser.add_argument("--min-accuracy", type=float, default=0.8)
    args = parser.parse_args()

    prompt = get_prompt(args.label)
    if prompt.is_fallback:
        print(f"error: prompt label {args.label!r} not found in Langfuse", file=sys.stderr)
        return 2
    llm = client()

    def task(*, item: Any, **_: Any) -> str:
        return triage(item["input"], prompt=prompt, llm=llm)

    result = get_client().run_experiment(
        name="ticket-triage",
        run_name=f"{args.label}-v{prompt.version}-{os.environ.get('CI_COMMIT_SHORT_SHA', 'local')}",
        data=load(),
        task=task,
        evaluators=[exact_match],
        max_concurrency=4,
        metadata={
            "prompt_version": str(prompt.version),
            "model": os.environ.get("LLM_MODEL", "chat"),
        },
    )
    get_client().flush()
    score = accuracy(result.item_results)
    print(f"prompt version {prompt.version}: accuracy {score:.2f} (minimum {args.min_accuracy})")
    for r in result.item_results:
        item = cast(LocalExperimentItem, r.item)
        if r.output != item["expected_output"]:
            print(f"  miss: expected {item['expected_output']}, got {r.output}: {item['input']}")
    return 0 if score >= args.min_accuracy else 1


if __name__ == "__main__":
    sys.exit(main())
