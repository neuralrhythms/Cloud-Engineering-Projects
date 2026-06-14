variable "project" {
  description = "Project name used as a prefix for repository names"
  type        = string
}

variable "repositories" {
  description = "List of ECR repository names to create (without project prefix)"
  type        = list(string)
  default     = ["sample-app"]
}

variable "image_tag_mutability" {
  description = "Image tag mutability setting (MUTABLE for dev/test, IMMUTABLE for prod)"
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for ECR image encryption"
  type        = string
}

variable "untagged_image_retention_days" {
  description = "Number of days to retain untagged images before expiry"
  type        = number
  default     = 7
}

variable "tagged_image_retention_count" {
  description = "Number of tagged images to retain per repository"
  type        = number
  default     = 20
}

variable "cross_account_arns" {
  description = "List of IAM principal ARNs allowed cross-account pull access"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
