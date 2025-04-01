include {
  path = find_in_parent_folders("root.hcl")
}

locals {
  base_module_path = "${find_in_parent_folders("root.hcl")}/../modules"
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
}

terraform {
  source = "${local.base_module_path}/iam_role"
}

dependency "eks_cluster" {
  config_path = "../eks-cluster"
  #mock_outputs_merge_with_state = true
  mock_outputs = {
    oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/mock"
  }
}

inputs = {
  role_name = "${local.common.environment}-alb-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = dependency.eks_cluster.outputs.oidc_provider_arn
        },
        Action = "sts:AssumeRoleWithWebIdentity"
      }
      # {
      #   Effect = "Allow",
      #   Principal = {
      #     Federated = dependency.eks_cluster.outputs.oidc_provider_arn
      #   },
      #   Action = "sts:AssumeRoleWithWebIdentity",
      #   Condition = {
      #     StringEquals = {
      #       "${replace(dependency.eks_cluster.outputs.oidc_provider_arn, "arn:aws:iam::[0-9]+:oidc-provider/", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
      #     },
      #     StringLike = {
      #       "${replace(dependency.eks_cluster.outputs.oidc_provider_arn, "arn:aws:iam::[0-9]+:oidc-provider/", "")}:aud" = "sts.amazonaws.com"
      #     }
      #   }
      # }
    ]
  })
  # If you want your ALB controller to be able to create and manage ALBs, you need to attach the following policies.
  inline_policies = {
    "alb-inline-policy" = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Action = ["iam:CreateServiceLinkedRole"],
          Resource = "*"
        },
        {
          Effect = "Allow",
          Action = [
            "ec2:DescribeSubnets",
            "ec2:DescribeAvailabilityZones",
            "ec2:DescribeVpcs",
            "ec2:DescribeTags",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeInstances",
            "ec2:DescribeAddresses",
            "ec2:CreateSecurityGroup",
            "ec2:DeleteSecurityGroup",
            "ec2:AuthorizeSecurityGroupIngress",
            "ec2:RevokeSecurityGroupIngress",
            "ec2:AuthorizeSecurityGroupEgress",
            "ec2:RevokeSecurityGroupEgress",
            "ec2:ModifySecurityGroupRules",
            "ec2:CreateTags",
            "ec2:DeleteTags"
          ],
          Resource = "*"
        },
        {
          Effect = "Allow",
          Action = ["elasticloadbalancing:*"],
          Resource = "*"
        },
        {
          Effect = "Allow",
          Action = [
            "tag:GetResources",
            "tag:TagResources",
            "tag:UntagResources"
          ],
          Resource = "*"
        },
        {
          Effect = "Allow",
          Action = [
            "route53:ChangeResourceRecordSets",
            "route53:ListResourceRecordSets"
          ],
          Resource = "*"
        },
        {
          Effect = "Allow",
          Action = [
            "shield:GetSubscriptionState",
            "shield:DescribeProtection",
            "shield:CreateProtection",
            "shield:DeleteProtection"
          ],
          Resource = "*"
        },
        {
          Effect = "Allow",
          Action = [
            "wafv2:GetWebACLForResource",
            "wafv2:AssociateWebACL",
            "wafv2:DisassociateWebACL",
            "wafv2:CreateWebACL",
            "wafv2:DeleteWebACL",
            "wafv2:UpdateWebACL",
            "wafv2:GetWebACL",
            "waf-regional:GetWebACLForResource",
            "waf-regional:CreateWebACL",
            "waf-regional:DeleteWebACL",
            "waf-regional:UpdateWebACL",
            "waf-regional:AssociateWebACL",
            "waf-regional:DisassociateWebACL"
          ],
          Resource = "*"
        },
        {
          Effect = "Allow",
          Action = [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          Resource = "*"
        }
      ]
    })
  }


  managed_policies = [
    "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
  ]

  tags = local.common.tags
}