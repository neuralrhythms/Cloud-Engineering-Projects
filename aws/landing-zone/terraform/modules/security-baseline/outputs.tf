# -----------------------------------------------------------------------------
# Security Baseline Module - Outputs
# -----------------------------------------------------------------------------

output "access_analyzer_arn" {
  description = "ARN of the IAM Access Analyzer"
  value       = aws_accessanalyzer_analyzer.account.arn
}

output "security_notification_topic_arn" {
  description = "ARN of the security notifications SNS topic"
  value       = var.create_notification_topic ? aws_sns_topic.security_notifications[0].arn : ""
}

output "support_role_arn" {
  description = "ARN of the AWS Support access role"
  value       = var.create_support_role ? aws_iam_role.support[0].arn : ""
}
