# -----------------------------------------------------------------------------
# Organization Module - Outputs
# -----------------------------------------------------------------------------

output "organization_id" {
  description = "The ID of the AWS Organization"
  value       = aws_organizations_organization.this.id
}

output "organization_root_id" {
  description = "The ID of the organization root"
  value       = aws_organizations_organization.this.roots[0].id
}

output "security_ou_id" {
  description = "ID of the Security OU"
  value       = aws_organizations_organizational_unit.security.id
}

output "infrastructure_ou_id" {
  description = "ID of the Infrastructure OU"
  value       = aws_organizations_organizational_unit.infrastructure.id
}

output "workloads_ou_id" {
  description = "ID of the Workloads OU"
  value       = aws_organizations_organizational_unit.workloads.id
}

output "workloads_prod_ou_id" {
  description = "ID of the Production OU (under Workloads)"
  value       = aws_organizations_organizational_unit.workloads_prod.id
}

output "workloads_nonprod_ou_id" {
  description = "ID of the Non-Production OU (under Workloads)"
  value       = aws_organizations_organizational_unit.workloads_nonprod.id
}

output "sandbox_ou_id" {
  description = "ID of the Sandbox OU"
  value       = aws_organizations_organizational_unit.sandbox.id
}

output "suspended_ou_id" {
  description = "ID of the Suspended OU"
  value       = aws_organizations_organizational_unit.suspended.id
}

output "security_account_id" {
  description = "Account ID of the Security Tooling account"
  value       = aws_organizations_account.security.id
}

output "log_archive_account_id" {
  description = "Account ID of the Log Archive account"
  value       = aws_organizations_account.log_archive.id
}

output "network_account_id" {
  description = "Account ID of the Network account"
  value       = aws_organizations_account.network.id
}

output "shared_services_account_id" {
  description = "Account ID of the Shared Services account"
  value       = aws_organizations_account.shared_services.id
}

output "workload_account_ids" {
  description = "Map of workload account names to their IDs"
  value       = { for k, v in aws_organizations_account.workload : k => v.id }
}
