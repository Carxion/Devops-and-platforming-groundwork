# Short-lived AWS credentials for GitLab CI/CD through OIDC (ID tokens), with
# no stored access keys. Two roles:
#
#   plan:  assumable from any branch of one project (merge request pipelines
#          run on the source branch); read-only, plus the state access that
#          `terraform plan` needs (read state, write the lock file)
#   apply: assumable only from pipelines on one protected branch
#
# GitLab's sub claim is project_path:<group>/<project>:ref_type:<type>:ref:<ref>.
# It names the branch, not the environment, so the apply role is only as safe
# as that branch's protection: protect it, and require merge request approval.
# On GitLab Self-Managed, AWS can match only sub and aud.

data "aws_partition" "current" {}

locals {
  tags = merge(var.tags, {
    Project   = var.project
    Owner     = var.owner
    ManagedBy = "terraform"
    Stack     = "gitlab-oidc"
  })

  # The issuer host, as AWS names the condition keys: "gitlab.com:sub".
  gitlab_host = trimprefix(var.gitlab_url, "https://")
  subject     = "project_path:${var.gitlab_project_path}:ref_type"

  plan_subjects = concat(["${local.subject}:branch:ref:*"], var.plan_additional_subjects)
  apply_subject = "${local.subject}:branch:ref:${var.apply_branch}"

  plan_policy_arns = coalesce(var.plan_policy_arns, ["arn:${data.aws_partition.current.partition}:iam::aws:policy/ReadOnlyAccess"])

  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.gitlab[0].arn : data.aws_iam_openid_connect_provider.gitlab[0].arn
}

resource "aws_iam_openid_connect_provider" "gitlab" {
  count = var.create_oidc_provider ? 1 : 0

  url            = var.gitlab_url
  client_id_list = [var.audience]
}

data "aws_iam_openid_connect_provider" "gitlab" {
  count = var.create_oidc_provider ? 0 : 1
  url   = var.gitlab_url
}

data "aws_iam_policy_document" "trust" {
  for_each = {
    # StringLike for plan: its subject ends in a branch wildcard.
    plan  = { test = "StringLike", subjects = local.plan_subjects }
    apply = { test = "StringEquals", subjects = [local.apply_subject] }
  }

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.gitlab_host}:aud"
      values   = [var.audience]
    }

    condition {
      test     = each.value.test
      variable = "${local.gitlab_host}:sub"
      values   = each.value.subjects
    }

    # GitLab.com only: pin to the project's numeric ID too, so a renamed or
    # transferred path can't inherit the trust.
    dynamic "condition" {
      for_each = var.gitlab_project_id == null ? [] : [var.gitlab_project_id]
      content {
        test     = "StringEquals"
        variable = "${local.gitlab_host}:project_id"
        values   = [tostring(condition.value)]
      }
    }
  }
}

# --- Plan role ---------------------------------------------------------------

resource "aws_iam_role" "plan" {
  name                 = "${var.project}-gitlab-plan"
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
  name                 = "${var.project}-gitlab-apply"
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
