# Offline, against mock providers:
#   terraform init -backend=false && terraform test -filter=tests/plan.tftest.hcl
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
  mock_resource "aws_sqs_queue" {
    defaults = { arn = "arn:aws:sqs:us-east-1:123456789012:example-dev-uploads" }
  }
  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws:s3:::example-dev-uploads-123456789012-us-east-1" }
  }
}

variables {
  project     = "example"
  environment = "dev"
  region      = "us-east-1"
  owner       = "platform-team"
}

run "names_follow_project_and_environment" {
  command = plan

  assert {
    condition     = module.bucket.id == "example-dev-uploads-123456789012-us-east-1"
    error_message = "Bucket name should be <project>-<environment>-uploads-<account>-<region>."
  }
  assert {
    condition     = aws_sqs_queue.uploads.name == "example-dev-uploads" && aws_sqs_queue.dead_letter.name == "example-dev-uploads-dlq"
    error_message = "Queue names changed; renaming a queue replaces it and drops its messages."
  }
}

run "failed_messages_go_to_the_dead_letter_queue" {
  command = plan

  variables {
    max_receive_count = 3
  }

  assert {
    condition     = jsondecode(aws_sqs_queue.uploads.redrive_policy).maxReceiveCount == 3
    error_message = "max_receive_count should set the redrive policy."
  }
  assert {
    condition     = aws_sqs_queue.uploads.sqs_managed_sse_enabled && aws_sqs_queue.dead_letter.sqs_managed_sse_enabled
    error_message = "Both queues should be encrypted."
  }
}

run "one_notification_per_prefix" {
  command = plan

  variables {
    upload_prefixes = ["incoming/", "imports/"]
  }

  assert {
    condition     = length(aws_s3_bucket_notification.uploads.queue) == 2
    error_message = "Expected one queue notification per prefix."
  }
  assert {
    condition     = toset([for q in aws_s3_bucket_notification.uploads.queue : q.filter_prefix]) == toset(["incoming/", "imports/"])
    error_message = "Each notification should filter on its prefix."
  }
}

run "rejects_an_unknown_environment" {
  command = plan

  variables {
    environment = "production"
  }

  expect_failures = [var.environment]
}

run "rejects_a_prefix_without_a_slash" {
  command = plan

  variables {
    upload_prefixes = ["incoming"]
  }

  expect_failures = [var.upload_prefixes]
}
