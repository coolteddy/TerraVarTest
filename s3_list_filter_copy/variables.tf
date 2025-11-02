############################################
# Inputs
############################################
variable "region" {
  description = "Deployment region for S3"
  type        = string
  default     = "eu-west-1"
}

variable "source_bucket" {
	description = "Name of the source S3 bucket to copy from"
	type        = string
}

variable "target_bucket" {
	description = "Name of the target S3 bucket to copy to"
	type        = string
}