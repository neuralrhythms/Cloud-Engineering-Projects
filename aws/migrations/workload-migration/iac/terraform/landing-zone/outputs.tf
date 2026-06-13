output "security_ou_id" {
  description = "Security OU ID"
  value       = aws_organizations_organizational_unit.security.id
}

output "infrastructure_ou_id" {
  description = "Infrastructure OU ID"
  value       = aws_organizations_organizational_unit.infrastructure.id
}

output "workloads_ou_id" {
  description = "Workloads OU ID"
  value       = aws_organizations_organizational_unit.workloads.id
}

output "sandbox_ou_id" {
  description = "Sandbox OU ID"
  value       = aws_organizations_organizational_unit.sandbox.id
}

output "scp_deny_root_id" {
  description = "SCP ID — deny root actions"
  value       = aws_organizations_policy.deny_root_actions.id
}

output "scp_restrict_regions_id" {
  description = "SCP ID — region restriction"
  value       = aws_organizations_policy.restrict_regions.id
}
