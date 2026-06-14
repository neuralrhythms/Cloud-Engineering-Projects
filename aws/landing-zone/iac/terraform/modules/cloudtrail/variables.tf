# -----------------------------------------------------------------------------
# CloudTrail Module - Variables
# -----------------------------------------------------------------------------

variable "trail_name" {
  description = "Name of the CloudTrail trail"
  type        = string
  default     = "organization-trail"
}

variable "log_bucket_name" {
  description = "Name of the S3 bucket in the Log Archive account for CloudTrail logs"
  type        = string
}

variable "s3_key_prefix" {
  description = "S3 key prefix for CloudTrail logs"
  type        = string
  default     = "cloudtrail"
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encrypting CloudTrail logs"
  type        = string
}

variable "enable_insights" {
  description = "Whether to enable CloudTrail Insights"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "landing-zone"
    ManagedBy = "terraform"
    Layer     = "logging"
  }
}
