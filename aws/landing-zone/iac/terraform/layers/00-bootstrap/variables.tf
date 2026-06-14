# -----------------------------------------------------------------------------
# Layer 00: Bootstrap - Variables
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "Primary AWS region for the landing zone"
  type        = string
  default     = "us-east-1"
}

variable "terraform_role_arn" {
  description = "ARN of the IAM role used by Terraform for state access"
  type        = string
  default     = ""
}

variable "enable_github_oidc" {
  description = "Whether to create GitHub OIDC provider for CI/CD"
  type        = bool
  default     = true
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = ""
}
