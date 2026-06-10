variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "instance_type" {
  description = "OpenSearch instance type"
  type        = string
}

variable "instance_count" {
  description = "Number of OpenSearch instances"
  type        = number
}

variable "subnet_ids" {
  description = "Subnet IDs for OpenSearch VPC configuration"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID for OpenSearch security group"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
