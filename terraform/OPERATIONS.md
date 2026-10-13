# Terraform administration and troubleshooting

Everyday commands for running the [reference stacks](README.md), and a symptom-by-symptom guide for when `init`, `plan`, or `apply` fails. The [README](README.md) covers the process side: pipelines, upgrades, and policy. This page is the command reference you keep open while doing the work.

Commands run from inside a stack directory, such as `terraform/aws/network-vpc`, unless noted. Add `-chdir=<dir>` to run from elsewhere.

> **The pipeline applies; people look.** In an operational setup, plan and apply run in CI. Use these commands locally to read, plan, and diagnose. State changes and applies from a laptop are break-glass events that get recorded and followed by a pull request ([README: break-glass changes](README.md#break-glass-changes)).

## Contents

- [Setup and habits](#setup-and-habits)
- [Everyday commands](#everyday-commands)
- [Reading a plan](#reading-a-plan)
- [Inspecting state](#inspecting-state)
- [Changing state safely](#changing-state-safely)
- [Locks](#locks)
- [Restoring a previous state version](#restoring-a-previous-state-version)
- [Debugging Terraform itself](#debugging-terraform-itself)
- [Troubleshooting by symptom](#troubleshooting-by-symptom)
- [Stack-specific notes](#stack-specific-notes)

---

## Setup and habits

Confirm **who** and **where** before every plan:

```sh
# AWS
aws sts get-caller-identity                      # account and role
echo "$AWS_PROFILE"

# Azure
az account show --query "{name:name, id:id, tenant:tenantId, user:user.name}"

# Terraform
terraform version                                # matches required_version and CI?
terraform workspace show                         # should be "default"; environments use backend files
grep -E 'key|bucket|storage_account_name' envs/<env>.backend.hcl   # which state you're about to touch
```

Habits that prevent incidents:

- **Always plan to a file and apply that file.** `plan -out=tfplan` then `apply tfplan` applies exactly what you reviewed. Plain `apply` re-plans and may differ.
- **Switch environments with `-reconfigure`.** `terraform init -reconfigure -backend-config=envs/prod.backend.hcl` points the working directory at prod's state. Without `-reconfigure`, Terraform may offer to *copy* dev state into prod.
- **Delete `tfplan` files after use.** Plans can contain sensitive values in plain text.
- **Never edit state by hand.** Use the commands in [Changing state safely](#changing-state-safely).

---

## Everyday commands

```sh
# Initialize
terraform init -backend-config=envs/dev.backend.hcl           # first time in this directory
terraform init -reconfigure -backend-config=envs/prod.backend.hcl   # switch to another environment's state
terraform init -backend=false                                 # no state access; for validate and test only
terraform init -upgrade                                       # allow newer providers within the constraints; updates the lock file
terraform init -lockfile=readonly                             # fail instead of changing the lock file (CI)

# Check
terraform fmt -recursive                                      # fix formatting (CI runs fmt -check)
terraform validate
terraform test                                                # offline tests with mock providers

# Plan and apply
terraform plan -var-file=envs/dev.tfvars -out=tfplan
terraform show tfplan                                         # re-read a saved plan
terraform apply tfplan

# Variants
terraform plan -var-file=envs/dev.tfvars -refresh-only        # only show drift between state and reality
terraform plan -var-file=envs/dev.tfvars -replace='aws_instance.example'   # force one resource to be recreated
terraform plan -var-file=envs/dev.tfvars -destroy             # preview a full teardown
terraform plan -var-file=envs/dev.tfvars -detailed-exitcode   # exit 0 = no changes, 1 = error, 2 = changes (drift checks)

# Outputs
terraform output                                              # all outputs
terraform output -raw backend_config                          # one value, unquoted, for scripts
terraform output -json | jq .                                 # everything, machine-readable

# Explore
terraform console -var-file=envs/dev.tfvars                   # evaluate expressions: local.tags, cidrsubnet(...)
terraform providers                                           # which providers each module needs
terraform graph | dot -Tsvg > graph.svg                       # dependency graph (needs Graphviz)
```

`-target` exists, but treat it as an emergency tool. A targeted apply leaves the rest of the stack unreconciled, and the next full plan may surprise you. If you need it routinely, the stack is too big; split it.

---

## Reading a plan

The summary line tells you the scale; the symbols tell you the risk:

| Symbol | Meaning | Reaction |
|---|---|---|
| `+` | create | Expected for new resources |
| `~` | update in place | Read the changed attributes |
| `-/+` or `+/-` | **replace** (destroy, then create, or the reverse) | Stop and find the `# forces replacement` line. On anything stateful (databases, buckets, clusters, state storage), this is data loss until proven otherwise. |
| `-` | destroy | Confirm it's intended |
| `<=` | read a data source | Usually harmless |

Summarize a large plan:

```sh
terraform show -json tfplan | jq -r '
  .resource_changes[]
  | select(.change.actions != ["no-op"])
  | "\(.change.actions | join(",")) \(.address)"'
```

List only the replacements:

```sh
terraform show -json tfplan | jq -r '.resource_changes[] | select(.change.actions | index("delete") and index("create")) | .address'
```

Two plan messages worth recognizing:

- **`(known after apply)`:** the value depends on something not yet created. Normal for IDs and ARNs. Suspicious if it causes a replacement of something that exists.
- **`Instance cannot be destroyed` / `prevent_destroy`:** the plan tried to destroy a protected resource, and Terraform refused. The protection is doing its job. Find out why the plan wants to destroy it before considering anything else.

---

## Inspecting state

```sh
terraform state list                                   # every resource address in state
terraform state list | grep aws_subnet                 # filter
terraform state show 'aws_subnet.private[0]'           # attributes of one resource
terraform state show 'azurerm_subnet.spoke["app/db"]'  # quote addresses with brackets
terraform show                                         # the whole state, human-readable

terraform state pull > backup-$(date +%Y%m%d-%H%M%S).tfstate   # local backup before any state change
```

Find which address manages a known cloud resource:

```sh
terraform show -json | jq -r '.values.root_module.resources[] | select(.values.id == "subnet-0abc123") | .address'
```

State backups are as sensitive as state. Keep them on approved storage and delete them when you're done.

---

## Changing state safely

Prefer **configuration blocks**. They show up in `plan`, go through review, and apply in CI like any other change:

```hcl
# Rename or move a resource without destroying it
moved {
  from = aws_subnet.app
  to   = aws_subnet.private
}

# Adopt a resource someone created by hand
import {
  to = aws_s3_bucket.logs
  id = "example-logs-bucket"
}

# Stop managing a resource without destroying it
removed {
  from = aws_instance.legacy
  lifecycle {
    destroy = false
  }
}
```

Draft the code for imported resources:

```sh
terraform plan -var-file=envs/dev.tfvars -generate-config-out=generated.tf
```

Review and clean up `generated.tf` before committing. It includes every attribute, including defaults you should delete.

**CLI fallbacks**, for break-glass only: take a backup first, and follow up with a pull request so code and state agree.

```sh
terraform state pull > backup.tfstate
terraform state mv 'aws_subnet.app' 'aws_subnet.private'
terraform state rm 'aws_instance.legacy'                       # forget; does NOT delete the resource
terraform import 'aws_s3_bucket.logs' example-logs-bucket
```

`terraform taint` is deprecated. Use `plan -replace=<address>` instead, which shows the replacement in the plan before it happens.

---

## Locks

Every state-changing command takes a lock: an S3 `.tflock` object on AWS, a blob lease on Azure. A second run waits (`-lock-timeout=5m`) or fails with `Error acquiring the state lock`, which names the holder:

```text
Lock Info:
  ID:        6f1c3c84-...
  Path:      example-tfstate-.../network-vpc/prod/terraform.tfstate
  Operation: OperationTypeApply
  Who:       runner@fv-az123-456
  Created:   2026-10-12 14:03:11 UTC
```

1. **Find the holder.** `Who` and `Created` usually identify a CI job or a person. Check for a running pipeline.
2. **If it's running, wait.** Interrupting an apply is worse than waiting for it.
3. **If the process is definitely dead** (cancelled job, crashed laptop), release the lock with the ID from the message:

```sh
terraform force-unlock <lock id>
```

Then run `terraform plan` immediately. A crashed apply may have changed some resources, and the plan shows what's left to reconcile.

Inspect the lock directly:

```sh
# AWS: the lock is an object next to the state
aws s3 ls s3://<bucket>/<stack>/<env>/terraform.tfstate.tflock

# Azure: the lock is a lease on the state blob
az storage blob show --auth-mode login --account-name <account> --container-name tfstate \
  --name <stack>/<env>/terraform.tfstate --query "properties.lease"
```

---

## Restoring a previous state version

Both bootstrap stacks keep every version of every state file. If a bad apply or state command damaged state, restore the last good version, then **plan** to see how reality compares. Don't apply until the plan makes sense.

Back up the current version first, with `terraform state pull > before-restore.tfstate`.

**AWS (S3 object versions):**

```sh
aws s3api list-object-versions --bucket <bucket> --prefix <stack>/<env>/terraform.tfstate \
  --query 'Versions[].{version:VersionId,modified:LastModified,size:Size,latest:IsLatest}' --output table

# Make an old version current again (the history stays intact)
aws s3api copy-object --bucket <bucket> --key <stack>/<env>/terraform.tfstate \
  --copy-source "<bucket>/<stack>/<env>/terraform.tfstate?versionId=<version id>"
```

**Azure (blob versions):**

```sh
az storage blob list --auth-mode login --account-name <account> --container-name tfstate \
  --prefix <stack>/<env>/terraform.tfstate --include v \
  --query "[].{version:versionId, modified:properties.lastModified, current:isCurrentVersion}" -o table

az storage blob download --auth-mode login --account-name <account> --container-name tfstate \
  --name <stack>/<env>/terraform.tfstate --version-id <version id> --file restored.tfstate
az storage blob upload --auth-mode login --account-name <account> --container-name tfstate \
  --name <stack>/<env>/terraform.tfstate --file restored.tfstate --overwrite
```

Then:

```sh
terraform init -reconfigure -backend-config=envs/<env>.backend.hcl
terraform plan -var-file=envs/<env>.tfvars
```

If the plan wants to create resources that already exist, they were created after the restored version. Bring them back into state with `import` blocks rather than letting Terraform create duplicates.

---

## Debugging Terraform itself

```sh
TF_LOG=DEBUG TF_LOG_PATH=tf-debug.log terraform plan -var-file=envs/dev.tfvars
TF_LOG_CORE=ERROR TF_LOG_PROVIDER=DEBUG terraform plan ...   # provider API calls only (PowerShell: set $env:TF_LOG_PROVIDER)
```

Debug logs include request and response bodies, which can contain secrets and tokens. Never paste them into a ticket or chat without redacting, and delete the file afterwards.

Evaluate expressions against real inputs:

```sh
terraform console -var-file=envs/dev.tfvars
> local.public_cidrs
> cidrsubnet("10.20.0.0/16", 4, 8)
> [for k, v in var.spokes : k]
```

---

## Troubleshooting by symptom

Read the **first** error. Later errors are often consequences of it.

### `init` fails

| Error contains | Cause | Fix |
|---|---|---|
| `AccessDenied` on `s3:GetObject` / `ListBucket` | The identity can't read the state bucket | Check the role (`aws sts get-caller-identity`) and its state policy; the github-oidc stack grants exactly this |
| `AccessDenied` / `KMS` / `kms:Decrypt` | The identity can read S3 but not use the state key | Grant `kms:Decrypt`, `kms:Encrypt`, `kms:GenerateDataKey` on the state key |
| `AuthorizationPermissionMismatch` (Azure) | Missing **Storage Blob Data Contributor** on the state account | Assign it. Role assignments can take several minutes to take effect. |
| `Key based authentication is not permitted` | Shared keys are disabled, but the backend tried to use one | Add `use_azuread_auth = true` to the backend config |
| `This request is not authorized to perform this operation` (Azure, 403) | The storage firewall blocks your IP | Add your egress IP to `allowed_ip_ranges` in bootstrap-state, or use a private endpoint |
| `Backend configuration changed` | The backend settings differ from the last init | `-reconfigure` to point at the new backend; `-migrate-state` only if you mean to move state there |
| `Failed to query available provider packages` | No access to the registry (proxy or disconnected network), or a constraint nothing satisfies | Check the network path or configure a provider mirror; check the version constraints |
| `the cached package ... does not match any of the checksums` | The lock file has no checksum for this platform | `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=windows_amd64`, then commit the lock file |
| `Unsupported Terraform Core version` | Your Terraform doesn't satisfy `required_version` | Use the version CI uses |

### Credentials

| Error contains | Cause | Fix |
|---|---|---|
| `No valid credential sources found` / `ExpiredToken` (AWS) | No or expired session | `aws sso login --profile <profile>` |
| `subscription ID could not be determined` / `az login` (Azure) | No Azure CLI session, or the wrong subscription | `az login`, then `az account set --subscription <id>` |
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` (CI) | The OIDC token's subject doesn't match the role's trust | Pull request jobs match `...:pull_request`; apply jobs must declare `environment: <apply_environment>`. Also check the workflow has `permissions: id-token: write`. |
| `AADSTS70021: No matching federated identity record found` (CI) | Same, on Azure | Compare the subject in the error with the federated credentials on the app registration |
| `AADSTS700016` / application not found | Wrong `ARM_CLIENT_ID` or tenant | Use the client ID from the github-oidc outputs |

### Plan or apply is denied

`AccessDenied`, `AuthorizationFailed`, or `403` on a specific API call means the identity is authenticated but not allowed to do that action.

- **Plan identity:** expected for anything beyond read. If plan itself fails reading a resource type, the read-only policy is missing that service.
- **Apply identity:** add the specific permission to the apply policy, through a pull request to github-oidc's inputs. Don't fall back to an admin role.
- **Azure role assignments failing** (`AuthorizationFailed` on `Microsoft.Authorization/roleAssignments/write`): `Contributor` can't grant access. Stacks that create role assignments (app-service-web, aks-cluster, functions-api) need the apply identity to also hold Role Based Access Control Administrator, ideally with a condition.
- **Explicit deny:** an AWS SCP or permissions boundary, or an Azure Policy deny assignment, blocks the action regardless of the role. The error usually says "explicit deny" or names the policy. That's an organizational control; talk to its owner.

### The plan wants to replace something

Find the trigger:

```sh
terraform plan -var-file=envs/<env>.tfvars -no-color | grep -B3 -A3 "forces replacement"
```

Common causes:

- **An immutable attribute changed**, such as a name, region, AZ, CIDR, or engine version on some services. Usually intentional, sometimes an accidental input change.
- **A resource address changed** (renamed in code, or moved into `for_each`). Terraform sees a delete plus a create. Add a `moved` block.
- **A provider upgrade changed a default or a computed value.** Compare the plan before and after the lock file change. Pin back and read the provider's upgrade guide.
- **A `random_string` changed** because its `keepers` changed or its state was lost. This renames every resource built from it (storage accounts, web apps). Restore state rather than accepting the rename.

### The plan always shows changes

A clean apply followed by a plan should show **no changes**. If the same diff reappears every time:

- **Something else owns that attribute.** Autoscalers own replica and desired counts, Azure Policy may add tags, and AWS services add their own tags. If the other owner is legitimate, use `lifecycle { ignore_changes = [...] }` for that attribute only, with a comment saying who owns it. The stacks already do this for ECS `desired_count` and the EKS node group's `desired_size`.
- **Formatting normalization:** JSON policies or CIDRs the API rewrites. Use `jsonencode()` or `aws_iam_policy_document` instead of raw JSON strings.
- **A provider bug:** search the provider's issue tracker for the resource and attribute.

### Someone changed something outside Terraform (drift)

```sh
terraform plan -var-file=envs/<env>.tfvars -refresh-only    # what changed in the real world
```

Then decide, on purpose:

- **Revert to code:** a normal `plan` and `apply` puts the code's values back.
- **Keep the change:** update the code to match, so the next plan shows no changes. Use `apply -refresh-only` only to record values in state that the code doesn't manage.

Either way, find out who made the change and why. Drift is a finding ([guide section 4](../README.md#4-infrastructure-as-code)).

### `already exists` on create

The resource exists but isn't in this state. Someone created it by hand, a previous apply created it and then lost the state write, or another stack manages it.

- If **another stack** manages it, remove it from one of them. Two owners fight forever.
- Otherwise, adopt it with an `import` block (see [Changing state safely](#changing-state-safely)).

### Apply failed halfway

Terraform writes state as each resource completes, so finished resources are recorded and failed ones aren't. **Don't delete state or start over.** Fix the cause and run `plan` again; it shows only what's left. If the failure was a timeout, the resource may exist in the cloud but not in state. Check the console, then `import` it if needed.

### Eventual consistency and retries

Some cloud changes take seconds to minutes to propagate, so an apply that fails once succeeds on retry:

- **AWS:** a new IAM role used immediately (`The role defined for the function cannot be assumed by Lambda`, or the EKS cluster role).
- **Azure:** a new managed identity used in a role assignment (`PrincipalNotFound`), or a new role assignment used for data access (`AuthorizationPermissionMismatch`).

Re-run the plan and apply. If it happens on every new environment, add an explicit `depends_on`, or a `time_sleep` from the `hashicorp/time` provider, with a comment explaining why.

### Long-running or stuck resources

Some resources legitimately take a long time to create or update: EKS clusters and node groups, AKS clusters, Azure Firewall, PostgreSQL Flexible Server with HA, and NAT gateways. Expect 10 to 30 minutes, and watch the console. If an apply was interrupted mid-create, the next plan may show the resource as `tainted`. Terraform will replace it, which is usually right for a half-created resource.

### Quotas and limits

| Error contains | Likely limit | Check |
|---|---|---|
| `AddressLimitExceeded` | Elastic IPs per region (default 5); network-vpc uses one per NAT gateway | `aws service-quotas list-service-quotas --service-code ec2 --query "Quotas[?contains(QuotaName, 'Elastic IP')]"` |
| `VpcLimitExceeded` | VPCs per region (default 5) | Service Quotas console, or the same command with `--service-code vpc` |
| `QuotaExceeded` / `OperationNotAllowed` for VM cores (Azure) | vCPU quota per VM family per region, often hit by AKS node pools | `az vm list-usage --location <region> -o table` |
| `MissingSubscriptionRegistration` (Azure) | The resource provider isn't registered in the subscription | `az provider register --namespace Microsoft.ContainerService` (or the namespace in the error) |

Request increases ahead of production. They can take days.

### Names already taken

S3 bucket names and Azure storage account, web app, Cosmos DB, and Key Vault names are **globally** unique. The stacks add the account ID or a random suffix. If you remove those for "cleaner" names, expect collisions.

### Destroy is blocked

| Error contains | Cause | Resolution |
|---|---|---|
| `Instance cannot be destroyed` | `prevent_destroy` | Intentional. Remove it in a reviewed pull request first. |
| `deletion protection` (ALB, DynamoDB) | The `deletion_protection` variable | Set it to `false` in that environment's tfvars, apply, then destroy |
| `ScopeLocked` (Azure) | The `CanNotDelete` management lock on the state account | Remove the `azurerm_management_lock` resource first |
| `BucketNotEmpty` | Versioned objects remain | For a state bucket, that's your state history. Archive it before emptying. |
| KMS key `PendingDeletion` | KMS keys wait 7 to 30 days before deletion | Expected; cancel with `aws kms cancel-key-deletion` if it was a mistake |

### `Invalid for_each argument` / `Invalid count argument`

`for_each` keys and `count` must be known at plan time. The error means they depend on something created in the same apply, such as an ID. Key `for_each` on values you control (names from variables), not on resource attributes. As a one-time bootstrap workaround only, `-target` the dependency first.

### `Cycle:`

Two resources depend on each other. Draw the graph to find the loop (`terraform graph | dot -Tsvg > graph.svg`), then break it, usually by splitting a resource into two (for example, a security group and its rules as separate resources, as the ecs-fargate-web stack does).

### CI checks fail

Run the same check locally (commands in the [README](README.md#checks-and-tested-versions)):

- **fmt:** `terraform fmt -recursive`, then commit.
- **tflint:** read the rule name in the output. Fix the code, or use `# tflint-ignore: <rule> # reason` on the line above the resource if the rule doesn't apply.
- **checkov:** fix it, or add `#checkov:skip=<ID>:<reason>` **inside** the resource block. Checkov ignores skip comments placed above the block. Read the check's definition before deciding it's a false positive.
- **terraform test:** an assertion failing means behavior changed. Decide whether the code or the test is wrong. Mock providers can't fill computed nested blocks, so code that indexes into one (`x.block[0].attr`) fails under test; use `one(x.block[*].attr)` instead.

---

## Stack-specific notes

| Stack | Notes |
|---|---|
| bootstrap-state (both) | First apply uses local state. Back up `terraform.tfstate` before `-migrate-state`, and delete the local copy after confirming the migration. |
| github-oidc (AWS) | Only one GitHub OIDC provider can exist per account. If another stack or a console click created it, set `create_oidc_provider = false`. |
| github-oidc (Azure) | Needs an Entra ID role that can create app registrations. The error is `Authorization_RequestDenied` from Microsoft Graph. |
| network-vpc | With one NAT gateway per AZ, it uses three Elastic IPs; check the quota in fresh accounts. Changing `availability_zones` or `vpc_cidr` replaces subnets, and everything in them. |
| network-hub-spoke | Changing `egress_mode` swaps NAT gateways for routes through the firewall, or the reverse. Spoke egress is briefly interrupted, so schedule it. |
| ecs-fargate-web | A failed deployment rolls back automatically (circuit breaker); the apply still succeeds. Check `aws ecs describe-services` for the deployment state. |
| eks-cluster | Cluster creation takes about 10 to 15 minutes, node groups a few more. Changing `kubernetes_version` upgrades the control plane; upgrade one minor version at a time. |
| aks-cluster | `host_encryption = true` fails with a feature-not-registered error until `EncryptionAtHost` is registered on the subscription ([README: per-stack prerequisites](README.md#per-stack-prerequisites)). |
| app-service-web | The app can't reach the database until an admin creates its role (`terraform output create_app_db_role_sql`). |
| functions-api | Terraform creates the infrastructure only; publish code with `terraform output publish_command`. |
