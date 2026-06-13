variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "account_name" {
  description = "Short account name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (prod, nonprod, shared, sandbox)"
  type        = string
}

variable "is_management_account" {
  description = "Set true for management account — skips per-account CloudTrail"
  type        = bool
  default     = false
}

variable "is_shared_services" {
  description = "Set true for shared-services account — creates Terraform state resources"
  type        = bool
  default     = false
}

variable "cloudtrail_s3_bucket" {
  description = "S3 bucket name in log-archive account for CloudTrail logs"
  type        = string
}

variable "cloudtrail_kms_key_arn" {
  description = "KMS key ARN in log-archive account for CloudTrail log encryption"
  type        = string
}

variable "config_s3_bucket" {
  description = "S3 bucket name in log-archive account for Config snapshots"
  type        = string
}

variable "owner_tag" {
  type    = string
  default = "platform-team@example.com"
}

variable "cost_centre" {
  type    = string
  default = "CC-MIGRATION"
}
