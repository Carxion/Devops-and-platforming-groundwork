from __future__ import annotations

import gzip
import io
import json
from pathlib import Path

import pytest

from ops_examples import logstats

SAMPLE = """\
203.0.113.9 - - [13/Oct/2026:08:00:01 +0000] "GET /items/17 HTTP/1.1" 200 512 "-" "curl/8.5.0"
203.0.113.9 - - [13/Oct/2026:08:00:02 +0000] "GET /items/42?full=1 HTTP/1.1" 200 1024 "-" "curl/8.5.0"
198.51.100.4 - alice [13/Oct/2026:08:00:30 +0000] "POST /items HTTP/1.1" 201 64 "-" "app/1.0"
198.51.100.4 - - [13/Oct/2026:08:01:05 +0000] "GET /items/9b2f1c3e-0a4d-4e5f-8a6b-7c8d9e0f1a2b HTTP/1.1" 404 - "-" "app/1.0"
192.0.2.7 - - [13/Oct/2026:08:01:10 +0000] "DELETE /items/17 HTTP/1.1" 503 0 "-" "app/1.0"
this line is not a log line
"""


@pytest.mark.parametrize(
    ("path", "expected"),
    [
        ("/items/17", "/items/{id}"),
        ("/items/17/notes/3", "/items/{id}/notes/{id}"),
        ("/items?page=2", "/items"),
        ("/items/9b2f1c3e-0a4d-4e5f-8a6b-7c8d9e0f1a2b", "/items/{uuid}"),
        ("/v2/items", "/v2/items"),  # a digit inside a segment is not an ID
    ],
)
def test_route(path: str, expected: str) -> None:
    assert logstats.route(path) == expected


def test_analyze() -> None:
    stats = logstats.analyze(SAMPLE.splitlines())
    assert stats.requests == 5
    assert stats.unparsed == 1
    assert stats.bytes_sent == 512 + 1024 + 64
    assert stats.status == {"200": 2, "201": 1, "404": 1, "503": 1}
    assert stats.routes["GET /items/{id}"] == 2
    assert stats.error_ratio == pytest.approx(0.2)
    summary = stats.summary(top=3)
    assert summary["peak_minute"] == {"minute": "13/Oct/2026:08:00", "requests": 3}
    assert summary["top_server_errors"] == [("503 DELETE /items/{id}", 1)]


def test_empty_input() -> None:
    stats = logstats.analyze([])
    assert stats.error_ratio == 0.0
    assert stats.summary(top=5)["peak_minute"] is None


def test_reads_gzip_and_plain(tmp_path: Path) -> None:
    plain = tmp_path / "access.log"
    plain.write_text(SAMPLE, encoding="utf-8")
    zipped = tmp_path / "access.log.1.gz"
    with gzip.open(zipped, "wt", encoding="utf-8") as f:
        f.write(SAMPLE)
    lines = list(logstats.read_lines([plain, zipped], io.StringIO()))
    assert len(lines) == 2 * len(SAMPLE.splitlines())


def test_main_json_from_stdin(capsys: pytest.CaptureFixture[str]) -> None:
    assert logstats.main(["--output", "json"], stdin=io.StringIO(SAMPLE)) == 0
    out = json.loads(capsys.readouterr().out)
    assert out["requests"] == 5


def test_main_error_budget(capsys: pytest.CaptureFixture[str]) -> None:
    assert logstats.main(["--max-error-ratio", "0.5"], stdin=io.StringIO(SAMPLE)) == 0
    assert logstats.main(["--max-error-ratio", "0.1"], stdin=io.StringIO(SAMPLE)) == 1
    assert "5xx ratio: 20.00%" in capsys.readouterr().out
