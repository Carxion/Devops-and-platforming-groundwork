# 3. The AWS provider

The `hashicorp/aws` provider turns resource blocks into AWS API calls. This guide covers how it finds credentials, how to make sure it's talking to the account you think it is, tags on everything, working in more than one region or account, and writing IAM policies.

## Contents

- [Pin it](#pin-it)
- [Credentials](#credentials)
- [Guard the account](#guard-the-account)
- [Default tags](#default-tags)
- [Data sources you will use everywhere](#data-sources-you-will-use-everywhere)
- [More than one region or account: aliases](#more-than-one-region-or-account-aliases)
- [IAM policies](#iam-policies)
- [Names, eventual consistency, and timeouts](#names-eventual-consistency-and-timeouts)
- [Reading the provider documentation](#reading-the-provider-documentation)
- [Next](#next)

## Pin it

```hcl
# Root module: pin the major version; the lock file pins the exact build.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.68"
    }
  }
}
```

Major versions remove and rename things: 4.0 split `aws_s3_bucket` into separate resources for versioning, encryption, and the rest; 6.0 added a per-resource `region` argument and changed several defaults. Read the [upgrade guide](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/version-6-upgrade) before moving to a new major version, and upgrade minors regularly with `terraform init -upgrade` so you're never many releases behind.

## Credentials

The provider looks for credentials in the same places as the AWS CLI and SDKs, in this order (the provider docs' [authentication section](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)):

1. Arguments in the `provider` block (don't: they end up in Git).
2. Environment variables: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, or `AWS_PROFILE`.
3. The shared config and credentials files (`~/.aws/config`), including IAM Identity Center (SSO) profiles.
4. Container and instance credentials: ECS task roles, EC2 instance profiles, EKS pod identity.

Keep credentials out of the configuration entirely. Day to day:

| Where | Use |
|---|---|
| Your laptop | An IAM Identity Center profile: `aws sso login --profile sandbox`, then `export AWS_PROFILE=sandbox` |
| A pipeline | OIDC: the CI system's identity token is exchanged for a short-lived role session. The [`gitlab-oidc`](aws/gitlab-oidc/) and [`github-oidc`](aws/github-oidc/) stacks create the roles |
| A runner in AWS | The task or instance role |

Long-lived access keys are the most common way AWS accounts get breached. If a tool insists on them, use them for a sandbox only.

The provider can also assume a role itself, which is how one set of credentials reaches several accounts:

```hcl
# The caller's credentials are only used to assume this role.
provider "aws" {
  region = "us-east-1"

  assume_role {
    role_arn     = "arn:aws:iam::111111111111:role/terraform-apply"
    session_name = "terraform"
  }
}
```

## Guard the account

The easiest way to damage production is to run a plan with the wrong profile active. `allowed_account_ids` makes the provider refuse to do anything in any other account:

```hcl
# guard/main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.68"
    }
  }
}

provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = ["111111111111"] # the sandbox account, and nothing else
}

resource "aws_sqs_queue" "jobs" {
  name = "guarded-jobs"
}
```

<!-- check: fails -->
<!-- check: output "AWS account ID not allowed" -->
```sh
# in guard
terraform init
terraform plan
```

The credentials here belong to a different account (`123456789012`), so the plan stops before reading or changing anything. Put the account ID in every environment's configuration; it costs one line and turns "oops, that was prod" into an error message.

## Default tags

`default_tags` adds tags to every resource the provider creates that supports them, so no one has to remember:

```hcl
# provider/versions.tf
terraform {
  required_version = "~> 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.68"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = "shop"
      Owner     = "platform-team"
      ManagedBy = "terraform"
    }
  }
}

# Same account, second region: see "aliases" below.
provider "aws" {
  alias  = "west"
  region = "us-west-2"

  default_tags {
    tags = {
      Project   = "shop"
      Owner     = "platform-team"
      ManagedBy = "terraform"
    }
  }
}
```

Each resource shows the merged result in `tags_all`; its own `tags` win when a key is in both. Tag for ownership and cost: `Owner`, `Project`, `Environment`, and `ManagedBy` answer most "whose is this?" questions, and you can turn on [cost allocation tags](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/cost-alloc-tags.html) for them in Billing.

## Data sources you will use everywhere

```hcl
# provider/main.tf
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  # "aws", or "aws-us-gov" and "aws-cn" in other partitions. Build ARNs with it.
  partition = data.aws_partition.current.partition
}

resource "aws_sqs_queue" "east" {
  name = "shop-orders"
}

resource "aws_sqs_queue" "west" {
  provider = aws.west
  name     = "shop-orders"
}

# Provider 6.0 and later: a per-resource region, same account and credentials.
resource "aws_sqs_queue" "europe" {
  region = "eu-west-1"
  name   = "shop-orders"
}

output "account_id" {
  value = local.account_id
}

output "where" {
  value = {
    provider_region = data.aws_region.current.region
    east            = aws_sqs_queue.east.arn
    west            = aws_sqs_queue.west.arn
    europe          = aws_sqs_queue.europe.arn
  }
}

output "zones" {
  value = data.aws_availability_zones.available.names
}

output "role_arn_pattern" {
  value = "arn:${local.partition}:iam::${local.account_id}:role/example"
}
```

| Data source | Gives you |
|---|---|
| `aws_caller_identity` | The account ID and ARN of the credentials in use |
| `aws_partition` | `aws`, `aws-us-gov`, or `aws-cn`, for building ARNs that work everywhere |
| `aws_region` | The provider's region (`.region`) |
| `aws_availability_zones` | The zones open to this account in the region |
| `aws_iam_policy_document` | A policy as HCL, rendered to JSON ([below](#iam-policies)) |

<!-- check: output "arn:aws:sqs:us-east-1:123456789012:shop-orders" -->
<!-- check: output "arn:aws:sqs:us-west-2:123456789012:shop-orders" -->
<!-- check: output "arn:aws:sqs:eu-west-1:123456789012:shop-orders" -->
<!-- check: output "provider_region = \"us-east-1\"" -->
<!-- check: output "us-east-1a" -->
```sh
# in provider
terraform init
terraform apply
```

Hard-coded account IDs, regions, and `arn:aws:` prefixes are the usual reason a stack works in one account and not the next. Look them up.

## More than one region or account: aliases

A second `provider "aws"` block with an `alias` is a second configuration of the same provider: another region, or another account through `assume_role`. A resource uses it with `provider = aws.west`; a module gets it through `providers = { aws = aws.west }`. The `west` queue above is in us-west-2 that way.

Since provider 6.0, most resources also take a `region` argument directly, which saves an alias when only the region differs: the `europe` queue above is in eu-west-1 through the same provider configuration.

Use an alias when the account or credentials differ, and `region` when only the region does. Either way, keep cross-region and cross-account stacks rare: each extra provider is another set of permissions the pipeline needs.

<!-- check: output "Destroy complete! Resources: 3 destroyed" -->
```sh
# in provider
terraform destroy
```

## IAM policies

Write policies with the `aws_iam_policy_document` data source rather than JSON strings:

```hcl
# The consumer may read uploads and work its queue, and nothing else.
data "aws_iam_policy_document" "consumer" {
  statement {
    sid       = "ReadUploads"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.uploads.arn}/incoming/*"]
  }

  statement {
    sid       = "WorkTheQueue"
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
    resources = [aws_sqs_queue.uploads.arn]
  }
}

resource "aws_iam_role_policy" "consumer" {
  name   = "uploads"
  role   = aws_iam_role.consumer.id
  policy = data.aws_iam_policy_document.consumer.json
}
```

It's checked by `terraform validate`, it formats with everything else, it can loop with `dynamic "statement"`, and documents combine with `source_policy_documents`. `jsonencode({...})` is fine for a short policy; a heredoc of raw JSON is the one to avoid, because nothing checks it until AWS rejects it.

Least privilege in practice: name the actions (no `"sqs:*"`), name the resources (no `"*"` where an ARN is known), and add conditions such as `aws:SourceArn` and `aws:SourceAccount` on anything a service assumes or sends to. [06-building-a-stack.md](06-building-a-stack.md) uses all three.

## Names, eventual consistency, and timeouts

- **Global names.** S3 bucket names are unique across every AWS account. Include the account ID and region, or use `bucket_prefix` and let AWS add a suffix.
- **Name changes replace.** Most AWS resources can't be renamed, so changing `name` destroys and re-creates. Decide on a naming scheme before the first apply.
- **Eventual consistency.** IAM changes take seconds to reach every region. The provider retries the common cases; when an apply fails with "role cannot be assumed" or "invalid principal" just after creating that role, run it again, and see [OPERATIONS.md](OPERATIONS.md#eventual-consistency-and-retries).
- **Timeouts.** Slow resources (databases, EKS clusters, CloudFront) accept a `timeouts` block when the default isn't enough.

## Reading the provider documentation

Every resource page in the [Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) has the same sections: example usage, **argument reference** (what you set; note which ones say "forces new resource"), **attribute reference** (what you can read back), and **import** (the ID format). Check the page for the version you've pinned, from the version selector at the top; arguments change between majors.

When a page and reality disagree, the provider schema wins: `terraform providers schema -json` prints exactly what your installed version accepts.

## Next

[04-state.md](04-state.md): remote state in S3, locking, and changing state without destroying anything.
