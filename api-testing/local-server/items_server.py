#!/usr/bin/env python3
"""In-memory reference implementation of api-testing/openapi/items-api.yaml.

Behaves like the AWS and Azure item stores (terraform/aws/serverless-api,
terraform/azure/functions-api), so every test in this folder can run on a
laptop or in CI without a cloud account. Standard library only.

  python items_server.py [--host 127.0.0.1] [--port 8080]

Data lives in memory and is lost on exit. Not for production use.
"""

from __future__ import annotations

import argparse
import json
import re
import signal
import sys
import threading
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote, urlsplit

ROUTE = re.compile(r"/items/([^/]+)")
VALID_ID = re.compile(r"[A-Za-z0-9._-]{1,128}")
MAX_BODY = 256 * 1024  # bytes; DynamoDB items are capped at 400 KB

_items: dict[str, dict] = {}
_lock = threading.Lock()


class Handler(BaseHTTPRequestHandler):
    server_version = "items-server/1.0"
    protocol_version = "HTTP/1.1"

    def _send(self, status: int, body: dict | None = None, headers: dict | None = None) -> None:
        payload = json.dumps(body).encode() if body is not None else b""
        self.send_response(status)
        if body is not None:
            self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        for name, value in (headers or {}).items():
            self.send_header(name, value)
        self.end_headers()
        self.wfile.write(payload)

    def _item_id(self) -> str | None:
        """Return the ID for /items/{id}, or None after sending an error."""
        match = ROUTE.fullmatch(urlsplit(self.path).path)
        if not match:
            self._send(HTTPStatus.NOT_FOUND, {"error": "not found"})
            return None
        item_id = unquote(match.group(1))
        if not VALID_ID.fullmatch(item_id):
            self._send(HTTPStatus.BAD_REQUEST, {"error": "invalid id"})
            return None
        return item_id

    def _read_body(self) -> bytes | None:
        """Read the whole request body, so the connection stays in sync for the next request.

        Returns None (and closes the connection afterward) when the body is too large to read.
        """
        try:
            length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            length = -1
        if length < 0 or length > MAX_BODY:
            self.close_connection = True
            return None
        return self.rfile.read(length)

    def do_GET(self) -> None:  # noqa: N802 (http.server naming)
        self._read_body()
        item_id = self._item_id()
        if item_id is None:
            return
        with _lock:
            item = _items.get(item_id)
        if item is None:
            self._send(HTTPStatus.NOT_FOUND, {"error": "not found"})
        else:
            self._send(HTTPStatus.OK, {**item, "id": item_id})

    def do_PUT(self) -> None:  # noqa: N802
        raw = self._read_body()
        item_id = self._item_id()
        if item_id is None:
            return
        if raw is None:
            self._send(HTTPStatus.REQUEST_ENTITY_TOO_LARGE, {"error": "body too large"})
            return
        try:
            data = json.loads(raw)  # an empty body is invalid JSON, so it's rejected
        except ValueError:
            self._send(HTTPStatus.BAD_REQUEST, {"error": "body must be JSON"})
            return
        if not isinstance(data, dict):
            self._send(HTTPStatus.BAD_REQUEST, {"error": "body must be a JSON object"})
            return
        with _lock:
            _items[item_id] = {k: v for k, v in data.items() if k != "id"}
        self._send(HTTPStatus.OK, {"id": item_id})

    def do_DELETE(self) -> None:  # noqa: N802
        self._read_body()
        item_id = self._item_id()
        if item_id is None:
            return
        with _lock:
            _items.pop(item_id, None)
        self._send(HTTPStatus.NO_CONTENT)

    def _not_allowed(self) -> None:
        self._read_body()
        self._send(HTTPStatus.METHOD_NOT_ALLOWED, {"error": "method not allowed"}, {"Allow": "GET, PUT, DELETE"})

    def __getattr__(self, name: str):
        # http.server dispatches to do_<METHOD>; answer every method without one
        # (POST, PATCH, OPTIONS, QUERY, ...) with 405 instead of its default 501.
        if name.startswith("do_"):
            return self._not_allowed
        raise AttributeError(name)

    def do_HEAD(self) -> None:  # noqa: N802
        # No body on HEAD responses.
        self.send_response(HTTPStatus.METHOD_NOT_ALLOWED)
        self.send_header("Allow", "GET, PUT, DELETE")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def log_message(self, fmt: str, *args) -> None:
        # One line per request, like an access log.
        print(f"{self.address_string()} {fmt % args}", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args()
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    # Exit cleanly on SIGTERM. In a container this process is PID 1, which
    # gets no default signal handling: without this, "docker stop" waits 10
    # seconds and then kills it.
    signal.signal(signal.SIGTERM, lambda signum, frame: sys.exit(0))
    print(f"Items API listening on http://{args.host}:{args.port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
