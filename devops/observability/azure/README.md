# Observability on Azure

[← Observability](../README.md)

How to instrument, collect, alert on, and look at telemetry for workloads on Azure, with Azure Monitor (metrics, Log Analytics, Application Insights, alerts) and its managed open-source services (managed Prometheus, Azure Managed Grafana). For investigating a subscription you've inherited, with activity log and KQL commands, see [devops/azure/guides/logging-and-monitoring.md](../../azure/guides/logging-and-monitoring.md).

| Section | What it covers |
|---|---|
| [The services](#the-services) | Which part of Azure Monitor does what |
| [Alerts for the functions API](#alerts-for-the-functions-api) | Deploying [api-alerts.bicep](bicep/api-alerts.bicep) |
| [Collect platform telemetry](#collect-platform-telemetry) | Diagnostic settings, the activity log |
| [Instrument the code](#instrument-the-code) | Application Insights with OpenTelemetry, including Functions |
| [Query with KQL](#query-with-kql) | The tables, and queries for each signal |
| [Alerts](#alerts) | Metric, log search, and activity log alerts; action groups; maintenance windows |
| [AKS](#aks) | Container insights, managed Prometheus |
| [Prometheus and Grafana on Azure](#prometheus-and-grafana-on-azure) | Azure Monitor workspaces, Azure Managed Grafana |
| [Cost](#cost) | What drives the Azure Monitor bill |

---

## The services

| Need | Azure service | Notes |
|---|---|---|
| Platform metrics | Azure Monitor Metrics | Every resource publishes metrics automatically, kept for 93 days. |
| Logs | Log Analytics workspaces | Resource logs (through diagnostic settings), the activity log, VM and container logs, and Application Insights data all land here. Query with KQL. |
| Application telemetry | Application Insights | Requests, dependencies, exceptions, traces, and custom metrics from your code, through OpenTelemetry. Workspace-based: its data lives in a Log Analytics workspace. |
| Alerts | Azure Monitor alerts | Metric, log search, activity log, and Prometheus alerts. Notify through action groups. |
| Dashboards | Workbooks, Azure dashboards, Azure Managed Grafana | |
| Prometheus metrics | Azure Monitor managed service for Prometheus | Stored in an Azure Monitor workspace (a different resource from a Log Analytics workspace) |
| Synthetic checks | Application Insights availability tests | See [software/api-testing/azure.md](../../../software/api-testing/azure.md#synthetic-monitoring-with-availability-tests) |
| Audit | Activity log | Who changed which resource. Kept for 90 days unless exported. |

---

## Alerts for the functions API

[bicep/api-alerts.bicep](bicep/api-alerts.bicep) adds to the [functions-api stack](../../terraform/azure/functions-api/):

- A **standard availability test** that requests a missing item from five regions every five minutes and expects `404`, which proves the whole path works without any test data, and an alert when 3 of the 5 regions fail (Microsoft's guidance is test locations minus two).
- **Log search alerts** on the 5xx error ratio and p95 duration from the `requests` table. Log search alerts can express ratios and percentiles, which metric alerts can't.
- An **action group** that every alert notifies.

```sh
RG=<resource group of the functions-api stack>
APPI=$(az resource list --resource-group "$RG" --resource-type Microsoft.Insights/components --query "[0].name" -o tsv)
BASE_URL=$(terraform -chdir=devops/terraform/azure/functions-api output -raw api_base_url)

az deployment group what-if --resource-group "$RG" --template-file devops/observability/azure/bicep/api-alerts.bicep \
  --parameters appInsightsName="$APPI" apiBaseUrl="$BASE_URL" alertEmails='["platform-team@example.com"]'

az deployment group create --resource-group "$RG" --template-file devops/observability/azure/bicep/api-alerts.bicep \
  --parameters appInsightsName="$APPI" apiBaseUrl="$BASE_URL" alertEmails='["platform-team@example.com"]'

az extension add --name scheduled-query      # log search alert commands
az monitor scheduled-query list --resource-group "$RG" --query "[].{name:name, enabled:enabled, severity:severity}" -o table
az monitor metrics alert list --resource-group "$RG" --query "[].{name:name, enabled:enabled, severity:severity}" -o table
```

In a team setting, add the paging and chat tools as receivers on the action group (webhook, Logic App, or the built-in integrations) instead of email. If the stack's Entra ID authentication is on, the availability test gets `401`; the comments in the template cover the options. In a Terraform-managed program, the same resources are `azurerm_application_insights_standard_web_test`, `azurerm_monitor_metric_alert`, `azurerm_monitor_scheduled_query_rules_alert_v2`, and `azurerm_monitor_action_group`.

---

## Collect platform telemetry

Most Azure resources publish metrics automatically, but their **resource logs** (Key Vault access, Storage requests, Cosmos DB queries, Application Gateway access) go nowhere until a diagnostic setting sends them to a workspace:

```sh
WORKSPACE_ID=$(az monitor log-analytics workspace show --resource-group <rg> --workspace-name <workspace> --query id -o tsv)

az monitor diagnostic-settings categories list --resource <resource id> --query "[].{name:name, type:categoryType}" -o table

az monitor diagnostic-settings create --name to-log-analytics --resource <resource id> \
  --workspace "$WORKSPACE_ID" \
  --logs '[{"categoryGroup": "allLogs", "enabled": true}]' \
  --metrics '[{"category": "AllMetrics", "enabled": true}]'

az monitor diagnostic-settings list --resource <resource id> --query "[].{name:name, workspace:workspaceId}" -o table
```

- Configure diagnostic settings with Azure Policy (the built-in "Enable logging by category group" initiatives) so new resources are covered automatically, rather than by hand.
- `allLogs` can be large for busy resources (Storage, Application Gateway). Use `audit` for security-relevant categories only, or pick categories.
- Export the **activity log** to a workspace for retention beyond 90 days: [activity-log-export.bicep](../../azure/bicep/governance/activity-log-export.bicep).

---

## Instrument the code

Application Insights takes telemetry through the **Azure Monitor OpenTelemetry Distro**: the OpenTelemetry SDK plus an exporter to Azure Monitor and the common instrumentations, configured in one call. For a Python web app:

```sh
pip install azure-monitor-opentelemetry
```

```python
from azure.monitor.opentelemetry import configure_azure_monitor

# Reads APPLICATIONINSIGHTS_CONNECTION_STRING from the environment. With local
# authentication off (as in the functions-api stack), also pass
# credential=DefaultAzureCredential() so it signs in with Entra ID.
configure_azure_monitor()
```

That records incoming requests, outgoing HTTP and database calls (as dependencies), logs, and exceptions, with trace context propagated between services. Equivalent distros exist for .NET, Java, and Node.js.

### Azure Functions

Functions sends request telemetry from its host by default. To get end-to-end OpenTelemetry, including the Cosmos DB calls the [API testing guide](../../../software/api-testing/azure.md#see-what-happened-to-each-request) notes are missing, turn it on in both the host and the Python worker ([Microsoft's guide](https://learn.microsoft.com/azure/azure-functions/opentelemetry-howto)):

1. In `host.json`, add `"telemetryMode": "OpenTelemetry"` at the root. The `logging.applicationInsights` sampling settings no longer apply after this.
2. Add `azure-monitor-opentelemetry` to `requirements.txt`.
3. Add the app setting `PYTHON_APPLICATIONINSIGHTS_ENABLE_TELEMETRY=true`, which lets the worker send telemetry directly and avoids duplicate entries. In the Terraform stack, that's one more line in `app_settings`.
4. Because the stack turns off local authentication on Application Insights, configure Entra ID authentication for both the host (already set through `APPLICATIONINSIGHTS_AUTHENTICATION_STRING`) and the worker.

Sending to another backend, such as the [local lab's collector](../local-stack/) or Grafana Cloud, uses the standard `OTEL_EXPORTER_OTLP_ENDPOINT` settings instead.

### What to set on every service

- `OTEL_SERVICE_NAME` (Application Insights shows it as the *cloud role name*), so the application map and queries group by service.
- `OTEL_RESOURCE_ATTRIBUTES=deployment.environment.name=prod,service.version=1.4.2`, so you can compare environments and versions.
- Sampling: Application Insights samples by default to control cost. Keep failed requests unsampled where the SDK allows, and remember that sampled data needs `itemCount` to count correctly (`summarize sum(itemCount)` instead of `count()`).

---

## Query with KQL

Application Insights data is in a Log Analytics workspace. Queried from the Application Insights resource, the tables have short names; queried from the workspace, they have `App` prefixes and slightly different column names:

| Signal | From Application Insights | From the workspace |
|---|---|---|
| Incoming requests | `requests` | `AppRequests` |
| Outgoing calls | `dependencies` | `AppDependencies` |
| Exceptions | `exceptions` | `AppExceptions` |
| Log messages | `traces` | `AppTraces` |
| Availability tests | `availabilityResults` | `AppAvailabilityResults` |
| Custom metrics | `customMetrics` | `AppMetrics` |

```sh
# Requests, errors, and latency per operation over the last hour
az monitor app-insights query --app <app insights name> --resource-group <rg> --offset 1h --analytics-query "
  requests
  | summarize requests = sum(itemCount), failed = sumif(itemCount, success == false),
              p95_ms = percentile(duration, 95) by operation_Name
  | extend error_pct = round(100.0 * failed / requests, 2)
  | order by requests desc" -o table

# Everything that happened in one request: request, dependencies, logs, exceptions
az monitor app-insights query --app <app insights name> --resource-group <rg> --offset 1d --analytics-query "
  union requests, dependencies, traces, exceptions
  | where operation_Id == '<operation id>'
  | project timestamp, itemType, name, message, resultCode, duration
  | order by timestamp asc" -o table

# The same request data from the workspace
az monitor log-analytics query --workspace <workspace customer id> --timespan PT1H --analytics-query "
  AppRequests
  | summarize requests = sum(ItemCount), p95_ms = percentile(DurationMs, 95) by OperationName" -o table
```

The `operation_Id` is the trace ID, so the same value finds the request in Application Insights and its spans in any other OpenTelemetry backend.

---

## Alerts

| Alert type | Evaluates | Use for |
|---|---|---|
| Metric alert | Platform or custom metrics, every minute | Fast, cheap thresholds: availability test failures, CPU, queue depth. Dynamic thresholds learn normal patterns. |
| Log search alert | A KQL query, on a schedule | Ratios, percentiles, and anything in logs: error ratio, p95 latency, specific exceptions |
| Activity log alert | Control-plane events | Someone deleted a resource, changed a role assignment, or a Service Health incident affects you |
| Prometheus alert | PromQL rule groups in an Azure Monitor workspace | Kubernetes and Prometheus-instrumented services |

- **Action groups** are the notification targets (email, SMS, push, webhook, Logic Apps, Functions, ITSM, and Event Hubs). Use the common alert schema so receivers parse one format.
- **Alert processing rules** suppress notifications during planned maintenance, or add action groups to many alerts at once:

  ```sh
  az monitor alert-processing-rule create --name maintenance-window --resource-group <rg> \
    --scopes /subscriptions/<subscription id>/resourceGroups/<rg> \
    --rule-type RemoveAllActionGroups \
    --schedule-start-datetime "2026-11-01 22:00:00" --schedule-end-datetime "2026-11-02 02:00:00" \
    --description "Planned database upgrade"
  ```

- **Severity** runs from 0 (critical) to 4 (verbose). Route 0 and 1 to paging, 2 to the team queue, and question whether 3 and 4 need to exist.
- **Stateful alerts** (`autoMitigate: true` in the template) resolve themselves when the condition clears, so the alert list reflects what's still wrong.

```sh
az monitor metrics alert list --query "[].{name:name, severity:severity, enabled:enabled}" -o table
az monitor scheduled-query list --query "[].{name:name, severity:severity, enabled:enabled}" -o table
az monitor action-group list --query "[].{name:name, enabled:enabled, short:groupShortName}" -o table
```

For SLO-style burn-rate alerts, use the Prometheus rules in [devops/observability/prometheus](../prometheus/README.md#alert-on-slos-not-on-every-metric) with managed Prometheus, or write log search alerts with the same multiwindow logic in KQL.

---

## AKS

Two add-ons cover most needs, and the [aks-cluster stack](../../terraform/azure/aks-cluster/) is where to turn them on:

- **Container insights** collects container logs, Kubernetes events, and inventory into a Log Analytics workspace (`ContainerLogV2`, `KubePodInventory`, `KubeEvents`).
- **Managed Prometheus** scrapes cluster and workload metrics into an Azure Monitor workspace, with default recording rules and dashboards.

```sh
# Azure Monitor workspace for Prometheus metrics
az monitor account create --name amw-platform --resource-group <rg> --location <region>
AMW_ID=$(az monitor account show --name amw-platform --resource-group <rg> --query id -o tsv)

# Managed Prometheus, linked to the workspace (and optionally to Azure Managed Grafana)
az aks update --resource-group <rg> --name <cluster> --enable-azure-monitor-metrics \
  --azure-monitor-workspace-resource-id "$AMW_ID"

# Container insights, into a Log Analytics workspace
az aks enable-addons --resource-group <rg> --name <cluster> --addons monitoring \
  --workspace-resource-id "$WORKSPACE_ID"

az aks show --resource-group <rg> --name <cluster> \
  --query "{prometheus:azureMonitorProfile.metrics.enabled, containerInsights:addonProfiles.omsagent.enabled}"
```

The managed Prometheus agent scrapes pods that carry `prometheus.io/scrape: "true"` annotations once pod annotation scraping is configured, or targets defined in its ConfigMaps; it also understands PodMonitor and ServiceMonitor custom resources (under the `azmonitoring.coreos.com` API group). The web-app sample's metrics port and NetworkPolicy need the same changes as for any Prometheus; see the [Prometheus guide](../prometheus/README.md#in-kubernetes).

---

## Prometheus and Grafana on Azure

**Managed Prometheus rule groups** are Azure resources (`Microsoft.AlertsManagement/prometheusRuleGroups`), not YAML files. Convert this repository's rules with Microsoft's [az-prom-rules-converter](https://github.com/Azure/prometheus-collector/tree/main/tools/az-prom-rules-converter), which turns a Prometheus rule file into an ARM template, then deploy it alongside the workspace. Each rule group's alerts notify action groups instead of Alertmanager.

**Azure Managed Grafana** runs Grafana with Entra ID sign-in, a managed identity for data sources, and built-in Azure dashboards:

```sh
az grafana create --name grafana-platform --resource-group <rg> --location <region>
az grafana show --name grafana-platform --resource-group <rg> --query properties.endpoint -o tsv

# Let the team in (Grafana Admin, Grafana Editor, Grafana Viewer)
az role assignment create --assignee <group object id> --assignee-principal-type Group --role "Grafana Viewer" \
  --scope $(az grafana show --name grafana-platform --resource-group <rg> --query id -o tsv)

# Import this repository's dashboards
az grafana dashboard import --name grafana-platform --resource-group <rg> \
  --definition @observability/grafana/dashboards/web-app-overview.json
az grafana data-source list --name grafana-platform --resource-group <rg> --query "[].{name:name, type:type, uid:uid}" -o table
```

The imported dashboards refer to a Prometheus data source with `uid` `prometheus`. Either create one with that `uid` pointing at the Azure Monitor workspace's query endpoint, or change the `uid` in the JSON before import. Give Grafana's managed identity **Monitoring Data Reader** on the Azure Monitor workspace so it can query. The [Grafana 101](../grafana/README.md#azure-monitor) covers the Azure Monitor data source.

---

## Cost

Azure Monitor bills mostly for data ingested into Log Analytics, so control what goes in:

| Driver | Control it with |
|---|---|
| Log ingestion (per GB) | Pick diagnostic categories instead of `allLogs` on chatty resources. Use data collection rule transformations to drop columns and rows at ingestion. |
| Table plans | Basic and Auxiliary plans cost far less per GB for logs you only search occasionally (with limits on queries and alerts). Keep Analytics for what you alert on. |
| Retention | Interactive retention per table (30 days by default), then long-term retention at a lower price for data you keep for compliance. |
| Application Insights volume | Sampling, and a daily cap as a safety net (a cap that triggers means lost data, so alert on it). |
| Commitment tiers | Lower per-GB prices for a committed daily volume, once ingestion is steady. |
| Managed Prometheus | Billed per sample ingested and queried. Scrape less often, and drop unused metrics, rather than collecting everything. |

```sh
# Which tables ingest the most, in the last 30 days
az monitor log-analytics query --workspace <workspace customer id> --timespan P30D --analytics-query "
  Usage
  | where IsBillable == true
  | summarize GB = round(sum(Quantity) / 1024, 2) by DataType
  | order by GB desc
  | take 15" -o table
```

The [Azure cost guide](../../azure/guides/cost.md) covers the rest of the bill.
