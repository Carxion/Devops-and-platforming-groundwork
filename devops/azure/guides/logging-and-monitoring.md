# Azure logging and monitoring

[← Azure operations](../README.md)

## Activity log: who did this?

The activity log records control-plane operations (create, update, delete, role assignments) for 90 days. Export it to Log Analytics for longer retention and better queries ([activity-log-export.bicep](../bicep/governance/activity-log-export.bicep)).

```sh
# Recent changes in a resource group
az monitor activity-log list --resource-group <rg> --offset 24h \
  --query "[?status.value=='Succeeded'].{time:eventTimestamp, operation:operationName.localizedValue, caller:caller}" -o table

# Everything one person or service principal did in the last week
az monitor activity-log list --caller <upn or app id> --offset 7d \
  --query "[].{time:eventTimestamp, operation:operationName.localizedValue, resource:resourceId, status:status.value}" -o table

# Everything done to one resource
az monitor activity-log list --resource-id <resource id> --offset 7d \
  --query "[].{time:eventTimestamp, operation:operationName.localizedValue, caller:caller, status:status.value}" -o table
```

`caller` is an email address for users and an application or object ID for service principals and managed identities. Look those up with `az ad sp show --id <id> --query displayName`.

Activity log entries don't include data-plane operations (reading a blob, getting a secret). Those come from each resource's diagnostic logs.

## Log Analytics

```sh
az monitor log-analytics workspace list --query "[].{name:name, rg:resourceGroup, retentionDays:retentionInDays}" -o table
ws=$(az monitor log-analytics workspace show --resource-group <rg> --workspace-name <workspace> --query customerId -o tsv)

az monitor log-analytics query --workspace "$ws" --timespan P1D -o table \
  --analytics-query "AzureActivity | where OperationNameValue endswith 'DELETE' and ActivityStatusValue == 'Success' | project TimeGenerated, Caller, OperationNameValue, _ResourceId | take 50"
```

`--workspace` takes the workspace's customer ID (a GUID), not its name or resource ID.

Useful queries:

```kusto
// Role assignments created or deleted (who granted access to whom)
AzureActivity
| where OperationNameValue in~ ("Microsoft.Authorization/roleAssignments/write", "Microsoft.Authorization/roleAssignments/delete")
| where ActivityStatusValue == "Success"
| project TimeGenerated, Caller, OperationNameValue, Scope = tostring(Properties_d.entity)

// Key Vault: who read which secrets (Key Vault diagnostic logs)
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT" and OperationName == "SecretGet"
| summarize reads = count() by CallerIPAddress, identity_claim_oid_g, id_s
| order by reads desc

// Failed Key Vault requests (permission problems, firewall blocks)
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT" and httpStatusCode_d >= 400
| summarize count() by OperationName, httpStatusCode_d, CallerIPAddress

// AKS: container logs from one namespace
ContainerLogV2
| where PodNamespace == "sample-apps" and TimeGenerated > ago(1h)
| project TimeGenerated, PodName, LogMessage
| order by TimeGenerated desc

// Azure Firewall: denied traffic
AZFWNetworkRule
| where Action == "Deny" and TimeGenerated > ago(1h)
| summarize count() by SourceIp, DestinationIp, DestinationPort
| top 20 by count_
```

## Application Insights

```sh
az monitor app-insights component show --resource-group <rg> --app <app insights> --query "{name:name, workspace:workspaceResourceId}"

az monitor app-insights query --resource-group <rg> --app <app insights> --offset 1h \
  --analytics-query "requests | where success == false | summarize failures = count() by name, resultCode | order by failures desc"

az monitor app-insights query --resource-group <rg> --app <app insights> --offset 1h \
  --analytics-query "exceptions | summarize count() by type, outerMessage | top 10 by count_"
```

With a workspace-based component, the same data is also in the workspace as `AppRequests`, `AppExceptions`, and `AppTraces`.

## Metrics

```sh
az monitor metrics list-definitions --resource <resource id> --query "[].name.value" -o tsv

az monitor metrics list --resource <vm resource id> --metric "Percentage CPU" \
  --interval PT5M --aggregation Average Maximum --offset 1h -o table

az monitor metrics list --resource <web app resource id> --metric Http5xx --interval PT5M --aggregation Total --offset 6h -o table
```

## Alerts

```sh
az monitor metrics alert list --query "[].{name:name, rg:resourceGroup, enabled:enabled, severity:severity}" -o table
az monitor activity-log alert list --query "[].{name:name, rg:resourceGroup, enabled:enabled}" -o table
az monitor scheduled-query list --query "[].{name:name, rg:resourceGroup, enabled:enabled, severity:severity}" -o table
az monitor action-group list --query "[].{name:name, rg:resourceGroup, emails:length(emailReceivers)}" -o table

# Alerts firing now, across subscriptions
az graph query -q "alertsmanagementresources
  | where properties.essentials.monitorCondition == 'Fired'
  | project name, severity = tostring(properties.essentials.severity), target = tostring(properties.essentials.targetResourceName), fired = todatetime(properties.essentials.startDateTime)
  | order by fired desc" -o table
```

An action group with no receivers, or receivers nobody reads, means alerts that go nowhere. Check the routing, not only the alert rules.

## Diagnostic settings

Resource logs only exist if a diagnostic setting sends them somewhere:

```sh
az monitor diagnostic-settings list --resource <resource id> \
  --query "[].{name:name, workspace:workspaceId, logs:length(logs[?enabled])}" -o table

az monitor diagnostic-settings categories list --resource <resource id> --query "[].{name:name, type:categoryType}" -o table
```

Checking every resource by hand doesn't scale. Azure Policy has built-in "deploy diagnostic settings" policies per resource type, which create the setting automatically and report gaps.

## Service health

```sh
az graph query -q "servicehealthresources
  | where type =~ 'microsoft.resourcehealth/events'
  | extend status = tostring(properties.Status), title = tostring(properties.Title), impactStart = todatetime(properties.ImpactStartTime)
  | where status == 'Active'
  | project title, status, impactStart" -o table
```
