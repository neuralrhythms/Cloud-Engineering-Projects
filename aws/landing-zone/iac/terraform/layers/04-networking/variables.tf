# -----------------------------------------------------------------------------
# Layer 04: Networking - Variables
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "network_account_id" {
  description = "Account ID of the Network account"
  type        = string
}

variable "organization_role_name" {
  description = "Name of the cross-account access role"
  type        = string
  default     = "OrganizationAccountAccessRole"
}

variable "organization_arn" {
  description = "ARN of the AWS Organization"
  type        = string
}

variable "transit_gateway_name" {
  description = "Name prefix for Transit Gateway resources"
  type        = string
  default     = "landing-zone"
}

variable "egress_vpc_cidr" {
  description = "CIDR for the centralized egress VPC"
  type        = string
  default     = "10.255.0.0/20"
}

variable "shared_services_vpc_cidr" {
  description = "CIDR for the shared services VPC"
  type        = string
  default     = "10.254.0.0/20"
}

variable "flow_logs_bucket_arn" {
  description = "ARN of the centralized VPC Flow Logs S3 bucket"
  type        = string
}

variable "az_count" {
  description = "Number of availability zones"
  type        = number
  default     = 3
}
