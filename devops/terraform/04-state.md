# 4. State

State is Terraform's record of which real object each resource address points to. Lose it and Terraform no longer knows it created anything; let two people write it at once and it gets corrupted; leave it readable and anyone can see every attribute of every resource, secrets included. This guide puts it somewhere safe and shows how to change it without destroying anything.

## Contents

- [What's in state](#whats-in-state)
- [Create a state bucket](#create-a-state-bucket)
- [Move a stack's state to S3](#move-a-stacks-state-to-s3)
- [Locking](#locking)
- [Look at state](#look-at-state)
- [Rename without destroying: moved](#rename-without-destroying-moved)
- [Adopt what already exists: import](#adopt-what-already-exists-import)
- [Stop managing without destroying: removed](#stop-managing-without-destroying-removed)
- [State history](#state-history)
- [Workspaces, and why not to use them for environments](#workspaces-and-why-not-to-use-them-for-environments)
- [Next](#next)

## What's in state

For every resource: its address, the provider, the real object's ID, and every attribute as of the last plan or apply. Terraform uses it to:

- map `aws_sqs_queue.jobs` to one real queue;
- know what to delete when a block is removed;
- work out dependencies when deleting, after the configuration is gone;
- avoid reading every attribute of every resource from AWS on every command.

Rules that follow from that: one state file per stack and environment; never edit it by hand; never commit it; restrict reading it as tightly as applying; and keep old versions.

## Create a state bucket

The state bucket can't store its own state before it exists, so it starts with local state. The [`bootstrap-state`](aws/bootstrap-state/) reference stack is the production version, with a customer-managed KMS key and `prevent_destroy`. This is the minimum:

```hcl
# bootstrap/main.tf
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

resource "aws_s3_bucket" "state" {
  bucket = "guide-tfstate-${data.aws_caller_identity.current.account_id}-us-east-1"
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled" # every write keeps the previous version
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "state_bucket" {
  value = aws_s3_bucket.state.id
}
```

<!-- check: output "state_bucket = \"guide-tfstate-123456789012-us-east-1\"" -->
```sh
# in bootstrap
terraform init
terraform apply
```

Keep this bucket: [06-building-a-stack.md](06-building-a-stack.md) stores its state here too.

## Move a stack's state to S3

Start a small stack with local state:

```hcl
# app/versions.tf
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
# app/main.tf
resource "aws_sqs_queue" "jobs" {
  name = "app-jobs"
}
```

<!-- check: output "Resources: 1 added" -->
```sh
# in app
terraform init
terraform apply
```

Now add a backend. Leave the settings out of the block, a **partial configuration**, so the same code works for every environment, and pass them from a file at `init`:

```hcl
# app/versions.tf
terraform {
  required_version = "~> 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.68"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = "us-east-1"
}
```

<!-- check: output "Successfully configured the backend \"s3\"" -->
<!-- check: output "terraform.tfstate$" -->
```sh
# in app
cat > backend.hcl <<EOF
bucket       = "$(terraform -chdir=../bootstrap output -raw state_bucket)"
key          = "app/dev/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true
EOF
terraform init -migrate-state -force-copy -backend-config=backend.hcl
aws s3 ls "s3://$(terraform -chdir=../bootstrap output -raw state_bucket)/app/dev/"
```

`-migrate-state` copies the local state into the bucket (`-force-copy` answers "yes" to the prompt). From now on every command reads and writes `s3://<bucket>/app/dev/terraform.tfstate`. The `key` is the one setting that changes per stack and environment: `<stack>/<environment>/terraform.tfstate` keeps them apart.

`backend.hcl` holds no secrets, but it's per environment, so most teams keep it out of Git (the reference stacks commit a `backend.hcl.example`) and the pipeline writes it.

## Locking

`use_lockfile = true` makes Terraform write `terraform.tfstate.tflock` next to the state before any command that can change it, using an S3 conditional write that fails if the object is already there. A second `plan` or `apply` while one is running fails instead of corrupting state:

```text
Error: Error acquiring the state lock

Error message: operation error S3: PutObject, https response error
StatusCode: 412 ... api error PreconditionFailed: At least one of the
pre-conditions you specified did not hold
Lock Info:
  ID:        7f121430-e7f9-9b0e-8224-76e6b1995586
  Path:      <bucket>/app/dev/terraform.tfstate
```

S3 native locking is generally available from Terraform 1.11 ([changelog](https://github.com/hashicorp/terraform/blob/v1.11/CHANGELOG.md)), and the older DynamoDB lock table arguments are deprecated: new stacks don't need a table. If a run dies and leaves the lock behind, [OPERATIONS.md](OPERATIONS.md#locks) shows how to check nobody is running before you `terraform force-unlock <ID>`.

## Look at state

<!-- check: output "aws_sqs_queue.jobs" -->
<!-- check: output "name\s+= \"app-jobs\"" -->
```sh
# in app
terraform state list
terraform state show aws_sqs_queue.jobs
```

`terraform show -json` prints the whole state as JSON for scripts. Use these to look; change state with the blocks below, which go through review like any other change.

## Rename without destroying: moved

Renaming a resource's local name looks like deleting one resource and creating another, so Terraform plans exactly that. A `moved` block says it's the same object:

```hcl
# app/main.tf
resource "aws_sqs_queue" "orders" {
  name = "app-jobs"
}

moved {
  from = aws_sqs_queue.jobs
  to   = aws_sqs_queue.orders
}
```

<!-- check: output "aws_sqs_queue.jobs has moved to aws_sqs_queue.orders" -->
<!-- check: output "Plan: 0 to add, 0 to change, 0 to destroy" -->
```sh
# in app
terraform plan
terraform apply
```

`moved` also covers moving a resource into a module (`to = module.queue.aws_sqs_queue.this`) and switching between `count` and `for_each` (`to = aws_sqs_queue.this["orders"]`). Leave the block in place until every environment has applied it; for a shared module, leave it for good. `terraform state mv` does the same from the command line, but nothing reviews it and every environment has to run it by hand.

## Adopt what already exists: import

Something created by hand, or by another tool, can be brought under Terraform with an `import` block. Make a log group outside Terraform:

<!-- check: output "/app/legacy" -->
```sh
# in app
aws logs create-log-group --log-group-name /app/legacy
aws logs describe-log-groups --log-group-name-prefix /app/legacy --query 'logGroups[].logGroupName'
```

Then write the resource as it is, and an `import` block naming the real object. The ID format is on each resource's Registry page, under **Import**: a log group's ID is its name, an SQS queue's is its URL, an IAM role's is its name. `id` can be an expression, such as a variable or a data source attribute.

```hcl
# app/legacy.tf
import {
  to = aws_cloudwatch_log_group.legacy
  id = "/app/legacy"
}

resource "aws_cloudwatch_log_group" "legacy" {
  name = "/app/legacy"
}
```

<!-- check: output "aws_cloudwatch_log_group.legacy will be imported" -->
<!-- check: output "Plan: 1 to import, 0 to add, 0 to change, 0 to destroy" -->
```sh
# in app
terraform plan
terraform apply
```

Aim for an import plan with **0 to change**: any change means your block doesn't yet describe the real object, and applying would change it. For resources with many settings, `terraform plan -generate-config-out=generated.tf` writes a first draft of the block for you to clean up. Import blocks work inside modules from Terraform 1.16.

## Stop managing without destroying: removed

Deleting a resource block destroys the object. To hand an object back, to another stack or to nobody, use `removed`:

```hcl
# app/legacy.tf
removed {
  from = aws_cloudwatch_log_group.legacy

  lifecycle {
    destroy = false
  }
}
```

<!-- check: output "aws_cloudwatch_log_group.legacy will no longer be managed by Terraform" -->
<!-- check: output "\"/app/legacy\"" -->
```sh
# in app
terraform apply
aws logs describe-log-groups --log-group-name-prefix /app/legacy --query 'logGroups[].logGroupName'
```

The log group still exists; Terraform has forgotten it. Moving a resource between stacks is a `removed` in one and an `import` in the other.

## State history

Bucket versioning keeps every state write:

<!-- check: output "terraform.tfstate" -->
```sh
# in app
aws s3api list-object-versions \
  --bucket "$(terraform -chdir=../bootstrap output -raw state_bucket)" \
  --prefix app/dev/terraform.tfstate \
  --query 'Versions[].[Key,LastModified,VersionId]' --output text
```

When an apply goes wrong in a way that damages state, [OPERATIONS.md](OPERATIONS.md#restoring-a-previous-state-version) shows how to make an older version current again. Practice it once in a sandbox before you need it.

Clean up the stack, and the log group `removed` left behind. Keep `bootstrap`:

<!-- check: output "Destroy complete! Resources: 1 destroyed" -->
```sh
# in app
terraform destroy
aws logs delete-log-group --log-group-name /app/legacy
```

## Workspaces, and why not to use them for environments

`terraform workspace new staging` gives the same configuration a second state file in the same backend. It's handy for short-lived copies (a test stack per merge request). For environments, it's a trap:

- Every environment shares one backend, so one set of credentials can reach all of them.
- Nothing in the code shows which workspace is selected; `terraform apply` in the wrong one is easy.
- Environments drift apart in ways a workspace can't express (prod has three AZs, dev one), and the code fills up with `terraform.workspace == "prod" ? ... : ...`.

Use one directory or one tfvars file per environment, one state key per environment, and ideally one AWS account per environment ([10-best-practices.md](10-best-practices.md#environments)).

## Next

[05-modules.md](05-modules.md): packaging resources you use together into a module.
