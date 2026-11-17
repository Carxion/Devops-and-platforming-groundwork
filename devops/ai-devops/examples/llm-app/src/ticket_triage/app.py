"""The application: fetch the prompt, call the model through the gateway, parse the answer.

Configuration comes from the environment, so the same code runs on a laptop,
in CI, and in production:

  LLM_BASE_URL, LLM_API_KEY   the gateway (LiteLLM) and a virtual key for this app
  LLM_MODEL                   the gateway alias to use (default "chat")
  LANGFUSE_BASE_URL, LANGFUSE_PUBLIC_KEY, LANGFUSE_SECRET_KEY   tracing and prompts
  PROMPT_LABEL                which prompt version to use (default "production")
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

import langfuse.openai  # noqa: F401  (importing it instruments the OpenAI client)
from langfuse import get_client, observe
from openai import OpenAI

PROMPT_NAME = "ticket-triage"
PROMPT_FILE = Path(__file__).resolve().parents[2] / "prompts" / "ticket-triage.txt"
TEAMS = ("billing", "outage", "account", "other")


def local_prompt() -> str:
    return PROMPT_FILE.read_text(encoding="utf-8")


def parse(answer: str) -> str:
    """The first team named in the answer, or "other". Never trust the model's format."""
    words = answer.strip().lower().replace(".", " ").replace(",", " ").split()
    for word in words:
        if word in TEAMS:
            return word
    return "other"


def get_prompt(label: str | None = None) -> Any:
    """The managed prompt for `label`, or the copy in this repository if Langfuse is unreachable.

    The fallback keeps the application up when the prompt service is down; the
    trace records which one was used (prompt.is_fallback).
    """
    return get_client().get_prompt(
        PROMPT_NAME,
        label=label or os.environ.get("PROMPT_LABEL", "production"),
        fallback=local_prompt(),
        cache_ttl_seconds=60,
        max_retries=1,
        fetch_timeout_seconds=5,
    )


def client() -> OpenAI:
    return OpenAI(
        base_url=os.environ.get("LLM_BASE_URL", "http://localhost:4000"),
        api_key=os.environ.get("LLM_API_KEY", "missing"),
    )


@observe(name="triage")
def triage(ticket: str, prompt: Any | None = None, llm: OpenAI | None = None) -> str:
    prompt = prompt or get_prompt()
    # Read by the Langfuse wrapper, not sent to the model: links this
    # generation to the prompt version it used.
    tracing: dict[str, Any] = {"langfuse_prompt": None if prompt.is_fallback else prompt}
    response = (llm or client()).chat.completions.create(
        model=os.environ.get("LLM_MODEL", "chat"),
        messages=[{"role": "user", "content": prompt.compile(ticket=ticket)}],
        temperature=0,
        max_tokens=5,
        **tracing,
    )
    return parse(response.choices[0].message.content or "")


def main() -> None:
    import sys

    for ticket in sys.argv[1:] or ["The site has been down for ten minutes."]:
        print(f"{triage(ticket)}\t{ticket}")
    get_client().flush()


if __name__ == "__main__":
    main()
