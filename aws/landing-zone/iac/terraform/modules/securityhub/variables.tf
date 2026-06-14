# -----------------------------------------------------------------------------
# Security Hub Module - Variables
# -----------------------------------------------------------------------------

variable "security_account_id" {
  description = "Account ID of the Security Tooling account (delegated admin)"
  type        = string
  default     = ""
}

variable "is_delegated_admin_setup" {
  description = "Set to true when running in management account to designate delegated admin"
  type        = bool
  default     = false
}

variable "enable_aws_foundational_standard" {
  description = "Enable AWS Foundational Security Best Practices standard"
  type        = bool
  default     = true
}

variable "enable_cis_standard" {
  description = "Enable CIS AWS Foundations Benchmark standard"
  type        = bool
  default     = true
}

variable "enable_nist_standard" {
  description = "Enable NIST 800-53 Rev 5 standard"
  type        = bool
  default     = false
}

variable "enable_cross_region_aggregation" {
  description = "Enable cross-region finding aggregation"
  type        = bool
  default     = true
}

variable "enable_notifications" {
  description = "Whether to create EventBridge rules for findings notifications"
  type        = bool
  default     = true
}

variable "notification_topic_arn" {
  description = "ARN of the SNS topic for security notifications"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "landing-zone"
    ManagedBy = "terraform"
    Layer     = "security"
  }
}
