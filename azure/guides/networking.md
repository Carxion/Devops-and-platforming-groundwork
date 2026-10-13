# Azure networking

[← Azure operations](../README.md)

## Map the network

```sh
az network vnet list --query "[].{name:name, rg:resourceGroup, space:join(', ', addressSpace.addressPrefixes)}" -o table
az network vnet subnet list --resource-group <rg> --vnet-name <vnet> \
  --query "[].{name:name, prefix:addressPrefix, nsg:networkSecurityGroup.id, routeTable:routeTable.id, natGateway:natGateway.id, delegation:delegations[0].serviceName}" -o table
az network vnet peering list --resource-group <rg> --vnet-name <vnet> \
  --query "[].{name:name, remote:remoteVirtualNetwork.id, state:peeringState, sync:peeringSyncLevel, forwarded:allowForwardedTraffic}" -o table
az network route-table list --query "[].{name:name, rg:resourceGroup, routes:length(routes)}" -o table
az network nat gateway list --query "[].{name:name, rg:resourceGroup, ips:publicIpAddresses[].id}" -o table
```

A peering showing `peeringSyncLevel` other than `FullyInSync` needs a sync after either VNet's address space changed: `az network vnet peering sync --resource-group <rg> --vnet-name <vnet> --name <peering>`.

## What's exposed to the internet?

```sh
# NSG rules allowing inbound traffic from anywhere, across all subscriptions
az graph query -q "Resources
  | where type =~ 'microsoft.network/networksecuritygroups'
  | mv-expand rule = properties.securityRules
  | where rule.properties.direction == 'Inbound' and rule.properties.access == 'Allow'
  | where rule.properties.sourceAddressPrefix in ('*', 'Internet', '0.0.0.0/0')
  | project nsg = name, resourceGroup, rule = tostring(rule.name), ports = tostring(rule.properties.destinationPortRange), priority = toint(rule.properties.priority)" -o table

# Public IPs and what they're attached to
az network public-ip list --query "[].{name:name, ip:ipAddress, attachedTo:ipConfiguration.id}" -o table

# Resources with public network access enabled
az graph query -q "Resources | where properties.publicNetworkAccess =~ 'Enabled' | project name, type, resourceGroup" -o table
```

Rules allowing 22 or 3389 from the internet are almost never right. Use Bastion or just-in-time VM access instead.

## Why can't A reach B?

Start with what Azure actually applies to the network interface, which combines the subnet's and the NIC's NSGs and all routes:

```sh
az network nic list-effective-nsg --resource-group <rg> --name <nic> \
  --query "value[].effectiveSecurityRules[?direction=='Inbound'].{name:name, access:access, priority:priority, ports:destinationPortRange, source:sourceAddressPrefix}"

az network nic show-effective-route-table --resource-group <rg> --name <nic> -o table
```

Then let Network Watcher test the path. These run against the real configuration without sending application traffic:

```sh
# Would this packet be allowed, and by which rule?
az network watcher test-ip-flow --resource-group <rg> --vm <vm> --direction Inbound --protocol TCP \
  --local 10.1.0.4:443 --remote 203.0.113.5:60000

# Where does traffic to this address go next?
az network watcher show-next-hop --resource-group <rg> --vm <vm> --source-ip 10.1.0.4 --dest-ip 10.2.0.10

# Actually connect from a VM to a host and port (needs the Network Watcher agent extension on the VM)
az network watcher test-connectivity --resource-group <rg> --source-resource <vm> --dest-address db.internal.example.com --dest-port 5432
```

Manual checklist:

1. **Routes:** does the subnet's route table send the destination where you expect (a firewall, a peering, the internet)? User-defined routes override system routes.
2. **NSGs:** both the source subnet or NIC (outbound) and the destination subnet or NIC (inbound). Lower priority numbers win. The default rules allow traffic within a VNet and its peered VNets.
3. **Firewall:** with forced tunneling through Azure Firewall, the firewall policy must allow the flow; check its logs (`AZFWNetworkRule` and `AZFWApplicationRule` tables in Log Analytics).
4. **DNS:** private endpoints only work when the name resolves to the private IP. See below.

## Private endpoints and private DNS

```sh
az network private-endpoint list \
  --query "[].{name:name, rg:resourceGroup, target:privateLinkServiceConnections[0].privateLinkServiceId, status:privateLinkServiceConnections[0].privateLinkServiceConnectionState.status}" -o table

az network private-dns zone list --query "[].{zone:name, rg:resourceGroup, records:numberOfRecordSets, vnetLinks:numberOfVirtualNetworkLinks}" -o table
az network private-dns link vnet list --resource-group <rg> --zone-name privatelink.blob.core.windows.net -o table
az network private-dns record-set a list --resource-group <rg> --zone-name privatelink.blob.core.windows.net \
  --query "[].{name:name, ips:join(', ', aRecords[].ipv4Address)}" -o table
```

The most common private endpoint failure: the client's VNet isn't linked to the `privatelink.*` zone (or the on-premises DNS doesn't forward to Azure DNS), so the name resolves to the public IP and the service's firewall rejects the connection. Test resolution from the client side, for example with `az vm run-command invoke ... --scripts "nslookup <account>.blob.core.windows.net"` (see [compute](compute-and-containers.md#vms)).

## Flow logs

```sh
az network watcher flow-log list --location <region> --query "[].{name:name, target:targetResourceId, enabled:enabled, retentionDays:retentionPolicy.days}" -o table
```

With traffic analytics on, query denied flows in Log Analytics (see [Logging and monitoring](logging-and-monitoring.md#log-analytics)):

```kusto
NTANetAnalytics
| where TimeGenerated > ago(1h) and FlowStatus == "Denied"
| summarize attempts = count() by SrcIp, DestIp, DestPort
| top 20 by attempts
```

## DNS (public zones)

```sh
az network dns zone list --query "[].{zone:name, rg:resourceGroup, nameServers:join(', ', nameServers)}" -o table
az network dns record-set list --resource-group <rg> --zone-name example.com --query "[].{name:name, type:type, ttl:ttl}" -o table
```
