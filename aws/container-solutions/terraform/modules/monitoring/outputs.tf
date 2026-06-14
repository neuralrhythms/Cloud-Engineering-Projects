output "sns_alert_topic_arn" {
  description = "ARN of the SNS topic for cluster alerts"
  value       = null # TODO: replace with aws_sns_topic.alerts.arn
}

output "cloudwatch_log_group_names" {
  description = "Map of log group purpose to log group name"
  value       = {} # TODO: replace with log group name map
}
