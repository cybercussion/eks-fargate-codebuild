locals {
  aws_region        = get_env("AWS_REGION", "us-west-2")  # Defaults to us-west-2 if not set
  account_id        = get_aws_account_id()
  environment       = "dev"

  # Centralized CodeBuild Configuration
  github_repo_owner    = "cybercussion"
  github_repo          = "eks-fargate-codebuild"
  location             = "https://github.com/${local.github_repo_owner}/${local.github_repo}.git"
  # Retrieve connection details from SSM (Shared per Account)
  connection_arn       = run_cmd("aws", "ssm", "get-parameter", "--name", "/github/connection/arn", "--query", "Parameter.Value", "--output", "text")
  connection_name      = run_cmd("aws", "ssm", "get-parameter", "--name", "/github/connection/name", "--query", "Parameter.Value", "--output", "text")
  compute_type         = "BUILD_GENERAL1_SMALL"
  image                = "aws/codebuild/standard:7.0"
  privileged_mode      = true # You need this for Docker-in-Docker builds
  # VPC Configuration
  enable_codebuild_vpc = true # EKS is on a private VPC so enable this and apply after its setup.
  vpc_id               = "vpc-0baf82d68d911059f"  # Get this from eks vpc-subnet output or SSM
  private_subnet_ids   = ["subnet-0bd19c7d653a6f63b", "subnet-0f070cc833d7cd7e4"]  # manually off eks vpc-subnet
  # vpc_id = run_cmd("aws", "ssm", "get-parameter", "--name", "/vpc/id", "--query", "Parameter.Value", "--output", "text")
  # private_subnet_ids = split(",", run_cmd("aws", "ssm", "get-parameter", "--name", "/subnets/private", "--query", "Parameter.Value", "--output", "text"))

  tags = {
    Environment = local.environment
    Terraform   = "true"
    Team        = "platform"
    ManagedBy   = "terragrunt"
  }
}