"""Offline tests: no gateway, no Langfuse. The model is a fake client, and
Langfuse is pointed at a closed port so get_prompt must use the fallback."""

from __future__ import annotations

from types import SimpleNamespace
from typing import Any

import pytest

from ticket_triage import app, experiment


@pytest.fixture(autouse=True)
def offline(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("LANGFUSE_BASE_URL", "http://127.0.0.1:9")
    monkeypatch.setenv("LANGFUSE_PUBLIC_KEY", "pk-test")
    monkeypatch.setenv("LANGFUSE_SECRET_KEY", "sk-test")
    monkeypatch.setenv("LANGFUSE_TRACING_ENABLED", "false")


class FakeLLM:
    """Answers with a fixed string and records what it was sent."""

    def __init__(self, answer: str) -> None:
        self.answer = answer
        self.sent: list[dict[str, Any]] = []
        self.chat = SimpleNamespace(completions=SimpleNamespace(create=self._create))

    def _create(self, **kwargs: Any) -> Any:
        self.sent.append(kwargs)
        message = SimpleNamespace(content=self.answer)
        return SimpleNamespace(choices=[SimpleNamespace(message=message)])


@pytest.mark.parametrize(
    ("answer", "team"),
    [
        ("billing", "billing"),
        ("  Outage.\n", "outage"),
        ("The team is: account", "account"),
        ("I think this is about shipping", "other"),
        ("", "other"),
    ],
)
def test_parse(answer: str, team: str) -> None:
    assert app.parse(answer) == team


def test_prompt_falls_back_to_the_repository_copy() -> None:
    prompt = app.get_prompt("production")
    assert prompt.is_fallback
    assert "{{ticket}}" in prompt.prompt


def test_triage_sends_the_compiled_prompt() -> None:
    llm = FakeLLM("billing")
    assert app.triage("Charged twice", llm=llm) == "billing"  # type: ignore[arg-type]
    sent = llm.sent[0]
    assert sent["temperature"] == 0
    assert sent["messages"][0]["content"].endswith("Ticket: Charged twice\n")
    assert sent["langfuse_prompt"] is None  # a fallback prompt isn't linked


def test_dataset_covers_every_team_but_other() -> None:
    rows = experiment.load()
    assert {r["expected_output"] for r in rows} == {"billing", "outage", "account"}


def test_accuracy() -> None:
    def result(*values: float) -> Any:
        return SimpleNamespace(
            evaluations=[SimpleNamespace(name="correct", value=v) for v in values]
        )

    assert experiment.accuracy([result(1.0), result(0.0), result(1.0), result(1.0)]) == 0.75
    assert experiment.accuracy([]) == 0.0
