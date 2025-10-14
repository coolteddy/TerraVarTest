// VPC Module: main.tf

resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = merge(var.tags, { Name = "${var.name}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = merge(var.tags, { Name = "${var.name}-igw" })
}

resource "aws_subnet" "public_a" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.public_a_cidr
  availability_zone = var.az_a
  map_public_ip_on_launch = true
  tags = merge(var.tags, { Name = "${var.name}-public-subnet-a" })
}

resource "aws_subnet" "public_b" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.public_b_cidr
  availability_zone = var.az_b
  map_public_ip_on_launch = true
  tags = merge(var.tags, { Name = "${var.name}-public-subnet-b" })
}

resource "aws_subnet" "private_a" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.private_a_cidr
  availability_zone = var.az_a
  tags = merge(var.tags, { Name = "${var.name}-private-subnet-a" })
}

resource "aws_subnet" "private_b" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.private_b_cidr
  availability_zone = var.az_b
  tags = merge(var.tags, { Name = "${var.name}-private-subnet-b" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  tags = merge(var.tags, { Name = "${var.name}-public-rt" })
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

resource "aws_eip" "nat" {
  domain = "vpc"
  tags = merge(var.tags, { Name = "${var.name}-nat-eip" })
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  tags = merge(var.tags, { Name = "${var.name}-nat-gateway" })
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  tags = merge(var.tags, { Name = "${var.name}-private-rt" })
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
