output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = [for s in aws_subnet.public : s.id]
}

output "app_subnet_ids" {
  description = "List of application subnet IDs"
  value       = [for s in aws_subnet.app : s.id]
}

output "data_subnet_ids" {
  description = "List of data subnet IDs"
  value       = [for s in aws_subnet.data : s.id]
}

output "tgw_subnet_ids" {
  description = "List of TGW attachment subnet IDs"
  value       = [for s in aws_subnet.tgw : s.id]
}

output "tgw_attachment_id" {
  description = "Transit Gateway VPC Attachment ID"
  value       = length(aws_ec2_transit_gateway_vpc_attachment.tgw) > 0 ? aws_ec2_transit_gateway_vpc_attachment.tgw[0].id : null
}

output "vpc_endpoint_sg_id" {
  description = "Security Group ID for VPC endpoints"
  value       = aws_security_group.vpc_endpoints.id
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs (keyed by public subnet name)"
  value       = { for k, v in aws_nat_gateway.nat : k => v.id }
}
