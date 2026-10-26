# Python operational examples

[← Python 101](../README.md)

Five small tools of the kind every operations team ends up writing. Each one is a single module you can read top to bottom. They're built the same way in Go ([software/go/examples](../../go/examples/README.md)), so you can compare the two languages.

| Command | What it does | Shows you how to |
| --- | --- | --- |
| [`certcheck`](src/ops_examples/certcheck.py) | Reports TLS certificate expiry for a list of hosts; exits 1 inside the warning window | Verify TLS the way clients do, check hosts concurrently, and use exit codes that cron and CI can act on |
| [`logstats`](src/ops_examples/logstats.py) | Summarizes nginx and Apache access logs: status mix, top routes, 5xx ratio, peak minute | Parse logs with regex, read logs larger than memory, read `.gz` files, and gate on an error budget |
| [`probe-exporter`](src/ops_examples/probe_exporter.py) | Probes HTTP endpoints and serves the results at `/metrics` | Write a Prometheus exporter and stop cleanly on SIGTERM |
| [`alert-relay`](src/ops_examples/alert_relay.py) | Receives Alertmanager webhooks and posts a readable message to a chat incoming webhook | Write a webhook receiver with token auth, request limits, and retries with backoff |
| [`tag-audit`](src/ops_examples/tag_audit.py) | Lists AWS resources missing required tags; outputs text, JSON, or CSV | Use cloud SDK pagination and the default credential chain, and test against a fake cloud |

Only `probe-exporter` (prometheus-client) and `tag-audit` (boto3) need packages outside the standard library.

## Run them

```bash
cd software/python/examples
uv sync                                   # creates .venv with the tools and dev dependencies

uv run certcheck example.com example.org --warn-days 30
uv run logstats /var/log/nginx/access.log --top 5
uv run probe-exporter https://example.com/ --port 9101 &   # then: curl localhost:9101/metrics
RELAY_TOKEN="$(openssl rand -hex 24)" CHAT_WEBHOOK_URL=https://hooks.example.com/... uv run alert-relay
uv run tag-audit --require Owner --require Environment --output csv   # uses your AWS profile or SSO session
```

Without uv: `python -m venv .venv && . .venv/bin/activate && pip install -e . --group dev` (needs pip 25.1 or newer).

## Check them

```bash
uv run ruff check . && uv run ruff format --check .
uv run mypy
uv run pytest
```

The tests need no network access and no cloud account:

- certcheck runs against a local TLS server with a certificate generated for each test.
- probe-exporter probes local HTTP servers, then scrapes its own `/metrics`.
- alert-relay sends to a fake chat server that can fail on demand, which exercises the retries.
- tag-audit runs against [moto](https://docs.getmoto.org/)'s in-memory AWS.

CI runs the ruff checks ([lint.yml](../../../.github/workflows/lint.yml)); run mypy and pytest locally.

## Using them for real

- **Run on a schedule:** run certcheck and tag-audit from cron, a Kubernetes CronJob, or a scheduled pipeline, and alert on a non-zero exit. Exit codes work as the interface.
- **Prefer existing tools:** for HTTP and TLS probing in production, the [Prometheus Blackbox exporter](https://github.com/prometheus/blackbox_exporter) already does what probe-exporter does. Write your own exporter for things nothing else measures, such as a queue depth, a license count, or a business metric.
- **Keep secrets out of arguments:** alert-relay reads its token and webhook URL from the environment, because command-line arguments show up in `ps`. In Kubernetes, mount them from a Secret.
- **Use the narrowest permissions:** tag-audit needs only `tag:GetResources`.
