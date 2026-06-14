variable "project" {
  description = "Project name"
  type        = string
  default     = "eks-platform"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "ecr_repositories" {
  description = "List of ECR repositories to create"
  type        = list(string)
  default     = ["sample-app"]
}

variable "allowed_public_cidrs" {
  description = "CIDR blocks allowed to access the EKS public API endpoint (dev only)"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict to office/VPN IPs in real deployments
}

variable "platform_admin_role_arn" {
  description = "ARN of the IAM role for platform administrators"
  type        = string
}

variable "alert_email_addresses" {
  description = "Email addresses for CloudWatch alarm notifications"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}
