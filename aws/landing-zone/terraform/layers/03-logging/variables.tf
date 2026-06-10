# -----------------------------------------------------------------------------
# Layer 03: Logging - Variables
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "log_archive_account_id" {
  description = "Account ID of the Log Archive account"
  type        = string
}

variable "management_account_id" {
  description = "Account ID of the Management account"
  type        = string
}

variable "organization_role_name" {
  description = "Name of the cross-account access role"
  type        = string
  default     = "OrganizationAccountAccessRole"
}

variable "cloudtrail_name" {
  description = "Name of the organization CloudTrail"
  type        = string
  default     = "organization-trail"
}

variable "log_retention_days" {
  description = "Number of days to retain logs before expiration"
  type        = number
  default     = 2555  # ~7 years
}

variable "organization_account_ids" {
  description = "List of all account IDs in the organization (for bucket policies)"
  type        = list(string)
  default     = []
}
