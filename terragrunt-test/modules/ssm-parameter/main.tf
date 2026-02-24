resource "aws_ssm_parameter" "this" {
  name  = var.param_name
  type  = "String"
  value = var.param_value

  tags = {
    Environment = var.env
    ManagedBy   = "terragrunt"
  }
}
