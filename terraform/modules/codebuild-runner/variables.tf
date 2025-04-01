variable "project_name" {
  description = "Name of the CodeBuild project"
  type        = string
}

variable "connection_arn" {
  description = "CodeStar Connection ARN for GitHub authentication"
  type        = string
}

variable "connection_name" {
  description = "CodeStar Connection Name"
  type        = string
}

variable "provider_type" {
  description = "The source provider for CodeBuild (GitHub or GitLab)"
  type        = string
  validation {
    condition     = contains(["GitHub", "GitLab"], var.provider_type)
    error_message = "Allowed values: GitHub, GitLab."
  }
}

variable "service_role_arn" {
  description = "IAM role ARN for CodeBuild"
  type        = string
}

variable "repo_url" {
  description = "GitHub repository URL"
  type        = string
}

variable "compute_type" {
  description = "Compute type for CodeBuild"
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
}

variable "image" {
  description = "Docker image for CodeBuild"
  type        = string
  default     = "aws/codebuild/standard:6.0"
}

variable "privileged_mode" {
  description = "Enable Docker-in-Docker (required for building containers)"
  type        = bool
  default     = false
}

variable "enable_codebuild_vpc" {
  type        = bool
  description = "Whether to enable VPC config for CodeBuild"
  default     = false
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for CodeBuild VPC config"
  default     = null
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for CodeBuild"
  default     = []
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs for CodeBuild"
  default     = []
}

variable "tags" {
  description = "Tags for the CodeBuild project"
  type        = map(string)
  default     = {}
}