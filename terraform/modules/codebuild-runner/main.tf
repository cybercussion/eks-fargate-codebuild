terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.93.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.3"
    }
  }

  backend "s3" {}
}

# This requires manual action, not worth doing it here or it will fail.
# Also you only need one connection so no reason to keep replicating this.
# resource "aws_codestarconnections_connection" "this" {
#   name          = var.connection_name
#   provider_type = "GitHub"
# }

# I've reviewed Cloudformation and Terraform, I don't see a mechanism
# for getting the codestar connection arn into this.  Its like its almost
# implied, however when this creates it it seems to default to the runner
# provider, the credential is successfully connected, however the check
# box for "Use override credentials for this project only" where you pick the
# connection to the actual "github-runner" w/ ARN is not.
# Possible workaround it to use a null_resource and execute this.
# aws codebuild update-project \
#   --name github-runner \
#   --source "type=GITHUB,location=https://github.com/cybercussion/aws-codebuild-gh-runner,auth={type=CODECONNECTIONS,resource=arn:aws:codestar-connections:<region>:<account_id>:connection/<hash>},gitCloneDepth=1,buildspec=version: 0.2\\n\\nphases:\\n  build:\\n    commands:\\n       - echo \"Github Runner\""
resource "aws_codebuild_project" "runner" {
  name          = var.project_name
  description   = "${var.provider_type} Actions Runner in AWS CodeBuild"
  service_role  = var.service_role_arn
  build_timeout = 60
  queued_timeout = 480
  source {
    type            = upper(var.provider_type) 
    #location        = "CODEBUILD_DEFAULT_WEBHOOK_SOURCE_LOCATION"
    location        = var.repo_url
    git_clone_depth = 1
    buildspec       = <<-EOT
      version: 0.2
      phases:
        build:
          commands:
            - echo "${var.provider_type} Runner"
    EOT
    report_build_status = true
    insecure_ssl        = false
    # See Issue: https://github.com/hashicorp/terraform-provider-aws/issues/38572
    # auth {
    #   type = "CODECONNECTIONS"
    #   resource = var.connection_arn
    # }
  }

  dynamic "vpc_config" {
    for_each = var.enable_codebuild_vpc ? [1] : []
    content {
      vpc_id             = var.vpc_id
      subnets            = var.private_subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  environment {
    compute_type    = var.compute_type
    image          = var.image
    type           = "LINUX_CONTAINER"
    privileged_mode = var.privileged_mode
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  cache {
    type = "NO_CACHE"
  }

  logs_config {
    cloudwatch_logs {
      group_name = "/aws/codebuild/${lower(var.provider_type)}-runner"
    }
  }

  tags = var.tags
}

# Workaround for missing auth block mentioned above
resource "null_resource" "fix_codestar_connection" {
  provisioner "local-exec" {
    command = <<EOT
      echo "Running AWS CLI command to fix CodeBuild authentication..."
      aws codebuild update-project --name ${var.project_name} \
        --source "{\"type\": \"${upper(var.provider_type)}\", \"location\": \"${var.repo_url}\", \"auth\": {\"type\": \"CODECONNECTIONS\", \"resource\": \"${var.connection_arn}\"}}"
      
      echo "Checking if auth is correctly applied:"
      aws codebuild batch-get-projects --names ${var.project_name} --query "projects[*].source.auth"
    EOT
  }

  triggers = {
    always_run = timestamp()  # Forces Terraform to execute this every time
  }

  depends_on = [aws_codebuild_project.runner]
}

# Found terraform on this block doesn't have a way of dealing what is already made.
# What is already created results in a "Webhook already exists for this project" error.
# resource "aws_codebuild_webhook" "github_runner_webhook" {
#   project_name = aws_codebuild_project.github_runner.name
#   build_type   = "BUILD"

#   filter_group {
#     filter {
#       type    = "EVENT"
#       pattern = "WORKFLOW_JOB_QUEUED"
#     }
#   }
#   lifecycle {
#     create_before_destroy = true  # Ensures Terraform doesn't fail if the webhook already exists
#     ignore_changes = [filter_group]  # Prevents unnecessary re-creation
#   }
#   depends_on = [null_resource.fix_codestar_connection] 
# }

resource "null_resource" "create_webhook" {
  provisioner "local-exec" {
    command = <<EOT
      if ! aws codebuild batch-get-projects --names ${var.project_name} --query "projects[0].webhook" --output json | grep -q "filterGroups"; then
        echo "Creating webhook for ${var.project_name}..."
        aws codebuild create-webhook --project-name ${var.project_name} \
          --filter-groups '[ [ { "type": "EVENT", "pattern": "WORKFLOW_JOB_QUEUED" } ] ]'
      else
        echo "Webhook already exists, skipping creation."
      fi
    EOT
  }

  depends_on = [null_resource.fix_codestar_connection]
}