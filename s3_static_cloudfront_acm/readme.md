# Resource-by-Resource Explanation



This section explains each Terraform resource used to build a secure S3 static website with CloudFront and ACM SSL, with deeper technical details:

1. **aws_s3_bucket**
	- Creates a private S3 bucket to store your website files.
	- Bucket names must be globally unique and DNS-compliant.
	- Versioning, encryption, and lifecycle rules can be added for advanced use cases.
	- S3 buckets are region-specific; choose a region close to your users for lower latency.

2. **aws_s3_bucket_public_access_block**
	- Configures four settings to block public access via ACLs and bucket policies.
	- Prevents accidental exposure from misconfigured permissions.
	- Essential for compliance and security best practices.

3. **aws_s3_bucket_ownership_controls**
	- Controls object ownership, especially important when objects are uploaded by different AWS principals.
	- "BucketOwnerPreferred" ensures the bucket owner has full control, avoiding cross-account access issues.

4. **aws_s3_object**
	- Manages individual files in the bucket, such as `index.html`.
	- Supports metadata, content type, and server-side encryption.
	- Can be used to automate deployment of site assets.

5. **aws_acm_certificate**
	- Requests a public SSL/TLS certificate for your domain.
	- Must be created in `us-east-1` for CloudFront compatibility (even if your resources are elsewhere).
	- DNS validation is automated and secure; email validation is also available but less common.
	- Certificates are free and auto-renewed by AWS.

6. **aws_route53_record (cert_validation)**
	- Creates CNAME records in Route53 for ACM to verify domain ownership.
	- Terraform uses `for_each` to handle multiple validation options (e.g., for SANs).
	- TTL is set low for fast propagation, but DNS changes may still take minutes to hours.

7. **aws_acm_certificate_validation**
	- Waits for ACM to detect the DNS records and validate the certificate.
	- Ensures the certificate is active before CloudFront uses it.
	- Terraform will block until validation is complete, ensuring a reliable workflow.

8. **aws_cloudfront_origin_access_control**
	- Creates an Origin Access Control (OAC) for CloudFront to securely access S3.
	- OAC uses SigV4 signing for requests, replacing the older OAI method.
	- Prevents direct public access to S3, enforcing access only via CloudFront.

9. **aws_cloudfront_distribution**
	- Configures a global CDN for your static site.
	- "origin" block connects to S3 using OAC; "default_cache_behavior" sets caching, compression, and HTTPS redirects.
	- "viewer_certificate" attaches the ACM certificate for SSL.
	- "price_class" controls which edge locations are used (e.g., `PriceClass_100` is US/EU only, cheaper).
	- "restrictions" can limit access by geography if needed.
	- "depends_on" ensures CloudFront waits for ACM validation.

10. **aws_s3_bucket_policy**
	 - Defines a JSON policy allowing CloudFront (with OAC) to read objects from S3.
	 - Uses the `AWS:SourceArn` condition to restrict access to only your CloudFront distribution.
	 - Prevents all other principals from accessing the bucket, even if they have AWS credentials.

11. **aws_route53_record (alias)**
	 - Creates an "A" record alias pointing your domain to the CloudFront distribution.
	 - Uses the global CloudFront hosted zone ID (`Z2FDTNDATAQYW2`).
	 - "evaluate_target_health" is set to false since CloudFront handles health checks internally.

**Summary:**
- S3 provides secure, scalable storage for your site files.
- ACM automates SSL certificate management and renewal.
- CloudFront delivers your site with low latency, caching, compression, and HTTPS.
- Route53 integrates your custom domain with the CDN.
- The architecture is highly secure, cost-effective, and production-ready for static sites.
