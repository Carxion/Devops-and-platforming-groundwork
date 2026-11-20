# 9. Testing with moto

[moto](https://github.com/getmoto/moto) is a fake of the AWS APIs that runs locally. Point the AWS provider at it and `terraform apply` creates buckets, queues, and roles in moto's memory instead of in an account: no credentials, no cost, nothing to clean up, and a full apply in seconds to a couple of minutes.

Every command in these guides, and every example in [examples/](examples/), is run against moto by [`tests/check.py`](tests/check.py). This guide shows how to do the same for your own configurations, and where moto stops being a good stand-in for AWS.

## Contents

- [Where moto fits](#where-moto-fits)
- [Start moto](#start-moto)
- [Point Terraform at it](#point-terraform-at-it)
- [Write a configuration to test](#write-a-configuration-to-test)
- [Write an apply test](#write-an-apply-test)
- [Test behavior, not just configuration](#test-behavior-not-just-configuration)
- [Where moto differs from AWS](#where-moto-differs-from-aws)
- [Checking that a second plan is clean](#checking-that-a-second-plan-is-clean)
- [Run the guides against moto](#run-the-guides-against-moto)
- [In a pipeline](#in-a-pipeline)
- [Next](#next)

## Where moto fits

| | Mock provider (`terraform test`) | moto | Sandbox account |
|---|---|---|---|
| Calls an API | No | A fake one | The real one |
| Catches logic errors | Yes | Yes | Yes |
| Catches arguments the API rejects | No | Mostly | Yes |
| Exercises behavior (an upload sends an event; a failing message moves to the DLQ) | No | Yes, for the services it fakes well | Yes |
| Catches IAM permission problems | No | No (it accepts any request by default) | Yes |
| Credentials, cost, cleanup | None | None | All three |
| Speed | Seconds | Seconds to minutes | Minutes |

Use mock-provider tests on every change, moto for apply tests and behavior on every change too (it's cheap enough), and a sandbox account before production for anything moto can't tell you: permissions, quotas, and services it fakes poorly.

## Start moto

Run moto and Terraform as containers on one Docker network, so Terraform reaches moto by name:

```sh
docker network create tf-moto
docker run -d --rm --name moto --network tf-moto \
  --network-alias moto --network-alias 123456789012.moto \
  motoserver/moto:5.2.5
```

The second alias matters. Some AWS APIs put the account ID in front of the host name: the provider reads S3 bucket tags through S3 Control at `123456789012.<endpoint host>`. `123456789012` is moto's default account ID, so that's the name moto needs to answer to.

## Point Terraform at it

Three settings, none of them in your configuration:

1. **The endpoint.** `AWS_ENDPOINT_URL=http://moto:5000` sends every AWS API call to moto. The provider and the AWS CLI both read it.
2. **Credentials.** moto accepts any; the provider insists on having some. `AWS_ACCESS_KEY_ID=test` and `AWS_SECRET_ACCESS_KEY=test`.
3. **Path-style S3.** The provider addresses buckets as `<bucket>.<host>`, which Docker's DNS can't resolve for every bucket name. An **override file** switches to `<host>/<bucket>` without touching your code:

```hcl
# moto_override.tf: merged into the provider "aws" block in your files.
provider "aws" {
  s3_use_path_style = true
}
```

Terraform merges any file named `override.tf` or `*_override.tf` into the matching blocks of the other files, after loading them ([docs](https://developer.hashicorp.com/terraform/language/files/override)). That makes it the right tool for test-only settings: your code stays exactly what you deploy. This repository's `.gitignore` ignores `*_override.tf`, so the file can't be committed by accident. If the configuration has aliased providers, override each alias too (`alias = "west"` inside the block).

Then run Terraform in a container with those variables:

```sh
docker run --rm -it --network tf-moto -v "$PWD:/work" -w /work \
  -e AWS_ENDPOINT_URL=http://moto:5000 \
  -e AWS_ACCESS_KEY_ID=test -e AWS_SECRET_ACCESS_KEY=test \
  hashicorp/terraform:1.16.5 test
```

From Git Bash on Windows, set `MSYS_NO_PATHCONV=1` and use `$(pwd -W)` in place of `$PWD`, or run it from WSL. An S3 backend needs `-backend-config=use_path_style=true` at `init` as well; `terraform test` ignores the backend, so tests don't.

## Write a configuration to test

A queue with a dead-letter queue, small enough to read in one go:

```hcl
# moto-demo/main.tf
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

variable "name" {
  description = "Queue name."
  type        = string
}

variable "max_receive_count" {
  description = "Receives before a message moves to the dead-letter queue."
  type        = number
  default     = 3
}

resource "aws_sqs_queue" "dead_letter" {
  name                      = "${var.name}-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "this" {
  name = var.name

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter.arn
    maxReceiveCount     = var.max_receive_count
  })

  lifecycle {
    precondition {
      condition     = var.max_receive_count >= 2
      error_message = "Allow at least one retry before dead-lettering."
    }
  }
}

output "queue_url" {
  value = aws_sqs_queue.this.url
}

output "dead_letter_queue_url" {
  value = aws_sqs_queue.dead_letter.url
}
```

## Write an apply test

```hcl
# moto-demo/tests/queue.tftest.hcl
# Apply tests: run against moto or a sandbox account, never production.
variables {
  name = "moto-demo"
}

run "creates_both_queues" {
  command = apply

  assert {
    condition     = aws_sqs_queue.this.name == "moto-demo" && aws_sqs_queue.dead_letter.name == "moto-demo-dlq"
    error_message = "Unexpected queue names."
  }
  assert {
    condition     = jsondecode(aws_sqs_queue.this.redrive_policy).deadLetterTargetArn == aws_sqs_queue.dead_letter.arn
    error_message = "The queue should redrive to its dead-letter queue."
  }
  assert {
    condition     = aws_sqs_queue.dead_letter.message_retention_seconds == 1209600
    error_message = "Dead letters should be kept for 14 days."
  }
}

run "changes_the_receive_count_in_place" {
  command = apply

  variables {
    max_receive_count = 5
  }

  assert {
    condition     = jsondecode(aws_sqs_queue.this.redrive_policy).maxReceiveCount == 5
    error_message = "max_receive_count should update the redrive policy."
  }
}

run "rejects_no_retries" {
  command = plan

  variables {
    max_receive_count = 1
  }

  expect_failures = [aws_sqs_queue.this]
}
```

Runs in one file share state, in order: the second run updates the queues the first created, which tests the change path as well as creation. When the file finishes, Terraform destroys everything it created, in reverse order.

<!-- check: output "run \"creates_both_queues\"... pass" -->
<!-- check: output "run \"changes_the_receive_count_in_place\"... pass" -->
<!-- check: output "run \"rejects_no_retries\"... pass" -->
<!-- check: output "3 passed, 0 failed" -->
```sh
# in moto-demo
terraform init
terraform test
```

Assert on what your configuration decides (names, settings, relationships between resources), not on formats the service chooses: a queue URL from moto (`http://moto:5000/123456789012/moto-demo`) looks nothing like one from SQS, and an assertion on its host would pass in one place and fail in the other.

## Test behavior, not just configuration

Attributes in state only show that the API accepted the settings. moto also implements much of what the services *do*, so you can check that the stack works. Apply, then drive it with the AWS CLI against the same endpoint:

<!-- check: output "dead-lettered after 3 receives" -->
```sh
# in moto-demo
terraform apply -var name=behavior
queue=$(terraform output -raw queue_url)
dlq=$(terraform output -raw dead_letter_queue_url)

aws sqs send-message --queue-url "$queue" --message-body poison >/dev/null

# A consumer that keeps failing: receive and never delete. Visibility
# timeout 0 makes the message visible again at once.
for attempt in 1 2 3; do
  aws sqs receive-message --queue-url "$queue" --visibility-timeout 0 --query 'Messages[0].Body' --output text
done

# The next receive moves it to the dead-letter queue.
aws sqs receive-message --queue-url "$queue" --visibility-timeout 0 >/dev/null
body=$(aws sqs receive-message --queue-url "$dlq" --query 'Messages[0].Body' --output text)
test "$body" = poison && echo "dead-lettered after 3 receives"

terraform destroy -var name=behavior
```

The same approach checks the uploads example in [`tests/check.py`](tests/check.py): upload a file under `incoming/`, and a message naming it must arrive on the queue; upload one under `other/`, and none must.

## Where moto differs from AWS

moto is a reimplementation, and every gap below was found running these guides with moto 5.2.5 and provider 6.73. Expect your own list; when a test fails only on moto, confirm the behavior in a sandbox before changing your code.

| Gap | Symptom | What to do |
|---|---|---|
| Virtual-hosted S3 names don't resolve | `dial tcp: lookup <bucket>.moto ... no such host` | The `moto_override.tf` above |
| Account-prefixed hosts (S3 Control) | `lookup 123456789012.moto ... no such host` | The `123456789012.moto` network alias |
| Bucket policies with `aws:SecureTransport` deny every request, even over TLS | `403 Forbidden` on `PutObject` after applying a TLS-only policy | Keep the policy; in the behavior test only, delete it before uploading (`aws s3api delete-bucket-policy`) |
| Default tags on a new bucket aren't returned | Next plan: `tags_all` update on `aws_s3_bucket` | Allow it in the clean-plan check ([below](#checking-that-a-second-plan-is-clean)) |
| SQS returns the redrive policy with different JSON spacing | Next plan: `redrive_policy = jsonencode( # whitespace changes` | The same; then policies that depend on the queue show as "known after apply" |
| Updating a queue's redrive policy drops the queue's access policy | After a second apply, `aws_sqs_queue_policy` plans to be created again, or a later destroy counts one resource fewer | Don't assert exact resource counts across repeated applies; assert on the plan's actions instead |
| Queue URLs look like `http://moto:5000/123456789012/name` | `import`: `could not parse ... as SQS URL` (the provider expects `https://sqs.<region>.<host>/...`) | Test `import` with a resource whose ID is a name, such as a log group |
| The provider waits for SQS changes to settle | Each queue create takes about 25 seconds and each delete about 42 | Nothing; it's the provider's consistency waiter, and real SQS is the same or slower |
| No IAM enforcement by default | A policy missing an action still "works" | Test permissions in a sandbox account |
| S3 event records URL-encode the key | `incoming%2Fhello.txt` in the message | Match on the configuration ID, or URL-decode the key, as a real consumer must |

## Checking that a second plan is clean

After an apply, a plan should show no changes; if it doesn't, something in the configuration doesn't round-trip and will churn forever. On real AWS, check with `terraform plan -detailed-exitcode` (0: no changes, 2: changes). Against moto, the gaps above show up as in-place updates, so check the plan JSON instead, and allow exactly the known gaps:

<!-- check: output "aws_sqs_queue.this: update" -->
```sh
# in moto-demo
terraform apply -var name=replan
terraform plan -var name=replan -out=replan.tfplan
terraform show -json replan.tfplan | jq -r '
  .resource_changes[]
  | select(.change.actions != ["no-op"] and .change.actions != ["read"])
  | "\(.address): \(.change.actions | join(","))"'
terraform destroy -var name=replan
```

On moto, this lists `aws_sqs_queue.this: update`, the redrive-policy spacing gap, straight after an apply that changed nothing. Fail on any `create`, `delete`, or replacement, and on updates to attributes other than the known ones. `check_replan` in [`tests/check.py`](tests/check.py) does that in Python, and is the check that found the redrive-policy gap.

## Run the guides against moto

```sh
python devops/terraform/tests/check.py               # examples, then every guide
python devops/terraform/tests/check.py 04-state.md   # one guide (06 needs 04's state bucket)
python devops/terraform/tests/check.py examples      # only the examples
```

It starts moto and a Terraform container on a private network, writes each `# <workspace>/<file>` block from the guides into that workspace, runs each `# in <workspace>` block there, and checks the results with the hidden `<!-- check: ... -->` comments next to each block in the Markdown source. Commands run with `TF_INPUT=0` and `-auto-approve` (through `TF_CLI_ARGS_apply` and `TF_CLI_ARGS_destroy`), so the guides can show plain `terraform apply`.

To follow along by hand, start moto as above, then run a shell in the Terraform image with the same variables and work inside it:

```sh
docker run --rm -it --network tf-moto -v "$PWD:/work" -w /work \
  -e AWS_ENDPOINT_URL=http://moto:5000 -e AWS_DEFAULT_REGION=us-east-1 \
  -e AWS_ACCESS_KEY_ID=test -e AWS_SECRET_ACCESS_KEY=test \
  --entrypoint sh hashicorp/terraform:1.16.5
apk add aws-cli   # for the guides' aws commands
```

Add `moto_override.tf` to each directory that has a `provider "aws"` block, and pass `-backend-config=use_path_style=true` to `init` where there's an S3 backend.

## In a pipeline

In CI, moto is a service container next to the job, and the job sets the same three variables. The [GitLab lab](../gitlab/lab/README.md) runs moto beside its runner, and its Terraform scenario plans and applies a real stack through the [GitLab Terraform pipeline](../gitlab/examples/terraform/.gitlab-ci.yml) against it, including the OIDC role exchange, which moto also fakes. Run moto apply tests on every merge request; they're fast, free, and catch most of what a sandbox would, short of permissions.

## Next

[10-best-practices.md](10-best-practices.md): structuring repositories, environments, and pipelines, and keeping stacks healthy over time.
