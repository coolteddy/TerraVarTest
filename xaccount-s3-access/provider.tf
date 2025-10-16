
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    #   version = "~> 5.0"
      version = ">= 5.0, < 5.100.0" # or pin exactly: = 5.99.1
    }
  }
}

############################################
# Providers: B = default (terraform admin user), A = assume role
############################################
provider "aws" {
  region = var.region
  # Auth for Account B comes from your shell (profile/SSO/env vars)
}

provider "aws" {
  alias  = "account_a"
  region = var.region

  # Assumes into Account A using an existing admin role there
  assume_role {
    role_arn     = "arn:aws:iam::${var.account_a_id}:role/${var.account_a_admin_role_name}"
    session_name = "tf-cross-setup"
  }
}