# Offline plan with mocked providers: terraform init -backend=false && terraform test
mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111122223333" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{}" }
  }
}

variables {
  project     = "example"
  environment = "dev"
  region      = "us-east-1"
  owner       = "platform-team"
}

run "jwt_auth_on_every_route" {
  command = plan
  variables {
    jwt_issuer   = "https://issuer.example.com"
    jwt_audience = ["client"]
  }

  assert {
    condition     = alltrue([for r in aws_apigatewayv2_route.items : r.authorization_type == "JWT"])
    error_message = "Every route should require a JWT when an issuer is set."
  }
}

run "no_issuer_means_open_api" {
  command = plan

  assert {
    condition     = length(aws_apigatewayv2_authorizer.jwt) == 0 && alltrue([for r in aws_apigatewayv2_route.items : r.authorization_type == "NONE"])
    error_message = "Without an issuer there should be no authorizer."
  }
  assert {
    condition     = aws_dynamodb_table.items.point_in_time_recovery[0].enabled
    error_message = "Point-in-time recovery should be on."
  }
}
