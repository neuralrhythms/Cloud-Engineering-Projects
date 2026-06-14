# -----------------------------------------------------------------------------
# Layer 02: Security
# Configures organization-wide security services
# Enables GuardDuty, Security Hub, Config aggregator as delegated admin
# Target: Security Tooling Account (with delegated admin from Management)
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
    key            = "02-security/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "landing-zone-terraform-locks"
    encrypt        = true
  }
}

# Management account provider (for delegated admin setup)
provider "aws" {
  alias  = "management"
  region = var.aws_region
}

# Security account provider
provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn     = "arn:aws:iam::${var.security_account_id}:role/${var.organization_role_name}"
    session_name = "terraform-security"
  }

  default_tags {
    tags = {
      Project     = "landing-zone"
      ManagedBy   = "terraform"
      Layer       = "security"
      Environment = "security"
    }
  }
}

# -----------------------------------------------------------------------------
# Delegated Admin Setup (runs in Management Account)
# -----------------------------------------------------------------------------

module "guardduty_delegated_admin" {
  source = "../../modules/guardduty"

  providers = {
    aws = aws.management
  }

  is_delegated_admin_setup = true
  security_account_id      = var.security_account_id
}

module "securityhub_delegated_admin" {
  source = "../../modules/securityhub"

  providers = {
    aws = aws.management
  }

  is_delegated_admin_setup = true
  security_account_id      = var.security_account_id
}

# -----------------------------------------------------------------------------
# Security Account Configuration
# -----------------------------------------------------------------------------

# Security baseline for the security account itself
module "security_baseline" {
  source = "../../modules/security-baseline"

  create_notification_topic  = true
  create_support_role        = true
  trusted_principal_arns     = var.trusted_admin_arns

  tags = {
    Project   = "landing-zone"
    ManagedBy = "terraform"
    Layer     = "security"
  }
}

# GuardDuty organization configuration
module "guardduty" {
  source = "../../modules/guardduty"

  enable_notifications   = true
  notification_topic_arn = module.security_baseline.security_notification_topic_arn
  findings_bucket_arn    = var.guardduty_findings_bucket_arn
  findings_kms_key_arn   = var.logging_kms_key_arn

  depends_on = [module.guardduty_delegated_admin]
}

# Security Hub organization configuration
module "securityhub" {
  source = "../../modules/securityhub"

  enable_aws_foundational_standard  = true
  enable_cis_standard               = true
  enable_nist_standard              = var.enable_nist_standard
  enable_cross_region_aggregation   = true
  enable_notifications              = true
  notification_topic_arn            = module.security_baseline.security_notification_topic_arn

  depends_on = [module.securityhub_delegated_admin]
}

# AWS Config Aggregator
module "config_aggregator" {
  source = "../../modules/config"

  config_bucket_name       = var.config_bucket_name
  s3_key_prefix            = "config/security"
  is_aggregator            = true
  include_global_resources = true
  enable_default_rules     = true

  tags = {
    Project   = "landing-zone"
    ManagedBy = "terraform"
    Layer     = "security"
  }
}
