# Include the root configuration for backend and provider setup
include {
  path = find_in_parent_folders("root.hcl")
}

# Load common configuration
locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
  base_module_path = "${find_in_parent_folders("root.hcl")}/../modules"
}

# Terragrunt module configuration for VPC and subnets
terraform {
  source = "${local.base_module_path}/vpc_subnet"
}

inputs = {
  # VPC and Subnet configuration
  vpc_cidr_block        = local.common.vpc_cidr_block
  public_subnet_1_cidr  = local.common.public_subnet_1_cidr
  public_subnet_2_cidr  = local.common.public_subnet_2_cidr
  private_subnet_1_cidr = local.common.private_subnet_1_cidr
  private_subnet_2_cidr = local.common.private_subnet_2_cidr

  # Availability Zones for the subnets
  az_1                  = local.common.az_1
  az_2                  = local.common.az_2

  # Project details
  project_name = "${local.common.environment}-eks-cluster"

  k8s = local.common.k8s

  map_public_ip = local.common.map_public_ip

  # Tags for resources
  tags = local.common.tags 
}