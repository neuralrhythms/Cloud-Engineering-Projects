# -----------------------------------------------------------------------------
# Transit Gateway Module - Variables
# -----------------------------------------------------------------------------

variable "name" {
  description = "Name prefix for all Transit Gateway resources"
  type        = string
}

variable "description" {
  description = "Description for the Transit Gateway"
  type        = string
  default     = "Landing Zone Transit Gateway"
}

variable "organization_arn" {
  description = "ARN of the AWS Organization for RAM sharing"
  type        = string
}

variable "egress_vpc_cidr" {
  description = "CIDR block for the centralized egress VPC"
  type        = string
  default     = "10.255.0.0/20"
}

variable "az_count" {
  description = "Number of availability zones for egress VPC"
  type        = number
  default     = 3
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "landing-zone"
    ManagedBy = "terraform"
    Layer     = "networking"
  }
}
