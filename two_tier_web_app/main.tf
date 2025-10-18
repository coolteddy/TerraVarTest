locals {
  name = "burmanic-simple"
  tags = { Project = local.name, Environment = "dev", owner = "coolteddy" }
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = merge(local.tags, { Name = "${local.name}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
    tags = merge(local.tags, { Name = "${local.name}-igw" })
}

resource "aws_subnet" "public_a" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = merge(local.tags, { Name = "${local.name}-public-subnet" })
}

resource "aws_subnet" "public_b" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags = merge(local.tags, { Name = "${local.name}-public-subnet" })
}

resource "aws_subnet" "private_a" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.10.0/24"
  availability_zone = "${var.aws_region}a"
  tags = merge(local.tags, { Name = "${local.name}-private-subnet" })
}

resource "aws_subnet" "private_b" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.11.0/24"
  availability_zone = "${var.aws_region}b"
  tags = merge(local.tags, { Name = "${local.name}-private-subnet" })
}

# Public routing
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  tags = merge(local.tags, { Name = "${local.name}-public-rt" })
}

resource "aws_route" "default_route" {
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

# NAT in public_a (single NAT for demo speed)
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = merge(local.tags, { Name = "${local.name}-nat-eip" })
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  tags = merge(local.tags, { Name = "${local.name}-nat-gateway" })
  depends_on = [aws_internet_gateway.igw]
}

# Private routing via NAT
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  tags = merge(local.tags, { Name = "${local.name}-private-rt" })
}

resource "aws_route" "private_nat_route" {
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

# ############################
# Security Groups - Old way
# ############################
# resource "aws_security_group" "alb_sg" {
#   name   = "${local.name}-alb-sg"
#   vpc_id = aws_vpc.vpc.id

#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#     description = "HTTP from anywhere"
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = local.tags
# }

# The core security group resource, without inline rules.
resource "aws_security_group" "alb_sg" {
  name   = "${local.name}-alb-sg"
  vpc_id = aws_vpc.vpc.id
  tags = merge(local.tags, { Name = "${local.name}-alb_sg" })
}

# The ingress rule, managed by its own resource.
resource "aws_vpc_security_group_ingress_rule" "alb_sg_ingress_http" {
  security_group_id = aws_security_group.alb_sg.id
  description       = "HTTP from anywhere"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

# The egress rule, managed by its own resource.
resource "aws_vpc_security_group_egress_rule" "alb_sg_egress_all" {
  security_group_id = aws_security_group.alb_sg.id
  ip_protocol       = "-1" # Represents all protocols.
  cidr_ipv4         = "0.0.0.0/0"
}

# ############################
# Security Groups - Old way
# ############################
# resource "aws_security_group" "app_sg" {
#   name   = "${local.name}-app-sg"
#   vpc_id = aws_vpc.vpc.id

#   ingress {
#     from_port       = 80
#     to_port         = 80
#     protocol        = "tcp"
#     security_groups = [aws_security_group.alb_sg.id]
#     description     = "HTTP from ALB"
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = local.tags
# }

resource "aws_security_group" "app_sg" {
  name   = "${local.name}-app-sg"
  vpc_id = aws_vpc.vpc.id
  tags = merge(local.tags, { Name = "${local.name}-app_sg" })
}

resource "aws_vpc_security_group_ingress_rule" "app_sg_ingress_http_from_alb" {
  security_group_id        = aws_security_group.app_sg.id
  description              = "HTTP from ALB"
  ip_protocol              = "tcp"
  from_port                = 80
  to_port                  = 80
  referenced_security_group_id   = aws_security_group.alb_sg.id
}

resource "aws_vpc_security_group_egress_rule" "app_sg_egress_all" {
  security_group_id = aws_security_group.app_sg.id
  ip_protocol       = "-1" # Represents all protocols.
  cidr_ipv4         = "0.0.0.0/0"
}

############################
# ALB + TG + Listener
############################

resource "aws_lb" "alb" {
  name               = "${local.name}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  tags               = local.tags
}

resource "aws_lb_target_group" "tg" {
  name     = "${local.name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    path              = "/"
    interval          = 15
    healthy_threshold = 2
    unhealthy_threshold = 2
    matcher           = "200-399"
  }

  tags = local.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# ############################
# # EC2: Launch Template + ASG
# ############################

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"] # Official Amazon Linux AMI owner ID
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

locals {
  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nginx
    echo "<h1>${local.name} - hello from $(hostname)</h1>" > /usr/share/nginx/html/index.html
    systemctl enable nginx
    systemctl start nginx
  EOF
}

resource "aws_launch_template" "lt" {
  name_prefix   = "${local.name}-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = "t3.micro"
  user_data     = base64encode(local.user_data)

  network_interfaces {
    security_groups = [aws_security_group.app_sg.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.tags, { Name = "${local.name}-ec2" })
  }

  tags = local.tags
}

resource "aws_autoscaling_group" "asg" {
  name                = "${local.name}-asg"
  desired_capacity    = 2
  min_size            = 2
  max_size            = 3
  vpc_zone_identifier = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  target_group_arns           = [aws_lb_target_group.tg.arn]
  health_check_type           = "ELB"
  health_check_grace_period   = 60
  force_delete                = true

  tag {
    key                 = "Name"
    value               = "${local.name}-ec2"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${local.name}-db-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = {
    Name = "${local.name}-db-subnet-group"
  }
}

resource "aws_security_group" "db_sg" {
  name   = "${local.name}-db-sg"
  vpc_id = aws_vpc.vpc.id
  tags = merge(local.tags, { Name = "${local.name}-db_sg" })
}

resource "aws_vpc_security_group_ingress_rule" "db_sg_ingress_http_from_alb" {
  security_group_id        = aws_security_group.db_sg.id
  description              = "DB access from App SG"
  ip_protocol              = "tcp"
  from_port                = 3306
  to_port                  = 3306
  referenced_security_group_id   = aws_security_group.app_sg.id
}

resource "aws_vpc_security_group_egress_rule" "db_sg_egress_all" {
  security_group_id = aws_security_group.db_sg.id
  ip_protocol       = "-1" # Represents all protocols.
  cidr_ipv4         = "0.0.0.0/0"
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier             = "${local.name}-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = "appdb"
  username               = "admin"
  password               = "change-me-in-production" # Use AWS Secrets Manager in real scenarios
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true

  tags = {
    Name = "${local.name}-db"
  }
}