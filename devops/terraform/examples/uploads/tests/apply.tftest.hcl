# Creates real resources, checks them, and destroys them. Run it against a
# sandbox account (or moto, as tests/check.sh does), never production:
#   terraform test -filter=tests/apply.tftest.hcl
variables {
  project       = "tftest"
  environment   = "dev"
  region        = "us-east-1"
  owner         = "platform-team"
  force_destroy = true
}

run "creates_the_stack" {
  command = apply

  assert {
    condition     = startswith(output.bucket_name, "tftest-dev-uploads-")
    error_message = "Unexpected bucket name: ${output.bucket_name}"
  }
  assert {
    condition     = endswith(output.queue_url, "/tftest-dev-uploads")
    error_message = "Unexpected queue URL: ${output.queue_url}"
  }
  assert {
    condition     = jsondecode(aws_sqs_queue.uploads.redrive_policy).deadLetterTargetArn == aws_sqs_queue.dead_letter.arn
    error_message = "The queue should redrive to the dead-letter queue."
  }
}

run "adding_a_prefix_updates_in_place" {
  command = apply

  variables {
    upload_prefixes = ["incoming/", "imports/"]
  }

  assert {
    condition     = length(aws_s3_bucket_notification.uploads.queue) == 2
    error_message = "Expected two notifications after adding a prefix."
  }
}
