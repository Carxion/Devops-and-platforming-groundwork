# Azure identity and access

[← Azure operations](../README.md)

## Who am I, and where?

```sh
az account show --query "{subscription:name, id:id, tenant:tenantId, user:user.name, type:user.type}" -o table
az ad signed-in-user show --query "{name:displayName, id:id, upn:userPrincipalName}" -o table
az account management-group list --query "[].{name:displayName, id:name}" -o table
```

## Who has access?

```sh
# Everything you can do, including through groups and inherited scopes
az role assignment list --assignee <your object id> --all --include-inherited --include-groups \
  --query "[].{role:roleDefinitionName, scope:scope}" -o table

# Who holds Owner on the subscription (including inherited from management groups)
az role assignment list --role Owner --scope /subscriptions/<subscription id> --include-inherited \
  --query "[].{who:principalName, type:principalType, scope:scope}" -o table

# Every assignment on one resource group or resource
az role assignment list --scope <resource group or resource id> --include-inherited \
  --query "[].{who:principalName, type:principalType, role:roleDefinitionName}" -o table

# Across all subscriptions, with Resource Graph: who holds privileged roles?
az graph query -q "authorizationresources
  | where type =~ 'microsoft.authorization/roleassignments'
  | extend roleId = tostring(split(properties.roleDefinitionId, '/')[-1])
  | where roleId in ('8e3af657-a8ff-443c-a75c-2fe8c4bcb635', 'b24988ac-6180-42a0-ab88-20f7382dd24c', '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9')
  | project principalId = tostring(properties.principalId), principalType = tostring(properties.principalType), roleId, scope = tostring(properties.scope)" -o table
```

The three role IDs in that query are Owner, Contributor, and User Access Administrator. Read the results with the guide's question in mind: who has standing access that should be just-in-time through PIM ([section 3.2](../../README.md#32-identity-and-access))?

## Roles

```sh
az role definition list --name "Key Vault Secrets User" --query "[0].permissions"     # what a built-in role allows
az role definition list --custom-role-only true --query "[].{name:roleName, scopes:assignableScopes}" -o table
```

Grant at the narrowest scope that works, with a description that says why:

```sh
az role assignment create \
  --assignee-object-id <object id> --assignee-principal-type ServicePrincipal \
  --role "Key Vault Secrets User" \
  --scope <key vault resource id> \
  --description "orders-api reads its database credentials (CHG-1234)"

az role assignment delete --ids <role assignment id>
```

Setting `--assignee-principal-type` avoids failures when the principal was created moments ago and hasn't replicated yet. For repeatable assignments, use [role-assignment.bicep](../bicep/identity/role-assignment.bicep).

Role assignment changes can take up to about 10 minutes to take effect for data-plane access (storage, Key Vault). A fresh `AuthorizationPermissionMismatch` after granting access usually just needs a wait.

## App registrations and service principals

```sh
az ad sp list --display-name <name> --query "[].{name:displayName, appId:appId, objectId:id, type:servicePrincipalType}" -o table
az ad app show --id <app id> --query "{name:displayName, owners:owners, signInAudience:signInAudience}"

# Secrets and certificates on an app, with expiry
az ad app credential list --id <app id> --query "[].{name:displayName, keyId:keyId, expires:endDateTime}" -o table
az ad app credential list --id <app id> --cert --query "[].{name:displayName, keyId:keyId, expires:endDateTime}" -o table

# Apps with a client secret expiring before a date
az ad app list --all --query "[?passwordCredentials[?endDateTime < '2026-12-31']].{name:displayName, appId:appId}" -o table

# Federated credentials (OIDC trust, no secret)
az ad app federated-credential list --id <app id> --query "[].{name:name, subject:subject, issuer:issuer}" -o table
```

Every client secret is a long-lived credential that can leak. Prefer federated credentials for CI and managed identities for workloads, and treat any remaining secret's expiry date as a deadline to remove it, not just renew it.

## Managed identities

```sh
az identity list --query "[].{name:name, rg:resourceGroup, clientId:clientId, principalId:principalId}" -o table
az identity federated-credential list --identity-name <identity> --resource-group <rg> \
  --query "[].{name:name, subject:subject, issuer:issuer}" -o table

# Which resources use system-assigned identities
az graph query -q "Resources | where identity.type contains 'SystemAssigned' | project name, type, resourceGroup, principalId = tostring(identity.principalId)" -o table
```

## Groups

```sh
az ad group show --group "<group name>" --query "{id:id, name:displayName}"
az ad group member list --group "<group name>" --query "[].{name:displayName, upn:userPrincipalName}" -o table
az ad group member check --group "<group name>" --member-id <object id>
```

## Locks

Locks stop deletes (`CanNotDelete`) or all changes (`ReadOnly`), even for Owners:

```sh
az lock list --query "[].{name:name, level:level, scope:id}" -o table
az lock create --name do-not-delete --lock-type CanNotDelete --resource-group <rg> --notes "Production data. Remove via change request."
az lock delete --name do-not-delete --resource-group <rg>
```

`ReadOnly` locks block more than they appear to: listing storage account keys is a POST, so it fails, and many portal views break. Use `CanNotDelete` unless you have a specific reason.
