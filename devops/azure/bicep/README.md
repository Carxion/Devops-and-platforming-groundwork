# Bicep templates

Bicep templates for identity, governance, and baseline security. Bicep is Azure's native infrastructure-as-code language: it compiles to ARM JSON and needs no state file, because Azure itself is the source of truth. Use these where a program standardizes on Bicep, or for subscription-level governance that sits outside your Terraform stacks.

> **Status.** Every template built, passed the Bicep linter, and passed checkov when written. CI doesn't run them; run them locally before changing a template ([how](../../../CONTRIBUTING.md#running-the-tests-locally)). Built-in role and policy IDs were checked against Microsoft's published definitions. None has been deployed to a real subscription by this project; deploy to a sandbox first.

| Template | Scope | What it creates |
|---|---|---|
| [identity/custom-role.bicep](identity/custom-role.bicep) | Subscription | A least-privilege custom role (example: operate VMs without creating or deleting them) |
| [identity/role-assignment.bicep](identity/role-assignment.bicep) | Resource group | One built-in role for one principal, with a description |
| [identity/github-actions-identity.bicep](identity/github-actions-identity.bicep) | Resource group | Managed identities with federated credentials for GitHub Actions: plan (pull requests, Reader) and apply (protected environment, Contributor) |
| [identity/workload-identity.bicep](identity/workload-identity.bicep) | Resource group | Managed identity for one AKS service account (workload identity), with read access to one Key Vault |
| [governance/policy-baseline.bicep](governance/policy-baseline.bicep) | Subscription | Allowed regions, required Owner tag on resource groups, tag inheritance, and the Microsoft cloud security benchmark |
| [governance/activity-log-export.bicep](governance/activity-log-export.bicep) | Subscription | Sends the activity log to Log Analytics |
| [governance/budget.bicep](governance/budget.bicep) | Subscription | Monthly budget with 80% actual and 100% forecast alerts |
| [security/key-vault.bicep](security/key-vault.bicep) | Resource group | Key Vault with RBAC, purge protection, firewall, delete lock, and audit logs |
| [security/storage-account.bicep](security/storage-account.bicep) | Resource group | Storage account with Entra ID only (no shared keys), TLS 1.2, versioning, soft delete, and a deny-by-default firewall |

A typical order for a new subscription: **activity-log-export**, then **budget**, then **policy-baseline** (with `enforcementMode=DoNotEnforce` first, to see what would be blocked), then **github-actions-identity**. After that, the pipeline deploys everything else.

## Deploying

Build, preview with `what-if`, then deploy:

```sh
az bicep install                      # or az bicep upgrade
az bicep build --file devops/azure/bicep/security/key-vault.bicep --stdout > /dev/null   # compile and lint

# Resource group scope
az deployment group what-if --resource-group <rg> \
  --template-file devops/azure/bicep/security/key-vault.bicep \
  --parameters vaultName=<name> logAnalyticsWorkspaceId=<workspace id>

az deployment group create --resource-group <rg> \
  --template-file devops/azure/bicep/security/key-vault.bicep \
  --parameters vaultName=<name> logAnalyticsWorkspaceId=<workspace id>

# Subscription scope (needs a location for the deployment record)
az deployment sub what-if --location eastus2 \
  --template-file devops/azure/bicep/governance/policy-baseline.bicep \
  --parameters allowedLocations='["eastus2","centralus"]' enforcementMode=DoNotEnforce

az deployment sub create --location eastus2 \
  --template-file devops/azure/bicep/governance/policy-baseline.bicep \
  --parameters allowedLocations='["eastus2","centralus"]' enforcementMode=DoNotEnforce
```

`what-if` is Bicep's equivalent of `terraform plan`. Read it before every deployment, and look for `Delete` and `Modify` on things you didn't mean to change.

### Parameter files

Keep per-environment values in `.bicepparam` files next to your deployment, and commit them (they hold names and IDs, not secrets):

```bicep
// prod.bicepparam
using './security/key-vault.bicep'

param vaultName = 'kv-orders-prod'
param publicNetworkAccess = 'Disabled'
param logAnalyticsWorkspaceId = '/subscriptions/.../workspaces/log-prod'
```

```sh
az deployment group create --resource-group <rg> --template-file devops/azure/bicep/security/key-vault.bicep --parameters prod.bicepparam
```

## Operating deployments

```sh
az deployment group list --resource-group <rg> --query "[].{name:name, state:properties.provisioningState, time:properties.timestamp}" -o table
az deployment operation group list --resource-group <rg> --name <deployment> \
  --query "[?properties.provisioningState=='Failed'].{resource:properties.targetResource.resourceName, error:properties.statusMessage.error.message}" -o table
```

Bicep deployments are **incremental** by default: resources in the template are created or updated, and resources not in the template are left alone. Removing a resource from a template doesn't delete it. To manage a whole set, including deletions, use a [deployment stack](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deployment-stacks) (`az stack group create`), which tracks what it created and can deny manual changes.

## Conventions in these templates

- **Deterministic names for role assignments and definitions** (`guid(scope, principal, role)`), so redeploying updates rather than duplicates.
- **`principalType` set on every role assignment**, which avoids failures when a new identity hasn't replicated yet.
- **Built-in role and policy IDs as named variables** with their source noted, never bare GUIDs inline.
- **Secure defaults as parameter defaults:** a caller has to opt out explicitly, in a reviewable parameter.
- **checkov exceptions as `// checkov:skip=<ID>:<reason>` comments** inside the resource.

## Bicep and Terraform

They solve the same problem. Pick one per resource, never both: two tools managing the same resource fight. A common split is Bicep for subscription governance owned by a central cloud team (policy, budgets, activity log), and Terraform for workload infrastructure owned by delivery teams. That's how the files in this repository are organized.
