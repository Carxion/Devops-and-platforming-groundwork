# 6. Building a stack

This guide builds the [`uploads`](examples/uploads/) example from an empty directory, one file at a time, planning and applying after each step. It's how to build any stack: decide what it's for, pin versions, define inputs, add resources in dependency order, and check each step before the next.

```text
client ──PUT──► S3 bucket ──event──► SQS queue ──► consumer (IAM role)
                                         │
                                         └──after N failures──► dead-letter queue
```

A client uploads a file under `incoming/`; S3 puts a message on a queue; a consumer, running as its own IAM role, reads the message and the file. Messages the consumer fails on five times move to a dead-letter queue, where someone can look at them instead of losing them.

## Contents

- [1. Decide before you write](#1-decide-before-you-write)
- [2. Lay out the directory](#2-lay-out-the-directory)
- [3. Pin versions and configure the provider](#3-pin-versions-and-configure-the-provider)
- [4. Define the inputs](#4-define-the-inputs)
- [5. Names, tags, and the bucket](#5-names-tags-and-the-bucket)
- [6. Initialize against remote state and apply](#6-initialize-against-remote-state-and-apply)
- [7. The queues and the event](#7-the-queues-and-the-event)
- [8. The consumer's role](#8-the-consumers-role)
- [9. Outputs](#9-outputs)
- [10. Tests](#10-tests)
- [11. Change it](#11-change-it)
- [12. Before you commit](#12-before-you-commit)
- [13. Clean up](#13-clean-up)

## 1. Decide before you write

Settle these first. Each is cheap to decide now and expensive to change after the first apply.

| Decision | Here |
|---|---|
| What the stack owns, and what it doesn't | The bucket, queues, notification, and consumer role. Not the consumer itself (a separate deployment), not the network. |
| Lifecycle | Changes when the upload flow changes; separate from the app that consumes it, which deploys daily. |
| Names | `<project>-<environment>-uploads...`. Most of these can't be renamed without replacement. |
| Inputs | Project, environment, region, owner, prefixes, and the few tuning knobs. Everything else is a fixed, secure default. |
| State | One key per environment in the state bucket from [04-state.md](04-state.md#create-a-state-bucket). |
| Blast radius | A mistake here can lose uploads. The bucket is versioned, and `force_destroy` defaults to false. |

## 2. Lay out the directory

```text
modules/s3-bucket/     the module from 05-modules.md
uploads/
├── versions.tf        Terraform and provider versions, backend, provider
├── variables.tf       inputs
├── main.tf            names, tags, the bucket
├── queue.tf           queues and the bucket notification
├── consumer.tf        the consumer's role
├── outputs.tf         what other stacks and people need
├── terraform.tfvars   this environment's inputs (not committed)
├── backend.hcl        this environment's state location (not committed)
└── tests/             terraform test
```

Terraform doesn't care how resources are spread across files. Split by concern when `main.tf` gets long, so a reviewer can find things.

<!-- check: output "s3-bucket" -->
```sh
# in .
mkdir -p modules uploads
cp -r "$GUIDEBOOK/devops/terraform/examples/modules/s3-bucket" modules/
ls modules
```

## 3. Pin versions and configure the provider

<!-- check: matches examples/uploads/versions.tf -->
```hcl
# uploads/versions.tf
terraform {
  required_version = "~> 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.68"
    }
  }

  # Partial configuration: terraform init -backend-config=backend.hcl
  backend "s3" {}
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}
```

The provider's region comes from a variable and its default tags from a local, so every environment shares this file.

## 4. Define the inputs

<!-- check: matches examples/uploads/variables.tf -->
```hcl
# uploads/variables.tf
variable "project" {
  description = "Short project name, used as a prefix for resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,19}$", var.project))
    error_message = "Use 2 to 20 lowercase letters, digits, and hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Environment name, for example dev, staging, or prod."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Use dev, staging, or prod."
  }
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "owner" {
  description = "Team accountable for these resources (Owner tag)."
  type        = string
}

variable "tags" {
  description = "Extra tags applied to every resource."
  type        = map(string)
  default     = {}
}

variable "upload_prefixes" {
  description = "Key prefixes that send an event to the queue when an object is created, for example [\"incoming/\"]."
  type        = set(string)
  default     = ["incoming/"]

  validation {
    condition     = length(var.upload_prefixes) > 0 && alltrue([for p in var.upload_prefixes : endswith(p, "/")])
    error_message = "List at least one prefix, and end each with a slash."
  }
}

variable "consumer_service" {
  description = "AWS service that runs the consumer and assumes its role, for example ecs-tasks.amazonaws.com or lambda.amazonaws.com."
  type        = string
  default     = "ecs-tasks.amazonaws.com"
}

variable "visibility_timeout_seconds" {
  description = "How long a received message stays hidden from other consumers. Set it longer than the consumer takes to process one upload."
  type        = number
  default     = 60
}

variable "max_receive_count" {
  description = "Receives before a message moves to the dead-letter queue."
  type        = number
  default     = 5

  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000
    error_message = "SQS allows 1 to 1000."
  }
}

variable "force_destroy" {
  description = "Let terraform destroy delete the bucket while it still holds uploads. Only for throwaway environments."
  type        = bool
  default     = false
}
```

Four required inputs; everything else has a default that's safe for production. `upload_prefixes` is a `set`, because order means nothing and duplicates would be an error; the validation catches a missing slash, which S3 would otherwise accept and match against `incomingfoo.txt`.

## 5. Names, tags, and the bucket

<!-- check: matches examples/uploads/main.tf -->
```hcl
# uploads/main.tf
# Uploads: a private bucket that puts a message on an SQS queue for every new
# object under the configured prefixes, a dead-letter queue for messages the
# consumer keeps failing on, and an IAM role the consumer runs as.
#
#   client ──PUT──► S3 bucket ──event──► SQS queue ──► consumer (IAM role)
#                                            │
#                                            └──after N failures──► DLQ
#
#   main.tf      names, tags, and the bucket
#   queue.tf     the queues and the bucket's event notifications
#   consumer.tf  the consumer's IAM role
#
# 06-building-a-stack.md builds these files one step at a time.

data "aws_caller_identity" "current" {}

locals {
  name       = "${var.project}-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id

  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
    Stack       = "uploads"
  })
}

module "bucket" {
  source = "../modules/s3-bucket"

  # Bucket names are global; the account ID and region make this one unique.
  name          = "${local.name}-uploads-${local.account_id}-${var.region}"
  force_destroy = var.force_destroy
}
```

Start every file that does something non-obvious with a comment that says what and why; the code says how.

## 6. Initialize against remote state and apply

Write this environment's inputs and state location:

<!-- check: matches examples/uploads/terraform.tfvars.example -->
```hcl
# uploads/terraform.tfvars
project     = "example"
environment = "dev"
region      = "us-east-1"
owner       = "platform-team"

upload_prefixes = ["incoming/", "imports/"]

# Throwaway environments only: lets terraform destroy remove a bucket that
# still holds uploads.
force_destroy = true
```

`terraform.tfvars` is loaded automatically. With one file per environment, name them `dev.tfvars` and `prod.tfvars` and pass `-var-file=dev.tfvars`.

<!-- check: output "Successfully configured the backend \"s3\"" -->
<!-- check: output "Initializing modules" -->
<!-- check: output "module.bucket.aws_s3_bucket.this will be created" -->
<!-- check: output "Plan: 7 to add, 0 to change, 0 to destroy" -->
```sh
# in uploads
cat > backend.hcl <<EOF
bucket       = "$(terraform -chdir=../bootstrap output -raw state_bucket)"
key          = "uploads/dev/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true
EOF
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -out=tfplan
```

Save the plan to a file, read it, then apply exactly that file. Between a plain `plan` and `apply`, someone else's change could land; a saved plan fails to apply if state moved underneath it.

<!-- check: output "Apply complete! Resources: 7 added" -->
```sh
# in uploads
terraform apply tfplan
```

## 7. The queues and the event

<!-- check: matches examples/uploads/queue.tf -->
```hcl
# uploads/queue.tf
resource "aws_sqs_queue" "dead_letter" {
  name                      = "${local.name}-uploads-dlq"
  message_retention_seconds = 1209600 # 14 days, the SQS maximum
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "uploads" {
  name                       = "${local.name}-uploads"
  visibility_timeout_seconds = var.visibility_timeout_seconds
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter.arn
    maxReceiveCount     = var.max_receive_count
  })
}

# Only this bucket, in this account, may send to the queue.
data "aws_iam_policy_document" "queue" {
  statement {
    sid       = "AllowBucketEvents"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.uploads.arn]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [module.bucket.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_sqs_queue_policy" "uploads" {
  queue_url = aws_sqs_queue.uploads.id
  policy    = data.aws_iam_policy_document.queue.json
}

resource "aws_s3_bucket_notification" "uploads" {
  bucket = module.bucket.id

  dynamic "queue" {
    for_each = var.upload_prefixes

    content {
      id            = "created-${trimsuffix(queue.value, "/")}"
      queue_arn     = aws_sqs_queue.uploads.arn
      events        = ["s3:ObjectCreated:*"]
      filter_prefix = queue.value
    }
  }

  # S3 sends a test message when the notification is saved, and rejects the
  # configuration if the queue policy doesn't allow it yet.
  depends_on = [aws_sqs_queue_policy.uploads]
}
```

What to notice:

- **References set the order.** The queue refers to the dead-letter queue's ARN, so Terraform creates the dead-letter queue first. You never list the order yourself.
- **`depends_on` only for what references can't show.** The notification doesn't refer to the queue policy, but S3 checks the policy when the notification is saved. That hidden dependency is the one place `depends_on` belongs.
- **`dynamic` makes one nested block per prefix**, the nested-block version of `for_each` ([07-advanced-language.md](07-advanced-language.md#dynamic-blocks)).
- **The queue policy is scoped** to this bucket and this account with `aws:SourceArn` and `aws:SourceAccount`, so no other bucket can send to it.

<!-- check: output "aws_sqs_queue.dead_letter will be created" -->
<!-- check: output "Plan: 4 to add, \d+ to change, 0 to destroy" -->
<!-- check: output "Apply complete! Resources: 4 added" -->
```sh
# in uploads
terraform plan -out=tfplan
terraform apply tfplan
```

Try it: upload a file and read the message S3 sends.

<!-- check: moto-skip "moto denies every request under the module's TLS-only bucket policy; tests/check.py checks this flow on the examples with that policy removed" -->
```sh
# in uploads
echo hello > hello.txt
aws s3 cp hello.txt "s3://$(terraform output -raw bucket_name)/incoming/hello.txt"
aws sqs receive-message --queue-url "$(terraform output -raw queue_url)" --wait-time-seconds 10
```

The first message may be `s3:TestEvent`, which S3 sends when the notification is created; receive again for the `ObjectCreated:Put` record with your key. (The outputs come in step 9; until then, use the bucket and queue names from the plan.)

## 8. The consumer's role

<!-- check: matches examples/uploads/consumer.tf -->
```hcl
# uploads/consumer.tf
data "aws_iam_policy_document" "consumer_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = [var.consumer_service]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "consumer" {
  name               = "${local.name}-uploads-consumer"
  assume_role_policy = data.aws_iam_policy_document.consumer_assume.json
}

# Read uploads and work the queue; nothing else.
data "aws_iam_policy_document" "consumer" {
  statement {
    sid       = "ReadUploads"
    actions   = ["s3:GetObject"]
    resources = [for p in var.upload_prefixes : "${module.bucket.arn}/${p}*"]
  }

  statement {
    sid = "WorkTheQueue"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:GetQueueAttributes",
    ]
    resources = [aws_sqs_queue.uploads.arn]
  }
}

resource "aws_iam_role_policy" "consumer" {
  name   = "uploads"
  role   = aws_iam_role.consumer.id
  policy = data.aws_iam_policy_document.consumer.json
}
```

The consumer can read objects under the upload prefixes and receive, delete, and extend messages on one queue. It can't list the bucket, write to it, or touch the dead-letter queue: replaying dead letters is a person's decision.

<!-- check: output "aws_iam_role.consumer will be created" -->
<!-- check: output "Apply complete! Resources: 2 added" -->
```sh
# in uploads
terraform plan -out=tfplan
terraform apply tfplan
```

## 9. Outputs

<!-- check: matches examples/uploads/outputs.tf -->
```hcl
# uploads/outputs.tf
output "bucket_name" {
  description = "Where clients upload."
  value       = module.bucket.id
}

output "queue_url" {
  description = "The queue the consumer polls."
  value       = aws_sqs_queue.uploads.id
}

output "dead_letter_queue_url" {
  description = "Messages the consumer failed on max_receive_count times. Alarm on its depth."
  value       = aws_sqs_queue.dead_letter.id
}

output "consumer_role_arn" {
  description = "Role to run the consumer as."
  value       = aws_iam_role.consumer.arn
}
```

<!-- check: output "bucket_name = \"example-dev-uploads-123456789012-us-east-1\"" -->
<!-- check: output "consumer_role_arn = \"arn:aws:iam::123456789012:role/example-dev-uploads-consumer\"" -->
```sh
# in uploads
terraform apply
terraform output
```

Output only what another stack, a pipeline, or a person needs: the consumer's deployment needs the queue URL and the role ARN; nobody needs the lifecycle rule's ID.

## 10. Tests

Take the example's offline tests and run them:

<!-- check: output "5 passed, 0 failed" -->
```sh
# in uploads
mkdir -p tests
cp "$GUIDEBOOK/devops/terraform/examples/uploads/tests/plan.tftest.hcl" tests/
terraform test -filter=tests/plan.tftest.hcl
```

They plan against a mock provider, so they need no credentials and finish in seconds, and they check the decisions from step 1: names, the redrive policy, one notification per prefix, and that bad input is rejected. [08-testing-and-checks.md](08-testing-and-checks.md) explains how to write them.

## 11. Change it

Add a prefix:

```hcl
# uploads/terraform.tfvars
project     = "example"
environment = "dev"
region      = "us-east-1"
owner       = "platform-team"

upload_prefixes = ["incoming/", "imports/", "partners/"]

force_destroy = true
```

<!-- check: output "aws_s3_bucket_notification.uploads will be updated in-place" -->
<!-- check: output "aws_iam_role_policy.consumer will be updated in-place" -->
<!-- check: output "Plan: 0 to add, \d+ to change, 0 to destroy" -->
```sh
# in uploads
terraform plan -out=tfplan
```

Only in-place updates: the notification gains a rule, and the consumer's policy gains a resource. Nothing is added, replaced, or destroyed. That's what a reviewer wants to see before approving.

<!-- check: output "Apply complete! Resources: 0 added, \d+ changed, 0 destroyed" -->
```sh
# in uploads
terraform apply tfplan
```

## 12. Before you commit

- `terraform fmt -recursive` and `terraform validate` pass.
- `.terraform.lock.hcl` is committed, with hashes for every platform that will run it, or a Linux pipeline running `init -lockfile=readonly` rejects it:

<!-- check: output "Obtained hashicorp/aws checksums for linux_amd64" -->
<!-- check: output "Obtained hashicorp/aws checksums for windows_amd64" -->
```sh
# in uploads
terraform providers lock \
  -platform=linux_amd64 -platform=linux_arm64 \
  -platform=darwin_amd64 -platform=darwin_arm64 -platform=windows_amd64
```

- `.terraform/`, `*.tfstate*`, `*.tfplan`, `tfplan`, `terraform.tfvars`, and `backend.hcl` are in `.gitignore` (commit `.example` copies instead).
- The tests pass, and tflint and checkov are clean ([08-testing-and-checks.md](08-testing-and-checks.md)).
- The merge request includes the plan output.

## 13. Clean up

<!-- check: output "Destroy complete!" -->
<!-- check: output "^0$" -->
```sh
# in uploads
terraform destroy
terraform state list | wc -l
```

`force_destroy = true` in this environment's tfvars lets the bucket go with objects in it. In production it stays false, and `destroy` fails on a non-empty bucket, which is the point.

The state bucket from [04-state.md](04-state.md) still holds this stack's (now empty) state. Keep it for the next stack; to remove it, delete every object version first, because a versioned bucket only deletes when it's truly empty.
