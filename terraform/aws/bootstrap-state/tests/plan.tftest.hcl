# Offline plan with mocked providers: terraform init -backend=false && terraform test
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111122223333" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
}

variables {
  project = "example"
  region  = "us-east-1"
  owner   = "platform-team"
}

run "state_bucket_is_hardened" {
  command = plan

  assert {
    condition     = aws_s3_bucket.state.bucket == "example-tfstate-111122223333-us-east-1"
    error_message = "Bucket name should include project, account, and region."
  }
  assert {
    condition     = aws_s3_bucket_versioning.state.versioning_configuration[0].status == "Enabled"
    error_message = "State bucket must be versioned."
  }
  assert {
    condition     = aws_s3_bucket_public_access_block.state.block_public_acls && aws_s3_bucket_public_access_block.state.restrict_public_buckets
    error_message = "Public access must be blocked."
  }
}

run "rejects_invalid_project" {
  command = plan
  variables {
    project = "Not_Valid"
  }
  expect_failures = [var.project]
}
