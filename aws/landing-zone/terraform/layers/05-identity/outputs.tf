# -----------------------------------------------------------------------------
# Layer 05: Identity - Outputs
# -----------------------------------------------------------------------------

output "sso_instance_arn" {
  description = "IAM Identity Center instance ARN"
  value       = module.iam_identity_center.sso_instance_arn
}

output "identity_store_id" {
  description = "Identity Store ID"
  value       = module.iam_identity_center.identity_store_id
}

output "permission_set_arns" {
  description = "Map of permission set names to ARNs"
  value       = module.iam_identity_center.permission_set_arns
}
