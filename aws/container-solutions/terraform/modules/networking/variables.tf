variable "project" {
  description = "Project name used as a prefix for all resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, test, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of Availability Zones to deploy subnets into (minimum 3 for production)"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway (cost saving for dev/test). Set false for production HA."
  type        = bool
  default     = false
}

variable "cluster_name" {
  description = "EKS cluster name — required for subnet tagging"
  type        = string
}

variable "enable_vpc_endpoints" {
  description = "Enable VPC Interface Endpoints for AWS services"
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "CloudWatch log retention in days for VPC flow logs"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
