"""probe-exporter: a Prometheus exporter that probes HTTP endpoints.

    probe-exporter https://example.com/ https://example.org/healthz --port 9101 --interval 30

Probes each target on an interval and serves the results at /metrics for
Prometheus to scrape:

    probe_success{target="..."}              1 if the target answered with a 2xx or 3xx
    probe_http_status_code{target="..."}     the last status code (0 if no answer)
    probe_duration_seconds{target="..."}     how long the last probe took

In production, the Prometheus Blackbox exporter does this and more; this is
the pattern for writing an exporter of your own, for anything Prometheus
can't see yet. Scrape it from the observability lab by adding a job to
devops/observability/local-stack/prometheus.yml.
"""

from __future__ import annotations

import argparse
import logging
import signal
import sys
import threading
import time
import urllib.error
import urllib.request
from collections.abc import Sequence
from types import FrameType

from prometheus_client import CollectorRegistry, Counter, Gauge, start_http_server

log = logging.getLogger("probe_exporter")


class Prober:
    """Holds the metrics and probes targets. Takes its own registry, so tests are isolated."""

    def __init__(self, targets: list[str], registry: CollectorRegistry, timeout: float = 5.0):
        self.targets = targets
        self.timeout = timeout
        self.success = Gauge(
            "probe_success", "Whether the last probe succeeded", ["target"], registry=registry
        )
        self.status_code = Gauge(
            "probe_http_status_code", "HTTP status of the last probe", ["target"], registry=registry
        )
        self.duration = Gauge(
            "probe_duration_seconds", "Duration of the last probe", ["target"], registry=registry
        )
        self.runs = Counter("probe_runs", "Probe rounds completed", registry=registry)

    def probe(self, target: str) -> None:
        start = time.monotonic()
        status = 0
        try:
            request = urllib.request.Request(target, headers={"User-Agent": "probe-exporter/0.1"})  # noqa: S310
            with urllib.request.urlopen(request, timeout=self.timeout) as response:  # noqa: S310 (scheme checked in main)
                status = int(response.status)
        except urllib.error.HTTPError as err:
            status = err.code
        except (urllib.error.URLError, TimeoutError, OSError) as err:
            log.warning("probe failed: %s: %s", target, getattr(err, "reason", err))
        self.duration.labels(target).set(time.monotonic() - start)
        self.status_code.labels(target).set(status)
        self.success.labels(target).set(1 if 200 <= status < 400 else 0)

    def run_once(self) -> None:
        for target in self.targets:
            self.probe(target)
        self.runs.inc()


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="probe-exporter", description=__doc__.splitlines()[0])
    parser.add_argument("targets", nargs="+", help="http or https URLs to probe")
    parser.add_argument("--port", type=int, default=9101, help="port for /metrics")
    parser.add_argument("--interval", type=float, default=30.0, help="seconds between rounds")
    parser.add_argument("--timeout", type=float, default=5.0, help="seconds per probe")
    args = parser.parse_args(argv)
    if any(not t.startswith(("http://", "https://")) for t in args.targets):
        parser.error("targets must be http or https URLs")

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    registry = CollectorRegistry()
    prober = Prober(args.targets, registry, timeout=args.timeout)
    server, _ = start_http_server(args.port, registry=registry)
    log.info(
        "serving /metrics on :%d, probing %d targets every %ss",
        args.port,
        len(args.targets),
        args.interval,
    )

    # Stop cleanly on SIGTERM (docker stop, Kubernetes) as well as Ctrl-C.
    stop = threading.Event()

    def on_signal(signum: int, frame: FrameType | None) -> None:
        stop.set()

    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT, on_signal)
    while not stop.is_set():
        prober.run_once()
        stop.wait(args.interval)
    server.shutdown()
    log.info("stopped")
    return 0


if __name__ == "__main__":
    sys.exit(main())
