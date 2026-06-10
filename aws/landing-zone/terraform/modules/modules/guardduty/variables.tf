# -----------------------------------------------------------------------------
# GuardDuty Module - Variables
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

variable "findings_bucket_arn" {
  description = "ARN of the S3 bucket for GuardDuty findings export"
  type        = string
  default     = ""
}

variable "findings_kms_key_arn" {
  description = "ARN of the KMS key for encrypting exported findings"
  type        = string
  default     = ""
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
