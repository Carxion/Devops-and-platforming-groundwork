# Grafana 101

[← Observability](../README.md)

Grafana is where people look at telemetry. It doesn't store data itself: it queries *data sources* (Prometheus, Loki, Tempo, CloudWatch, Azure Monitor, SQL databases, and many more) and shows the results as dashboards, ad hoc queries, and alerts. One Grafana can put metrics from Prometheus beside logs from CloudWatch and traces from Tempo, and link between them.

This guide starts with a tour of the [local lab](../local-stack/), which has Grafana already wired to Prometheus, Loki, Tempo, and Alertmanager, then covers the concepts, building dashboards, the query languages, alerting, connecting AWS and Azure, and running Grafana for a team.

| Section | What it covers |
|---|---|
| [A first tour](#a-first-tour) | Twenty minutes with the lab: dashboards, Explore, metrics to traces to logs |
| [Concepts](#concepts) | The vocabulary: data sources, panels, variables, folders |
| [Building dashboards](#building-dashboards) | Layout, panels, variables, and what makes a dashboard useful |
| [Query languages](#query-languages) | PromQL, LogQL, and TraceQL starters |
| [Alerting in Grafana](#alerting-in-grafana) | Grafana alerts versus Prometheus alerts |
| [Dashboards as code](#dashboards-as-code) | Provisioning, Terraform, Jsonnet, and Git |
| [Cloud data sources](#cloud-data-sources) | CloudWatch and Azure Monitor |
| [Running Grafana](#running-grafana) | Managed options, access control, security |
| [Troubleshooting](#troubleshooting) | No data, wrong numbers, broken links |

The dashboards in [dashboards/](dashboards/) load into the lab automatically:

- [web-app-overview.json](dashboards/web-app-overview.json): rate, errors, and duration (RED) for the web app, with its logs and slowest traces
- [web-app-slo.json](dashboards/web-app-slo.json): error budgets and burn rates for its SLOs, and firing alerts

---

## A first tour

Start the lab with traffic, from the repository root:

```sh
docker compose -f devops/observability/local-stack/compose.yaml --profile traffic up -d
```

Then open http://localhost:3000. The lab signs you in automatically as an administrator.

1. **Open a dashboard.** Go to Dashboards, then the Groundwork folder, then **Web app: service overview**. The top row answers "is it healthy?" at a glance: request rate, error ratio, p95 latency, and targets up. The traffic generator fails 2% of requests and slows 4%, so the error ratio is red.
2. **Change the time range** with the picker at the top right (try "Last 15 minutes"), or drag across any graph to zoom in. Every panel follows. Press the back arrow in your browser to undo a zoom.
3. **Read a panel.** Hover over **Responses per second, by status** to see values at that moment. Click a series in the legend to show only that series; Ctrl or Cmd plus click adds more.
4. **Look at the query behind a panel.** Open a panel's menu (top right corner of the panel, or press `e` while hovering) and choose Edit. The query editor shows the PromQL; the right side holds the display options. Close without saving.
5. **Go to Explore.** From a panel's menu choose Explore, or select Explore in the left menu. Explore is for ad hoc questions: type a query, run it, and refine it without building a dashboard. Try `sum by (status) (rate(http_request_duration_seconds_count{job="web-app"}[5m]))`.
6. **Follow a trace.** On the dashboard, scroll to **Slowest recent traces** and select a trace ID. The trace view shows each span (unit of work) on a timeline. The slow ones here are calls to `/delay`, which waits a second on purpose.
7. **Jump from a trace to its logs.** In the trace view, open a span and choose the logs link. Grafana queries Loki for lines carrying that trace ID. Going the other way, open a log line in the **Logs** panel and select **View trace**.
8. **Check the SLOs.** Open **Web app: SLOs**. After a few minutes of traffic, the availability burn rate is about 20x: 2% errors against a 0.1% budget. The **Firing alerts** table shows the page alert. Open http://localhost:9093 to see Alertmanager holding it for the on-call receiver.
9. **Watch it recover.** Stop the bad traffic and watch the burn rate fall and the alert resolve:

   ```sh
   docker compose -f devops/observability/local-stack/compose.yaml --profile traffic stop traffic
   ```

That loop, from an alert to a dashboard, then a trace, then the logs, is most of what on-call investigation in Grafana looks like.

The Drilldown apps (Metrics, Logs, Traces, and Profiles in the left menu) are a fourth way in: they let you browse what's in each data source by clicking, with no query to write. They're useful when you don't yet know what to ask.

---

## Concepts

| Term | Meaning |
|---|---|
| Data source | A connection to a backend that Grafana queries: its URL, authentication, and settings. Each has a stable `uid` that dashboards refer to. |
| Dashboard | A page of panels with a shared time range and variables, saved as JSON. |
| Panel | One visualization: one or more queries, plus how to show them (time series, stat, gauge, table, bar chart, heatmap, logs, traces, node graph, and more). |
| Query | What a panel asks a data source, in the source's own language: PromQL for Prometheus, LogQL for Loki, TraceQL for Tempo, KQL for Azure Monitor logs. |
| Transformation | Processing after the query, inside Grafana: joining queries, renaming fields, filtering rows, calculating new columns. |
| Variable | A dropdown at the top of a dashboard (environment, service, region) whose value is substituted into every query, so one dashboard serves many services. |
| Row | A collapsible group of panels within a dashboard. |
| Folder | A group of dashboards and alert rules, and the usual unit of permissions. |
| Annotation | A marker on graphs for an event, such as a deployment or an incident, drawn from a query or added by hand. |
| Explore | The ad hoc query view, for investigation rather than display. |
| Alert rule, contact point, notification policy | Grafana alerting: what to evaluate, where to send notifications, and how to route them. |
| Organization, team, user, service account | Access control. Most installations use one organization, with teams for permissions and service accounts for automation. |

---

## Building dashboards

To build one in the lab: Dashboards, then New, then New dashboard, then Add visualization. Pick the Prometheus data source, write a query, choose a visualization, set the unit (under Standard options), and save. Then export the JSON (Share, then Export) and commit it, as described in [dashboards as code](#dashboards-as-code).

### What makes a dashboard useful

- **One question per dashboard.** "Is the web app healthy?" or "Why is the database slow?", not everything about everything. A dashboard nobody can read in ten seconds won't be read during an incident.
- **Top row: the answer.** Request rate, error ratio, latency, and saturation (the four golden signals) as stat panels with thresholds, so red means something. Details go below, from general to specific.
- **Set units on every panel** (requests per second, percent, seconds, bytes). An unlabeled "0.02" could mean anything.
- **Thresholds come from the SLOs,** not from what looks normal. The error-ratio stat here turns orange at 0.1% (the SLO) and red at 1.44% (the fast-burn page threshold).
- **Use rates and percentiles, not averages, for latency.** An average hides the slow requests that users notice.
- **Link onward:** to the SLO dashboard, to runbooks, to the service's repository. Dashboard links and panel data links do this.
- **Use variables instead of copies.** One dashboard with an `environment` variable beats three copies that drift apart.
- **Mark deployments** with annotations. "Did it start after the deploy?" is the first question in most incidents.
- **Delete dashboards nobody uses.** Grafana shows view counts in dashboard insights (in some editions); otherwise ask in the team channel.

### Variables

Dashboard settings, then Variables, then New variable. A *query* variable lists values from a data source. For Prometheus:

| Variable | Query |
|---|---|
| `job` | `label_values(up, job)` |
| `instance` | `label_values(up{job="$job"}, instance)` (depends on `job`) |
| `path` | `label_values(http_request_duration_seconds_count{job="$job"}, path)` |

Use them in queries as `$job`. With multi-value or "All" selected, match with a regex: `{job=~"$job"}`. Built-in variables include `$__rate_interval` (a safe window for `rate()`), `$__range` (the dashboard's time range), and `$__interval`.

### Panel types worth knowing

| Panel | Use it for |
|---|---|
| Time series | Anything over time. The default. |
| Stat | One headline number, colored by thresholds |
| Gauge, bar gauge | A value against a known maximum, such as disk use |
| Table | Many series at one moment, such as firing alerts or the top 10 endpoints |
| Heatmap | Latency distributions from histogram buckets, showing where most requests fall |
| State timeline | Status over time, such as up or down per instance |
| Logs | Log lines from Loki, CloudWatch Logs, or Azure Monitor Logs |
| Traces, node graph | One trace's spans, or a service map |

---

## Query languages

**PromQL**, for Prometheus metrics, is covered in the [Prometheus guide](../prometheus/README.md#promql-basics).

**LogQL**, for Loki logs, starts with a stream selector of indexed labels, then filters and parses:

```logql
{service_name="web-app"}                                         # every line from the service
{service_name="web-app"} |= "timeout"                            # lines containing the text
{service_name="web-app"} | uri="/status/500"                     # filter on structured metadata (from OTLP)
{service_name="web-app"} | json | status >= 500                  # parse JSON lines, then filter on a field
sum by (uri) (count_over_time({service_name="web-app"} [5m]))    # lines per URI: a metric from logs
```

Keep the selector in braces narrow (service, namespace, environment). Loki indexes only those labels; everything after the `|` is scanned, so a broad selector makes every query slow.

**TraceQL**, for Tempo traces, selects spans by their attributes:

```traceql
{ resource.service.name = "web-app" }                                         # every trace from the service
{ resource.service.name = "web-app" && status = error }                       # traces with a failed span
{ resource.service.name = "web-app" && duration > 500ms }                     # slow spans
{ span.http.response.status_code >= 500 }                                     # by an HTTP attribute
{ name = "GET /api/info" }                                                    # by span name
```

`resource.` attributes describe the service that sent the span; `span.` attributes describe the operation. The attribute names follow [OpenTelemetry semantic conventions](https://opentelemetry.io/docs/specs/semconv/), so the same query works for any instrumented service.

For AWS and Azure data sources, Grafana uses their languages: CloudWatch metric queries and Logs Insights for CloudWatch, and KQL for Azure Monitor Logs and Resource Graph. The [AWS](../aws/README.md) and [Azure](../azure/README.md) guides have examples.

---

## Alerting in Grafana

There are two places alert rules can live, and a team should choose one per kind of alert:

| | Prometheus (or Mimir) rules, routed by Alertmanager | Grafana-managed alert rules |
|---|---|---|
| Rules live in | YAML files in Git, like [the SLO rules](../prometheus/rules/web-app-slo.yaml) | Grafana's database, or provisioned files and Terraform |
| Can query | Prometheus metrics only | Any data source: CloudWatch, Azure Monitor, Loki, SQL |
| Testing | `promtool test rules` in CI | Manual, or with the alerting API |
| Keeps working if Grafana is down | Yes | No |
| Best for | Service and SLO alerts on Prometheus metrics | Alerts on sources Prometheus can't see, and for teams that live in Grafana |

The lab uses Prometheus rules and Alertmanager, and Grafana shows them: the Alertmanager data source makes them visible under Alerting.

Grafana-managed alerting has the same three pieces as Alertmanager: **alert rules** (a query, a condition, and how long it must hold), **contact points** (Slack, PagerDuty, email, webhooks), and **notification policies** (a routing tree on labels, with grouping and timing). Silences and mute timings handle maintenance windows. Whichever you use, every alert gets a severity label, a summary that says what's wrong for whom, and a runbook link.

---

## Dashboards as code

Dashboards made by clicking drift, break silently when someone edits them, and vanish when an instance is rebuilt. Keep them in Git:

- **File provisioning**, as the lab does: [provisioning/dashboards/dashboards.yaml](../local-stack/grafana/provisioning/dashboards/dashboards.yaml) loads every JSON file in a folder, and [provisioning/datasources/datasources.yaml](../local-stack/grafana/provisioning/datasources/datasources.yaml) defines the data sources with fixed `uid`s. With `allowUiUpdates: false`, changes must go through the files.
- **Terraform**, with the [Grafana provider](https://registry.terraform.io/providers/grafana/grafana/latest/docs): `grafana_dashboard` (from the same JSON files), `grafana_folder`, `grafana_data_source`, alert rules, contact points, and permissions. Good when Grafana is managed alongside the rest of the infrastructure.
- **Generators** for many similar dashboards: [Grafonnet](https://grafana.github.io/grafonnet/) (Jsonnet) or the Grafana Foundation SDK (Go, TypeScript, Python, Java). One template produces a dashboard per service.
- **Grafana's Git Sync** (in recent versions) syncs dashboards with a Git repository from inside Grafana.

The workflow: build or change a dashboard in a dev Grafana, export the JSON, and commit it in a pull request. Refer to data sources by `uid` and keep dashboard `uid`s fixed, so links and bookmarks survive. Review dashboard changes like code: a broken query in a panel is a broken view during the next incident.

---

## Cloud data sources

Grafana can query the cloud's own monitoring directly, so one dashboard can show the API Gateway metrics and the Prometheus metrics for a service side by side.

### Amazon CloudWatch

Give Grafana an IAM role (an instance profile, EKS Pod Identity, or IRSA; Amazon Managed Grafana does this for you) with the permissions in [Grafana's CloudWatch documentation](https://grafana.com/docs/grafana/latest/datasources/aws-cloudwatch/): read access to metrics and logs, plus `ec2:DescribeRegions` and `tag:GetResources` for the dropdowns. No access keys.

```yaml
apiVersion: 1
datasources:
  - name: CloudWatch
    type: cloudwatch
    uid: cloudwatch
    jsonData:
      authType: default        # the role from the environment
      defaultRegion: us-east-1
```

Queries come in two kinds: **metric queries** (namespace, metric, dimensions, statistic, such as `AWS/ApiGateway` `5xx` by `ApiId`) and **Logs Insights queries**. CloudWatch bills for API requests, so dashboards with many panels and short refresh intervals cost money; set refresh to a minute or more.

### Azure Monitor

Give Grafana a managed identity (Azure Managed Grafana has one) or a workload identity on AKS, with **Monitoring Reader** on the subscriptions it should see, and **Log Analytics Reader** for logs.

```yaml
apiVersion: 1
datasources:
  - name: Azure Monitor
    type: grafana-azure-monitor-datasource
    uid: azure-monitor
    jsonData:
      azureAuthType: msi                       # managed identity; workloadidentity on AKS
      subscriptionId: 00000000-0000-0000-0000-000000000000
```

One data source covers **Azure Monitor metrics**, **Logs** (KQL against Log Analytics and Application Insights), **Azure Resource Graph**, and **traces** from Application Insights. Azure Managed Grafana also ships prebuilt dashboards for many Azure services.

---

## Running Grafana

| Option | Notes |
|---|---|
| [Amazon Managed Grafana](https://docs.aws.amazon.com/grafana/latest/userguide/what-is-Amazon-Managed-Service-Grafana.html) | AWS runs it; sign-in through IAM Identity Center or SAML; billed per active user |
| [Azure Managed Grafana](https://learn.microsoft.com/azure/managed-grafana/overview) | Azure runs it; sign-in with Entra ID; access through Azure RBAC roles (Grafana Admin, Editor, Viewer) |
| Grafana Cloud | Grafana Labs runs it, with hosted Prometheus, Loki, and Tempo included |
| Self-hosted | The official Helm chart on Kubernetes, or a container or package on a VM. Use an external PostgreSQL or MySQL database instead of the default SQLite for anything shared. |

Whichever you choose:

- **Single sign-on** through the organization's identity provider (OIDC or SAML), never shared local accounts. Map identity provider groups to Grafana teams and roles.
- **Viewer by default.** Give Editor to the people who maintain dashboards, and Admin to very few. Use folder permissions to separate teams.
- **Service accounts with tokens** for automation (Terraform, CI), each with the narrowest role, and tokens that expire.
- **Data source credentials are powerful.** A Grafana user can run any query the data source's identity allows. Give data sources read-only identities, scoped to what that Grafana's users should see.
- **Turn off anonymous access** and the things the lab turns on for convenience (see the warning in [compose.yaml](../local-stack/compose.yaml)).
- **Upgrade regularly.** Grafana releases security fixes often.

---

## Troubleshooting

| Symptom | Check |
|---|---|
| Panel says "No data" | Open the panel in Explore and run the query there. Widen the time range. Remove label matchers one at a time. Check the variable values at the top of the dashboard. |
| Data source error | Connections, then Data sources, then the source, then Save & test. Usually a URL, network path, or permission problem. |
| Numbers differ from the backend's own UI | Different time ranges, step sizes, or rate windows. Use `$__rate_interval`, and compare at the same time range. |
| Graph is spiky or has gaps | The rate window is shorter than four scrape intervals. Use `$__rate_interval` instead of a fixed `[1m]`. |
| Times look wrong | The dashboard time zone (the lab's dashboards use UTC) differs from what you expect, or the data has clock skew. |
| Dashboard changes don't save | It's provisioned with `allowUiUpdates: false`. Edit the JSON in Git instead. |
| Trace to logs link finds nothing | The logs don't carry the trace ID, or the link's time window is too narrow. Check the data source's trace-to-logs settings. |
| Dashboards are slow | Too many panels, or queries over huge numbers of series. Use recording rules for heavy queries and collapse rarely used rows (collapsed rows don't query until opened). |

The [Grafana documentation](https://grafana.com/docs/grafana/latest/) goes deeper on every section here, and the [Grafana Play](https://play.grafana.org/) site has hundreds of example dashboards to take apart.
