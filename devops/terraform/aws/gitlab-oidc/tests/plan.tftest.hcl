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
  project             = "example"
  region              = "us-west-2"
  owner               = "platform-team"
  gitlab_project_path = "example-group/infra/example-infra"
  state_bucket_arn    = "arn:aws-test:s3:::example-tfstate"
  state_kms_key_arn   = "arn:aws-test:kms:us-west-2:111122223333:key/00000000-0000-0000-0000-000000000000"
  apply_policy_arns   = ["arn:aws-test:iam::111122223333:policy/apply"]
}

run "subjects_scoped_to_project_and_branch" {
  command = plan

  assert {
    condition     = output.trusted_subjects.plan == ["project_path:example-group/infra/example-infra:ref_type:branch:ref:*"]
    error_message = "Plan role should trust any branch of this project, and nothing else."
  }
  assert {
    condition     = output.trusted_subjects.apply == "project_path:example-group/infra/example-infra:ref_type:branch:ref:main"
    error_message = "Apply role should trust only the main branch."
  }
  assert {
    condition     = aws_iam_openid_connect_provider.gitlab[0].url == "https://gitlab.com"
    error_message = "Issuer should default to GitLab.com."
  }
  assert {
    condition     = aws_iam_openid_connect_provider.gitlab[0].client_id_list == toset(["sts.amazonaws.com"])
    error_message = "The provider's client ID list should be the audience."
  }
  assert {
    condition     = keys(aws_iam_role_policy_attachment.plan) == ["arn:aws-test:iam::aws:policy/ReadOnlyAccess"]
    error_message = "Default plan policy should use the current partition."
  }
}

run "self_managed_issuer_and_custom_branch" {
  command = plan
  variables {
    gitlab_url           = "https://gitlab.example.com"
    apply_branch         = "release/prod"
    create_oidc_provider = false
  }

  assert {
    condition     = output.trusted_subjects.apply == "project_path:example-group/infra/example-infra:ref_type:branch:ref:release/prod"
    error_message = "Apply subject should use the configured branch."
  }
  assert {
    condition     = length(aws_iam_openid_connect_provider.gitlab) == 0
    error_message = "Should look up the existing provider instead of creating one."
  }
}

run "rejects_wildcard_apply_branch" {
  command = plan
  variables {
    apply_branch = "*"
  }
  expect_failures = [var.apply_branch]
}

run "rejects_bad_project_path" {
  command = plan
  variables {
    gitlab_project_path = "just-a-group"
  }
  expect_failures = [var.gitlab_project_path]
}

run "rejects_trailing_slash_url" {
  command = plan
  variables {
    gitlab_url = "https://gitlab.com/"
  }
  expect_failures = [var.gitlab_url]
}
