# -----------------------------------------------------------------------------
# Layer 05: Identity
# Configures IAM Identity Center with permission sets and assignments
# Target: Management Account (Identity Center is always in management)
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
    key            = "05-identity/terraform.tfstate"
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
      Layer       = "identity"
    }
  }
}

# -----------------------------------------------------------------------------
# IAM Identity Center
# -----------------------------------------------------------------------------

module "iam_identity_center" {
  source = "../../modules/iam-identity-center"

  account_assignments = var.account_assignments

  tags = {
    Project   = "landing-zone"
    ManagedBy = "terraform"
    Layer     = "identity"
  }
}
