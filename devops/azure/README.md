# Azure operations

Command-line guides for running and investigating Azure subscriptions, plus Bicep templates for identity, governance, and baseline security resources. They pair with the [onboarding checklist](../../tech-lead/README.md): most "find out" items in sections 3, 7, and 8 are a few commands away.

| Guide | Covers |
|---|---|
| [Identity and access](guides/identity-and-access.md) | Who you are, who holds Owner, role assignments, expiring app secrets, managed identities and federated credentials, locks |
| [Networking](guides/networking.md) | VNets and peering, NSG rules open to the internet, effective routes and rules, Network Watcher diagnostics, private DNS and endpoints |
| [Compute and containers](guides/compute-and-containers.md) | VMs without SSH (run command, Bastion, serial console), App Service and Functions, ACR, AKS |
| [Storage and data](guides/storage-and-data.md) | Storage exposure and recovery, PostgreSQL, SQL, and Cosmos DB point-in-time restore, Key Vault recovery, Azure Backup |
| [Logging and monitoring](guides/logging-and-monitoring.md) | Activity log "who did this", Log Analytics (KQL) from the CLI, metrics, alerts, diagnostic settings |
| [Security and incident response](guides/security-and-incident-response.md) | Defender for Cloud, Azure Policy compliance, and runbooks for leaked credentials, compromised users, VMs, and storage |
| [Cost](guides/cost.md) | Spend by service and tag, budgets, Advisor, orphaned resources through Resource Graph |
| [Bicep templates](bicep/README.md) | Custom roles, role assignments, GitHub and workload identities, policy baseline, activity log export, budget, Key Vault, storage |

Kubernetes on AKS has its own guide: [devops/kubernetes/OPERATIONS.md](../kubernetes/OPERATIONS.md). Terraform state and plans: [devops/terraform/OPERATIONS.md](../terraform/OPERATIONS.md). Setting up metrics, logs, traces, and alerting: [devops/observability/azure](../observability/azure/README.md). Testing APIs: [software/api-testing/azure.md](../../software/api-testing/azure.md).

---

## Setup

### Install

| Tool | Install |
|---|---|
| Azure CLI | `winget install Microsoft.AzureCLI`, `brew install azure-cli`, or the [installer](https://learn.microsoft.com/cli/azure/install-azure-cli) |
| Bicep | `az bicep install` (the CLI manages it) |
| kubelogin and kubectl | `az aks install-cli` |

[Azure Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview) in the portal has the CLI preinstalled and signed in.

Keep the CLI current with `az upgrade`. Commands and output fields change between versions.

### Sign in

```sh
az login                                     # opens a browser; uses your Entra ID account and MFA
az login --tenant <tenant id or domain>      # when you belong to several tenants
az login --use-device-code                   # on a machine without a browser

az account list --query "[].{name:name, id:id, tenant:tenantId, default:isDefault}" -o table
az account set --subscription "<name or id>"
az account show --query "{name:name, id:id, user:user.name}" -o table
```

### Defaults and extensions

```sh
az config set defaults.location=eastus2 defaults.group=<resource group>   # optional; saves typing -l and -g
az config set extension.use_dynamic_install=yes_without_prompt            # install extensions on first use
az extension add --name resource-graph                                    # or add the ones you need up front
az extension list -o table
```

Several commands in these guides come from extensions: `resource-graph` (`az graph`), `log-analytics` (`az monitor log-analytics query`), `application-insights`, `bastion`, and `serial-console`.

### Make output usable

```sh
az vm list -o table          # table, json (default), jsonc, yaml, tsv, none
az vm list --query "[].{name:name, rg:resourceGroup, size:hardwareProfile.vmSize}" -o table
az vm list --query "[?location=='eastus2'].id" -o tsv      # tsv feeds IDs into other commands
```

`--query` filters output with [JMESPath](https://jmespath.org), the same as the AWS CLI. For questions across many subscriptions, **Azure Resource Graph** is much faster than listing resource by resource, because it queries an index instead of each resource provider:

```sh
az graph query -q "Resources | summarize count() by type | order by count_ desc" --first 20 -o table
az graph query -q "Resources | where type =~ 'microsoft.compute/virtualmachines' | project name, resourceGroup, location, subscriptionId" -o table
```

Resource Graph uses KQL (Kusto Query Language), the same language as Log Analytics.

### Quoting

The examples use bash or zsh quoting. In PowerShell, JMESPath backticks and embedded double quotes need escaping. Wrap `--query` values in single quotes, and pass JSON arguments from a file with `@file.json`.

---

## Habits that prevent incidents

- **Check the subscription before acting:** `az account show`. Put it in your shell prompt.
- **Use least-privilege roles day to day**, and activate elevated roles through Privileged Identity Management (PIM) only when needed.
- **Preview changes:** `az deployment group what-if` for templates; `--dry-run` doesn't exist for most `az` commands, so read the command twice.
- **Prefer infrastructure as code.** A fix made by hand is drift; follow up with a pull request to the Terraform or Bicep that owns the resource.
- **Record what you did during an incident**, with UTC times. The activity log records the operation, not your reasoning.
