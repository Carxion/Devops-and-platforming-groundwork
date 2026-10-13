# Run from terraform/: tflint --init && tflint --recursive --config "$(pwd)/.tflint.hcl"
config {
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.49.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

plugin "azurerm" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

# Every variable and output should say what it's for.
rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = false # many outputs are self-describing IDs and names
}

# Auto-heal restarts can mask application faults; health_check_path already
# takes unhealthy instances out of rotation.
rule "azurerm_app_service_missing_auto_heal_setting" {
  enabled = false
}
