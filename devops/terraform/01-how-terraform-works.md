# 1. How Terraform works

Terraform turns files that describe infrastructure into API calls that create, change, and delete it. You write what you want; Terraform works out what to do to get there.

This guide builds one SQS queue, changes it, replaces it, and destroys it, so you see every step of the loop once.

## Contents

- [The pieces](#the-pieces)
- [Your first configuration](#your-first-configuration)
- [init](#init)
- [plan](#plan)
- [apply](#apply)
- [Change it](#change-it)
- [Replace it](#replace-it)
- [destroy](#destroy)
- [What Terraform left on disk](#what-terraform-left-on-disk)
- [Next](#next)

## The pieces

| Piece | What it is |
|---|---|
| **Configuration** | `.tf` files in one directory. Terraform reads every `.tf` file in the directory as one configuration; file names are only for people. |
| **Provider** | A plugin that knows one platform's API. `hashicorp/aws` turns `aws_sqs_queue` into SQS API calls. Terraform itself knows no cloud. |
| **Resource** | One thing the provider manages: a queue, a bucket, a role. |
| **State** | Terraform's record of which real object each resource is, and what it looked like last time. Without it, Terraform can't tell "create" from "already exists". |
| **Plan** | The difference between the configuration and reality, as a list of create, update, replace, and delete actions. |

The loop is always the same:

```text
write .tf ──► init ──► plan ──► apply ──► (change .tf) ──► plan ──► apply ... ──► destroy
               │         │        │
     downloads providers │      calls the API, then writes state
                   reads state, asks the API what exists, compares with the .tf files
```

> **Trying this without an AWS account.** Every command in these guides was run against [moto](https://github.com/getmoto/moto), a local fake of the AWS APIs. [09-testing-with-moto.md](09-testing-with-moto.md#run-the-guides-against-moto) shows how to point your shell at it. With a real account, use a sandbox; everything here costs nothing or close to it, and each guide destroys what it creates.

Blocks that start with `# in first` are commands to run in a directory named `first`. Blocks that start with `# first/main.tf` are the contents of that file.

## Your first configuration

Make an empty directory named `first`, and create two files in it.

```hcl
# first/versions.tf
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

The `terraform` block pins the Terraform and provider versions. `~> 6.68` means 6.68 or any later 6.x, but not 7.0: minor releases add features, a major release can remove them. The `provider` block configures the AWS provider; credentials come from your environment ([03-the-aws-provider.md](03-the-aws-provider.md#credentials)), never from the file.

```hcl
# first/main.tf
resource "aws_sqs_queue" "jobs" {
  name = "first-jobs"

  tags = {
    Team = "platform"
  }
}

output "queue_url" {
  value = aws_sqs_queue.jobs.url
}
```

A resource block has a **type** (`aws_sqs_queue`, which also names the provider: everything before the first underscore) and a **local name** (`jobs`) that only exists inside this configuration. Together they make the resource's address, `aws_sqs_queue.jobs`. The arguments inside come from the provider's documentation: the [aws_sqs_queue page](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) in the Terraform Registry lists every argument and every attribute you can read back, such as `url`.

## init

<!-- check: output "Terraform has been successfully initialized" -->
<!-- check: output "hashicorp/aws v6\." -->
```sh
# in first
terraform init
```

`init` downloads the providers the configuration needs into `.terraform/`, and records the exact version and checksums it chose in `.terraform.lock.hcl`. Commit the lock file: the next person, and the pipeline, get the same provider build. Run `init` again whenever you add a provider or a module, or change the backend.

## plan

<!-- check: output "aws_sqs_queue.jobs will be created" -->
<!-- check: output "Plan: 1 to add, 0 to change, 0 to destroy" -->
```sh
# in first
terraform plan
```

The plan marks each resource with a symbol: `+` create, `~` update in place, `-/+` destroy and re-create (replace), `-` destroy. Values shown as `(known after apply)` come from AWS once the resource exists, such as the queue's ARN.

Read every plan. The code diff in a review shows what someone meant; the plan shows what will actually happen.

## apply

<!-- check: output "Apply complete! Resources: 1 added, 0 changed, 0 destroyed" -->
<!-- check: output "first-jobs" -->
```sh
# in first
terraform apply
terraform output queue_url
```

`apply` shows the same plan again and asks for `yes` before it changes anything. In a pipeline you save the plan with `terraform plan -out=tfplan` and apply exactly that file with `terraform apply tfplan`, so what runs is what was reviewed.

Run `plan` again straight away. With nothing changed in the files or in AWS, there's nothing to do:

<!-- check: output "No changes. Your infrastructure matches the configuration" -->
```sh
# in first
terraform plan
```

## Change it

Change the tag and add a visibility timeout:

```hcl
# first/main.tf
resource "aws_sqs_queue" "jobs" {
  name                       = "first-jobs"
  visibility_timeout_seconds = 120

  tags = {
    Team = "payments"
  }
}

output "queue_url" {
  value = aws_sqs_queue.jobs.url
}
```

<!-- check: output "aws_sqs_queue.jobs will be updated in-place" -->
<!-- check: output "Plan: 0 to add, 1 to change, 0 to destroy" -->
```sh
# in first
terraform plan
```

SQS can change both settings on an existing queue, so this is an **update in place** (`~`). The queue, its URL, and any messages in it stay.

## Replace it

Now rename the queue:

```hcl
# first/main.tf
resource "aws_sqs_queue" "jobs" {
  name                       = "first-jobs-v2"
  visibility_timeout_seconds = 120

  tags = {
    Team = "payments"
  }
}

output "queue_url" {
  value = aws_sqs_queue.jobs.url
}
```

<!-- check: output "aws_sqs_queue.jobs must be replaced" -->
<!-- check: output "# forces replacement" -->
<!-- check: output "Plan: 1 to add, 0 to change, 1 to destroy" -->
```sh
# in first
terraform plan
```

SQS can't rename a queue, so Terraform has to delete the old one and create a new one: `-/+`, `must be replaced`, with `# forces replacement` next to the argument responsible. On a queue that loses every message in it; on a database it loses the data. **Treat `must be replaced` on anything stateful as a stop sign**, and find out why before you apply. [OPERATIONS.md](OPERATIONS.md#the-plan-wants-to-replace-something) covers the usual causes.

Apply it anyway; this queue is empty:

<!-- check: output "Apply complete! Resources: 1 added, 0 changed, 1 destroyed" -->
```sh
# in first
terraform apply
```

## destroy

<!-- check: output "Destroy complete! Resources: 1 destroyed" -->
```sh
# in first
terraform destroy
```

`destroy` deletes everything in the state. It shows a plan of `-` actions and asks first, like `apply`.

## What Terraform left on disk

```text
first/
├── versions.tf
├── main.tf
├── .terraform/            providers (and modules); recreated by init, never commit
├── .terraform.lock.hcl    exact provider versions and checksums; commit
└── terraform.tfstate      state; local here, remote in real use, never commit
```

<!-- check: output "terraform.tfstate" -->
<!-- check: output ".terraform.lock.hcl" -->
```sh
# in first
ls -a
```

The state file is JSON that holds every attribute of every resource, sometimes including secrets. On a laptop it's lost when the laptop is; two people with their own copies will each create their own queue. [04-state.md](04-state.md) moves it to S3 with locking, which is where it belongs from the first real stack onward.

## Next

[02-the-language.md](02-the-language.md): variables, locals, outputs, expressions, and creating many things from one block.
