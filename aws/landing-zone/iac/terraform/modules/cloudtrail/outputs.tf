# -----------------------------------------------------------------------------
# CloudTrail Module - Outputs
# -----------------------------------------------------------------------------

output "trail_arn" {
  description = "ARN of the CloudTrail trail"
  value       = aws_cloudtrail.organization.arn
}

output "trail_name" {
  description = "Name of the CloudTrail trail"
  value       = aws_cloudtrail.organization.name
}
