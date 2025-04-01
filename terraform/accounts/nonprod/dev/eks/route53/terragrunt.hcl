include {
  path = find_in_parent_folders("root.hcl")
}

locals {
  base_module_path = "${find_in_parent_folders("root.hcl")}/../modules"
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
}

terraform {
  source = "${local.base_module_path}/route53"
}

# Originally made a load balancer but opted to just use the one below this block.
# Dependency on the ALB module to retrieve the ALB DNS name and hosted zone ID
# dependency "alb" {
#   config_path = "../alb"

#   #mock_outputs_merge_with_state = true
#   mock_outputs = {
#     alb_dns_name_dualstack  = "dualstack.dev-eks-fargate-alb-1348242378.us-west-2.elb.amazonaws.com"
#     alb_zone_id             = "Z1H1FL5HABSF5"
#   }
# }

# This is created as apart of the alb-controller since doing kubectl (manual) vs Helm or ArgoCD
dependency "eks_ingress" {
  config_path = "../alb-controller"

  # Mock outputs for planning (optional, remove once real outputs work)
  mock_outputs = {
    alb_dns_name = "dualstack.dev-eks-fargate-alb-1348242378.us-west-2.elb.amazonaws.com"
    alb_zone_id  = "Z1H1FL5HABSF5"
  }
}

inputs = {
  # SSM Parameter for Domain
  ssm_domain_param = "/network/domain"

  # Route 53 Inputs for ALB
  target_dns_name       = dependency.eks_ingress.outputs.alb_dns_name
  target_hosted_zone_id = dependency.eks_ingress.outputs.alb_zone_id

  # Application and Environment Details
  app_name = local.common.service_name  # From common.hcl
  env      = local.common.environment   # From common.hcl

  tags = merge(
    local.common.tags,
    {
      Application = local.common.service_name
    }
  )
}