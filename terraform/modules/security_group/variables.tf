variable "ingress_rules" {
  description = "List of ingress rules for the security group."
  type = list(object({
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_blocks     = list(string)
    security_groups = list(string)
  }))
  default = []
}

variable "egress_rules" {
  description = "List of egress rules for the security group."
  type = list(object({
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_blocks     = list(string)
    security_groups = list(string)
  }))
  default = []
}

variable "use_vpc_from_ssm" {
  description = "Whether to pull the VPC ID from SSM."
  type        = bool
  default     = false
}

variable "vpc_ssm_path" {
  description = "SSM parameter path for the VPC ID (optional if vpc_id is provided)"
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC ID to assign to the security group (used if not pulling from SSM)."
  type        = string
  default     = ""
}

variable "name_prefix" {
  description = "Prefix for the security group name."
  type        = string
}

variable "description" {
  description = "Description of the security group."
  type        = string
}

variable "tags" {
  description = "Tags to assign to the security group."
  type        = map(string)
  default     = {}
}