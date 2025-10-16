############################################
# Outputs
############################################
output "account_a_bucket" {
    value = aws_s3_bucket.a_bucket.bucket
    description = "Account A S3 Bucket Name"
}
output "account_a_reader_role" {
    value = aws_iam_role.a_reader_role.arn
    description = "Account A Reader Role ARN"
}
output "account_b_user_arn" {
    value = aws_iam_user.b_user.arn
    description = "Account B User ARN"
}
output "export_prefix" {
    value = var.export_prefix
    description = "S3 Export Prefix"
}