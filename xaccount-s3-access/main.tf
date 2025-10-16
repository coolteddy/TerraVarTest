############################################
# Account B: create the new user
############################################
resource "aws_iam_user" "b_user" {
  name = var.new_user_name_b
  tags = { Purpose = "Assume-AccountA-ExportReader" }
}

############################################
# Account A: bucket + role that trusts B user
############################################
# Bucket (private) in Account A
resource "aws_s3_bucket" "a_bucket" {
  provider = aws.account_a
  bucket   = var.bucket_name
  tags     = local.tags
}

resource "aws_s3_bucket_public_access_block" "a_block" {
  provider                = aws.account_a
  bucket                  = aws_s3_bucket.a_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "a_own" {
  provider = aws.account_a
  bucket   = aws_s3_bucket.a_bucket.id
  rule { object_ownership = "BucketOwnerPreferred" }
}

# Sample object under export/ to test
resource "aws_s3_object" "a_sample" {
  provider     = aws.account_a
  bucket       = aws_s3_bucket.a_bucket.id
  key          = "${var.export_prefix}hello.txt"
  content_type = "text/plain"
  content      = "Hello from Account A\n"
}


# Role in Account A that your new user in B can assume
data "aws_iam_policy_document" "a_trust" {
  # Trust exactly the new user's ARN in Account B
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.b_user.arn] # cross-account principal
    }
  }
}

resource "aws_iam_role" "a_reader_role" {
  provider            = aws.account_a
  name                = "AccountA-ExportPrefix-Reader"
  assume_role_policy  = data.aws_iam_policy_document.a_trust.json
  tags                = local.tags
}


# Permissions for the role: list restricted to prefix, get on prefix/*
resource "aws_iam_role_policy" "a_reader_permissions" {
  provider = aws.account_a
  name     = "ExportPrefixReadOnly"
  role     = aws_iam_role.a_reader_role.id
  policy   = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid: "ListBucketExportPrefix",
        Effect: "Allow",
        Action: ["s3:ListBucket"],
        Resource: aws_s3_bucket.a_bucket.arn,
        Condition: { 
            StringLike: { 
                "s3:prefix": [var.export_prefix, "${var.export_prefix}*"] 
            } 
        }
      },
      {
        Sid: "GetObjectsUnderExport",
        Effect: "Allow",
        Action: ["s3:GetObject"],
        Resource: "${aws_s3_bucket.a_bucket.arn}/${var.export_prefix}*"
      }
    ]
  })
}

# Bucket policy must also allow the role principal to access the bucket objects
resource "aws_s3_bucket_policy" "a_allow_role" {
  provider = aws.account_a
  bucket   = aws_s3_bucket.a_bucket.id
  policy   = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid: "AllowRoleListExport",
        Effect: "Allow",
        Principal = { AWS = aws_iam_role.a_reader_role.arn },
        Action   = "s3:ListBucket",
        Resource = aws_s3_bucket.a_bucket.arn,
        Condition: { 
            StringLike: { 
                "s3:prefix": [var.export_prefix, "${var.export_prefix}*"] 
            } 
        }
      },
      {
        Sid: "AllowRoleGetExport",
        Effect: "Allow",
        Principal = { AWS = aws_iam_role.a_reader_role.arn },
        Action   = "s3:GetObject",
        Resource = "${aws_s3_bucket.a_bucket.arn}/${var.export_prefix}*"
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.a_block, aws_s3_bucket_ownership_controls.a_own]
}

############################################
# Account B: allow the new user to assume the role in A
############################################
resource "aws_iam_user_policy" "b_user_allow_assume_a_role" {
  name = "AllowAssumeAccountARole"
  user = aws_iam_user.b_user.name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = ["sts:AssumeRole"],
      Resource = aws_iam_role.a_reader_role.arn
    }]
  })
}