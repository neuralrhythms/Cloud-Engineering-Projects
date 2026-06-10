# -----------------------------------------------------------------------------
# VPC Module - Variables
# -----------------------------------------------------------------------------

variable "name" {
  description = "Name prefix for all VPC resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 3
}

variable "subnet_newbits" {
  description = "Number of bits to add to the VPC CIDR for subnet calculation"
  type        = number
  default     = 4
}

variable "enable_public_subnets" {
  description = "Whether to create public subnets with Internet Gateway"
  type        = bool
  default     = true
}

variable "enable_isolated_subnets" {
  description = "Whether to create isolated subnets (no internet access, no NAT)"
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT Gateways for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway (cost savings for non-prod)"
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Whether to enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "flow_logs_bucket_arn" {
  description = "ARN of the S3 bucket for VPC Flow Logs"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
