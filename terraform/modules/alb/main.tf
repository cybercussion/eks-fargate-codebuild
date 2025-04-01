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

provider "aws" {
  region = var.region  # Dynamically set based on the input
}

# Conditionally fetch VPC ID from SSM
data "aws_ssm_parameter" "vpc_id" {
  count = var.use_vpc_from_ssm ? 1 : 0
  name  = var.vpc_ssm_path
}

# Conditionally fetch public subnet IDs from SSM
data "aws_ssm_parameter" "subnets" {
  for_each = var.use_vpc_from_ssm ? toset(var.subnet_ssm_paths) : []
  name     = each.value
}

# Security Group for ALB
#tfsec:ignore:aws-ec2-no-public-ingress-sgr
resource "aws_security_group" "alb" {
  name_prefix = var.name
  description = "Security group for ALB"
  vpc_id = var.use_vpc_from_ssm ? data.aws_ssm_parameter.vpc_id[0].value : var.vpc_id

  # HTTP ingress (optional)
  # 
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    #cidr_blocks = [data.aws_ssm_parameter.vpc_id.value]  # Restrict to your VPC CIDR
    description = "Allow HTTP or allow for HTTP to HTTPS redirection"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #tfsec:ignore:aws-ec2-no-public-egress-sgr
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Application Load Balancer
resource "aws_lb" "this" {
  name               = "${var.environment}-fargate-alb"
  internal           = var.scheme == "internal" ? true : false
  load_balancer_type = "application"
  #security_groups    = [aws_security_group.alb.id]
  security_groups    = length(var.security_group_ids) > 0 ? var.security_group_ids : [aws_security_group.alb.id]
  # subnets            = [for ssm in data.aws_ssm_parameter.subnets : ssm.value]
  subnets = (
    var.use_vpc_from_ssm 
    ? [for ssm in data.aws_ssm_parameter.subnets : ssm.value] 
    : var.subnet_ids
  )

  enable_deletion_protection = false

  idle_timeout = var.idle_timeout

  tags = merge(
    var.tags,
    {
      Environment = var.environment
    },
    var.eks_enabled ? {
      "kubernetes.io/cluster/${var.eks_cluster_name}" = "owned"
      "kubernetes.io/ingress.class"                   = "alb"
      "ingress.k8s.aws/stack"                         = var.name
    } : {}
  )
}

# Fetch Certificate ARN from SSM
data "aws_ssm_parameter" "certificate" {
  name = var.certificate_ssm_path
}

# HTTP Listener (port 80) with conditional redirection or fixed response
resource "aws_lb_listener" "http" {
  count             = var.enable_http ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "No service configured yet"
      status_code  = "404"
    }
  }
}

# Redirect listener (when HTTP is disabled)
resource "aws_lb_listener" "http_redirect" {
  count             = var.enable_http ? 0 : 1
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      protocol    = "HTTPS"
      port        = "443"
      host        = "#{host}"
      path        = "/#{path}"
      query       = "#{query}"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS Listener (port 443)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = data.aws_ssm_parameter.certificate.value

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "No service configured yet"
      status_code  = "404"
    }
  }
}

# Test Listener (Optional)
resource "aws_lb_listener" "test" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.test_listener_port
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Test listener response"
      status_code  = "200"
    }
  }
}