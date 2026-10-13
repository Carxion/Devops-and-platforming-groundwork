# Observability

How to see what your systems are doing: what to measure, how to collect it, how to alert on it without burning people out, and how to do it on AWS, on Azure, and with the open-source Prometheus and Grafana stack. It supports [section 8](../README.md#8-observability-and-operations) of the guide, and everything here is built around the same sample workloads as the rest of the repository.

> **Status.** CI checks every configuration file here: the Prometheus rules are unit-tested with promtool, the CloudFormation and Bicep templates are linted and scanned, and the local lab is started and checked end to end (metrics, traces, logs, dashboards, alerts). The cloud templates haven't been deployed by this project; deploy to a sandbox first.

| Path | What it is |
|---|---|
| [prometheus/](prometheus/README.md) | **Prometheus guide**: the data model, PromQL from basics to a cookbook, rules, Alertmanager, running it in Kubernetes. Plus [SLO rules](prometheus/rules/web-app-slo.yaml) for the web app and their [unit tests](prometheus/tests/web-app-slo.test.yaml). |
| [grafana/](grafana/README.md) | **Grafana 101**: a guided tour, building dashboards, LogQL and TraceQL, alerting, dashboards as code, cloud data sources. Plus two [dashboards](grafana/dashboards/). |
| [local-stack/](local-stack/README.md) | A Docker Compose lab: the web app sending metrics, traces, and logs through an OpenTelemetry Collector to Prometheus, Tempo, and Loki, with Grafana and Alertmanager |
| [aws/](aws/README.md) | CloudWatch, X-Ray, Application Signals, managed Prometheus and Grafana on AWS, plus [alarms and a dashboard](aws/cloudformation/api-alarms.yaml) for the serverless API |
| [azure/](azure/README.md) | Azure Monitor, Application Insights, KQL, managed Prometheus and Grafana on Azure, plus [alerts and an availability test](azure/bicep/api-alerts.bicep) for the functions API |

New to this? Start the [local lab](local-stack/README.md) and follow the [Grafana 101 tour](grafana/README.md#a-first-tour). It takes about 20 minutes and shows every idea on this page working.

---

## The three signals

| Signal | What it is | Good for | Costs grow with |
|---|---|---|---|
| **Metrics** | Numbers over time, aggregated (requests per second, error ratio, p95 latency, queue depth) | Alerting, dashboards, trends, capacity. Cheap to keep for a long time. | The number of distinct label combinations (cardinality) |
| **Logs** | Timestamped records of individual events | The details of what happened: an error message, a stack trace, an audit record | Volume: every line is stored and indexed |
| **Traces** | One request's path through every service, as a tree of timed spans | Finding *where* time goes and *which* service failed in a distributed system | Request volume, so traces are usually sampled |

They work best linked: an alert on a metric, then a dashboard showing which endpoint, then an example trace for a slow request (an *exemplar*), then the logs written during that trace, found by its trace ID. The local lab is wired this way, and the [Grafana tour](grafana/README.md#a-first-tour) walks through it.

## What to measure

For every **service** (anything that handles requests), the RED method:

- **Rate:** requests per second
- **Errors:** the share of requests that fail
- **Duration:** how long requests take, as a distribution (p50, p95, p99), never just an average

For every **resource** (CPU, memory, disks, connection pools, queues), the USE method:

- **Utilization:** how busy it is
- **Saturation:** how much work is waiting (queue length, throttling)
- **Errors:** failures of the resource itself

Google's four golden signals (latency, traffic, errors, saturation) combine the two. Add a few **business signals** that show the system is doing its job, such as orders placed or messages processed. They catch failures that every technical metric misses, like a bug that makes every request succeed with an empty result.

## Instrument with OpenTelemetry

[OpenTelemetry](https://opentelemetry.io/docs/) (OTel) is the vendor-neutral standard for producing traces, metrics, and logs. Instrument once with the OTel SDK or auto-instrumentation, and send the data anywhere: Prometheus and Grafana, CloudWatch and X-Ray (through ADOT), Azure Monitor (through the Azure Monitor distro), or a commercial tool.

- **Run a collector** between apps and backends, as the [lab does](local-stack/otel-collector.yaml). Apps only know the collector's address; batching, retries, redaction, sampling, and the choice of backend live in one place.
- **Set resource attributes** on every service: `service.name`, `service.version`, and `deployment.environment.name`. Every query and dashboard depends on them.
- **Follow the [semantic conventions](https://opentelemetry.io/docs/specs/semconv/)** for attribute names (`http.response.status_code`, `db.system.name`), so queries and dashboards work across services and languages.
- **Propagate trace context** (the W3C `traceparent` header) through every hop, including queues. A trace that stops at the first queue can't show where time went.

## SLOs and alerting

Alerts that fire on every blip teach people to ignore them. Alert on what users experience, measured against an agreed objective:

1. **Choose SLIs** (service level indicators) users would notice: the share of requests that succeed, and the share faster than a threshold.
2. **Set SLOs** (objectives) for them over a window, such as 99.9% of requests succeed over 30 days. The remaining 0.1% is the **error budget**.
3. **Alert on the burn rate,** how fast the budget is being spent, with a long and a short window. A fast burn pages someone; a slow burn opens a ticket. The [Prometheus guide](prometheus/README.md#alert-on-slos-not-on-every-metric) explains the method, and [the rules here](prometheus/rules/web-app-slo.yaml) implement it with tests.
4. **Use the budget to decide.** When the budget is healthy, ship faster; when it's spent, prioritize reliability work.

For every alert:

- **It's actionable.** Someone needs to do something now (page) or soon (ticket). If not, it's a dashboard, not an alert.
- **It's about a symptom,** not a cause. "Error ratio is 5%" pages; "CPU is 90%" goes on a dashboard, because high CPU with happy users isn't an incident.
- **It links to a runbook** saying what to check first.
- **It's reviewed.** Look at every page from the last month: was it real, was it actionable, did it fire early enough? Delete or fix the ones that weren't.

## Dashboards

- **Start with one overview per service**, answering "is it healthy?" in ten seconds: the RED signals and the SLO status. The [web-app overview](grafana/dashboards/web-app-overview.json) is an example.
- **Drill down from there,** from service to endpoint to instance to dependency, rather than one dashboard with everything.
- **Keep dashboards in Git** and load them by provisioning or Terraform ([dashboards as code](grafana/README.md#dashboards-as-code)), so they survive rebuilds and changes are reviewed.

## Logs that help

- **Structured (JSON or key-value), one event per line,** with consistent field names across services.
- **Every line carries the trace ID** (OTel logging integrations do this), so a log line leads to its trace and back.
- **Levels mean something:** ERROR is something someone should look at, WARN is unexpected but handled, INFO is normal business events, DEBUG is off in production.
- **Never log secrets, tokens, or personal data.** Redact at the source; the collector's [redaction processor](local-stack/otel-collector.yaml) is a safety net, not a design.

## Cost and cardinality

Observability bills grow quietly. The usual causes, and the fixes:

- **High-cardinality metric labels** (user IDs, request IDs, full URLs) multiply the number of series. Keep label values from small, fixed sets; put the detail in logs and traces.
- **Debug logging in production** and logging every health check. Drop them at the source or in the collector.
- **Unsampled traces.** Sample a fixed share of requests (head sampling), or keep every error and slow trace and a share of the rest (tail sampling in the collector).
- **Retention by default, not by decision.** Decide how long each kind of data is useful, and set it.

## Choosing a stack

| Option | Strengths | Watch out for |
|---|---|---|
| Cloud native: CloudWatch and X-Ray ([AWS](aws/README.md)), Azure Monitor and Application Insights ([Azure](azure/README.md)) | Nothing to run; every managed service reports into it automatically; identity and access built in | Each cloud is different; cross-cloud views are hard; costs scale with volume |
| Open source: Prometheus, Grafana, Loki, Tempo ([this folder](local-stack/README.md)) | Portable across clouds; standard query languages; huge ecosystem; no per-GB vendor pricing | You run, scale, upgrade, and back it up yourself |
| Managed open source: Amazon Managed Service for Prometheus and Amazon Managed Grafana; Azure Monitor managed Prometheus and Azure Managed Grafana; Grafana Cloud | Open standards without running the storage | Usage-based pricing; some features differ from upstream |
| Commercial platforms: Datadog, New Relic, Dynatrace, Splunk, Elastic, Honeycomb, and others | One product for everything, strong correlation and analysis features | Cost at scale; switching away is hard unless you instrument with OpenTelemetry |

Many programs combine them: cloud-native for the managed services' own metrics and logs, Prometheus for Kubernetes, and Grafana on top of both. Whatever you choose, instrumenting with OpenTelemetry keeps the choice reversible.

## Checklist for a new service

- [ ] Emits RED metrics (a request counter and a duration histogram), labeled by route, method, and status.
- [ ] Sends traces with `service.name`, `service.version`, and `deployment.environment.name`, and propagates trace context to everything it calls.
- [ ] Writes structured logs with the trace ID, at INFO in production, with no secrets.
- [ ] Has written SLOs for availability and latency, agreed with whoever owns the product.
- [ ] Has burn-rate alerts on those SLOs, each with a runbook link, routed by severity, and tested (`promtool test rules`, or a forced alarm state).
- [ ] Has an overview dashboard in Git, linked from the service's README.
- [ ] Has retention set for its logs, and nothing high-cardinality in its metric labels.
- [ ] Has a synthetic check from outside the network ([AWS](../api-testing/aws.md#synthetic-monitoring-with-cloudwatch-synthetics), [Azure](../api-testing/azure.md#synthetic-monitoring-with-availability-tests)).
