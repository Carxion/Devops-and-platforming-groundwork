# Short-lived Azure credentials for GitLab CI/CD through workload identity
# federation (ID tokens), with no client secrets. Two Entra ID applications:
#
#   plan:  federated to the branches in plan_branches; Reader on the scope,
#          plus state access (plan takes a blob lease to lock state, so it
#          needs write)
#   apply: federated only to pipelines on one protected branch
#
# GitLab's sub claim is project_path:<group>/<project>:ref_type:<type>:ref:<ref>.
# A standard federated credential matches one exact subject, and merge request
# pipelines run on their source branch, so planning every merge request needs
# plan_any_branch: a flexible federated credential, which is in preview.

data "azurerm_subscription" "current" {}

locals {
  scope    = coalesce(var.scope_id, data.azurerm_subscription.current.id)
  audience = "api://AzureADTokenExchange"
  subject  = "project_path:${var.gitlab_project_path}:ref_type:branch:ref"

  roles = {
    plan  = "Reader"
    apply = var.apply_role_definition_name
  }

  # One exact-match credential each: the plan branches, and the apply branch.
  credentials = merge(
    { for branch in var.plan_branches : "plan-${branch}" => { app = "plan", subject = "${local.subject}:${branch}" } },
    { apply = { app = "apply", subject = "${local.subject}:${var.apply_branch}" } },
  )
}

resource "azuread_application" "gitlab" {
  for_each = local.roles

  display_name = "${var.project}-gitlab-${each.key}"
  notes        = "GitLab CI/CD ${each.key} identity for ${var.gitlab_project_path}. Owner: ${var.owner}. Managed by Terraform."
}

resource "azuread_service_principal" "gitlab" {
  for_each = local.roles

  client_id = azuread_application.gitlab[each.key].client_id
}

resource "azuread_application_federated_identity_credential" "gitlab" {
  #checkov:skip=CKV_AZURE_249:Subjects are exact project- and branch-scoped claims built from validated variables; checkov can't resolve for_each values.
  for_each = local.credentials

  application_id = azuread_application.gitlab[each.value.app].id
  display_name   = "gitlab-${substr(sha1(each.key), 0, 12)}"
  description    = "GitLab CI/CD: ${each.value.subject}"
  issuer         = var.gitlab_url
  subject        = each.value.subject
  audiences      = [local.audience]
}

# Preview: one credential matching every branch of the project, so plan runs in
# any merge request pipeline. The plan identity is read-only on the scope.
resource "azuread_application_flexible_federated_identity_credential" "plan_any_branch" {
  count = var.plan_any_branch ? 1 : 0

  application_id             = azuread_application.gitlab["plan"].id
  display_name               = "gitlab-plan-any-branch"
  description                = "GitLab CI/CD: any branch of ${var.gitlab_project_path}"
  issuer                     = var.gitlab_url
  audience                   = local.audience
  claims_matching_expression = "claims['sub'] matches '${local.subject}:*'"
}

resource "azurerm_role_assignment" "scope" {
  for_each = local.roles

  scope                = local.scope
  role_definition_name = each.value
  principal_id         = azuread_service_principal.gitlab[each.key].object_id
}

resource "azurerm_role_assignment" "state" {
  for_each = local.roles

  scope                = var.state_storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.gitlab[each.key].object_id
}
