# Offline plan with mocked providers: terraform init -backend=false && terraform test
mock_provider "azurerm" {
  mock_data "azurerm_subscription" {
    defaults = {
      id              = "/subscriptions/00000000-0000-0000-0000-000000000000"
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "00000000-0000-0000-0000-000000000001"
    }
  }
}

mock_provider "azuread" {
  mock_resource "azuread_application" {
    defaults = {
      id        = "/applications/00000000-0000-0000-0000-000000000008"
      client_id = "00000000-0000-0000-0000-000000000009"
    }
  }
  mock_resource "azuread_service_principal" {
    defaults = { object_id = "00000000-0000-0000-0000-00000000000a" }
  }
}

variables {
  project                  = "example"
  subscription_id          = "00000000-0000-0000-0000-000000000000"
  owner                    = "platform-team"
  github_repository        = "example-org/example-infra"
  state_storage_account_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/st"
}

run "exact_subjects_and_least_privilege_plan" {
  command = plan

  assert {
    condition     = azuread_application_federated_identity_credential.github["plan"].subject == "repo:example-org/example-infra:pull_request"
    error_message = "Plan identity should trust pull requests from this repository only."
  }
  assert {
    condition     = azuread_application_federated_identity_credential.github["apply"].subject == "repo:example-org/example-infra:environment:production"
    error_message = "Apply identity should trust only the protected environment."
  }
  assert {
    condition     = azurerm_role_assignment.scope["plan"].role_definition_name == "Reader"
    error_message = "Plan identity should be read-only on the scope."
  }
  assert {
    condition     = azurerm_role_assignment.scope["apply"].scope == "/subscriptions/00000000-0000-0000-0000-000000000000"
    error_message = "Scope should default to the subscription."
  }
}

run "drift_detection_subject_opt_in" {
  command = plan
  variables {
    plan_additional_subjects = ["repo:example-org/example-infra:ref:refs/heads/main"]
  }

  assert {
    condition     = length(azuread_application_federated_identity_credential.plan_additional) == 1
    error_message = "Each additional subject should get its own federated credential on the plan app."
  }
}
