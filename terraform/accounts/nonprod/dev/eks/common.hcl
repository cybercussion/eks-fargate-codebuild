locals {
  aws_region        = get_env("AWS_REGION", "us-west-2")  # Defaults to us-west-2 if not set
  account_id        = get_aws_account_id()
  environment       = "dev"

  pod_role_name      = "${local.environment}-eks-cluster-fargate-pod-role"
  cluster_name       = "${local.environment}-eks-cluster"

  # Admin Group for EKS
  admin_users = ["mstatkus"]

  # Tags for all resources
  tags = {
    Environment = local.environment
    Terraform   = "true"
    Team        = "platform"
    ManagedBy   = "terragrunt"
  }

  # Networking configuration - if you change these you WILL need to destroy
  # Please verify your settings or consider using a network module instead of param store
  use_vpc_from_ssm = false
  vpc_ssm_path     = "/network/vpc2"
  # Public subnets for EKS Cluster (unless you generate the network module)
  subnet_ssm_paths_public = [
    "/network/subnet/public/2b",
    "/network/subnet/public/2c"
  ]
  
  # Private subnets for Fargate (unless you generate the network module)
  subnet_ssm_paths_private = [
    "/network/subnet/private/2b",
    "/network/subnet/private/2c"
  ]

  # Fargate Profiles
  use_fargate = true
  fargate_profiles = local.use_fargate ? flatten([
    [
      {
        name                   = "kube-system"
        pod_execution_role_arn = "arn:aws:iam::${local.account_id}:role/${local.pod_role_name}"
        selectors = [
          { namespace = "kube-system" }
        ]
      }
    ],
    [
      {
        name                   = "gitlab-runner"
        pod_execution_role_arn = "arn:aws:iam::${local.account_id}:role/${local.pod_role_name}"
        selectors = [
          { namespace = "default" }
        ]
      }
    ]
  ]) : []

  # Node groups fallback
  node_groups = {
    workers = {
      desired_capacity = 2
      max_size         = 4
      min_size         = 1
      instance_types   = ["t3.medium"]
      # key_name         = "my-ssh-key" # Optional
      labels = {
        "node.kubernetes.io/purpose" = "worker"
      }
      taints = []
    }
  }
}