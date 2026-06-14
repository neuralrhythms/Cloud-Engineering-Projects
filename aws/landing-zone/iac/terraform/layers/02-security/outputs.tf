# -----------------------------------------------------------------------------
# Layer 02: Security - Outputs
# -----------------------------------------------------------------------------

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = module.guardduty.detector_id
}

output "securityhub_arn" {
  description = "Security Hub ARN"
  value       = module.securityhub.securityhub_arn
}

output "config_aggregator_arn" {
  description = "Config aggregator ARN"
  value       = module.config_aggregator.aggregator_arn
}

output "security_notification_topic_arn" {
  description = "SNS topic for security notifications"
  value       = module.security_baseline.security_notification_topic_arn
}
