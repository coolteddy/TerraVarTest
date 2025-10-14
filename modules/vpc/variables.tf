variable "name" {
  description = "Project name prefix for resources"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

variable "cidr_block" {
  description = "VPC CIDR block"
  type        = string
}

variable "public_a_cidr" {
  description = "CIDR block for public subnet A"
  type        = string
}

variable "public_b_cidr" {
  description = "CIDR block for public subnet B"
  type        = string
}

variable "private_a_cidr" {
  description = "CIDR block for private subnet A"
  type        = string
}

variable "private_b_cidr" {
  description = "CIDR block for private subnet B"
  type        = string
}

variable "az_a" {
  description = "Availability zone for subnet A"
  type        = string
}

variable "az_b" {
  description = "Availability zone for subnet B"
  type        = string
}
