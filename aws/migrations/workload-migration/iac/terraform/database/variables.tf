variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  description = "VPC ID of the workload account"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR for security group rules"
  type        = string
}

variable "data_subnet_ids" {
  description = "List of data tier subnet IDs"
  type        = list(string)
}

variable "app_security_group_ids" {
  description = "Security group IDs of application tier (EC2/ECS) allowed to access databases"
  type        = list(string)
}

variable "kms_key_rds_mssql_arn" {
  description = "KMS CMK ARN for RDS SQL Server encryption"
  type        = string
}

variable "kms_key_aurora_mysql_arn" {
  description = "KMS CMK ARN for Aurora MySQL encryption"
  type        = string
}

variable "kms_key_secrets_arn" {
  description = "KMS CMK ARN for Secrets Manager"
  type        = string
}

variable "sns_ops_topic_arn" {
  description = "SNS topic ARN for operational alarms"
  type        = string
}

# RDS SQL Server
variable "mssql_engine_version" {
  description = "SQL Server engine version"
  type        = string
  default     = "15.00.4236.7.v1" # SQL Server 2019 SE
}

variable "mssql_instance_class" {
  description = "RDS instance class for SQL Server"
  type        = string
  default     = "db.m6i.xlarge"
}

variable "mssql_license_model" {
  description = "License model: license-included or bring-your-own-license"
  type        = string
  default     = "license-included"
}

variable "mssql_allocated_storage_gb" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 500
}

variable "mssql_max_allocated_storage_gb" {
  description = "Maximum autoscaling storage in GB"
  type        = number
  default     = 2000
}

variable "mssql_option_group_name" {
  description = "RDS option group name (pre-created with SQLSERVER_BACKUP_RESTORE)"
  type        = string
  default     = ""
}

# Aurora MySQL Serverless v2
variable "aurora_mysql_engine_version" {
  description = "Aurora MySQL engine version"
  type        = string
  default     = "8.0.mysql_aurora.3.04.0"
}

variable "aurora_min_acu" {
  description = "Aurora Serverless v2 minimum ACUs"
  type        = number
  default     = 0.5
}

variable "aurora_max_acu" {
  description = "Aurora Serverless v2 maximum ACUs"
  type        = number
  default     = 16
}

# DMS
variable "dms_instance_class" {
  description = "DMS replication instance class"
  type        = string
  default     = "dms.r6i.xlarge"
}

# SDDC source database connection (use Secrets Manager in production; vars for framework demo)
variable "sddc_mssql_host" {
  description = "SDDC SQL Server hostname or IP"
  type        = string
  default     = "10.10.2.10"
}

variable "sddc_mssql_username" {
  description = "SDDC SQL Server migration username"
  type        = string
  default     = "dms_migration_user"
  sensitive   = true
}

variable "sddc_mssql_password" {
  description = "SDDC SQL Server migration password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "sddc_mssql_database" {
  description = "SDDC SQL Server source database name"
  type        = string
  default     = "master"
}

variable "sddc_mysql_host" {
  description = "SDDC MySQL hostname or IP"
  type        = string
  default     = "10.10.2.20"
}

variable "sddc_mysql_username" {
  description = "SDDC MySQL migration username"
  type        = string
  default     = "dms_migration_user"
  sensitive   = true
}

variable "sddc_mysql_password" {
  description = "SDDC MySQL migration password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "sddc_mysql_database" {
  description = "SDDC MySQL source database name"
  type        = string
  default     = "main"
}

variable "sddc_db_cidrs" {
  description = "CIDR blocks of SDDC database subnet (for DMS egress SG rules)"
  type        = list(string)
  default     = ["10.10.2.0/24"]
}

variable "owner_tag" {
  type    = string
  default = "platform-team@example.com"
}

variable "cost_centre" {
  type    = string
  default = "CC-MIGRATION"
}
