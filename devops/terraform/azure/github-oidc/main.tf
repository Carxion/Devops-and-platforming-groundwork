# Short-lived Azure credentials for GitHub Actions through workload
# identity federation, with no client secrets. Two Entra ID applications:
#
#   plan:  federated to pull requests; Reader on the scope, plus state access
#          (plan takes a blob lease to lock state, so it needs write)
#   apply: federated only to jobs in a protected GitHub environment
#
# Each federated credential matches one exact `sub` claim.

data "azurerm_subscription" "current" {}

locals {
  scope  = coalesce(var.scope_id, data.azurerm_subscription.current.id)
  issuer = "https://token.actions.githubusercontent.com"

  identities = {
    plan = {
      subject = "repo:${var.github_repository}:pull_request"
      role    = "Reader"
    }
    apply = {
      subject = "repo:${var.github_repository}:environment:${var.apply_environment}"
      role    = var.apply_role_definition_name
    }
  }
}

resource "azuread_application" "github" {
  for_each = local.identities

  display_name = "${var.project}-github-${each.key}"
  notes        = "GitHub Actions ${each.key} identity for ${var.github_repository}. Owner: ${var.owner}. Managed by Terraform."
}

resource "azuread_service_principal" "github" {
  for_each = local.identities

  client_id = azuread_application.github[each.key].client_id
}

resource "azuread_application_federated_identity_credential" "github" {
  #checkov:skip=CKV_AZURE_249:Subjects are exact repo-scoped claims built from a validated owner/name; checkov can't resolve for_each values.
  for_each = local.identities

  application_id = azuread_application.github[each.key].id
  display_name   = "github-${each.key}"
  description    = "GitHub Actions: ${each.value.subject}"
  issuer         = local.issuer
  subject        = each.value.subject
  audiences      = ["api://AzureADTokenExchange"]
}

resource "azurerm_role_assignment" "scope" {
  for_each = local.identities

  scope                = local.scope
  role_definition_name = each.value.role
  principal_id         = azuread_service_principal.github[each.key].object_id
}

resource "azurerm_role_assignment" "state" {
  for_each = local.identities

  scope                = var.state_storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.github[each.key].object_id
}

# Extra subjects for the plan identity (for example drift detection on main).
resource "azuread_application_federated_identity_credential" "plan_additional" {
  #checkov:skip=CKV_AZURE_249:Subjects come from plan_additional_subjects; review them like any trust change.
  for_each = toset(var.plan_additional_subjects)

  application_id = azuread_application.github["plan"].id
  display_name   = "github-plan-${substr(sha1(each.value), 0, 8)}"
  description    = "GitHub Actions: ${each.value}"
  issuer         = local.issuer
  subject        = each.value
  audiences      = ["api://AzureADTokenExchange"]
}
