variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "api_arn" {
  description = "ARN of the API Gateway stage to associate with WAF"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
