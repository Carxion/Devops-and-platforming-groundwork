# 5. Modules

A module is a directory of `.tf` files. Every configuration is one (the **root module**, where you run `terraform`), and a root module can call others (**child modules**) to reuse a group of resources that belong together. This guide walks through the [`s3-bucket`](examples/modules/s3-bucket/) example module and calls it twice.

## Contents

- [When to write a module](#when-to-write-a-module)
- [Anatomy of a module](#anatomy-of-a-module)
- [Call it](#call-it)
- [Module sources and versions](#module-sources-and-versions)
- [Providers in modules](#providers-in-modules)
- [Public modules](#public-modules)
- [Next](#next)

## When to write a module

Write one when a group of resources is used together, in more than one place, with a few things that differ: "a bucket with our security settings", "a queue with its dead-letter queue and alarms". The module hides the twenty settings everyone should get right and exposes the three that legitimately differ.

Don't write one to wrap a single resource with the same arguments under different names, or to make a module of modules before there's a second user. A thin wrapper adds a layer to read through and a version to keep up to date, and buys nothing. The [reference stacks](README.md#whats-here) in this folder are root modules to copy, not modules to call, for that reason.

## Anatomy of a module

Copy the example module into a working directory. `GUIDEBOOK` is the path to your clone of this repository:

<!-- check: output "main.tf" -->
```sh
# in .
mkdir -p modules
cp -r "$GUIDEBOOK/devops/terraform/examples/modules/s3-bucket" modules/
ls modules/s3-bucket
```

```text
modules/s3-bucket/
├── versions.tf      provider requirements: the oldest versions it works with
├── variables.tf     inputs, each with a description, type, and validation where it helps
├── main.tf          resources
├── outputs.tf       what callers can use
├── README.md        how to call it
└── tests/           terraform test, offline with a mock provider
```

`versions.tf` in a module states a **minimum**, not an exact pin. The root module decides the exact version through its own constraints and lock file; a module that pins exactly makes every caller pin the same, and two modules with different pins can't be used together.

<!-- check: matches examples/modules/s3-bucket/versions.tf -->
```hcl
# modules/s3-bucket/versions.tf
terraform {
  # A module states the oldest versions it works with. The root module that
  # calls it pins exact versions through its lock file.
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}
```

Modules have no `provider` blocks. They inherit the caller's provider configuration ([below](#providers-in-modules)), which is how one module works in any region and account.

Inputs are the module's interface. Require what has no safe default, default everything else to the secure choice, and validate what has a known shape:

```hcl
# From modules/s3-bucket/variables.tf
variable "name" {
  description = "Bucket name. Globally unique across all AWS accounts, so include something unique such as the account ID."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.name))
    error_message = "Use 3 to 63 lowercase letters, digits, dots, and hyphens, starting and ending with a letter or digit."
  }
}

variable "force_destroy" {
  description = "Let terraform destroy delete a bucket that still holds objects. Keep false for anything you can't recreate."
  type        = bool
  default     = false
}
```

Inside, resources are usually named `this` when there's one of a kind: the caller already gave the module a meaningful name. Conditionals on inputs choose between settings:

```hcl
# From modules/s3-bucket/main.tf
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn == null ? "AES256" : "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null
  }
}
```

Outputs are the only way out. A caller can't reach `module.bucket.aws_s3_bucket.this`; it gets what the module chooses to return:

<!-- check: matches examples/modules/s3-bucket/outputs.tf -->
```hcl
# modules/s3-bucket/outputs.tf
output "id" {
  # The bucket attribute is the name we passed in, so it's known at plan time,
  # and callers can use it in plans and tests. References still wait for the
  # bucket to exist, because they depend on the resource, not the attribute.
  description = "Bucket name."
  value       = aws_s3_bucket.this.bucket
}

output "arn" {
  description = "Bucket ARN, for IAM policies."
  value       = aws_s3_bucket.this.arn
}
```

Return identifiers callers will need (names, ARNs, URLs), not every attribute. Each output is a promise you'll keep making in every later version.

The module's own tests run offline against a mock provider ([08-testing-and-checks.md](08-testing-and-checks.md)):

<!-- check: output "3 passed, 0 failed" -->
```sh
# in modules/s3-bucket
terraform init
terraform test
```

## Call it

```hcl
# buckets/main.tf
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
}

data "aws_caller_identity" "current" {}

locals {
  # One bucket per entry: short name => days to keep old versions.
  buckets = {
    reports = 30
    uploads = 90
  }
}

module "bucket" {
  source   = "../modules/s3-bucket"
  for_each = local.buckets

  name                               = "guide-${each.key}-${data.aws_caller_identity.current.account_id}"
  noncurrent_version_expiration_days = each.value
  force_destroy                      = true # a throwaway example
}

output "bucket_arns" {
  value = { for key, bucket in module.bucket : key => bucket.arn }
}
```

`source` is a path, so `init` links the module rather than downloading it. `for_each` and `count` work on modules as on resources, and each copy gets its own addresses:

<!-- check: output "Initializing modules" -->
<!-- check: output "module.bucket\[\"reports\"\].aws_s3_bucket.this will be created" -->
<!-- check: output "module.bucket\[\"uploads\"\].aws_s3_bucket_policy.this will be created" -->
<!-- check: output "Plan: 14 to add, 0 to change, 0 to destroy" -->
```sh
# in buckets
terraform init
terraform plan
```

Fourteen resources, seven per bucket, from one block. Every bucket gets the same encryption, public access block, TLS-only policy, and lifecycle rule; no one can forget one.

<!-- check: output "Apply complete! Resources: 14 added" -->
<!-- check: output "reports\" = \"arn:aws:s3:::guide-reports-" -->
<!-- check: output "Destroy complete! Resources: 14 destroyed" -->
```sh
# in buckets
terraform apply
terraform output bucket_arns
terraform destroy
```

Moving existing resources into a module changes their addresses; add `moved` blocks ([04-state.md](04-state.md#rename-without-destroying-moved)) so the plan shows moves, not replacements:

```hcl
# Was a plain resource; now inside the module.
moved {
  from = aws_s3_bucket.uploads
  to   = module.bucket["uploads"].aws_s3_bucket.this
}
```

## Module sources and versions

```hcl
# Local path: same repository, versioned with the caller.
module "a" {
  source = "../modules/s3-bucket"
}

# Terraform Registry: version constraint required in practice.
module "b" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 5.0"
}

# Git: pin a tag, or better, a commit.
module "c" {
  source = "git::https://gitlab.example.com/platform/terraform-modules.git//s3-bucket?ref=v1.4.0"
}
```

- **Local paths** for modules used only by this repository. They change with the code that calls them, in the same review.
- **A registry** (public, or private in GitLab, Terraform Cloud, or Artifactory) for modules shared across repositories. `version` is honored only for registry sources.
- **Git** with `?ref=` when there's no registry. A tag can be moved; a commit SHA can't.

Release shared modules with semantic versions and a changelog, and treat removing an input or output as a breaking change.

## Providers in modules

A child module uses the caller's default provider configuration unless told otherwise. To run a module in another region or account, pass an aliased provider:

```hcl
# The module's "aws" is the caller's "aws.west".
module "replica" {
  source = "../modules/s3-bucket"

  providers = {
    aws = aws.west
  }

  name = "guide-replica-123456789012"
}
```

A module that needs two configurations at once (copying between regions, for example) declares them with `configuration_aliases` in its `required_providers`, and the caller passes both.

## Public modules

The Registry's [terraform-aws-modules](https://registry.terraform.io/namespaces/terraform-aws-modules) collection covers most AWS services and is widely used. Before adopting a public module:

- Read the code. It's a dependency that creates resources in your account with your apply role.
- Check it's maintained: recent releases, issues answered, support for your provider major version.
- Pin the version, and review its changelog when you upgrade, as you would a library.
- Weigh it against writing the twenty lines yourself. Large general-purpose modules expose hundreds of inputs; your use needs a few.

## Next

[06-building-a-stack.md](06-building-a-stack.md): putting it all together, one step at a time.
