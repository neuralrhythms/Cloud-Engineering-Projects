# -----------------------------------------------------------------------------
# Layer 06: Workloads - Outputs
# -----------------------------------------------------------------------------

output "workload_vpc_ids" {
  description = "Map of workload names to VPC IDs"
  value       = { for k, v in module.workload_vpc : k => v.vpc_id }
}

output "workload_private_subnet_ids" {
  description = "Map of workload names to private subnet IDs"
  value       = { for k, v in module.workload_vpc : k => v.private_subnet_ids }
}

output "workload_tgw_attachment_ids" {
  description = "Map of workload names to TGW attachment IDs"
  value       = { for k, v in aws_ec2_transit_gateway_vpc_attachment.workload : k => v.id }
}
