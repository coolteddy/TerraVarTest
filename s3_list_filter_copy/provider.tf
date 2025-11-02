
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
      # version = ">= 5.0, < 5.100.0" # or pin exactly: = 5.99.1
    }
  }
}

# Your account’s working region
provider "aws" {
  region = var.region
}
