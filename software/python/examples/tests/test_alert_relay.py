"""alert-relay end to end: a fake Alertmanager post in, a fake chat webhook out."""

from __future__ import annotations

import json
import threading
import urllib.error
import urllib.request
from collections.abc import Iterator
from dataclasses import dataclass, field
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

import pytest

from ops_examples import alert_relay

TOKEN = "test-token-0123456789"

ALERT = {
    "version": "4",
    "status": "firing",
    "receiver": "on-call",
    "commonLabels": {"alertname": "HighErrorRate", "severity": "page"},
    "alerts": [
        {
            "status": "firing",
            "labels": {"alertname": "HighErrorRate", "instance": "api-1:8080"},
            "annotations": {
                "summary": "5xx ratio above 5% for 10 minutes",
                "runbook_url": "https://runbooks.example.com/high-error-rate",
            },
        },
        {
            "status": "firing",
            "labels": {"alertname": "HighErrorRate", "job": "api"},
            "annotations": {"description": "second replica"},
        },
    ],
}


@dataclass
class FakeChat:
    url: str
    received: list[dict[str, Any]] = field(default_factory=list)
    fail_next: int = 0  # answer this many requests with 503 first


@pytest.fixture
def chat() -> Iterator[FakeChat]:
    fake = FakeChat(url="")

    class Handler(BaseHTTPRequestHandler):
        def do_POST(self) -> None:
            body = self.rfile.read(int(self.headers["Content-Length"]))
            if fake.fail_next:
                fake.fail_next -= 1
                self.send_response(503)
            else:
                fake.received.append(json.loads(body))
                self.send_response(200)
            self.end_headers()

        def log_message(self, format: str, *args: object) -> None:
            pass

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    fake.url = f"http://127.0.0.1:{server.server_address[1]}/hook"
    yield fake
    server.shutdown()


@pytest.fixture
def relay(chat: FakeChat, monkeypatch: pytest.MonkeyPatch) -> Iterator[str]:
    monkeypatch.setattr("time.sleep", lambda _: None)  # no real backoff in tests
    server = ThreadingHTTPServer(("127.0.0.1", 0), alert_relay.make_handler(TOKEN, chat.url))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    yield f"http://127.0.0.1:{server.server_address[1]}"
    server.shutdown()


def post(url: str, body: bytes, token: str | None = TOKEN) -> int:
    headers = {"Content-Type": "application/json"}
    if token is not None:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, data=body, headers=headers, method="POST")  # noqa: S310
    try:
        with urllib.request.urlopen(request, timeout=5) as response:  # noqa: S310
            return int(response.status)
    except urllib.error.HTTPError as err:
        return err.code


def test_format_message() -> None:
    text = alert_relay.format_message(ALERT)
    assert text.splitlines()[0] == "[FIRING:2] HighErrorRate (severity=page)"
    assert "- 5xx ratio above 5% for 10 minutes [api-1:8080]" in text
    assert "runbook: https://runbooks.example.com/high-error-rate" in text
    assert "- second replica [api]" in text


def test_forwards_alert(relay: str, chat: FakeChat) -> None:
    assert post(f"{relay}/alertmanager", json.dumps(ALERT).encode()) == 200
    assert len(chat.received) == 1
    assert chat.received[0]["text"].startswith("[FIRING:2] HighErrorRate")


def test_retries_then_succeeds(relay: str, chat: FakeChat) -> None:
    chat.fail_next = 2
    assert post(f"{relay}/alertmanager", json.dumps(ALERT).encode()) == 200
    assert len(chat.received) == 1


def test_gives_up_with_502(relay: str, chat: FakeChat) -> None:
    chat.fail_next = 3
    assert post(f"{relay}/alertmanager", json.dumps(ALERT).encode()) == 502
    assert chat.received == []


@pytest.mark.parametrize("token", [None, "wrong-token-0123456789", ""])
def test_rejects_bad_token(relay: str, chat: FakeChat, token: str | None) -> None:
    assert post(f"{relay}/alertmanager", json.dumps(ALERT).encode(), token=token) == 401
    assert chat.received == []


@pytest.mark.parametrize("body", [b"not json", b"[]", b'{"alerts": "nope"}'])
def test_rejects_bad_payload(relay: str, body: bytes) -> None:
    assert post(f"{relay}/alertmanager", body) == 400


def test_unknown_path_and_health(relay: str) -> None:
    assert post(f"{relay}/other", b"{}") == 404
    with urllib.request.urlopen(f"{relay}/healthz", timeout=5) as response:  # noqa: S310
        assert response.status == 200
