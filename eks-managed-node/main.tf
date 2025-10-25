

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

# custom security group for the cluster control plane
# resource "aws_security_group" "eks_cluster" {
#   name        = "${var.cluster_name}-cluster-sg"
#   description = "EKS Cluster API server security group"
#   vpc_id      = aws_vpc.this.id

#   ingress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["your-corporate-cidr", aws_vpc.this.cidr_block]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = local.tags
# }


resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = "1.34"

  vpc_config {
    endpoint_public_access  = true
    endpoint_private_access = true
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]
    # You can set cluster_security_group_id here; if omitted, AWS creates one.
    # cluster_security_group_id = aws_security_group.eks_cluster.id
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

# to allow the port 80 from NLB/ALB to the nodes
# resource "aws_security_group" "node_sg" {
#   name   = "node-group-sg"
#   vpc_id = aws_vpc.this.id
#   tags = merge(local.tags, { Name = "node-group_custom_sg" })
# }

# resource "aws_vpc_security_group_ingress_rule" "node_sg_ingress_http_from_alb" {
#   security_group_id        = aws_security_group.node_sg.id
#   description              = "HTTP from ALB/NLB"
#   ip_protocol              = "tcp"
#   from_port                = 80
#   to_port                  = 80
# }

# resource "aws_vpc_security_group_egress_rule" "node_sg_egress_all" {
#   security_group_id = aws_security_group.node_sg.id
#   ip_protocol       = "-1" # Represents all protocols.
#   cidr_ipv4         = "0.0.0.0/0"
# }


resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "ng-default"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  capacity_type   = "ON_DEMAND"
  instance_types  = [var.node_instance_type]

  # only enable if you created the custom SG above
  # remote_access {
  #   # Add your custom security group here
  #   source_security_group_ids = [aws_security_group.node_sg.id]
  # } 

  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  update_config { max_unavailable = 1 }

  ami_type = "AL2023_x86_64_STANDARD" # Amazon Linux 2

  tags = local.tags

  depends_on = [
    aws_eks_cluster.this,
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy
  ]
}

############################
# IRSA: OIDC provider for the cluster
############################

# OIDC issuer from EKS
locals {
  oidc_issuer = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

data "tls_certificate" "oidc" {
  url = local.oidc_issuer
}

############################
# IAM: Policy + Role for the controller (IRSA)
############################

resource "aws_iam_openid_connect_provider" "eks" {
  url = local.oidc_issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]
}

# IAM policy from file (recommended official JSON)
resource "aws_iam_policy" "alb_controller" {
  name   = "AWSLoadBalancerControllerIAMPolicy"
  policy = file("${path.module}/policies/iam-policy-alb-controller.json")
}

# Trust policy for IRSA (service account in kube-system namespace)
data "aws_iam_policy_document" "alb_controller_trust" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(local.oidc_issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "alb_controller" {
  name               = "eks-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_trust.json
}

resource "aws_iam_role_policy_attachment" "alb_controller_attach" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

############################
# Kubernetes SA + Helm release (controller)
############################

# ServiceAccount that will be bound to the IAM role via IRSA
resource "kubernetes_service_account" "alb_sa" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn
    }
    labels = {
      "app.kubernetes.io/name" = "aws-load-balancer-controller"
    }
  }
  automount_service_account_token = true
}

# Install ALB Controller via Helm (uses the existing SA)
resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.14.1" # recent chart version

  # Don't create the SA; we provide our own with IRSA annotation
  set = [
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = kubernetes_service_account.alb_sa.metadata[0].name
    },
    {
      name  = "clusterName"
      value = aws_eks_cluster.this.name
    },
    # metadata access is blocked or unavailable in new versions
    # The node AMI or configuration disables or restricts IMDS (Instance Metadata Service) 
    # access (e.g., IMDSv2 enforcement, hop limit settings)
    {
      name  = "vpcId"
      value = aws_vpc.this.id
   }
]

  depends_on = [
    aws_eks_node_group.default,
    aws_iam_role_policy_attachment.alb_controller_attach,
    aws_eks_cluster.this
  ]
}


############################
# IRSA for VPC CNI Plugin (aws-node)
############################
# 1. IAM Policy for VPC CNI
resource "aws_iam_policy" "vpc_cni" {
  name   = "AmazonEKS_CNI_Policy"
  description = "IAM policy for EKS VPC CNI plugin"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeVpcs",
        "ec2:DescribeInstances",
        "ec2:DescribeNetworkInterfaces",
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:AttachNetworkInterface",
        "ec2:DetachNetworkInterface",
        "ec2:ModifyNetworkInterfaceAttribute",
        "ec2:AssignPrivateIpAddresses",
        "ec2:UnassignPrivateIpAddresses"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

# 2. Trust Policy for VPC CNI IRSA
data "aws_iam_policy_document" "vpc_cni_trust" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(local.oidc_issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }
  }
}

# 3. IAM Role for VPC CNI

resource "aws_iam_role" "vpc_cni" {
  name               = "eks-vpc-cni-irsa"
  assume_role_policy = data.aws_iam_policy_document.vpc_cni_trust.json
  tags = local.tags
}

# 4. Attach Policy to Role
resource "aws_iam_role_policy_attachment" "vpc_cni_attach" {
  role       = aws_iam_role.vpc_cni.name
  policy_arn = aws_iam_policy.vpc_cni.arn
}

# 5. Annotate aws-node ServiceAccount (Kubernetes)
# looks like already created by EKS or Helm chart
# resource "kubernetes_service_account" "aws_node" {
#   metadata {
#     name      = "aws-node"
#     namespace = "kube-system"
#     annotations = {
#       "eks.amazonaws.com/role-arn" = aws_iam_role.vpc_cni.arn
#     }
#     labels = {
#       "app.kubernetes.io/name" = "aws-node"
#     }
#   }
#   automount_service_account_token = true
# }

# manually run this after commented out aws-node service account
# kubectl annotate serviceaccount aws-node \
#   -n kube-system \
#   eks.amazonaws.com/role-arn=<paste-the-arn-here> --overwrite


