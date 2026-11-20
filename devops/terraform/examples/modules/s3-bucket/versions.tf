terraform {
  # A module states the oldest versions it works with. The root module that
  # calls it pins exact versions through its lock file.
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}
