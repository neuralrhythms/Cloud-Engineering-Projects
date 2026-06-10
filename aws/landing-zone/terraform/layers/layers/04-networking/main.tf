# -----------------------------------------------------------------------------
# Layer 04: Networking
# Creates Transit Gateway, Egress VPC, Shared Services VPC, DNS
# Target: Network Account
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "landing-zone-terraform-state-ACCOUNT_ID"
    key            = "04-networking/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "landing-zone-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn     = "arn:aws:iam::${var.network_account_id}:role/${var.organization_role_name}"
    session_name = "terraform-networking"
  }

  default_tags {
    tags = {
      Project     = "landing-zone"
      ManagedBy   = "terraform"
      Layer       = "networking"
      Environment = "network"
    }
  }
}

# -----------------------------------------------------------------------------
# Transit Gateway
# -----------------------------------------------------------------------------

module "transit_gateway" {
  source = "../../modules/transit-gateway"

  name             = var.transit_gateway_name
  organization_arn = var.organization_arn
  egress_vpc_cidr  = var.egress_vpc_cidr
  az_count         = var.az_count

  tags = {
    Project   = "landing-zone"
    ManagedBy = "terraform"
    Layer     = "networking"
  }
}

# -----------------------------------------------------------------------------
# Shared Services VPC
# -----------------------------------------------------------------------------

module "shared_services_vpc" {
  source = "../../modules/vpc"

  name                    = "shared-services"
  vpc_cidr                = var.shared_services_vpc_cidr
  az_count                = var.az_count
  enable_public_subnets   = false
  enable_nat_gateway      = false
  enable_isolated_subnets = true
  enable_flow_logs        = true
  flow_logs_bucket_arn    = var.flow_logs_bucket_arn

  tags = {
    Project   = "landing-zone"
    ManagedBy = "terraform"
    Layer     = "networking"
  }
}

# Attach Shared Services VPC to Transit Gateway
resource "aws_ec2_transit_gateway_vpc_attachment" "shared_services" {
  transit_gateway_id = module.transit_gateway.transit_gateway_id
  vpc_id             = module.shared_services_vpc.vpc_id
  subnet_ids         = module.shared_services_vpc.private_subnet_ids

  tags = {
    Name = "shared-services-tgw-attachment"
  }
}

# Associate with shared services route table
resource "aws_ec2_transit_gateway_route_table_association" "shared_services" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shared_services.id
  transit_gateway_route_table_id = module.transit_gateway.shared_services_route_table_id
}

# Route from shared services VPC to TGW for all traffic
resource "aws_route" "shared_services_to_tgw" {
  count = var.az_count

  route_table_id         = module.shared_services_vpc.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = module.transit_gateway.transit_gateway_id
}

# -----------------------------------------------------------------------------
# Route 53 Private Hosted Zone (shared DNS)
# -----------------------------------------------------------------------------

resource "aws_route53_zone" "private" {
  name = "internal.landing-zone.local"

  vpc {
    vpc_id = module.shared_services_vpc.vpc_id
  }

  tags = {
    Name = "internal-dns-zone"
  }

  lifecycle {
    ignore_changes = [vpc]
  }
}

# Store TGW ID in SSM for cross-layer reference
resource "aws_ssm_parameter" "tgw_id" {
  name  = "/landing-zone/networking/transit-gateway-id"
  type  = "String"
  value = module.transit_gateway.transit_gateway_id
}
