# -----------------------------------------------------------------------------
# Account Baseline Module - Variables
# -----------------------------------------------------------------------------

variable "account_name" {
  description = "Name of the account (used for S3 prefix)"
  type        = string
}

variable "config_bucket_name" {
  description = "Name of the centralized S3 bucket for Config delivery"
  type        = string
}

variable "ebs_kms_key_arn" {
  description = "ARN of the KMS key for EBS default encryption"
  type        = string
  default     = ""
}

variable "create_support_role" {
  description = "Whether to create the AWS Support access role"
  type        = bool
  default     = true
}

variable "trusted_principal_arns" {
  description = "List of principal ARNs trusted to assume the support role"
  type        = list(string)
  default     = []
}

variable "create_notification_topic" {
  description = "Whether to create the security notifications SNS topic"
  type        = bool
  default     = true
}

variable "include_global_resources" {
  description = "Whether Config records global resource types"
  type        = bool
  default     = true
}

variable "enable_default_config_rules" {
  description = "Whether to enable default AWS Config rules"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "landing-zone"
    ManagedBy = "terraform"
  }
}
