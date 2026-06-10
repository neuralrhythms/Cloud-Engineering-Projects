variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "event_bus_name" {
  description = "Name of the EventBridge event bus"
  type        = string
}

variable "notification_email" {
  description = "Email address for fraud alert notifications"
  type        = string
  default     = ""
}

variable "notification_phone" {
  description = "Phone number for SMS fraud alert notifications"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
