# Azure cost

[← Azure operations](../README.md)

## Where is the money going?

The Cost Management Query API answers "how much, grouped by what". Put the query in a file, then call it with `az rest`. A relative URI is sent to Azure Resource Manager, and `{subscriptionId}` is filled in from `az account set`.

```json
{
  "type": "ActualCost",
  "timeframe": "MonthToDate",
  "dataset": {
    "granularity": "None",
    "aggregation": { "totalCost": { "name": "Cost", "function": "Sum" } },
    "grouping": [ { "type": "Dimension", "name": "ServiceName" } ]
  }
}
```

Save that as `cost-query.json`, then:

```sh
# Rows are [cost, group, currency]; sort by cost, highest first
az rest --method post \
  --uri "/subscriptions/{subscriptionId}/providers/Microsoft.CostManagement/query?api-version=2025-03-01" \
  --body @cost-query.json --query "properties.rows" -o tsv | sort -t$'\t' -k1 -rn | head -15
```

Change the query to answer other questions:

| To group by | Set `grouping` to |
|---|---|
| Service | `{ "type": "Dimension", "name": "ServiceName" }` |
| Resource group | `{ "type": "Dimension", "name": "ResourceGroupName" }` |
| Resource | `{ "type": "Dimension", "name": "ResourceId" }` |
| A tag, such as Owner | `{ "type": "TagKey", "name": "Owner" }` |

`timeframe` also accepts `TheLastMonth`, `WeekToDate`, and `Custom` (with a `timePeriod` of `from` and `to` dates), and `granularity` accepts `Daily` for a trend. For a management group or billing account, change the scope at the start of the URI.

Costs with no `Owner` tag group under an empty value. That's the share nobody owns ([guide section 3.5](../../README.md#35-resilience-and-cost)). For one-off questions, the portal's Cost analysis view is often faster; use the API for scripted and recurring reports.

## Budgets and recommendations

```sh
az consumption budget list --query "[].{name:name, amount:amount, spent:currentSpend.amount, timeGrain:timeGrain}" -o table

az advisor recommendation list --category Cost \
  --query "[].{impact:impact, problem:shortDescription.problem, resource:impactedValue}" -o table
```

No budget yet? See [budget.bicep](../bicep/governance/budget.bicep).

## Idle and orphaned resources

Resource Graph finds these across every subscription you can read, in seconds:

```sh
# Unattached managed disks
az graph query -q "Resources
  | where type =~ 'microsoft.compute/disks' and properties.diskState == 'Unattached'
  | project name, resourceGroup, sizeGb = toint(properties.diskSizeGB), sku = tostring(sku.name)" -o table

# Public IPs attached to nothing (Standard SKU IPs bill even when unused)
az graph query -q "Resources
  | where type =~ 'microsoft.network/publicipaddresses'
  | where isnull(properties.ipConfiguration) and isnull(properties.natGateway)
  | project name, resourceGroup, ip = tostring(properties.ipAddress)" -o table

# Network interfaces attached to nothing
az graph query -q "Resources
  | where type =~ 'microsoft.network/networkinterfaces'
  | where isnull(properties.virtualMachine) and isnull(properties.privateEndpoint)
  | project name, resourceGroup" -o table

# Snapshots older than 90 days
az graph query -q "Resources
  | where type =~ 'microsoft.compute/snapshots' and todatetime(properties.timeCreated) < ago(90d)
  | project name, resourceGroup, created = todatetime(properties.timeCreated), sizeGb = toint(properties.diskSizeGB)" -o table

# VMs stopped but not deallocated (still billed for compute)
az graph query -q "Resources
  | where type =~ 'microsoft.compute/virtualmachines'
  | where properties.extended.instanceView.powerState.code == 'PowerState/stopped'
  | project name, resourceGroup" -o table

# App Service plans with no apps
az graph query -q "Resources
  | where type =~ 'microsoft.web/serverfarms' and toint(properties.numberOfSites) == 0
  | project name, resourceGroup, sku = tostring(sku.name)" -o table

# Empty resource groups
az graph query -q "ResourceContainers
  | where type =~ 'microsoft.resources/subscriptions/resourcegroups'
  | join kind=leftouter (Resources | summarize n = count() by resourceGroup, subscriptionId) on resourceGroup, subscriptionId
  | where isnull(n)
  | project resourceGroup, subscriptionId" -o table
```

Before deleting anything, check its tags and activity log for an owner, and snapshot disks you aren't sure about.

## Untagged resources

```sh
az graph query -q "Resources | where isnull(tags.Owner) | summarize untagged = count() by type | order by untagged desc" -o table
```

The [policy baseline](../bicep/governance/policy-baseline.bicep) requires an `Owner` tag on resource groups and copies it to the resources inside, which closes most of this gap going forward.

## Dev and test savings

```sh
az vm deallocate --resource-group <rg> --name <vm>                 # stop paying for compute
az vm auto-shutdown --resource-group <rg> --name <vm> --time 1900   # every evening, 19:00 UTC
az aks stop --resource-group <rg> --name <cluster>                  # whole cluster, outside working hours
az webapp stop --resource-group <rg> --name <app>                   # stops the app; the plan still bills
```

An App Service plan bills whether or not its apps are running. Scale the plan down or delete it to save money.
