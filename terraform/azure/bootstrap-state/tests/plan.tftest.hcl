# Offline plan with mocked providers: terraform init -backend=false && terraform test
mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id = "00000000-0000-0000-0000-000000000001"
      object_id = "00000000-0000-0000-0000-000000000002"
    }
  }
}

mock_provider "random" {}

variables {
  project         = "example"
  subscription_id = "00000000-0000-0000-0000-000000000000"
  location        = "eastus2"
  owner           = "platform-team"
}

run "entra_only_and_recoverable" {
  command = plan

  assert {
    condition     = azurerm_storage_account.state.shared_access_key_enabled == false
    error_message = "Shared keys must be disabled; state access is Entra ID only."
  }
  assert {
    condition     = azurerm_storage_account.state.blob_properties[0].versioning_enabled
    error_message = "Blob versioning must be on so old state can be recovered."
  }
  assert {
    condition     = keys(azurerm_role_assignment.state_contributors) == ["00000000-0000-0000-0000-000000000002"]
    error_message = "The identity running the stack should get state access."
  }
}

run "firewall_denies_when_ips_given" {
  command = plan
  variables {
    allowed_ip_ranges = ["203.0.113.10"]
  }

  assert {
    condition     = azurerm_storage_account.state.network_rules[0].default_action == "Deny"
    error_message = "Default action should be Deny once allowed IPs are set."
  }
}
