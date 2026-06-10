variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "instance_class" {
  description = "Neptune instance class"
  type        = string
  default     = "db.r5.large"
}

variable "subnet_ids" {
  description = "List of subnet IDs for Neptune subnet group"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID for Neptune security group"
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
