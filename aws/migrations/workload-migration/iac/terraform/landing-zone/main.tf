################################################################################
# Landing Zone — AWS Organizations, SCPs, and Control Tower Guardrails
# Reference framework for VMware → AWS Cloud Native Migration
################################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Populated via -backend-config or terragrunt
    # bucket         = "s3-tfstate-<account-id>-<region>"
    # key            = "landing-zone/terraform.tfstate"
    # region         = "ap-southeast-2"
    # encrypt        = true
    # kms_key_id     = "alias/terraform-state"
    # dynamodb_table = "ddb-terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      TerraformManaged = "true"
      Environment      = "management"
      Owner            = var.owner_tag
      CostCentre       = var.cost_centre
    }
  }
}

################################################################################
# Organisational Units
################################################################################

resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = data.aws_organizations_organization.root.roots[0].id
}

resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = data.aws_organizations_organization.root.roots[0].id
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = data.aws_organizations_organization.root.roots[0].id
}

resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = data.aws_organizations_organization.root.roots[0].id
}

################################################################################
# Service Control Policies
################################################################################

resource "aws_organizations_policy" "deny_root_actions" {
  name        = "scp-deny-root-actions"
  description = "Deny all actions performed by root account credentials"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/scp-deny-root-actions.json")
}

resource "aws_organizations_policy" "restrict_regions" {
  name        = "scp-restrict-regions"
  description = "Restrict resource creation to approved AWS regions"
  type        = "SERVICE_CONTROL_POLICY"
  content     = templatefile("${path.module}/policies/scp-restrict-regions.json.tpl", {
    approved_regions = jsonencode(var.approved_regions)
  })
}

resource "aws_organizations_policy" "deny_disable_security_services" {
  name        = "scp-deny-disable-security-services"
  description = "Prevent disabling of CloudTrail, GuardDuty, Config, Security Hub"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/scp-deny-disable-security-services.json")
}

resource "aws_organizations_policy" "require_encryption" {
  name        = "scp-require-encryption"
  description = "Deny creation of unencrypted EBS volumes and RDS instances"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/scp-require-encryption.json")
}

resource "aws_organizations_policy" "deny_public_s3" {
  name        = "scp-deny-public-s3"
  description = "Enforce S3 Block Public Access"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/scp-deny-public-s3.json")
}

################################################################################
# SCP Attachments
################################################################################

# Deny root actions — all OUs
resource "aws_organizations_policy_attachment" "deny_root_security" {
  policy_id = aws_organizations_policy.deny_root_actions.id
  target_id = aws_organizations_organizational_unit.security.id
}

resource "aws_organizations_policy_attachment" "deny_root_infra" {
  policy_id = aws_organizations_policy.deny_root_actions.id
  target_id = aws_organizations_organizational_unit.infrastructure.id
}

resource "aws_organizations_policy_attachment" "deny_root_workloads" {
  policy_id = aws_organizations_policy.deny_root_actions.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_policy_attachment" "deny_root_sandbox" {
  policy_id = aws_organizations_policy.deny_root_actions.id
  target_id = aws_organizations_organizational_unit.sandbox.id
}

# Region restriction — workloads and infrastructure
resource "aws_organizations_policy_attachment" "restrict_regions_infra" {
  policy_id = aws_organizations_policy.restrict_regions.id
  target_id = aws_organizations_organizational_unit.infrastructure.id
}

resource "aws_organizations_policy_attachment" "restrict_regions_workloads" {
  policy_id = aws_organizations_policy.restrict_regions.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

# Deny disabling security services — all OUs
resource "aws_organizations_policy_attachment" "deny_disable_sec_security" {
  policy_id = aws_organizations_policy.deny_disable_security_services.id
  target_id = aws_organizations_organizational_unit.security.id
}

resource "aws_organizations_policy_attachment" "deny_disable_sec_infra" {
  policy_id = aws_organizations_policy.deny_disable_security_services.id
  target_id = aws_organizations_organizational_unit.infrastructure.id
}

resource "aws_organizations_policy_attachment" "deny_disable_sec_workloads" {
  policy_id = aws_organizations_policy.deny_disable_security_services.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

# Require encryption — workloads OU only
resource "aws_organizations_policy_attachment" "require_enc_workloads" {
  policy_id = aws_organizations_policy.require_encryption.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

# Deny public S3 — all OUs
resource "aws_organizations_policy_attachment" "deny_public_s3_security" {
  policy_id = aws_organizations_policy.deny_public_s3.id
  target_id = aws_organizations_organizational_unit.security.id
}

resource "aws_organizations_policy_attachment" "deny_public_s3_infra" {
  policy_id = aws_organizations_policy.deny_public_s3.id
  target_id = aws_organizations_organizational_unit.infrastructure.id
}

resource "aws_organizations_policy_attachment" "deny_public_s3_workloads" {
  policy_id = aws_organizations_policy.deny_public_s3.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

################################################################################
# Data Sources
################################################################################

data "aws_organizations_organization" "root" {}
