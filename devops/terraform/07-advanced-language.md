# 7. Advanced language

The features in this guide solve specific problems: settings that repeat inside one resource, resources that must not be deleted, inputs that are only wrong in combination, secrets that shouldn't reach state, and checks that run after every apply. Reach for each when you have that problem, not before.

## Contents

- [Dynamic blocks](#dynamic-blocks)
- [lifecycle](#lifecycle)
- [Preconditions and postconditions](#preconditions-and-postconditions)
- [check blocks](#check-blocks)
- [Ephemeral values and write-only arguments](#ephemeral-values-and-write-only-arguments)
- [Provider-defined functions](#provider-defined-functions)
- [Replacing one resource on purpose](#replacing-one-resource-on-purpose)
- [terraform_data and templatefile](#terraform_data-and-templatefile)
- [Next](#next)

## Dynamic blocks

`for_each` repeats resources; `dynamic` repeats **nested blocks** inside one resource. The uploads stack makes one `queue` block per prefix:

```hcl
# From examples/uploads/queue.tf
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
}
```

Inside `content`, the iterator is named after the block (`queue.key`, `queue.value`). Use `dynamic` when the number of blocks comes from input. Writing out three fixed blocks is easier to read than a `dynamic` over a literal list of three.

## lifecycle

Every resource accepts a `lifecycle` block that changes how Terraform handles it:

```hcl
# lifecycle options, one resource each
resource "aws_s3_bucket" "records" {
  bucket = "example-records-123456789012"

  lifecycle {
    prevent_destroy = true # any plan that would delete it fails
  }
}

resource "aws_launch_template" "web" {
  name_prefix = "web-"

  lifecycle {
    create_before_destroy = true # build the replacement before deleting the old one
  }
}

resource "aws_ecs_service" "web" {
  name          = "web"
  desired_count = 2

  lifecycle {
    ignore_changes = [desired_count] # autoscaling owns this after creation
  }
}

resource "aws_sqs_queue" "worker" {
  name = "worker"

  lifecycle {
    replace_triggered_by = [terraform_data.worker_version] # replace when this changes
  }
}
```

| Option | Use it for | Watch out for |
|---|---|---|
| `prevent_destroy` | Data you can't recreate: state buckets, databases, KMS keys | It only guards against Terraform; deleting the block removes the guard |
| `create_before_destroy` | Things in use that must never be missing, such as a launch template or certificate | Needs a name that can exist twice (`name_prefix`) |
| `ignore_changes` | Attributes another system manages after creation | Hides real drift on those attributes; list them, never `all` without a written reason |
| `replace_triggered_by` | Replacing a resource when something it doesn't reference changes | Replacement is the blunt instrument; prefer an argument that updates in place |

See `prevent_destroy` work:

```hcl
# advanced/versions.tf
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
# advanced/ledger.tf
resource "aws_sqs_queue" "ledger" {
  name = "advanced-ledger"

  lifecycle {
    prevent_destroy = true
  }
}
```

<!-- check: fails -->
<!-- check: output "Instance cannot be destroyed" -->
```sh
# in advanced
terraform init
terraform apply
terraform destroy
```

The apply succeeds; the destroy stops at plan time with `Instance cannot be destroyed`, and nothing is deleted. To remove the queue on purpose, delete the `lifecycle` setting in a reviewed change first.

## Preconditions and postconditions

Variable validation checks one input. A **precondition** checks anything known at plan time, including combinations of inputs and data sources; a **postcondition** checks the result after the resource is created or read.

```hcl
# advanced/main.tf
variable "consumer_timeout_seconds" {
  description = "How long the consumer may take to process one message."
  type        = number
  default     = 30
}

variable "visibility_timeout_seconds" {
  description = "How long a received message stays hidden."
  type        = number
  default     = 60
}

resource "aws_sqs_queue" "jobs" {
  name                       = "advanced-jobs"
  visibility_timeout_seconds = var.visibility_timeout_seconds

  lifecycle {
    precondition {
      condition     = var.visibility_timeout_seconds > var.consumer_timeout_seconds
      error_message = "The visibility timeout must be longer than the consumer timeout, or messages are processed twice."
    }

    postcondition {
      condition     = self.sqs_managed_sse_enabled
      error_message = "The queue came back unencrypted."
    }
  }
}
```

<!-- check: fails -->
<!-- check: output "Resource precondition failed" -->
<!-- check: output "processed twice" -->
```sh
# in advanced
terraform plan -var consumer_timeout_seconds=90
```

Neither value is wrong alone; together they cause duplicate processing, which AWS would happily accept. The postcondition uses `self` and relies on SQS encrypting new queues by default: if that ever stops being true, the apply fails instead of quietly creating an unencrypted queue.

## check blocks

A `check` block asserts something about the whole configuration, and only **warns**: it runs on every plan and apply, never blocks one, and is a cheap health check for things that can drift.

```hcl
# advanced/checks.tf
check "jobs_queue_is_encrypted" {
  assert {
    condition     = aws_sqs_queue.jobs.sqs_managed_sse_enabled
    error_message = "advanced-jobs is not encrypted with SQS-managed keys."
  }
}

check "dead_letters_kept_long_enough" {
  assert {
    condition     = aws_sqs_queue.jobs.message_retention_seconds >= 1209600
    error_message = "Messages are kept for less than 14 days; failures may expire before anyone looks."
  }
}
```

<!-- check: output "Warning: Check block assertion failed" -->
<!-- check: output "expire before anyone" -->
<!-- check: output "Apply complete" -->
```sh
# in advanced
terraform apply
```

The second check fails (SQS keeps messages for four days by default), the apply goes ahead, and the warning stays in the output for someone to act on. A check can also hold a scoped `data` block, such as an HTTP health check against an endpoint the stack built.

## Ephemeral values and write-only arguments

`sensitive = true` hides a value in output, but Terraform still stores it in state. Two newer features keep secrets out of state entirely:

- **Ephemeral resources** (Terraform 1.10) produce a value during a run and never store it. `ephemeral "aws_secretsmanager_random_password"` generates a password.
- **Write-only arguments** (Terraform 1.11) are sent to the API and never stored. They end in `_wo`, with a `_wo_version` you bump to send a new value, because Terraform can't compare a value it never kept.

```hcl
# advanced/secret.tf
ephemeral "aws_secretsmanager_random_password" "api_key" {
  password_length     = 32
  exclude_punctuation = true
}

resource "aws_ssm_parameter" "api_key" {
  name             = "/advanced/api-key"
  type             = "SecureString"
  value_wo         = ephemeral.aws_secretsmanager_random_password.api_key.random_password
  value_wo_version = 1 # bump to rotate
}
```

<!-- check: output "the password is in SSM and not in state" -->
```sh
# in advanced
terraform apply -var visibility_timeout_seconds=60
password=$(aws ssm get-parameter --name /advanced/api-key --with-decryption --query Parameter.Value --output text)
test ${#password} -eq 32
terraform state pull | grep -q "$password" && echo "found in state" && exit 1
echo "the password is in SSM and not in state"
```

Write-only arguments exist on resources where providers added them, such as `password_wo` on `aws_db_instance` and `secret_string_wo` on `aws_secretsmanager_secret_version`; check the resource page. Where they don't exist, keep the secret in Secrets Manager and let the application read it at run time, rather than passing it through Terraform.

## Provider-defined functions

Providers can ship functions, called as `provider::<name>::<function>`. The AWS provider has ARN helpers:

<!-- check: output "\"region\" = \"us-east-1\"" -->
<!-- check: output "\"resource\" = \"advanced-jobs\"" -->
```sh
# in advanced
echo 'provider::aws::arn_parse(aws_sqs_queue.jobs.arn)' | terraform console
```

`arn_parse` and `arn_build` save brittle `split(":", ...)` expressions. The provider must be in `required_providers` for its functions to be available.

## Replacing one resource on purpose

When a resource is broken in a way Terraform can't see (a corrupted instance, a key you want rotated), plan its replacement explicitly instead of editing code to force it:

<!-- check: output "aws_sqs_queue.jobs will be replaced, as requested" -->
<!-- check: output "Plan: 1 to add, 0 to change, 1 to destroy" -->
```sh
# in advanced
terraform plan -replace=aws_sqs_queue.jobs
```

`-replace` affects one run and leaves no trace in the code. It replaced `terraform taint`, which changed state before anyone saw a plan.

Clean up. The ledger queue is still protected, so `destroy` would stop again. Remove the protection in a change of its own, as you would for real, by deleting the block:

```hcl
# advanced/ledger.tf
# The ledger queue was retired in a reviewed change: deleting its block
# removes prevent_destroy along with it, and plans the queue's deletion.
```

<!-- check: output "aws_sqs_queue.ledger will be destroyed" -->
<!-- check: output "Destroy complete" -->
```sh
# in advanced
terraform destroy
```

`prevent_destroy` lives in the configuration, so it protects a resource only while its block exists. That's why the deletion of a protected resource deserves its own reviewed change.

## terraform_data and templatefile

```hcl
# terraform_data: a value in state that other resources can depend on.
resource "terraform_data" "worker_version" {
  input = var.worker_version
}

# templatefile: render a file with variables, for user data or policies.
locals {
  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    environment = var.environment
    queue_url   = aws_sqs_queue.jobs.url
  })
}
```

`terraform_data` holds a value whose change should ripple through `replace_triggered_by`; it replaced the `null_resource` from the `null` provider. `templatefile` keeps scripts and long documents in their own files, where editors highlight them, instead of heredocs inside HCL.

## Next

[08-testing-and-checks.md](08-testing-and-checks.md): fmt, validate, tflint, checkov, and `terraform test`.
