# terraform {
#   backend "s3" {
#     bucket         = "terravar-state-bucket"
#     key            = "two_tierstate/terraform.tfstate"
#     region         = "your-region"
#     dynamodb_table = "terraform-lock-table"   # Optional, for state locking
#     encrypt        = true
#   }
# }

# creating bucket first
# aws s3api create-bucket --bucket terravar-state-bucket --region eu-west-1

# versioning (Optional)
# aws s3api put-bucket-versioning --bucket <your-unique-bucket-name> --versioning-configuration Status=Enabled

# (Optional) Create a DynamoDB Table for State Locking

# aws dynamodb create-table \
#   --table-name terraform-lock-table \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST