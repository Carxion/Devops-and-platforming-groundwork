# Short-lived AWS credentials for GitHub Actions through OIDC, with no
# stored access keys. Two roles:
#
#   plan:  assumable from pull requests; read-only, plus the state access
#          that `terraform plan` needs (read state, write the lock file)
#   apply: assumable only from jobs in a protected GitHub environment
#
# Trust is scoped to one repository using the exact `sub` claim, never a
# wildcard on the organization.

data "aws_partition" "current" {}

locals {
  tags = merge(var.tags, {
    Project   = var.project
    Owner     = var.owner
    ManagedBy = "terraform"
    Stack     = "github-oidc"
  })

  github_host = "token.actions.githubusercontent.com"

  plan_policy_arns = coalesce(var.plan_policy_arns, ["arn:${data.aws_partition.current.partition}:iam::aws:policy/ReadOnlyAccess"])

  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = "https://${local.github_host}"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://${local.github_host}"
}

data "aws_iam_policy_document" "trust" {
  for_each = {
    plan  = concat(["repo:${var.github_repository}:pull_request"], var.plan_additional_subjects)
    apply = ["repo:${var.github_repository}:environment:${var.apply_environment}"]
  }

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_host}:sub"
      values   = each.value
    }
  }
}

# --- Plan role ---------------------------------------------------------------

resource "aws_iam_role" "plan" {
  name                 = "${var.project}-github-plan"
  assume_role_policy   = data.aws_iam_policy_document.trust["plan"].json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "plan" {
  for_each   = toset(local.plan_policy_arns)
  role       = aws_iam_role.plan.name
  policy_arn = each.value
}

data "aws_iam_policy_document" "plan_state" {
  statement {
    sid       = "ListState"
    actions   = ["s3:ListBucket"]
    resources = [var.state_bucket_arn]
  }

  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = ["${var.state_bucket_arn}/*"]
  }

  statement {
    sid       = "Lock"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.state_bucket_arn}/*.tflock"]
  }

  statement {
    sid       = "StateKey"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey"]
    resources = [var.state_kms_key_arn]
  }
}

resource "aws_iam_role_policy" "plan_state" {
  name   = "terraform-state"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan_state.json
}

# --- Apply role --------------------------------------------------------------

resource "aws_iam_role" "apply" {
  name                 = "${var.project}-github-apply"
  assume_role_policy   = data.aws_iam_policy_document.trust["apply"].json
  max_session_duration = 3600
  permissions_boundary = var.apply_permissions_boundary_arn
}

resource "aws_iam_role_policy_attachment" "apply" {
  for_each   = toset(var.apply_policy_arns)
  role       = aws_iam_role.apply.name
  policy_arn = each.value
}

data "aws_iam_policy_document" "apply_state" {
  statement {
    sid       = "ListState"
    actions   = ["s3:ListBucket"]
    resources = [var.state_bucket_arn]
  }

  statement {
    sid       = "ReadWriteState"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.state_bucket_arn}/*"]
  }

  statement {
    sid       = "StateKey"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey"]
    resources = [var.state_kms_key_arn]
  }
}

resource "aws_iam_role_policy" "apply_state" {
  name   = "terraform-state"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply_state.json
}
