"""Tests run against a real HTTP server on localhost, so they need no network access."""

from __future__ import annotations

import json
import threading
from collections.abc import Iterator
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import pytest

from healthcheck.checker import check_all, check_url
from healthcheck.cli import EXIT_FAILED, EXIT_OK, main


class _Handler(BaseHTTPRequestHandler):
    """/ok answers 200, /broken answers 500, /slow waits before answering."""

    def do_GET(self) -> None:
        if self.path == "/slow":
            threading.Event().wait(1.0)
        status = 500 if self.path == "/broken" else 200
        self.send_response(status)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def log_message(self, format: str, *args: object) -> None:  # keep test output quiet
        pass


@pytest.fixture(scope="module")
def server() -> Iterator[str]:
    httpd = ThreadingHTTPServer(("127.0.0.1", 0), _Handler)  # port 0: any free port
    thread = threading.Thread(target=httpd.serve_forever, daemon=True)
    thread.start()
    yield f"http://127.0.0.1:{httpd.server_address[1]}"
    httpd.shutdown()


def test_healthy_endpoint(server: str) -> None:
    result = check_url(f"{server}/ok")
    assert result.ok
    assert result.status == 200
    assert result.error is None


def test_server_error_is_unhealthy_but_reported(server: str) -> None:
    result = check_url(f"{server}/broken")
    assert not result.ok
    assert result.status == 500


def test_expected_status_can_be_changed(server: str) -> None:
    assert check_url(f"{server}/broken", expect_status=500).ok


def test_timeout_is_a_failure_not_an_exception(server: str) -> None:
    result = check_url(f"{server}/slow", timeout=0.2)
    assert not result.ok
    assert result.status is None
    assert result.error


def test_connection_refused(server: str) -> None:
    result = check_url("http://127.0.0.1:1/")
    assert not result.ok
    assert result.error


@pytest.mark.parametrize("url", ["file:///etc/passwd", "ftp://example.com/", "not-a-url"])
def test_non_http_schemes_are_refused(url: str) -> None:
    result = check_url(url)
    assert not result.ok
    assert result.error == "only http and https URLs"


def test_check_all_keeps_input_order(server: str) -> None:
    urls = [f"{server}/broken", f"{server}/ok", f"{server}/ok"]
    results = check_all(urls, concurrency=3)
    assert [r.url for r in results] == urls
    assert [r.ok for r in results] == [False, True, True]


def test_cli_exit_codes(server: str, capsys: pytest.CaptureFixture[str]) -> None:
    assert main([f"{server}/ok"]) == EXIT_OK
    assert main([f"{server}/ok", f"{server}/broken"]) == EXIT_FAILED
    assert "FAIL" in capsys.readouterr().out


def test_cli_json_output(server: str, capsys: pytest.CaptureFixture[str]) -> None:
    main(["--output", "json", f"{server}/ok"])
    data = json.loads(capsys.readouterr().out)
    assert data[0]["ok"] is True
    assert data[0]["status"] == 200


def test_cli_reads_url_file(server: str, tmp_path: Path) -> None:
    url_file = tmp_path / "urls.txt"
    url_file.write_text(f"# production\n{server}/ok\n\n{server}/ok\n", encoding="utf-8")
    assert main(["--file", str(url_file)]) == EXIT_OK


def test_cli_without_urls_is_a_usage_error() -> None:
    with pytest.raises(SystemExit) as exc:
        main([])
    assert exc.value.code == 2
