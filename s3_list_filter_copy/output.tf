output "s3_object_keys" {
	value = data.aws_s3_objects.source_objects.keys
}

output "s3_sh_object_keys" {
	value = [for k in data.aws_s3_objects.source_objects.keys : k if length(regexall("(\\.sh$|\\.csv$)", k)) > 0]
}