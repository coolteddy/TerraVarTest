############################
# Outputs
############################
output "alb_dns_name" {
  value       = aws_lb.alb.dns_name
  description = "Public URL for the application."
}

output "rds_endpoint" {
  value       = aws_db_instance.main.endpoint
  description = "RDS instance endpoint"
  sensitive   = true
}