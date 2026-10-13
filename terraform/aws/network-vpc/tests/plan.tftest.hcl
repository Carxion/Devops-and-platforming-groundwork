# Offline plan with mocked providers: terraform init -backend=false && terraform test
mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{}" }
  }
}

variables {
  project            = "example"
  environment        = "dev"
  region             = "us-east-1"
  owner              = "platform-team"
  vpc_cidr           = "10.20.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

run "three_tiers_per_az" {
  command = plan

  assert {
    condition     = length(aws_subnet.public) == 3 && length(aws_subnet.private) == 3 && length(aws_subnet.isolated) == 3
    error_message = "Expected one subnet per tier per AZ."
  }
  assert {
    condition     = aws_subnet.public[0].cidr_block == "10.20.0.0/20" && aws_subnet.private[0].cidr_block == "10.20.64.0/20" && aws_subnet.isolated[0].cidr_block == "10.20.128.0/20"
    error_message = "Tier CIDR layout changed; existing VPCs would be replaced."
  }
  assert {
    condition     = length(aws_nat_gateway.main) == 3
    error_message = "Expected one NAT gateway per AZ by default."
  }
  assert {
    condition     = aws_flow_log.main.traffic_type == "ALL"
    error_message = "Flow logs should capture all traffic."
  }
}

run "single_nat_gateway" {
  command = plan
  variables {
    single_nat_gateway = true
  }

  assert {
    condition     = length(aws_nat_gateway.main) == 1 && length(aws_route.private_nat) == 3
    error_message = "Expected one shared NAT gateway with a route from every private subnet."
  }
}

run "rejects_one_az" {
  command = plan
  variables {
    availability_zones = ["us-east-1a"]
  }
  expect_failures = [var.availability_zones]
}
