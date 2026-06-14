# =============================================================================
# Module: networking
# Purpose: VPC, subnets, NAT gateways, route tables, VPC endpoints
# =============================================================================
# NOTE: This is a scaffolding placeholder.
# Implement using terraform-aws-modules/vpc/aws or equivalent resources.
# See docs/architecture/network-design.md for design specifications.
# =============================================================================

locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = merge(var.tags, {
    Module      = "networking"
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
# TODO: Implement aws_vpc resource
# Reference: docs/architecture/network-design.md

# resource "aws_vpc" "main" {
#   cidr_block           = var.vpc_cidr
#   enable_dns_hostnames = true
#   enable_dns_support   = true
#
#   tags = merge(local.common_tags, {
#     Name = "${local.name_prefix}-vpc"
#   })
# }

# -----------------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------------
# TODO: Implement aws_internet_gateway

# -----------------------------------------------------------------------------
# Public Subnets
# -----------------------------------------------------------------------------
# TODO: Implement aws_subnet (public) across var.availability_zones
# Required tags for EKS:
#   kubernetes.io/role/elb = 1
#   kubernetes.io/cluster/${var.cluster_name} = shared

# -----------------------------------------------------------------------------
# Private Subnets
# -----------------------------------------------------------------------------
# TODO: Implement aws_subnet (private) across var.availability_zones
# Required tags for EKS:
#   kubernetes.io/role/internal-elb = 1
#   kubernetes.io/cluster/${var.cluster_name} = shared

# -----------------------------------------------------------------------------
# Elastic IPs for NAT Gateways
# -----------------------------------------------------------------------------
# TODO: Implement aws_eip (one per AZ in prod; single in dev/test)

# -----------------------------------------------------------------------------
# NAT Gateways
# -----------------------------------------------------------------------------
# TODO: Implement aws_nat_gateway
# Count controlled by var.single_nat_gateway (dev/test = true, prod = false)

# -----------------------------------------------------------------------------
# Route Tables
# -----------------------------------------------------------------------------
# TODO: Implement aws_route_table (public), aws_route_table (private per AZ)
# TODO: Implement aws_route_table_association

# -----------------------------------------------------------------------------
# VPC Endpoints
# -----------------------------------------------------------------------------
# TODO: Implement aws_vpc_endpoint for:
#   - S3 (Gateway type — free)
#   - ECR API (Interface)
#   - ECR DKR (Interface)
#   - Secrets Manager (Interface)
#   - SSM (Interface)
#   - CloudWatch Logs (Interface)
#   - KMS (Interface)
#   - STS (Interface)

# -----------------------------------------------------------------------------
# VPC Flow Logs
# -----------------------------------------------------------------------------
# TODO: Implement aws_flow_log → CloudWatch Logs
