# -----------------------------------------------------------------------------
# AWS Config Module - Outputs
# -----------------------------------------------------------------------------

output "recorder_id" {
  description = "ID of the Config recorder"
  value       = aws_config_configuration_recorder.this.id
}

output "config_role_arn" {
  description = "ARN of the IAM role used by Config"
  value       = aws_iam_role.config.arn
}

output "aggregator_arn" {
  description = "ARN of the Config aggregator (if created)"
  value       = var.is_aggregator ? aws_config_configuration_aggregator.organization[0].arn : ""
}
