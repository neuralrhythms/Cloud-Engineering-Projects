output "event_bus_name" {
  description = "Name of the custom EventBridge event bus"
  value       = aws_cloudwatch_event_bus.fraud_events.name
}

output "event_bus_arn" {
  description = "ARN of the custom EventBridge event bus"
  value       = aws_cloudwatch_event_bus.fraud_events.arn
}

output "high_risk_rule_arn" {
  description = "ARN of the high-risk EventBridge rule"
  value       = aws_cloudwatch_event_rule.high_risk.arn
}
