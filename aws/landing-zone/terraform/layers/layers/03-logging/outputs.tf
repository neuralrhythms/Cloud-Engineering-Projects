# -----------------------------------------------------------------------------
# Layer 03: Logging - Outputs
# -----------------------------------------------------------------------------

output "cloudtrail_bucket_name" {
  description = "Name of the CloudTrail S3 bucket"
  value       = aws_s3_bucket.cloudtrail.id
}

output "cloudtrail_bucket_arn" {
  description = "ARN of the CloudTrail S3 bucket"
  value       = aws_s3_bucket.cloudtrail.arn
}

output "config_bucket_name" {
  description = "Name of the Config S3 bucket"
  value       = aws_s3_bucket.config.id
}

output "config_bucket_arn" {
  description = "ARN of the Config S3 bucket"
  value       = aws_s3_bucket.config.arn
}

output "vpc_flow_logs_bucket_name" {
  description = "Name of the VPC Flow Logs S3 bucket"
  value       = aws_s3_bucket.vpc_flow_logs.id
}

output "vpc_flow_logs_bucket_arn" {
  description = "ARN of the VPC Flow Logs S3 bucket"
  value       = aws_s3_bucket.vpc_flow_logs.arn
}

output "logging_kms_key_arn" {
  description = "ARN of the KMS key for log encryption"
  value       = aws_kms_key.logging.arn
}

output "cloudtrail_trail_arn" {
  description = "ARN of the organization CloudTrail"
  value       = module.cloudtrail.trail_arn
}
