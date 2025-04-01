include {
  path = find_in_parent_folders("root.hcl")
}

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
  base_module_path = "${find_in_parent_folders("root.hcl")}/../modules"
}

terraform {
  source = "${local.base_module_path}/codebuild-runner"
}

dependency "codebuild_role" {
  config_path = "../codebuild_role"

  mock_outputs = {
    role_arn = "arn:aws:iam::123456789012:role/mock-codebuild-role"
  }
}

dependency "codebuild_sg" {
  config_path = "../codebuild-sg"

  mock_outputs = {
    security_group_id = "sg-mock"
  }
}

# Since the connection gets reused, use the one pre-setup in Parameter Store.
# dependency "codestar_connection" {
#   config_path = "../../codestar-connection"

#   mock_outputs = {
#     connection_arn  = "arn:aws:codestar-connections:us-west-2:123456789012:connection/mock-connection"
#     connection_name = "github-cybercussion"
#   }
# }

inputs = {
  project_name = "${local.common.environment}-${local.common.github_repo}-github-runner"
  service_role_arn     = dependency.codebuild_role.outputs.role_arn
  provider_type        = "GitHub"
  repo_url             = local.common.location
  connection_arn       = local.common.connection_arn
  connection_name      = local.common.connection_name
  compute_type         = local.common.compute_type
  image                = local.common.image
  privileged_mode      = local.common.privileged_mode
  enable_codebuild_vpc = true
  vpc_id               = local.common.vpc_id
  private_subnet_ids   = local.common.private_subnet_ids
  security_group_ids   = [dependency.codebuild_sg.outputs.security_group_id]

  # Tags for resources
  tags = local.common.tags
}