# Prod environment — inherits root config

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../modules/ssm-parameter"
}

inputs = {
  env         = "prod"
  param_name  = "/myapp/prod/database_url"
  param_value = "postgres://prod-db:5432/myapp"
}
