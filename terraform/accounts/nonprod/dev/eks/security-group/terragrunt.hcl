# Include the root configuration for backend and provider setup
include {
  path = find_in_parent_folders("root.hcl")
}

# Load common configuration
locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
  base_module_path = "${find_in_parent_folders("root.hcl")}/../modules"
}

terraform {
  source = "${local.base_module_path}/security_group"  # Path to your security_group module
}

# Only used if use_vpc_from_ssm = false
dependency "vpc" {
  config_path = "../vpc-subnet"
  mock_outputs = {
    vpc_id = "vpc-mock"
  }
}

inputs = {
  # Retrieve the VPC ID from the SSM parameter
  # Dynamic VPC assignment
  use_vpc_from_ssm = local.common.use_vpc_from_ssm
  vpc_ssm_path     = local.common.use_vpc_from_ssm ? local.common.vpc_ssm_path : null
  vpc_id           = local.common.use_vpc_from_ssm ? null : dependency.vpc.outputs.vpc_id

  name_prefix = "${local.common.environment}-eks-cluster-sg"     # Security group name prefix
  description = "Security group for EKS cluster"

  # Define ingress and egress rules
  ingress_rules = [
    {
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"]  # Adjust this based on security needs
      security_groups = []
    },
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"]  # Adjust this based on security needs
      security_groups = []
    }
  ]

  egress_rules = [
    {
      from_port       = 0
      to_port         = 0
      protocol        = "-1"  # Allows all outbound traffic
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
    }
  ]

  tags = local.common.tags  # Tags from your common configuration
}