# Dev environment — inherits root config

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../modules/ssm-parameter"
}

inputs = {
  env         = "dev"
  param_name  = "/myapp/dev/database_url"
  param_value = "postgres://dev-db:5432/myapp"
}
