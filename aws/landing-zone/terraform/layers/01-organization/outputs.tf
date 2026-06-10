# -----------------------------------------------------------------------------
# Layer 01: Organization - Outputs
# -----------------------------------------------------------------------------

output "organization_id" {
  description = "AWS Organization ID"
  value       = module.organization.organization_id
}

output "security_account_id" {
  description = "Security Tooling account ID"
  value       = module.organization.security_account_id
}

output "log_archive_account_id" {
  description = "Log Archive account ID"
  value       = module.organization.log_archive_account_id
}

output "network_account_id" {
  description = "Network account ID"
  value       = module.organization.network_account_id
}

output "shared_services_account_id" {
  description = "Shared Services account ID"
  value       = module.organization.shared_services_account_id
}

output "workloads_prod_ou_id" {
  description = "Production OU ID"
  value       = module.organization.workloads_prod_ou_id
}

output "workloads_nonprod_ou_id" {
  description = "Non-Production OU ID"
  value       = module.organization.workloads_nonprod_ou_id
}

output "workload_account_ids" {
  description = "Map of workload account names to IDs"
  value       = module.organization.workload_account_ids
}
