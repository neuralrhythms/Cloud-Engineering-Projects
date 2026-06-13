variable "aws_region" {
  description = "Primary AWS region for deployment"
  type        = string
  default     = "ap-southeast-2"
}

variable "approved_regions" {
  description = "List of AWS regions permitted by SCP"
  type        = list(string)
  default     = ["ap-southeast-2", "ap-southeast-1"]
}

variable "owner_tag" {
  description = "Owner tag value applied to all resources"
  type        = string
  default     = "platform-team@example.com"
}

variable "cost_centre" {
  description = "Cost centre tag for billing allocation"
  type        = string
  default     = "CC-MIGRATION"
}
