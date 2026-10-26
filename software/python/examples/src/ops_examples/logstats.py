"""logstats: summarize web access logs (nginx and Apache combined format).

    logstats /var/log/nginx/access.log /var/log/nginx/access.log.2.gz
    zcat access.log.*.gz | logstats --output json
    logstats access.log --max-error-ratio 0.01    # exit 1 if over 1% 5xx

Streams the input line by line, so it handles logs larger than memory. The
Bash version of the same idea is devops/bash/scripts/log-summary.sh.
"""

from __future__ import annotations

import argparse
import gzip
import json
import re
import sys
from collections import Counter
from collections.abc import Iterable, Iterator, Sequence
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, TextIO

# 203.0.113.9 - - [13/Oct/2026:08:00:01 +0000] "GET /items/17 HTTP/1.1" 200 512 "-" "curl/8.5.0"
LINE = re.compile(
    r"^(?P<ip>\S+) \S+ \S+ \[(?P<time>[^\]]+)\] "
    r'"(?P<method>[A-Z]+) (?P<path>\S+)[^"]*" (?P<status>\d{3}) (?P<bytes>\d+|-)'
)
NUMERIC_SEGMENT = re.compile(r"/\d+(?=/|$)")
UUID_SEGMENT = re.compile(r"/[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}(?=/|$)")


def route(path: str) -> str:
    """Collapse IDs so /items/17 and /items/42 count as one route: /items/{id}."""
    path = path.split("?", 1)[0]
    path = UUID_SEGMENT.sub("/{uuid}", path)
    return NUMERIC_SEGMENT.sub("/{id}", path)


@dataclass
class Stats:
    requests: int = 0
    unparsed: int = 0
    bytes_sent: int = 0
    status: Counter[str] = field(default_factory=Counter)
    routes: Counter[str] = field(default_factory=Counter)
    clients: Counter[str] = field(default_factory=Counter)
    per_minute: Counter[str] = field(default_factory=Counter)
    server_errors: Counter[str] = field(default_factory=Counter)

    @property
    def error_ratio(self) -> float:
        errors = sum(n for code, n in self.status.items() if code.startswith("5"))
        return errors / self.requests if self.requests else 0.0

    def add(self, line: str) -> None:
        m = LINE.match(line)
        if not m:
            self.unparsed += 1
            return
        self.requests += 1
        code = m["status"]
        self.status[code] += 1
        key = f"{m['method']} {route(m['path'])}"
        self.routes[key] += 1
        self.clients[m["ip"]] += 1
        self.per_minute[m["time"][:17]] += 1  # 13/Oct/2026:08:00
        if m["bytes"] != "-":
            self.bytes_sent += int(m["bytes"])
        if code.startswith("5"):
            self.server_errors[f"{code} {key}"] += 1

    def summary(self, top: int) -> dict[str, Any]:
        busiest = self.per_minute.most_common(1)
        return {
            "requests": self.requests,
            "unparsed_lines": self.unparsed,
            "bytes_sent": self.bytes_sent,
            "error_ratio": round(self.error_ratio, 4),
            "peak_minute": {"minute": busiest[0][0], "requests": busiest[0][1]}
            if busiest
            else None,
            "status": dict(sorted(self.status.items())),
            "top_routes": self.routes.most_common(top),
            "top_clients": self.clients.most_common(top),
            "top_server_errors": self.server_errors.most_common(top),
        }


def read_lines(paths: Sequence[Path], stdin: TextIO) -> Iterator[str]:
    """Yield lines from each file (gzip if it ends in .gz), or from stdin if none."""
    if not paths:
        yield from stdin
        return
    for path in paths:
        opener = gzip.open if path.suffix == ".gz" else open
        with opener(path, "rt", encoding="utf-8", errors="replace") as f:
            yield from f


def analyze(lines: Iterable[str]) -> Stats:
    stats = Stats()
    for line in lines:
        stats.add(line)
    return stats


def render_text(s: dict[str, Any]) -> str:
    out = [
        f"Requests: {s['requests']}, 5xx ratio: {s['error_ratio']:.2%}, "
        f"data sent: {s['bytes_sent'] / 1_048_576:.1f} MB, unparsed lines: {s['unparsed_lines']}",
    ]
    if s["peak_minute"]:
        out.append(f"Peak minute: {s['peak_minute']['minute']} ({s['peak_minute']['requests']})")
    out.append("Status: " + ", ".join(f"{k}={v}" for k, v in s["status"].items()))
    for title, key in [
        ("Top routes", "top_routes"),
        ("Top clients", "top_clients"),
        ("Top server errors", "top_server_errors"),
    ]:
        if s[key]:
            out.append(f"\n{title}")
            out += [f"  {n:>7}  {name}" for name, n in s[key]]
    return "\n".join(out)


def main(argv: Sequence[str] | None = None, stdin: TextIO = sys.stdin) -> int:
    parser = argparse.ArgumentParser(prog="logstats", description=__doc__.splitlines()[0])
    parser.add_argument(
        "files", nargs="*", type=Path, help="log files (.gz read directly); stdin if none"
    )
    parser.add_argument("--top", type=int, default=10)
    parser.add_argument("-o", "--output", choices=["text", "json"], default="text")
    parser.add_argument("--max-error-ratio", type=float, help="exit 1 if the 5xx ratio is higher")
    args = parser.parse_args(argv)

    try:
        stats = analyze(read_lines(args.files, stdin))
    except OSError as err:
        parser.error(str(err))
    summary = stats.summary(args.top)
    print(json.dumps(summary, indent=2) if args.output == "json" else render_text(summary))

    if args.max_error_ratio is not None and stats.error_ratio > args.max_error_ratio:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
