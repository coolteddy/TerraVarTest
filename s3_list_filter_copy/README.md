# S3 List, Filter, and Copy Terraform Module

## Purpose
This Terraform module allows you to:
- List all objects in a source AWS S3 bucket
- Filter objects to show only `.sh` and `.csv` files
- Create a new target S3 bucket
- Output the filtered list of files for easy copying

**Note:** Terraform cannot natively copy objects between buckets. Use the provided shell script after running Terraform to copy the filtered files using AWS CLI.

## Usage

### 1. Initialize Terraform
```sh
terraform init
```

### 2. Plan and Apply with Variables
Replace the bucket names as needed:
```sh
terraform plan -var="source_bucket=sourcebucketname" -var="target_bucket=destinationbucketname"
terraform apply -var="source_bucket=sourcebucketname" -var="target_bucket=destinationbucketname"
```

### 3. Copy Filtered Files Using AWS CLI
After `terraform apply`, use this shell script to copy `.sh` and `.csv` files:

```sh
#!/bin/bash
SOURCE_BUCKET="sourcebucketname"
TARGET_BUCKET="destinationbucketname"
for key in $(aws s3api list-objects --bucket "$SOURCE_BUCKET" --query 'Contents[?ends_with(Key, `.sh`) || ends_with(Key, `.csv`)].Key' --output text); do
  aws s3 cp "s3://$SOURCE_BUCKET/$key" "s3://$TARGET_BUCKET/$key"
done
```

You can get the filtered keys from the Terraform output `s3_sh_object_keys` as well.

## Requirements
- Terraform >= 1.0
- AWS CLI installed and configured
- AWS credentials with access to both buckets

## Outputs
- `s3_object_keys`: All object keys in the source bucket
- `s3_sh_object_keys`: Filtered list of `.sh` and `.csv` files

## License
MIT
