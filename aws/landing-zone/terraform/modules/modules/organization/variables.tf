# -----------------------------------------------------------------------------
# Organization Module - Variables
# -----------------------------------------------------------------------------

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
  description = "Name of the IAM role created in member accounts for cross-account access"
  type        = string
  default     = "OrganizationAccountAccessRole"
}

variable "allowed_regions" {
  description = "List of AWS regions to allow. If null, region restriction SCP is not applied"
  type        = list(string)
  default     = null
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "landing-zone"
    ManagedBy = "terraform"
    Layer     = "organization"
  }
}
