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
  gitlab_project_path      = "example-group/example-infra"
  state_storage_account_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/st"
}

run "exact_subjects_and_least_privilege_plan" {
  command = plan

  assert {
    condition     = azuread_application_federated_identity_credential.gitlab["plan-main"].subject == "project_path:example-group/example-infra:ref_type:branch:ref:main"
    error_message = "Plan identity should trust the main branch of this project."
  }
  assert {
    condition     = azuread_application_federated_identity_credential.gitlab["apply"].subject == "project_path:example-group/example-infra:ref_type:branch:ref:main"
    error_message = "Apply identity should trust only the apply branch."
  }
  assert {
    condition     = azuread_application_federated_identity_credential.gitlab["apply"].issuer == "https://gitlab.com"
    error_message = "Issuer should default to GitLab.com."
  }
  assert {
    condition     = length(azuread_application_flexible_federated_identity_credential.plan_any_branch) == 0
    error_message = "The preview any-branch credential should be off by default."
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

run "plan_in_every_merge_request" {
  command = plan
  variables {
    gitlab_url      = "https://gitlab.example.com"
    plan_branches   = ["main", "develop"]
    plan_any_branch = true
  }

  assert {
    condition     = length([for k, v in azuread_application_federated_identity_credential.gitlab : k if startswith(k, "plan-")]) == 2
    error_message = "Each plan branch should get its own exact credential."
  }
  assert {
    condition     = azuread_application_flexible_federated_identity_credential.plan_any_branch[0].claims_matching_expression == "claims['sub'] matches 'project_path:example-group/example-infra:ref_type:branch:ref:*'"
    error_message = "The any-branch credential should match every branch of this project only."
  }
  assert {
    condition     = azuread_application_flexible_federated_identity_credential.plan_any_branch[0].issuer == "https://gitlab.example.com"
    error_message = "The issuer should follow gitlab_url."
  }
}

run "rejects_wildcard_branches" {
  command = plan
  variables {
    plan_branches = ["feature/*"]
    apply_branch  = "*"
  }
  expect_failures = [var.plan_branches, var.apply_branch]
}
