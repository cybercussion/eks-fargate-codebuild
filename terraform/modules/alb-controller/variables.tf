variable "env" {
  description = "The environment (e.g., dev, stage, prod)."
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "API endpoint for the EKS cluster"
  type        = string
}

variable "cluster_ca" {
  description = "Base64 encoded certificate authority data for the EKS cluster"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2" # Set a default region if not provided
}

variable "vpc_id" {
  description = "The ID of the VPC in which the ALB should be deployed"
  type        = string
}

variable "service_name" {
  description = "Name of the service for which the ALB is being created"
  type        = string
}

variable "ssm_domain_param" {
  description = "SSM Parameter name for the domain (e.g., /network/domain)."
  type        = string
}

variable "certificate_ssm_path" {
  description = "SSM parameter path for the HTTPS certificate ARN."
  type        = string
}

variable "irsa_role_arn" {
  description = "ARN of the IAM role for the ALB Controller to assume"
  type        = string
}

# variable "acm_certificate_arn" {
#   description = "The ARN of the ACM certificate to use for the ALB."
#   type        = string
# }

# variable "route53_url" {
#   description = "The Route 53 DNS name for the application (e.g., python-a-dev.cybercussion.com)."
#   type        = string
# }


variable "chart_version" {
  description = "Version of the AWS Load Balancer Controller Helm chart"
  type        = string
  default     = "1.7.1"  # Default to a commonly used version
}