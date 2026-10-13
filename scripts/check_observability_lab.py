#!/usr/bin/env python3
"""Check the local observability lab end to end, against a running stack.

Start it first:
  docker compose -f observability/local-stack/compose.yaml --profile traffic up -d

Then this script waits until each signal arrives and fails if any doesn't:
  - every Prometheus scrape target is up, and the SLO recording rules have values
  - Tempo has traces from web-app, and Loki has its logs, linked by trace ID
  - Grafana's data sources pass their health checks and both dashboards are loaded
  - with the default traffic (2% errors), the availability page alert fires
    and reaches Alertmanager's on-call receiver

Standard library only. Usage: python scripts/check_observability_lab.py [--timeout 600]
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

PROMETHEUS = "http://127.0.0.1:9090"
TEMPO = "http://127.0.0.1:3200"
LOKI = "http://127.0.0.1:3100"
GRAFANA = "http://127.0.0.1:3000"
ALERTMANAGER = "http://127.0.0.1:9093"


def get(url: str, params: dict | None = None):
    if params:
        url += "?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=10) as r:
        return json.load(r)


def prom(query: str) -> list:
    return get(f"{PROMETHEUS}/api/v1/query", {"query": query})["data"]["result"]


def wait_for(name: str, check, deadline: float) -> None:
    """Retry check() until it returns a truthy value or the deadline passes."""
    last = None
    while time.time() < deadline:
        try:
            result = check()
            if result:
                print(f"ok    {name}: {result}", flush=True)
                return
        except (urllib.error.URLError, KeyError, IndexError, ValueError) as err:
            last = err
        time.sleep(5)
    print(f"FAIL  {name}" + (f" (last error: {last})" if last else ""), flush=True)
    raise SystemExit(1)


def targets_up():
    targets = get(f"{PROMETHEUS}/api/v1/targets", {"state": "active"})["data"]["activeTargets"]
    jobs = {t["labels"]["job"]: t["health"] for t in targets}
    # Every job in prometheus.yml must be present and up (not merely "none down").
    expected = {"web-app", "prometheus", "alertmanager", "otel-collector", "tempo", "loki", "grafana"}
    ok = expected <= jobs.keys() and all(jobs[j] == "up" for j in expected)
    return ok and f"{len(expected)} targets up"


def recording_rules():
    result = prom('job:slo_availability_errors:ratio_rate5m{job="web-app"}')
    return result and f"error ratio {float(result[0]['value'][1]):.4f}"


def traces():
    found = get(f"{TEMPO}/api/search", {"q": '{ resource.service.name = "web-app" }', "limit": 5}).get("traces", [])
    return found and f"{len(found)} traces"


def logs_linked_to_trace():
    trace_id = get(f"{TEMPO}/api/search", {"q": '{ resource.service.name = "web-app" }', "limit": 1})["traces"][0]["traceID"]
    trace_id = trace_id.rjust(32, "0")  # Tempo's search API drops leading zeros
    start = str(int((time.time() - 3600) * 1e9))
    streams = get(f"{LOKI}/loki/api/v1/query_range",
                  {"query": f'{{service_name="web-app"}} | trace_id="{trace_id}"', "start": start})["data"]["result"]
    return streams and f"logs found for trace {trace_id}"


def grafana_datasources():
    for uid in ("prometheus", "loki", "tempo"):
        health = get(f"{GRAFANA}/api/datasources/uid/{uid}/health")
        if health.get("status") != "OK":
            return False
    return "prometheus, loki, tempo healthy"


def grafana_dashboards():
    uids = {d["uid"] for d in get(f"{GRAFANA}/api/search", {"type": "dash-db"})}
    return {"web-app-overview", "web-app-slo"} <= uids and "both dashboards loaded"


def page_alert_routed():
    alerts = get(f"{ALERTMANAGER}/api/v2/alerts")
    for a in alerts:
        if a["labels"].get("alertname") == "WebAppAvailabilityBudgetBurn" and a["labels"].get("severity") == "page":
            receivers = [r["name"] for r in a["receivers"]]
            return "on-call" in receivers and f"routed to {receivers}"
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--timeout", type=int, default=600, help="seconds to wait for everything (default 600)")
    args = parser.parse_args()
    deadline = time.time() + args.timeout

    wait_for("Prometheus targets", targets_up, deadline)
    wait_for("SLO recording rules", recording_rules, deadline)
    wait_for("Tempo traces", traces, deadline)
    wait_for("Loki logs linked by trace ID", logs_linked_to_trace, deadline)
    wait_for("Grafana data sources", grafana_datasources, deadline)
    wait_for("Grafana dashboards", grafana_dashboards, deadline)
    wait_for("Availability page alert in Alertmanager", page_alert_routed, deadline)
    print("All checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
