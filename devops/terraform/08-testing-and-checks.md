# 8. Testing and checks

A Terraform change can be wrong in several ways: it doesn't parse, it's insecure, it does something other than intended, or it works in your head and fails against the real API. Each check below catches a different one, and they get slower and more expensive as you go down, so run them in this order.

| Check | Catches | Speed | Needs |
|---|---|---|---|
| `terraform fmt -check` | Formatting | instant | nothing |
| `terraform validate` | Syntax, wrong argument names, type errors | seconds | `init` |
| tflint | Mistakes validate allows: invalid instance types, unused declarations, deprecated syntax | seconds | the ruleset plugins |
| checkov | Insecure settings: public buckets, missing encryption, wide IAM | seconds | nothing |
| `terraform test`, `command = plan`, mock provider | Your logic: conditionals, names, counts, validation | seconds | nothing |
| `terraform test`, `command = apply` | What the real API accepts and returns | minutes | a sandbox account, or moto ([09](09-testing-with-moto.md)) |
| Reading the plan | Everything else: replacements, surprises | minutes | credentials for the target |

## Contents

- [Set up](#set-up)
- [fmt and validate](#fmt-and-validate)
- [tflint](#tflint)
- [checkov](#checkov)
- [terraform test](#terraform-test)
- [Write a test](#write-a-test)
- [Test that bad input fails](#test-that-bad-input-fails)
- [Apply tests](#apply-tests)
- [Reports for CI](#reports-for-ci)
- [In a pipeline](#in-a-pipeline)
- [Next](#next)

## Set up

Work on a copy of the examples:

<!-- check: output "uploads" -->
```sh
# in testing
cp -r "$GUIDEBOOK/devops/terraform/examples/." .
ls
```

## fmt and validate

<!-- check: output "Success! The configuration is valid" -->
```sh
# in testing
terraform fmt -check -recursive
cd uploads
terraform init -backend=false
terraform validate
```

`fmt -check` exits non-zero and lists files that need formatting; run `terraform fmt -recursive` to fix them. `-backend=false` lets `init` and `validate` run without access to the state bucket, which is what you want in a check job.

## tflint

[tflint](https://github.com/terraform-linters/tflint) finds problems `validate` can't: values the AWS API would reject, declarations nothing uses, missing descriptions. This repository's [`.tflint.hcl`](.tflint.hcl) enables the recommended Terraform rules and the AWS ruleset:

```hcl
# .tflint.hcl (excerpt)
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.49.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

rule "terraform_documented_variables" {
  enabled = true
}
```

```sh
# from devops/terraform/
tflint --init
tflint --recursive --config "$(pwd)/.tflint.hcl" --chdir examples
```

tflint caught an unused `data "aws_partition"` while the uploads example was being written. Unused declarations are harmless until someone assumes they're used.

## checkov

[checkov](https://www.checkov.io/) checks configuration against security policies. Run it on the directory:

```sh
# from devops/terraform/
checkov -d examples --framework terraform --compact --quiet
```

Fix what it finds. When a finding doesn't apply, skip it **inside the resource**, with a reason that's specific and true, so the exception is reviewed with the code it excuses:

```hcl
# From examples/modules/s3-bucket/main.tf
resource "aws_s3_bucket" "this" {
  #checkov:skip=CKV_AWS_144:Cross-region replication is a disaster recovery decision for the caller, not a default.

  bucket = var.name
}
```

A skip that says "not needed" will be read, in the next audit, as "nobody checked". Read what the check looks for (`checkov --list` or the check's page) before deciding it doesn't apply.

## terraform test

`terraform test` runs `.tftest.hcl` files in the module's `tests/` directory. Each file has `run` blocks, executed in order; each `run` plans or applies the module with the variables given and evaluates `assert` blocks against the result.

<!-- check: output "tests/plan.tftest.hcl... pass" -->
<!-- check: output "5 passed, 0 failed" -->
```sh
# in testing/uploads
terraform test -filter=tests/plan.tftest.hcl
```

The file starts with a **mock provider**: Terraform makes up values for every resource and data source instead of calling AWS, so the test runs offline, in seconds, with no credentials.

```hcl
# From examples/uploads/tests/plan.tftest.hcl
mock_provider "aws" {
  # Use the mock values below at plan time too, so assertions can read
  # attributes the real provider only knows after apply, such as ARNs.
  override_during = plan

  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{}" }
  }
}

variables {
  project     = "example"
  environment = "dev"
  region      = "us-east-1"
  owner       = "platform-team"
}
```

Mock values are random strings unless you give defaults, so give defaults for anything that's parsed (JSON policies) or that an assertion compares (account IDs, ARNs). Without `override_during = plan`, attributes only AWS knows, such as an ARN, are unknown in a `command = plan` run, and an assertion that reads them fails with `Unknown condition value`.

## Write a test

Test the decisions that matter, not that Terraform works. For uploads, one decision is that the consumer can read only the upload prefixes:

```hcl
# testing/uploads/tests/consumer.tftest.hcl
mock_provider "aws" {
  override_during = plan

  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{}" }
  }
  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws:s3:::example-dev-uploads-123456789012-us-east-1" }
  }
}

variables {
  project         = "example"
  environment     = "dev"
  region          = "us-east-1"
  owner           = "platform-team"
  upload_prefixes = ["incoming/", "imports/"]
}

run "consumer_reads_only_the_upload_prefixes" {
  command = plan

  assert {
    condition = toset(data.aws_iam_policy_document.consumer.statement[0].resources) == toset([
      "arn:aws:s3:::example-dev-uploads-123456789012-us-east-1/incoming/*",
      "arn:aws:s3:::example-dev-uploads-123456789012-us-east-1/imports/*",
    ])
    error_message = "The consumer should read only objects under the upload prefixes."
  }
  assert {
    condition     = data.aws_iam_policy_document.consumer.statement[0].actions == toset(["s3:GetObject"])
    error_message = "The consumer should only get objects, not list, write, or delete them."
  }
}

run "consumer_role_is_for_the_configured_service" {
  command = plan

  variables {
    consumer_service = "lambda.amazonaws.com"
  }

  assert {
    condition     = one(one(data.aws_iam_policy_document.consumer_assume.statement).principals).identifiers == toset(["lambda.amazonaws.com"])
    error_message = "consumer_service should set who can assume the role."
  }
}
```

<!-- check: output "run \"consumer_reads_only_the_upload_prefixes\"... pass" -->
<!-- check: output "2 passed, 0 failed" -->
```sh
# in testing/uploads
terraform test -filter=tests/consumer.tftest.hcl
```

The assertions read the policy document's **inputs** (its statements), which are known at plan time, rather than the rendered JSON, which the mock replaces with `{}`.

Make sure a test can fail. Change `"s3:GetObject"` to `"s3:*"` in `consumer.tf`, run it, see the failure, and change it back. A test that has never failed hasn't been shown to test anything.

## Test that bad input fails

`expect_failures` turns a failure into a pass, for validation rules and preconditions:

```hcl
# From examples/uploads/tests/plan.tftest.hcl
run "rejects_a_prefix_without_a_slash" {
  command = plan

  variables {
    upload_prefixes = ["incoming"]
  }

  expect_failures = [var.upload_prefixes]
}
```

Name the exact object expected to fail. If a different check fails, or none does, the run fails.

## Apply tests

`command = apply` creates real resources, runs the assertions against what came back, and destroys everything at the end of the file. It catches what mocks can't: an argument the API rejects, an attribute that comes back different, a dependency Terraform didn't know about.

```hcl
# From examples/uploads/tests/apply.tftest.hcl
run "creates_the_stack" {
  command = apply

  assert {
    condition     = jsondecode(aws_sqs_queue.uploads.redrive_policy).deadLetterTargetArn == aws_sqs_queue.dead_letter.arn
    error_message = "The queue should redrive to the dead-letter queue."
  }
}
```

Run apply tests against a dedicated sandbox account, never one with anything you care about, or against moto. [09-testing-with-moto.md](09-testing-with-moto.md) runs this file locally in a minute.

Keep plan and apply tests in separate files so CI can run the offline ones on every change (`-filter=tests/plan.tftest.hcl`) and the apply ones where credentials exist.

## Reports for CI

<!-- check: output "testsuite" -->
```sh
# in testing/uploads
terraform test -filter=tests/plan.tftest.hcl -filter=tests/consumer.tftest.hcl -junit-xml=report.xml
head -c 300 report.xml
```

GitLab and most CI systems show JUnit XML as a test report on the merge request. `-junit-xml` is generally available from Terraform 1.11.

## In a pipeline

```text
merge request:  fmt -check ─► validate ─► tflint ─► checkov ─► test (plan) ─► plan, posted to the MR
default branch: the same ─► manual approval ─► apply the saved plan
```

The [GitLab Terraform pipeline](../gitlab/examples/terraform/.gitlab-ci.yml) does this with OIDC credentials, `init -lockfile=readonly` (a pipeline must never change the lock file), and a saved plan that the apply job uses as-is. It was run end to end against moto in the [GitLab lab](../gitlab/lab/README.md).

## Next

[09-testing-with-moto.md](09-testing-with-moto.md): running apply tests and whole stacks locally against moto.
