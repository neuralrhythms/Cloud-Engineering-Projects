# -----------------------------------------------------------------------------
# Layer 06: Workloads - Variables
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "workload_accounts" {
  description = "List of workload accounts to configure"
  type = list(object({
    name                     = string
    account_id               = string
    environment              = string
    team                     = optional(string, "")
    vpc_cidr                 = string
    include_global_resources = optional(bool, false)
  }))
  default = []
}

variable "config_bucket_name" {
  description = "Name of the centralized Config delivery bucket"
  type        = string
}

variable "flow_logs_bucket_arn" {
  description = "ARN of the centralized VPC Flow Logs S3 bucket"
  type        = string
}

variable "transit_gateway_id" {
  description = "ID of the Transit Gateway to attach workload VPCs"
  type        = string
}

variable "organization_role_name" {
  description = "Name of the cross-account access role"
  type        = string
  default     = "OrganizationAccountAccessRole"
}

variable "trusted_admin_arns" {
  description = "ARNs trusted to assume support/admin roles"
  type        = list(string)
  default     = []
}

variable "az_count" {
  description = "Number of availability zones"
  type        = number
  default     = 3
}
