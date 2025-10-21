############################
# Outputs
############################
# output "cluster_name" {
#   value = module.eks.cluster_name
# }

# output "cluster_endpoint" {
#   value = module.eks.cluster_endpoint
# }

# output "cluster_oidc_provider_arn" {
#   value = module.eks.oidc_provider_arn
# }

# output "oidc_issuer_url" {
#   value = module.eks.cluster_oidc_issuer_url
# }

# output "node_group_role_arn" {
#   value = module.eks.eks_managed_node_groups["default"].iam_role_arn
# }

# output "private_subnets" {
#   value = module.vpc.private_subnets
# }

# output "public_subnets" {
#   value = module.vpc.public_subnets
# }


output "cluster_name" { 
    value = aws_eks_cluster.this.name 
}
output "cluster_endpoint" { 
    value = aws_eks_cluster.this.endpoint 
}
output "private_subnets" { 
    value = [aws_subnet.private_a.id, aws_subnet.private_b.id] 
}