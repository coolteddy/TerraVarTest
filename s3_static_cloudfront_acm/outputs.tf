############################################
# Outputs
############################################
output "site_domain" {
  value       = "https://${var.domain_name}"
  description = "Your website URL"
}

output "cloudfront_domain" {
  value       = aws_cloudfront_distribution.cdn.domain_name
  description = "CloudFront domain (useful before DNS propagates)"
}

output "bucket" {
  value = aws_s3_bucket.site.bucket
}
