# -----------------------------------------------------------------------------
# Security Baseline Module - Variables
# -----------------------------------------------------------------------------

variable "ebs_kms_key_arn" {
  description = "ARN of the KMS key for EBS default encryption. If empty, uses AWS-managed key"
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

variable "sns_kms_key_id" {
  description = "KMS key ID for encrypting SNS messages"
  type        = string
  default     = "alias/aws/sns"
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
