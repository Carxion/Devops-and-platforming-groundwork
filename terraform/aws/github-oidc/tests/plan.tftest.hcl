# Offline plan with mocked providers: terraform init -backend=false && terraform test
mock_provider "aws" {
  mock_data "aws_partition" {
    # A non-default partition, to prove ARNs use the partition instead of a hard-coded "aws".
    defaults = { partition = "aws-test" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{}" }
  }
}

variables {
  project           = "example"
  region            = "us-west-2"
  owner             = "platform-team"
  github_repository = "example-org/example-infra"
  state_bucket_arn  = "arn:aws-test:s3:::example-tfstate"
  state_kms_key_arn = "arn:aws-test:kms:us-west-2:111122223333:key/00000000-0000-0000-0000-000000000000"
  apply_policy_arns = ["arn:aws-test:iam::111122223333:policy/apply"]
}

run "default_plan_policy_follows_partition" {
  command = plan

  assert {
    condition     = keys(aws_iam_role_policy_attachment.plan) == ["arn:aws-test:iam::aws:policy/ReadOnlyAccess"]
    error_message = "Default plan policy should use the current partition."
  }
  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 1
    error_message = "OIDC provider should be created by default."
  }
}

run "reuse_existing_oidc_provider" {
  command = plan
  variables {
    create_oidc_provider = false
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 0
    error_message = "Should look up the existing provider instead of creating one."
  }
}

run "rejects_bad_repository" {
  command = plan
  variables {
    github_repository = "example-org"
  }
  expect_failures = [var.github_repository]
}
