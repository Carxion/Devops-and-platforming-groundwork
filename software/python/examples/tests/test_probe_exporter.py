"""probe-exporter against local HTTP servers, then reading its own /metrics."""

from __future__ import annotations

import socket
import threading
import urllib.request
from collections.abc import Iterator
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import pytest
from prometheus_client import CollectorRegistry, start_http_server

from ops_examples.probe_exporter import Prober


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        self.send_response(200 if self.path == "/ok" else 500)
        self.end_headers()

    def log_message(self, format: str, *args: object) -> None:
        pass


@pytest.fixture
def target() -> Iterator[str]:
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    yield f"http://127.0.0.1:{server.server_address[1]}"
    server.shutdown()


def closed_port() -> int:
    with socket.create_server(("127.0.0.1", 0)) as s:
        return int(s.getsockname()[1])


def test_probe_results(target: str) -> None:
    registry = CollectorRegistry()
    down = f"http://127.0.0.1:{closed_port()}/"
    prober = Prober([f"{target}/ok", f"{target}/broken", down], registry, timeout=2)
    prober.run_once()

    def value(name: str, url: str) -> float | None:
        return registry.get_sample_value(name, {"target": url})

    assert value("probe_success", f"{target}/ok") == 1
    assert value("probe_http_status_code", f"{target}/ok") == 200
    assert value("probe_success", f"{target}/broken") == 0
    assert value("probe_http_status_code", f"{target}/broken") == 500
    assert value("probe_success", down) == 0
    assert value("probe_http_status_code", down) == 0
    duration = value("probe_duration_seconds", f"{target}/ok")
    assert duration is not None and duration >= 0
    assert registry.get_sample_value("probe_runs_total") == 1


def test_metrics_endpoint(target: str) -> None:
    """What Prometheus sees when it scrapes the exporter."""
    registry = CollectorRegistry()
    Prober([f"{target}/ok"], registry).run_once()
    server, thread = start_http_server(0, addr="127.0.0.1", registry=registry)
    try:
        port = server.server_address[1]
        with urllib.request.urlopen(f"http://127.0.0.1:{port}/metrics", timeout=5) as resp:
            body = resp.read().decode()
    finally:
        server.shutdown()
        thread.join()
    assert f'probe_success{{target="{target}/ok"}} 1.0' in body
    assert "# TYPE probe_duration_seconds gauge" in body
