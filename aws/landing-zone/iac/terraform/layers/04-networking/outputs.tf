# -----------------------------------------------------------------------------
# Layer 04: Networking - Outputs
# -----------------------------------------------------------------------------

output "transit_gateway_id" {
  description = "Transit Gateway ID"
  value       = module.transit_gateway.transit_gateway_id
}

output "transit_gateway_arn" {
  description = "Transit Gateway ARN"
  value       = module.transit_gateway.transit_gateway_arn
}

output "production_route_table_id" {
  description = "TGW production route table ID"
  value       = module.transit_gateway.production_route_table_id
}

output "non_production_route_table_id" {
  description = "TGW non-production route table ID"
  value       = module.transit_gateway.non_production_route_table_id
}

output "shared_services_route_table_id" {
  description = "TGW shared services route table ID"
  value       = module.transit_gateway.shared_services_route_table_id
}

output "shared_services_vpc_id" {
  description = "Shared services VPC ID"
  value       = module.shared_services_vpc.vpc_id
}

output "shared_services_private_subnet_ids" {
  description = "Private subnet IDs in the shared services VPC"
  value       = module.shared_services_vpc.private_subnet_ids
}
