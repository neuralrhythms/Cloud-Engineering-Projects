variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "app_subnet_ids" {
  type = list(string)
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener"
  type        = string
}

variable "alb_access_logs_bucket" {
  description = "S3 bucket name for ALB access logs"
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ECS task execution IAM role ARN"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "ECS task IAM role ARN for application permissions"
  type        = string
}

variable "ec2_instance_profile_name" {
  description = "IAM instance profile name for rehosted EC2 workloads"
  type        = string
}

variable "kms_key_ebs_arn" {
  description = "KMS CMK ARN for EBS encryption"
  type        = string
}

variable "db_secret_arn" {
  description = "Secrets Manager ARN for DB connection string injected into ECS tasks"
  type        = string
}

variable "sddc_cidr_blocks" {
  description = "CIDR blocks of SDDC for MGN agent inbound replication"
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "ecs_web_desired_count" {
  description = "Desired ECS web task count (minimum)"
  type        = number
  default     = 2
}

variable "ecs_web_max_count" {
  description = "Maximum ECS web task count for auto-scaling"
  type        = number
  default     = 10
}

variable "owner_tag" {
  type    = string
  default = "platform-team@example.com"
}

variable "cost_centre" {
  type    = string
  default = "CC-MIGRATION"
}
