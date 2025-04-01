terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.93.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.36.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
  }
}

# Fetch VPC ID from SSM
data "aws_ssm_parameter" "vpc_id" {
  count = var.use_vpc_from_ssm ? 1 : 0
  name  = var.vpc_ssm_path
}

data "aws_ssm_parameter" "public_subnets" {
  for_each = var.use_vpc_from_ssm ? toset(var.subnet_ssm_paths_public) : []
  name     = each.value
}

data "aws_ssm_parameter" "private_subnets" {
  for_each = var.use_vpc_from_ssm ? toset(var.subnet_ssm_paths_private) : []
  name     = each.value
}

# Fetch Account ID
data "aws_caller_identity" "current" {}

# EKS Cluster Module
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "20.35.0"
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # Ensure nodes can only communicate within VPC
  node_security_group_additional_rules = var.use_fargate ? {} : {
    egress_vpc_only = {
      description = "Allow egress only within VPC"
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = [var.vpc_cidr_block]
    }
  }

  # Authentication configuration
  authentication_mode = "API_AND_CONFIG_MAP"

  access_entries = {
    admin_role = {
      kubernetes_groups = ["eks-admin-group"] # Changed from system:masters
      principal_arn =  var.eks_admin_role
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    admin_user = {
      kubernetes_groups = ["eks-admin-group"] # Changed from system:masters
      principal_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/mstatkus"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    github_runner = {
      kubernetes_groups = ["eks-github-runner-group"]  # Or a more restricted group based on your needs TODO: Fix this later.
      principal_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/dev-CodeBuildGitHubRunnerRole-eks-fargate-codebuild"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
  # Be very careful editing this, as you can lose access.  Hint: May require you to go into EKS Cluster
  # And set your access to recover.
  # access_entries = merge(
  #   # Admin role
  #   {
  #     admin_role = {
  #       kubernetes_groups = ["eks-admin-group"]
  #       principal_arn    = var.eks_admin_role
  #       policy_associations = {
  #         admin = {
  #           policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  #           access_scope = {
  #             type = "cluster"
  #           }
  #         }
  #       }
  #     }
  #   },
  #   # Admin users - this section was problematic but works off admin_users in common.hcl (locals)
  #   {
  #     for i, user in var.admin_users : "admin_user_${i + 1}" => {
  #       kubernetes_groups = ["eks-admin-group"]
  #       principal_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${user}"
  #       policy_associations = {
  #         admin = {
  #           policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  #           access_scope = {
  #             type = "cluster"
  #           }
  #         }
  #       }
  #     }
  #   }
  # )

  # Networking
  vpc_id = var.use_vpc_from_ssm ? data.aws_ssm_parameter.vpc_id[0].value : var.vpc_id

  subnet_ids = var.use_fargate ? (
    var.use_vpc_from_ssm ?
      [for ssm in data.aws_ssm_parameter.private_subnets : ssm.value] :
      var.private_subnet_ids
  ) : (
    var.use_vpc_from_ssm ?
      concat(
        [for ssm in data.aws_ssm_parameter.private_subnets : ssm.value],
        [for ssm in data.aws_ssm_parameter.public_subnets : ssm.value]
      ) :
      concat(var.private_subnet_ids, var.public_subnet_ids)
  )

  # Cluster Endpoint Configuration
  cluster_endpoint_private_access = var.cluster_endpoint_private_access
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access

  # Fargate Profiles
  fargate_profiles = var.fargate_profiles

  # Node Groups
  self_managed_node_groups = var.use_fargate ? {} : {
    for group_name, group_config in var.node_groups : group_name => {
      name            = group_name
      instance_type   = group_config.instance_types[0]
      desired_size    = group_config.desired_capacity
      max_size        = group_config.max_size
      min_size        = group_config.min_size
      subnet_ids      = [for ssm in data.aws_ssm_parameter.private_subnets : ssm.value]
      tags = merge(
        var.tags,
        {
          "Name" = "${var.cluster_name}-${group_name}"
        }
      )
      # Add custom security group rules
      additional_security_group_rules = {
        egress_vpc_only = {
          description = "Allow egress only within VPC"
          type        = "egress"
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = [var.vpc_cidr_block]
        }
      }
      # Disable default security group rules if possible
      use_default_security_group = false  # May not be supported; see below
    }
  }

  # CoreDNS configuration
  cluster_addons = {
    coredns = {
      most_recent = true
      preserve    = true
      timeouts = {
        create = "40m"
        update = "40m"
        delete = "10m"
      }
      configuration_values = jsonencode({
        tolerations = [
          {
            key      = "eks.amazonaws.com/compute-type"
            operator = "Equal"
            value    = "fargate"
            effect   = "NoSchedule"
          }
        ]
      })
    }
  }

  tags = var.tags
}

# Get cluster authentication token
data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

resource "time_sleep" "wait_for_access" {
  depends_on = [module.eks]
  create_duration = "30s"
}

# Role Binding to Map eks-admins Group to Cluster Admin Role
resource "kubernetes_role_binding" "eks_admin" {
  metadata {
    name      = "eks-admin-binding"
    namespace = "kube-system"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "Group"
    name      = "eks-admins" # Match the custom group
    api_group = "rbac.authorization.k8s.io"
  }
  depends_on = [time_sleep.wait_for_access] # Adjusted to give it some lead time for mapping (occasional Error: Unauthorized)
  #depends_on = [module.eks]
}
# Or Cluster Wide
# resource "kubernetes_cluster_role_binding" "eks_admin" {
#   metadata {
#     name = "eks-admin-binding"
#   }

#   role_ref {
#     api_group = "rbac.authorization.k8s.io"
#     kind      = "ClusterRole"
#     name      = "cluster-admin"
#   }

#   subject {
#     kind      = "Group"
#     name      = "eks-admins"
#     api_group = "rbac.authorization.k8s.io"
#   }
#   depends_on = [module.eks]
# }

# resource "aws_vpc_endpoint" "eks" {
#   vpc_id             = var.vpc_id
#   service_name       = "com.amazonaws.${var.region}.eks"
#   subnet_ids         = var.private_subnet_ids
#   security_group_ids = var.security_group_ids
# }