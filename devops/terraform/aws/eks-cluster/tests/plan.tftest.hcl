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
  project                      = "example"
  environment                  = "dev"
  region                       = "us-east-1"
  owner                        = "platform-team"
  kubernetes_version           = "1.34"
  private_subnet_ids           = ["subnet-0ccc", "subnet-0ddd"]
  cluster_admin_principal_arns = ["arn:aws:iam::111122223333:role/admin-a", "arn:aws:iam::111122223333:role/admin-b"]
}

run "private_api_and_access_entries" {
  command = plan

  assert {
    condition     = aws_eks_cluster.main.vpc_config[0].endpoint_public_access == false
    error_message = "API endpoint should be private by default."
  }
  assert {
    condition     = aws_eks_cluster.main.access_config[0].authentication_mode == "API"
    error_message = "Use access entries, not the aws-auth ConfigMap."
  }
  assert {
    condition     = length(aws_eks_access_policy_association.admins) == 2
    error_message = "Each admin principal needs an access policy association."
  }
  assert {
    condition     = jsondecode(aws_eks_addon.vpc_cni.configuration_values).enableNetworkPolicy == "true"
    error_message = "VPC CNI must enforce NetworkPolicy, or policies are silently ignored."
  }
  assert {
    condition     = aws_launch_template.node.metadata_options[0].http_tokens == "required"
    error_message = "Nodes must enforce IMDSv2."
  }
}
