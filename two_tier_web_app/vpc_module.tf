# VPC Module, but currently not used in this project
# Uncomment to use
# module "vpc" {
# 	source         = "../modules/vpc"
# 	name           = local.name
# 	tags           = local.tags
# 	cidr_block     = "10.0.0.0/16"
# 	public_a_cidr  = "10.0.1.0/24"
# 	public_b_cidr  = "10.0.2.0/24"
# 	private_a_cidr = "10.0.10.0/24"
# 	private_b_cidr = "10.0.11.0/24"
# 	az_a           = "${var.aws_region}a"
# 	az_b           = "${var.aws_region}b"
# }

