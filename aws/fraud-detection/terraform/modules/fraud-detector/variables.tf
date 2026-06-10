variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "data_bucket_arn" {
  description = "ARN of the S3 bucket for training data"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
