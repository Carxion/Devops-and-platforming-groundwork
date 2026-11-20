# 10. Best practices

The habits that keep Terraform boring after the first stack: how to lay out code and environments, how changes reach production, and how to keep stacks healthy for years. Each is a default, not a law; depart from one when you can say why.

The [README's best practices](README.md#best-practices) are the short version of this page.

## Contents

- [Repository layout](#repository-layout)
- [Environments](#environments)
- [Size and split stacks](#size-and-split-stacks)
- [Naming and tagging](#naming-and-tagging)
- [Versions](#versions)
- [Inputs and defaults](#inputs-and-defaults)
- [Secrets](#secrets)
- [Protecting what matters](#protecting-what-matters)
- [The change workflow](#the-change-workflow)
- [Pipeline identities](#pipeline-identities)
- [Drift](#drift)
- [Upgrades](#upgrades)
- [Reviewing a Terraform change](#reviewing-a-terraform-change)

## Repository layout

```text
infrastructure/
├── modules/                  modules used only in this repository
│   └── s3-bucket/
├── stacks/
│   ├── network/              one root module per stack
│   │   ├── *.tf
│   │   ├── tests/
│   │   ├── dev.tfvars        one inputs file per environment
│   │   ├── prod.tfvars
│   │   └── .terraform.lock.hcl
│   └── uploads/
├── .tflint.hcl
└── .gitlab-ci.yml
```

One root module per stack, used by every environment with a different tfvars file and state key. The code that runs in production is the code that ran in dev, with different inputs.

The alternative, a directory per environment (`envs/dev/uploads/`, `envs/prod/uploads/`) each calling a shared module, suits environments that genuinely differ in shape. It costs a copy of the wiring per environment, and copies drift. Start with one root module and tfvars; split when the differences stop fitting in variables.

## Environments

- **One AWS account per environment**, at least separating production from everything else. An account is the strongest boundary AWS has: a dev credential can't touch prod resources if they're in another account, whatever its policies say.
- **One state key per stack per environment** (`uploads/prod/terraform.tfstate`), ideally in a state bucket in that environment's account, so reading prod state needs prod access.
- **`allowed_account_ids`** in each environment's provider configuration ([03](03-the-aws-provider.md#guard-the-account)), so a wrong profile fails instead of applying.
- **Not workspaces** for long-lived environments ([04](04-state.md#workspaces-and-why-not-to-use-them-for-environments)).

To set the account per environment, make it a variable:

```hcl
# The account comes from each environment's tfvars.
variable "account_id" {
  description = "The AWS account this environment must run in."
  type        = string
}

provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]
}
```

## Size and split stacks

Split stacks by **lifecycle** and **blast radius**:

- Things that change together go together; things that change at different rates go apart. The network changes yearly, the uploads flow monthly, an app daily.
- A plan should be readable. Past a few dozen resources, reviewers stop reading.
- A mistake should be contained. `destroy` in the uploads stack shouldn't be able to touch the VPC.
- Small states plan fast and lock briefly.

Pass values between stacks as **inputs** (outputs copied into the next stack's tfvars, or wired up in the pipeline), or look them up with data sources by name or tag. Avoid `terraform_remote_state`: it gives one stack read access to another's entire state, secrets included, and couples them so you can't change one's outputs without breaking the other.

## Naming and tagging

- A predictable scheme, `<project>-<environment>-<component>`, set in one local and used everywhere.
- Global names (S3 buckets) include the account ID and region.
- Most names can't change without replacement, so settle the scheme before the first apply.
- `default_tags` with at least `Project`, `Environment`, `Owner`, and `ManagedBy`, so every resource answers "whose is this, and is Terraform managing it?" in the console.

## Versions

| What | How |
|---|---|
| Terraform | `required_version = "~> 1.10"` in code; one exact version in CI, and the same locally through a version manager |
| Providers in root modules | `version = "~> 6.68"`, plus `.terraform.lock.hcl` committed with hashes for every platform |
| Providers in shared modules | A minimum (`>= 6.0, < 7.0`), never an exact pin |
| Modules from a registry | An exact version or a narrow `~>` |
| Modules from Git | `?ref=` a tag or, better, a commit |
| CI images and actions | Pinned to a digest or commit SHA |

In CI, `terraform init -lockfile=readonly` fails rather than changing the lock file, so provider upgrades only happen in a reviewed commit.

## Inputs and defaults

- Every variable has a `description` and a `type`; tflint's `terraform_documented_variables` rule enforces the first.
- Defaults are the **production-safe** choice. Cheaper non-production settings (one NAT gateway, `force_destroy`) go in that environment's tfvars with a comment, so production can't get them by omission.
- Validate anything with a known shape. A validation failure at plan time beats an API error halfway through an apply.
- Few inputs. Every variable is a decision someone has to make correctly; fix what doesn't need to vary.

## Secrets

- No secrets in `.tf` files, tfvars, or CI variables that reach Terraform, if you can help it.
- Applications read secrets from Secrets Manager or SSM Parameter Store at run time; Terraform creates the empty secret and grants access to it.
- When Terraform must set a secret, use an ephemeral resource and a write-only argument, which never reach state ([07](07-advanced-language.md#ephemeral-values-and-write-only-arguments)).
- Treat state as sensitive anyway: encrypted, versioned, and readable only by the people and pipelines that apply.

## Protecting what matters

- `prevent_destroy` on resources whose loss is a data loss: state buckets, databases, KMS keys, log archives.
- Versioning and backups on data, and AWS-side deletion protection where it exists (`deletion_protection` on RDS instances, `deletion_protection_enabled` on DynamoDB tables).
- `force_destroy = false` on buckets by default.
- Treat `must be replaced` on a stateful resource as a stop sign in review.

## The change workflow

```text
branch ─► merge request ─► fmt, validate, tflint, checkov, tests ─► plan posted to the MR
       ─► review the plan ─► merge ─► plan on main ─► manual approval ─► apply that plan
```

- **Every change goes through a merge request with its plan attached.** Nobody applies from a laptop outside a recorded break-glass procedure.
- **Apply the saved plan** (`terraform apply tfplan`) that was reviewed, not a fresh one.
- **Small changes.** A plan with three changes gets read; one with three hundred gets approved.
- The [GitLab Terraform pipeline](../gitlab/examples/terraform/.gitlab-ci.yml) implements all of this and was run end to end in the [GitLab lab](../gitlab/lab/README.md).

## Pipeline identities

- **Short-lived credentials through OIDC**, never stored access keys. The [`gitlab-oidc`](aws/gitlab-oidc/) and [`github-oidc`](aws/github-oidc/) stacks create the roles.
- **Separate plan and apply roles.** Plan can read; apply can change, and only from a protected branch or environment.
- **Least privilege for apply**, grown from what plans actually need, and a permissions boundary so the pipeline can't grant itself more.
- The pipeline is a production credential. Protect who can change it as tightly as who can change production.

## Drift

Drift is a difference between state and reality: someone changed something in the console, or another tool did. Detect it on a schedule:

```sh
# Exit code 0: no changes. 1: error. 2: drift (or unapplied changes).
terraform plan -detailed-exitcode -lock=false -input=false
```

Run it nightly per stack and environment, and alert on exit code 2. Treat drift as an incident to explain, not noise to overwrite: the console change may have been a fix someone made during an outage. Then either bring it into code or reapply. [OPERATIONS.md](OPERATIONS.md#someone-changed-something-outside-terraform-drift) covers both.

## Upgrades

- **Providers**: minor versions monthly or so, with `terraform init -upgrade`, a plan in every environment that should show no changes, and the new lock file in one commit. Majors deliberately, after reading the upgrade guide.
- **Terraform**: one minor at a time, CI first. Read the `UPGRADE NOTES` in [Terraform's changelog](https://github.com/hashicorp/terraform/blob/main/CHANGELOG.md) for each version.
- **Modules**: read the changelog; a new major version can rename resources, which a good module covers with `moved` blocks.

Falling a year behind turns every upgrade into a project. A little every month keeps each step small.

## Reviewing a Terraform change

Read the plan first, then the code.

- [ ] Any `must be replaced` or `destroy`? Is it intended, and is the resource stateless?
- [ ] Does the change count match what the description says it does?
- [ ] New IAM: specific actions, specific resources, conditions where a service is the principal?
- [ ] Anything newly public: security group rules from `0.0.0.0/0`, bucket policies, public endpoints?
- [ ] New variables described, typed, validated where it helps, with safe defaults?
- [ ] Renames covered by `moved` blocks?
- [ ] Tests updated for new conditional behavior?
- [ ] Lock file changed? If so, was a provider upgrade intended?
- [ ] checkov skips: is each reason specific and true?
