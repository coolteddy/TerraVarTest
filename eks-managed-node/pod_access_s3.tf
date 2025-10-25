############################
# IRSA Example: Pod Access to S3 access
############################

# # 1. IAM Policy for S3 access (replace bucket name as needed)
# resource "aws_iam_policy" "s3_access" {
#   name        = "eks-s3-access-policy"
#   description = "Allow pod to access specific S3 bucket"
#   policy      = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Action": ["s3:GetObject", "s3:ListBucket"],
#       "Resource": [
#         "arn:aws:s3:::your-bucket-name",
#         "arn:aws:s3:::your-bucket-name/*"
#       ]
#     }
#   ]
# }
# EOF
# }

# # 2. Trust Policy for IRSA (service account in app namespace)
# data "aws_iam_policy_document" "s3_access_trust" {
#   statement {
#     effect = "Allow"
#     actions = ["sts:AssumeRoleWithWebIdentity"]
#     principals {
#       type        = "Federated"
#       identifiers = [aws_iam_openid_connect_provider.eks.arn]
#     }
#     condition {
#       test     = "StringEquals"
#       variable = "${replace(local.oidc_issuer, "https://", "")}:sub"
#       values   = ["system:serviceaccount:app:s3-access-sa"]
#     }
#   }
# }

# # 3. IAM Role for S3 access
# resource "aws_iam_role" "s3_access" {
#   name               = "eks-s3-access-role"
#   assume_role_policy = data.aws_iam_policy_document.s3_access_trust.json
#   tags = local.tags
# }

# # 4. Attach Policy to Role
# resource "aws_iam_role_policy_attachment" "s3_access_attach" {
#   role       = aws_iam_role.s3_access.name
#   policy_arn = aws_iam_policy.s3_access.arn
# }

# # 5. Annotate ServiceAccount for pod (namespace: app)
# resource "kubernetes_service_account" "s3_access_sa" {
#   metadata {
#     name      = "s3-access-sa"
#     namespace = "app"
#     annotations = {
#       "eks.amazonaws.com/role-arn" = aws_iam_role.s3_access.arn
#     }
#     labels = {
#       "app.kubernetes.io/name" = "s3-access"
#     }
#   }
#   automount_service_account_token = true
# }

# To use: Set your pod/deployment spec to use serviceAccountName: s3-access-sa in the app namespace.