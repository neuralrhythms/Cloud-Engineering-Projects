# -----------------------------------------------------------------------------
# Layer 01: Organization - Variables
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "security_account_name" {
  description = "Name for the Security Tooling account"
  type        = string
  default     = "Security"
}

variable "security_account_email" {
  description = "Email for the Security Tooling account"
  type        = string
}

variable "log_archive_account_name" {
  description = "Name for the Log Archive account"
  type        = string
  default     = "Log Archive"
}

variable "log_archive_account_email" {
  description = "Email for the Log Archive account"
  type        = string
}

variable "network_account_name" {
  description = "Name for the Network account"
  type        = string
  default     = "Network"
}

variable "network_account_email" {
  description = "Email for the Network account"
  type        = string
}

variable "shared_services_account_name" {
  description = "Name for the Shared Services account"
  type        = string
  default     = "Shared Services"
}

variable "shared_services_account_email" {
  description = "Email for the Shared Services account"
  type        = string
}

variable "workload_accounts" {
  description = "List of workload accounts to create"
  type = list(object({
    name        = string
    email       = string
    environment = string
    team        = optional(string, "")
  }))
  default = []
}

variable "organization_role_name" {
  description = "Name of the cross-account access role in member accounts"
  type        = string
  default     = "OrganizationAccountAccessRole"
}

variable "allowed_regions" {
  description = "List of allowed AWS regions. Null means no region restriction"
  type        = list(string)
  default     = null
}
