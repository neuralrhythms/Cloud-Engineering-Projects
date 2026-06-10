output "sns_topic_arn" {
  description = "ARN of the SNS topic for fraud alerts"
  value       = aws_sns_topic.fraud_alerts.arn
}
