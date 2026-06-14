# -----------------------------------------------------------------------------
# Security Hub Module - Outputs
# -----------------------------------------------------------------------------

output "securityhub_arn" {
  description = "ARN of the Security Hub"
  value       = aws_securityhub_account.this.arn
}
