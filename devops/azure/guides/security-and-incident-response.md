# Azure security and incident response

[← Azure operations](../README.md)

## Defender for Cloud

```sh
az security pricing list --query "value[].{plan:name, tier:pricingTier}" -o table     # which Defender plans are on
az security secure-scores list --query "[].{name:displayName, current:score.current, max:score.max}" -o table

# Active alerts
az security alert list --query "[?status=='Active'].{name:alertDisplayName, severity:severity, resource:compromisedEntity, time:timeGeneratedUtc}" -o table

# Unhealthy recommendations
az security assessment list --query "[?status.code=='Unhealthy'].{recommendation:displayName, resource:resourceDetails.id}" -o table
```

## Azure Policy compliance

```sh
az policy assignment list --query "[].{name:name, displayName:displayName, enforcement:enforcementMode}" -o table
az policy state summarize --query "results.{nonCompliantResources:nonCompliantResources, nonCompliantPolicies:nonCompliantPolicies}"

az policy state list --filter "complianceState eq 'NonCompliant'" --top 50 \
  --query "[].{policy:policyDefinitionName, assignment:policyAssignmentName, resource:resourceId}" -o table

# Fix existing resources for a modify or deployIfNotExists policy (for example tag inheritance)
az policy remediation create --name inherit-owner-tag-$(date +%Y%m%d) --policy-assignment inherit-owner-tag
az policy remediation list --query "[].{name:name, state:provisioningState, deployed:deploymentSummary.successfulDeployments}" -o table
```

New assignments take up to about 30 minutes to evaluate. To trigger a scan now: `az policy state trigger-scan --resource-group <rg>`. A starting baseline is in [policy-baseline.bicep](../bicep/governance/policy-baseline.bicep).

---

## Incident runbooks

These are first-response steps that limit damage and preserve evidence. Follow your program's incident response plan and notification requirements; regulated programs often have reporting deadlines measured in hours.

General rules:

- **Contain, don't destroy.** Disable, isolate, and snapshot. Deleting resources destroys evidence.
- **Write down every action with its UTC time.**
- **Work from a known-clean identity**, not the possibly compromised one.

### Leaked app registration secret

A client secret was found in a repository, a log, or a paste site.

```sh
app=<app id>

# 1. Which app, and which credential?
az ad app show --id "$app" --query "{name:displayName, objectId:id}"
az ad app credential list --id "$app" --query "[].{name:displayName, keyId:keyId, hint:hint, expires:endDateTime}" -o table

# 2. Remove the leaked secret (match the hint: the first characters of the secret)
az ad app credential delete --id "$app" --key-id <key id>

# 3. What did the service principal do? Control plane first:
sp=$(az ad sp show --id "$app" --query id -o tsv)
az monitor activity-log list --caller "$app" --offset 30d \
  --query "[].{time:eventTimestamp, operation:operationName.localizedValue, resource:resourceId}" -o table

# 4. What can it reach? (that's the blast radius)
az role assignment list --assignee "$sp" --all --include-inherited --query "[].{role:roleDefinitionName, scope:scope}" -o table
```

Sign-ins by the service principal are in Entra ID's service principal sign-in logs (`AADServicePrincipalSignInLogs` in Log Analytics, if exported). Look for sign-ins from unfamiliar IP addresses. Then rotate anything it could read (Key Vault secrets, storage data), and replace the secret with a federated credential or managed identity so there's nothing left to leak.

### Compromised user account

```sh
user=<upn or object id>

# 1. Block sign-in
az ad user update --id "$user" --account-enabled false

# 2. Revoke refresh tokens and sessions (Microsoft Graph)
az rest --method POST --url "https://graph.microsoft.com/v1.0/users/$user/revokeSignInSessions"

# 3. What did they change?
az monitor activity-log list --caller "$user" --offset 14d \
  --query "[].{time:eventTimestamp, operation:operationName.localizedValue, resource:resourceId}" -o table

# 4. What can they reach?
az role assignment list --assignee "$user" --all --include-inherited --include-groups -o table
```

Revoking sessions invalidates refresh tokens. Access tokens already issued remain valid until they expire, typically within an hour, unless the resource supports continuous access evaluation. Also check for persistence: new app registrations, credentials added to existing apps, new role assignments, and new MFA methods registered on the account.

### Compromised VM

```sh
rg=<rg>; vm=<vm>

# 1. Isolate with an NSG that denies everything, applied to the NIC
az network nsg create --resource-group "$rg" --name "isolation-$vm"
az network nsg rule create --resource-group "$rg" --nsg-name "isolation-$vm" --name deny-all-in \
  --priority 100 --direction Inbound --access Deny --protocol "*" \
  --source-address-prefixes "*" --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges "*"
az network nsg rule create --resource-group "$rg" --nsg-name "isolation-$vm" --name deny-all-out \
  --priority 100 --direction Outbound --access Deny --protocol "*" \
  --source-address-prefixes "*" --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges "*"
nic=$(az vm show --resource-group "$rg" --name "$vm" --query "networkProfile.networkInterfaces[0].id" -o tsv)
az network nic update --ids "$nic" --network-security-group "isolation-$vm"

# 2. Cut off its identity
az vm identity show --resource-group "$rg" --name "$vm"
az vm identity remove --resource-group "$rg" --name "$vm" --identities [system]

# 3. Preserve the disks
for d in $(az vm show --resource-group "$rg" --name "$vm" --query "[storageProfile.osDisk.managedDisk.id, storageProfile.dataDisks[].managedDisk.id][]" -o tsv); do
  az snapshot create --resource-group "$rg" --name "forensic-$(basename "$d")-$(date +%Y%m%d%H%M)" --source "$d" \
    --tags Incident=INC-<number>
done

# 4. Keep it from being deleted
az lock create --name "incident-hold" --lock-type CanNotDelete --resource-group "$rg" --notes "INC-<number> evidence"
```

If the subnet's NSG has higher-priority allow rules, it still applies, because traffic must pass both the subnet NSG and the NIC NSG. A deny on either one blocks the traffic.

### Storage account exposed publicly

```sh
az storage account update --resource-group <rg> --name <account> --allow-blob-public-access false
az storage account update --resource-group <rg> --name <account> --default-action Deny
```

Then establish what was read while it was exposed. That needs storage diagnostic logs (`StorageBlobLogs`), which only exist if they were turned on beforehand. That's a good reason to turn them on for sensitive accounts now.

### Key Vault secret exposed

Rotate the secret at its source (the database password, the API key), then store the new value:

```sh
az keyvault secret set --vault-name <vault> --name <secret> --file ./new-value.txt
az keyvault secret set-attributes --vault-name <vault> --name <secret> --version <old version> --enabled false
```

Review who read it with the Key Vault query in [Logging and monitoring](logging-and-monitoring.md#log-analytics).
