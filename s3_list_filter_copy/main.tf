data "aws_s3_objects" "source_objects" {
	bucket = var.source_bucket
}

resource "aws_s3_bucket" "copy_target" {
	bucket        = var.target_bucket
	force_destroy = true
}

# Copy .sh and .csv files from source to target bucket
# resource "aws_s3_object" "copied_objects" {
# 		# This resource cannot copy objects directly between buckets. Use null_resource below.
# }

# Use null_resource and local-exec to copy .sh and .csv files using AWS CLI
resource "null_resource" "copy_sh_and_csv_files" {
  triggers = {
	object_keys = join(",", [for k in data.aws_s3_objects.source_objects.keys : k if length(regexall("(\\.sh$|\\.csv$)", k)) > 0])
  }

  provisioner "local-exec" {
	command = <<EOT
for key in $(aws s3api list-objects --bucket ${var.source_bucket} --query 'Contents[?ends_with(Key, \`.sh\`) || ends_with(Key, \`.csv\`)].Key' --output text); do
  aws s3 cp s3://${var.source_bucket}/$key s3://${var.target_bucket}/$key
done
EOT
	environment = {
	  AWS_DEFAULT_REGION = var.region != null ? var.region : "eu-west-2"
	}
  }
}


# list the contents of the source bucket
# data "aws_s3_objects" "sourcebucket_objects" {
# 	bucket = "sourcebucketname"
# }

# resource "aws_s3_bucket" "copy_target" {
# 	bucket = "dest-new-bucket-name"
# 	force_destroy = true
# }
