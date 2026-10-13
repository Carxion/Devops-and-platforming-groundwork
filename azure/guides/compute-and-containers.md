# Azure compute and containers

[← Azure operations](../README.md)

## VMs

```sh
az vm list --show-details \
  --query "[].{name:name, rg:resourceGroup, size:hardwareProfile.vmSize, power:powerState, privateIp:privateIps, publicIp:publicIps}" -o table

az vm get-instance-view --resource-group <rg> --name <vm> --query "instanceView.statuses[].displayStatus" -o tsv
az vm boot-diagnostics get-boot-log --resource-group <rg> --name <vm>     # serial output, for VMs that won't boot

az vm restart --resource-group <rg> --name <vm>
az vm deallocate --resource-group <rg> --name <vm>     # stops billing for compute; "stop" alone does not
az vm start --resource-group <rg> --name <vm>
```

`az vm stop` powers the VM off but keeps the hardware allocated, and keeps billing. Use `deallocate` to stop paying for compute.

### Run commands without SSH or RDP

Run command goes through the VM agent, with no open ports, and is logged in the activity log:

```sh
az vm run-command invoke --resource-group <rg> --name <vm> --command-id RunShellScript \
  --scripts "uptime" "df -h /" "systemctl --failed"

az vm run-command invoke --resource-group <rg> --name <vm> --command-id RunPowerShellScript \
  --scripts "Get-Service | Where-Object Status -eq 'Stopped' | Select-Object -First 10"
```

### Interactive access

```sh
# Bastion: SSH through the Bastion host, signing in with Entra ID (needs Bastion Standard and the bastion extension)
az network bastion ssh --name <bastion> --resource-group <rg> --target-resource-id <vm resource id> --auth-type AAD

# Serial console: for VMs whose network or SSH is broken (needs boot diagnostics on)
az serial-console connect --resource-group <rg> --name <vm>
```

### Resize and scale sets

```sh
az vm list-vm-resize-options --resource-group <rg> --name <vm> -o table
az vm resize --resource-group <rg> --name <vm> --size Standard_D4ds_v5        # restarts the VM

az vmss list-instances --resource-group <rg> --name <scale set> -o table
az vmss update-instances --resource-group <rg> --name <scale set> --instance-ids "*"   # roll instances onto the latest model
```

### Dev and test savings

```sh
az vm auto-shutdown --resource-group <rg> --name <vm> --time 1900       # daily shutdown at 19:00 UTC
```

## App Service

```sh
az webapp list --query "[].{name:name, rg:resourceGroup, state:state, host:defaultHostName}" -o table
az webapp show --resource-group <rg> --name <app> --query "{state:state, httpsOnly:httpsOnly, outboundVnet:virtualNetworkSubnetId}"
az webapp config show --resource-group <rg> --name <app> \
  --query "{tls:minTlsVersion, ftps:ftpsState, http2:http20Enabled, alwaysOn:alwaysOn, healthCheck:healthCheckPath}"
```

### Logs and troubleshooting

```sh
az webapp log config --resource-group <rg> --name <app> --docker-container-logging filesystem   # turn on container logs
az webapp log tail --resource-group <rg> --name <app>
az webapp log download --resource-group <rg> --name <app> --log-file logs.zip

az webapp ssh --resource-group <rg> --name <app>        # shell in the running Linux container
az webapp restart --resource-group <rg> --name <app>
```

Container apps that keep restarting usually fail the startup probe: the container isn't listening on the port App Service expects. Set `WEBSITES_PORT` if it isn't 80 or 8080, and check the app's startup log in `log tail`.

### Settings and slots

```sh
az webapp config appsettings list --resource-group <rg> --name <app> --query "[].{name:name, slotSetting:slotSetting}" -o table

az webapp deployment slot list --resource-group <rg> --name <app> -o table
az webapp deployment slot swap --resource-group <rg> --name <app> --slot staging --target-slot production
```

A slot swap is a fast rollback, too: swap again to put the previous version back.

## Azure Functions

```sh
az functionapp list --query "[].{name:name, rg:resourceGroup, state:state, kind:kind}" -o table
az functionapp function list --resource-group <rg> --name <app> --query "[].{name:name, disabled:isDisabled}" -o table
az functionapp config appsettings list --resource-group <rg> --name <app> --query "[].name" -o tsv
az functionapp restart --resource-group <rg> --name <app>
```

Function logs and failures are in Application Insights; see [Logging and monitoring](logging-and-monitoring.md#application-insights).

## Container Registry

```sh
az acr list --query "[].{name:name, rg:resourceGroup, sku:sku.name, adminEnabled:adminUserEnabled, public:publicNetworkAccess}" -o table
az acr repository list --name <registry> -o table
az acr repository show-tags --name <registry> --repository <repo> --orderby time_desc --top 5 -o table
az acr check-health --name <registry> --yes

az acr login --name <registry>          # sign Docker in with your Entra ID identity
```

The admin user should be disabled (`adminEnabled: false`). Pull with managed identities (`AcrPull`) instead.

Mirror public images into your registry, so builds and clusters don't depend on Docker Hub, and images get scanned where you control them:

```sh
az acr import --name <registry> --source docker.io/library/busybox:1.38.0 --image mirror/busybox:1.38.0
```

Clean up old images (dry run first by adding `--dry-run` to the purge command):

```sh
az acr run --registry <registry> --cmd "acr purge --filter 'web:.*' --ago 30d --untagged --keep 10" /dev/null
```

## AKS

Cluster-level commands are here; everything inside the cluster is in [kubernetes/OPERATIONS.md](../../kubernetes/OPERATIONS.md).

```sh
az aks list --query "[].{name:name, rg:resourceGroup, version:kubernetesVersion, state:provisioningState, power:powerState.code}" -o table
az aks get-credentials --resource-group <rg> --name <cluster>
az aks get-upgrades --resource-group <rg> --name <cluster> -o table
az aks nodepool list --resource-group <rg> --cluster-name <cluster> \
  --query "[].{name:name, mode:mode, count:count, size:vmSize, version:orchestratorVersion}" -o table
az aks nodepool scale --resource-group <rg> --cluster-name <cluster> --name user --node-count 3   # pools without autoscaling
az aks check-acr --resource-group <rg> --name <cluster> --acr <registry>.azurecr.io

# Dev clusters: stop the whole cluster outside working hours
az aks stop --resource-group <rg> --name <cluster>
az aks start --resource-group <rg> --name <cluster>
```
