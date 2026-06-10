# -----------------------------------------------------------------------------
# IAM Identity Center Module - Outputs
# -----------------------------------------------------------------------------

output "sso_instance_arn" {
  description = "ARN of the IAM Identity Center instance"
  value       = local.sso_instance_arn
}

output "identity_store_id" {
  description = "ID of the Identity Store"
  value       = local.identity_store_id
}

output "permission_set_arns" {
  description = "Map of permission set names to their ARNs"
  value       = local.permission_set_arns
}

output "admin_permission_set_arn" {
  description = "ARN of the Administrator permission set"
  value       = aws_ssoadmin_permission_set.admin.arn
}

output "readonly_permission_set_arn" {
  description = "ARN of the ReadOnly permission set"
  value       = aws_ssoadmin_permission_set.readonly.arn
}

output "developer_permission_set_arn" {
  description = "ARN of the Developer permission set"
  value       = aws_ssoadmin_permission_set.developer.arn
}
