variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  type        = string
}

variable "events_table_name" {
  description = "Name of the DynamoDB events table"
  type        = string
}

variable "events_table_arn" {
  description = "ARN of the DynamoDB events table"
  type        = string
}

variable "lambda_execution_role" {
  description = "ARN of the Lambda execution IAM role"
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
