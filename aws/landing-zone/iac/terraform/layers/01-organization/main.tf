# -----------------------------------------------------------------------------
# Layer 01: Organization
# Creates AWS Organizations structure, OUs, accounts, and SCPs
# Target: Management Account
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
    key            = "01-organization/terraform.tfstate"
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
      Layer       = "organization"
    }
  }
}

# -----------------------------------------------------------------------------
# Organization Module
# -----------------------------------------------------------------------------

module "organization" {
  source = "../../modules/organization"

  security_account_email        = var.security_account_email
  log_archive_account_email     = var.log_archive_account_email
  network_account_email         = var.network_account_email
  shared_services_account_email = var.shared_services_account_email

  security_account_name        = var.security_account_name
  log_archive_account_name     = var.log_archive_account_name
  network_account_name         = var.network_account_name
  shared_services_account_name = var.shared_services_account_name

  workload_accounts   = var.workload_accounts
  organization_role_name = var.organization_role_name
  allowed_regions     = var.allowed_regions

  tags = {
    Project   = "landing-zone"
    ManagedBy = "terraform"
    Layer     = "organization"
  }
}

# Store account IDs in SSM Parameter Store for cross-layer reference
resource "aws_ssm_parameter" "security_account_id" {
  name  = "/landing-zone/accounts/security"
  type  = "String"
  value = module.organization.security_account_id
}

resource "aws_ssm_parameter" "log_archive_account_id" {
  name  = "/landing-zone/accounts/log-archive"
  type  = "String"
  value = module.organization.log_archive_account_id
}

resource "aws_ssm_parameter" "network_account_id" {
  name  = "/landing-zone/accounts/network"
  type  = "String"
  value = module.organization.network_account_id
}

resource "aws_ssm_parameter" "shared_services_account_id" {
  name  = "/landing-zone/accounts/shared-services"
  type  = "String"
  value = module.organization.shared_services_account_id
}
