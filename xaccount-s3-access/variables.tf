############################################
# Inputs
############################################
variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "account_a_id" {
  description = "12-digit Account A ID"
  type        = string
}

variable "account_a_admin_role_name" {
  description = "Role name in Account A that your Account B creds can assume"
  type        = string
  default     = "OrganizationAccountAccessRole"
}

variable "bucket_name" {
  description = "Globally-unique S3 bucket name to create in Account A"
  type        = string
}

variable "new_user_name_b" {
  description = "Name of the new IAM user to create in Account B"
  type        = string
  default     = "export-reader"
}

variable "export_prefix" {
  description = "Prefix inside the bucket to allow reading"
  type        = string
  default     = "export/"
}

locals {
  tags = { Project = "xacct-export-read", Owner = "coolteddy", Env = "demo" }
}