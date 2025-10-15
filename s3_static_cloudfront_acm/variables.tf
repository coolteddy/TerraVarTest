############################################
# Inputs
############################################
variable "region" {
  description = "Deployment region for S3/Route53 helpers (not CloudFront)"
  type        = string
  default     = "eu-west-1"
}

variable "domain_name" {
  description = "Fully-qualified domain (e.g. example.com or www.example.com)"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 Hosted Zone ID that matches domain_name"
  type        = string
}
