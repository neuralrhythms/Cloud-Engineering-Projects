# -----------------------------------------------------------------------------
# Transit Gateway Module
# Creates a Transit Gateway with segmented route tables
# Deployed in the Network account and shared via RAM
# -----------------------------------------------------------------------------

resource "aws_ec2_transit_gateway" "this" {
  description                     = var.description
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  auto_accept_shared_attachments  = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = merge(var.tags, {
    Name = "${var.name}-tgw"
  })
}

# -----------------------------------------------------------------------------
# Transit Gateway Route Tables (Segmentation)
# -----------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_route_table" "production" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-tgw-rt-production"
  })
}

resource "aws_ec2_transit_gateway_route_table" "non_production" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-tgw-rt-non-production"
  })
}

resource "aws_ec2_transit_gateway_route_table" "shared_services" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-tgw-rt-shared-services"
  })
}

resource "aws_ec2_transit_gateway_route_table" "edge" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-tgw-rt-edge"
  })
}

# -----------------------------------------------------------------------------
# Resource Access Manager (Share TGW with Organization)
# -----------------------------------------------------------------------------

resource "aws_ram_resource_share" "tgw" {
  name                      = "${var.name}-tgw-share"
  allow_external_principals = false

  tags = merge(var.tags, {
    Name = "${var.name}-tgw-ram-share"
  })
}

resource "aws_ram_resource_association" "tgw" {
  resource_arn       = aws_ec2_transit_gateway.this.arn
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

resource "aws_ram_principal_association" "org" {
  principal          = var.organization_arn
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

# -----------------------------------------------------------------------------
# Egress VPC and Attachment
# -----------------------------------------------------------------------------

resource "aws_vpc" "egress" {
  cidr_block           = var.egress_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.name}-egress-vpc"
  })
}

resource "aws_subnet" "egress_public" {
  count = var.az_count

  vpc_id            = aws_vpc.egress.id
  cidr_block        = cidrsubnet(var.egress_vpc_cidr, 4, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-egress-public-${count.index}"
  })
}

resource "aws_subnet" "egress_private" {
  count = var.az_count

  vpc_id            = aws_vpc.egress.id
  cidr_block        = cidrsubnet(var.egress_vpc_cidr, 4, count.index + var.az_count)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-egress-private-${count.index}"
  })
}

resource "aws_internet_gateway" "egress" {
  vpc_id = aws_vpc.egress.id

  tags = merge(var.tags, {
    Name = "${var.name}-egress-igw"
  })
}

resource "aws_eip" "egress_nat" {
  count  = var.az_count
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}-egress-nat-eip-${count.index}"
  })
}

resource "aws_nat_gateway" "egress" {
  count = var.az_count

  allocation_id = aws_eip.egress_nat[count.index].id
  subnet_id     = aws_subnet.egress_public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.name}-egress-nat-${count.index}"
  })

  depends_on = [aws_internet_gateway.egress]
}

# TGW attachment for egress VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "egress" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = aws_vpc.egress.id
  subnet_ids         = aws_subnet.egress_private[*].id

  tags = merge(var.tags, {
    Name = "${var.name}-egress-tgw-attachment"
  })
}

# Associate egress VPC with edge route table
resource "aws_ec2_transit_gateway_route_table_association" "egress" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.edge.id
}

# Default route in production and non-prod route tables points to egress
resource "aws_ec2_transit_gateway_route" "prod_default" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.production.id
}

resource "aws_ec2_transit_gateway_route" "nonprod_default" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.non_production.id
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}
