locals {
  tags = {
    Project = "eks-demo"
    Owner   = "coolteddy"
    Env     = "demo"
  }
  az_a = "${var.region}a"
  az_b = "${var.region}b"
}

# # --- VPC (2 AZs, public + private) ---
# module "vpc" {
#   source  = "terraform-aws-modules/vpc/aws"
#   version = "~> 5.5"

#   name = "${var.cluster_name}-vpc"
#   cidr = "10.0.0.0/16"

#   azs             = ["${var.region}a", "${var.region}b"]
#   public_subnets  = ["10.0.0.0/24",  "10.0.1.0/24"]
#   private_subnets = ["10.0.10.0/24", "10.0.11.0/24"]

#   enable_nat_gateway     = true
#   single_nat_gateway     = true   # fast & cheap for demos; per-AZ NAT in prod
#   map_public_ip_on_launch = true

#   tags = local.tags
# }

# # --- EKS Cluster + Managed Node Group ---
# module "eks" {
#   source  = "terraform-aws-modules/eks/aws"
#   version = "~> 20.13" # current major as of 2025

#   cluster_name    = var.cluster_name
#   cluster_version = "1.29"

#   cluster_endpoint_public_access  = true
#   cluster_endpoint_private_access = true

#   vpc_id                   = module.vpc.vpc_id
#   subnet_ids               = module.vpc.private_subnets
#   control_plane_subnet_ids = module.vpc.private_subnets

#   enable_cluster_creator_admin_permissions = true

#   # Core EKS add-ons
#   cluster_addons = {
#     coredns                = { most_recent = true }
#     kube-proxy             = { most_recent = true }
#     vpc-cni                = { most_recent = true }
#   }

#   # One managed node group
#   eks_managed_node_groups = {
#     default = {
#       desired_size     = var.desired_size
#       min_size         = var.min_size
#       max_size         = var.max_size
#       instance_types   = var.node_instance_types
#       capacity_type    = "ON_DEMAND"
#       subnets          = module.vpc.private_subnets
#       ami_type         = "AL2_x86_64"
#       create_security_group = true
#       tags = local.tags
#     }
#   }

#   tags = local.tags
# }


############################
# VPC + Subnets + Routing (2 AZ)
############################
resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.tags, { Name = "${var.cluster_name}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = local.tags
}

# Public subnets
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = local.az_a
  map_public_ip_on_launch = true
  tags = merge(local.tags, {
    Name = "${var.cluster_name}-public-a"
    "kubernetes.io/role/elb" = "1"
  })
}
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = local.az_b
  map_public_ip_on_launch = true
  tags = merge(local.tags, {
    Name = "${var.cluster_name}-public-b"
    "kubernetes.io/role/elb" = "1"
  })
}

# Private subnets (nodes live here)
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = local.az_a
  tags = merge(local.tags, {
    Name = "${var.cluster_name}-private-a"
    "kubernetes.io/role/internal-elb" = "1"
  })
}
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = local.az_b
  tags = merge(local.tags, {
    Name = "${var.cluster_name}-private-b"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# Public routing
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = local.tags
}
resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# NAT (1 for demo speed/cost)
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = local.tags
}
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  depends_on    = [aws_internet_gateway.igw]
  tags          = local.tags
}

# Private routing via NAT
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = local.tags
}
resource "aws_route" "private_default" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

############################
# IAM: EKS Cluster & NodeGroup roles
############################
# Cluster role
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "eks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKS_VPC_ResourceController" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

# Node group role
resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action   = "sts:AssumeRole"
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

############################
# EKS Cluster
############################
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = "1.29"

  vpc_config {
    endpoint_public_access  = true
    endpoint_private_access = true
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]
    # You can set cluster_security_group_id here; if omitted, AWS creates one.
  }

  tags = local.tags

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKS_VPC_ResourceController
  ]
}

############################
# Managed Node Group
############################
resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "ng-default"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  capacity_type   = "ON_DEMAND"
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  update_config { max_unavailable = 1 }

  ami_type = "AL2_x86_64" # Amazon Linux 2

  tags = local.tags

  depends_on = [
    aws_eks_cluster.this,
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy
  ]
}


