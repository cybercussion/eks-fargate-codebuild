include {
  path = find_in_parent_folders("root.hcl")
}

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
  base_module_path = "${find_in_parent_folders("root.hcl")}/../modules"
}

terraform {
  source = "${local.base_module_path}/alb-controller"
}

dependency "eks_cluster" {
  config_path = "../eks-cluster"
  #mock_outputs_merge_with_state = true
  mock_outputs = {
    cluster_name                     = "mock"
    cluster_endpoint                 = "https://mock"
    cluster_ca_certificate           = "LS0tLS1NS0tLS0tCg=="
  }
}

dependency "alb_role" {
  config_path = "../alb-role"
  #mock_outputs_merge_with_state = true
  mock_outputs = {
    role_arn = "arn:aws:iam::123456789012:role/mock-alb-controller"
  }
}

dependency "vpc" {
  config_path = "../vpc-subnet"
  mock_outputs = {
    vpc_id = "vpc-123456"
  }
}

inputs = {
  ssm_domain_param     = "/network/domain"
  certificate_ssm_path = "/network/cert/us-west-2"
  service_name         = local.common.service_name
  env                  = local.common.environment
  cluster_name         = dependency.eks_cluster.outputs.cluster_name
  cluster_endpoint     = dependency.eks_cluster.outputs.cluster_endpoint
  cluster_ca           = dependency.eks_cluster.outputs.cluster_ca_certificate
  region               = local.common.aws_region
  vpc_id               = dependency.vpc.outputs.vpc_id
  irsa_role_arn        = dependency.alb_role.outputs.role_arn
  chart_version        = "1.7.1"
}