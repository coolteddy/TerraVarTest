output "parameter_name" {
  value = aws_ssm_parameter.this.name
}

output "parameter_arn" {
  value = aws_ssm_parameter.this.arn
}
