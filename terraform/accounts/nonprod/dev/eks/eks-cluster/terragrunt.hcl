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
  source = "${local.base_module_path}/eks"
}

# Dependency for the pod role
dependency "pod_role" {
  config_path = "../pod-role"

  mock_outputs = {
    role_arn  = "arn:aws:iam::123456789012:role/mock-pod-role"
    role_name = "mock-pod-role"
  }
}

# Dependency for the EKS admin role
dependency "eks_admin_role" {
  config_path = "../eks-admin-role"

  mock_outputs = {
    role_arn  = "arn:aws:iam::123456789012:role/mock-eks-admin-role"
    role_name = "mock-eks-admin-role"
  }
}

# Mock outputs for self-managed node groups
dependency "self_managed_node_groups_mock" {
  config_path = null  # No actual dependency, just a placeholder for mocks

  mock_outputs = {
    self_managed_node_groups = {}
  }
}

# Dependency for the security group
dependency "security_group" {
  config_path = "../security-group"  # Path to the security group module

  mock_outputs = {
    security_group_id = "sg-12345678"  # Mock security group ID
    security_group_arn = "arn:aws:ec2:us-west-2:123456789012:security-group/sg-12345678"  # Mock security group ARN
  }
}

dependency "vpc" {
  config_path = "../vpc-subnet"
  mock_outputs = {
    vpc_id = "vpc-123456"
    public_subnet_ids  = ["subnet-aaaa", "subnet-bbbb"]
    private_subnet_ids = ["subnet-cccc", "subnet-dddd"]
  }
  skip = local.common.use_vpc_from_ssm
}

inputs = {
  # Cluster configuration
  cluster_name    = local.common.cluster_name
  cluster_version = "1.31"

  # AWS region
  region = local.common.aws_region

  # Networking configuration
  # vpc_ssm_path     = local.common.vpc_ssm_path
  # subnet_ssm_paths_public = local.common.subnet_ssm_paths_public  # Public subnets for EKS Cluster
  # subnet_ssm_paths_private = local.common.subnet_ssm_paths_private  # Private subnets for Fargate

  # Flexible VPC/Subnet handling
  vpc_id = local.common.use_vpc_from_ssm ? null : dependency.vpc.outputs.vpc_id
  vpc_ssm_path = local.common.use_vpc_from_ssm ? local.common.vpc_ssm_path : null

  subnet_ssm_paths_public  = local.common.use_vpc_from_ssm ? local.common.subnet_ssm_paths_public : []
  subnet_ssm_paths_private = local.common.use_vpc_from_ssm ? local.common.subnet_ssm_paths_private : []

  subnet_ids = local.common.use_vpc_from_ssm ? null : concat(
    dependency.vpc.outputs.private_subnet_ids,
    dependency.vpc.outputs.public_subnet_ids
  )

  # Fargate configuration
  use_fargate      = local.common.use_fargate
  fargate_profiles = local.common.fargate_profiles

  # Node group configuration
  node_groups = local.common.use_fargate ? {} : local.common.node_groups

  # Security Group configuration
  cluster_security_group_id = dependency.security_group.outputs.security_group_id  # Reference the mock security group

  # IAM roles
  pod_execution_role_arn = dependency.pod_role.outputs.role_arn  # Role for Fargate Pods
  eks_admin_role         = dependency.eks_admin_role.outputs.role_arn  # Admin role for cluster management

  # Tags for resources
  tags = local.common.tags
}