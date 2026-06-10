variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "events_table_name" {
  description = "Name of the fraud events DynamoDB table"
  type        = string
}

variable "findings_table_name" {
  description = "Name of the fraud findings DynamoDB table"
  type        = string
}

variable "events_table_arn" {
  description = "ARN of the fraud events DynamoDB table"
  type        = string
}

variable "findings_table_arn" {
  description = "ARN of the fraud findings DynamoDB table"
  type        = string
}

variable "fraud_detector_arn" {
  description = "ARN of the Fraud Detector"
  type        = string
}

variable "timestream_database" {
  description = "Timestream database name"
  type        = string
}

variable "timestream_table" {
  description = "Timestream table name"
  type        = string
}

variable "neptune_endpoint" {
  description = "Neptune cluster endpoint"
  type        = string
}

variable "event_bus_arn" {
  description = "ARN of the EventBridge event bus"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for Lambda VPC configuration"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for Lambda VPC configuration"
  type        = list(string)
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

variable "lambda_execution_role" {
  description = "ARN of the Lambda execution IAM role"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
