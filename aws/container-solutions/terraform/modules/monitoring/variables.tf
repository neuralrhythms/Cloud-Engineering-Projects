variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name (used for CloudWatch log group naming)"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for CloudWatch Logs encryption"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 90
}

variable "alert_email_addresses" {
  description = "List of email addresses for CloudWatch Alarm notifications"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
