variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "account_name" {
  description = "Short account name used in resource naming (e.g. workload-prod, shared-services)"
  type        = string
}

variable "environment" {
  description = "Environment tag (prod, nonprod, shared, sandbox)"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "public_subnets" {
  description = "List of public subnets"
  type = list(object({
    name = string
    cidr = string
    az   = string
  }))
  default = []
}

variable "app_subnets" {
  description = "List of application tier subnets"
  type = list(object({
    name = string
    cidr = string
    az   = string
  }))
  default = []
}

variable "data_subnets" {
  description = "List of data tier subnets"
  type = list(object({
    name = string
    cidr = string
    az   = string
  }))
  default = []
}

variable "tgw_subnets" {
  description = "List of Transit Gateway attachment subnets"
  type = list(object({
    name = string
    cidr = string
    az   = string
  }))
  default = []
}

variable "transit_gateway_id" {
  description = "Transit Gateway ID for VPC attachment (leave empty for network-hub account)"
  type        = string
  default     = ""
}

variable "create_igw" {
  description = "Whether to create an Internet Gateway (true for public-facing VPCs)"
  type        = bool
  default     = false
}

variable "create_nat_gateway" {
  description = "Whether to create NAT Gateway(s) for private subnet egress"
  type        = bool
  default     = false
}

variable "create_interface_endpoints" {
  description = "Whether to create interface VPC endpoints for AWS services"
  type        = bool
  default     = true
}

variable "flow_logs_s3_arn" {
  description = "S3 bucket ARN in log-archive account for VPC Flow Logs"
  type        = string
}

variable "owner_tag" {
  description = "Owner tag value"
  type        = string
  default     = "platform-team@example.com"
}

variable "cost_centre" {
  description = "Cost centre tag"
  type        = string
  default     = "CC-MIGRATION"
}
