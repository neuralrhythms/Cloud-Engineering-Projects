################################################################################
# Networking — VPCs, Subnets, Transit Gateway, Route 53 Resolver
# Reference framework for VMware → AWS Cloud Native Migration
# Deploy once per account by passing appropriate var files
################################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      TerraformManaged = "true"
      Environment      = var.environment
      Owner            = var.owner_tag
      CostCentre       = var.cost_centre
    }
  }
}

################################################################################
# VPC
################################################################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-${var.account_name}"
  }
}

resource "aws_flow_log" "vpc_flow_logs" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = var.flow_logs_s3_arn

  destination_options {
    file_format        = "parquet"
    per_hour_partition = true
  }

  tags = {
    Name = "flowlog-${var.account_name}"
  }
}

################################################################################
# Subnets
################################################################################

resource "aws_subnet" "public" {
  for_each = { for s in var.public_subnets : s.name => s }

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name = each.value.name
    Tier = "public"
  }
}

resource "aws_subnet" "app" {
  for_each = { for s in var.app_subnets : s.name => s }

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name = each.value.name
    Tier = "application"
  }
}

resource "aws_subnet" "data" {
  for_each = { for s in var.data_subnets : s.name => s }

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name = each.value.name
    Tier = "data"
  }
}

resource "aws_subnet" "tgw" {
  for_each = { for s in var.tgw_subnets : s.name => s }

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name = each.value.name
    Tier = "tgw-attachment"
  }
}

################################################################################
# Internet Gateway (public-facing accounts only)
################################################################################

resource "aws_internet_gateway" "igw" {
  count  = var.create_igw ? 1 : 0
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw-${var.account_name}"
  }
}

################################################################################
# NAT Gateway (one per AZ for prod; single for nonprod)
################################################################################

resource "aws_eip" "nat" {
  for_each = var.create_nat_gateway ? { for s in var.public_subnets : s.name => s } : {}
  domain   = "vpc"

  tags = {
    Name = "eip-nat-${each.key}"
  }
}

resource "aws_nat_gateway" "nat" {
  for_each = var.create_nat_gateway ? { for s in var.public_subnets : s.name => s } : {}

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = {
    Name = "nat-${each.key}"
  }

  depends_on = [aws_internet_gateway.igw]
}

################################################################################
# Route Tables
################################################################################

resource "aws_route_table" "public" {
  count  = var.create_igw ? 1 : 0
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw[0].id
  }

  route {
    cidr_block         = "10.0.0.0/8"
    transit_gateway_id = var.transit_gateway_id
  }

  tags = { Name = "rtb-public-${var.account_name}" }
}

resource "aws_route_table_association" "public" {
  for_each = var.create_igw ? aws_subnet.public : {}

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table" "app" {
  for_each = aws_subnet.app
  vpc_id   = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.create_nat_gateway ? values(aws_nat_gateway.nat)[0].id : null
    # If no NAT, route to TGW for centralised egress
    transit_gateway_id = var.create_nat_gateway ? null : var.transit_gateway_id
  }

  route {
    cidr_block         = "10.0.0.0/8"
    transit_gateway_id = var.transit_gateway_id
  }

  tags = { Name = "rtb-app-${each.key}" }
}

resource "aws_route_table_association" "app" {
  for_each = aws_subnet.app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.app[each.key].id
}

resource "aws_route_table" "data" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block         = "10.0.0.0/8"
    transit_gateway_id = var.transit_gateway_id
  }

  # No default 0.0.0.0/0 — data tier has no internet access

  tags = { Name = "rtb-data-${var.account_name}" }
}

resource "aws_route_table_association" "data" {
  for_each = aws_subnet.data

  subnet_id      = each.value.id
  route_table_id = aws_route_table.data.id
}

################################################################################
# Transit Gateway Attachment
################################################################################

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw" {
  count = var.transit_gateway_id != "" ? 1 : 0

  transit_gateway_id                              = var.transit_gateway_id
  vpc_id                                          = aws_vpc.main.id
  subnet_ids                                      = [for s in aws_subnet.tgw : s.id]
  dns_support                                     = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "tgw-attach-${var.account_name}"
  }
}

################################################################################
# VPC Endpoints
################################################################################

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(
    [for rt in aws_route_table.app : rt.id],
    [aws_route_table.data.id]
  )

  tags = { Name = "vpce-s3-${var.account_name}" }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.app : rt.id]

  tags = { Name = "vpce-dynamodb-${var.account_name}" }
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "sg-vpce-${var.account_name}"
  description = "Allow HTTPS from within VPC to interface VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-vpce-${var.account_name}" }
}

locals {
  interface_endpoints = [
    "secretsmanager", "kms", "logs", "monitoring",
    "ssm", "ssmmessages", "ec2messages", "ecr.api", "ecr.dkr"
  ]
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(var.create_interface_endpoints ? local.interface_endpoints : [])

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.app : s.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = { Name = "vpce-${each.value}-${var.account_name}" }
}

################################################################################
# IAM Role for VPC Flow Logs
################################################################################

resource "aws_iam_role" "flow_logs" {
  name = "role-vpc-flow-logs-${var.account_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "policy-vpc-flow-logs"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetBucketLocation",
        "s3:ListBucket"
      ]
      Resource = [
        var.flow_logs_s3_arn,
        "${var.flow_logs_s3_arn}/*"
      ]
    }]
  })
}
