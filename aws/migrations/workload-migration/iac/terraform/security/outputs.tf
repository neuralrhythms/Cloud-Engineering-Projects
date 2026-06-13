output "kms_key_rds_mssql_arn" {
  description = "KMS CMK ARN for RDS SQL Server"
  value       = aws_kms_key.rds_mssql.arn
}

output "kms_key_aurora_mysql_arn" {
  description = "KMS CMK ARN for Aurora MySQL"
  value       = aws_kms_key.aurora_mysql.arn
}

output "kms_key_ebs_arn" {
  description = "KMS CMK ARN for EBS encryption"
  value       = aws_kms_key.ebs.arn
}

output "kms_key_secrets_arn" {
  description = "KMS CMK ARN for Secrets Manager"
  value       = aws_kms_key.secrets.arn
}

output "kms_key_terraform_state_arn" {
  description = "KMS CMK ARN for Terraform state bucket"
  value       = var.is_shared_services ? aws_kms_key.terraform_state[0].arn : null
}

output "ec2_instance_profile_name" {
  description = "EC2 instance profile name for rehosted workloads"
  value       = aws_iam_instance_profile.ec2_workload.name
}

output "ecs_task_execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = aws_guardduty_detector.main.id
}

output "terraform_state_bucket_name" {
  description = "Terraform state S3 bucket name (shared-services only)"
  value       = var.is_shared_services ? aws_s3_bucket.terraform_state[0].id : null
}

output "terraform_lock_table_name" {
  description = "DynamoDB lock table name (shared-services only)"
  value       = var.is_shared_services ? aws_dynamodb_table.terraform_lock[0].name : null
}
