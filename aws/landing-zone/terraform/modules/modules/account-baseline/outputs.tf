# -----------------------------------------------------------------------------
# Account Baseline Module - Outputs
# -----------------------------------------------------------------------------

output "access_analyzer_arn" {
  description = "ARN of the IAM Access Analyzer"
  value       = module.security_baseline.access_analyzer_arn
}

output "security_notification_topic_arn" {
  description = "ARN of the security notifications SNS topic"
  value       = module.security_baseline.security_notification_topic_arn
}

output "config_recorder_id" {
  description = "ID of the AWS Config recorder"
  value       = module.config.recorder_id
}
