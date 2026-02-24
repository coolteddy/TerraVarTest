# Root config — inherited by all environments

locals {
  account_id = get_aws_account_id()
  region     = "eu-west-2"
}

# Auto-create S3 bucket + DynamoDB table for remote state
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "terragrunt-state-${local.account_id}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.region
    encrypt      = true
    use_lockfile = true

    s3_bucket_tags = {
      ManagedBy = "terragrunt"
    }
  }
}

# Generate provider.tf in each environment automatically
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.region}"
}
EOF
}
