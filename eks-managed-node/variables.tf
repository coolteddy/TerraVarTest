############################
# Variables (lightweight)
############################
variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "cluster_name" {
  type    = string
  default = "burmanic-eks-demo"
}

# --- for module ---
# variable "node_instance_types" {
#   type    = list(string)
#   default = ["t3.medium"]
# }

variable "node_instance_type" { 
    type = string
    default = "t3.medium" 
}

variable "desired_size" { 
    type = number 
    default = 2 
}
variable "min_size" { 
    type = number
    default = 2 
}
variable "max_size" { 
    type = number
    default = 3
}
