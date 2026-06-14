# -----------------------------------------------------------------------------
# Transit Gateway Module - Outputs
# -----------------------------------------------------------------------------

output "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  value       = aws_ec2_transit_gateway.this.id
}

output "transit_gateway_arn" {
  description = "ARN of the Transit Gateway"
  value       = aws_ec2_transit_gateway.this.arn
}

output "production_route_table_id" {
  description = "ID of the production TGW route table"
  value       = aws_ec2_transit_gateway_route_table.production.id
}

output "non_production_route_table_id" {
  description = "ID of the non-production TGW route table"
  value       = aws_ec2_transit_gateway_route_table.non_production.id
}

output "shared_services_route_table_id" {
  description = "ID of the shared services TGW route table"
  value       = aws_ec2_transit_gateway_route_table.shared_services.id
}

output "edge_route_table_id" {
  description = "ID of the edge TGW route table"
  value       = aws_ec2_transit_gateway_route_table.edge.id
}

output "egress_vpc_id" {
  description = "ID of the centralized egress VPC"
  value       = aws_vpc.egress.id
}

output "ram_share_arn" {
  description = "ARN of the RAM resource share for the TGW"
  value       = aws_ram_resource_share.tgw.arn
}
