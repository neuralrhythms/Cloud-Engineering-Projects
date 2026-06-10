# -----------------------------------------------------------------------------
# Layer 02: Security - Variables
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "security_account_id" {
  description = "Account ID of the Security Tooling account"
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

variable "guardduty_findings_bucket_arn" {
  description = "ARN of the S3 bucket for GuardDuty findings export"
  type        = string
  default     = ""
}

variable "logging_kms_key_arn" {
  description = "ARN of the KMS key in the logging account"
  type        = string
  default     = ""
}

variable "config_bucket_name" {
  description = "Name of the centralized Config delivery bucket"
  type        = string
}

variable "enable_nist_standard" {
  description = "Whether to enable NIST 800-53 standard in Security Hub"
  type        = bool
  default     = false
}
