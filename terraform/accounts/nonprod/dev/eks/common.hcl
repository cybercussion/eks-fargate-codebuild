locals {
  aws_region        = get_env("AWS_REGION", "us-west-2")  # Defaults to us-west-2 if not set
  account_id        = get_aws_account_id()
  environment       = "dev"

  pod_role_name      = "${local.environment}-eks-cluster-fargate-pod-role"
  cluster_name       = "${local.environment}-eks-cluster"

  project_name          = "eks-fargate-demo"
  service_name          = "python-a"

  # Admin Group for EKS
  admin_users = ["mstatkus"]

  # Map of placeholder images by port
  port                     = "5000"
  enable_placeholder_image = false
  placeholder_tag          = "latest"
  placeholder_images       = {
    "80"    = "nginx:latest"        # Default web server
    "3000"  = "node:20-alpine"      # Node.js https://nodejs.org/en
    "5000"  = "python:3.12-alpine"  # Python Flask/Django https://flask.palletsprojects.com/en/stable/
    "8080"  = "openjdk:11-jre"      # Java/Spring Boot https://spring.io/projects/spring-boot
    "8501"  = "python:3.12-alpine"  # Streamlit https://streamlit.io
    "9000"  = "php:8.4-apache"      # PHP https://www.php.net/releases/8.0/en.php
  }
  placeholder_image = lookup(local.placeholder_images, local.port, "python:3.12-alpine")

  # Tags for all resources
  tags = {
    Environment = local.environment
    Terraform   = "true"
    Team        = "platform"
    ManagedBy   = "terragrunt"
  }

  k8s           = true  # Enable Kubernetes-specific subnet tagging
  map_public_ip = false  # Default to false for Fargate use case
  # Networking configuration - if you change these you WILL need to destroy
  # Please verify your settings or consider using a network module instead of param store
  cluster_endpoint_public_access  = true  # Enable during bootstrap
  cluster_endpoint_private_access = true  # Still keep internal access

  # VPC Configuration (/24 small to medium, /22 medium to large)
  # Public Subnets (1 per AZ)
  public_subnet_1_cidr  = "10.10.1.0/24"  # AZ-a
  public_subnet_2_cidr  = "10.10.2.0/24"  # AZ-b
  public_subnet_3_cidr  = "10.10.3.0/24"  # AZ-c

  # Private Subnets (1 per AZ, for EKS nodes or Fargate)
  private_subnet_1_cidr = "10.10.4.0/24"  # AZ-a
  private_subnet_2_cidr = "10.10.5.0/24"  # AZ-b
  private_subnet_3_cidr = "10.10.6.0/24"  # AZ-c

  az_1 = "us-west-2a"
  az_2 = "us-west-2b"
  az_3 = "us-west-2c"

  use_vpc_from_ssm = false # Set to true if you want to use an existing VPC from SSM
  vpc_ssm_path     = "/network/vpc2"
  # Public subnets for EKS Cluster (unless you generate the network module)
  subnet_ssm_paths_public = [
    "/network/subnet/public/2a",
    "/network/subnet/public/2b",
    "/network/subnet/public/2c"
  ]
  
  # Private subnets for Fargate (unless you generate the network module)
  subnet_ssm_paths_private = [
    "/network/subnet/private/2a",
    "/network/subnet/private/2b",
    "/network/subnet/private/2c"
  ]

  # Subnet layout supports both ALB and NLB:
  #
  # - ALB (Application Load Balancer)
  #   - Works at Layer 7 (HTTP/HTTPS)
  #   - Supports path-based and host-based routing
  #   - Requires at least 2 public subnets across AZs
  #   - Automatically assigns public IPs unless internal
  #
  # - NLB (Network Load Balancer)
  #   - Works at Layer 4 (TCP/UDP)
  #   - Ideal for high-performance or static IP needs
  #   - Can be public or internal
  #   - If internal, must be placed in private subnets
  #
  # For Kubernetes ingress (e.g. AWS Load Balancer Controller),
  # ALB is typically used for HTTP(S) traffic.

  # Fargate Profiles
  use_fargate = true
  # Define Fargate profiles only if Fargate is enabled
  fargate_profiles = local.use_fargate ? flatten([

    # Profile to run system-level Kubernetes pods like CoreDNS on Fargate
    [
      {
        name                   = "kube-system"  # Profile name
        pod_execution_role_arn = "arn:aws:iam::${local.account_id}:role/${local.pod_role_name}"  # IAM role Fargate uses to run pods
        selectors = [
          {
            namespace = "kube-system"  # Target only pods in the 'kube-system' namespace
          }
        ]
      }
    ],

    # Profile to run application pods in the 'default' namespace on Fargate
    [
      {
        name                   = "default"  # Profile name
        pod_execution_role_arn = "arn:aws:iam::${local.account_id}:role/${local.pod_role_name}"  # Same IAM role for simplicity
        selectors = [
          {
            namespace = "default"  # Target app pods deployed in the 'default' namespace
          }
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