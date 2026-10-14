"""Command-line interface: parse arguments, run the checks, print, and set the exit code."""

from __future__ import annotations

import argparse
import json
import logging
import sys
from collections.abc import Sequence
from pathlib import Path

from healthcheck import __version__
from healthcheck.checker import Result, check_all

log = logging.getLogger("healthcheck")

EXIT_OK = 0
EXIT_FAILED = 1
EXIT_USAGE = 2


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="healthcheck",
        description="Check that HTTP endpoints answer with the expected status, in parallel.",
        epilog="Exit codes: 0 all healthy, 1 at least one failed, 2 bad usage.",
    )
    parser.add_argument("urls", nargs="*", help="URLs to check")
    parser.add_argument(
        "-f", "--file", type=Path, help="read URLs from a file, one per line (# comments allowed)"
    )
    parser.add_argument("-t", "--timeout", type=float, default=5.0, help="seconds per request")
    parser.add_argument("-e", "--expect-status", type=int, default=200, help="healthy HTTP status")
    parser.add_argument("-c", "--concurrency", type=int, default=8, help="requests in parallel")
    parser.add_argument("-o", "--output", choices=["text", "json"], default="text")
    parser.add_argument("-v", "--verbose", action="store_true", help="debug logging to stderr")
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    return parser


def read_url_file(path: Path) -> list[str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    return [line.strip() for line in lines if line.strip() and not line.lstrip().startswith("#")]


def render_text(results: list[Result]) -> str:
    width = max(len(r.url) for r in results)
    rows = []
    for r in results:
        state = "OK  " if r.ok else "FAIL"
        detail = str(r.status) if r.status is not None else (r.error or "")
        rows.append(f"{state}  {r.url:<{width}}  {detail:<6}  {r.elapsed_ms} ms")
    return "\n".join(rows)


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.WARNING,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        stream=sys.stderr,  # stderr for logs, stdout for results, so output can be piped
    )

    urls = list(args.urls)
    if args.file:
        try:
            urls += read_url_file(args.file)
        except OSError as err:
            parser.error(f"can't read {args.file}: {err.strerror}")
    if not urls:
        parser.error("give at least one URL, or --file")
    if args.timeout <= 0 or args.concurrency < 1:
        parser.error("--timeout must be positive and --concurrency at least 1")

    log.debug("checking %d URL(s) with concurrency %d", len(urls), args.concurrency)
    results = check_all(
        urls,
        timeout=args.timeout,
        expect_status=args.expect_status,
        concurrency=args.concurrency,
    )

    if args.output == "json":
        print(json.dumps([r.to_dict() for r in results], indent=2))
    else:
        print(render_text(results))
    return EXIT_OK if all(r.ok for r in results) else EXIT_FAILED


if __name__ == "__main__":
    raise SystemExit(main())
