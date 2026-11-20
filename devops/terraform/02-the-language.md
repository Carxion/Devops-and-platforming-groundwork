# 2. The language

Terraform configuration is written in HCL. It looks like a data format, and mostly is: blocks, arguments, and values. The parts that make it a language are expressions (references, functions, conditionals, `for`) and the meta-arguments that make one block into many resources.

## Contents

- [Blocks and arguments](#blocks-and-arguments)
- [Types](#types)
- [Variables](#variables)
- [Locals](#locals)
- [Outputs](#outputs)
- [Expressions](#expressions)
- [Try expressions in the console](#try-expressions-in-the-console)
- [Validation stops bad input before the API does](#validation-stops-bad-input-before-the-api-does)
- [Many resources from one block: count and for_each](#many-resources-from-one-block-count-and-for_each)
- [Why for_each beats count for lists of things](#why-for_each-beats-count-for-lists-of-things)
- [Data sources](#data-sources)
- [Next](#next)

## Blocks and arguments

```hcl
# A block has a type, zero or more labels, and a body in braces.
resource "aws_sqs_queue" "jobs" {
  name = "jobs" # an argument: name = expression

  tags = { # a map value
    Team = "platform"
  }
}
```

The top-level block types you'll use:

| Block | Purpose |
|---|---|
| `terraform` | Terraform and provider versions, the backend |
| `provider` | Provider settings, such as the AWS region |
| `resource` | Something Terraform creates and manages |
| `data` | Something Terraform only reads |
| `variable` | An input |
| `locals` | Named values computed inside the module |
| `output` | A value the module returns |
| `module` | A call to another module ([05-modules.md](05-modules.md)) |

Run `terraform fmt` before every commit. It fixes indentation and lines up the `=` signs, and CI should fail on unformatted code (`terraform fmt -check -recursive`).

## Types

| Type | Example |
|---|---|
| `string` | `"us-east-1"`, `"${var.project}-queue"` |
| `number` | `30`, `0.5` |
| `bool` | `true` |
| `list(string)` | `["a", "b"]`: ordered, duplicates allowed |
| `set(string)` | `toset(["a", "b"])`: unordered, unique |
| `map(string)` | `{ Team = "platform" }`: string keys, all values one type |
| `object({...})` | `{ name = "jobs", retries = 3 }`: fixed attributes, each its own type |
| `tuple([...])` | `["a", 1, true]`: fixed length, each element its own type |

`null` means "not set": an argument set to `null` behaves as if you'd left it out, which is how a module passes through an optional value.

## Variables

```hcl
# variables.tf
variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Use dev, staging, or prod."
  }
}

variable "db_password" {
  description = "Never printed in plans or output; still stored in state."
  type        = string
  sensitive   = true
}
```

Give every variable a `description` and a `type`. A variable without a default is required. Set values, from lowest to highest precedence, with: the default, a `terraform.tfvars` file, `*.auto.tfvars` files, `-var-file=dev.tfvars`, `TF_VAR_environment=prod` in the environment, and `-var environment=prod` on the command line. Pick one way per stack: a `.tfvars` file per environment is the easiest to review.

`sensitive = true` hides the value in plans and output, but it is still written to state in plain text. [07-advanced-language.md](07-advanced-language.md#ephemeral-values-and-write-only-arguments) shows how to keep secrets out of state altogether.

## Locals

Locals name an expression so you write it once:

```hcl
# main.tf
locals {
  name = "${var.project}-${var.environment}"

  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
  })
}
```

Refer to them as `local.name` (singular, though the block is `locals`). Use them for anything you'd otherwise repeat; don't use them to rename a variable for no reason.

## Outputs

```hcl
# outputs.tf
output "queue_url" {
  description = "The queue the worker polls."
  value       = aws_sqs_queue.jobs.url
}
```

Outputs print after `apply`, answer `terraform output`, and are how a module returns values to its caller. Mark an output `sensitive = true` if its value is.

## Expressions

```hcl
# Expressions, all valid wherever a value goes.
locals {
  # References
  region_from_var = var.region
  queue_arn       = aws_sqs_queue.jobs.arn

  # String templates
  bucket_name = "${var.project}-${var.environment}-uploads"

  # Conditionals: condition ? if_true : if_false
  retention = var.environment == "prod" ? 1209600 : 345600

  # for over a list makes a list; over a map, with => makes a map
  upper_names = [for n in var.names : upper(n)]
  by_name     = { for q in var.queues : q.name => q }

  # for with if filters
  long_running = [for q in var.queues : q.name if q.timeout > 60]

  # Splat: an attribute from every element
  all_arns = aws_sqs_queue.many[*].arn
}
```

Terraform has [built-in functions](https://developer.hashicorp.com/terraform/language/functions) for strings (`format`, `replace`, `trimsuffix`), collections (`merge`, `concat`, `flatten`, `lookup`, `keys`), encoding (`jsonencode`, `yamldecode`, `base64encode`), files (`file`, `templatefile`), and networking (`cidrsubnet`). You can't write your own; when an expression gets hard to read, split it into locals.

## Try expressions in the console

`terraform console` evaluates expressions against a configuration, which is the quickest way to learn them. Create a configuration with no resources:

```hcl
# lang/main.tf
variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Use dev, staging, or prod."
  }
}

variable "queues" {
  description = "Queues to create, keyed by short name."
  type = map(object({
    visibility_timeout = optional(number, 30)
    fifo               = optional(bool, false)
  }))
  default = {
    orders   = {}
    invoices = { visibility_timeout = 120 }
    payments = { fifo = true }
  }
}

locals {
  prefix = "shop-${var.environment}"

  queue_names = {
    for key, q in var.queues : key => "${local.prefix}-${key}${q.fifo ? ".fifo" : ""}"
  }

  slow_queues = [for key, q in var.queues : key if q.visibility_timeout > 60]
}

output "queue_names" {
  value = local.queue_names
}
```

`optional(number, 30)` lets callers leave an attribute out and get the default. Now ask the console:

<!-- check: output "\"payments\" = \"shop-dev-payments.fifo\"" -->
<!-- check: output "\"invoices\"" -->
<!-- check: output "10.0.16.0/20" -->
```sh
# in lang
terraform init
echo 'local.queue_names' | terraform console
echo 'local.slow_queues' | terraform console
echo 'cidrsubnet("10.0.0.0/16", 4, 1)' | terraform console
```

Maps iterate in key order, so `invoices` comes before `orders` whatever order you wrote them in.

## Validation stops bad input before the API does

<!-- check: fails -->
<!-- check: output "Invalid value for variable" -->
<!-- check: output "Use dev, staging, or prod" -->
```sh
# in lang
terraform plan -var environment=qa
```

A validation failure stops the plan before any API call. Validate anything with a known shape: names, CIDRs, enumerations. It's far cheaper than a failed apply halfway through.

## Many resources from one block: count and for_each

`count` makes N copies, addressed by number: `aws_sqs_queue.worker[0]`. `for_each` makes one per key of a map or set, addressed by key: `aws_sqs_queue.this["orders"]`. Inside the block, `count.index` or `each.key` and `each.value` tell the copies apart.

```hcl
# queues/versions.tf
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
```

```hcl
# queues/main.tf
variable "queues" {
  description = "Queues to create: short name => visibility timeout in seconds."
  type        = map(number)
  default = {
    orders   = 30
    invoices = 120
    payments = 30
  }
}

resource "aws_sqs_queue" "this" {
  for_each = var.queues

  name                       = "shop-${each.key}"
  visibility_timeout_seconds = each.value
}

output "queue_urls" {
  value = { for key, q in aws_sqs_queue.this : key => q.url }
}
```

<!-- check: output "aws_sqs_queue.this\[\"invoices\"\]: Creation complete" -->
<!-- check: output "Resources: 3 added" -->
```sh
# in queues
terraform init
terraform apply
```

Remove `invoices` from the map:

```hcl
# queues/main.tf
variable "queues" {
  description = "Queues to create: short name => visibility timeout in seconds."
  type        = map(number)
  default = {
    orders   = 30
    payments = 30
  }
}

resource "aws_sqs_queue" "this" {
  for_each = var.queues

  name                       = "shop-${each.key}"
  visibility_timeout_seconds = each.value
}

output "queue_urls" {
  value = { for key, q in aws_sqs_queue.this : key => q.url }
}
```

<!-- check: output "aws_sqs_queue.this\[\"invoices\"\] will be destroyed" -->
<!-- check: output "Plan: 0 to add, 0 to change, 1 to destroy" -->
```sh
# in queues
terraform plan
```

Only `invoices` goes; `orders` and `payments` are untouched, because their keys didn't change.

## Why for_each beats count for lists of things

Here is the same thing with `count` over a list:

```hcl
# queues/main.tf
variable "queue_names" {
  description = "Queues to create."
  type        = list(string)
  default     = ["invoices", "orders", "payments"]
}

resource "aws_sqs_queue" "this" {
  count = length(var.queue_names)

  name = "shop-${var.queue_names[count.index]}"
}
```

<!-- check: output "Destroy complete" -->
<!-- check: output "Apply complete! Resources: 3 added" -->
```sh
# in queues
terraform destroy
terraform apply
```

Remove `invoices`, the first element:

```hcl
# queues/main.tf
variable "queue_names" {
  description = "Queues to create."
  type        = list(string)
  default     = ["orders", "payments"]
}

resource "aws_sqs_queue" "this" {
  count = length(var.queue_names)

  name = "shop-${var.queue_names[count.index]}"
}
```

<!-- check: output "aws_sqs_queue.this\[0\] must be replaced" -->
<!-- check: output "aws_sqs_queue.this\[1\] must be replaced" -->
<!-- check: output "Plan: 2 to add, 0 to change, 3 to destroy" -->
```sh
# in queues
terraform plan
```

Every element after the removed one shifts down an index, so `[0]` becomes `orders` and `[1]` becomes `payments`: Terraform replaces both, and deletes `[2]`. Three queues destroyed to remove one. Use `count` only for "zero or one" (`count = var.enabled ? 1 : 0`) or truly identical copies; use `for_each` for anything with an identity.

`for_each` keys must be known at plan time. A key built from something only AWS knows, such as a generated ID, fails with `Invalid for_each argument`; build keys from your own input instead ([OPERATIONS.md](OPERATIONS.md#invalid-for_each-argument--invalid-count-argument)).

<!-- check: output "Destroy complete" -->
```sh
# in queues
terraform destroy
```

## Data sources

A `data` block reads something that already exists, managed elsewhere or by AWS itself:

```hcl
# Look things up instead of hard-coding them.
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "read" {
  statement {
    actions   = ["sqs:ReceiveMessage"]
    resources = [aws_sqs_queue.jobs.arn]
  }
}

locals {
  account_id = data.aws_caller_identity.current.account_id
}
```

Data sources are read during plan, unless they depend on something not created yet, in which case they're read during apply. [03-the-aws-provider.md](03-the-aws-provider.md#data-sources-you-will-use-everywhere) lists the AWS ones you'll use in most stacks.

## Next

[03-the-aws-provider.md](03-the-aws-provider.md): credentials, regions, default tags, more than one region or account, and IAM policies.
