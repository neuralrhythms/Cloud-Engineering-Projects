# -----------------------------------------------------------------------------
# Layer 06: Workloads
# Applies account baseline and networking to each workload account
# Target: Each Workload Account
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
    key            = "06-workloads/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "landing-zone-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "landing-zone"
      ManagedBy   = "terraform"
      Layer       = "workload"
    }
  }
}

# -----------------------------------------------------------------------------
# Workload Account Baselines
# Each workload gets: security baseline, Config, VPC, TGW attachment
# -----------------------------------------------------------------------------

module "workload_baseline" {
  source   = "../../modules/account-baseline"
  for_each = { for acct in var.workload_accounts : acct.name => acct }

  providers = {
    aws = aws
  }

  account_name                = each.value.name
  config_bucket_name          = var.config_bucket_name
  ebs_kms_key_arn             = ""
  create_support_role         = true
  trusted_principal_arns      = var.trusted_admin_arns
  create_notification_topic   = true
  include_global_resources    = each.value.include_global_resources
  enable_default_config_rules = true

  tags = {
    Project     = "landing-zone"
    ManagedBy   = "terraform"
    Layer       = "workload"
    Environment = each.value.environment
    Team        = each.value.team
  }
}

# VPC for each workload account
module "workload_vpc" {
  source   = "../../modules/vpc"
  for_each = { for acct in var.workload_accounts : acct.name => acct }

  name                    = each.value.name
  vpc_cidr                = each.value.vpc_cidr
  az_count                = var.az_count
  enable_public_subnets   = each.value.environment != "production"
  enable_nat_gateway      = false  # Using centralized egress
  enable_isolated_subnets = true
  enable_flow_logs        = true
  flow_logs_bucket_arn    = var.flow_logs_bucket_arn

  tags = {
    Project     = "landing-zone"
    ManagedBy   = "terraform"
    Layer       = "workload"
    Environment = each.value.environment
    Team        = each.value.team
  }
}

# TGW Attachment for each workload VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "workload" {
  for_each = { for acct in var.workload_accounts : acct.name => acct }

  transit_gateway_id = var.transit_gateway_id
  vpc_id             = module.workload_vpc[each.key].vpc_id
  subnet_ids         = module.workload_vpc[each.key].private_subnet_ids

  tags = {
    Name        = "${each.key}-tgw-attachment"
    Environment = each.value.environment
  }
}

# Route tables: default route through TGW for egress
resource "aws_route" "workload_to_tgw" {
  for_each = { for pair in local.route_table_pairs : "${pair.account}-${pair.index}" => pair }

  route_table_id         = each.value.route_table_id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = var.transit_gateway_id
}

locals {
  route_table_pairs = flatten([
    for acct in var.workload_accounts : [
      for idx, rt_id in module.workload_vpc[acct.name].private_route_table_ids : {
        account        = acct.name
        index          = idx
        route_table_id = rt_id
      }
    ]
  ])
}
