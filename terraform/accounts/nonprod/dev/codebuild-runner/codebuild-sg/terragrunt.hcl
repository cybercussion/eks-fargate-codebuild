# Include the root configuration for backend and provider setup
include {
  path = find_in_parent_folders("root.hcl")
}

locals {
  common            = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
  base_module_path  = "${find_in_parent_folders("root.hcl")}/../modules"
}

terraform {
  source = "${local.base_module_path}/security_group"
}

inputs = {
  vpc_id      = local.common.vpc_id
  name_prefix = "${local.common.environment}-codebuild-sg"
  description = "Security group for CodeBuild inside VPC to access EKS and ECR"

  # Ingress not required unless other resources need to reach CodeBuild (rare)
  ingress_rules = []

  egress_rules = [
    {
      description     = "Allow DNS (UDP 53)"
      from_port       = 53
      to_port         = 53
      protocol        = "udp"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
    },
    {
      description     = "Allow HTTPS (TCP 443)"
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
    },
    {
      description     = "General egress fallback"
      from_port       = 0
      to_port         = 0
      protocol        = "-1"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
    }
  ]

  tags = local.common.tags
}