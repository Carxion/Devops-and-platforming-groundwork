# Terraform reference stacks

Starting points for common AWS and Azure architectures, written to the standards the [onboarding checklist](../../tech-lead/README.md) asks you to look for. Use them to compare against what a program already has, or copy one into your own infrastructure repository as the first version of a new stack.

These are **root modules to copy and adapt**, not a module library to call. Every program's constraints are different, and code you own outright is easier to change than a dependency you don't.

> **Status.** Every stack passes `terraform validate`, `terraform test` (offline plans against mock providers), tflint with the AWS and Azure rulesets, and checkov, in CI on every change. None has been applied to a real account by this project. Apply to a sandbox first, and read [Decisions you still own](#decisions-you-still-own) before production.

## Contents

- [What's here](#whats-here)
- [Setup](#setup)
- [Quick start in a sandbox](#quick-start-in-a-sandbox)
- [Making it operational](#making-it-operational)
- [Day-2 operations](#day-2-operations)
- [Best practices](#best-practices)
- [Decisions you still own](#decisions-you-still-own)
- [Checks and tested versions](#checks-and-tested-versions)

For day-to-day commands and troubleshooting, see [OPERATIONS.md](OPERATIONS.md).

---

## What's here

### AWS

| Stack | What it builds | Inputs from |
|---|---|---|
| [bootstrap-state](aws/bootstrap-state/) | S3 state bucket: versioned, KMS-encrypted, TLS-only, public access blocked, native lock files (no DynamoDB) | — |
| [github-oidc](aws/github-oidc/) | GitHub OIDC provider and two roles: **plan** (pull requests, read-only plus state lock) and **apply** (protected environment only) | bootstrap-state |
| [network-vpc](aws/network-vpc/) | VPC with public, private, and isolated subnets per AZ, NAT per AZ (or one shared), flow logs, S3 gateway endpoint, locked-down default security group | — |
| [ecs-fargate-web](aws/ecs-fargate-web/) | HTTPS-only ALB with WAF managed rules, Fargate service in private subnets (non-root, read-only root filesystem), immutable KMS-encrypted ECR, autoscaling, deployment circuit breaker | network-vpc |
| [eks-cluster](aws/eks-cluster/) | EKS with private API endpoint, access entries (no `aws-auth`), KMS-encrypted Secrets, enforced NetworkPolicy (VPC CNI), all control plane logs, IMDSv2-only nodes, Pod Identity agent | network-vpc |
| [serverless-api](aws/serverless-api/) | HTTP API with throttling, access logs, and optional JWT authorizer, then Lambda (arm64, X-Ray), then DynamoDB with point-in-time recovery | — |

### Azure

| Stack | What it builds | Inputs from |
|---|---|---|
| [bootstrap-state](azure/bootstrap-state/) | State storage account with shared keys disabled (Entra ID only), versioning, soft delete, delete lock | — |
| [github-oidc](azure/github-oidc/) | Two Entra ID apps with federated credentials (no secrets): **plan** (pull requests, Reader) and **apply** (protected environment only) | bootstrap-state |
| [network-hub-spoke](azure/network-hub-spoke/) | Hub VNet with firewall, Bastion, and gateway subnets; peered spokes with an NSG per subnet; explicit egress (NAT gateway, Azure Firewall, or none); shared Log Analytics workspace | — |
| [app-service-web](azure/app-service-web/) | Zone-balanced App Service running a container, with VNet integration, managed identity, and App Insights; private PostgreSQL Flexible Server with Entra ID auth only | network-hub-spoke |
| [aks-cluster](azure/aks-cluster/) | AKS with Entra ID and Azure RBAC (local accounts off), workload identity, CNI overlay with Cilium, automatic patch upgrades, Azure Policy, Container Insights | network-hub-spoke |
| [functions-api](azure/functions-api/) | Flex Consumption Functions (Python) with optional Entra ID auth, then serverless Cosmos DB; managed identity everywhere, no keys | — |

### Stack layout

```text
versions.tf                Terraform and provider pins, backend, provider config
variables.tf               inputs, each with a description
main.tf                    resources, with a header comment explaining the design
outputs.tf                 values the next stack or a person needs
terraform.tfvars.example   example inputs
backend.hcl.example        example backend config (bootstrap stacks start with local state)
tests/plan.tftest.hcl      offline tests of the stack's important behavior
.terraform.lock.hcl        exact provider versions and checksums
```

### How the stacks fit together

```text
bootstrap-state ──► github-oidc            (once per account or subscription)
       │
       └──► state for every stack below
network ──► ecs-fargate-web | eks-cluster   (AWS)
network ──► app-service-web | aks-cluster   (Azure)
serverless-api, functions-api               (standalone)
```

Stacks share values through **inputs**, not by reading each other's state. Copy outputs into the next stack's tfvars, or wire them up in your pipeline. That keeps every state file small and every blast radius contained.

---

## Setup

### Tools

| Tool | Version | Used for | Install |
|---|---|---|---|
| Terraform | 1.10 or later (tested on 1.16.5) | everything | `brew install hashicorp/tap/terraform`, `winget install Hashicorp.Terraform`, or a version manager such as [tenv](https://github.com/tofuutils/tenv) |
| AWS CLI v2 | current | AWS sign-in | `brew install awscli` or `winget install Amazon.AWSCLI` |
| Azure CLI | current | Azure sign-in | `brew install azure-cli` or `winget install Microsoft.AzureCLI` |
| tflint | 0.64 or later | linting | `brew install tflint`, or a binary from [the latest release](https://github.com/terraform-linters/tflint/releases/latest) |
| checkov | 3.x | policy checks | `pipx install checkov` or `pip install checkov` |
| kubectl and kubelogin | current | EKS and AKS access | `az aks install-cli` installs both; for EKS, kubectl alone |
| Azure Functions Core Tools | v4 | publishing functions-api code | `npm install -g azure-functions-core-tools@4` |

Pin the Terraform version your CI uses, and use the same one locally. A version manager makes switching between programs painless.

### Cloud access

Use short-lived credentials from single sign-on, never long-lived access keys or client secrets on a laptop.

**AWS**

```sh
aws configure sso                     # once per profile
aws sso login --profile sandbox-admin
export AWS_PROFILE=sandbox-admin      # PowerShell: $env:AWS_PROFILE = "sandbox-admin"
aws sts get-caller-identity           # confirm the account before every apply
```

**Azure**

```sh
az login
az account set --subscription "<subscription id>"
az account show --query "{name:name, id:id, tenant:tenantId}"   # confirm before every apply
```

The azurerm provider uses your Azure CLI sign-in locally. In CI it uses OIDC (see [CI pipeline](#4-ci-pipeline)).

### Permissions for the first run

A person, not the pipeline, runs `bootstrap-state` and `github-oidc` once per account or subscription. They need more access than the pipeline ever will:

| Stack | Needs |
|---|---|
| aws/bootstrap-state, aws/github-oidc | IAM administrator (to create the OIDC provider and roles) |
| azure/bootstrap-state | Owner, or Contributor plus Role Based Access Control Administrator, on the subscription (it creates a role assignment) |
| azure/github-oidc | The same subscription access, plus an Entra ID role that can create app registrations, such as Application Administrator or Cloud Application Administrator |

After that, all changes go through the pipeline's plan and apply identities.

### Per-stack prerequisites

| Stack | Have this ready first |
|---|---|
| aws/ecs-fargate-web | An ACM certificate in the same region. For the first apply, point `container_image` at an image you can already pull (from your approved mirror). Then push to the new ECR repository and switch to its digest. |
| aws/eks-cluster | The IAM role ARNs of cluster admins, such as your SSO admin role. With the default private endpoint, a network path into the VPC: VPN, Direct Connect, a bastion, or CI runners inside the VPC. |
| aws/serverless-api | An OIDC issuer and audience for the JWT authorizer, such as a Cognito user pool or your IdP |
| aws/github-oidc | The managed policy (or policies) the apply role gets, and ideally a permissions boundary policy. Create both deliberately; there's no safe default. |
| azure/app-service-web | An Entra ID group for database admins, a container image in a registry, and spoke subnets delegated to `Microsoft.Web/serverFarms` and `Microsoft.DBforPostgreSQL/flexibleServers` (the network-hub-spoke example creates them) |
| azure/aks-cluster | An Entra ID group for cluster admins. Register host encryption once per subscription: `az feature register --namespace Microsoft.Compute --name EncryptionAtHost`, wait for `Registered`, then `az provider register --namespace Microsoft.Compute`. Or set `host_encryption = false`. |
| azure/functions-api | A region that supports Flex Consumption (`az functionapp list-flexconsumption-locations`), and an Entra ID app registration for `entra_client_id` |

---

## Quick start in a sandbox

Use a sandbox account or subscription with nothing you'd mind losing. The steps are identical for both clouds; swap `aws` for `azure`.

```sh
# 1. State storage (local state at first)
cd devops/terraform/aws/bootstrap-state
cp terraform.tfvars.example terraform.tfvars   # edit
terraform init
terraform apply
terraform output backend_config                # keep this for step 3

# 2. Move bootstrap's own state into the bucket it just created:
#    uncomment the backend block in versions.tf, fill it in, then
terraform init -migrate-state

# 3. Any other stack
cd ../network-vpc
cp backend.hcl.example backend.hcl             # paste from backend_config; set a unique key
cp terraform.tfvars.example terraform.tfvars   # edit
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan                     # read it
terraform apply tfplan
```

To tear a sandbox down, destroy in reverse order: workloads, then network, then github-oidc, then bootstrap-state. Protected resources need the extra step described in [Teardown](#teardown).

---

## Making it operational

Running a stack once from a laptop is a demo. Making it operational means it lives in version control, changes only through reviewed pull requests, applies only from a pipeline, and tells you when reality drifts from code.

### 1. Copy the stacks into your infrastructure repository

Copy only the stacks you need, with their lock files and tests, and make them yours: rename resources to your conventions, delete variables you'll never set, and add your organization's required tags. A layout that scales to several environments:

```text
infra/
├── .github/
│   ├── CODEOWNERS
│   └── workflows/
│       ├── terraform-network-vpc.yml
│       └── terraform-drift.yml
├── bootstrap/                    # bootstrap-state and github-oidc, one folder per account
└── stacks/
    └── network-vpc/
        ├── *.tf
        ├── .terraform.lock.hcl
        ├── tests/
        └── envs/
            ├── dev.tfvars
            ├── dev.backend.hcl
            ├── prod.tfvars
            └── prod.backend.hcl
```

Unlike this repository, **commit `envs/*.tfvars` and `envs/*.backend.hcl`** in your infrastructure repository. They hold names, sizes, and IDs, not secrets. Secrets never go in tfvars; reference them from Secrets Manager or Key Vault.

Run a stack against one environment with:

```sh
terraform init -reconfigure -backend-config=envs/prod.backend.hcl
terraform plan -var-file=envs/prod.tfvars -out=tfplan
```

### 2. Separate environments at the account boundary

Put production and non-production in **different AWS accounts or Azure subscriptions**, each with its own bootstrap-state and github-oidc. A mistake or a compromised credential in dev then can't reach prod. This is section [3.1](../../tech-lead/README.md#31-account-and-organization-structure) of the guide.

Within an account, use one state key per stack per environment (`<stack>/<env>/terraform.tfstate`). Avoid Terraform workspaces for environment separation; separate backend files are explicit and show up in review.

### 3. Configure GitHub

| Setting | Configuration |
|---|---|
| **Environments** | One per deployment target, such as `production`. Add required reviewers, turn on "prevent self-review", and limit deployment branches to `main`. The apply identity trusts only jobs in this environment, so these rules gate every apply. |
| **Variables** | Role ARNs and client IDs aren't secrets, so store them as variables. Put plan identities at repository level, and apply identities **on the environment**, so only gated jobs can see them. |
| **Branch ruleset on `main`** | Require a pull request with at least one approval, require status checks (plan, validate and test, tflint, checkov), require branches to be up to date, and allow no bypass. |
| **CODEOWNERS** | Platform team owns `stacks/`. Platform and security own `.github/workflows/` and anything touching IAM, network boundaries, or `github-oidc`. |
| **Actions settings** | Default workflow token permissions read-only. Allow only actions you've reviewed, pinned to commit SHAs. |

### 4. CI pipeline

Apply the `github-oidc` stack first. One workflow per stack keeps permissions and triggers narrow. This one plans on pull requests and applies after merge:

```yaml
name: terraform-network-vpc

on:
  pull_request:
    paths: ["stacks/network-vpc/**"]
  push:
    branches: [main]
    paths: ["stacks/network-vpc/**"]

permissions:
  contents: read
  id-token: write # lets jobs request an OIDC token

env:
  TF_IN_AUTOMATION: "1"
  ENV: prod

defaults:
  run:
    working-directory: stacks/network-vpc

jobs:
  plan:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: aws-actions/configure-aws-credentials@e1253824e5c10ff9df46874f81ed3ec929e19cfd # v6.3.0
        with:
          role-to-assume: ${{ vars.AWS_PLAN_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}
      - uses: hashicorp/setup-terraform@dfe3c3f87815947d99a8997f908cb6525fc44e9e # v4.0.1
        with:
          terraform_version: 1.16.5
          terraform_wrapper: false
      - run: terraform init -input=false -lockfile=readonly -backend-config=envs/$ENV.backend.hcl
      - run: terraform plan -input=false -lock-timeout=5m -var-file=envs/$ENV.tfvars -out=tfplan
      - name: Plan to job summary
        run: |
          { echo '```'; terraform show -no-color tfplan; echo '```'; } >> "$GITHUB_STEP_SUMMARY"

  apply:
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    environment: production # required reviewers approve here
    concurrency:
      group: network-vpc-prod
      cancel-in-progress: false # never interrupt an apply
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: aws-actions/configure-aws-credentials@e1253824e5c10ff9df46874f81ed3ec929e19cfd # v6.3.0
        with:
          role-to-assume: ${{ vars.AWS_APPLY_ROLE_ARN }} # environment-level variable
          aws-region: ${{ vars.AWS_REGION }}
      - uses: hashicorp/setup-terraform@dfe3c3f87815947d99a8997f908cb6525fc44e9e # v4.0.1
        with:
          terraform_version: 1.16.5
          terraform_wrapper: false
      - run: terraform init -input=false -lockfile=readonly -backend-config=envs/$ENV.backend.hcl
      - run: terraform plan -input=false -lock-timeout=5m -var-file=envs/$ENV.tfvars -out=tfplan
      - run: terraform apply -input=false tfplan
```

**For Azure**, drop the AWS credentials step and set these on the job instead. The azurerm and azuread providers and the azurerm backend all read them and fetch the GitHub OIDC token themselves:

```yaml
    env:
      ARM_USE_OIDC: "true"
      ARM_CLIENT_ID: ${{ vars.AZURE_PLAN_CLIENT_ID }} # AZURE_APPLY_CLIENT_ID in the apply job
      ARM_TENANT_ID: ${{ vars.AZURE_TENANT_ID }}
      ARM_SUBSCRIPTION_ID: ${{ vars.AZURE_SUBSCRIPTION_ID }}
```

Things to know about this pipeline:

- **Reviewers approve the plan on the pull request.** The apply job re-plans against the merged code. "Require branches to be up to date" keeps that plan the same as the one reviewed. If you need a byte-for-byte guarantee, upload the PR plan as an artifact and apply that file instead. Plans can contain sensitive values, though, so restrict and expire the artifact.
- **Add your other checks to the PR**, such as `terraform test`, tflint, and checkov. This repository's [terraform.yml](../../.github/workflows/terraform.yml) is a working example.
- **Multiple environments:** add a job per environment. Typically dev applies on merge without approval, then prod waits for approval in its own environment.
- **Fork pull requests** don't get OIDC tokens, so they can't plan against your accounts. That's intended.

### 5. Drift detection

Drift means someone changed real resources outside Terraform. The guide treats hand-built and drifted resources as findings ([section 4](../../tech-lead/README.md#4-infrastructure-as-code)). Detect drift on a schedule with a plan that fails when anything would change.

First, let the plan identity trust scheduled runs on `main`. Add this to `github-oidc`'s tfvars:

```hcl
plan_additional_subjects = ["repo:<owner>/<repo>:ref:refs/heads/main"]
```

Then add a scheduled workflow:

```yaml
name: terraform-drift
on:
  schedule:
    - cron: "0 7 * * 1-5" # weekdays 07:00 UTC
  workflow_dispatch:

permissions:
  contents: read
  id-token: write

jobs:
  drift:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        stack: [network-vpc, ecs-fargate-web]
    defaults:
      run:
        working-directory: stacks/${{ matrix.stack }}
    steps:
      # checkout, credentials (plan identity), and setup-terraform as in the plan job
      - run: terraform init -input=false -lockfile=readonly -backend-config=envs/prod.backend.hcl
      # Exit code 2 means "changes present", which fails the job and alerts you.
      - run: terraform plan -input=false -lock=false -detailed-exitcode -var-file=envs/prod.tfvars
```

`-lock=false` keeps a scheduled read from blocking a real apply. When drift appears, either reconcile the code to match the change, through a pull request, or apply to revert it. Find out who made the change and why either way.

---

## Day-2 operations

### Upgrades

- **Terraform:** bump `required_version` and the CI `terraform_version` together, in one pull request. Read the release notes and run plans in every environment before merging.
- **Providers:** Dependabot opens monthly pull requests that update lock files. Merge them only after the PR plan shows no unexpected changes. Treat deprecation warnings in `terraform validate` as a backlog; they're the next major version's breaking changes.
- **Kubernetes:** upgrade `kubernetes_version` one minor version at a time, in non-prod first. EKS add-ons should be pinned to explicit versions once you adopt the stack. AKS applies patch versions itself through the `patch` upgrade channel, inside the maintenance windows in the stack.

### Changing what Terraform manages

Use configuration blocks so every change shows up in a plan and in review, instead of `terraform state` commands run from a laptop:

| Situation | Use |
|---|---|
| Renaming or moving a resource in code | a `moved` block |
| Adopting a resource someone built by hand | an `import` block, then `terraform plan -generate-config-out=generated.tf` to draft its code |
| Stopping management without destroying the resource | a `removed` block with `lifecycle { destroy = false }` |

### Recovering state

- **A bad apply corrupted state:** both backends keep versions. Restore the previous version of the state object (S3 object versions, or Azure blob versions), then run `terraform plan` to see where reality stands.
- **A lock is stuck:** confirm in CI that no job is still running, then run `terraform force-unlock <lock id>`. Never force-unlock a lock held by a running apply.

### Break-glass changes

When the pipeline is down and production needs a fix, an engineer with emergency access can run Terraform locally against the same backend. State locking prevents collisions. Record what was run and why, then open a pull request that matches the code to the change, so the next pipeline run doesn't revert it.

### Teardown

State storage, databases, Key Vault-style data, and the ALB are protected on purpose. Destroying them takes two reviewed steps:

1. A pull request that removes the protection, for example `prevent_destroy`, `deletion_protection = false`, or deleting the `azurerm_management_lock`. Apply it.
2. Then `terraform destroy`, or a pull request that deletes the resources.

Destroy in reverse dependency order: workloads, then network, then github-oidc, then bootstrap-state last. Its state lives in the bucket you're deleting, so migrate it back to local first (`terraform init -migrate-state` with the backend block commented out).

---

## Best practices

### Workflow

- **Every change is a pull request with a plan attached.** Nobody applies from a laptop except during a recorded break-glass event.
- **Read the plan, not the diff.** The code diff shows intent; the plan shows what will actually happen, including replacements. Treat any `must be replaced` on a stateful resource as a stop sign.
- **Small, frequent changes.** A plan with three changes gets reviewed; a plan with three hundred gets approved.
- **One stack, one owner, one pipeline.** Shared stacks become nobody's stacks.

### State

- **Remote, encrypted, versioned, and locked**, from day one. Local state is for the bootstrap's first apply only.
- **Small state files.** Split by lifecycle and blast radius: network changes rarely, apps change daily.
- **Treat state as sensitive.** It contains resource attributes, and sometimes secrets, in plain text. Restrict who can read it as tightly as who can apply.

### Code

- **Pin everything:** Terraform, providers (commit `.terraform.lock.hcl`), modules, and CI actions.
- **Describe every variable**, and validate inputs that have a known shape. A failed validation beats a failed apply.
- **Defaults should be production-safe.** Put cheaper non-prod settings in that environment's tfvars, not in the defaults.
- **No secrets in code or tfvars.** Use Secrets Manager or Key Vault and managed identities. If a secret must pass through Terraform, mark it `sensitive` and expect it in state anyway.
- **Test conditional behavior** with `terraform test` and mock providers. It's fast, offline, and catches logic errors `validate` can't.

### Security

- **Separate plan and apply identities**, with apply gated by a protected environment. The pipeline is a production credential; threat-model it ([section 7.6](../../tech-lead/README.md#76-threat-modeling-and-incident-response)).
- **Least privilege for apply.** Start narrow and add permissions when a plan fails, not before. On AWS, use a permissions boundary so the pipeline can't grant itself more.
- **Policy as code that blocks**, with every exception written down next to the code it excuses. A warning-only scanner gets ignored.
- **Pull providers and modules through an approved mirror** where policy requires it. Terraform supports a `provider_installation` block in the CLI configuration for network mirrors.

### Operations

- **Detect drift on a schedule** and treat it as an incident to explain, not just noise to reapply.
- **Tag for ownership and cost** on every resource; the stacks already apply `Owner`, `Project`, `Environment`, `ManagedBy`, and `Stack`.
- **Practice restores.** Restore an old state version and a database backup in a sandbox at least once before you need to.

---

## Decisions you still own

Defaults are a starting point, not an authorization. Settle these with your security lead before production.

- **Who can reach the edge.** `allowed_ingress_cidrs` (ALB) defaults to the internet. App Service and Functions are public endpoints; front them with Front Door or Application Gateway and restrict access where required.
- **Authentication on the serverless APIs.** Both are open until you set `jwt_issuer` (AWS) or `entra_client_id` (Azure). The tests check both modes.
- **CI permissions.** AWS `ReadOnlyAccess` for plan can read some data (for example S3 objects and parameter values). Azure `Contributor` for apply can't create role assignments. Narrow or extend both deliberately, and use a permissions boundary on the AWS apply role.
- **Customer-managed keys.** Most services use provider-managed keys. If policy requires customer-managed keys, the relevant checkov skips tell you where to add them.
- **Egress.** AWS private subnets egress through NAT to anywhere. Azure spokes default to NAT gateway; `egress_mode = "firewall"` denies everything until you add policy rules.
- **Retention.** Log retention defaults (365 days in CloudWatch, 90 in Log Analytics) are placeholders. Set them to your program's records requirement.
- **Cost.** NAT gateways, Azure Firewall, EKS and AKS control planes, zone-redundant Postgres, and WAF all carry fixed monthly costs. Non-prod examples in the tfvars turn the expensive ones down.

Every checkov exception is an inline `#checkov:skip=<ID>:<reason>` next to the resource it applies to. Review the list with `grep -rn "checkov:skip" devops/terraform/`.

---

## Checks and tested versions

Run from the repository root. None of these need cloud credentials.

```sh
terraform fmt -check -recursive devops/terraform

# per stack: validate and offline tests against mock providers
cd devops/terraform/aws/network-vpc
terraform init -backend=false
terraform validate
terraform test

# from devops/terraform/
tflint --init && tflint --recursive --config "$(pwd)/.tflint.hcl"
checkov -d . --framework terraform
```

Tested with Terraform 1.16.5, `hashicorp/aws` 6.68, `hashicorp/azurerm` 5.9, `hashicorp/azuread` 3.10, tflint 0.64 (AWS ruleset 0.49, azurerm ruleset 0.32), and checkov 3.3, in October 2026.
