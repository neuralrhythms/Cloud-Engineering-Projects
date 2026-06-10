# -----------------------------------------------------------------------------
# Root Variables
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "fraud-detection"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "neptune_instance_class" {
  description = "Instance class for Neptune cluster"
  type        = string
  default     = "db.r5.large"
}

variable "opensearch_instance_type" {
  description = "Instance type for OpenSearch domain"
  type        = string
  default     = "t3.medium.search"
}

variable "opensearch_instance_count" {
  description = "Number of OpenSearch instances"
  type        = number
  default     = 2
}

variable "enable_neptune" {
  description = "Whether to deploy Neptune cluster (AML detection)"
  type        = bool
  default     = true
}

variable "enable_opensearch" {
  description = "Whether to deploy OpenSearch (analytics)"
  type        = bool
  default     = true
}

variable "enable_waf" {
  description = "Whether to deploy WAF rules on API Gateway"
  type        = bool
  default     = true
}

variable "notification_email" {
  description = "Email address for fraud alert notifications"
  type        = string
  default     = ""
}

variable "notification_phone" {
  description = "Phone number for SMS fraud alerts (E.164 format)"
  type        = string
  default     = ""
}
