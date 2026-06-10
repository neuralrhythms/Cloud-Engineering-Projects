variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "findings_table_stream_arn" {
  description = "Stream ARN of the fraud findings DynamoDB table"
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
