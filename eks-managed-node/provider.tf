
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" 
    }
  }
}

provider "aws" { 
  region = var.region 
}

# Providers wired to your EKS cluster
# Auth/token for talking to the cluster
data "aws_eks_cluster_auth" "this" {
  name = aws_eks_cluster.this.name
}

# Kubernetes & Helm providers use the live cluster endpoint/CA/token
provider "kubernetes" {
  host                   = aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

# provider "helm" {
#   kubernetes_host                   = aws_eks_cluster.this.endpoint
#   kubernetes_cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
#   kubernetes_token                  = data.aws_eks_cluster_auth.this.token
# }

# provider "helm" {
#   # No arguments needed; uses default Kubernetes provider
# }

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}