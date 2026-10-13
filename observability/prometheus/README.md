# Prometheus guide

[← Observability](../README.md)

Prometheus is the open-source standard for metrics: it pulls numbers from your services on a schedule, stores them as time series, and evaluates queries and alert rules over them. This guide covers what you need to read, write, and run it, using the [web-app sample](../../kubernetes/apps/web-app/) and the [local lab](../local-stack/) for every example. Start the lab and open http://localhost:9090 to follow along.

| Section | What it covers |
|---|---|
| [How Prometheus works](#how-prometheus-works) | Scraping, the data model, metric types |
| [PromQL basics](#promql-basics) | Selectors, rates, aggregation, histograms |
| [PromQL cookbook](#promql-cookbook) | Queries you'll actually need, by question |
| [Rules](#recording-and-alerting-rules) | Recording rules, alert rules, testing them |
| [Alertmanager](#alertmanager) | Routing, grouping, silences, inhibition |
| [Instrumenting a service](#instrumenting-a-service) | Naming, labels, what to expose |
| [Running Prometheus](#running-prometheus) | Kubernetes, storage, scaling, managed services |
| [Troubleshooting](#troubleshooting) | Targets down, no data, wrong numbers |

The files in this folder:

- [rules/web-app-slo.yaml](rules/web-app-slo.yaml): SLO recording rules and multiwindow burn-rate alerts for the web app
- [tests/web-app-slo.test.yaml](tests/web-app-slo.test.yaml): unit tests for those rules, run in CI with `promtool test rules`

---

## How Prometheus works

- **Pull model.** Each service exposes its current metric values as text at an HTTP endpoint, usually `/metrics`. Prometheus fetches (*scrapes*) every *target* on an interval, typically 15 to 60 seconds. If a scrape fails, `up` for that target becomes 0, so a missing service is itself a signal.
- **Targets come from service discovery:** Kubernetes pods and services, EC2 instances, Azure VMs, Consul, DNS, or a static list (as in the [lab's prometheus.yml](../local-stack/prometheus.yml)).
- **Push, when you have to.** Short-lived batch jobs can push to a Pushgateway. Systems sending OpenTelemetry can push OTLP to Prometheus directly (`--web.enable-otlp-receiver`), and other Prometheus servers can `remote_write` to it.
- **Local storage** is a time-series database on disk, kept for a set retention (15 days by default). For longer retention or a global view across clusters, Prometheus writes to a remote store (Thanos, Mimir, Cortex, or a managed service).

### The data model

Every time series is a metric name plus a set of key-value labels, with a stream of timestamped values:

```text
http_request_duration_seconds_count{job="web-app", instance="web-app:9797", method="GET", path="root", status="200"}  48213
```

- `job` and `instance` are added by Prometheus from the scrape configuration. The rest come from the application.
- **Every distinct combination of label values is a separate series.** That's what makes labels powerful and what makes them dangerous; see [cardinality](#labels-and-cardinality).

### Metric types

| Type | What it is | Example | Query it with |
|---|---|---|---|
| Counter | A number that only goes up, and resets to zero on restart | requests served, errors, bytes sent | `rate()` or `increase()`, never the raw value |
| Gauge | A number that goes up and down | memory in use, queue depth, temperature | the value itself, `avg_over_time()`, `max_over_time()` |
| Histogram | Counts of observations in configurable buckets, plus their sum and count | request duration, response size | `histogram_quantile()` over `rate()` of the `_bucket` series |
| Summary | Quantiles computed in the client | request duration, in some libraries | the quantile series directly; can't be aggregated across instances |

A histogram `http_request_duration_seconds` is really several series: `_bucket{le="0.25"}` (requests that took 0.25 s or less, cumulative), `_sum`, and `_count`. Prefer histograms to summaries: they can be aggregated across instances, and the SLO rules here use their buckets directly. Prometheus 3 also supports *native histograms*, which pick buckets automatically and cost less storage; they need to be enabled in both the client library and the scrape config.

---

## PromQL basics

### Selecting series

```promql
http_request_duration_seconds_count                                      # every series with this name
http_request_duration_seconds_count{job="web-app"}                       # exact match
http_request_duration_seconds_count{job="web-app", status=~"5.."}        # regular expression (fully anchored)
http_request_duration_seconds_count{job="web-app", path!~"healthz|readyz"}  # not matching
```

That's an *instant vector*: one value per series, at the evaluation time. Add a duration in brackets for a *range vector*, every sample in the window, which functions like `rate()` take as input:

```promql
http_request_duration_seconds_count{job="web-app"}[5m]
```

### Rates: the most important function

Counters are only useful as rates. `rate()` gives the per-second average increase over the window, and handles counter resets from restarts:

```promql
rate(http_request_duration_seconds_count{job="web-app"}[5m])      # requests per second, per series
increase(http_request_duration_seconds_count{job="web-app"}[1h])  # requests in the last hour, per series
```

- Make the window at least four times the scrape interval, so it always holds enough samples. In Grafana, use `$__rate_interval`, which does this for you.
- **Rate first, then aggregate:** `sum(rate(x[5m]))`, never `rate(sum(x)[5m])`. Summing raw counters across instances breaks reset detection.
- `irate()` uses only the last two samples. It's jumpy; use it only for fast-moving graphs, never in alerts.

### Aggregating

```promql
sum(rate(http_request_duration_seconds_count{job="web-app"}[5m]))                      # total requests per second
sum by (path) (rate(http_request_duration_seconds_count{job="web-app"}[5m]))           # per path
sum without (instance) (rate(http_request_duration_seconds_count{job="web-app"}[5m]))  # drop one label, keep the rest
topk(5, sum by (path) (rate(http_request_duration_seconds_count{job="web-app"}[5m])))  # the five busiest paths
```

Other aggregations: `avg`, `min`, `max`, `count`, `quantile`, `bottomk`, `count_values`, `stddev`.

### Ratios and arithmetic

Arithmetic between two vectors matches series with identical labels. Aggregate both sides to the same labels first:

```promql
# Error ratio: failed requests per second / all requests per second
sum(rate(http_request_duration_seconds_count{job="web-app", status=~"5.."}[5m]))
/
sum(rate(http_request_duration_seconds_count{job="web-app"}[5m]))
```

When the labels differ, `on()`, `ignoring()`, and `group_left()` control matching. Most of the time, aggregating with `sum by (...)` to the same labels is simpler.

### Percentiles from histograms

```promql
# p95 request duration across all instances and paths
histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{job="web-app"}[5m])))

# p95 per path: keep le plus the labels you want
histogram_quantile(0.95, sum by (le, path) (rate(http_request_duration_seconds_bucket{job="web-app"}[5m])))
```

Always keep `le` in the `by` clause. The result is an estimate, interpolated within a bucket, so it's only as precise as the bucket boundaries: if the buckets are 0.25 s and 0.5 s, a "p95 of 0.4 s" means "somewhere between them". For an SLO threshold, put a bucket boundary exactly at the threshold and count requests under it, as [the SLO rules](rules/web-app-slo.yaml) do, instead of estimating a percentile.

### Over time

```promql
max_over_time(process_resident_memory_bytes{job="web-app"}[1h])     # peak memory in the last hour
avg_over_time(up{job="web-app"}[1d])                                # share of scrapes that succeeded today
rate(http_request_duration_seconds_count{job="web-app"}[5m] offset 1w)  # the same rate, one week ago
predict_linear(node_filesystem_avail_bytes[6h], 24 * 3600) < 0      # disk full within a day, at the current trend
```

---

## PromQL cookbook

| Question | Query |
|---|---|
| Is it up? | `up{job="web-app"}` |
| How many instances are up? | `sum(up{job="web-app"})` |
| Requests per second | `sum(rate(http_request_duration_seconds_count{job="web-app"}[5m]))` |
| Error ratio | `sum(rate(http_request_duration_seconds_count{job="web-app", status=~"5.."}[5m])) / sum(rate(http_request_duration_seconds_count{job="web-app"}[5m]))` |
| p99 latency | `histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{job="web-app"}[5m])))` |
| Share of requests under 250 ms | `sum(rate(http_request_duration_seconds_bucket{job="web-app", le="0.25"}[5m])) / sum(rate(http_request_duration_seconds_count{job="web-app"}[5m]))` |
| Average request duration | `sum(rate(http_request_duration_seconds_sum{job="web-app"}[5m])) / sum(rate(http_request_duration_seconds_count{job="web-app"}[5m]))` |
| Did it restart recently? | `changes(process_start_time_seconds{job="web-app"}[1h]) > 0` |
| Uptime | `time() - process_start_time_seconds{job="web-app"}` |
| CPU used, in cores | `rate(process_cpu_seconds_total{job="web-app"}[5m])` |
| Which metrics have the most series? | `topk(10, count by (__name__) ({__name__=~".+"}))` (expensive; run it rarely) |
| Which jobs send the most series? | `sort_desc(sum by (job) (scrape_samples_scraped))` |

In Kubernetes, with kube-state-metrics and cAdvisor (the kubelet) scraped:

| Question | Query |
|---|---|
| Pods restarting | `increase(kube_pod_container_status_restarts_total{namespace="web-app"}[1h]) > 0` |
| Pods not ready | `kube_pod_status_ready{namespace="web-app", condition="false"} == 1` |
| Container memory against its limit | `sum by (pod) (container_memory_working_set_bytes{namespace="web-app", container!=""}) / sum by (pod) (kube_pod_container_resource_limits{namespace="web-app", resource="memory"})` |
| CPU throttling | `sum by (pod) (rate(container_cpu_cfs_throttled_periods_total{namespace="web-app"}[5m])) / sum by (pod) (rate(container_cpu_cfs_periods_total{namespace="web-app"}[5m]))` |
| Deployment replicas missing | `kube_deployment_spec_replicas != kube_deployment_status_replicas_available` |

---

## Recording and alerting rules

Rules live in YAML files that Prometheus loads (`rule_files` in its configuration) and evaluates on a schedule.

**Recording rules** compute an expensive query in advance and store the result as a new series. Use them for anything a dashboard or alert evaluates often, and for SLO ratios over long windows. The naming convention is `level:metric:operations`, such as `job:slo_availability_errors:ratio_rate5m`: aggregated to `job`, from the SLO's error counts, as a ratio of 5-minute rates.

**Alerting rules** fire when a query returns any series for longer than `for`:

```yaml
- alert: WebAppTargetDown
  expr: up{job="web-app"} == 0
  for: 5m                        # must be true for 5 minutes before firing; filters blips
  labels:
    severity: page               # Alertmanager routes on labels
  annotations:
    summary: "Prometheus can't scrape web-app ({{ $labels.instance }})"
    runbook_url: "https://..."   # every alert links to what to do
```

An alert is *pending* while its condition holds but `for` hasn't elapsed, then *firing*. Firing alerts go to Alertmanager, and appear as the `ALERTS` series.

### Alert on SLOs, not on every metric

[rules/web-app-slo.yaml](rules/web-app-slo.yaml) follows the [Google SRE Workbook's multiwindow, multi-burn-rate method](https://sre.google/workbook/alerting-on-slos/). Instead of "error rate above 1% for 5 minutes", which pages on small blips and misses slow leaks, each alert asks how fast the error budget is being spent:

| Severity | Burn rate | Long window | Short window | Budget gone in |
|---|---|---|---|---|
| page | 14.4x | 1 hour | 5 minutes | about 2 days |
| page | 6x | 6 hours | 30 minutes | 5 days |
| ticket | 3x | 1 day | 2 hours | 10 days |
| ticket | 1x | 3 days | 6 hours | 30 days |

The long window shows that a meaningful share of the budget has gone; the short window shows the problem is still happening, so the alert resolves soon after a fix.

### Test rules like code

```sh
promtool check config observability/local-stack/prometheus.yml
promtool check rules observability/prometheus/rules/web-app-slo.yaml
promtool test rules observability/prometheus/tests/web-app-slo.test.yaml
```

A rule test feeds synthetic series in and asserts which alerts fire, with which labels and annotations, at which times. [The tests here](tests/web-app-slo.test.yaml) check that 2% errors page, that 0.05% errors don't, that slow requests trip the latency SLO but not availability, and that failing health checks are ignored. An alert nobody has tested is an alert nobody knows will fire. `promtool` ships with Prometheus, or run it from the image: `docker run --rm --entrypoint promtool prom/prometheus:v3.15.0 --version`.

---

## Alertmanager

Prometheus decides *that* an alert is firing; Alertmanager decides *who hears about it and how*. Its [lab configuration](../local-stack/alertmanager.yml) shows each piece:

- **Routing:** a tree of matchers on alert labels. Here, `severity="page"` goes to the on-call receiver and `severity="ticket"` to the team queue.
- **Grouping:** alerts with the same `group_by` labels become one notification, so 50 failing pods send one message, not 50. `group_wait`, `group_interval`, and `repeat_interval` control how soon and how often.
- **Inhibition:** while one alert fires, suppress related ones. Here, a firing page holds back the matching ticket.
- **Silences:** mute alerts matching some labels for a set time, such as during planned maintenance. Always set an end time and a comment.
- **Receivers:** PagerDuty, Opsgenie, Slack, Microsoft Teams, email, or any webhook.

```sh
amtool --alertmanager.url=http://localhost:9093 alert query                       # what's firing
amtool --alertmanager.url=http://localhost:9093 silence add alertname=WebAppTargetDown \
  --duration=2h --comment="Planned node maintenance"
amtool --alertmanager.url=http://localhost:9093 silence query
amtool check-config observability/local-stack/alertmanager.yml
amtool config routes test --config.file=observability/local-stack/alertmanager.yml severity=page   # which receiver?
```

Run Alertmanager as a cluster of two or three instances in production. Each Prometheus sends to all of them, and they deduplicate.

---

## Instrumenting a service

Use the official client library for your language, or OpenTelemetry's metrics SDK exporting to Prometheus. Then:

- **Measure RED for every service:** a request counter and a duration histogram, labeled by route (the template, `/items/{id}`, not the actual URL), method, and status code. That one histogram gives you rate, errors, and duration.
- **Measure USE for every resource** you manage: utilization, saturation, and errors for pools, queues, and connections.
- **Name metrics** `<namespace>_<what>_<unit>`, in base units (seconds, bytes), with counters ending in `_total`: `http_requests_total`, `queue_depth`, `payment_duration_seconds`.
- **Pick histogram buckets around your SLO.** Put a boundary exactly at each latency threshold you alert on, plus a few on each side.
- **Expose build information** as a gauge with value 1, such as `app_build_info{version="1.4.2", commit="a1b2c3d"} 1`, so dashboards can show which version was running when.

### Labels and cardinality

Each new label value is a new time series, held in memory and stored on disk. A label for HTTP status code adds a handful of series. A label for user ID, email, request ID, full URL, or IP address adds one series per distinct value, without limit, and can take Prometheus down.

- Label values must come from a small, bounded set.
- Put unbounded detail in logs and traces, which are built for it. An *exemplar* attaches one trace ID to a histogram sample, linking a slow bucket to an example trace without a label per request.
- Watch `prometheus_tsdb_head_series` and the cardinality pages in the Prometheus UI (Status, then TSDB Status).

---

## Running Prometheus

### In Kubernetes

The usual way is the [Prometheus Operator](https://prometheus-operator.dev/), often installed with the kube-prometheus-stack Helm chart (Prometheus, Alertmanager, Grafana, node-exporter, kube-state-metrics, and default rules and dashboards). Configuration becomes Kubernetes objects:

- **ServiceMonitor** or **PodMonitor**: which services or pods to scrape, selected by label.
- **PrometheusRule**: rule groups, in the same format as [rules/web-app-slo.yaml](rules/web-app-slo.yaml), wrapped in a Kubernetes object.
- **AlertmanagerConfig**: routes and receivers per namespace.

For the web-app sample, a PodMonitor fits, because the metrics port (9797, named `metrics`) is on the container but not on the Service:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: web-app
  namespace: web-app
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: web-app
  podMetricsEndpoints:
    - port: metrics                  # the named container port
      interval: 30s
  jobLabel: app.kubernetes.io/name   # makes job="web-app", which the SLO rules expect
```

The sample's namespace denies all ingress by default, so the web-app NetworkPolicy also needs a rule letting Prometheus reach that port, or every scrape fails:

```yaml
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring   # where Prometheus runs
      ports:
        - port: metrics
```

### Storage, retention, and scale

- **One Prometheus server** handles a few million active series on a large machine. Plan memory at a few kilobytes per active series.
- **Retention:** `--storage.tsdb.retention.time` (default 15 days) or `--storage.tsdb.retention.size`. Local disk is not replicated or backed up.
- **High availability:** run two identical servers scraping the same targets. Alertmanager deduplicates their alerts; a remote store deduplicates their data.
- **Long-term and global view:** `remote_write` to Thanos, Grafana Mimir, Cortex, or a managed service.

### Managed Prometheus

| Service | Notes |
|---|---|
| [Amazon Managed Service for Prometheus](https://docs.aws.amazon.com/prometheus/latest/userguide/what-is-Amazon-Managed-Service-Prometheus.html) | Prometheus-compatible store and query API. Collect with the managed scraper for EKS, the ADOT collector, or Prometheus with `remote_write`; rule groups and Alertmanager config are uploaded through the API. See the [AWS guide](../aws/README.md#prometheus-and-grafana-on-aws). |
| [Azure Monitor managed service for Prometheus](https://learn.microsoft.com/azure/azure-monitor/metrics/prometheus-metrics-overview) | Stores metrics in an Azure Monitor workspace. On AKS, one setting deploys the collector; rule groups are Azure resources. See the [Azure guide](../azure/README.md#prometheus-and-grafana-on-azure). |
| Grafana Cloud, Chronosphere, and others | Hosted Prometheus-compatible backends, often with Grafana included |

Managed services remove storage and scaling work, but bill per sample ingested and per query, so cardinality becomes a cost problem as well as a performance one.

---

## Troubleshooting

| Symptom | Check |
|---|---|
| Target down (`up == 0`) | Status, then Targets in the UI shows the scrape error. Usual causes: wrong port or path, a NetworkPolicy or security group blocking the scrape, TLS or authentication on the metrics endpoint, or a scrape slower than `scrape_timeout`. |
| A metric you expect isn't there | `curl` the target's `/metrics` yourself. If it's there, check `metric_relabel_configs` dropping it, and the exact name (counters gained `_total` in recent client libraries). |
| Query returns nothing | Remove label matchers one at a time to find the one that doesn't match. Remember regex matches are fully anchored: `path=~"items"` doesn't match `items_get`. |
| Rate is zero or gaps appear | The window is shorter than four scrape intervals, or scrapes are failing intermittently (`avg_over_time(up[1h]) < 1`). |
| Numbers jump at restarts | You're graphing a raw counter. Use `rate()` or `increase()`. |
| `increase()` returns fractions | Expected: it extrapolates across the window's edges. Round in the display, not the query. |
| Rule doesn't fire | Run its `expr` in the UI: if it returns nothing, neither will the alert. Then check `for`, and Status, then Rules for evaluation errors. Test it with `promtool test rules`. |
| Alert fires but nobody is notified | Check Alertmanager's UI for the alert, then `amtool config routes test` with its labels, and check for silences and inhibitions. |
| Prometheus is slow or out of memory | Cardinality. Check TSDB Status for the metrics and labels with the most series, then drop or relabel them at the scrape. |
| Duplicate series after a migration | Two scrape jobs, or a ServiceMonitor and annotations, scraping the same target. Look for the same `instance` under two `job` values. |

The [Prometheus documentation](https://prometheus.io/docs/) covers everything here in depth, especially [querying basics](https://prometheus.io/docs/prometheus/latest/querying/basics/) and the [best practices on naming](https://prometheus.io/docs/practices/naming/) and [histograms](https://prometheus.io/docs/practices/histograms/).
