############################################
# S3 bucket (private) to hold the website
############################################
resource "aws_s3_bucket" "site" {
  bucket = var.domain_name
  tags   = { Project = "static-site", Owner = "Thet" }
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id
  rule { object_ownership = "BucketOwnerPreferred" }
}

# Optional: a sample index.html so the site works post-apply
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.site.id
  key          = "index.html"
  content_type = "text/html"
  content      = <<HTML
<!doctype html>
<html>
  <head><meta charset="utf-8"><title>${var.domain_name}</title></head>
  <body style="font-family:system-ui;padding:3rem;text-align:center">
    <h1>Deployed via Terraform </h1>
    <p>Hello from <b>${var.domain_name}</b></p>
  </body>
</html>
HTML
}

############################################
# ACM certificate (must be in us-east-1)
############################################
resource "aws_acm_certificate" "cert" {
  provider          = aws.use1
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Create Route53 DNS validation records
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = var.hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.value]
  ttl     = 60
}

# Wait for validation
resource "aws_acm_certificate_validation" "cert" {
  provider                = aws.use1
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

############################################
# CloudFront + OAC (secure S3 origin)
############################################
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.domain_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
  description                       = "OAC for ${var.domain_name}"
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Static site for ${var.domain_name}"
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-origin-${aws_s3_bucket.site.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    s3_origin_config {
      origin_access_identity = "" # Required, but empty when using OAC
    }
  }

  default_cache_behavior {
    target_origin_id       = "s3-origin-${aws_s3_bucket.site.id}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  depends_on = [aws_acm_certificate_validation.cert]
}

# Bucket policy to allow CloudFront (via OAC) to read objects
resource "aws_s3_bucket_policy" "allow_cf" {
  bucket = aws_s3_bucket.site.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid:    "AllowCloudFrontServicePrincipalRead",
        Effect: "Allow",
        Principal: { Service: "cloudfront.amazonaws.com" },
        Action: ["s3:GetObject"],
        Resource: "${aws_s3_bucket.site.arn}/*",
        Condition: {
          StringEquals: {
            "AWS:SourceArn": aws_cloudfront_distribution.cdn.arn
          }
        }
      }
    ]
  })
}

############################################
# Route53 alias -> CloudFront
############################################
# CloudFront hosted zone ID is always Z2FDTNDATAQYW2 (global)
locals {
  cloudfront_zone_id = "Z2FDTNDATAQYW2"
}

resource "aws_route53_record" "alias" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }
}