# -----------------------------------------------------------------------------
# AWS Config Module - Variables
# -----------------------------------------------------------------------------

variable "recorder_name" {
  description = "Name for the Config recorder"
  type        = string
  default     = "default"
}

variable "config_bucket_name" {
  description = "Name of the S3 bucket for Config delivery"
  type        = string
}

variable "s3_key_prefix" {
  description = "S3 key prefix for Config snapshots"
  type        = string
  default     = "config"
}

variable "sns_topic_arn" {
  description = "ARN of SNS topic for Config notifications"
  type        = string
  default     = ""
}

variable "include_global_resources" {
  description = "Whether to include global resource types in recording"
  type        = bool
  default     = true
}

variable "is_aggregator" {
  description = "Whether to create an organization-level Config aggregator (Security account only)"
  type        = bool
  default     = false
}

variable "enable_default_rules" {
  description = "Whether to enable default Config rules"
  type        = bool
  default     = true
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
