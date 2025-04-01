terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.93.0"
    }
  }

  backend "s3" {}
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-vpc"
  })
}

# Public Subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = var.az_1
  map_public_ip_on_launch = var.map_public_ip

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-public-subnet-1"
    },
    var.k8s ? {
      "kubernetes.io/role/elb" = "1"
      "kubernetes.io/cluster/${var.project_name}" = "owned"
    } : {}
  )
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = var.az_2
  map_public_ip_on_launch = var.map_public_ip

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-public-subnet-2"
    },
    var.k8s ? {
      "kubernetes.io/role/elb" = "1"
      "kubernetes.io/cluster/${var.project_name}" = "owned"
    } : {}
  )
}

# Private Subnets
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = var.az_1

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-private-subnet-1"
    },
    var.k8s ? {
      "kubernetes.io/role/internal-elb" = "1"
      "kubernetes.io/cluster/${var.project_name}" = "owned"
    } : {}
  )
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = var.az_2

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-private-subnet-2"
    },
    var.k8s ? {
      "kubernetes.io/role/internal-elb" = "1"
      "kubernetes.io/cluster/${var.project_name}" = "owned"
    } : {}
  )
}

# Internet Gateway for public subnets
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-igw"
  })
}

# Elastic IP and NAT Gateway for private subnets
resource "aws_eip" "nat" {
  tags = merge(var.tags, {
    Name = "${var.project_name}-nat-eip"
  })
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnet_1.id

  depends_on = [aws_internet_gateway.this]
  tags = merge(var.tags, {
    Name = "${var.project_name}-nat-gw"
  })
}

# Public Route Table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-public-rt"
  })
}

resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Private Route Table with NAT access
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-private-rt"
  })
}

resource "aws_route_table_association" "private_subnet_1_association" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_subnet_2_association" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}

# resource "aws_flow_log" "vpc_flow_log" {
#   iam_role_arn    = aws_iam_role.vpc_flow_log_role.arn
#   log_destination = aws_cloudwatch_log_group.vpc_flow_log.arn
#   traffic_type    = "ALL"
#   vpc_id          = aws_vpc.this.id
# }