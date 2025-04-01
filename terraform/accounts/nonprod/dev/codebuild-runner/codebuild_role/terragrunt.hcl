include {
  path = find_in_parent_folders("root.hcl")
}

locals {
  # Load shared configuration from common.hcl
  common            = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
  base_module_path  = "${find_in_parent_folders("root.hcl")}/../modules"
  region            = local.common.aws_region
  account_id        = local.common.account_id
}

terraform {
  source = "${local.base_module_path}/iam_role"
}

inputs = {
  role_name = "${local.common.environment}-CodeBuildGitHubRunnerRole-${local.common.github_repo}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  managed_policies = []

  inline_policies = {
    "CodeBuildGitHubRunnerPolicy" = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          "Effect": "Allow",
          "Action": [
            "codebuild:StartBuild",
            "codebuild:BatchGetBuilds",
            "codebuild:ListBuilds",
            "codebuild:BatchGetProjects"
          ],
          "Resource": "*"
        },
        {
          "Effect": "Allow",
          "Action": [
            "codestar-connections:UseConnection",
            "codestar-connections:GetConnection",
            "codestar-connections:GetConnectionToken",
            "codeconnections:GetConnection",
            "codeconnections:GetConnectionToken"
          ],
          "Resource": [
            local.common.connection_arn,
            "arn:aws:codestar-connections:${local.region}:${local.account_id}:connection/*",
            "arn:aws:codeconnections:${local.region}:${local.account_id}:connection/*"
          ]
        },
        {
          "Effect": "Allow",
          "Action": [
            "codebuild:CreateWebhook",
            "codebuild:UpdateWebhook",
            "codebuild:DeleteWebhook"
          ],
          "Resource": "arn:aws:codebuild:${local.region}:${local.account_id}:project/*"
        },
        {
          "Effect": "Allow",
          "Action": [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource": "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/codebuild/*"
        },
        {
          "Effect": "Allow",
          "Action": [
            "s3:PutObject",
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:GetBucketAcl",
            "s3:GetBucketLocation"
          ],
          "Resource": "arn:aws:s3:::codepipeline-${local.region}-*"
        },
        {
          "Effect": "Allow",
          "Action": [
            "codebuild:CreateReportGroup",
            "codebuild:CreateReport",
            "codebuild:UpdateReport",
            "codebuild:BatchPutTestCases",
            "codebuild:BatchPutCodeCoverages"
          ],
          "Resource": "arn:aws:codebuild:${local.region}:${local.account_id}:report-group/*"
        },
        {
          "Effect": "Allow",
          "Action": [
            "iam:PassRole"
          ],
          "Resource": "arn:aws:iam::${local.account_id}:role/${local.common.environment}-CodeBuildGitHubRunnerRole-${local.common.github_repo}",
          "Condition": {
            "StringEqualsIfExists": {
              "iam:PassedToService": "codebuild.amazonaws.com"
            }
          }
        },
        {
          "Effect": "Allow",
          "Action": [
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "ecr:PutImage",
            "ecr:InitiateLayerUpload",
            "ecr:UploadLayerPart",
            "ecr:CompleteLayerUpload"
          ],
          "Resource": "*"
        },
        {
          "Effect": "Allow",
          "Action": [
            "eks:DescribeCluster"
          ],
          "Resource": "arn:aws:eks:${local.region}:${local.account_id}:cluster/*"
        },
        {
          "Effect": "Allow",
          "Action": [
            "ec2:CreateNetworkInterface",
            "ec2:DeleteNetworkInterface",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DescribeInstances",
            "ec2:DescribeInstanceTypes",
            "ec2:DescribeSubnets",
            "ec2:DescribeVpcs",
            "ec2:DescribeAvailabilityZones",
            "ec2:DescribeRouteTables",
            "ec2:DescribeDhcpOptions",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeNetworkAcls"
          ],
          "Resource": "*"
        },
        {
          "Effect": "Allow",
          "Action": [
            "ec2:CreateNetworkInterface",
            "ec2:CreateNetworkInterfacePermission"
          ],
          "Resource": "*",
          "Condition": {
            "StringEquals": {
              "ec2:AuthorizedService": "codebuild.amazonaws.com"
            }
          }
        },
        # {
        #   "Sid": "CodeBuildInVPCSecurityGroup",
        #   "Effect": "Allow",
        #   "Action": [
        #     "ec2:CreateNetworkInterface",
        #     "ec2:CreateNetworkInterfacePermission"
        #   ],
        #   "Resource": [
        #     "arn:aws:ec2:${region}:${account_id}:network-interface/*",
        #     "arn:aws:ec2:${region}:${account_id}:security-group/${security_group_id}"
        #   ],
        #   "Condition": {
        #     "StringEquals": {
        #       "ec2:AuthorizedService": "codebuild.amazonaws.com"
        #     }
        #   }
        # },
        {
          "Effect": "Allow",
          "Action": [
            "eks:GetToken",
            "eks:DescribeCluster",
            "eks:ListClusters",
            "eks:DescribeNodegroup",
            "eks:ListNodegroups",
            "eks:DescribeFargateProfile",
            "eks:ListFargateProfiles",
            "eks:DescribeAddon",
            "eks:ListAddons",
            "eks:DescribeUpdate",
            "eks:ListUpdates"
          ],
          "Resource": "arn:aws:eks:${local.region}:${local.account_id}:cluster/*"
        },
        {
          "Effect": "Allow",
          "Action": [
            "eks:UpdateClusterConfig",
            "eks:CreateNodegroup",
            "eks:DeleteNodegroup"
          ],
          "Resource": "arn:aws:eks:${local.region}:${local.account_id}:cluster/*"
        },
        {
          "Effect": "Allow",
          "Action": [
            "sts:GetCallerIdentity"
          ],
          "Resource": "*"
        },
        {
          "Effect": "Allow",
          "Action": [
            "ssm:GetParameter"
          ],
          "Resource": "arn:aws:ssm:${local.region}:${local.account_id}:parameter/eks/*"
        }
      ]
    })
  }

  tags = local.common.tags
}