terraform {
  required_version = "~> 1.10" # 1.10+ for S3 native state locking

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.68"
    }
  }

  # This stack creates the state bucket, so it starts with local state.
  # After the first apply, uncomment this block, fill it in from the
  # `backend_config` output, and run `terraform init -migrate-state`.
  #
  # backend "s3" {
  #   bucket       = "<state_bucket_name>"
  #   key          = "bootstrap-state/terraform.tfstate"
  #   region       = "<region>"
  #   encrypt      = true
  #   use_lockfile = true
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}
