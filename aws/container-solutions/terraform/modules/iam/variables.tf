variable "project" {
  description = "Project name used as a prefix for all resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, test, prod)"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider (required for IRSA roles)"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the EKS OIDC provider (without https://)"
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
