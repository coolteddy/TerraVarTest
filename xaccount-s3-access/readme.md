# Cross-Account S3 Access with AssumeRole

This module provisions cross-account access to an S3 bucket using AWS IAM roles and users. It enables a user in Account B to assume a role in Account A and access objects in a specific S3 bucket/prefix.

---

## Architecture Overview
- **Account A (Target):**
  - S3 bucket is created.
  - IAM role (`AccountA-ExportPrefix-Reader`) is created, allowing access to the bucket/prefix.
  - Trust policy allows assumption by Account B user.
- **Account B (Main):**
  - IAM user (`export-reader`) is created.
  - User is allowed to assume the role in Account A.

---

## Resource-by-Resource Explanation

### 1. S3 Bucket (Account A)
**Purpose:**
Creates the target bucket for cross-account access. Objects under the specified prefix (e.g., `export/`) are accessible to the assumed role.
**Testing:**
- List and copy objects using the assumed role credentials.

### 2. IAM Role in Account A (`AccountA-ExportPrefix-Reader`)
**Purpose:**
Allows access to the S3 bucket/prefix. Trusts Account B for role assumption.
**Deep Explanation:**
- Trust policy allows Account B user to assume the role.
- Inline policy grants `s3:ListBucket` and `s3:GetObject` on the bucket/prefix.
**Testing:**
- Assume the role from Account B and access the bucket.

### 3. IAM User in Account B (`export-reader`)
**Purpose:**
User who will assume the role in Account A.
**Deep Explanation:**
- User is created with access keys for CLI/API use.
- Policy allows `sts:AssumeRole` on the Account A role.
**Testing:**
- Use the user's credentials to assume the role and access S3.

---

## How to Deploy and Test

### 1. Run Terraform
```
terraform apply -var 'account_a_id=12345678910' \
  -var 'bucket_name=whateverbucketnameyouwant' \
  -var 'new_user_name_b=export-reader' \
  -var 'export_prefix=export/' \
  -var 'account_a_admin_role_name=OrganizationAccountAccessRole' \
  -var 'region=eu-west-1'
```

### 2. Configure AWS CLI for Account B User
- Create access keys for the new user in Account B (manual step).
- Configure the profile:
```
aws configure --profile account-b-reader
```

### 3. Assume Role into Account A
```
aws sts assume-role \
  --profile account-b-reader \
  --role-arn arn:aws:iam::12345678910:role/AccountA-ExportPrefix-Reader \
  --role-session-name read-export \
  --duration-seconds 3600 > /tmp/assume.json
```

### 4. Set Session Credentials
```
export AWS_ACCESS_KEY_ID=$(jq -r .Credentials.AccessKeyId /tmp/assume.json)
export AWS_SECRET_ACCESS_KEY=$(jq -r .Credentials.SecretAccessKey /tmp/assume.json)
export AWS_SESSION_TOKEN=$(jq -r .Credentials.SessionToken /tmp/assume.json)
export AWS_REGION=eu-west-1
```

### 5. Test S3 Access
```
BUCKET=$(terraform output -raw account_a_bucket)
aws s3 ls "s3://${BUCKET}/export/"
aws s3 cp "s3://${BUCKET}/export/hello.txt" -
```

### 6. Terraform destroy 
**make sure to delete the Account A access key first**
```
terraform destroy -var 'account_a_id=12345678910' \
  -var 'bucket_name=whateverbucketnameyouwant' \
  -var 'new_user_name_b=export-reader' \
  -var 'export_prefix=export/' \
  -var 'account_a_admin_role_name=OrganizationAccountAccessRole' \
  -var 'region=eu-west-1'
```

---

## Security Notes
- The IAM role in Account A uses least-privilege policies for S3 access.
- The trust relationship is restricted to the specific Account B user.
- Always rotate access keys and follow AWS security best practices.

---

## Troubleshooting
- If access fails, check:
  - Trust policy on the Account A role
  - Inline policy permissions
  - Correct session credentials are exported
  - S3 bucket and prefix exist
- Use CloudTrail and IAM policy simulator for debugging.

---

For more details, see the Terraform code and comments in `main.tf`.
