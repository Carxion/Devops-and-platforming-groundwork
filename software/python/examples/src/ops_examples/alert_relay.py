"""alert-relay: forward Alertmanager webhooks to a chat channel.

    RELAY_TOKEN=... CHAT_WEBHOOK_URL=https://hooks.example.com/... alert-relay --port 9102

Alertmanager posts alert groups to POST /alertmanager; the relay checks a
shared bearer token, formats a readable message, and posts {"text": "..."} to
an incoming-webhook URL (the format Slack-compatible webhooks accept), with
retries. Point Alertmanager at it:

    receivers:
      - name: on-call
        webhook_configs:
          - url: http://alert-relay:9102/alertmanager
            http_config:
              authorization: { credentials_file: /etc/alertmanager/relay-token }

Standard library only.
"""

from __future__ import annotations

import argparse
import hmac
import json
import logging
import os
import signal
import sys
import threading
import time
import urllib.error
import urllib.request
from collections.abc import Sequence
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

log = logging.getLogger("alert_relay")
MAX_BODY = 1024 * 1024


def format_message(payload: dict[str, Any]) -> str:
    """One message per Alertmanager group: a header line, then one line per alert."""
    alerts = payload.get("alerts", [])
    status = str(payload.get("status", "unknown")).upper()
    labels = payload.get("commonLabels", {})
    name = labels.get("alertname", "alert")
    severity = labels.get("severity")
    header = f"[{status}:{len(alerts)}] {name}" + (f" (severity={severity})" if severity else "")
    lines = [header]
    for alert in alerts:
        notes = alert.get("annotations", {})
        summary = notes.get("summary") or notes.get("description") or ""
        instance = alert.get("labels", {}).get("instance") or alert.get("labels", {}).get("job", "")
        line = f"- {summary}" + (f" [{instance}]" if instance else "")
        if notes.get("runbook_url"):
            line += f"\n  runbook: {notes['runbook_url']}"
        lines.append(line)
    return "\n".join(lines)


def post_with_retry(
    url: str, body: dict[str, Any], attempts: int = 3, timeout: float = 5.0
) -> bool:
    """POST JSON, retrying network errors and 5xx with backoff. Returns True on success."""
    data = json.dumps(body).encode()
    for attempt in range(1, attempts + 1):
        request = urllib.request.Request(  # noqa: S310 (scheme checked in main)
            url, data=data, method="POST", headers={"Content-Type": "application/json"}
        )
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:  # noqa: S310
                if 200 <= response.status < 300:
                    return True
        except urllib.error.HTTPError as err:
            if err.code < 500:
                log.error("chat webhook rejected the message: %s", err.code)
                return False  # a 4xx won't succeed on retry
            log.warning("chat webhook returned %s (attempt %d)", err.code, attempt)
        except (urllib.error.URLError, TimeoutError, OSError) as err:
            log.warning("chat webhook unreachable: %s (attempt %d)", err, attempt)
        if attempt < attempts:
            time.sleep(0.5 * 2 ** (attempt - 1))
    return False


def make_handler(token: str, chat_url: str) -> type[BaseHTTPRequestHandler]:
    class Handler(BaseHTTPRequestHandler):
        server_version = "alert-relay"

        def _reply(self, status: int, message: str) -> None:
            body = json.dumps({"status": message}).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self) -> None:
            if self.path == "/healthz":
                self._reply(HTTPStatus.OK, "ok")
            else:
                self._reply(HTTPStatus.NOT_FOUND, "not found")

        def do_POST(self) -> None:
            length = int(self.headers.get("Content-Length") or 0)
            if length > MAX_BODY:
                self.close_connection = True
                self._reply(HTTPStatus.REQUEST_ENTITY_TOO_LARGE, "too large")
                return
            raw = self.rfile.read(length)
            if self.path != "/alertmanager":
                self._reply(HTTPStatus.NOT_FOUND, "not found")
                return
            # Constant-time comparison, so the token can't be guessed byte by byte from timing.
            supplied = self.headers.get("Authorization", "").removeprefix("Bearer ")
            if not hmac.compare_digest(supplied.encode(), token.encode()):
                self._reply(HTTPStatus.UNAUTHORIZED, "unauthorized")
                return
            try:
                payload = json.loads(raw)
                if not isinstance(payload, dict) or not isinstance(payload.get("alerts"), list):
                    raise ValueError("not an Alertmanager payload")
            except ValueError:
                self._reply(HTTPStatus.BAD_REQUEST, "invalid payload")
                return
            if post_with_retry(chat_url, {"text": format_message(payload)}):
                self._reply(HTTPStatus.OK, "forwarded")
            else:
                # 5xx makes Alertmanager retry the notification later.
                self._reply(HTTPStatus.BAD_GATEWAY, "chat webhook failed")

        def log_message(self, format: str, *args: object) -> None:
            log.info("%s %s", self.address_string(), format % args)

    return Handler


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="alert-relay", description=__doc__.splitlines()[0])
    parser.add_argument("--host", default="0.0.0.0")  # noqa: S104 (a service: listens on all interfaces)
    parser.add_argument("--port", type=int, default=9102)
    args = parser.parse_args(argv)

    # Secrets and endpoints from the environment, never from arguments (visible in ps).
    token = os.environ.get("RELAY_TOKEN", "")
    chat_url = os.environ.get("CHAT_WEBHOOK_URL", "")
    if len(token) < 16:
        parser.error("set RELAY_TOKEN to a shared secret of at least 16 characters")
    if not chat_url.startswith(("https://", "http://")):
        parser.error("set CHAT_WEBHOOK_URL to the chat incoming-webhook URL")

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    server = ThreadingHTTPServer((args.host, args.port), make_handler(token, chat_url))
    log.info("listening on %s:%d", args.host, args.port)

    # Serve in a thread; stop cleanly on SIGTERM (docker stop, Kubernetes) or Ctrl-C.
    stop = threading.Event()
    signal.signal(signal.SIGTERM, lambda signum, frame: stop.set())
    signal.signal(signal.SIGINT, lambda signum, frame: stop.set())
    threading.Thread(target=server.serve_forever, daemon=True).start()
    stop.wait()
    server.shutdown()  # finishes in-flight requests, then returns
    log.info("stopped")
    return 0


if __name__ == "__main__":
    sys.exit(main())
