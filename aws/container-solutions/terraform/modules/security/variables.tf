variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, test, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (used for security group association)"
  type        = string
}

variable "enable_guardduty" {
  description = "Enable Amazon GuardDuty"
  type        = bool
  default     = true
}

variable "enable_security_hub" {
  description = "Enable AWS Security Hub"
  type        = bool
  default     = true
}

variable "enable_config" {
  description = "Enable AWS Config"
  type        = bool
  default     = true
}

variable "cloudtrail_s3_bucket_name" {
  description = "S3 bucket name for CloudTrail logs"
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
