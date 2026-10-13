# Offline plan with mocked providers: terraform init -backend=false && terraform test
mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{}" }
  }
}

variables {
  project            = "example"
  environment        = "dev"
  region             = "us-east-1"
  owner              = "platform-team"
  vpc_id             = "vpc-0123456789abcdef0"
  public_subnet_ids  = ["subnet-0aaa", "subnet-0bbb"]
  private_subnet_ids = ["subnet-0ccc", "subnet-0ddd"]
  certificate_arn    = "arn:aws:acm:us-east-1:111122223333:certificate/00000000-0000-0000-0000-000000000000"
  container_image    = "111122223333.dkr.ecr.us-east-1.amazonaws.com/web:1.0.0"
}

run "secure_defaults" {
  command = plan

  assert {
    condition     = length(aws_wafv2_web_acl.main) == 1 && length(aws_wafv2_web_acl_association.main) == 1
    error_message = "WAF should be attached by default."
  }
  assert {
    condition     = aws_lb_listener.http_redirect.default_action[0].type == "redirect"
    error_message = "Port 80 must only redirect."
  }
  assert {
    condition     = aws_ecr_repository.app.image_tag_mutability == "IMMUTABLE"
    error_message = "Image tags must be immutable."
  }
  assert {
    condition     = jsondecode(aws_ecs_task_definition.app.container_definitions)[0].readonlyRootFilesystem
    error_message = "Containers should run with a read-only root filesystem."
  }
  assert {
    condition     = aws_ecs_service.app.network_configuration[0].assign_public_ip == false
    error_message = "Tasks must not get public IPs."
  }
}

run "waf_optional" {
  command = plan
  variables {
    enable_waf = false
  }

  assert {
    condition     = length(aws_wafv2_web_acl.main) == 0
    error_message = "WAF should be removable."
  }
}
